# Untangle — UI/UX Design Specification

## 1. Visual Language: Warm Editorial, Not Vanilla
- **Light theme (warm paper):** Background `#F7F3EC`, Surface `#FFFFFF`, Ink `#1C1917`, Muted `#78716C`, Border `#E8E1D6`, Accent brass `#9A6F1E`.
- **Dark theme (matte charcoal & gold):** Background `#121214`, Surface `#1C1C20`, Ink `#F5F5F4`, Muted `#A8A29E`, Border `#2E2E34`, Accent gold `#D4A853`.
- **Signature dark gradient** (`#1E1A15 → #3B2F1E`) used sparingly for the three "moments that matter": the Decide hero prompt, the workspace **Takeaway** card, and the Journal "reviews due" banner.
- **Serif display type** (`fontFamily: serif`) for headings, technique titles and takeaways gives a book-like character; sans-serif for UI text. Minimum text size `12 px`.
- **Brand mark & Companion Character ("Kip"):** A loop resolving into a straight arrow (`KnotMark`) paired with **Kip** (`UntangleCharacter`), an expressive hand-drawn stick-figure thinker inspired by *The Decision Book*'s illustrations. Kip reacts with finite spring animations: thinking/aha in the Decide hero (tap to bounce & wave), live elastic tug-of-war leaning in Force Balance models, calm/stressed/bored moods in Flow, compass-exploring on Page-82 Compass, and celebrating on saves & review catch-ups.
- **Tactile Micro-Animations:** Spring-animated (`Curves.easeOutBack`) compact `?` popovers, `AnimatedSwitcher` tab & recommendation cross-fades, smooth 9-dot path drawing, and rising Monte Carlo histogram bars.

## 2. Section Color System (from the book's four parts)
| Section | Light | Dark | Used for |
| :--- | :--- | :--- | :--- |
| Improve Yourself (Me · Doing) | `#C4613A` terracotta | `#E08A62` | Monograms, tabs, compass quadrant, journal stripe |
| Understand Yourself (Me · Thinking) | `#4F8560` sage | `#8DBF98` | 〃 |
| Understand Others (Others · Thinking) | `#4F6AA8` slate indigo | `#8FA6DE` | 〃 |
| Improve Others (Others · Doing) | `#8E5A8C` plum | `#C493C2` | 〃 |

Every technique shows a **numbered monogram tile** tinted in its section color, so the 52 models are scannable by color at a glance.

## 3. Screens
- **Decide (Mode 1):** Dark hero card with time-of-day greeting, serif prompt "What are you trying to untangle?", inline input, scope menu and "Try an example" disclosure. Below: **Best Match** card (monogram, serif title, section-colored rationale bar, engine/minutes/section chips, primary CTA) with an animated cross-fade when the match changes; alternatives collapse behind "N other angles".
- **Techniques (Mode 2):** Search + two square toggles (filters, compass). Section tabs with colored dots and colored underline; selecting a section shows a tinted summary strip. Rows: monogram, title, engine glyph + subtitle, `?` button.
- **Book Compass:** Four quadrants tinted by section, labelled in-corner; numbered dots in section colors.
- **Workspace:** Header with section dot, `?`, bookmark, `⋯` menu, Save. Section-tinted hero band (monogram, serif title, chips) → topic field → interactive engine → dark serif **Takeaway** card (animated on change).
- **Journal:** Cards with a 4 px section-color stripe, technique eyebrow, serif title, verdict, and 4-dot SuperMemo progress (Day 1/10/30/60). Dark "reviews due" banner with gold Catch-up button.
- **Navigation:** Floating rounded pill bar (Decide · Techniques · Journal) with an animated tinted selection.

## 4. Progressive Disclosure
- Technique writeups live only in the compact **`?` popover** (max 332×430, never full-screen), headed by the section monogram.
- Secondary actions sit in popovers, collapsible rows and the `⋯` menu; settings use a one-section-at-a-time accordion sheet.

## 5. Responsive Rules
- **Phone (`360×800`):** single pane, `Wrap` chips, `Expanded`/`Flexible` labels; verified with zero overflow by `test/cuj_verification_test.dart`.
- **Tablet/Desktop (`≥900 px`):** 384 px navigation pane + live workspace pane.
