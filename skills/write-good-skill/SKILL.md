---
name: write-good-skill
description: Principles for writing and editing SKILL.md files. Use when asked to create, review, or trim a skill.
---

# Write a good skill

Skills load into agent context. Every sentence costs tokens; keep only sentences that change agent behavior.

- **Principles, not essays.** State each rule once, in the fewest words. Prefer a clause over a sentence, a parenthetical over an explanatory sentence.
- **Extract the concept.** When the user dictates a rule, distill the underlying principle; never transcribe their phrasing.
- **Cut the obvious.** No sections for what a capable agent does anyway (locating input, defining common terms), no example catalogs.
- **Don't repeat.** Say each thing once. An example that shows a format replaces prose describing it.
- **Reference, don't inline.** Point at sources the agent can read itself: commits over diffs, other skills by name (paths only for files inside a skill directory).
- **Terse description with trigger verbs.** Roughly two sentences: what the skill does, then "Use when..." with the verbs users actually type. The matcher decides from this text alone.
- **Short name.** Name the workflow; drop words the rest implies (a loop implies fixing).
- **Plain style.** Sentence-case headings, active voice, no em dashes. Apply the unslop skill.
