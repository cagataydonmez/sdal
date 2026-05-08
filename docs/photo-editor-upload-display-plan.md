# Photo Editor, Upload, Preview, and Lightbox Stabilization Plan

Date: 2026-05-08
Status: Direction changed after review. The new implementation target is crop-only image preparation with `image_cropper`; custom text/draw/blur/filter editing is no longer part of the user-facing flow for new uploads.

## Implementation Log

- 2026-05-08: Added album media payloads on the backend and Flutter album media models.
- 2026-05-08: Updated album grid, album detail, profile album previews, and album lightboxes to prefer rendered/display media URLs.
- 2026-05-08: Updated multi-photo album detail editing so the selected group item carries its own media/edit state.
- 2026-05-08: Refactored the editor stage to separate the full stage from the crop frame, with topmost dashed border and outside-frame dim overlay.
- 2026-05-08: Added selected text resize handle, larger text scale range, and hide-region corner/side handles for locked/free resize modes.
- 2026-05-08: Phase 5 — Feed: FeedVariants extended with thumbUrl/fullUrl; FeedItem.lightboxUrl getter added; SdalNetworkImage in feed_page and post_detail_page now passes lightboxImageUrl from fullUrl. Requests upload: aspectPreset set to album43. All other upload entry points were already using correct aspect presets (wide169 for groups/events/announcements, story916 for stories, square for admin broadcast). All display surfaces that had no variants (community events/announcements, group posts) continue to use their existing image field; lightbox correctly falls back to the same processed URL.
- 2026-05-08: Bug fix — zoom/pan sticking and free-rotation: InteractiveViewer minScale lowered to 0.15×base, boundaryMargin set to double.maxFinite, pinch-rotate gesture tracked via onInteractionUpdate, image wrapped with Transform.rotate; export pipeline applies img.copyRotate (expanded canvas) followed by a center-relative crop-rect formula.
- 2026-05-08: Bug fix — gallery stale after photo edit: added AlbumPhotoEditCounter Notifier + albumPhotoEditCounterProvider; album_photo_page.dart increments it after replacePhotoFile succeeds; album_category_page.dart listens and calls _load(reset: true).
- 2026-05-08: Bug fix — emoji invisible and black corners in export preview: replaced img.drawString bitmap-font pipeline with Flutter TextPainter/Canvas/PictureRecorder pipeline (supports full Unicode emoji); removed radius parameter from img.copyCrop in blur hide-region path (JPEG has no alpha, so radius filled corners with opaque black that composited as solid rectangles).
- 2026-05-08: User approved replacing the complex editor with crop-only image preparation. Existing public helper names remain temporarily for compatibility, but the helpers now route normal image preparation through native `image_cropper`.
- 2026-05-08: Added embedded multi-photo crop flow with `crop_your_image`: selected photos stay in one PageView screen, back/next navigation is available, "Bitir" is always active, and untouched photos fall back to target-ratio center crop.
- 2026-05-08: Added album upload progress UI: single uploads show a progress bar; multi-photo uploads show story-like segmented bars and `1/x`, `2/x`, `3/x` status.

## Revised Direction: Crop-Only Image Preparation

The app should not expose a full image editor for new uploads. Users should only prepare an image for the place where it will be shown.

Allowed actions:

- choose image from gallery or camera
- crop/position image inside the target aspect ratio
- rotate/reset when supported by the native cropper
- confirm or cancel

Removed from the user-facing upload flow:

- text overlays
- drawing
- blur/mosaic masking
- filters
- custom Flutter bitmap/layer export for normal uploads

Implementation rule:

- Keep existing public helper names such as `pickAndCropImage`, `pickAndEditImage`, `pickAndEditImages`, and `editImageFile` temporarily so feature screens do not need a large rewrite.
- Internally, these helpers call `image_cropper`.
- New metadata identifies `editorMode: cropOnly`.
- Older metadata remains backward compatible for existing photos, but new photos should treat the cropped output as the authoritative display image.

