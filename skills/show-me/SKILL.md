---
name: show-me
description: Produce human-friendly evidence of the work on a branch (screenshots, screen recordings, Mermaid diagrams, HTML explainers) stored outside the repo with a manifest. Use when asked to show, demo, prove, record, or visualize a change, or to capture evidence for a PR.
---

# Show me

Demonstrate the work in a form a human can judge at a glance. Evidence is also a quality gate: if you cannot demonstrate the described behavior, the work may not do what it claims. Report the gap; never fake or stage a result.

## Storage

Evidence lives outside the repo; heavy files, drafts, and rejects don't belong in git:

```
~/.show-me/{repo-name}/{branch-name}/{yyyy-mm-dd}-{slug}/
```

Repo name: basename of the origin remote (directory name if no remote). Sanitize `/` in branch names to `-`. The skill can run many times per branch; each run gets its own directory.

Every directory contains `manifest.md`:

```markdown
---
status: draft | approved | rejected | outdated
branch: {branch-name}
commit: {HEAD sha at capture time}
date: {yyyy-mm-dd}
---

One paragraph: what this evidence demonstrates.

* `{file}` - one line on what it shows
```

## Choose the medium

- User-facing behavior: screen recording or screenshots of the real product. Drive web UIs with the playwright-cli skill; launch the app with the run skill. Show before and after states when the contrast matters; capture "before" from the base branch in a temporary worktree.
- Architecture or flow changes: a markdown file with Mermaid diagrams embedded as ```mermaid blocks, plus short notes. GitHub renders Mermaid natively.
- A visual UI, layout, state comparison, or concept too dense for Mermaid: one focused HTML file, `show-me-{description}.html`. A diagram, an infographic, or a short slide deck, whichever fits the point. Match the product's colors, type, spacing, and components; use real labels and data; support desktop and mobile.

Only screenshots and recordings of the real product are evidence: hard to fake, they prove behavior. Mermaid diagrams and HTML files are agent-authored explanations; they help the reader but prove nothing and can be wrong, so only the user's verdict validates them.

## Workflow

1. Confirm what to demonstrate; record repo name, branch, and HEAD sha.
2. Capture the evidence into a new dated directory and write `manifest.md` with `status: draft`.
3. Open the results for the user: `open {file-or-dir}`.
4. Ask for a verdict and record it in the manifest: approved, rejected, or leave as draft.
5. If the demonstration failed, say exactly what could not be shown and why. That report is the deliverable, not a defect of this skill.

Consumers such as the describe-pr skill scan the manifests and use only approved, fresh evidence.

## Publish

Local storage under `~/.show-me/` is the default and the end of the normal workflow. Publish a file only when the user or a consumer skill (such as describe-pr) requests a public URL, for example to embed images and recordings in a PR description. Publishing is available when `~/.config/show-me/publish.env` exists; consumers check only for that file. The storage platform (currently Cloudflare R2) is this skill's concern, encoded entirely here and in the config:

```bash
R2_BUCKET=...
R2_S3_API_ENDPOINT=...     # https://{account_id}.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=...       # R2 API token (S3 credentials), Object Read & Write on the bucket
R2_SECRET_ACCESS_KEY=...
R2_PUBLIC_BASE_URL=...     # pub-*.r2.dev or custom domain with public access enabled
```

Upload each file under an unguessable key (the random slug is the access control; never omit it), then verify the public URL returns 200:

```bash
source ~/.config/show-me/publish.env
key="{repo-name}/{purpose}/$(openssl rand -hex 4)/{filename}"   # purpose: e.g. pr_{NNN}
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" AWS_DEFAULT_REGION=auto \
  aws s3 cp {path} "s3://$R2_BUCKET/$key" --endpoint-url "$R2_S3_API_ENDPOINT"
curl -s -o /dev/null -w "%{http_code}" "$R2_PUBLIC_BASE_URL/$key"
```
