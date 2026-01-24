# Design Rules

## Baseline UI Principles (TrainState)

- Keep the UI clean, minimal, and legible.
- Prefer native SwiftUI building blocks over custom wrappers.
- Use restrained typography and spacing; avoid visual noise.
- Structure screens top-to-bottom: summary, filters, content.
- Favor clarity over decoration; data should read at a glance.

## List View Standard

- Summary header at the top (short, 1–2 lines).
- Horizontal filter chips directly under the summary.
- List content grouped by day with clear section headers.
- Rows are simple: icon + title + secondary details + trailing metrics.
- Avoid heavy backgrounds, gradients, or custom list chrome.
