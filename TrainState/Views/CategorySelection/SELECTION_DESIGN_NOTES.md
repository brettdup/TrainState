# Category & Subcategory Selection – Design Style Notes

## 1. Modern iOS/visionOS Aesthetic

- **Glassy, floating surfaces:** Uses `.ultraThinMaterial` and soft backgrounds for a sense of depth and lightness.
- **Rounded corners:** Generous corner radii (16–20) on cards and controls for a friendly, approachable look.
- **Subtle shadows:** Light shadows under cards and buttons to create separation and a floating effect.

## 2. Color & Contrast

- **Accent color usage:** Each workout type and category uses a distinct, vibrant color for quick recognition and visual interest.
- **Selection feedback:** Selected items fill with a soft tint of their accent color, making choices obvious and delightful.
- **Floating action button:** The "plus" button uses a solid accent color, white icon, and border for maximum visibility.

## 3. Interaction & Feedback

- **Direct tap-to-select:** The entire card/row is tappable, with clear visual feedback.
- **Animated selection:** Checkmarks and backgrounds animate in with fade and scale for a lively, tactile feel.
- **Scale effect on tap:** Cards and rows briefly "pop" when tapped, mimicking native button feedback.
- **Haptic feedback:** Medium haptic for category, light for subcategory, reinforcing the action.

## 4. Layout & Spacing

- **Floating header:** The header is glassy, compact, and visually separated from content.
- **Minimal padding:** Spacing is tight but comfortable, avoiding visual clutter.
- **No double cards:** Only one layer of card/background per element for clarity.

## 5. Accessibility & Usability

- **Large tap targets:** All interactive elements are easy to tap.
- **High contrast:** Text and icons are readable on all backgrounds.
- **VoiceOver-friendly:** Selection state is visually and programmatically clear.

## 6. Animations

- **EaseInOut transitions:** All state changes use `.easeInOut(duration: 0.18)` for smooth, non-bouncy feedback.
- **No spring animations:** Keeps the experience calm and professional.

## 7. Visual Hierarchy

- **Primary actions (Done, Add) are prominent:** The "Done" button and floating "plus" button are always visible and easy to reach.
- **Selected items stand out:** Use of color and animation ensures users always know what's selected.

---

### Summary

This design style is inspired by the latest iOS and visionOS guidelines, focusing on clarity, delight, and directness. It uses color, glass, and animation to create a modern, premium, and highly usable experience.