User-friendly layout direction from impeccable/product guidance:

- Product UI, restrained styling.
- Native cropper toolbar title should say "Fotoğrafı hazırla" or the target-specific equivalent.
- Use target-specific aspect ratios so users do not need to make layout decisions.
- Avoid multi-tab tool panels. The flow should feel like a short preparation step, not a creative editor.

## Goal

Fix photo upload, editing, preview, album cover, detail carousel, post media, story media, community media, request attachments, notification/admin media, and lightbox behavior as one consistent app-wide media pipeline.

Primary tested surfaces:

- Profile album, multi-photo upload and edit.
- Albums, cohort album, single-photo upload and edit.
- Any shared post/album/story/group/event surface that uses the common upload/editor/lightbox widgets.

## App-Wide Scope

This plan covers the whole Flutter app, not only albums. The media pipeline must be shared across every feature that uploads, edits, previews, or opens images.

### Upload and edit entry points

Current upload/edit calls discovered with `pickAndCropImage`, `pickAndEditImage`, and `pickAndEditImages`:

- `mobile/flutter_sdal/lib/features/profile/presentation/profile_photo_page.dart`
- `mobile/flutter_sdal/lib/features/profile/presentation/profile_verification_page.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/feed_page.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/feed_edit_text_dialog.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/album_upload_page.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/album_photo_page.dart`
- `mobile/flutter_sdal/lib/features/requests/presentation/requests_page.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/events_page.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/announcements_page.dart`
- `mobile/flutter_sdal/lib/features/groups/presentation/group_detail_page.dart`
- `mobile/flutter_sdal/lib/features/stories/presentation/stories_rail.dart`
- `mobile/flutter_sdal/lib/features/admin/presentation/admin_pages.dart`

Required behavior for every upload entry:

- The editor opens with the target surface's intended aspect ratio.
- The intended target crop is shown as a topmost dashed border.
- Image areas outside the crop frame remain visible but dimmed under a transparent black overlay.
- Pinch/zoom/drag operate relative to the crop frame, not the full screen.
- Exported result must match the visible crop frame.

Suggested target ratios:

- Profile avatar: `1:1`.
- Verification proof and request attachments: default `4:3`, unless later changed to document/freeform mode.
- Feed and group post images: current app convention `4:5`.
- Album photos and album uploads: `4:3` by default.
- Stories: `9:16`.
- Group covers, event images, announcement images: `16:9`.
- Admin broadcast images: keep `1:1` only if the destination UI is square; otherwise move to `16:9` or destination-specific ratio.

### Display and lightbox entry points

Current display/lightbox consumers discovered with `SdalNetworkImage`, `SdalLightboxImage`, `Image.network`, `Image.file`, `NetworkImage`, and `FileImage`:

- `mobile/flutter_sdal/lib/core/widgets/sdal_network_image.dart`
- `mobile/flutter_sdal/lib/core/widgets/image_lightbox.dart`
- `mobile/flutter_sdal/lib/core/widgets/remote_avatar.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/album_category_page.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/albums_page.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/album_photo_page.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/album_upload_page.dart`
- `mobile/flutter_sdal/lib/features/profile/presentation/profile_album_section.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/feed_page.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/feed_edit_text_dialog.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/post_detail_page.dart`
- `mobile/flutter_sdal/lib/features/groups/presentation/group_detail_page.dart`
- `mobile/flutter_sdal/lib/features/groups/presentation/groups_page.dart`
- `mobile/flutter_sdal/lib/features/stories/presentation/stories_rail.dart`
- `mobile/flutter_sdal/lib/features/stories/presentation/expired_stories_page.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/events_page.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/announcements_page.dart`
- `mobile/flutter_sdal/lib/features/community/presentation/entity_detail_page.dart`
- `mobile/flutter_sdal/lib/features/following/presentation/following_detail_page.dart`
- `mobile/flutter_sdal/lib/features/notifications/presentation/notifications_page.dart`
- `mobile/flutter_sdal/lib/features/admin/presentation/admin_pages.dart`

