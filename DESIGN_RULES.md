# Design Rules

## Baseline UI Principles (TrainState)

- Keep the UI clean, minimal, and legible.
- Prefer native SwiftUI building blocks over custom wrappers.
- Use restrained typography and spacing; avoid visual noise.
- Structure screens top-to-bottom: summary, filters, content.
- Favor clarity over decoration; data should read at a glance.
- Default to bare SwiftUI section and list styling before introducing custom surfaces.
- Avoid stacks of custom cards, pills, glass effects, or bespoke chrome unless there is a clear functional reason.

## Detail View Standard

- Detail screens should primarily use `List` with grouped `Section`s and standard SwiftUI rows.
- Use plain section headers and native controls before considering custom header treatments.
- Prefer simple stat rows over custom metric tiles unless comparison density truly requires a grid.
- Route, notes, and related detail content should live inside normal sections instead of separate decorative cards.
- Primary actions should read like native SwiftUI actions, not custom hero buttons, unless the action is truly dominant.

## List View Standard

- Summary header at the top (short, 1–2 lines).
- Horizontal filter chips directly under the summary.
- List content grouped by day with clear section headers.
- Rows are simple: icon + title + secondary details + trailing metrics.
- Avoid heavy backgrounds, gradients, or custom list chrome.
