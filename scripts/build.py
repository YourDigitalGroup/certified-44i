#!/usr/bin/env python3
"""
CERTIFIED.44i static site generator.

Reads scripts/site-data.json (extracted from the WordPress/LearnPress export)
and emits fully static HTML pages into the repository root. No build step is
required to *view* the site — the generated .html files are the deliverable.
Re-run this script to regenerate after editing data or templates.
"""
import html
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = json.load(open(os.path.join(ROOT, "scripts", "site-data.json"), encoding="utf-8"))

SITE = DATA["site"]
COURSES = DATA["courses"]
CERTS = DATA["certs"]
RANKS = DATA["ranks"]

# Original media (served from the live site; referenced with graceful fallback)
UP = "https://certified.44i.com/wp-content/uploads"
COVERS = {
    "101-process-certification": f"{UP}/2023/09/courseCovers_1.jpg",
    "101-products-certification": f"{UP}/2023/08/courseCovers_2.jpg",
    "201-products-certification": f"{UP}/2023/07/courseCovers_3.jpg",
    "packages-certification": f"{UP}/2023/10/courseCovers_PLUS.jpg",
}
CERT_IMG = {
    "certified-bottom-of-house": f"{UP}/2023/10/44iDigital_Certificate_OnlineVisibility.png",
    "certified201-content-marketing": f"{UP}/2023/10/44iDigital_Certificate_ContentMarketing.png",
    "certified301-targeted-digital": f"{UP}/2023/10/44iDigital_Certificate_TargetedDigital.png",
}

# Editorial copy for courses whose export description was empty
COURSE_COPY = {
    "101-process-certification": {
        "blurb": "Master the 44i way of working — from understanding your digital agency to audits, "
                 "needs analyses, insertion orders and reporting.",
        "track": "Certified:101 Online Visibility",
    },
    "101-products-certification": {
        "blurb": "The Online Visibility foundation: Google Business Profile, websites, SEO, social media, "
                 "email marketing, local listings and reputation management.",
        "track": "Certified:101 Online Visibility",
    },
    "201-products-certification": {
        "blurb": "Level up into paid search. A focused deep-dive into Search Engine Marketing (SEM) and its certification.",
        "track": "Certified:201 Content Marketing",
    },
    "packages-certification": {
        "blurb": "The complete sales-enablement track — digital sales tools, resource center, Trello, site visits, "
                 "marketing & promotion, and building your digital agency.",
        "track": "Certified:301 Targeted Digital",
    },
}
LEVEL_LABEL = {"beginner": "Beginner", "intermediate": "Intermediate", "expert": "Expert", "": "All levels"}

NAV = [
    ("courses.html", "Courses"),
    ("certificates.html", "Certifications"),
    ("instructors.html", "Instructors"),
    ("certificates.html#verify", "Verify"),
]

# ---------------------------------------------------------------- icons
IC_CLOCK = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'
IC_BOOK = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 5a2 2 0 0 1 2-2h12v16H6a2 2 0 0 0-2 2z"/></svg>'
IC_USERS = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 19v-1a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v1"/><circle cx="9" cy="7" r="3"/><path d="M21 19v-1a4 4 0 0 0-3-3.87M16 4.13A4 4 0 0 1 16 12"/></svg>'
IC_PLAY = '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'
IC_QUIZ = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9.1 9a3 3 0 1 1 4 2.8c-.9.4-1.6 1.2-1.6 2.2"/><circle cx="12" cy="18" r="0.6" fill="currentColor" stroke="none"/></svg>'
IC_CHECK = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M20 6 9 17l-5-5"/></svg>'
IC_CHEV = '<svg class="acc__chev" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>'
IC_AWARD = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="5"/><path d="M8.2 12.5 7 22l5-3 5 3-1.2-9.5"/></svg>'


def e(s):
    return html.escape(str(s or ""))


def course_url(slug):
    return f"course-{slug}.html"


def course_lessons(c):
    return sum(1 for s in c["sections"] for it in s["items"] if it["type"] == "lesson")


def course_quizzes(c):
    return sum(1 for s in c["sections"] for it in s["items"] if it["type"] == "quiz")


