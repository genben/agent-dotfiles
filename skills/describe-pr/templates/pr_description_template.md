<!-- H1: the PR branch name, verbatim. Second line: a one-sentence human-readable summary. -->

# {branch-name}

{One-sentence summary of the PR.}

## 🎯 Why

<!-- What problem or need does this PR address? Who hit it, in what scenario, and what did it cost them? -->

---

## 👀 What changes for users

<!-- Observable behavior before vs. after, in plain language, with feature names as users see them in the product. No file or function names, no internal code names.
For UI changes, embed the approved show-me screenshots and recordings of the new or updated feature (public URLs published via the show-me skill), before and after states as applicable. The captures must let a reviewer confirm the feature works and spot flaws by eye: a missing button, wrong text, misaligned elements. No diagrams or explainers here; explanation belongs to the prose sections.
If nothing changes for users, write exactly "None." (only when true for the whole PR); release-notes compilation skips such PRs. -->

---

## 🐛 Bug details

<!-- Bug fixes only; delete this section otherwise.
Severity: critical = data loss or security; high = broken workflow, no workaround; medium = workaround exists; low = cosmetic. -->

* **Severity**: critical | high | medium | low
* **Symptom**: what users saw
* **Trigger**: conditions that cause it
* **Exposure**: how long it shipped; workaround, if any

---

## 💥 Blast radius and risks

<!-- What changes for users covers the what; this section covers the who and the how badly. -->

* **Blast radius**: affected user segments, scenarios, integrations
* **Breaking changes**: what breaks; migration steps
* **New risks**: failure modes this change can introduce; rollback story

---

## 🔧 Implementation notes

<!-- Orientation for the code reviewer: a brief high-level overview of how the change is structured, to speed up reading the diff, plus decisions the diff can't show (trade-offs, rejected alternatives, gotchas). Not an inventory of changed files and functions. Link the exec plan (docs/plans/...) if the PR includes one; don't restate it. -->

---

## 📌 Related issues

<!-- Delete this section if there is no linked issue. -->

Closes #ISSUE_ID
