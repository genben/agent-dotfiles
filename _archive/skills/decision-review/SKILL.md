---
name: decision-review
description: Create interactive HTML decision reviews with choices, comments, autosave, a summary, and Markdown or JSON feedback exports. Use when a user wants to review decisions, compare proposals, or return structured feedback through a reusable decision sheet.
---

# Decision review

Generate the artifact with the bundled renderer. Author the review data, not a new page implementation.

## Build the review

- Establish the decisions from the supplied material and current evidence. Separate current behavior, proposed behavior,
  and uncertainty. Recommendations must respect the product's existing architecture, scale, and operating constraints.
- Read [the data contract](references/data-format.md) and use [the example](references/example.json) as a starting point.
  Give each question and option a stable semantic ID. Keep recommendations separate from the user's unselected choices.
- For each decision, explain the practical scenario, recommendation, viable choices and their costs, concrete proposal,
  verification checks, evidence, and related decisions. Do not pad the review with invented choices or decisions the user
  does not need to make. An unknown fact can require investigation rather than a speculative implementation proposal.
- Concrete proposal sections start collapsed. Use them for execution steps, failure behavior, scope, and data changes
  when relevant. Keep the visible choice understandable without requiring the reader to expand technical details.
- Choose media using [the evidence guidance](references/evidence.md). Keep screenshots, recordings, and rendered diagrams
  as separate files under `assets/` beside the output HTML. Never embed screenshots as data URLs or base64.
- Use the user's destination. Otherwise create a dated directory outside the repository under
  `~/.show-me/{repo}/{branch}/{yyyy-mm-dd}-{slug}/` (replace branch slashes with hyphens).
- Write `review.json` in that directory, then run:

```bash
python3 /path/to/decision-review/scripts/build_review.py /path/to/review.json --output /path/to/review-directory
```

The builder embeds validated content and the renderer into `review.html`, copies referenced assets when needed, and
retains the authoring JSON. It requires Python 3.10+ and no third-party packages. Open `review.html` directly in a browser.
No server or CDN is required. Share the whole directory to preserve images, diagrams, and recordings.

## Preserve feedback

- Choices, comments, overall feedback, filters, navigation, and expanded sections save automatically to browser
  `localStorage`. The save indicator reports failures. Browser storage is not a portable backup; offer Backup JSON.
- **Export feedback** writes readable Markdown, including the selected proposals and unresolved questions.
  **Backup JSON** saves feedback and view state. **Import JSON** restores a matching backup and confirms before replacing
  existing feedback. Authoring JSON and feedback JSON are different formats.
- Content hashes isolate changed reviews: edits to questions or proposals do not silently inherit old approvals.
  Keep the previous artifact available when revising content. To carry feedback forward, preserve it as attributed
  comments for reconfirmation; never equate option positions across revisions.
- A selection records feedback. It does not execute changes or expand authorization to implement or publish them.

## Verify and deliver

- Use a browser to check a choice and comment, reload, and confirm persistence. Exercise the summary, Markdown export,
  JSON backup/import, related links, and a narrow viewport. Confirm initial choices are empty and proposals are collapsed.
- Verify media actually loads, inspect diagrams at readable size, and check the browser console. Use a disposable browser
  context for verification so test answers do not appear in the user's review.
- For renderer changes, run `python3 -m unittest discover -s /path/to/decision-review/tests` and
  `node --check /path/to/decision-review/assets/review.js`, then exercise the affected behavior in a real browser.
- Write `manifest.md` beside the artifact: `status: draft`, source revision or input identity, capture date, what each file
  demonstrates, and verification limits. Only record approved/rejected status when the user actually gives that verdict.
- Return the HTML link and explain how to export feedback. Publish externally only when requested. Do not require a
  separate approval merely to create or deliver a local review.