# ---------------------------------------------------------------- shell
def head(title, desc, active=""):
    links = ""
    for href, label in NAV:
        base = href.split("#")[0]
        cls = " is-active" if base == active else ""
        links += f'<a class="nav-link{cls}" href="{href}">{label}</a>'
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)} — CERTIFIED.44i</title>
<meta name="description" content="{e(desc)}">
<link rel="icon" type="image/svg+xml" href="assets/img/favicon.svg">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/css/styles.css">
</head>
<body>
<header class="site-header">
  <div class="wrap">
    <nav class="nav" aria-label="Primary">
      <a class="brand" href="index.html">
        <img class="brand__mark" src="assets/img/logomark.svg" alt="">
        <span>CERTIFIED<em>.44i</em></span>
      </a>
      <button class="nav__toggle" aria-label="Menu" aria-expanded="false"><span></span><span></span><span></span></button>
      <div class="nav__links">{links}</div>
      <div class="nav__cta">
        <a class="btn btn--ghost-light btn--sm" href="login.html">Sign in</a>
        <a class="btn btn--primary btn--sm" href="login.html">Start training</a>
      </div>
    </nav>
  </div>
</header>
<main>
"""


def footer():
    course_links = "".join(
        f'<a href="{course_url(c["slug"])}">{e(c["title"])}</a>' for c in COURSES
    )
    return f"""</main>
<footer class="site-footer">
  <div class="wrap">
    <div class="footer__grid">
      <div class="footer__brand">
        <a class="brand" href="index.html" style="margin-bottom:14px">
          <img class="brand__mark" src="assets/img/logomark.svg" alt="">
          <span>CERTIFIED<em>.44i</em></span>
        </a>
        <p>The digital certification portal from 44&nbsp;Interactive. Learn the process, master the products, and earn credentials that prove it.</p>
      </div>
      <div>
        <h4>Courses</h4>
        {course_links}
      </div>
      <div>
        <h4>Credentials</h4>
        <a href="certificates.html">Certifications</a>
        <a href="certificates.html#verify">Verify a certificate</a>
        <a href="instructors.html">Instructors</a>
      </div>
      <div>
        <h4>Company</h4>
        <a href="https://44interactive.com" rel="noopener">44 Interactive</a>
        <a href="privacy.html">Privacy Policy</a>
        <a href="terms.html">Terms &amp; Conditions</a>
      </div>
    </div>
    <div class="footer__bottom">
      <span>&copy; <span data-year>2026</span> 44 Interactive. All rights reserved.</span>
      <span>Static rebuild of CERTIFIED.44i</span>
    </div>
  </div>
</footer>
<script src="assets/js/main.js"></script>
{{extra_scripts}}
</body>
</html>"""


def media(cover_url, title, cls="card__media"):
    """Image with a graceful gradient+title fallback if the remote asset is unavailable."""
    return (
        f'<div class="{cls}">'
        f'<div class="fallback">{e(title)}</div>'
        f'<img src="{cover_url}" alt="{e(title)} cover" loading="lazy" '
        f'onerror="this.style.display=\'none\'"></div>'
    )


def page(path, title, desc, body, active="", extra_scripts=""):
    htmlout = head(title, desc, active) + body + footer().replace("{extra_scripts}", extra_scripts)
    with open(os.path.join(ROOT, path), "w", encoding="utf-8") as f:
        f.write(htmlout)
    print("  wrote", path)


# ---------------------------------------------------------------- components
def course_card(c):
    copy = COURSE_COPY.get(c["slug"], {})
    blurb = copy.get("blurb") or re.sub("<[^>]+>", "", c.get("description", ""))[:160]
    level = LEVEL_LABEL.get(c.get("level", ""), c.get("level") or "All levels")
    return f"""<article class="card">
  <a href="{course_url(c['slug'])}" aria-label="{e(c['title'])}">{media(COVERS.get(c['slug'],''), c['title'])}</a>
  <div class="card__body">
    <div class="badge-row"><span class="tag">{e(copy.get('track',''))}</span></div>
    <h3><a href="{course_url(c['slug'])}" style="color:inherit">{e(c['title'])}</a></h3>
    <p>{e(blurb)}</p>
    <div class="card__meta">
      <span class="tag--level tag">{e(level)}</span>
      <span>{IC_BOOK}{len(c['sections'])} sections</span>
      <span>{IC_USERS}{e(c['students'])} enrolled</span>
    </div>
  </div>
