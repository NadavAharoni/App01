/* ============================================================================
   i18n.js — every user-visible string in App01 lives here. Nowhere else.
   ----------------------------------------------------------------------------
   RULE: adding UI text means adding a key here and referencing it from the
   markup with data-i18n="key". Never hardcode a sentence in index.html and
   never build one in JS. Both dictionaries must have the same key set.

   Loaded BLOCKING from <head> so the dictionary and the correct dir/lang are
   in place before first paint — a Hebrew visitor must not see an English LTR
   frame flash past. That is also why this is a .js file and not a .json one
   fetched at runtime: a fetch is asynchronous by definition.
   ========================================================================= */

window.I18N_LANGS = {
  en: { dir: "ltr", label: "EN",    name: "English" },
  he: { dir: "rtl", label: "עברית", name: "Hebrew"  },
};

window.I18N = {
  en: {
    "meta.title": "App01 — an example cloud app",

    "nav.features":    "Features",
    "nav.stack":       "Stack",
    "nav.dashboard":   "Dashboard",
    "nav.signin":      "Sign in",
    "nav.signup":      "Sign up",
    "nav.signout":     "Sign out",
    "nav.open_menu":   "Open menu",
    "nav.lang_switch": "Change language",

    "hero.badge_demo":    "DEMO",
    "hero.badge_text":    "Example app",
    "hero.title_lead":    "An example app, running",
    "hero.title_mid":     "in the cloud",
    "hero.title_accent":  "for almost nothing.",
    "hero.tagline":       "It signs you in, keeps your data in a real database, and lives at a " +
                          "public URL — the parts every app needs, already working.",
    "hero.line_out":      "Create an account and have a look around.",
    "hero.line_in":       "You are signed in — open your dashboard to see what the app knows about you.",
    "hero.cta_register":  "Create an account",
    "hero.cta_dashboard": "Open your dashboard",
    "hero.cta_inside":    "See what is inside",
    "hero.mock_url":      "app01-xxxx.run.app",

    "features.heading":  "The boring parts, already working",
    "features.sub":      "Auth, database and deployment are solved. You start at the interesting part.",
    "features.auth_t":   "Authentication",
    "features.auth_d":   "Sign in with Google, or with email and password. The session is a signed " +
                         "JWT in an HttpOnly cookie, never a token sitting in local storage.",
    "features.db_t":     "Managed Postgres",
    "features.db_d1":    "A real Neon database with a",
    "features.db_d2":    "table created on startup. Scales to zero while nobody is looking.",
    "features.deploy_t": "Deploys to Cloud Run",
    "features.deploy_d": "Containerised, capped at one instance, scaling to zero. A live demo costs " +
                         "cents a month, and the whole thing stays yours.",

    "stack.heading":    "Small enough to read in one sitting",
    "stack.body":       "Under a thousand lines of Python across six files. No framework layered on " +
                        "the framework, no generated code you are afraid to touch. Open it, read it, change it.",
    "stack.item1":      "FastAPI and async SQLAlchemy",
    "stack.item2":      "Neon Postgres over asyncpg",
    "stack.item3":      "Google OAuth 2.0, identity scopes only",
    "stack.item4":      "Tailwind from a CDN, so there is no build step",
    "stack.code_local": "# run it locally",
    "stack.code_ship":  "# ship it — a push to main builds and deploys",

    "cta.heading": "Try the sign-in flow",
    "cta.body":    "Register with an email or a Google account and see the whole round trip — it " +
                   "takes about a minute.",
    "cta.button":  "Create an account",

    "dash.email":           "Email",
    "dash.username":        "Username",
    "dash.userid":          "User ID",
    "dash.provider":        "Auth provider",
    "dash.provider_google": "Google account",
    "dash.provider_local":  "Local account",
    "dash.empty":           "—",
    "dash.placeholder":     "This is where your app goes. Ask Claude Code for the first feature.",

    "footer.tagline": "App01 — a starter template",
    "footer.stack":   "FastAPI · Neon Postgres · Cloud Run",

    "auth.title_login":     "Welcome back",
    "auth.title_register":  "Create your account",
    "auth.close":           "Close",
    "auth.google":          "Continue with Google",
    "auth.or":              "or",
    "auth.tab_login":       "Sign in",
    "auth.tab_register":    "Sign up",
    "auth.label_email":     "Email",
    "auth.label_password":  "Password",
    "auth.label_username":  "Username",
    "auth.ph_email":        "you@example.com",
    "auth.ph_password":     "••••••••",
    "auth.ph_username":     "cooluser",
    "auth.ph_password_new": "min 8 characters",
    "auth.submit_login":    "Sign in",
    "auth.submit_register": "Create account",

    /* Keys matching the `detail` codes returned by routers/auth.py. */
    "err.email_taken":         "Email already registered",
    "err.username_taken":      "Username already taken",
    "err.invalid_credentials": "Invalid credentials",
    "err.google_exchange":     "Could not complete Google sign-in",
    "err.google_userinfo":     "Could not read your Google profile",
    "err.google_no_email":     "That Google account has no email address",
    "err.network":             "Network error. Please try again.",
    "err.generic":             "Something went wrong",
  },

  /* --------------------------------------------------------------------------
     Hebrew. Written as Hebrew rather than transliterated English: sentences are
     restructured where a literal rendering would read like a translation.
     Product and technology names (FastAPI, Neon, Cloud Run, JWT, cookie) stay
     in Latin script, which is how Israeli developers actually write them.
     Phrasing leans on impersonal forms ("אפשר לפתוח", "פותחים, קוראים") because
     Hebrew has no gender-neutral second person and the alternative is choosing
     a gender for every visitor.
     -------------------------------------------------------------------------- */
  he: {
    "meta.title": "App01 — אפליקציית ענן לדוגמה",

    "nav.features":    "יכולות",
    "nav.stack":       "הטכנולוגיה",
    "nav.dashboard":   "אזור אישי",
    "nav.signin":      "התחברות",
    "nav.signup":      "הרשמה",
    "nav.signout":     "התנתקות",
    "nav.open_menu":   "פתיחת תפריט",
    "nav.lang_switch": "החלפת שפה",

    "hero.badge_demo":    "דמו",
    "hero.badge_text":    "אפליקציה לדוגמה",
    "hero.title_lead":    "אפליקציה לדוגמה, שרצה",
    "hero.title_mid":     "בענן",
    "hero.title_accent":  "כמעט בחינם.",
    "hero.tagline":       "היא מזהה אותך, שומרת את הנתונים בבסיס נתונים אמיתי, ויושבת על כתובת " +
                          "אינטרנט ציבורית — כל מה שכל אפליקציה צריכה, כבר עובד.",
    "hero.line_out":      "אפשר לפתוח חשבון ולהסתכל מסביב.",
    "hero.line_in":       "החיבור בוצע — אפשר להיכנס לאזור האישי ולראות מה האפליקציה יודעת עליך.",
    "hero.cta_register":  "פתיחת חשבון",
    "hero.cta_dashboard": "לאזור האישי",
    "hero.cta_inside":    "מה יש בפנים",
    "hero.mock_url":      "app01-xxxx.run.app",

    "features.heading":  "החלקים המשעממים, כבר עובדים",
    "features.sub":      "הזדהות, בסיס נתונים ופריסה — פתורים. מתחילים מהחלק המעניין.",
    "features.auth_t":   "הזדהות",
    "features.auth_d":   "כניסה עם Google, או עם אימייל וסיסמה. ה-session הוא JWT חתום בתוך " +
                         "cookie מסוג HttpOnly, ולא טוקן ששוכב ב-local storage.",
    "features.db_t":     "Postgres מנוהל",
    "features.db_d1":    "בסיס נתונים אמיתי של Neon, עם טבלת",
    "features.db_d2":    "שנוצרת כשהאפליקציה עולה. מתכווץ לאפס כשאף אחד לא מסתכל.",
    "features.deploy_t": "פריסה ל-Cloud Run",
    "features.deploy_d": "בקונטיינר, מוגבל למכונה אחת, מתכווץ לאפס. דמו חי עולה אגורות בחודש, " +
                         "והכול נשאר שלך.",

    "stack.heading":    "קטן מספיק כדי לקרוא בישיבה אחת",
    "stack.body":       "פחות מאלף שורות Python בשישה קבצים. בלי פריימוורק על גבי פריימוורק, בלי " +
                        "קוד מגונרט שמפחיד לגעת בו. פותחים, קוראים, משנים.",
    "stack.item1":      "FastAPI ו-SQLAlchemy אסינכרוני",
    "stack.item2":      "Neon Postgres מעל asyncpg",
    "stack.item3":      "Google OAuth 2.0, הרשאות זיהוי בלבד",
    "stack.item4":      "Tailwind מ-CDN, כך שאין שלב build",
    "stack.code_local": "# הרצה מקומית",
    "stack.code_ship":  "# פריסה — push ל-main בונה ומעלה לאוויר",

    "cta.heading": "כדאי לנסות את תהליך ההתחברות",
    "cta.body":    "נרשמים עם אימייל או עם חשבון Google ורואים את כל המסלול — זה לוקח בערך דקה.",
    "cta.button":  "פתיחת חשבון",

    "dash.email":           "אימייל",
    "dash.username":        "שם משתמש",
    "dash.userid":          "מזהה משתמש",
    "dash.provider":        "שיטת הזדהות",
    "dash.provider_google": "חשבון Google",
    "dash.provider_local":  "חשבון מקומי",
    "dash.empty":           "—",
    "dash.placeholder":     "כאן נכנסת האפליקציה שלך. אפשר לבקש מ-Claude Code את הפיצ׳ר הראשון.",

    "footer.tagline": "App01 — תבנית התחלה",
    "footer.stack":   "FastAPI · Neon Postgres · Cloud Run",

    "auth.title_login":     "טוב לראות אותך שוב",
    "auth.title_register":  "פתיחת חשבון חדש",
    "auth.close":           "סגירה",
    "auth.google":          "המשך עם Google",
    "auth.or":              "או",
    "auth.tab_login":       "התחברות",
    "auth.tab_register":    "הרשמה",
    "auth.label_email":     "אימייל",
    "auth.label_password":  "סיסמה",
    "auth.label_username":  "שם משתמש",
    "auth.ph_email":        "you@example.com",
    "auth.ph_password":     "••••••••",
    "auth.ph_username":     "cooluser",
    "auth.ph_password_new": "לפחות 8 תווים",
    "auth.submit_login":    "התחברות",
    "auth.submit_register": "פתיחת חשבון",

    "err.email_taken":         "כתובת האימייל הזו כבר רשומה",
    "err.username_taken":      "שם המשתמש הזה כבר תפוס",
    "err.invalid_credentials": "אימייל או סיסמה שגויים",
    "err.google_exchange":     "ההתחברות מול Google לא הושלמה",
    "err.google_userinfo":     "לא הצלחנו לקרוא את הפרופיל שלך מ-Google",
    "err.google_no_email":     "לחשבון ה-Google הזה אין כתובת אימייל",
    "err.network":             "שגיאת רשת. אפשר לנסות שוב.",
    "err.generic":             "משהו השתבש",
  },
};

