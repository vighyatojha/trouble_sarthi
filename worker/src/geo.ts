// worker/src/geo.ts
// Geohash helpers. The apps store a 5-character geohash (cells of about
// 4.9 km × 4.5 km). A 5×5 block of cells around a point covers more than 5 km
// in every direction; exact distance is then checked with haversine.
// Same maths as lib/core/geo.dart in both apps.

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
const CELL_LAT = 180 / 4096; // precision 5 → 12 latitude bits
const CELL_LNG = 360 / 8192; // and 13 longitude bits

export function geohash(lat: number, lng: number, precision = 5): string {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let out = "", bit = 0, ch = 0, even = true;
  while (out.length < precision) {
    if (even) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { ch = (ch << 1) | 1; lngMin = mid; } else { ch <<= 1; lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { ch = (ch << 1) | 1; latMin = mid; } else { ch <<= 1; latMax = mid; }
    }
    even = !even;
    if (++bit === 5) { out += BASE32[ch]; bit = 0; ch = 0; }
  }
  return out;
}

/** The 25 precision-5 cells around a point (Firestore "in" allows up to 30 values). */
export function nearbyCells(lat: number, lng: number): string[] {
  const cLat = Math.floor((lat + 90) / CELL_LAT) * CELL_LAT - 90 + CELL_LAT / 2;
  const cLng = Math.floor((lng + 180) / CELL_LNG) * CELL_LNG - 180 + CELL_LNG / 2;
  const cells = new Set<string>();
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const la = Math.max(-89.99, Math.min(89.99, cLat + dy * CELL_LAT));
      let ln = cLng + dx * CELL_LNG;
      if (ln > 180) ln -= 360;
      if (ln < -180) ln += 360;
      cells.add(geohash(la, ln, 5));
    }
  }
  return [...cells];
}

export function km(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const dLat = r(lat2 - lat1), dLng = r(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(a));
}