</article>"""


# ---------------------------------------------------------------- pages
def build_index():
    cards = "".join(course_card(c) for c in COURSES)
    total_students = COURSES[0]["students"] if COURSES else "72"
    total_sections = sum(len(c["sections"]) for c in COURSES)
    total_lessons = sum(course_lessons(c) for c in COURSES)

    cred_cards = ""
    seals = ["101", "201", "301"]
    for i, ct in enumerate(CERTS):
        cred_cards += f"""<div class="credcard">
  <div class="credcard__seal">{seals[i] if i < len(seals) else IC_AWARD}</div>
  <h3>{e(ct['title'])}</h3>
  <p>Earned by completing the matching certification track and passing every section quiz.</p>
</div>"""

    journey = ""
    for i, r in enumerate(RANKS, 1):
        desc = {
            "Welcome": "Create your account and get oriented with the certification path.",
            "101 Process": "Learn how 44i works end to end — the Process Certification.",
            "101 Products": "Master the Online Visibility product suite.",
            "201 Products": "Advance into paid search and SEM.",
            "Packages": "Complete the full sales-enablement Packages track.",
        }.get(r["title"], "Progress to the next rank as you complete certifications.")
        journey += f"""<div class="journey__row">
  <div class="journey__num">{i}</div>
  <div><h3>{e(r['title'])}</h3><p>{desc}</p></div>
</div>"""

    body = f"""
<section class="hero">
  <div class="wrap">
    <div class="hero__grid">
      <div>
        <span class="hero__badge">{IC_AWARD}&nbsp; Digital certification by <b>44&nbsp;Interactive</b></span>
        <h1>Get CERTIFIED in the way 44i does digital.</h1>
        <p class="lead">Watch focused training videos, pass each section quiz, and earn printable digital credentials — Online Visibility, Content Marketing and Targeted Digital.</p>
        <div class="hero__cta">
          <a class="btn btn--primary" href="courses.html">Explore courses</a>
          <a class="btn btn--ghost-light" href="certificates.html">View certifications</a>
        </div>
        <div class="hero__stats">
          <div><div class="num">{len(COURSES)}</div><div class="lbl">Courses</div></div>
          <div><div class="num">{total_sections}</div><div class="lbl">Sections</div></div>
          <div><div class="num">{total_lessons}</div><div class="lbl">Video lessons</div></div>
          <div><div class="num">{e(total_students)}</div><div class="lbl">Learners</div></div>
        </div>
      </div>
      <div class="credstack">{cred_cards}</div>
    </div>
  </div>
</section>

<section class="section">
  <div class="wrap">
    <div class="sec-head center">
      <div class="eyebrow">How it works</div>
      <h2>Learn it. Prove it. Print it.</h2>
      <p class="lead">Every certification follows the same simple, disciplined path.</p>
    </div>
    <div class="grid grid--3">
      <div class="card"><div class="card__body"><h3>{IC_PLAY} Watch in order</h3><p>Each section opens with a concise training video. Videos are watched in sequence — rewatch any as often as you need.</p></div></div>
      <div class="card"><div class="card__body"><h3>{IC_QUIZ} Pass the quiz</h3><p>Complete the section quiz to advance. The Process track requires a perfect 100%; product tracks require 80%.</p></div></div>
      <div class="card"><div class="card__body"><h3>{IC_AWARD} Earn the credential</h3><p>Finish every section and print your digital certificate — verifiable proof of what you've mastered.</p></div></div>
    </div>
  </div>
</section>

<section class="section" style="background:var(--paper-2)">
  <div class="wrap">
    <div class="sec-head">
      <div class="eyebrow">Curriculum</div>
      <h2>Four courses, one certification path</h2>
      <p class="lead">Progress from process fundamentals to advanced, targeted digital strategy.</p>
    </div>
    <div class="grid grid--4">{cards}</div>
  </div>
</section>