/* ============================== runtime ================================== */

window.I18N_STORAGE_KEY = "app01.lang";
window.I18N_DEFAULT = "en";

/* Which language to show. Order: an explicit past choice, then the browser's
   preference list, then English. `iw` is the legacy ISO code for Hebrew and is
   still emitted by some browsers, so it maps to `he`. */
function i18nPickLang() {
  var supported = Object.keys(window.I18N_LANGS);
  try {
    var saved = localStorage.getItem(window.I18N_STORAGE_KEY);
    if (saved && supported.indexOf(saved) !== -1) return saved;
  } catch (e) { /* localStorage throws in some privacy modes; fall through */ }

  var prefs = navigator.languages || [navigator.language || ""];
  for (var i = 0; i < prefs.length; i++) {
    var base = String(prefs[i]).toLowerCase().split("-")[0];
    if (base === "iw") base = "he";
    if (supported.indexOf(base) !== -1) return base;
  }
  return window.I18N_DEFAULT;
}

window.i18nLang = i18nPickLang();

/* Set lang/dir on <html> the moment this script runs — during <head> parsing,
   before any of <body> is painted. Without this the RTL flip would be visible. */
function i18nApplyDir() {
  var meta = window.I18N_LANGS[window.i18nLang] || window.I18N_LANGS.en;
  document.documentElement.lang = window.i18nLang;
  document.documentElement.dir = meta.dir;
}
i18nApplyDir();