Required behavior for every display entry:

- Inline preview uses the latest rendered/display media, not the original source.
- Lightbox uses the latest rendered/display media, not the original source.
- If a thumbnail is used inline, the lightbox must use a higher-resolution display URL for the same edited output.
- When exact composition matters, use `BoxFit.contain` with neutral/dark background.
- Use `BoxFit.cover` only where the product intentionally wants a cropped card thumbnail.
- Album/profile preview components must not distort aspect ratio.

### Backend/media domains in scope

The album API is the first concrete implementation target, but the same contract should be reused for other domains:

- Albums: `server/routes/albumRoutes.js`.
- Feed posts: locate feed/post upload and media routes before implementation.
- Groups: locate group post/cover upload and media routes before implementation.
- Stories: locate story upload/media routes before implementation.
- Community events/announcements: locate community media routes before implementation.
- Requests/attachments: locate request attachment upload route before implementation.
- Profile/verification/admin images: use the shared editor and display resolver where applicable.

Implementation should not duplicate media URL construction in each feature.

## Current Findings

### 1. Editor crop frame is modeled as the viewport itself

Current editor code treats the crop area as the whole image viewport in `mobile/flutter_sdal/lib/core/media/pick_cropped_image.dart`.

Effects:

- Dashed frame is drawn inside the same stack as the image, and it can be visually covered by the image depending on child order.
- There is no explicit "outside crop area" because the viewport itself is the crop area.
- That prevents the desired interaction where the photo can remain visible outside the target crop frame under a transparent black overlay.
- Zoom-out behavior is fragile because the `InteractiveViewer` is constrained around the same rectangle that also represents the crop output.

Needed model:

- Full editor stage.
- Crop frame rect inside that stage.
- Image transform relative to the stage.
- Mask overlay outside the crop frame.
- Dashed crop frame drawn above everything.
- Export crop computed from `cropFrameRect` and image transform, not from widget viewport assumptions.

### 2. Editor state still mixes coordinate systems

Recent changes normalized drawing points, but other edit layers still mix concepts:

- Crop uses `TransformationController.toScene`.
- Text anchor and hide-region center are normalized to viewport.
- Text size is a scale multiplier, not a true normalized layer box.
- Hide-region size is normalized but resizing UX is only partially modeled.
- Output rendering uses a bitmap pipeline, but visual editing still depends on current widget layout.

Effects:

- Text, drawing, hide regions, crop, and filter can diverge when viewport size or aspect ratio changes.
- Pinch/zoom and output crop can mismatch.
- Text scale can feel stuck because sticker transform only handles gesture scale and has no corner/handle resize affordance.

Needed model:

- One internal coordinate space for all layers: normalized crop-frame space.
- Separate image transform model: `scale`, `offset`, `rotation`, `cropAspectRatio`.
- Each layer stores normalized rect/anchor relative to the crop frame.
- Export renderer consumes only this state, not screen widget positions.

### 3. "Mevcut görseli aç" is not reliable for newly edited photos

Current album detail payload exposes one `editMetadata` and one `editSourceFileName` for the opened photo. In multi-photo groups, `groupPhotos` only includes:

- `id`
- `fileName`
- `title`
- `groupIndex`

Effects:

- A newly edited third photo may not bring its own source/edit metadata when the detail page was opened through the group's canonical photo.
- The editor may fall back to the rendered/current file, or the wrong item state, depending on which photo id the detail payload represents.
- Old photos can work while newly edited grouped photos fail because their per-item edit state is not included in `groupPhotos`.

Needed model:

- Every `groupPhotos` item must include its own display file, source file, edit metadata, display dimensions, and display aspect ratio.
- "Mevcut görseli aç" must resolve the selected group item's own edit state, never the canonical item unless selected.
- If source/edit state is missing, fall back to the selected item's rendered display image with a clear warning path.

### 4. Previews and lightboxes are not using one display-media contract

Most album/profile preview widgets build URLs directly from `fileName` and `/api/media/kucukresim`.

Examples:

- `album_category_page.dart`
- `albums_page.dart`
- `profile_album_section.dart`
- `album_photo_page.dart`
- `sdal_network_image.dart`
- `image_lightbox.dart`

Effects:

- Some surfaces can show original/cached/raw image instead of the latest rendered edited image.
- Aspect ratio is lost or visually cropped because widgets often use fixed square/4:3 slots with `BoxFit.cover`.
- Lightbox and preview can disagree.
- Album cover/preview can crop the edited image instead of fitting it with a neutral background.

Needed model:

- Backend returns a canonical display media object for every photo:
  - `displayFileName`
  - `displayUrl`
  - `thumbnailUrl`
  - `lightboxUrl`
  - `sourceFileName`
  - `editMetadata`
  - `width`
  - `height`
  - `aspectRatio`
  - `isEdited`
- Flutter uses a single resolver/widget instead of manually constructing `/api/media/kucukresim?...` everywhere.

### 5. Album cover/preview aspect handling is inconsistent

Some preview widgets use `BoxFit.cover`, fixed squares, or fixed 4:3 frames.

Effects:

- The edited output's aspect ratio is not respected.
- Cropped photos appear as if the original image is back.
- Album cover previews can crop or visually distort the expected edited composition.

Needed model:

- Display media should be rendered with `BoxFit.contain` inside constrained preview slots where the goal is "show the edited photo exactly".
- Empty area should use a stable dark/neutral background.
- Only intentional feed-card designs should use `cover`, and those should be opt-in.

## Proposed Architecture

### A. Introduce an app-wide media presentation contract

Add a shared media reference shape used by every domain. Start with albums because the current user-visible bugs are there, then migrate feed, groups, stories, community, requests, admin, and profile-adjacent media to the same shape.

Initial album helper in `server/routes/albumRoutes.js`, for example:

```js
async function buildAlbumPhotoMediaPayload(photo) {
  // returns source, rendered/display, thumbnail, dimensions, aspect, edit state
}
```

Use the album helper in:

- album category photos endpoint
- photo detail endpoint
- group photo list payload
- album/category summary previews
- latest/popular/dashboard album sections

Then create or reuse equivalent helpers for:

- feed post media
- group post media and group cover media
- story media
- event and announcement media
- request attachments
- admin broadcast media
- profile/verification upload responses when they are displayed through common media widgets

Recommended payload shape:

```json
{
  "id": 123,
  "fileName": "rendered.jpg",
  "displayFileName": "rendered.jpg",
  "displayUrl": "/api/media/album-display?file=rendered.jpg",
  "thumbnailUrl": "/api/media/album-display?width=640&file=rendered.jpg",
  "lightboxUrl": "/api/media/album-display?width=1800&file=rendered.jpg",
  "sourceFileName": "source.jpg",
  "editMetadata": {},
  "width": 1200,
  "height": 900,
  "aspectRatio": 1.333333,
  "isEdited": true
}
```

Notes:

- Existing `fileName` can remain for compatibility.
- New Flutter code should prefer `displayUrl`/`thumbnailUrl`/`aspectRatio`.
- Do not rely on clients manually reconstructing paths.

### B. Make rendered edited file the authoritative display file

The server should explicitly separate:

- `source_file_name`: original or editor source.
- `rendered_file_name`: latest saved edited output.
- `file_name`/`dosyaadi`: legacy display file, kept in sync with rendered output.

Current code partly does this by replacing `file_name`, but the contract is implicit. The plan is to make it explicit in payloads and helpers.

Required server checks:

- `PUT /api/photos/:id/file` updates only the selected group item.
- It stores:
  - edited/rendered output as display file
  - source file as source
  - edit metadata against the same target photo id
  - image width/height/aspect if cheap to extract
- Category cover file should update to the rendered display file, not source.

### C. Build Flutter display-media models and a shared widget

Extend these model classes:

- `AlbumPhotoCard`
- `AlbumPhotoGroupItem`
- `AlbumPhotoDetail`
- category preview models if needed

Add fields:

- `displayUrl`
- `thumbnailUrl`
- `lightboxUrl`
- `sourceFileName`
- `editMetadata`
- `aspectRatio`
- `isEdited`

Add a helper widget/resolver used app-wide, for example:

- `SdalMediaImage`
- or extend `SdalNetworkImage` with a `SdalMediaRef`.

This widget should handle:

- preview URL
- lightbox URL
- fit mode
- neutral background
- cache width/height
- edited/original consistency

All feature-specific image widgets should either use this helper directly or pass through `SdalNetworkImage` after it is upgraded to accept the shared media reference.

### D. Refactor editor stage around crop frame

Replace the current "viewport is crop" editor with:

- full stage rect
- crop frame rect computed from target aspect ratio and available stage
- image layer drawn behind/through crop frame
- semi-transparent black mask outside crop frame
- dashed border above mask and image
- gesture transform applies to image layer

Interaction behavior:

- The dashed crop frame is always topmost.
- Outside crop frame image remains visible but dimmed.
- User can pinch zoom in/out and drag the image relative to the frame.
- Zoom-out should not snap to top-left.
- If the image becomes smaller than crop frame, center it and clamp only enough to avoid unintended empty crop output, unless we intentionally support background fill.

Export behavior:

- Compute crop rect by inverting the image transform from crop-frame corners into source bitmap coordinates.
- Apply crop, rotation, filters, draw, hide, and text in one bitmap pipeline.
- Export result dimensions should match crop frame aspect.

### E. Normalize all edit layers to crop-frame space

Layer state should be relative to the crop frame, not the full screen.

Store:

- drawing points: normalized crop-frame points
- hide-region rect: normalized crop-frame rect
- text layer rect/anchor: normalized crop-frame rect
- text scale/font size: normalized to crop frame width or output width
- filters: numeric adjustments
- crop/image transform: normalized offset + scale + rotation

Benefits:

- Reopening an edit on a different device keeps layers aligned.
- Export matches preview.
- Multi-photo editing becomes predictable.

### F. Add resize handles for text and hide-region layers

For text:

- Select text layer.
- Show handles around bounding box.
- Drag corners to resize text.
- Drag middle/box to move.
- Optional pinch remains supported.

For hide-region:

- `Kilitli`: corner drag preserves aspect ratio.
- `Serbest`: side handles resize width/height independently, corner handles resize both.
- Keep the existing `Kilitli / Serbest` toggle.

Layer handles should be visible only when the layer is selected and not during export.

### G. Update all album/profile preview components

Replace manual thumbnail URL creation with the display-media helper in:

- `album_category_page.dart`
- `albums_page.dart`
- `album_photo_page.dart`
- `profile_album_section.dart`
- any dashboard/latest/popular album photo list

Rules:

- Detail page photo viewer: use display/lightbox URL and actual edited aspect when possible.
- Album grid thumbnail: if design slot is fixed, use `contain` plus neutral background unless the product intentionally wants cropping.
- Album cover/preview: preserve edited image aspect; empty space should be dark/neutral background.
- Multi-photo stacked preview: stack frame should preserve displayed edited photo.

### H. Update lightbox behavior globally

`SdalLightboxImage` currently receives a single `ImageProvider`. It should support:

- preview provider for the on-screen child
- full/lightbox provider for the opened view
- explicit `BoxFit.contain`
- optional aspect ratio metadata for initial layout

Recommended:

