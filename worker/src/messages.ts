// worker/src/messages.ts
// Notification text in English, Hindi and Gujarati. {name} is replaced from vars.

export type Lang = "en" | "hi" | "gu";

type Vars = Record<string, string | number>;
type Msg = { title: string; body: string };

// {name} placeholders are filled from vars.
export const TEXT: Record<string, Record<Lang, Msg>> = {
  new_request: {
    en: { title: "New {service} request nearby", body: "{distance} km away · {slot}. Send your price." },
    hi: { title: "पास में नया {service} काम", body: "{distance} किमी दूर · {slot}. अपनी कीमत भेजें।" },
    gu: { title: "નજીકમાં નવું {service} કામ", body: "{distance} કિમી દૂર · {slot}. તમારો ભાવ મોકલો." },
  },
  new_pitch: {
    en: { title: "{count} price quote(s) received", body: "Compare helpers for your {service} request and pick one." },
    hi: { title: "{count} कीमत प्रस्ताव मिले", body: "अपने {service} काम के लिए हेल्पर की तुलना करें और चुनें।" },
    gu: { title: "{count} ભાવ પ્રસ્તાવ મળ્યા", body: "તમારા {service} કામ માટે હેલ્પરની સરખામણી કરો અને પસંદ કરો." },
  },
  pitch_accepted: {
    en: { title: "You got the job! 🎉", body: "{customer} booked you for {service} at ₹{amount}. {slot}." },
    hi: { title: "आपको काम मिल गया! 🎉", body: "{customer} ने {service} के लिए ₹{amount} पर आपको बुक किया। {slot}." },
    gu: { title: "તમને કામ મળ્યું! 🎉", body: "{customer} એ {service} માટે ₹{amount} પર તમને બુક કર્યા. {slot}." },
  },
  pitch_not_selected: {
    en: { title: "Request closed", body: "The customer chose another helper for {service}. Keep pitching!" },
    hi: { title: "काम बंद", body: "ग्राहक ने {service} के लिए दूसरा हेल्पर चुना। प्रस्ताव भेजते रहें!" },
    gu: { title: "કામ બંધ", body: "ગ્રાહકે {service} માટે બીજા હેલ્પર પસંદ કર્યા. પ્રસ્તાવ મોકલતા રહો!" },
  },
  status_on_the_way: {
    en: { title: "{helper} is on the way", body: "Your {service} helper has started travelling." },
    hi: { title: "{helper} रास्ते में हैं", body: "आपके {service} हेल्पर निकल चुके हैं।" },
    gu: { title: "{helper} રસ્તામાં છે", body: "તમારા {service} હેલ્પર નીકળી ગયા છે." },
  },
  status_arrived: {
    en: { title: "{helper} has arrived", body: "Share your 4-digit start code only when the work begins." },
    hi: { title: "{helper} पहुँच गए", body: "काम शुरू होने पर ही अपना 4 अंकों का स्टार्ट कोड बताएं।" },
    gu: { title: "{helper} પહોંચી ગયા", body: "કામ શરૂ થાય ત્યારે જ તમારો 4 અંકનો સ્ટાર્ટ કોડ આપો." },
  },
  status_in_progress: {
    en: { title: "Work started", body: "{helper} has started your {service} job." },
    hi: { title: "काम शुरू", body: "{helper} ने आपका {service} काम शुरू कर दिया है।" },
    gu: { title: "કામ શરૂ", body: "{helper} એ તમારું {service} કામ શરૂ કર્યું છે." },
  },
  status_work_done: {
    en: { title: "Work marked done", body: "Pay ₹{amount} to {helper} by cash or UPI, then confirm in the app." },
    hi: { title: "काम पूरा", body: "{helper} को ₹{amount} नकद या UPI से दें, फिर ऐप में पुष्टि करें।" },
    gu: { title: "કામ પૂર્ણ", body: "{helper} ને ₹{amount} રોકડ અથવા UPI થી આપો, પછી એપમાં પુષ્ટિ કરો." },
  },
  completed_customer: {
    en: { title: "Job completed ✅", body: "How was {helper}? Your rating helps other customers." },
    hi: { title: "काम पूरा ✅", body: "{helper} कैसे रहे? आपकी रेटिंग दूसरों की मदद करती है।" },
    gu: { title: "કામ પૂર્ણ ✅", body: "{helper} કેવા રહ્યા? તમારું રેટિંગ બીજાને મદદ કરે છે." },
  },
  completed_helper: {
    en: { title: "Job completed ✅", body: "₹{amount} recorded for {service}. Rate your customer." },
    hi: { title: "काम पूरा ✅", body: "{service} के लिए ₹{amount} दर्ज। ग्राहक को रेटिंग दें।" },
    gu: { title: "કામ પૂર્ણ ✅", body: "{service} માટે ₹{amount} નોંધાયા. ગ્રાહકને રેટિંગ આપો." },
  },
  customer_paid: {
    en: { title: "Customer says they paid", body: "{customer} paid ₹{amount} by {method}. Confirm when you receive it." },
    hi: { title: "ग्राहक ने भुगतान किया", body: "{customer} ने ₹{amount} {method} से दिए। मिलने पर पुष्टि करें।" },
    gu: { title: "ગ્રાહકે ચુકવણી કરી", body: "{customer} એ ₹{amount} {method} થી આપ્યા. મળે ત્યારે પુષ્ટિ કરો." },
  },
  cancelled_by_helper: {
    en: { title: "Helper cancelled", body: "{helper} cancelled. Pick another quote for your {service} request." },
    hi: { title: "हेल्पर ने रद्द किया", body: "{helper} ने रद्द किया। अपने {service} काम के लिए दूसरा प्रस्ताव चुनें।" },
    gu: { title: "હેલ્પરે રદ કર્યું", body: "{helper} એ રદ કર્યું. તમારા {service} કામ માટે બીજો પ્રસ્તાવ પસંદ કરો." },
  },
  cancelled_by_customer: {
    en: { title: "Booking cancelled", body: "{customer} cancelled the {service} job. Reason: {reason}" },
    hi: { title: "बुकिंग रद्द", body: "{customer} ने {service} काम रद्द किया। कारण: {reason}" },
    gu: { title: "બુકિંગ રદ", body: "{customer} એ {service} કામ રદ કર્યું. કારણ: {reason}" },
  },
  job_no_pitches: {
    en: { title: "No quotes yet", body: "No helper sent a price for {service}. Try another time slot." },
    hi: { title: "कोई प्रस्ताव नहीं", body: "{service} के लिए किसी हेल्पर ने कीमत नहीं भेजी। दूसरा समय चुनें।" },
    gu: { title: "કોઈ પ્રસ્તાવ નથી", body: "{service} માટે કોઈ હેલ્પરે ભાવ મોકલ્યો નથી. બીજો સમય પસંદ કરો." },
  },
  job_expired: {
    en: { title: "Request expired", body: "Your {service} request expired without a booking." },
    hi: { title: "अनुरोध समाप्त", body: "आपका {service} अनुरोध बिना बुकिंग के समाप्त हो गया।" },
    gu: { title: "વિનંતી સમાપ્ત", body: "તમારી {service} વિનંતી બુકિંગ વગર સમાપ્ત થઈ." },
  },
  overdue: {
    en: { title: "Visit overdue", body: "The {service} visit time has passed. Please update the booking or chat." },
    hi: { title: "समय निकल गया", body: "{service} का समय निकल गया। बुकिंग अपडेट करें या चैट करें।" },
    gu: { title: "સમય વીતી ગયો", body: "{service} નો સમય વીતી ગયો. બુકિંગ અપડેટ કરો અથવા ચેટ કરો." },
  },
};

