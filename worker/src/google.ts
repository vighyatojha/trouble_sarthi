// worker/src/google.ts
// Minimal Google APIs for the Worker: verify Firebase ID tokens, get an OAuth
// access token from the service account, and talk to Firestore (REST) and
// Firebase Cloud Messaging (HTTP v1).

import { SignJWT, importPKCS8, jwtVerify, createRemoteJWKSet } from "jose";

export interface Env {
  FIREBASE_PROJECT_ID: string;
  SERVICE_ACCOUNT_JSON: string;
}

// ─── ID token (who is calling) ──────────────────────────────────────────────

const JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

export async function verifyIdToken(token: string, projectId: string): Promise<string> {
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
    algorithms: ["RS256"],
  });
  if (typeof payload.sub !== "string" || payload.sub.length === 0) throw new Error("no uid");
  return payload.sub;
}

// ─── Service-account access token (cached per Worker instance) ──────────────

let cached: { token: string; exp: number } | null = null;

export async function accessToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;
  const sa = JSON.parse(env.SERVICE_ACCOUNT_JSON) as { client_email: string; private_key: string };
  const key = await importPKCS8(sa.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}`);
  const j = (await res.json()) as { access_token: string; expires_in: number };
  cached = { token: j.access_token, exp: now + j.expires_in };
  return j.access_token;
}

// ─── Firestore value encoding ───────────────────────────────────────────────

type FsValue = Record<string, unknown>;
export type Doc = { id: string; path: string; data: Record<string, unknown> };

export function fromValue(v: FsValue): unknown {
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return Number(v.doubleValue);
  if ("booleanValue" in v) return v.booleanValue;
  if ("nullValue" in v) return null;
  if ("timestampValue" in v) return new Date(v.timestampValue as string);
  if ("geoPointValue" in v) return v.geoPointValue;
  if ("arrayValue" in v) {
    const arr = (v.arrayValue as { values?: FsValue[] }).values ?? [];
    return arr.map(fromValue);
  }
  if ("mapValue" in v) return fromFields((v.mapValue as { fields?: Record<string, FsValue> }).fields ?? {});
  return undefined;
}

export function fromFields(fields: Record<string, FsValue>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(fields)) out[k] = fromValue(v);
  return out;
}

export function toValue(v: unknown): FsValue {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (typeof v === "object") return { mapValue: { fields: toFields(v as Record<string, unknown>) } };
  throw new Error(`cannot encode ${typeof v}`);
}

export function toFields(o: Record<string, unknown>): Record<string, FsValue> {
  const out: Record<string, FsValue> = {};
  for (const [k, v] of Object.entries(o)) if (v !== undefined) out[k] = toValue(v);
  return out;
}

/** Field path segment with special characters (e.g. an FCM token) must be back-quoted. */
export function quoteSegment(s: string): string {
  return /^[A-Za-z_][A-Za-z_0-9]*$/.test(s) ? s : "`" + s.replace(/\\/g, "\\\\").replace(/`/g, "\\`") + "`";
}

// ─── Firestore REST ─────────────────────────────────────────────────────────

export class Firestore {
  private root: string;
  constructor(private env: Env) {
    this.root = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
  }