<section class="section">
  <div class="wrap split">
    <div>
      <div class="eyebrow">Your progression</div>
      <h2>Rank up as you get certified</h2>
      <p class="lead" style="margin-bottom:28px">Learners advance through five ranks as they complete each certification track.</p>
      <div class="journey">{journey}</div>
    </div>
    <aside>
      <div class="quote">
        <div class="mark">&ldquo;</div>
        <p>Welcome to the 44i Digital Certification course. This comprehensive course is structured into three distinct sections: Process, Digital 101, and Digital 201.</p>
        <footer>— Course welcome message</footer>
      </div>
    </aside>
  </div>
</section>

<section class="section--tight">
  <div class="wrap">
    <div class="cta-band">
      <h2>Ready to get certified?</h2>
      <p>Start with the Process Certification and work your way to Targeted Digital. Every step is video-led and quiz-verified.</p>
      <a class="btn btn--primary" href="courses.html">Browse all courses</a>
    </div>
  </div>
</section>
"""
    page("index.html", "Digital Certification", SITE["tagline"], body)


def build_courses():
    cards = "".join(course_card(c) for c in COURSES)
    body = f"""
<section class="page-hero">
  <div class="wrap">
    <div class="crumbs"><a href="index.html">Home</a> / Courses</div>
    <h1>All Courses</h1>
    <p class="lead">The complete CERTIFIED.44i catalog — from process fundamentals to advanced targeted digital.</p>
  </div>
</section>
<section class="section">
  <div class="wrap">
    <div class="grid grid--3">{cards}</div>
  </div>
</section>
"""
    page("courses.html", "All Courses", "Browse the CERTIFIED.44i course catalog.", body, active="courses.html")


def build_course(c):
    copy = COURSE_COPY.get(c["slug"], {})
    blurb = copy.get("blurb") or re.sub("<[^>]+>", "", c.get("description", ""))
    desc_full = re.sub("<[^>]+>", "", c.get("description", "")) or blurb
    level = LEVEL_LABEL.get(c.get("level", ""), c.get("level") or "All levels")
    lessons, quizzes = course_lessons(c), course_quizzes(c)

    # curriculum accordions (first two open)
    accs = ""
    for si, s in enumerate(c["sections"]):
        items = ""
        for it in s["items"]:
            is_quiz = it["type"] == "quiz"
            ico = f'<span class="ico ico--quiz">{IC_QUIZ}</span>' if is_quiz else f'<span class="ico">{IC_PLAY}</span>'
            href = "lesson-demo.html" if not is_quiz else "lesson-demo.html#quiz"
            dur = f'<span class="dur">{e(it["duration"])}</span>' if it.get("duration") else ""
            items += f"""<li class="acc__item">{ico}
  <a href="{href}" style="color:inherit;font-weight:600">{e(it['title'])}</a>
  <span class="type">{'Quiz' if is_quiz else 'Video'}</span>{dur}</li>"""
        openc = " is-open" if si < 2 else ""
        exp = "true" if si < 2 else "false"
        accs += f"""<div class="acc{openc}">
  <button class="acc__head" aria-expanded="{exp}">
    <span class="acc__idx">{si+1}</span>
    <span>{e(s['title'])}</span>
    <span class="acc__count">{len(s['items'])} items</span>
    {IC_CHEV}
  </button>
  <div class="acc__panel"><ul class="acc__list">{items}</ul></div>
</div>"""

    welcome = ""
    if c.get("welcome"):
        welcome = f"""<div class="note" style="margin-bottom:28px"><b>{e(c['welcome'].get('title','Welcome!'))}</b><br>{e(c['welcome'].get('content',''))}</div>"""

    pass_note = "a perfect 100%" if str(c["passing"]) == "100" else f'{e(c["passing"])}%'

    body = f"""
<section class="page-hero">
  <div class="wrap">
    <div class="crumbs"><a href="index.html">Home</a> / <a href="courses.html">Courses</a> / {e(c['title'])}</div>
    <h1>{e(c['title'])}</h1>
    <p class="lead">{e(blurb)}</p>
    <div class="badge-row" style="margin-top:18px">
      <span class="tag">{e(copy.get('track',''))}</span>
      <span class="tag tag--level" style="background:rgba(255,255,255,.1);color:#fff">{e(level)}</span>
    </div>
  </div>
