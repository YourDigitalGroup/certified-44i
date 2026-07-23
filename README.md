# CERTIFIED.44i — Static Site

A static **HTML / CSS / JS** rebuild of [certified.44i.com](https://certified.44i.com),
the digital certification training portal from **44 Interactive**.

The original site runs on WordPress + LearnPress (a dynamic LMS). This project
reconstructs its public structure, branding, course catalog, and curriculum as a
fast, dependency-free static site — with the interactive pieces (section quiz,
certificate verification) implemented as clear front-end demos.

## What's here

| Page | File | Description |
|------|------|-------------|
| Home | `index.html` | Hero, how-it-works, course catalog, rank progression, CTA |
| Courses | `courses.html` | Full course catalog |
| Course detail ×4 | `course-*.html` | Curriculum accordion, welcome message, metadata sidebar |
| Certifications | `certificates.html` | The 3 credentials + a certificate **verification** tool |
| Instructors | `instructors.html` | The 44i team behind the program |
| Sample lesson | `lesson-demo.html` | Video player + working section quiz demo |
| Privacy | `privacy.html` | Privacy policy (from the export) |
| Terms | `terms.html` | Terms & conditions (placeholder — replace with current copy) |
| Not found | `404.html` | Friendly 404 |

### Content

All course, section, lesson, quiz, credential, and rank content was extracted
from a WordPress/LearnPress WXR export:

- **4 courses** — Process Certification, 101 Products, 201 Products, Packages
- **3 credentials** — Certified:101 Online Visibility, 201 Content Marketing, 301 Targeted Digital
- **5 progression ranks** — Welcome → 101 Process → 101 Products → 201 Products → Packages

## Structure

```
.
├── index.html, courses.html, course-*.html, ...   # generated static pages
├── assets/
│   ├── css/styles.css      # design system + components
│   ├── js/main.js          # nav, accordions, video demo, footer year
│   ├── js/verify.js        # certificate verification (demo records)
│   ├── js/quiz.js          # section quiz (client-side grading demo)
│   └── img/                # logomark + favicon (SVG)
└── scripts/
    ├── site-data.json      # content extracted from the WordPress export
    └── build.py            # regenerates all .html pages from site-data.json
```

## Regenerating pages

The `.html` files are committed and viewable as-is — **no build step is required
to run the site.** To regenerate after editing `scripts/site-data.json` or the
templates in `scripts/build.py`:

```bash
python3 scripts/build.py
```

## Running locally

Any static server works:

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

## Notes & assumptions

- **Media**: Course covers, certificate images, and training videos are
  self-hosted on the original WordPress server. Pages reference those URLs and
  fall back gracefully (styled placeholders) if an asset is unavailable. Drop
  local copies into `assets/img/` and update paths to fully self-host.
- **Brand color**: The export's global styles were empty, so an orange (`#f26a1b`)
  + ink palette was chosen to match 44 Interactive's look. Adjust the CSS
  variables at the top of `assets/css/styles.css` to match exact brand values.
- **Dynamic behavior**: A real LMS handles login, progress gating, quiz grading,
  and certificate issuance on a backend. Here, the quiz and certificate
  verification are **front-end demonstrations** (sample data) that convey the
  experience without a server.
- Student order/enrollment records from the export were intentionally **not**
  published — they are private data.
