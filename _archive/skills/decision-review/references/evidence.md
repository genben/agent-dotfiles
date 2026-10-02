# Evidence and visual explanations

Adapted from the show-me workflow. Choose the smallest visual that helps the user decide.

## Choose the medium

- **Visible product behavior:** capture screenshots or a short recording of the real product. Use the project's
  verification workflow and approved test environment. Label mockups as proposals; they are not captured evidence.
- **Architecture, sequence, ownership, or state transitions:** use Mermaid when it makes a specific decision clearer.
  Prefer `flowchart TD` or `TB`. Use `LR` only for short linear flows. Keep labels short, wrap with `<br/>`, group
  layers vertically, and split large system maps into focused diagrams. Do not hardcode colors.
- **Dense UI alternatives:** use a focused mockup or before/after comparison, explicitly labeled as proposed.
- **Simple wording or a single fact:** use text. A diagram is not required for every question.

For Mermaid, keep the `.mmd` source and render an SVG or PNG using an available renderer. Reference the rendered file
in `media.src` and the `.mmd` file in `media.source`. The artifact must not depend on a CDN or remote diagram service.
If no renderer is available, report that limitation or use a simpler explanation; do not call raw Mermaid text a
rendered diagram. Inspect the final image for clipped labels and legibility.

## Make comparisons visible

- Capture before and after from the corresponding real revisions when the difference matters.
- Lead with a crop or element capture of the changed region, and retain the full capture for context.
- Include the control state that should not change, such as another role or locale.
- Read the relevant values from the DOM, logs, or API and record them in the manifest. Describe text equality and visual
  layout separately. A screenshot does not establish behavior outside the captured scenario.

## Keep the bundle portable

```text
review-directory/
  review.html
  review.json
  manifest.md
  assets/
    current-state.png
    proposed-flow.svg
    proposed-flow.mmd
    interaction.webm
```

Use relative asset paths. No base64 images, data URLs, remote screenshot hosting, or inline screenshot payloads.
Captions identify current behavior versus proposed behavior and the relevant state or revision. Diagrams and mockups
explain a claim; real captures support it. Neither substitutes for source or runtime validation of the underlying claim.

The manifest records `status: draft`, date, source identity (branch/commit when applicable), file purposes, capture
conditions, and what was actually verified. Preserve uncertainty. Do not mark evidence approved without the user's verdict.