- `SdalNetworkImage` uses thumbnail for inline display and `lightboxUrl` for full screen.
- Lightbox should never reopen the raw/original source unless the source is explicitly intended.

## Implementation Phases

### Phase 0, App-Wide Inventory and Ratios

Goal: lock the app-wide upload/display inventory before code changes.

Tasks:

1. Confirm every upload entry point listed in "App-Wide Scope".
2. Confirm every display/lightbox entry point listed in "App-Wide Scope".
3. Assign a target aspect ratio and display fit policy to every entry point.
4. Document exceptions where original/freeform display is intentional.
5. Add code comments or constants for target aspect presets so features do not silently drift.

Acceptance tests:

- No upload entry calls the editor without an intentional target ratio.
- No display entry manually builds a media URL when a shared resolver exists.

### Phase 1, Album Data Contract and Display Consistency

Goal: make every album surface use the same displayed edited image. This is first because the user's current reproduction cases are album-specific.

Tasks:

1. Add backend media payload helper for album photos.
2. Include media payload in photo detail, group photos, category grid photos, category summaries/previews.
3. Extend Flutter album models with media fields.
4. Add `SdalMediaImage` or extend `SdalNetworkImage`.
5. Replace direct `/api/media/kucukresim` construction in album/profile photo surfaces.
6. Ensure lightbox uses `lightboxUrl`, not thumbnail or original source.

Acceptance tests:

- Upload edited/cropped single photo to cohort album.
- Album grid shows the edited crop.
- Album detail shows the edited crop.
- Lightbox shows the edited crop.
- Profile album preview shows the edited crop.
- Cache-busting or unique filename prevents stale thumbnail display.

### Phase 2, Multi-Photo Edit State Correctness

Goal: selected group item always edits and saves its own state.

Tasks:

1. Add per-photo edit state to each `groupPhotos` payload item.
2. Update Flutter `AlbumPhotoGroupItem` to carry source/edit/display fields.
3. Make "Mevcut görseli aç" use selected item state.
4. Ensure replacement sends selected item id and group index.
5. Add server guard that group index and id refer to the same group item.

Acceptance tests:

- Upload 3-photo group.
- Open group detail from first photo.
- Select third photo.
- Open current image.
- Draw and save.
- Only third photo changes.
- First photo remains unchanged.
- Reopen third photo, current image includes the last edit state.

### Phase 3, Editor Stage Refactor

Goal: fix dashed border, overlay, zoom-out, crop mismatch, and tool alignment.

Tasks:

1. Replace current viewport-as-crop layout with full-stage + crop-frame layout.
2. Draw image behind the crop frame.
3. Draw transparent black overlay outside crop frame.
4. Draw dashed border topmost.
5. Store image transform independently from `InteractiveViewer` quirks.
6. Compute export crop by inverse transform from crop frame to source bitmap.
7. Keep filters/draw/hide/text rendering in one bitmap export pipeline.

Acceptance tests:

- Dashed border is always visible above photo.
- Outside crop frame is dimmed.
- Zoom out does not stick to top-left.
- Photo can be moved under crop frame.
- Export matches preview for crop, rotation, and filters.

### Phase 4, Layer Tool Robustness

Goal: make text/draw/hide/filter match preview and export.

Tasks:

1. Normalize all layer coordinates to crop-frame space.
2. Add text resize handles.
3. Add hide-region resize handles.
4. Keep hide-region aspect lock toggle.
5. Add direct width/height sliders for unlocked hide regions.
6. Ensure text and hide layers do not drift after aspect or viewport changes.

Acceptance tests:

- Add text, resize it, move it, save, reopen, verify same position/size.
- Add hide blur, locked resize, save, verify same output.
- Toggle hide to free size, drag side/corner handles, save, verify same output.
- Draw a line near image edge, save, verify line is not shifted.
- Apply filter, save, verify output and thumbnail match.

### Phase 5, App-Wide Media Migration

