// worker/src/index.ts
// Push-notification Worker for Trouble Sarthi (customers) and Sarthi Kendra (helpers).
//
// The apps call   POST /notify   with   Authorization: Bearer <Firebase ID token>
// and a body of   { event: "job_created" | "pitch" | "booking", jobId?, bookingId? }.
//
// The Worker NEVER trusts the body for recipients or text. It reads the real
// documents from Firestore, checks the caller is part of them, decides who
// should be told, sends the push (FCM) and writes the in-app notification.
// Every event is sent at most once (it records what it already sent).

import { Doc, Env, Firestore, Push, Write, quoteSegment, sendPush, verifyIdToken } from "./google";
import { km, nearbyCells } from "./geo";
import { MsgKey, render, slotText } from "./messages";
import { SUBCATEGORIES } from "./catalog";

const RADIUS_KM = 5;
const MAX_HELPERS_PER_JOB = 35; // free Workers allow 50 outgoing requests per call
const LOCATION_MAX_AGE_MS = 14 * 864e5;
const PITCH_PUSH_GAP_MS = 45_000;

type Role = "user" | "helper";

// ─── helpers ────────────────────────────────────────────────────────────────

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

const NAME_TO_ID = new Map<string, string>();
for (const s of SUBCATEGORIES) for (const n of [s.en, s.id, ...s.aliases]) NAME_TO_ID.set(n.trim().toLowerCase(), s.id);

function helperOffers(h: Record<string, unknown>, subId: string): boolean {
  const list = Array.isArray(h.services) ? h.services : [];
  return list.some((s) => typeof s === "string" && NAME_TO_ID.get(s.trim().toLowerCase()) === subId);
}

const first = (name: unknown) => String(name ?? "").trim().split(/\s+/)[0] || "";
const ms = (v: unknown) => (v instanceof Date ? v.getTime() : 0);

/** Newest FCM token of this person for the given app, from push_tokens/{uid}. */
function latestToken(tokensDoc: Doc | null | undefined, app: Role): string | null {
  const tokens = (tokensDoc?.data.tokens ?? {}) as Record<string, { app?: string; updatedAt?: unknown }>;
  let best: string | null = null;
  let bestAt = -1;
  for (const [t, info] of Object.entries(tokens)) {
    if (info?.app !== app) continue;
    const at = ms(info.updatedAt);
    if (at > bestAt) { best = t; bestAt = at; }
  }
  return best;
}

interface Recipient {
  uid: string;
  role: Role;
  key: MsgKey;
  vars: Record<string, string | number>;
  data: Record<string, string>;
  itemId: string;          // in-app notification doc id (same id = overwrite, no duplicates)
  collapseKey?: string;
}

/**
 * Sends pushes and writes in-app notifications for a list of recipients.
 * Uses 1 request to load profiles+tokens, 1 per push, 1 commit.
 */
async function deliver(env: Env, fs: Firestore, list: Recipient[], extraWrites: Write[] = []): Promise<number> {
  if (list.length === 0) {
    await fs.commit(extraWrites);
    return 0;
  }
  const paths: string[] = [];
  for (const r of list) {
    paths.push(`${r.role === "helper" ? "helpers" : "users"}/${r.uid}`, `push_tokens/${r.uid}`);
  }
  const docs = await fs.getAll([...new Set(paths)]);
  const writes: Write[] = [...extraWrites];
  const deadTokens = new Map<string, string[]>();
  let sent = 0;

  await Promise.all(list.map(async (r) => {
    const profile = docs.get(`${r.role === "helper" ? "helpers" : "users"}/${r.uid}`);
    const msg = render(r.key, profile?.data.lang, r.vars);
    const data = { type: r.key, app: r.role, ...r.data };
    writes.push({
      path: `notifications/${r.uid}/items/${r.itemId}`,
      fields: { ...data, title: msg.title, body: msg.body, read: false },
      serverTime: ["createdAt"],
    });
    const token = latestToken(docs.get(`push_tokens/${r.uid}`), r.role);
    if (!token) return;
    const push: Push = {
      token,
      title: msg.title,
      body: msg.body,
      data,
      channelId: r.role === "helper" ? "sarthi_kendra_channel" : "trouble_sarthi_channel",
      collapseKey: r.collapseKey,
    };
    const alive = await sendPush(env, push);
    if (alive) sent++;
    else deadTokens.set(r.uid, [...(deadTokens.get(r.uid) ?? []), token]);
  }));

  for (const [uid, tokens] of deadTokens) {
    writes.push({ path: `push_tokens/${uid}`, fields: {}, mask: tokens.map((t) => `tokens.${quoteSegment(t)}`) });
  }
  await fs.commit(writes);
  return sent;
}

