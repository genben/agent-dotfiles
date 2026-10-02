# Review data contract

Use `example.json` for the complete shape. All prose is plain text, not HTML or Markdown. The renderer escapes it.
Unknown extra keys are not rendered; use only the fields below. The builder validates required fields and references.

## Authoring JSON

| Field | Meaning |
| --- | --- |
| `schemaVersion` | `1` |
| `reviewId` | Stable identifier for this review, e.g. `export-design-review` |
| `title`, `subtitle`, `intro` | Page heading, context line, and short instructions |
| `notice` | Optional context notice |
| `items` | Nonempty array of decisions in reading order |

IDs use letters, digits, hyphens, or underscores and start with a letter or digit. Max length: 100.
Decision IDs are unique across the review. Option IDs are unique within a decision.

## Decision

| Field | Meaning |
| --- | --- |
| `id`, `title`, `group` | Stable ID, question title, navigation category |
| `decision` | The behavior or tradeoff the user is choosing |
| `problem` | Current behavior, constraint, or gap, grounded in evidence |
| `scenario` | Concrete explanation shown as “What this means in practice” |
| `recommendation` | Suggested direction and its reason; never a default selection |
| `question` | Label for the choice group |
| `options` | At least two real alternatives; at most one recommended |
| `checks` | Nonempty list of observable verification outcomes |
| `evidence` | Source-reference objects; an empty array is allowed for clearly labeled hypothetical examples |
| `definitions` | Optional list of short definitions |
| `related` | Optional list of other decision IDs |
| `media` | Optional list of colocated media objects |

## Option and concrete proposal

Each option has `id`, `title`, `detail` (behavior), `cost` (tradeoff), and `proposal`.
Optional booleans: `recommended` and `requiresComment` (both default false).

The renderer adds custom approach, discussion, deferral, and disagreement choices. Their reserved IDs are
`custom`, `discuss`, `defer`, and `disagree`; do not use those for authored alternatives.

`proposal` contains:

- `steps`: nonempty list of concrete actions or behavior.
- `failure`: what happens when the proposed path cannot complete.
- `scope`: what this choice covers and, when needed, its boundary.
- `example`: optional illustration for this option.
- `data`: optional rows with `place`, `type`, and `purpose`. Omit when schema or configuration detail is irrelevant.

## Evidence and media

A source reference is either:

```json
{"note": "Playback passes persisted encryption fields to the reader", "path": "src/playback.py", "lines": "40–57"}
```

or:

```json
{"note": "Relevant primary-source documentation", "url": "https://example.org/docs"}
```

Source paths are displayed as text, not fabricated clickable links. Use a verified commit URL in `url` when available.
Record the reviewed revision in the page context or manifest. Only HTTP(S) evidence URLs are accepted.

Media shape:

```json
{"kind": "screenshot", "src": "assets/export-result.png", "alt": "Export result showing three saved files", "caption": "Actual result captured from the test run."}
```

- `kind`: `screenshot`, `recording`, or `diagram`.
- `src`: relative path under `assets/`; spaces and parent traversal are not accepted.
- `alt`, `caption`: required accessible description and context.
- `source`: optional relative `.mmd` path for a diagram, e.g. `assets/export-flow.mmd`.
- Images: PNG, JPEG, WebP, SVG. Recordings: MP4 or WebM.
- The builder copies referenced files; it does not capture screenshots or render Mermaid.

## Generated HTML and feedback backups

Content is embedded as JSON at build time, then rendered by JavaScript. No runtime JSON fetch is used, so `file://`
opening works. Screenshots and diagrams remain linked files. CSS and JavaScript are embedded for portability.

The builder computes `contentHash` from the validated authoring data. The browser storage key includes that hash and
`reviewId`. Identical content at the same browser origin can share state; different browser profiles or file origins
may not. Use Backup JSON to move feedback reliably.

Feedback JSON has schema version 1, review identity, content hash, answers, overall feedback, and view state. It also
includes readable selections for inspection. Import validates identity and choices before changing state. Backups from
changed content are rejected, preserving existing answers. Import is replacement, not a merge. Invalid stored data and
conflicting edits from another tab pause autosave rather than silently overwriting feedback.
