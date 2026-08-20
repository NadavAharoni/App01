/* Behavioural test for the bilingual UI, run against a live server with jsdom.
 *
 *   npm install                       # once, installs jsdom
 *   python -m uvicorn main:app --port 8080 &
 *   npm test                          # or: node tests/dom_i18n.test.js
 *
 * Point it somewhere else with APP_BASE, which is how production gets verified:
 *   APP_BASE=https://app01-295433370725.us-east1.run.app npm test
 *
 * It loads the page as actually served, lets the page's own scripts run, and then drives them.
 * That means it covers the real applyI18n/renderAuth/renderDashboard path rather than a
 * reimplementation of it. jsdom computes no CSS, so this proves strings, direction attributes and
 * switching behaviour, and proves nothing about rendered layout — check that in a real browser.
 */
const { JSDOM, VirtualConsole } = require("jsdom");

const BASE = process.env.APP_BASE || "http://127.0.0.1:8080";
let failures = [];
function check(cond, label, extra) {
  if (cond) { console.log("  ok   " + label); }
  else { console.log(" FAIL  " + label + (extra ? "  [" + extra + "]" : "")); failures.push(label); }
}

// Minimal fake for the page's own fetch calls: /auth/me decides the auth state.
function makeFetch(user) {
  return async (url, opts) => {
    if (String(url).includes("/auth/me")) {
      return user
        ? { ok: true, status: 200, json: async () => user }
        : { ok: false, status: 401, json: async () => ({ detail: "Not authenticated" }) };
    }
    if (String(url).includes("/auth/login")) {
      return { ok: false, status: 401, json: async () => ({ detail: "invalid_credentials" }) };
    }
    if (String(url).includes("/auth/register")) {
      return { ok: false, status: 400, json: async () => ({ detail: "email_taken" }) };
    }
    return { ok: true, status: 200, json: async () => ({}) };
  };
}

async function load({ languages, saved, user }) {
  const vc = new VirtualConsole();
  const errors = [];
  vc.on("jsdomError", e => errors.push(e.message));
  vc.on("error", (...a) => errors.push(a.join(" ")));

  const dom = await JSDOM.fromURL(BASE + "/", {
    runScripts: "dangerously",
    resources: "usable",
    pretendToBeVisual: true,
    virtualConsole: vc,
  });
  const w = dom.window;

  // JSDOM.fromURL resolves before external scripts have finished, unlike a real browser where a
  // blocking <script src> in <head> is guaranteed to run before the body. Wait for load so
  // i18n.js has definitely executed.
  if (w.document.readyState !== "complete") {
    await new Promise(res => { w.addEventListener("load", res); setTimeout(res, 2000); });
  }
  if (typeof w.applyI18n !== "function") throw new Error("i18n.js did not load");

  // Stub the environment BEFORE the page's inline script runs. JSDOM.fromURL already ran the
  // head scripts, so i18n.js has executed once with the real navigator; we re-run its picker
  // after overriding, which is what a real browser would have done in one pass.
  const store = {};
  if (saved) store["app01.lang"] = saved;
  Object.defineProperty(w.navigator, "languages", { value: languages, configurable: true });
  Object.defineProperty(w, "localStorage", {
    value: { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = v; },
             removeItem: k => { delete store[k]; } },
    configurable: true,
  });
  w.fetch = makeFetch(user);

  // Re-derive the language now that navigator/localStorage are the ones under test, then let the
  // page apply it exactly as it does at boot.
  w.i18nLang = w.i18nPickLang();
  w.applyI18n();
  // Drain the page's async /auth/me boot path.
  await new Promise(r => setTimeout(r, 50));
  if (user) { w.setUser(user); }
  return { dom, w, errors, store };
}

const GOOGLE_USER = {
  id: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  email: "someone@example.com",
  username: null,
  full_name: "Dana Levi",
  avatar_url: null,
  auth_provider: "google",
};

