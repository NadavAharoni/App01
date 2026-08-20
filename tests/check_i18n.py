#!/usr/bin/env python
"""Static checks on the i18n wiring. No dependencies, no running server, no network.

    python tests/check_i18n.py

Enforces the rules in CLAUDE.md under "Multilingual (Hebrew / RTL)". Every one of these checks
exists because the failure it catches is invisible in the language you are working in: a key
missing from Hebrew silently falls back to English, and a physical direction utility looks
perfectly fine until the page is RTL. Exits non-zero on the first category that fails.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding="utf-8").read()


def dictionaries(js):
    """Pull the per-language key sets out of i18n.js by text, so this needs no JS engine.

    Anchored on `window.I18N = {` specifically: window.I18N_LANGS also has `en:` / `he:` members
    and would otherwise be picked up as if it were a dictionary.
    """
    body = js.split("window.I18N = {", 1)[1]
    marker = "\n  he: {"
    if marker not in body:
        raise SystemExit("could not locate the `he` dictionary in static/i18n.js")
    en_src, he_src = body.split(marker, 1)
    key_re = re.compile(r'^\s{4}"([^"]+)"\s*:', re.M)
    return set(key_re.findall(en_src)), set(key_re.findall(he_src))


def main():
    html = read("static/index.html")
    js = read("static/i18n.js")
    py = read("routers/auth.py")

    en, he = dictionaries(js)
    failures = []

    def ok(label):
        print("  ok   " + label)

    def bad(label, detail=""):
        print(" FAIL  " + label + ("  [" + str(detail) + "]" if detail else ""))
        failures.append(label)

    # 1. Both dictionaries carry the same keys. A one-sided key degrades to English in silence.
    if en == he:
        ok("dictionaries have identical key sets (%d keys)" % len(en))
    else:
        bad("dictionary key sets differ",
            "missing from he: %s | missing from en: %s" % (sorted(en - he), sorted(he - en)))

    # 2. No empty values — an empty string renders as a blank element, not as a visible mistake.
    val_re = re.compile(r'^\s{4}"([^"]+)"\s*:\s*""\s*,', re.M)
    empties = val_re.findall(js)
    if empties:
        bad("empty dictionary values", empties)
    else:
        ok("no empty dictionary values")

    # 3. Every key referenced from markup or the inline script exists.
    used = set()
    for attr in ("data-i18n", "data-i18n-placeholder", "data-i18n-aria-label"):
        used |= set(re.findall(attr + r'="([^"]+)"', html))
    used |= set(re.findall(r'\bt\(\s*"([a-z][a-z0-9_.]*)"\s*\)', html))
    used |= set(re.findall(r'"(dash\.provider_[a-z]+)"', html))
    used |= set(re.findall(r'"(auth\.title_[a-z]+)"', html))

    unknown = sorted(k for k in used if k not in en)
    if unknown:
        bad("keys referenced but not defined", unknown)
    else:
        ok("all %d referenced keys are defined" % len(used))

    # 4. No dead copy. err.* and the state-driven keys are reached by computed name.
    computed = {k for k in en if k.startswith("err.")} | {
        "meta.title", "dash.empty", "dash.provider_google", "dash.provider_local",
        "auth.title_login", "auth.title_register",
    }
    orphans = sorted(k for k in en if k not in used and k not in computed)
    if orphans:
        bad("dictionary keys nothing references", orphans)
    else:
        ok("no orphaned dictionary keys")

    # 5. Every error code the API can raise has a message. Without this the user sees the generic
    #    fallback and the specific cause is lost.
    codes = set(re.findall(r'detail="([a-z_]+)"', py))
    missing = sorted(c for c in codes if "err." + c not in en)
    if missing:
        bad("API error codes with no err.* key", missing)
    else:
        ok("all %d API error codes have messages" % len(codes))

    # 6. No physical direction utilities. These are correct in English and wrong in Hebrew.
    body = html.split("<body", 1)[1].split("<script>", 1)[0]
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)   # commentary may name them legitimately
    phys = set(re.findall(r"(?<![\w:-])-?(?:sm:|md:|lg:)?(?:ml|mr|pl|pr)-[\w.\[\]/]+", body))
    phys |= set(re.findall(r"\btext-(?:left|right)\b", body))
    phys |= set(re.findall(r"\b(?:border|rounded)-(?:l|r)(?:-[\w.]+)?\b", body))
    if phys:
        bad("physical direction utilities (use ms/me/ps/pe/text-start)", sorted(phys))
    else:
        ok("no physical direction utilities in markup")

    # 7. Values that are LTR by nature must say so, or bidi reorders them on screen.
    for eid in ("user-email", "user-id", "user-username"):
        m = re.search(r'id="%s"[^>]*>' % eid, html)
        if not m or 'dir="ltr"' not in m.group(0):
            bad('#%s is missing dir="ltr"' % eid)
    if not any("missing dir" in f for f in failures):
        ok('LTR-by-nature dashboard values carry dir="ltr"')

    # 8. Nothing user-visible left hardcoded in the markup.
    stripped = re.sub(r"<(script|style|svg)\b.*?</\1>", "", body, flags=re.S | re.I)
    allowed = {
        "App01", "A", "python", "git", "users",          # brand, logo glyph, a table name
        "-m uvicorn main:app --reload --port 8080",      # shell commands are typed verbatim
        "push origin main",
        "Welcome back",   # #auth-title's pre-JS default; set by syncAuthTitle(), checked below
    }
    leftovers = []
    for m in re.finditer(r">([^<>]+)<", stripped):
        txt = re.sub(r"\s+", " ", m.group(1)).strip()
        if len(txt) < 2 or not re.search("[A-Za-z֐-׿]{2}", txt):
            continue
        tag = stripped[stripped.rfind("<", 0, m.start()):m.start() + 1]
        if "data-i18n" in tag or "data-lang" in tag or txt in allowed:
            continue
        leftovers.append(txt[:60])
    if leftovers:
        bad("hardcoded user-visible text (belongs in i18n.js)", leftovers)
    else:
        ok("no hardcoded user-visible text")

    # 9. The one state-dependent string is wired through the dictionary and re-applied on switch.
    if not re.search(r'function syncAuthTitle\(\)\s*\{[^}]*\$\("auth-title"\)\.textContent\s*=\s*t\(',
                     html):
        bad("#auth-title is not set from the dictionary by syncAuthTitle()")
    elif "window.syncAuthTitle" not in js:
        bad("applyI18n() never calls syncAuthTitle(), so the dialog title would not follow a switch")
    else:
        ok("#auth-title wired via syncAuthTitle() and re-applied by applyI18n()")

    # 10. i18n.js must stay blocking and ahead of the stylesheet, or RTL flips after first paint.
    head = html.split("</head>", 1)[0]
    tag = re.search(r'<script[^>]*src="/static/i18n\.js"[^>]*>', head)
    if not tag:
        bad("i18n.js is not loaded in <head>")
    elif "defer" in tag.group(0) or "async" in tag.group(0):
        bad("i18n.js is defer/async — dir would be set after first paint", tag.group(0))
    elif head.index("i18n.js") > head.index("fonts.googleapis.com/css2"):
        bad("i18n.js loads after the stylesheet; move it earlier so dir is set first")
    else:
        ok("i18n.js is blocking, in <head>, ahead of the stylesheet")

    print()
    if failures:
        print("%d check(s) failed:" % len(failures))
        for f in failures:
            print("  - " + f)
        return 1
    print("all i18n checks pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
