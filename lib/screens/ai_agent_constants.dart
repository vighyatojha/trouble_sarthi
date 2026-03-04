// ai_agent_constants.dart
// ignore_for_file: prefer_single_quotes

const String kAiSystemPrompt =
    "You are Sarthi, a friendly AI support agent for the Trouble Sarthi app — "
    "an on-demand home services platform in India. "
    "Only answer questions related to the Trouble Sarthi app. "
    "App features include: booking helpers (plumbers, electricians, carpenters, cleaners), "
    "UPI escrow payments, mutual ratings, in-booking messaging, cancellations, refunds, "
    "profile completion, trust scores, emergency safety, and app navigation. "
    "Always respond warmly and concisely. Use numbered lists for step-by-step instructions. "
    "If the issue needs human support, end with: "
    "\"Need more help? Tap Support → Live Chat to speak with our team.\"";

// ── Main menu ────────────────────────────────────────────────────────────────
const List<Map<String, String>> kMainMenuItems = [
  {"id": "bookings", "label": "📦  My Bookings"},
  {"id": "payments", "label": "💳  Payments & Refunds"},
  {"id": "account",  "label": "👤  Account & Profile"},
  {"id": "safety",   "label": "🛡️  Safety & Trust"},
  {"id": "app",      "label": "📱  App Help"},
  {"id": "human",    "label": "💬  Talk to a Human Agent"},
];

// ── Sub-menus ────────────────────────────────────────────────────────────────
const Map<String, List<Map<String, String>>> kSubMenuItems = {
  "bookings": [
    {"id": "book_how",        "label": "How do I book a service?"},
    {"id": "book_cancel",     "label": "Cancel my booking"},
    {"id": "book_noshow",     "label": "My helper didn't show up"},
    {"id": "book_reschedule", "label": "Reschedule a booking"},
    {"id": "book_status",     "label": "Check booking status"},
    {"id": "book_message",    "label": "Message my helper"},
  ],
  "payments": [
    {"id": "pay_escrow",   "label": "How does UPI escrow work?"},
    {"id": "pay_refund",   "label": "Request a refund"},
    {"id": "pay_cash",     "label": "Cash payment questions"},
    {"id": "pay_history",  "label": "View payment history"},
    {"id": "pay_failed",   "label": "Payment failed / not received"},
  ],
  "account": [
    {"id": "acc_profile",  "label": "Update my profile"},
    {"id": "acc_photo",    "label": "Change profile photo"},
    {"id": "acc_password", "label": "Change my password"},
    {"id": "acc_address",  "label": "Update my address"},
    {"id": "acc_trust",    "label": "My trust score"},
    {"id": "acc_rating",   "label": "How ratings work"},
  ],
  "safety": [
    {"id": "safe_trust",  "label": "What is a Trust Score?"},
    {"id": "safe_report", "label": "Report a helper"},
    {"id": "safe_female", "label": "Female safety features"},
    {"id": "safe_sos",    "label": "Emergency / SOS help"},
  ],
  "app": [
    {"id": "app_notif",   "label": "Notification settings"},
    {"id": "app_lang",    "label": "Language & region"},
    {"id": "app_bug",     "label": "Report a bug"},
    {"id": "app_version", "label": "App version info"},
  ],
};