(async () => {
  // ───────────────────────── 1. Hebrew browser, first visit ─────────────────────────
  console.log("\n[1] Hebrew browser, never chosen a language, signed out");
  {
    const { w, errors } = await load({ languages: ["he-IL", "en-US"], user: null });
    check(w.document.documentElement.lang === "he", 'html lang="he"', w.document.documentElement.lang);
    check(w.document.documentElement.dir === "rtl", 'html dir="rtl"', w.document.documentElement.dir);
    check(/אפליקציית ענן/.test(w.document.title), "title is Hebrew", w.document.title);
    const nav = w.document.querySelector('[data-i18n="nav.signin"]');
    check(nav && nav.textContent === "התחברות", "nav Sign in -> התחברות", nav && nav.textContent);
    const h1 = w.document.querySelector("h1");
    check(/אפליקציה לדוגמה/.test(h1.textContent), "hero h1 translated", h1.textContent.trim().slice(0, 40));
    // No English left anywhere visible (product names excepted).
    const body = w.document.body.textContent;
    for (const s of ["Sign in", "Create an account", "The boring parts", "Welcome back"]) {
      check(!body.includes(s), "no leftover English: " + JSON.stringify(s));
    }
    check(errors.length === 0, "no script errors", errors.join(" | ").slice(0, 200));
  }

  // ───────────────────────── 2. English browser ─────────────────────────
  console.log("\n[2] English browser, signed out");
  {
    const { w } = await load({ languages: ["en-US"], user: null });
    check(w.document.documentElement.dir === "ltr", 'html dir="ltr"');
    const nav = w.document.querySelector('[data-i18n="nav.signin"]');
    check(nav.textContent === "Sign in", "nav stays English", nav.textContent);
    check(!/[֐-׿]/.test(w.document.body.textContent.replace(/עברית/g, "")),
          "no Hebrew leaked into the English page (switcher label excepted)");
  }

  // ───────────────────────── 3. saved choice overrides the browser ─────────────────────────
  console.log("\n[3] English browser but Hebrew previously chosen");
  {
    const { w } = await load({ languages: ["en-US"], saved: "he", user: null });
    check(w.document.documentElement.dir === "rtl", "saved choice wins -> rtl");
    const active = w.document.querySelector('[data-lang="he"]');
    check(active.classList.contains("lang-active"), "he button marked active");
    check(active.getAttribute("aria-current") === "true", 'aria-current="true" on active');
    const other = w.document.querySelector('[data-lang="en"]');
    check(!other.classList.contains("lang-active"), "en button not active");
    check(other.textContent === "EN" && active.textContent === "עברית",
          "switcher labels come from I18N_LANGS", other.textContent + "/" + active.textContent);
  }

  // ───────────────────────── 4. live switch, and it persists ─────────────────────────
  console.log("\n[4] Switching language at runtime");
  {
    const { w, store } = await load({ languages: ["en-US"], user: null });
    check(w.document.documentElement.dir === "ltr", "starts ltr");
    w.setLang("he");
    check(w.document.documentElement.dir === "rtl", "setLang('he') flips to rtl");
    check(w.document.querySelector('[data-i18n="nav.signup"]').textContent === "הרשמה",
          "nav retranslated after switch");
    check(store["app01.lang"] === "he", "choice written to localStorage", JSON.stringify(store));
    w.setLang("en");
    check(w.document.documentElement.dir === "ltr", "switches back to ltr");
    check(w.document.querySelector('[data-i18n="nav.signup"]').textContent === "Sign up",
          "nav back to English");
  }

  // ───────────────────────── 5. signed-in dashboard in Hebrew ─────────────────────────
  console.log("\n[5] Signed-in Google user, Hebrew");
  {
    const { w } = await load({ languages: ["he-IL"], user: GOOGLE_USER });
    w.showView("dashboard");
    const label = id => w.document.getElementById(id);
    check(label("user-provider").textContent === "חשבון Google",
          "provider badge translated", label("user-provider").textContent);
    check(label("user-provider-detail").textContent === "חשבון Google",
          "provider detail is a label, not the raw slug", label("user-provider-detail").textContent);
    check(label("user-username").textContent === "—",
          "null username shows the em dash", JSON.stringify(label("user-username").textContent));
    check(label("user-email").getAttribute("dir") === "ltr", 'email keeps dir="ltr"');
    check(label("user-id").getAttribute("dir") === "ltr", 'UUID keeps dir="ltr"');
    check(label("user-id").textContent === GOOGLE_USER.id, "UUID rendered intact");
    check(w.document.querySelector('[data-i18n="dash.userid"]').textContent === "מזהה משתמש",
          "dashboard labels translated");
    // Signed in: the hero must show the signed-in line, in Hebrew.
    check(label("hero-line-in").classList.contains("hidden") === false, "signed-in hero line shown");
    check(/החיבור בוצע/.test(label("hero-line-in").textContent), "signed-in line is Hebrew");
    check(label("cta-section").classList.contains("hidden"), "register CTA removed when signed in");
  }

  // ───────────────────────── 6. dialog title follows the tab and the language ─────────────
  console.log("\n[6] Auth dialog title across tab + language changes");
  {
    const { w } = await load({ languages: ["en-US"], user: null });
    w.openAuth("login");
    check(w.document.getElementById("auth-title").textContent === "Welcome back", "login title (en)");
    w.switchTab("register");
    check(w.document.getElementById("auth-title").textContent === "Create your account", "register title (en)");
    w.setLang("he");
    check(w.document.getElementById("auth-title").textContent === "פתיחת חשבון חדש",
          "register title follows a language switch",
          w.document.getElementById("auth-title").textContent);
    w.switchTab("login");
    check(w.document.getElementById("auth-title").textContent === "טוב לראות אותך שוב", "login title (he)");
  }

  // ───────────────────────── 7. API error codes become sentences ─────────────────────────
  console.log("\n[7] Server error codes translated");
  {
    const { w } = await load({ languages: ["he-IL"], user: null });
    const form = w.document.getElementById("form-login");
    await w.handleLogin({ preventDefault() {}, target: { email: { value: "a@b.com" }, password: { value: "x" } } });
    await new Promise(r => setTimeout(r, 30));
    const err = w.document.getElementById("login-error");
    check(err.textContent === "אימייל או סיסמה שגויים",
          "invalid_credentials -> Hebrew sentence", err.textContent);
    check(!err.classList.contains("hidden"), "error is visible");

    await w.handleRegister({ preventDefault() {}, target: {
      email: { value: "a@b.com" }, username: { value: "u" }, password: { value: "pw" } } });
    await new Promise(r => setTimeout(r, 30));
    const rerr = w.document.getElementById("register-error");
    check(rerr.textContent === "כתובת האימייל הזו כבר רשומה", "email_taken -> Hebrew", rerr.textContent);
  }

  // ───────────────────────── 8. unknown code falls back, not raw ─────────────────────────
  console.log("\n[8] Unknown error code falls back to the generic message");
  {
    const { w } = await load({ languages: ["he-IL"], user: null });
    w.fetch = async () => ({ ok: false, status: 500, json: async () => ({ detail: "some_new_code" }) });
    await w.handleLogin({ preventDefault() {}, target: { email: { value: "a@b.com" }, password: { value: "x" } } });
    await new Promise(r => setTimeout(r, 30));
    const err = w.document.getElementById("login-error");
    check(err.textContent === "משהו השתבש", "unknown code -> generic Hebrew, not the raw key", err.textContent);
  }

  console.log("\n" + (failures.length
    ? failures.length + " FAILURE(S):\n  - " + failures.join("\n  - ")
    : "all DOM tests pass"));
  process.exit(failures.length ? 1 : 0);
})().catch(e => { console.error("harness error:", e); process.exit(2); });