/* Look up a key. Falls back to English, then to the key itself, so a missing
   translation degrades to readable text instead of a blank element. */
function t(key) {
  var dict = window.I18N[window.i18nLang] || window.I18N.en;
  if (Object.prototype.hasOwnProperty.call(dict, key)) return dict[key];
  if (Object.prototype.hasOwnProperty.call(window.I18N.en, key)) return window.I18N.en[key];
  return key;
}

/* Attributes that carry copy: selector -> dataset key -> attribute to set. */
var I18N_ATTRS = [
  { sel: "[data-i18n-placeholder]", ds: "i18nPlaceholder", attr: "placeholder" },
  { sel: "[data-i18n-aria-label]",  ds: "i18nAriaLabel",   attr: "aria-label"  },
];

function applyI18n() {
  i18nApplyDir();
  document.title = t("meta.title");

  document.querySelectorAll("[data-i18n]").forEach(function (el) {
    el.textContent = t(el.dataset.i18n);
  });

  I18N_ATTRS.forEach(function (a) {
    document.querySelectorAll(a.sel).forEach(function (el) {
      el.setAttribute(a.attr, t(el.dataset[a.ds]));
    });
  });

  // Mark the active language button so the switcher shows where you are.
  document.querySelectorAll("[data-lang]").forEach(function (el) {
    var meta = window.I18N_LANGS[el.dataset.lang];
    // Each button is labelled in its own language and is deliberately NOT translated: a Hebrew
    // speaker looking for Hebrew scans for "עברית", not for whatever the current UI calls it.
    if (meta) el.textContent = meta.label;
    var on = el.dataset.lang === window.i18nLang;
    el.classList.toggle("lang-active", on);
    el.setAttribute("aria-current", on ? "true" : "false");
  });

  // Anything rendered from data rather than from markup has to be redrawn.
  if (typeof window.renderAuth === "function") window.renderAuth();
  if (typeof window.renderDashboard === "function") window.renderDashboard();
  if (typeof window.syncAuthTitle === "function") window.syncAuthTitle();
}

function setLang(lang) {
  if (!window.I18N_LANGS[lang]) return;
  window.i18nLang = lang;
  try { localStorage.setItem(window.I18N_STORAGE_KEY, lang); } catch (e) { /* ignore */ }
  applyI18n();
}