Goal: apply the shared media contract beyond albums.

Tasks:

1. Migrate feed post image upload/display to shared editor ratio and display media helper.
2. Migrate group post image and group cover media.
3. Migrate story upload/display.
4. Migrate event and announcement image upload/display.
5. Migrate request attachment previews where image attachments use the photo editor.
6. Migrate notification/admin broadcast image display where applicable.
7. Keep profile avatars separate only where avatar-specific square media handling is intentional.

Acceptance tests:

- A feed post edited image appears identically in composer preview, feed card, detail, and lightbox.
- A group post edited image appears identically in group detail and lightbox.
- A story edited image respects 9:16 in preview and viewer.
- Event/announcement edited images respect 16:9.
- Request attachment image preview and lightbox use the edited output.

### Phase 6, Cross-Surface Regression Matrix

Run the same photo through:

- profile photo
- profile album multi-photo
- cohort album single-photo
- feed post image
- group post image
- story image
- event image
- announcement image
- request attachment

For each:

- initial crop frame ratio matches target use
- preview matches edited output
- detail page matches edited output
- lightbox matches edited output
- re-edit current image works

## Bug Fixes (post-Phase 5)

### Bug 1 — Zoom-out sticking and free rotation

**Symptom:** When the user zoomed out during cropping, the photo snapped to the top edge and could not be panned freely. Pinch-to-rotate was not supported.

**Root cause:**
- `InteractiveViewer.minScale` was set to `_baseScale`, preventing zoom below fill level.
- `boundaryMargin: EdgeInsets.all(320)` created a hard boundary that caused the snapping.
- Both `_setImageTransform` and `_updateViewport` clamped the zoom to `(1.0, 6.0)`, reinforcing the restriction.
- `InteractiveViewer` has no native rotation support.

**Fix (`lib/core/media/pick_cropped_image.dart`):**
- `minScale` changed to `_baseScale * 0.15`; both zoom clamps changed to `(0.15, 6.0)`.
- `boundaryMargin` set to `const EdgeInsets.all(double.maxFinite)`.
- Added `double _freeRotationAngle` state. The image content is wrapped in `Transform.rotate(angle: _freeRotationAngle)` inside the InteractiveViewer's scene SizedBox.
- `onInteractionStart` saves the angle at gesture start; `onInteractionUpdate` accumulates `ScaleUpdateDetails.rotation` when two or more fingers are active.
- Quarter-turn rotation (rotate button) resets `_freeRotationAngle` to 0.
- `freeRotationAngle` is serialized into edit metadata for round-trip restore.
- **Export:** After `_applyQuarterTurns`, `img.copyRotate` is applied (which expands the canvas). The crop rect in the expanded bitmap uses the formula `bx = expandedW/2 + (sceneX − displayCenterX) × scale`, which is correct when scaleX == scaleY (always true here because both the display size and the bitmap are constrained from the same image aspect ratio). A dedicated `_resolveCropRectInFreeRotatedBitmap` method implements this mapping.

### Bug 2 — Gallery/category page shows original photo after an edit

**Symptom:** After saving a photo edit in `AlbumPhotoPage`, navigating back to `AlbumCategoryPage` showed the old unedited thumbnail. The stale photo only updated after the app was fully restarted or the category page was manually re-navigated to.

**Root cause:** `AlbumCategoryPage` loads its photo list into local state (`_detail`) on `initState`. Saving in `AlbumPhotoPage` only invalidated `albumPhotoLikesProvider` and called the photo-page-local `_load()`. No signal reached the category page's state.

**Fix:**
- `lib/features/albums/data/albums_repository.dart`: Added `AlbumPhotoEditCounter` Notifier and `albumPhotoEditCounterProvider`.
- `lib/features/albums/presentation/album_photo_page.dart`: After a successful `replacePhotoFile`, calls `ref.read(albumPhotoEditCounterProvider.notifier).increment()`.
- `lib/features/albums/presentation/album_category_page.dart`: `ref.listen<int>(albumPhotoEditCounterProvider, ...)` in `build` calls `_load(reset: true)` whenever the counter changes, forcing a fresh category photo list from the server.