// ── Answers ──────────────────────────────────────────────────────────────────
const Map<String, String> kAnswers = {
  "book_how":
  "Booking a Sarthi helper is easy! 🛠️\n\n"
      "1. Open the Home screen\n"
      "2. Select your service category (Plumber, Electrician, etc.)\n"
      "3. Browse nearby helpers — check ratings & Trust Score\n"
      "4. Choose a date & time slot\n"
      "5. Tap \"Book Now\" — the helper is notified instantly!\n\n"
      "You can book immediately or schedule up to 7 days ahead.",

  "book_cancel":
  "You can cancel FREE up to 30 minutes before the scheduled time. ✅\n\n"
      "To cancel:\n"
      "1. Go to Activity screen\n"
      "2. Tap your active booking\n"
      "3. Tap \"Cancel Booking\"\n\n"
      "Late cancellations (within 30 min) may attract a small Rs.20–50 fee.",

  "book_noshow":
  "Sorry your helper didn't show up! 😔\n\n"
      "1. Wait 10–15 minutes past scheduled time\n"
      "2. Message your helper via in-booking chat\n"
      "3. Still no response? Activity → booking → \"Report Issue\"\n"
      "4. Our team contacts you within 15 minutes\n\n"
      "Confirmed no-shows get a FULL refund and free rebook.",

  "book_reschedule":
  "To reschedule a booking:\n\n"
      "1. Go to Activity screen\n"
      "2. Tap your upcoming booking\n"
      "3. Tap \"Reschedule\"\n"
      "4. Pick a new date and time slot\n"
      "5. Confirm — the helper is notified automatically\n\n"
      "Free rescheduling if done more than 2 hours before the booking time.",

  "book_status":
  "To check your booking status:\n\n"
      "1. Tap Activity (bottom nav or Profile → Activity)\n"
      "2. Bookings are sorted latest first\n"
      "3. Status badges: Pending 🟡 · Ongoing 🔵 · Completed 🟢 · Cancelled 🔴\n\n"
      "Tap any booking for full details — helper info, ETA, and payment status.",

  "book_message":
  "You can message your helper directly! 💬\n\n"
      "1. Go to Activity screen\n"
      "2. Tap your active booking\n"
      "3. Tap the Chat icon (top right)\n"
      "4. Send your message!\n\n"
      "Use chat to share your address, ask for ETA, or clarify job details.",

  "pay_escrow":
  "UPI payments on Trouble Sarthi are 100% safe thanks to Escrow! 🔐\n\n"
      "• You pay via UPI → money is held securely in escrow\n"
      "• The helper cannot receive the money yet\n"
      "• After the job is done, YOU confirm completion\n"
      "• Only then is money released to the helper\n\n"
      "This fully protects you from bad or incomplete service.",

  "pay_refund":
  "Refund Policy 💰\n\n"
      "✅ Full refund: helper no-show or service not started\n"
      "✅ Partial refund: service only partially completed\n"
      "❓ Dispute refund: unsatisfied with completed work\n\n"
      "To request:\n"
      "• Activity → booking → \"Raise Dispute\"\n"
      "• Our team reviews within 48 hours\n"
      "• UPI refunds take 3–5 business days.",

  "pay_cash":
  "Cash payments are simple and direct! 💵\n\n"
      "• Pay the helper in cash after job completion\n"
      "• The helper marks it in-app\n"
      "• You confirm — it appears in payment history\n\n"
      "Cash payments are NOT held in escrow. Raise disputes within 24 hours.",

  "pay_history":
  "To view your payment history:\n\n"
      "1. Go to Profile → Payments\n"
      "2. See All Payments or filter by \"In Escrow\"\n"
      "3. Each card shows: service, amount, mode (Cash/UPI), and status\n\n"
      "Statuses: In Escrow 🔵 · Released ✅ · Refunded 🟣 · Cash Paid ✅",

  "pay_failed":
  "Payment failed or not received?\n\n"
      "For UPI failures:\n"
      "1. Check your bank app — if money was deducted wait 30 min for auto-reversal\n"
      "2. Not reversed in 2 hours? Contact support with your booking ID\n\n"
      "For helper not receiving payment:\n"
      "• Escrow releases only after YOU confirm completion\n"
      "• Go to your booking → tap \"Confirm Completion\"",

  "acc_profile":
  "Updating your profile is easy! ✏️\n\n"
      "1. Go to Profile tab\n"
      "2. Tap \"Edit Profile\" or the pencil icon on your photo\n"
      "3. Update: Name, Phone, DOB, Emergency Contact, Gender\n"
      "4. Tap \"Save Changes\"\n\n"
      "💡 100% profile completion boosts your Trust Score!",

  "acc_photo":
  "To change your profile photo:\n\n"
      "1. Profile → Edit Profile\n"
      "2. Tap the camera icon on your current photo\n"
      "3. Choose Camera or Gallery\n"
      "4. Crop and confirm\n"
      "5. Tap \"Save Changes\" — your photo updates instantly!",

  "acc_password":
  "To change your password:\n\n"
      "1. Profile → Change Password\n"
      "2. Enter your current password\n"
      "3. Enter new password (8+ chars, uppercase & number required)\n"
      "4. Confirm new password\n"
      "5. Tap \"Update Password\"\n\n"
      "Forgot your password? Tap \"Forgot Password\" on the Login screen.",

  "acc_address":
  "To update your home address:\n\n"
      "1. Profile → Saved Addresses\n"
      "2. Fill in: House/Flat, Building, Street, Landmark, City, State, Pincode\n"
      "3. Tap \"Save Address\"\n\n"
      "Your saved address is used as the default service location.",

  "acc_trust":
  "Your Trust Score is Trouble Sarthi's reliability rating! 🛡️\n\n"
      "Calculated from:\n"
      "• Profile completion %\n"
      "• Ratings received from helpers\n"
      "• Booking & cancellation history\n"
      "• Account verification status\n\n"
      "Higher Trust Score = priority matching with top helpers.",

  "acc_rating":
  "Trouble Sarthi uses a Mutual Rating System ⭐\n\n"
      "After every completed booking:\n"
      "• You rate the helper: quality, punctuality & behaviour\n"
      "• The helper rates you: clear instructions & respectful behaviour\n\n"
      "Ratings are submitted independently — fully fair.\n"
      "You have 24 hours after completion to rate.",

  "safe_trust":
  "Trust Score is our reliability metric for every user and helper! 🛡️\n\n"
      "For helpers: background check, skill verification, average rating, completed jobs.\n\n"
      "For users: profile completion, ratings from helpers, booking history.\n\n"
      "A score above 4.5 ⭐ earns a \"Verified\" badge.",

  "safe_report":
  "To report a helper:\n\n"
      "1. Activity → your completed/ongoing booking\n"
      "2. Scroll down → tap \"Report Helper\"\n"
      "3. Select a reason: Unprofessional, Late, Rude, Unsafe, Other\n"
      "4. Add details and submit\n\n"
      "Our team reviews all reports within 24 hours.",

  "safe_female":
  "Female Safety Features on Trouble Sarthi 💜\n\n"
      "• Request female helpers when booking\n"
      "• Trouble Sarthi Safety Line dispatches female helpers + police\n"
      "• Women Helpline: 1091 (national)\n"
      "• SOS button on every active booking screen\n"
      "• All female helpers are background-verified\n\n"
      "Go to Support → Emergency Helplines for all safety contacts.",

  "safe_sos":
  "If you are in immediate danger, call 112 NOW! 🚨\n\n"
      "In the app: Support → Emergency Helplines\n\n"
      "• 🚔 Police: 100\n"
      "• 🚑 Ambulance: 108\n"
      "• 🔥 Fire: 101\n"
      "• 👩 Women Helpline: 1091\n"
      "• 🛡️ Trouble Sarthi Safety Line: dispatches helpers & police\n\n"
      "Your safety is our top priority. Please stay safe! 💜",

  "app_notif":
  "To manage notifications:\n\n"
      "1. Profile → Settings (gear icon top right)\n"
      "2. Go to NOTIFICATIONS section\n"
      "3. Toggle Push Notifications and Email Alerts\n\n"
      "You can also manage in phone Settings → Apps → Trouble Sarthi.",

  "app_lang":
  "To change language:\n\n"
      "1. Profile → Settings\n"
      "2. Go to LOCALIZATION section\n"
      "3. Tap Language and select your preferred option\n\n"
      "Currently supported: English, Hindi, Gujarati. More coming soon!",

  "app_bug":
  "To report a bug:\n\n"
      "1. Support → Email Support\n"
      "2. Subject: Bug Report — [brief description]\n"
      "3. Include: device model, OS version, app version, steps to reproduce\n\n"
      "Or use Support → Live Chat for urgent issues.\n"
      "We investigate all reports within 24–48 hours. Thank you!",

  "app_version":
  "App version info:\n\n"
      "Current version: 2.4.1 (Indigo)\n\n"
      "Check your version: Profile → Settings → scroll to the bottom.\n\n"
      "To update: visit App Store or Play Store and tap Update.",
};