</section>
<section class="section">
  <div class="wrap split">
    <div>
      {welcome}
      <h2>About this course</h2>
      <p class="lead" style="color:var(--muted)">{e(desc_full)}</p>
      <ul class="checks" style="margin:22px 0 40px">
        <li>{IC_CHECK}<span>{lessons} training {'video' if lessons==1 else 'videos'}, watched in sequence.</span></li>
        <li>{IC_CHECK}<span>{quizzes} section {'quiz' if quizzes==1 else 'quizzes'} — you must score {pass_note} to advance.</span></li>
        <li>{IC_CHECK}<span>Rewatch any video as many times as you need.</span></li>
        <li>{IC_CHECK}<span>Print your digital certificate on completion.</span></li>
      </ul>

      <h2>Curriculum</h2>
      <p style="color:var(--muted);margin-bottom:18px">{len(c['sections'])} sections &middot; {lessons + quizzes} items</p>
      <div class="curriculum">{accs}</div>
    </div>

    <aside>
      <div class="sticky-card">
        {media(COVERS.get(c['slug'],''), c['title'], cls="sticky-card__media")}
        <div class="sticky-card__body">
          <div class="price">Included <small>with 44i onboarding</small></div>
          <a class="btn btn--primary" href="lesson-demo.html" style="width:100%;justify-content:center;margin-top:16px">Start course</a>
          <ul class="meta-list">
            <li><span>Level</span><b>{e(level)}</b></li>
            <li><span>Sections</span><b>{len(c['sections'])}</b></li>
            <li><span>Video lessons</span><b>{lessons}</b></li>
            <li><span>Quizzes</span><b>{quizzes}</b></li>
            <li><span>Passing grade</span><b>{e(c['passing'])}%</b></li>
            <li><span>Enrolled</span><b>{e(c['students'])}</b></li>
          </ul>
        </div>
      </div>
    </aside>
  </div>
</section>
"""
    page(course_url(c["slug"]), c["title"], blurb[:150], body, active="courses.html")


def build_certificates():
    seals = ["101", "201", "301"]
    tracks = [
        "Awarded on completion of the 101 Products (Online Visibility) track.",
        "Awarded for the Content Marketing certification track.",
        "The advanced credential for Targeted Digital strategy.",
    ]
    cards = ""
    for i, ct in enumerate(CERTS):
        img = CERT_IMG.get(ct["slug"], "")
        cards += f"""<article class="cert">
  <div class="cert__frame">
    <div class="cert__doc">
      <div class="seal"></div>
      <small>44 Interactive certifies</small>
      <strong>{e(ct['title'])}</strong>
      <small>Digital Certification</small>
      <img src="{img}" alt="{e(ct['title'])} certificate" loading="lazy" onerror="this.style.display='none'" style="position:absolute;inset:0;width:100%;height:100%;object-fit:contain">
    </div>
  </div>
  <div class="cert__body">
    <span class="tag tag--gold">Credential {seals[i] if i < len(seals) else ''}</span>
    <h3 style="margin:10px 0 6px">{e(ct['title'])}</h3>
    <p style="color:var(--muted);margin:0">{tracks[i] if i < len(tracks) else ''}</p>
  </div>
</article>"""

    samples = "".join(
        f'<button class="btn btn--ghost-light btn--sm" type="button" data-sample="{code}">{code}</button>'
        for code in ["44I-101-8A3F2K", "44I-201-7QW9ZP", "44I-301-3LM6XT"]
    )

    body = f"""
<section class="page-hero">
  <div class="wrap">
    <div class="crumbs"><a href="index.html">Home</a> / Certifications</div>
    <h1>Certifications</h1>
    <p class="lead">Three digital credentials, earned by completing the matching certification track and passing every section quiz.</p>
  </div>
</section>

<section class="section">
  <div class="wrap">
    <div class="grid grid--3">{cards}</div>
  </div>
</section>

