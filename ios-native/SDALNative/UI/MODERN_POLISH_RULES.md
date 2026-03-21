# Modern Polish Rules

These rules apply to new and refactored SDAL iOS UI work.

1. Depth and materials
Use `.background(.ultraThinMaterial)` or hierarchical semantic system colors instead of flat fills.
Cards should include a subtle 1pt inner stroke to create a glass effect.

2. Motion
Avoid linear animation.
Interactive state changes should use `.spring(response: 0.4, dampingFraction: 0.8)`.
Interactive controls should include `.scaleEffect(isPressed ? 0.96 : 1.0)`.

3. Sensory feedback
Add light or medium haptics to button presses and successful completions.

4. Typography and spacing
Prefer Dynamic Type styles such as `.title2` and `.subheadline`.
Use rounded typography styling where practical to echo SF Pro Rounded.
Increase spacing and use `foregroundStyle(.secondary)` for metadata.

5. Iconography
Prefer SF Symbols with `.symbolRenderingMode(.hierarchical)`.
Use `.symbolEffect(.pulse)` for active or emphasized states where it adds value.

6. Adaptive design
Use semantic colors like `Color(uiColor: .systemGroupedBackground)` and related grouped/system fills so views adapt to Dark Mode and accessibility contrast automatically.