export type MsgKey = keyof typeof TEXT;

export function render(key: MsgKey, lang: unknown, vars: Vars): Msg {
  const l: Lang = lang === "hi" || lang === "gu" ? lang : "en";
  const m = TEXT[key][l] ?? TEXT[key].en;
  const fill = (t: string) => t.replace(/\{(\w+)\}/g, (_, k: string) => (vars[k] !== undefined ? String(vars[k]) : ""));
  return { title: fill(m.title), body: fill(m.body) };
}

/** Human-readable slot text in IST, e.g. "Now" or "Tue 14 Oct, 4–6 PM". */
export function slotText(slot: { type: string; startMs: number; endMs: number }): string {
  if (slot.type === "now") return "Now";
  const fmt = (ms: number, opts: Intl.DateTimeFormatOptions) =>
    new Intl.DateTimeFormat("en-IN", { timeZone: "Asia/Kolkata", ...opts }).format(new Date(ms));
  const day = fmt(slot.startMs, { weekday: "short", day: "numeric", month: "short" });
  const s = fmt(slot.startMs, { hour: "numeric", hour12: true }).replace(/\s?(am|pm)/i, "");
  const e = fmt(slot.endMs, { hour: "numeric", hour12: true }).toUpperCase();
  return `${day}, ${s}–${e}`;
}