// ─── Event: a customer posted a request ─────────────────────────────────────

async function onJobCreated(env: Env, fs: Firestore, uid: string, jobId: string) {
  const job = await fs.get(`jobs/${jobId}`);
  if (!job) throw new HttpError(404, "job not found");
  const j = job.data;
  if (j.customerId !== uid) throw new HttpError(403, "not your request");
  if (j.status !== "open") return { notifiedCount: 0, skipped: "not open" };
  if (j.notifiedAt) return { notifiedCount: Number(j.notifiedCount ?? 0), skipped: "already notified" };
  if (Date.now() - ms(j.createdAt) > 30 * 60e3) return { notifiedCount: 0, skipped: "too old" };

  const loc = await fs.get(`jobs/${jobId}/private/location`);
  const lat = Number(loc?.data.lat), lng = Number(loc?.data.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new HttpError(400, "no location");

  // 1. Helpers whose last position is within 5 km.
  const locs = await fs.query("helper_locations", [{ field: "geohash5", op: "IN", value: nearbyCells(lat, lng) }]);
  const near = new Map<string, number>();
  for (const l of locs) {
    if (l.id === uid) continue;
    if (Date.now() - ms(l.data.updatedAt) > LOCATION_MAX_AGE_MS) continue;
    const d = km(lat, lng, Number(l.data.lat), Number(l.data.lng));
    if (d <= RADIUS_KM) near.set(l.id, Math.round(d * 10) / 10);
  }

  // 2. Approved, available, and offering this service.
  const profiles = await fs.getAll([...near.keys()].map((id) => `helpers/${id}`));
  const eligible = [...near.entries()]
    .filter(([id]) => {
      const h = profiles.get(`helpers/${id}`)?.data;
      return !!h && h.kycStatus === "approved" && h.isOnline === true && h.isBlocked !== true
        && helperOffers(h, String(j.subcategoryId));
    })
    .sort((a, b) => a[1] - b[1])
    .slice(0, MAX_HELPERS_PER_JOB);

  const slot = slotText(j.slot as { type: string; startMs: number; endMs: number });
  const recipients: Recipient[] = eligible.map(([helperId, distance]) => ({
    uid: helperId,
    role: "helper",
    key: "new_request",
    vars: { service: String(j.serviceName), distance, slot },
    data: { jobId },
    itemId: `job_${jobId}`,
    collapseKey: `job_${jobId}`,
  }));

  const mark: Write = {
    path: `jobs/${jobId}`,
    fields: { notifiedCount: recipients.length },
    mask: ["notifiedCount", "notifiedAt"],
    serverTime: ["notifiedAt"],
  };
  await deliver(env, fs, recipients, [mark]);
  return { notifiedCount: recipients.length };
}

// ─── Event: a helper sent or changed a price ────────────────────────────────

async function onPitch(env: Env, fs: Firestore, uid: string, jobId: string) {
  const docs = await fs.getAll([`jobs/${jobId}`, `jobs/${jobId}/pitches/${uid}`]);
  const job = docs.get(`jobs/${jobId}`);
  const pitch = docs.get(`jobs/${jobId}/pitches/${uid}`);
  if (!job || !pitch) throw new HttpError(404, "not found");
  if (pitch.data.status !== "active") return { skipped: "pitch not active" };
  if (job.data.status !== "open") return { skipped: "job not open" };
  if (Date.now() - ms(job.data.lastPitchPushAt) < PITCH_PUSH_GAP_MS) return { skipped: "throttled" };

  const active = await fs.query("pitches", [{ field: "status", op: "EQUAL", value: "active" }], `jobs/${jobId}`);
  const count = active.length;
  await deliver(env, fs, [{
    uid: String(job.data.customerId),
    role: "user",
    key: "new_pitch",
    vars: { count, service: String(job.data.serviceName) },
    data: { jobId },
    itemId: `pitches_${jobId}`,
    collapseKey: `pitches_${jobId}`,
  }], [{
    path: `jobs/${jobId}`, fields: {}, mask: ["lastPitchPushAt"], serverTime: ["lastPitchPushAt"],
  }]);
  return { count };
}

// ─── Event: a booking changed ───────────────────────────────────────────────

async function onBooking(env: Env, fs: Firestore, uid: string, bookingId: string) {
  const b = await fs.get(`bookings/${bookingId}`);
  if (!b) throw new HttpError(404, "booking not found");
  const d = b.data;
  const customerId = String(d.customerId), helperId = String(d.helperId);
  if (uid !== customerId && uid !== helperId) throw new HttpError(403, "not your booking");

  const already = (d.notified ?? {}) as Record<string, boolean>;
  const vars = {
    helper: first(d.helperName), customer: first(d.customerName), service: String(d.serviceName),
    amount: Number(d.agreedAmount), slot: slotText(d.slot as { type: string; startMs: number; endMs: number }),
    reason: String(d.cancelReason ?? ""), method: d.paymentMethod === "upi" ? "UPI" : "cash",
  };
  const data = { bookingId, jobId: String(d.jobId) };
  const toCustomer = (key: MsgKey, tag: string): Recipient =>
    ({ uid: customerId, role: "user", key, vars, data, itemId: `${bookingId}_${tag}`, collapseKey: `booking_${bookingId}` });
  const toHelper = (key: MsgKey, tag: string): Recipient =>
    ({ uid: helperId, role: "helper", key, vars, data, itemId: `${bookingId}_${tag}`, collapseKey: `booking_${bookingId}` });

  const recipients: Recipient[] = [];
  const done: string[] = [];
  const once = (tag: string, list: Recipient[]) => {
    if (already[tag]) return;
    done.push(tag);
    recipients.push(...list);
  };

  switch (d.status) {
    case "confirmed": {
      // The chosen helper, plus everyone else who pitched.
      const others = (await fs.query("pitches", [{ field: "status", op: "EQUAL", value: "active" }], `jobs/${d.jobId}`))
        .map((p) => p.id)
        .filter((id) => id !== helperId)
        .slice(0, MAX_HELPERS_PER_JOB - 1);
      once("confirmed", [
        toHelper("pitch_accepted", "confirmed"),
        ...others.map((h): Recipient => ({
          uid: h, role: "helper", key: "pitch_not_selected", vars, data: { jobId: String(d.jobId) },
          itemId: `job_${d.jobId}`, collapseKey: `job_${d.jobId}`,
        })),
      ]);
      break;
    }
    case "on_the_way": once("on_the_way", [toCustomer("status_on_the_way", "on_the_way")]); break;
    case "arrived": once("arrived", [toCustomer("status_arrived", "arrived")]); break;
    case "in_progress": once("in_progress", [toCustomer("status_in_progress", "in_progress")]); break;
    case "work_done": once("work_done", [toCustomer("status_work_done", "work_done")]); break;
    case "completed":
      once("completed", [toCustomer("completed_customer", "completed"), toHelper("completed_helper", "completed")]);
      break;
    case "cancelled":
      once("cancelled", [d.cancelledBy === "helper"
        ? toCustomer("cancelled_by_helper", "cancelled")
        : toHelper("cancelled_by_customer", "cancelled")]);
      break;
  }
  if (d.customerPaidAt && d.status === "work_done") once("paid", [toHelper("customer_paid", "paid")]);

  if (done.length === 0) return { skipped: "nothing new" };
  const mark: Write = {
    path: `bookings/${bookingId}`,
    fields: { notified: Object.fromEntries(done.map((t) => [t, true])) },
    mask: done.map((t) => `notified.${t}`),
  };
  const sent = await deliver(env, fs, recipients, [mark]);
  return { sent, events: done };
}

// ─── Router ─────────────────────────────────────────────────────────────────

const ID = /^[A-Za-z0-9_-]{6,80}$/;

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (req.method === "GET" && url.pathname === "/") return json({ ok: true, service: "sarthi-notify" });
    if (req.method !== "POST" || url.pathname !== "/notify") return json({ error: "not found" }, 404);

    try {
      const auth = req.headers.get("authorization") ?? "";
      if (!auth.startsWith("Bearer ")) throw new HttpError(401, "missing token");
      let uid: string;
      try {
        uid = await verifyIdToken(auth.slice(7), env.FIREBASE_PROJECT_ID);
      } catch {
        throw new HttpError(401, "invalid token");
      }

      const body = (await req.json().catch(() => ({}))) as { event?: string; jobId?: string; bookingId?: string };
      const fs = new Firestore(env);
      switch (body.event) {
        case "job_created":
          if (!ID.test(body.jobId ?? "")) throw new HttpError(400, "jobId");
          return json(await onJobCreated(env, fs, uid, body.jobId!));
        case "pitch":
          if (!ID.test(body.jobId ?? "")) throw new HttpError(400, "jobId");
          return json(await onPitch(env, fs, uid, body.jobId!));
        case "booking":
          if (!ID.test(body.bookingId ?? "")) throw new HttpError(400, "bookingId");
          return json(await onBooking(env, fs, uid, body.bookingId!));
        default:
          throw new HttpError(400, "unknown event");
      }
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      console.error(e);
      return json({ error: "internal" }, 500);
    }
  },
};