<section class="section" id="verify" style="background:var(--paper-2)">
  <div class="wrap">
    <div class="split">
      <div>
        <div class="eyebrow">Verify a certificate</div>
        <h2>Confirm a credential is genuine</h2>
        <p class="lead" style="color:var(--muted)">Enter the certificate code from any CERTIFIED.44i document to confirm the holder, credential and issue date.</p>
        <div class="verify" style="margin-top:24px">
          <form id="verify-form" autocomplete="off">
            <label for="verify-code" style="color:#fff;font-weight:600;font-size:.92rem">Certificate code</label>
            <div class="verify__form">
              <input class="input" id="verify-code" name="code" placeholder="e.g. 44I-101-8A3F2K" aria-label="Certificate code">
              <button class="btn btn--primary" type="submit">Verify</button>
            </div>
            <div style="margin-top:14px" class="badge-row">
              <span style="color:var(--muted-on-dark);font-size:.82rem">Try a sample:</span>{samples}
            </div>
          </form>
          <div id="verify-result" class="verify__result" aria-live="polite"></div>
        </div>
        <p class="note" style="margin-top:20px">This lookup is a front-end demonstration using sample records. In the live portal, codes validate against 44i's credential registry.</p>
      </div>
      <aside>
        <div class="sticky-card"><div class="sticky-card__body">
          <h3 style="margin-top:0">{IC_AWARD} What's on a certificate?</h3>
          <ul class="meta-list">
            <li><span>Holder name</span><b>✓</b></li>
            <li><span>Credential earned</span><b>✓</b></li>
            <li><span>Issue date</span><b>✓</b></li>
            <li><span>Unique code</span><b>✓</b></li>
            <li><span>44 Interactive seal</span><b>✓</b></li>
          </ul>
        </div></div>
      </aside>
    </div>
  </div>
</section>
"""
    page("certificates.html", "Certifications", "View and verify CERTIFIED.44i credentials.",
         body, active="certificates.html", extra_scripts='<script src="assets/js/verify.js"></script>')


def build_instructors():
    body = f"""
<section class="page-hero">
  <div class="wrap">
    <div class="crumbs"><a href="index.html">Home</a> / Instructors</div>
    <h1>Instructors</h1>
    <p class="lead">CERTIFIED.44i training is developed and delivered by the digital specialists at 44&nbsp;Interactive.</p>
  </div>
</section>
<section class="section">
  <div class="wrap">
    <div class="grid grid--3">
      <div class="card"><div class="card__body">
        <div class="credcard__seal" style="background:var(--ink);color:#fff">44i</div>
        <h3 style="margin:8px 0 2px">The 44i Digital Team</h3>
        <p style="color:var(--muted)">Strategists across SEO, paid media, content and web who built the certification curriculum from real client work.</p>
      </div></div>
      <div class="card"><div class="card__body">
        <div class="credcard__seal" style="background:var(--accent)">{IC_BOOK}</div>
        <h3 style="margin:8px 0 2px">Process & Onboarding</h3>
        <p style="color:var(--muted)">Owns the Process Certification — the agency's end-to-end workflow, audits and reporting.</p>
      </div></div>
      <div class="card"><div class="card__body">
        <div class="credcard__seal" style="background:var(--gold);color:#1a1400">{IC_AWARD}</div>
        <h3 style="margin:8px 0 2px">Products & Packages</h3>
        <p style="color:var(--muted)">Leads the Online Visibility, SEM and Packages tracks that lead to each credential.</p>
      </div></div>
    </div>
    <div class="cta-band" style="margin-top:48px">
      <h2>Train with the 44i team</h2>
      <p>Start the certification path and learn the exact process 44 Interactive uses for clients.</p>
      <a class="btn btn--primary" href="courses.html">See the courses</a>
    </div>
  </div>
</section>
"""
    page("instructors.html", "Instructors", "Meet the 44 Interactive team behind the certification.",
         body, active="instructors.html")


def build_lesson_demo():
    body = f"""
<section class="page-hero" style="padding-bottom:34px">
  <div class="wrap">
    <div class="crumbs"><a href="index.html">Home</a> / <a href="courses.html">Courses</a> / Sample lesson</div>
    <h1 style="font-size:clamp(1.8rem,3vw,2.4rem)">Your Digital Agency — Video</h1>
    <p class="lead">A representative section: watch the training video, then pass the quiz to advance.</p>
  </div>
