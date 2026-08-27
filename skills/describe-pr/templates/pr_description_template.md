<!-- Audience: readers who don't read code — the product owner deciding priorities, support triaging user reports, the writer compiling release notes. Reviewers read the diff itself; never recite it: no inventories of changed files or functions. Mention a file or module only when it orients the reader or requires action (config, migration, public API).
State each fact once, in the section that owns it.
Keep the whole description under one screen (about 300 words), excluding embedded evidence.
No verification content: test results and check runs belong to CI, not here. -->

<!-- H1: the PR branch name, verbatim. Second line: one sentence stating why the PR exists and how important it is — the kind of change and its stakes, not a summary of what the code does now. "Fixes a high-severity replication bug that silently drops updates between sites", not "The database now records when a row was written". For bug fixes, name the severity here. -->

# {branch-name}

{Why this PR exists and its stakes, in one sentence.}

## 🎯 Problem

<!-- The problem or need this PR answers: who hits it, in what scenario, what it costs them. One or two short paragraphs; the first sentence names the problem, context follows. For bug fixes, describe the impact only; the failure mechanism belongs in Bug details. -->

---

## 👀 What changes for users

<!-- Observable behavior before vs. after, in plain language, with feature names as users see them in the product. No file or function names, no internal code names.
For UI changes, embed the approved show-me evidence of the new or updated feature (public URLs published via the show-me skill): screenshots as images, recordings as plain links, before and after states as applicable. The captures must let a reviewer confirm the feature works and spot flaws by eye: a missing button, wrong text, misaligned elements. No diagrams or explainers here; explanation belongs to the prose sections.
If nothing changes for users, write exactly "None." (only when true for the whole PR); release-notes compilation skips such PRs. -->

---

## 🐛 Bug details

<!-- Bug fixes only; delete this section otherwise. This section owns the failure mechanism; don't retell it in other sections.
Severity: critical = data loss or security; high = broken workflow, no workaround; medium = workaround exists; low = cosmetic. Weigh impact together with likelihood: name the real code paths that can hit the trigger and how often they run; a severe outcome on a rare path is not automatically high.
Exposure: the commit or release that introduced the bug and when it shipped, traced through git history, so a customer can tell whether their version is affected. "As long as the code has done X" is a guess, not an answer. -->

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

<!-- Only decisions the diff can't show: trade-offs, rejected alternatives, gotchas. A few bullets. If the diff shows it, don't write it. Link the exec plan (docs/plans/...) if the PR includes one; don't restate it. -->

---

## 📌 Related issues

<!-- Delete this section if there is no linked issue. -->

Closes #ISSUE_ID