### Bug 3 — Emoji invisible and black corners in export preview

**Symptom:** In the pre-save export preview (and final saved JPEG), text stickers containing emoji or special Unicode characters appeared as blank/invisible. Hide-region blur overlays showed solid black corners instead of rounded ones.

**Root cause (emoji):** `_paintStickersOnBitmap` used `img.drawString` with `img.arial14/24/48` bitmap fonts. These fonts only contain ASCII codepoints; Unicode/emoji characters are silently skipped.

**Root cause (black corners):** `img.copyCrop(image, ..., radius: radius)` was used to sample the blur region from the JPEG bitmap. The `image` package's `copyCrop` fills outside-rounded-rect pixels with `transparent` (RGBA 0,0,0,0), but JPEG images have no alpha channel so these become opaque black `(0,0,0,255)`. When the blurred sample was composited back with `img.compositeImage`, the solid black corner pixels overwrote the background.

**Fix (`lib/core/media/pick_cropped_image.dart`):**
- `_paintStickersOnBitmap` converted from `void` to `Future<void>` and rewritten using Flutter's `TextPainter` + `Canvas` + `ui.PictureRecorder` pipeline. The rendered sticker (background + text with shadows and emoji) is rasterized to `ui.Image`, converted via `ui.ImageByteFormat.rawRgba` to an `img.Image`, and alpha-composited onto the export bitmap. Full Unicode and emoji are now supported.
- The `await _paintStickersOnBitmap(cropped)` call in `_buildExportBitmap` is now awaited.
- Removed `radius: radius` from the `img.copyCrop` call in `_paintHideRegionsOnBitmap` for the blur path. The rectangular blur sample is composited back without corner rounding; the subsequent `img.fillRect(..., radius: radius)` dark overlay still renders with rounded corners to provide visual edge softening.

## Validation Commands

Narrow checks after each phase:

```bash
cd mobile/flutter_sdal
dart analyze lib/core/media/pick_cropped_image.dart lib/core/widgets/image_lightbox.dart lib/core/widgets/sdal_network_image.dart
dart analyze lib/features/albums lib/features/profile
```

Server checks:

```bash
node --check server/routes/albumRoutes.js
```

If backend payload changes touch shared route helpers, also run targeted Node syntax checks for edited route files.

## Rollout Notes

- Keep backward compatibility for existing photos that only have `fileName`.
- If `displayUrl` is missing, fallback to current `/api/media/kucukresim` behavior.
- If `aspectRatio` is missing, default to current layout ratio.
- Avoid database migration unless needed. If dimensions/aspect are stored, add migration and backfill lazily from image metadata.
- Prefer unique rendered filenames and stable cache behavior over query-only cache busting.

## Open Decisions for Review

1. Should album grid thumbnails show the entire edited image with dark padding everywhere, or should some dense grids still use cover-crop by design?
2. Should feed posts remain `4:5`, or should they use a freer crop depending on selected image?
3. Should request attachments keep the default `4:3`, or remain freeform because they may be documents/screenshots?
4. Should edited image dimensions be stored in DB, or computed lazily and returned from backend when available?
5. Should we introduce a separate edited media endpoint, for example `/api/media/album-display`, or keep using `/api/media/kucukresim` with richer payloads?

## Proposed First Implementation After Approval

Start with Phase 0 as a quick verification checklist, then Phase 1 and Phase 2 together. This fixes the most visible correctness bugs while keeping the app-wide target in view:

- previews/lightboxes show edited output
- multi-photo "current image" uses the selected item
- album covers stop showing the wrong/original image

Then move to Phase 3 and Phase 4 for the deeper editor interaction refactor.