</section>
<section class="section">
  <div class="wrap split">
    <div>
      <div class="player">
        <div class="player__play" role="button" tabindex="0" aria-label="Play video">{IC_PLAY}</div>
        <span class="player__label">Section training video &middot; 12 min</span>
      </div>
      <h2 style="margin-top:34px">About this section</h2>
      <p style="color:var(--muted)">To successfully complete each section and attain certification, you view a concise topical video and then complete a quiz. A perfect score is required for advancement in the Process track. You may rewatch videos as needed and must watch them in order. On completing a section you're authorized to print your digital certificate.</p>

      <h2 id="quiz" style="margin-top:40px">Section quiz</h2>
      <p style="color:var(--muted);margin-bottom:18px">Answer every question correctly to advance.</p>
      <div class="quiz" id="quiz-widget">
        <div class="quiz__head">{IC_QUIZ}<b>Your Digital Agency Quiz</b><span id="quiz-progress" style="margin-left:auto;color:var(--muted);font-size:.85rem"></span></div>
        <div class="quiz__body">
          <div class="quiz__q" id="quiz-question"></div>
          <div class="quiz__opts" id="quiz-options"></div>
        </div>
        <div class="quiz__foot">
          <button class="btn btn--dark btn--sm" id="quiz-next" type="button">Next question</button>
          <span class="quiz__score" id="quiz-score"></span>
        </div>
      </div>
    </div>
    <aside>
      <div class="sticky-card"><div class="sticky-card__body">
        <h3 style="margin-top:0">Section progress</h3>
        <ul class="meta-list">
          <li><span>{IC_PLAY} Watch the video</span><b style="color:var(--ok)">Ready</b></li>
          <li><span>{IC_QUIZ} Pass the quiz</span><b style="color:var(--muted)">Locked</b></li>
          <li><span>{IC_AWARD} Next section</span><b style="color:var(--muted)">Locked</b></li>
        </ul>
        <p class="note" style="margin-top:16px">This is a front-end demo. The live LMS gates each step and tracks real progress per learner.</p>
      </div></div>
    </aside>
  </div>
</section>
"""
    page("lesson-demo.html", "Sample Lesson", "A representative CERTIFIED.44i lesson and quiz.",
         body, extra_scripts='<script src="assets/js/quiz.js"></script>')


def build_prose(path, title, raw_html):
    # Strip WordPress block comments (<!-- wp:... -->) and collapse blank lines
    content = re.sub(r"<!--.*?-->", "", raw_html, flags=re.S).strip()
    content = re.sub(r"\n{3,}", "\n\n", content) or "<p>Content to be provided.</p>"
    body = f"""
<section class="page-hero">
  <div class="wrap">
    <div class="crumbs"><a href="index.html">Home</a> / {e(title)}</div>
    <h1>{e(title)}</h1>
  </div>
</section>
<section class="section">
  <div class="wrap"><div class="prose">{content}</div></div>
</section>
"""
    page(path, title, f"{title} — CERTIFIED.44i", body)


def build_404():
    body = """
<section class="section" style="text-align:center;padding:120px 0">
  <div class="wrap">
    <div class="eyebrow">404</div>
    <h1>Page not found</h1>
    <p class="lead" style="margin:0 auto 26px">The page you're looking for isn't here. Let's get you back on track.</p>
    <a class="btn btn--primary" href="index.html">Back to home</a>
  </div>
</section>
"""
    page("404.html", "Not Found", "Page not found.", body)


def main():
    print("Generating CERTIFIED.44i static site...")
    build_index()
    build_courses()
    for c in COURSES:
        build_course(c)
    build_certificates()
    build_instructors()
    build_lesson_demo()
    privacy = DATA.get("pages", {}).get("privacy", "")
    build_prose("privacy.html", "Privacy Policy", privacy)
    build_prose("terms.html", "Terms & Conditions",
                "<p>These terms govern use of the CERTIFIED.44i training portal, operated by "
                "44&nbsp;Interactive. Access is provided for authorized learners completing the "
                "digital certification program.</p><p><em>Full terms content was not included in the "
                "source export; replace this section with the current agency terms.</em></p>")
    build_404()
    print("Done.")


if __name__ == "__main__":
    main()