  private async call(url: string, init: RequestInit): Promise<Response> {
    const token = await accessToken(this.env);
    return fetch(url, {
      ...init,
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...(init.headers ?? {}) },
    });
  }

  name(path: string): string {
    return `${this.root}/${path}`;
  }

  async get(path: string): Promise<Doc | null> {
    const res = await this.call(`https://firestore.googleapis.com/v1/${this.name(path)}`, { method: "GET" });
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`firestore get ${path}: ${res.status}`);
    const j = (await res.json()) as { name: string; fields?: Record<string, FsValue> };
    return { id: j.name.split("/").pop()!, path, data: fromFields(j.fields ?? {}) };
  }

  /** Many documents in ONE request. Missing documents come back as null. */
  async getAll(paths: string[]): Promise<Map<string, Doc | null>> {
    const out = new Map<string, Doc | null>();
    if (paths.length === 0) return out;
    const res = await this.call(`https://firestore.googleapis.com/v1/${this.root}:batchGet`, {
      method: "POST",
      body: JSON.stringify({ documents: paths.map((p) => this.name(p)) }),
    });
    if (!res.ok) throw new Error(`firestore batchGet: ${res.status}`);
    const rows = (await res.json()) as Array<{
      found?: { name: string; fields?: Record<string, FsValue> };
      missing?: string;
    }>;
    for (const r of rows) {
      if (r.found) {
        const path = r.found.name.slice(this.root.length + 1);
        out.set(path, { id: path.split("/").pop()!, path, data: fromFields(r.found.fields ?? {}) });
      } else if (r.missing) {
        out.set(r.missing.slice(this.root.length + 1), null);
      }
    }
    return out;
  }

  /** Simple query: collection (optionally under a parent document) + filters. */
  async query(
    collectionId: string,
    filters: Array<{ field: string; op: "EQUAL" | "IN"; value: unknown }>,
    parentPath = "",
    limit = 300,
  ): Promise<Doc[]> {
    const parent = parentPath ? `${this.root}/${parentPath}` : this.root;
    const fieldFilters = filters.map((f) => ({
      fieldFilter: { field: { fieldPath: f.field }, op: f.op, value: toValue(f.value) },
    }));
    const where = fieldFilters.length === 1
      ? fieldFilters[0]
      : { compositeFilter: { op: "AND", filters: fieldFilters } };
    const res = await this.call(`https://firestore.googleapis.com/v1/${parent}:runQuery`, {
      method: "POST",
      body: JSON.stringify({ structuredQuery: { from: [{ collectionId }], where, limit } }),
    });
    if (!res.ok) throw new Error(`firestore query ${collectionId}: ${res.status} ${await res.text()}`);
    const rows = (await res.json()) as Array<{ document?: { name: string; fields?: Record<string, FsValue> } }>;
    return rows
      .filter((r) => r.document)
      .map((r) => {
        const path = r.document!.name.slice(this.root.length + 1);
        return { id: path.split("/").pop()!, path, data: fromFields(r.document!.fields ?? {}) };
      });
  }

  /** Atomic multi-document write. */
  async commit(writes: Write[]): Promise<void> {
    if (writes.length === 0) return;
    for (let i = 0; i < writes.length; i += 450) {
      const chunk = writes.slice(i, i + 450).map((w) => {
        const out: Record<string, unknown> = {
          update: { name: this.name(w.path), fields: toFields(w.fields) },
        };
        if (w.mask) out.updateMask = { fieldPaths: w.mask };
        if (w.serverTime?.length) {
          out.updateTransforms = w.serverTime.map((f) => ({ fieldPath: f, setToServerValue: "REQUEST_TIME" }));
        }
        return out;
      });
      const res = await this.call(`https://firestore.googleapis.com/v1/${this.root}:commit`, {
        method: "POST",
        body: JSON.stringify({ writes: chunk }),
      });
      if (!res.ok) throw new Error(`firestore commit: ${res.status} ${await res.text()}`);
    }
  }
}

export interface Write {
  path: string;
  fields: Record<string, unknown>;
  /** Field paths to update. Omit to replace the whole document. */
  mask?: string[];
  /** Field paths set to the server's time. */
  serverTime?: string[];
}

// ─── FCM HTTP v1 ────────────────────────────────────────────────────────────

export interface Push {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  channelId: string;
  collapseKey?: string;
}

/** Sends one push. Returns false if the token is dead and should be removed. */
export async function sendPush(env: Env, p: Push): Promise<boolean> {
  const token = await accessToken(env);
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({
      message: {
        token: p.token,
        notification: { title: p.title, body: p.body },
        data: p.data,
        android: {
          priority: "HIGH",
          ...(p.collapseKey ? { collapseKey: p.collapseKey } : {}),
          notification: { channelId: p.channelId, ...(p.collapseKey ? { tag: p.collapseKey } : {}) },
        },
        apns: { payload: { aps: { sound: "default" } } },
      },
    }),
  });
  if (res.ok) return true;
  if (res.status === 404) return false; // UNREGISTERED: app uninstalled / token rotated
  if (res.status === 400) {
    const text = await res.text();
    if (text.includes("registration token")) return false; // malformed / stale token
  }
  return true; // other errors (quota, 5xx): keep the token

}