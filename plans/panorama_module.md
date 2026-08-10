# Panorama Module (V2.0): 🚧 PLANNED - Split One Wide Photo Into a 4:5 Carousel

**Goal:** Turn a single wide/panoramic photo into N tiles of 4:5 that the user uploads to Instagram as a carousel, so the shot reads as one continuous panorama when swiped — instead of being posted as a 16:9 or 21:9 image that gets shown tiny in the feed.

**Status:** 🚧 Planned and specced — no code written yet. This section is the executable spec; work through it in the Build Order at the bottom.

**Related:** background-color suggestions (dominant colors picked from the photo, offered alongside White/Black/Blur) are planned as an addition on top of this editor — see `plans/color_picking.md`. Product decision there: ship in this editor first, since a panorama has exactly one source photo and no ambiguity about whose colors to suggest.

---

## 🧠 **The Core Insight (read this first)**

**N tiles of 4:5 side by side = one canvas of aspect ratio `N × 0.8`.**

```
4 tiles × 4:5  →  canvas 3.20:1

┌──────┬──────┬──────┬──────┐
│      │      │      │      │
│  1   │  2   │  3   │  4   │   ← each tile is exactly 1080 × 1350
│      │      │      │      │
└──────┴──────┴──────┴──────┘
        canvas 4320 × 1350
```

So panorama is **not a new pipeline**. It is *"frame the photo into an N×0.8 canvas using the existing framer engine, then slice it into N equal columns."* The existing `_createCanvasWithBackground`, `_overlayScaledImage` and `_generateFastBlurBackground` are reused verbatim — padding and panorama are the same feature with a derived aspect ratio and a slice step.

---

## 🎯 **Product Decisions (settled — do not re-litigate)**

1. **Fit / Fill toggle**
   - ✅ **Fit** - contain-fit into the canvas, pad the leftover with White/Black/Blur, scale slider active. Nothing is cropped away — this matters because panorama shooters deliberately frame content at the edges.
   - ✅ **Fill** - cover-fit + centre crop, no bars. Background and scale controls are hidden (removed from the tree, not disabled).
2. **No free pan/zoom reframe in V1** - the existing 0.5–1.0 scale slider, plus a **seam-nudge offset slider** (see below). A draggable crop rect is a V2 candidate.
3. **✅ Seam-nudge IS in V1** - a single horizontal offset slider (±half a tile) that shifts the image within the canvas so seams don't land on a face or subject. *Originally scoped to V2; promoted to V1 because the fit-to-width preview is only ~112pt tall at 4 tiles — the user can barely see a bad seam, and without this they'd have no way to fix one. "See a problem you can't fix" is worse than not showing it.*
   - ✅ **Its initial value is computed, not zero** - see [🤖 Smart Defaults](#-smart-defaults). The slider is an override, not a chore.
4. **Tile count: auto-suggest + override** - preselect `round(sourceAspect / 0.8)` clamped to the valid range, user can override via a pill row, with a live canvas-ratio hint.
5. **Hard eligibility gate, generous limits** - source aspect > 1.2 **and** source width ≥ 2160px (2 tiles × 1080). Ineligible sources are not offered panorama, with a one-line reason.
6. **Name: "Panorama Carousel"** - **not** "Create Panorama". In every camera app "create panorama" means *stitching photos together*; this does the opposite. Naming the output rather than the operation removes the ambiguity, and "carousel" signals the Instagram context. Use this string on the home button and the share dialog option.
7. **Tiles are saved in REVERSE order** - see [Export](#-export). Non-obvious and load-bearing.
8. **The share dialog gets a Cancel action** - barrier-tap and back-button dismissal stay disabled (no ambiguous state), but a plain text Cancel clears the bloc and returns Home. Non-dismissable should mean "make a deliberate choice", not "you are trapped" — an accidental share otherwise costs two dialogs and a gallery duplicate to undo.

---

## ⚠️ **Four Hazards This Design Solves (do not lose these)**

1. **Gallery ordering** - `ExportService.exportPhotos` runs batches of **3 concurrently** via `Future.wait`. Tiles could hit MediaStore out of order, and Instagram's picker sorts by date — which would scramble the panorama. Panorama export must be **strictly sequential**.
2. **EXIF** - `_preserveMetadata` re-injects the source's APP1 segment byte-for-byte. On a tile, `ImageWidth`/`ImageLength` describe an image that no longer exists, the embedded thumbnail shows the whole source, and an `Orientation` of 6 would rotate a tile we just baked upright.
3. **Progress contract** - `PhotosProcessingState.progress = current / total` and `editor_screen.dart:567`'s `state.photos[state.current.clamp(0, photos.length - 1)]` are *structurally* a per-source-photo contract. 1 photo → N outputs breaks it.
4. **Warm-share double-push** - a share arriving while the editor is open goes `PhotosLoadedState → PhotosLoadingState → PhotosLoadedState`, which passes `HomeScreen`'s `listenWhen` and pushes a **second** `EditorScreen`. Pre-existing bug; the mode dialog would compound it.

---

## ✅ **Verified API Facts (checked against the pub cache, not assumed)**

- **`AssetEntity.orientatedWidth` / `orientatedHeight`** exist (`photo_manager-3.8.3/lib/src/types/entity.dart:487,490`) and swap w/h for EXIF-rotated assets. **Eligibility must use these, not raw `width`/`height`** — an EXIF-rotated wide photo reports portrait dimensions on Android and would be wrongly rejected. Both can be `0` when EXIF parsing fails, which needs its own reason string.
- **`img.copyCrop(src, {x, y, width, height})`** exists in `image-4.7.1` and self-clamps to source bounds.
- Reading dimensions is **free** — they come from the MediaStore row, no decode and no I/O.

---

## 🏗️ **Architecture: a separate `PanoramaBloc`**

Not an extension of `PhotoBloc`. Justification:

1. **Simpler, not branchier** - all eight existing `PhotoBloc` handlers guard on `state is PhotosLoadedState`; panorama would add `if (isPanorama)` to each, plus nullable `tileCount`/`fitMode` fields meaningless to the framer.
2. **Resolves Hazard 3 for free** - a separate state class leaves the framer's progress contract completely untouched.
3. **Sharing happens at the right layer** - `ImageProcessor`, `ExportService` and `PanoramaSpec` are shared; two blocs sharing zero mutable state is not duplication.

**Files to Create:**

1. **`lib/blocs/panorama_bloc/panorama_event.dart`**
   - ✅ `PanoramaSourceSelectedEvent(AssetEntity source)`
   - ✅ `UpdateTileCountEvent(int tileCount)`
   - ✅ `UpdateFitModeEvent(PanoramaFitMode fitMode)`
   - ✅ `UpdatePanoramaScaleEvent(double scale)`
   - ✅ `UpdatePanoramaBackgroundTypeEvent(BackgroundType backgroundType)`
   - ✅ `UpdatePanoramaBlurIntensityEvent(int intensity)`
   - ✅ `ExportPanoramaEvent()`, `DismissPanoramaErrorEvent()`, `ClearPanoramaEvent()`

2. **`lib/blocs/panorama_bloc/panorama_state.dart`**
   ```dart
   class PanoramaInitialState    extends PanoramaState {}
   class PanoramaIneligibleState extends PanoramaState { final String reason; }   // terminal

   class PanoramaReadyState extends PanoramaState {
     final AssetEntity source;
     final int sourceWidth;   // orientation-normalised, so the UI never touches AssetEntity
     final int sourceHeight;
     final int maxTiles;
     final PanoramaSettings settings;
     final List<double> energyProfile;  // see Smart Defaults — EXCLUDED from props
     double get sourceAspect => sourceWidth / sourceHeight;
     PanoramaReadyState copyWith({PanoramaSettings? settings});
   }

   class PanoramaExportingState extends PanoramaState {
     final PanoramaExportPhase phase;   // rendering | saving
     final int saved, total;
     double get progress => total == 0 ? 0 : saved / total;
   }

   class PanoramaExportedState extends PanoramaState { final int tileCount; }    // terminal
   class PanoramaErrorState    extends PanoramaState { final String message; final PanoramaReadyState previous; }
   ```

3. **`lib/blocs/panorama_bloc/panorama_bloc.dart`**
   - ✅ Constructed with injected `ExportService` + `PreferencesService` (existing convention)
   - ✅ Registered as a **third provider** in `lib/main.dart`'s `MultiBlocProvider`
   - ✅ Scale/blur reuse the existing `lastUsedScale` / `lastUsedBlurIntensity` prefs keys, re-saved on change exactly like `PhotoBloc._onUpdateScale` — **`UserPreferences` needs no new fields and no JSON migration**
   - ✅ `_onPanoramaSourceSelected` also awaits `computeEdgeEnergyProfile(thumbnail)` and seeds `settings.seamOffset` from `bestSeamOffset(...)` — the slider opens at a good position, not zero
   - ✅ `_onUpdateTileCountEvent` and `_onUpdateFitModeEvent` **re-run `bestSeamOffset`** from the cached profile (pure Dart, microseconds) — seam positions change with tile count, so a good offset for 4 tiles is not a good offset for 5
   - ⚠️ **Once the user drags the seam slider, stop re-optimising.** Track a `seamOffsetIsManual` flag on `PanoramaSettings`; silently overriding a deliberate adjustment is worse than a mediocre default. Reset it if the user picks a new source.

**❌ Do NOT copy the error-recovery pattern from `PhotoBloc._onExportAllPhotos` (lines 397-400):**

```dart
// ❌ WRONG - this is the auto-state-cycling the Development Rules forbid
emit(PhotoErrorState('Export failed: $e'));
await Future.delayed(const Duration(seconds: 2));
emit(currentState);
```

```dart
// ✅ RIGHT - error state carries the state to return to; the UI decides when
emit(PanoramaErrorState(message: 'Export failed: $e', previous: currentState));
// editor's listenWhen-gated listener shows the snackbar, then dispatches
// DismissPanoramaErrorEvent, whose handler emits event-carried `previous`
```

---

## 📦 **Models**

**Files to Create:**

1. **`lib/models/panorama_spec.dart`** — constants + eligibility. Takes plain `int`s so the models layer never imports `photo_manager`.
   ```dart
   static const double tileRatio       = 4 / 5;   // 0.8
   static const int    minTiles        = 2;
   static const int    maxTilesCap     = 10;
   static const double minSourceAspect = 1.2;
   static const int    minTileWidth    = 1080;    // used for BOTH the gate and the max-tile cap

   static PanoramaEligibility evaluate({required int sourceWidth, required int sourceHeight});
   static double canvasRatio(int tileCount) => tileCount * tileRatio;
   ```
   `evaluate` checks **in order, first failure wins**, so the message is always the most actionable:
   - ✅ `width == 0 || height == 0` → *"Couldn't read this photo's dimensions."*
   - ✅ `aspect <= 1.2` → *"This photo isn't wide enough for a panorama — it needs to be wider than 6:5."*
   - ✅ `width < 2160` → *"This photo is too low-resolution for a panorama — it needs to be at least 2160px wide."*

   Then `maxTiles = (width ~/ 1080).clamp(2, 10)` and `suggestedTiles = (aspect / 0.8).round().clamp(2, maxTiles)`. Use the **constant** 1080 for the cap, not the user's configured tile width — eligibility is computed inside `PhotoBloc` before prefs are loaded, and this keeps it identical to the editor's cap.

2. **`lib/models/panorama_settings.dart`**
   ```dart
   enum PanoramaFitMode { fit, fill }

   class PanoramaSettings extends Equatable {
     final int tileCount;
     final PanoramaFitMode fitMode;
     final double scale;                  // 0.5–1.0, Fit only
     final BackgroundType backgroundType; // Fit only
     final int blurIntensity, imageQuality, tileWidth;
     final double seamOffset;             // -0.5..0.5, in TILE WIDTHS. 0 = centred.
     final bool seamOffsetIsManual;       // true once the user drags the slider

     int    get tileHeight   => (tileWidth / PanoramaSpec.tileRatio).round();
     int    get canvasWidth  => tileWidth * tileCount;   // exact multiple — see sizing note
     int    get canvasHeight => tileHeight;
     double get canvasRatio  => tileCount * PanoramaSpec.tileRatio;

     /// Horizontal pixel shift applied when compositing. Expressed in tile
     /// widths so the slider means the same thing at every tile count.
     int get seamOffsetPx => (seamOffset * tileWidth).round();
   }
   ```
   `seamOffset` is stored in **tile widths, not pixels or canvas fractions**, so dragging the slider halfway always moves the image by half a tile regardless of `tileCount` or `tileWidth`. Range ±0.5 — a full tile of travel is enough to move any subject off any seam, and clamping there stops the user sliding the photo off the canvas.
   Standalone rather than wrapping `PhotoSettings` — `aspectRatio` is meaningless here because the canvas ratio is *derived* from `tileCount`, and pushing `tileCount`/`fitMode` into `PhotoSettings` would leak panorama concepts into `_processImageInIsolate` and the framer's `copyWith`.

**❌ Do NOT build a synthetic `models.AspectRatio` for the canvas.** Its only two consumers are the crop maths (ints) and the `AspectRatio` **widget** (a plain `double`); `settings.canvasRatio` serves both. This guarantees nothing can leak into `AspectRatios.all`, which `editor_screen.dart:308` renders dynamically into the framer's ratio row. **`lib/models/aspect_ratio.dart` is not modified at all.**

---

## ⚙️ **Image Processing**

**File Modified: `lib/services/image_processor.dart`**

A new method on the existing class, **not** a new `PanoramaProcessor` service — `_createCanvasWithBackground`, `_overlayScaledImage` and `_generateFastBlurBackground` are file-private statics, so a separate service could only reuse them by widening visibility or copying. Adding a method keeps the isolate boundary in exactly one place.

```dart
/// Renders the source into an N×0.8 canvas and slices it into [tileCount]
/// equal-width 4:5 tiles, in left-to-right order.
Future<List<Uint8List>> processPanorama(Uint8List sourceBytes, PanoramaSettings settings)
  => compute(_processPanoramaInIsolate, _PanoramaProcessingParams(...));
```

**One isolate call, not N.** Decode + blur background + cubic resize is >90% of the cost and is **canvas-global** — it cannot be done per tile without redoing it N times, and N calls would re-ship the full source bytes across the isolate boundary N times. One call = one decode, one canvas render, N `copyCrop` + N `encodeJpg`. At N=10 the canvas is 10800×1350 RGBA ≈ 58 MB plus the decoded source; **`maxTilesCap = 10` is what bounds this**.

**Isolate body:**

1. ✅ `img.decodeImage`
2. ✅ **Bake EXIF rotation, guarded:**
   ```dart
   // bakeOrientation does an unconditional full-image copy BEFORE checking
   // whether there's anything to do — ~48 MB wasted on a 12 MP source.
   if (src.exif.imageIfd.hasOrientation && src.exif.imageIfd.orientation != 1) {
     src = img.bakeOrientation(src);
   }
   ```
3. ✅ **Fill** → `_coverCropResize(src, cw, ch, offsetX: s.seamOffsetPx)` · **Fit** → `_createCanvasWithBackground` (background stays centred, `offsetX: 0`) + `_overlayScaledImage(..., offsetX: s.seamOffsetPx)`
4. ✅ Slice: `for i in 0..tileCount` → `img.copyCrop(canvas, x: i * tileWidth, y: 0, width: tileWidth, height: tileHeight)` → `encodeJpg(quality: imageQuality.clamp(70, 95))`

**Threading the seam offset.** Both `_overlayScaledImage` and `_coverCropResize` gain a **required** named `int offsetX` — required, not defaulted, so every call site states its intent (the Development Rules forbid compatibility defaults). Three call sites:

| Caller | `offsetX` | Why |
|--------|-----------|-----|
| Framer `_processImageInIsolate` | `0` | no seam concept |
| Panorama photo overlay / cover crop | `settings.seamOffsetPx` | this is the whole point |
| Blur background generation | `0` | the background stays put while the photo slides — shifting both would defeat the nudge |

In `_overlayScaledImage` the change is one line — `final x = (targetSize.width - w) ~/ 2 + offsetX;`. In `_coverCropResize` the crop window shifts: `x: ((src.width - cropW) ~/ 2 + scaledOffset).clamp(0, src.width - cropW)`, where `scaledOffset` converts canvas pixels to source pixels (`offsetX * cropW / targetW`). **Clamping matters** — at extreme offsets an unclamped crop window would run past the source edge and `copyCrop` would silently return a smaller image, breaking the exact-multiple tiling.

**🔧 Load-bearing sizing detail — derive height first, make width an exact multiple:**

```dart
// ✅ RIGHT — tiles tile the canvas perfectly: zero overlap, zero gap
tileHeight   = (tileWidth / 0.8).round();     // 1350
canvasHeight = tileHeight;                     // 1350
canvasWidth  = tileWidth * tileCount;          // exact integer multiple
```

```dart
// ❌ WRONG — the shape _calculateTargetSize:73-77 uses. Rounding here produces
// sub-pixel drift that shows up as a duplicated or missing pixel column at a seam.
canvasHeight = (canvasWidth / canvasRatio).round();
```

`copyCrop` self-clamps, so there's no out-of-bounds risk either way — but self-clamping would silently produce a **narrower final tile**. The exact-multiple arithmetic means it never triggers. Note `_calculateTargetSize` is **not** reused for panorama: it takes width from `settings.imageSize.width` and would give a 1080-wide canvas, i.e. 1080/N-wide tiles.

**New static — `_coverCropResize`** (used by both the Fill path and the blur fix below):

```dart
/// Centre-crops [src] to the target aspect, then resizes to exactly [targetW]×[targetH].
static img.Image _coverCropResize(img.Image src, int targetW, int targetH) {
  final srcAspect = src.width / src.height;
  final dstAspect = targetW / targetH;
  final int cropW, cropH;
  if (srcAspect > dstAspect) {          // source wider than canvas → crop sides
    cropH = src.height;
    cropW = (src.height * dstAspect).round();
  } else {                              // source taller → crop top & bottom
    cropW = src.width;
    cropH = (src.width / dstAspect).round();
  }
  final cropped = img.copyCrop(src,
      x: (src.width - cropW) ~/ 2, y: (src.height - cropH) ~/ 2,
      width: cropW, height: cropH);
  return img.copyResize(cropped,
      width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
}
```

**🔧 Required fix (not polish): `_generateFastBlurBackground` stretches, it doesn't cover.**

Lines 148-154 resize the blurred low-res image to *exactly* `targetSize` — a **stretch**, not a cover. On a 4:5 canvas the distortion is unnoticeable. On a 3.2:1 panorama canvas the background is stretched **4× horizontally** into a visible smear, and it wouldn't match the widget-composited preview.

**Before:**
```dart
// 3. Upscale to fill target
// 'cover' logic: crop to fill          ← comment claims cover, code stretches
return img.copyResize(lowRes,
    width: targetSize.width, height: targetSize.height,
    interpolation: img.Interpolation.linear);
```

**After:**
```dart
// 3. Cover the target: centre-crop to the target aspect, then upscale.
return _coverCropResize(lowRes, targetSize.width, targetSize.height);
```

This slightly changes existing framer blur output — for the better, and it makes preview and export agree in both modules. Per the Development Rules, **no compatibility flag is added**.

**🏷️ EXIF: panorama tiles carry none.** There is no correct "slice of" EXIF short of rewriting IFD entries — a large lift for zero user value (see Hazard 2). `exportPanorama` takes **no `preserveMetadata` parameter** and never calls `_preserveMetadata`. `img.encodeJpg` writes no EXIF and orientation is baked, so tiles are self-consistent. Surface the divergence from the global pref with one line under the export button: *"Camera and location info isn't copied to panorama tiles."*

---

## 📤 **Export**

**File Modified: `lib/services/export_service.dart`** — a new method. **`exportPhotos` is unchanged.** Different input, output cardinality, concurrency, naming and metadata policy; folding both into one method means four boolean flags, which is the config-knob indirection the Development Rules forbid.

`PanoramaExportPhase` goes in **`lib/models/enums.dart`** (see the Step 1 convention note), not declared inline in `export_service.dart`:

```dart
enum PanoramaExportPhase { rendering, saving }
class PanoramaExportProgress { final PanoramaExportPhase phase; final int saved, total; }

Stream<PanoramaExportProgress> exportPanorama({
  required AssetEntity source,
  required PanoramaSettings settings,
}) async*
```

**✅ Hazard 1 solved structurally — a plain `for` loop with `await` inside, iterating BACKWARDS:**

```dart
// NOTE: reverse iteration is deliberate. See "Why reverse?" below — do not
// "fix" this to a forward loop. Tile numbering in the filename stays 1..N.
for (var i = tiles.length - 1; i >= 0; i--) {
  final seq = (i + 1).toString().padLeft(2, '0');
  final file = File('${exportDir.path}/${baseName}_pano_${seq}_of_$n.jpg');
  await file.writeAsBytes(tiles[i]);
  await Gal.putImage(file.path);        // each tile committed before the next is written
  await file.delete();
  yield PanoramaExportProgress(
    phase: PanoramaExportPhase.saving, saved: tiles.length - i, total: n);
}
```

No `Future.wait`, no batching — each tile is fully committed to MediaStore before the next is written, so `_id` and `date_added` increase monotonically. Zero-padded `_pano_01_of_04` filenames give the user a deterministic fallback when hand-picking.

**🧭 Why reverse? The gallery grid is newest-first.**

Instagram's picker (like most galleries) sorts **newest first**, and numbers carousel slides in **tap order**. Saving tiles 1→N means tile N is newest and lands top-left, so tapping left-to-right builds the panorama backwards:

**❌ Forward save — user taps left to right, gets a reversed carousel:**
```
save order:      1 → 2 → 3 → 4          (4 is newest)
IG picker grid:  [ 4 ][ 3 ][ 2 ][ 1 ]
tapped L→R:       4,   3,   2,   1      ← panorama runs backwards
```

**✅ Reverse save — grid reads left to right, tapping is natural:**
```
save order:      4 → 3 → 2 → 1          (1 is newest)
IG picker grid:  [ 1 ][ 2 ][ 3 ][ 4 ]
tapped L→R:       1,   2,   3,   4      ← correct
```

**⚠️ Verify this on a real device before shipping.** The reverse-chronological grid is standard; the assumption that Instagram orders carousel slides by tap sequence rather than capture date is the part to confirm. If it turns out to order by date, flip the loop back to forward — it's a one-line change, and the success sheet copy changes with it.

**Progress counts forward regardless.** `saved` is `tiles.length - i`, so the user always sees "Saving tile 1 of 4 → 2 of 4 → …" even though the loop runs backwards. Never surface the internal save order in the UI.

**❌ Do not insert an artificial `Future.delayed` between saves.** MediaStore `date_added` is second-resolution so two fast writes can tie, but `_id` breaks the tie in practice — a delay would slow every export to paper over a case that's already handled.

**✅ Hazard 3 solved with two-phase progress.** The single `processPanorama` call happens *before* any tile can be saved, so a naive `Stream<int>` would sit at 0% then jump — worse than the framer's UX. Make it honest instead:

- **`rendering`** → indeterminate spinner, *"Rendering panorama…"*
- **`saving`** → determinate bar, *"Saving tile 3 of 4"*

`PhotosProcessingState` is never emitted for a panorama, so `editor_screen.dart:567`'s indexing never sees one. Reuse `WakelockPlus.enable()/disable()` around the whole operation, and the same temp-dir + `finally` cleanup as `exportPhotos`.

---

## 🤖 **Smart Defaults**

Three pieces of cheap intelligence that remove decisions the user shouldn't have to make. None of them needs a new dependency, and **none needs ML** — a face detector would be a heavy dep for a landscape use case where edge energy already finds faces, horizons, poles and buildings just as well.

##### **A. Automatic seam placement**

Seams sit at fixed spacing (`tileWidth` apart), so there is exactly **one free parameter** — the offset. That makes good seam placement a 1-D minimization, not a vision problem:

```
column energy across the photo (horizontal gradient, downscaled):

 ▁▁▁▂▂▁▁▁████▇▆▁▁▁▁▁▂▁▁▁███▇▁▁▁▁▁▁▂▂▁▁▁
 └ sky ┘ └ person ┘  └water┘ └ building ┘

offset = 0      seams ┆    ┆    ┆      ← cuts through the person ✗
offset = +0.18  seams  ┆    ┆    ┆     ← all three land in flat areas ✓
```

**The caching is what makes this free.** The energy profile depends only on the photo — not on tile count, fit mode, scale or offset. So:

1. **Once, when the photo loads** — `compute()` on a **thumbnail** (`AssetEntity.thumbnailDataWithSize`, not `originBytes` — no full decode needed), producing a ~600-element `List<double>`.
2. **Every re-optimization after that is pure Dart** over that small array — tile count changed, Fit/Fill toggled — microseconds, main thread, no isolate.

New method on `ImageProcessor`:
```dart
/// Per-column horizontal gradient energy, normalised to 0..1 and resampled
/// to [samples] buckets spanning the FULL SOURCE WIDTH (source coordinates).
Future<List<double>> computeEdgeEnergyProfile(Uint8List thumbnailBytes, {int samples = 600});
```
Isolate body: decode → grayscale → for each column `x`, sum `|L(x+1,y) - L(x-1,y)|` over all `y` → normalise → resample to `samples`.

New pure function in `lib/models/panorama_seams.dart` (no isolate, no I/O):
```dart
static double bestSeamOffset({
  required List<double> energyProfile,
  required int tileCount,
  required double photoSpanFraction,  // where the photo sits in the canvas
  int steps = 200,
});
```
Sweeps `offset` across ±0.5 tile widths, scoring each candidate as the summed energy in a **window** (±1% of source width) around each of the N−1 interior seams, and returns the minimum.

**⚠️ The coordinate mapping is the fiddly part.** The profile is in **source** coordinates; seams are in **canvas** coordinates. Store the profile normalised 0–1 across the source width and convert at query time:
- **Fit** — the photo occupies canvas fraction `[c0, c1]`. `srcFrac = (canvasFrac - c0) / (c1 - c0)`. A seam landing **outside** that range is in the letterbox bar — score it **zero**, since a seam in a plain bar is a perfect seam.
- **Fill** — the photo covers the whole canvas but is cropped, so canvas fraction maps into a **sub-range** of the source. Convert through the same crop window `_coverCropResize` uses.

**Store the profile in `PanoramaReadyState` but EXCLUDE it from `props`.** It is derived purely from `source`, which is already in `props`, so excluding it is correct — and it avoids a 600-element list comparison on every slider tick.

##### **B. Empty-tile warning**

The one genuinely bad output Fit permits: a canvas far wider than the source leaves the edge tiles almost pure background. Source 1.5:1 at 6 tiles (4.8:1 canvas) puts the photo in the middle ~29% of the canvas — **tiles 1, 2, 5 and 6 are essentially blank.**

This needs **no rendering** — it's arithmetic, so it can run live on every rebuild:

```dart
// fraction of the canvas width occupied by the photo
final photoSpan = fitMode == PanoramaFitMode.fill
    ? 1.0
    : scale * math.min(1.0, sourceAspect / canvasRatio);

// photo occupies [0.5 - photoSpan/2 + off, 0.5 + photoSpan/2 + off],
// where off = seamOffset / tileCount  (seamOffset is in TILE widths)
// tile k occupies [k / tileCount, (k + 1) / tileCount]
// coverage_k = overlap(tile_k, photoSpan) * tileCount
```

Warn when any `coverage_k < 0.5`, and **name the offending tiles plus a fix**: *"Tiles 1, 2, 5 and 6 are mostly empty — try 3 tiles."* That's advice, not just a warning; the suggested count is the largest N where every tile clears the threshold.

##### **C. Per-tile resolution readout**

`maxTiles = width ~/ 1080` silently truncates the pill row, so the user sees 6 missing with no explanation. Show the consequence instead of hiding the option:

```
( 2 )( 3 )(●4 )( 5 )( 6 )
 4 tiles · each slide 1080px ✓          ← at 5:  "864px — below Instagram's 1080"
```

Counts above `maxTiles` render **disabled with the reason attached**, not absent. This turns a mystery constraint into a visible quality tradeoff, and leaves the door open to relaxing the hard cap into a soft warning later without any UI rework.

---

## 🧭 **UX Flows (walk these before writing UI code)**

**Flow A — Home entry**

```
Home ─tap "Panorama Carousel"─→ picker (maxAssets: 1) ─pick─→ PanoramaBloc.evaluate()
                                                                   │
                                    ┌──────────────────────────────┴──────────┐
                                    ▼                                         ▼
                            PanoramaReadyState                       PanoramaIneligibleState
                            → push editor                            → snackbar on Home, STAY PUT
```

**❌ Do not push the editor and render the ineligible state there.** Navigating the user forward to a screen whose only content is "no" wastes a transition and forces them back out to retry. `HomeScreen` listens for both states and only pushes on `PanoramaReadyState`; the ineligible reason surfaces as a snackbar with the picker one tap away. Eligibility still lives solely in the bloc, so the layering is unchanged.

**Flow B — Share entry**

```
Gallery ─share─→ InstaFramer
   │
   ├─ cold start: splash → permission → saveImageWithPath → Home renders   [several seconds]
   │
   └─→ SharedPhotoModeSelectionState → CreateModeDialog
                                          ├─ Framed Photo → PhotosSelectedEvent → EditorScreen
                                          ├─ Panorama     → PanoramaSourceSelectedEvent + ClearPhotos → PanoramaEditorScreen
                                          └─ Cancel       → ClearPhotosEvent → stay on Home
```

⚠️ **The photo is already copied into the gallery before the dialog appears.** `saveImageWithPath` runs during import, so by the time the user is asked anything, a duplicate exists in their library. This is pre-existing share behaviour, but it is *why* Cancel is needed — without it, an accidental share costs two dialogs to escape and still leaves the duplicate.

⚠️ **Dangling state: a warm share while an editor is open is silently swallowed.** The `isCurrent` guard correctly suppresses the dialog, but `PhotoBloc` is then parked in `SharedPhotoModeSelectionState`, and `listenWhen` only fires on *transition* — so returning Home later shows nothing, and the user gets a mystery gallery duplicate with no acknowledgement. **Fix:** when `HomeScreen` becomes current again, check whether `PhotoBloc.state is SharedPhotoModeSelectionState` and show the dialog then (a `builder`-side check or post-frame callback, not the listener). Verify this case explicitly on device.

**Flow C — Export handoff** *(the part that decides whether the feature works)*

```
Export ─→ rendering (indeterminate) ─→ saving 1..N (determinate) ─→ success sheet
                                                                        │
                                                                        └─→ user leaves for Instagram
```

Everything up to the success sheet is in our control; the actual carousel assembly is not. The sheet is the **only** place we can explain tap order, so it carries a small numbered grid diagram rather than a sentence — see the mockup below.

---

## 🎨 **UI**

**Preview: widget-composited, no processed preview.** `photo_card.dart:10-11` documents that the codebase deliberately moved from CPU pixel manipulation to GPU widget composition to kill preview lag. A `FutureBuilder` around an isolate call — re-running on every scale-slider tick and every tile-count tap — would regress that on the **widest canvas in the app**. It isn't needed, because widget composition reproduces the export maths exactly:

| Export | Preview widget |
|--------|----------------|
| `_overlayScaledImage` (contain-fit × scale, centred) | `Center(Transform.scale(scale: s.scale, child: AssetEntityImage(fit: BoxFit.contain)))` |
| `_coverCropResize` | `AssetEntityImage(fit: BoxFit.cover)` |
| `_createCanvasWithBackground` white/black | `Container(color: ...)` |
| `_generateFastBlurBackground` (after the cover fix) | tiny thumbnail `fit: BoxFit.cover` + `BackdropFilter` |

Seam guides are an **overlay**, not derived from the image, so they're exact regardless of fit: `Row(children: List.generate(n, (i) => Expanded(...)))` with a right-hand `Border` on all but the last and a centred tile-number badge. Pixel-accurate because the tiles are exact equal fractions of the canvas.

**Files to Create:**

```
lib/screens/panorama_editor_screen.dart
lib/widgets/panorama/panorama_preview.dart              AspectRatio + Stack(bg, photo) + seam overlay
lib/widgets/panorama/panorama_seam_overlay.dart         Row of Expanded: borders + tile numbers
lib/widgets/panorama/panorama_tile_count_selector.dart  2..maxTiles pills + live ratio hint
lib/widgets/panorama/panorama_fit_mode_toggle.dart      SegmentedButton<PanoramaFitMode>
lib/widgets/panorama/panorama_export_button.dart        "Export N tiles" + EXIF note
lib/widgets/panorama/panorama_processing_view.dart      rendering / saving phases
lib/widgets/home/create_mode_dialog.dart                the share-intent popup
```

**Screen mockups — Fit (left) and Fill (right):**

```
┌────────────────────────────────┐    ┌────────────────────────────────┐
│  ←    Panorama Carousel    ⚙   │    │  ←    Panorama Carousel    ⚙   │
├────────────────────────────────┤    ├────────────────────────────────┤
│   ┌────┆────┆────┆────┐        │    │   ┌────┆────┆────┆────┐        │
│   │ 1  ┆ 2  ┆ 3  ┆ 4  │        │    │   │ 1  ┆ 2  ┆ 3  ┆ 4  │        │
│   └────┆────┆────┆────┘        │    │   └────┆────┆────┆────┘        │
│                                │    │                                │
│  Tiles                         │    │  Tiles                         │
│  ( 2 )( 3 )(●4 )( 5 )( 6̶ )     │    │  ( 2 )( 3 )(●4 )( 5 )( 6̶ )     │
│  each slide 1080px ✓           │    │  each slide 1080px ✓           │
│  3.20:1 canvas · photo 3.05:1  │    │  3.20:1 canvas · photo 3.05:1  │
│  Bars on the left & right      │    │  Top & bottom will be cropped  │
│                                │    │                                │
│  ┌──────────┬──────────┐       │    │  ┌──────────┬──────────┐       │
│  │  ● Fit   │   Fill   │       │    │  │   Fit    │  ● Fill  │       │
│  └──────────┴──────────┘       │    │  └──────────┴──────────┘       │
│                                │    │                                │
│  [☀ White][🌙 Black][◍ Blur]   │    │        (bg + scale absent)     │
│  🔍 ────────●────────    92%   │    │                                │
│  ◐  ──────●──────────     25   │    │                                │
│  ⬅  ──────●──────────  seams   │    │  ⬅  ──────●──────────  seams   │
│                                │    │                                │
│  ┌──────────────────────────┐  │    │  ┌──────────────────────────┐  │
│  │      Export 4 tiles      │  │    │  │      Export 4 tiles      │  │
│  └──────────────────────────┘  │    │  └──────────────────────────┘  │
│  Camera info isn't copied      │    │  Camera info isn't copied      │
└────────────────────────────────┘    └────────────────────────────────┘
```

**Disabled tile counts** (`6̶` above) render greyed with the reason on tap, never absent — see [Smart Defaults C](#-smart-defaults). When a count would leave edge tiles blank, the consequence line is replaced by the empty-tile advice:

```
│  ( 2 )( 3 )( 4 )( 5 )(●6 )     │
│  each slide 1080px ✓           │
│  4.80:1 canvas · photo 1.50:1  │
│  ⚠ Tiles 1, 2, 5, 6 are mostly │
│    empty — try 3 tiles         │
```

Two layout rules:

1. **The seam-nudge slider stays visible in both modes.** It's meaningful either way (Fit: slides the photo between the bars; Fill: shifts the crop window), and holding it fixed while the block above collapses reduces the jump when toggling Fit→Fill.
2. **The control stack must scroll.** With blur active, Fit mode stacks five control rows: preview (~112pt at 4 tiles) + tiles + hint + toggle + backgrounds + 3 sliders + button + note ≈ **620pt plus safe areas**. That fits a typical phone but not a small one. Wrap the controls below the preview in a scroll view rather than letting them overflow.

**Progress and success:**

```
┌────────────────────────────┐    ┌──────────────────────────────────┐
│   ┌────┆────┆────┆────┐    │    │              ✅                  │
│   │    dimmed preview  │    │    │          All Done! 🎉            │
│   └────┆────┆────┆────┘    │    │    4 tiles saved to gallery      │
│                            │    │                                  │
│          ◜◝ spinner        │    │  ┌────────────────────────────┐  │
│     Rendering panorama…    │    │  │ In Instagram, tap them     │  │
│                            │    │  │ left to right — they're    │  │
│   ────────────────────     │    │  │ already in the right order │  │
│   Don't leave this page    │    │  │   ┌───┬───┬───┬───┐        │  │
└────────────────────────────┘    │  │   │ 1 │ 2 │ 3 │ 4 │        │  │
              ↓                   │  │   └───┴───┴───┴───┘        │  │
┌────────────────────────────┐    │  └────────────────────────────┘  │
│    ████████████░░░░  75%   │    │                                  │
│     Saving tile 3 of 4     │    │   [ Home ]    [ View Photos ]    │
└────────────────────────────┘    └──────────────────────────────────┘
```

The numbered grid in the success sheet is **not decoration** — it is the only place the reverse-save trick can be explained, and tap order is the single step users get wrong. Render it as real widgets sized to the actual tile count, not a static image.

**Share-intent dialog:**

```
┌────────────────────────────────┐
│  One photo shared              │
│  What do you want to make?     │
│                                │
│  ┌──────────────────────────┐  │
│  │ 🖼  Framed Photo          │  │
│  │    Fit to 4:5 with a bg  │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │ 🌄 Panorama Carousel      │  │
│  │    Split into 4 tiles  ←  │  │  suggestedTiles, already computed
│  └──────────────────────────┘  │
│                                │
│            Cancel              │
└────────────────────────────────┘
```

The panorama option shows the **actual suggested tile count**, not generic copy — `evaluate()` has already run to decide whether to offer the option at all, so the number is free and it turns an abstract choice into a concrete one.

The consequence line under the ratio hint is driven by `fitMode` and the sign of `canvasRatio - sourceAspect`:

| Mode | Canvas vs source | Line |
|------|------------------|------|
| Fill | narrower | *"Sides will be cropped"* |
| Fill | wider | *"Top & bottom will be cropped"* |
| Fit | wider | *"Bars on the left & right"* |
| Fit | narrower | *"Bars above & below"* |

This is the guardrail for the one genuinely user-hostile configuration Fit permits — a canvas far wider than the source makes the edge tiles almost pure background. Visible, warned about, and user-chosen.

`PopScope(canPop: false)` while exporting; dispatch `ClearPanoramaEvent` on normal pop. Preview is `AspectRatio(aspectRatio: settings.canvasRatio)` — fit-to-width, whole panorama visible. At N=10 that's an 8:1 sliver, but it's the truthful preview of the finished carousel, which is the entire point.

**🧹 Shared-widget extraction (required, not optional).** Panorama needs the same selected/unselected pill and labelled slider that `editor_screen.dart` holds inline; duplicating them is exactly what the Development Rules forbid.

**Files to Create:**
1. **`lib/widgets/editor/control_button.dart`** — `ControlButton({icon, label, isSelected, onTap})`, extracted from `_buildControlButton` (lines 406-454)
2. **`lib/widgets/editor/labeled_slider.dart`** — `LabeledSlider({leadingIcon, trailingIcon, value, min, max, divisions, valueLabel, onChanged})`, extracted from the `_buildScaleSlider` / `_buildBlurIntensitySlider` bodies

**File Modified: `lib/widgets/editor/editor_app_bar.dart`** — gains a **required** `String title` (no default; the Development Rules forbid compatibility defaults). Update the call site at `editor_screen.dart:223` to `EditorAppBar(title: 'Edit Photos')`.

---

## 🚪 **Entry Points**

**(a) Home screen**

**File Modified: `lib/screens/home_screen.dart`** — add an `OutlinedButton.icon('Panorama Carousel', Icons.panorama_horizontal_outlined)` under the existing `FilledButton.icon('Select Photos')` (lines 136-153), and swap one `_FeatureItem` for a panorama one so the landing copy sets the right expectation.

**File Modified: `lib/screens/photo_picker_screen.dart`** — new `static Future<AssetEntity?> pickSinglePhoto(BuildContext context)`. Same permission handling and error dialogs as `pickPhotos`, but `maxAssets: 1`, `selectedAssets: const []`, and it **returns** the asset instead of dispatching to `PhotoBloc` — because the caller routes it to `PanoramaBloc`.

```dart
final asset = await PhotoPickerScreen.pickSinglePhoto(context);
if (asset == null || !context.mounted) return;
context.read<PanoramaBloc>().add(PanoramaSourceSelectedEvent(asset));
// Navigation is NOT here — Home listens to PanoramaBloc and pushes only on
// PanoramaReadyState. See Flow A: an ineligible photo shows a snackbar and
// keeps the user on Home instead of pushing a dead-end screen.
```

`HomeScreen` gains a second `BlocListener<PanoramaBloc, PanoramaState>`:
- ✅ `PanoramaReadyState` → push `PanoramaEditorScreen`
- ✅ `PanoramaIneligibleState` → snackbar with `state.reason`, stay on Home

Eligibility stays in **one** place (the bloc) and the screen never touches `photo_manager`.

**(c) Framer → panorama suggestion** *(discovery for people who never notice the home button)*

Today, loading a 3:1 photo into the framer and picking 4:5 produces a tiny strip marooned in white — a genuinely bad result, with no hint that a better tool is two taps away. That failure is the ideal moment to suggest the alternative.

**File Created: `lib/widgets/editor/panorama_suggestion_banner.dart`** — shown in `editor_screen.dart` above the quick controls, only when `photos.length == 1 && PanoramaSpec.evaluate(...).isEligible`:

```
┌────────────────────────────────────┐
│ 🌄 This photo is very wide.        │
│    Split it into a 4-tile carousel │
│    instead?          [Try it]  [✕] │
└────────────────────────────────────┘
```

`[Try it]` → `PanoramaSourceSelectedEvent` + `ClearPhotosEvent` + replace the route with `PanoramaEditorScreen`. `[✕]` dismisses for the session (local widget state — do **not** persist it; a per-photo suggestion isn't worth a prefs key). Reuses `PanoramaSpec.evaluate` and the suggested tile count, so the copy names the actual number.

**(b) Share intent — the non-dismissable mode popup**

The share path enters `PhotoBloc` with **no UI in the loop**, so `PhotoBloc` must surface a decision-required state instead of jumping straight to `PhotosLoadedState`.

**File Modified: `lib/blocs/photo_bloc/photo_state.dart`** — add `SharedPhotoModeSelectionState(AssetEntity photo)`.

**File Modified: `lib/blocs/photo_bloc/photo_bloc.dart`** — at the tail of `_onExternalMediaShared`, **before** the merge (~line 230):

```dart
final freshSingle = assets.length == 1 && currentState == null;  // no editor session in flight
if (freshSingle && PanoramaSpec.evaluate(
      sourceWidth: assets.first.orientatedWidth,
      sourceHeight: assets.first.orientatedHeight).isEligible) {
  emit(SharedPhotoModeSelectionState(assets.first));
  return;
}
// ...existing merge / 30-cap / emit PhotosLoadedState unchanged
```

**💭 Interpretation to confirm during implementation:** an *ineligible* single share **skips the popup** and goes straight to the Frame editor. A non-dismissable modal presenting one enabled button and one greyed-out button is a dialog with no decision in it. If the reason should be surfaced on the share path too, it's a one-`if` change plus a disabled-button branch in `CreateModeDialog`.

`CreateModeDialog.show()` uses `barrierDismissible: false` + `PopScope(canPop: false)` so there's no tap-outside or back-button dismissal, but it offers **three** exits: Framed Photo, Panorama Carousel, and a plain text **Cancel** (→ `ClearPhotosEvent`, stay on Home). The **Frame** branch dispatches `PhotosSelectedEvent([photo])` and re-enters the listener rather than pushing directly, so there stays exactly **one** `Navigator.push(EditorScreen)` call site in the app. `ClearPhotosEvent` emits `PhotoInitialState`, which `listenWhen` rejects — no spurious navigation.

---

## 🔧 **Prerequisite Bug Fix (Step 0 — ships alone, before any panorama code)**

**File Modified: `lib/screens/home_screen.dart`** — `HomeScreen`'s `BlocConsumer` (lines 42-75) is the single navigation choke point and carries Hazard 4. One guard fixes **two** bugs:

```dart
listener: (context, state) async {
  // Only the visible route may navigate. Fixes the warm-share double-push,
  // and prevents a second share from stacking a second mode dialog
  // (showDialog pushes a DialogRoute, so isCurrent is false while it's up).
  if (ModalRoute.of(context)?.isCurrent != true) return;
  ...
}
```

With the guard, a share arriving while the editor is open correctly **merges into the live editor** instead of pushing a second one. `listenWhen` also gains the `SharedPhotoModeSelectionState` transition clause:

```dart
listenWhen: (previous, current) =>
    (previous is! PhotosLoadedState && current is PhotosLoadedState) ||
    (previous is! SharedPhotoModeSelectionState && current is SharedPhotoModeSelectionState) ||
    current is PhotoErrorState,
```

---

## 🚀 **Build Order (each step leaves the app building and running end to end)**

| Step | Scope | Verifiable outcome |
|------|-------|--------------------|
| **0** | Navigation choke-point fix — the `isCurrent` guard, no panorama code | Warm-share no longer pushes a second editor. Standalone, revertable. |
| **1** | `panorama_spec.dart`, `panorama_settings.dart`, `processPanorama` + isolate + `_coverCropResize`, blur cover fix | `processPanorama` is briefly unreferenced, but the blur fix is **live and observable in the framer** |
| **2** | Extract `ControlButton`/`LabeledSlider`, `EditorAppBar.title`, `PanoramaBloc` through Ready/Ineligible, `main.dart` provider, `pickSinglePhoto`, home button, Home's `PanoramaBloc` listener (push on Ready, snackbar on Ineligible), `PanoramaEditorScreen` (export button disabled) | Pick a wide photo → live preview with seam guides → change N, toggle Fit/Fill, drag scale and seam-nudge. Pick a portrait photo → snackbar on Home, no navigation |
| **3** | `PanoramaExportProgress` + `exportPanorama` (**reverse loop**), exporting/exported/error states + handlers, processing view, success sheet with the tap-order grid | **Entry point (a) feature-complete.** Verify tile order in Instagram on a real device *before* moving on — this is the assumption the whole feature rests on |
| **4** | `SharedPhotoModeSelectionState`, the `freshSingle` branch, `CreateModeDialog` (incl. Cancel), the `home_screen.dart` listener branch, and the **dangling-state recovery** for a warm share arriving while an editor is open | Both entry points done |
| **5** | [🤖 Smart Defaults](#-smart-defaults) — `computeEdgeEnergyProfile` + `panorama_seams.dart` + auto seam offset, empty-tile warning, per-tile resolution readout, and the framer suggestion banner | **Feature complete.** Deliberately last: every piece is a refinement of something already working, so each can be evaluated against the un-smart baseline and dropped if it doesn't earn its place |

---

## ☑️ **Implementation Checklist**

> **How to use this.** Tick `- [ ]` → `- [x]` as you go. Items are ordered — later ones assume earlier ones are done. **🚦 GATE** items are blocking: do not start the next step until the gate passes. Each step ends with `flutter analyze` clean and a commit, so the app is runnable and revertable at every checkpoint.

| Step | Items | Gates | Done |
|------|-------|-------|------|
| 0 · Navigation fix | 4 | 1 | ☐ |
| 1 · Processing core | 10 | 1 | ☐ |
| 2 · Bloc + editor (preview) | 30 | 2 | ☑ (code); device gate pending |
| 3 · Export | 11 | 1 ⚠️ device | ☑ |
| 4 · Share entry | 11 | 1 | ☑ (code); device tests pending |
| 5 · Smart defaults | 13 | 1 ⚠️ device | ☑ (code); device gate pending |
| 6 · Wrap-up | 4 | — | ☐ |
| **Total** | **83** | **7** | |

---

**Step 0 — Navigation choke-point fix** *(no panorama code; ships alone)*

- [x] Add `if (ModalRoute.of(context)?.isCurrent != true) return;` as the first line of `HomeScreen`'s `BlocConsumer` listener
- [ ] 🚦 **GATE** — on device: open the editor, share a photo from the gallery → photos merge into the live editor, **no second `EditorScreen` is pushed**
- [x] `flutter analyze` clean
- [ ] Commit (standalone bug fix, revertable on its own)

**Step 1 — Processing core**

- [x] Create `lib/models/panorama_spec.dart` — constants, `PanoramaEligibility`, `evaluate()` with the three ordered checks and their reason strings
- [x] Create `lib/models/panorama_settings.dart` — `PanoramaSettings` with `seamOffset` / `seamOffsetIsManual`, the four canvas getters, `seamOffsetPx`, `copyWith`. **Convention change made during this step:** all enums in the app (including `PanoramaFitMode`) now live in `lib/models/enums.dart` using Dart's enhanced-enum syntax (fields + const constructor) instead of a bare `enum` plus a same-file `extension … on … { displayName }` — this folded in the pre-existing `BackgroundType` and `ImageSizePreset`, both moved out of `background_type.dart`/`image_size.dart` into `enums.dart`. `background_type.dart` no longer exists. Apply this to `PanoramaExportPhase` (Step 3) and any other enum introduced later.
- [x] Add `_coverCropResize(src, targetW, targetH, {required int offsetX})` to `image_processor.dart`
- [x] Change `_generateFastBlurBackground` step 3 from `copyResize` to `_coverCropResize(..., offsetX: 0)` — the stretch→cover fix
- [x] Add required `offsetX` to `_overlayScaledImage`; update the framer call site in `_processImageInIsolate` to pass `0`
- [x] Add `_PanoramaProcessingParams` (serializable data only)
- [x] Add `_processPanoramaInIsolate` — decode → guarded `bakeOrientation` → Fit/Fill branch → slice loop
- [x] Add public `processPanorama(Uint8List, PanoramaSettings)`
- [ ] 🚦 **GATE** — the blur fix is live in the **existing** framer: export a photo with a Blur background at 16:9 and confirm the background covers instead of smearing
- [ ] `flutter analyze` clean + commit

**Step 2 — Bloc + editor, preview only** *(export button present but disabled)*

- [x] Create `lib/widgets/editor/control_button.dart`; delete `_buildControlButton` from `editor_screen.dart` and call the widget
- [x] Create `lib/widgets/editor/labeled_slider.dart`; rewrite `_buildScaleSlider` / `_buildBlurIntensitySlider` to use it
- [x] Make `EditorAppBar.title` required; update `editor_screen.dart:223` to `EditorAppBar(title: 'Edit Photos')`
- [x] 🚦 **GATE** — the framer looks and behaves **identically** after the extraction (pills, sliders, app bar). Verified on an Android emulator: aspect-ratio pills, background pills, and both sliders render and read (92% scale, etc.) exactly as before.
- [x] Create `lib/blocs/panorama_bloc/panorama_event.dart` — all nine events. **Deviation:** also added `UpdatePanoramaSeamOffsetEvent` — the plan's Architecture section lists nine events but omits one for the seam-nudge slider, even though Product Decision 3 ("Seam-nudge IS in V1") and this step's own gate ("seam-nudge all reflow correctly") require it to be interactive already. Treated as a documentation gap rather than deferring the slider to Step 5.
- [x] Create `lib/blocs/panorama_bloc/panorama_state.dart` — `Initial`, `Ineligible`, `Ready` (leave export states for Step 3)
- [x] Create `lib/blocs/panorama_bloc/panorama_bloc.dart` — `_onPanoramaSourceSelected` (uses `orientatedWidth`/`orientatedHeight`) + the five settings handlers (plus the seam-offset handler above, which sets `seamOffsetIsManual: true`)
- [x] Persist scale/blur to `lastUsedScale` / `lastUsedBlurIntensity` on change, mirroring `PhotoBloc._onUpdateScale`
- [x] Register `PanoramaBloc` as the third provider in `main.dart`
- [x] Add `PhotoPickerScreen.pickSinglePhoto` — `maxAssets: 1`, **returns** the asset
- [x] Add a `BlocListener<PanoramaBloc, PanoramaState>` to `HomeScreen`: push on `PanoramaReadyState`, snackbar on `PanoramaIneligibleState`
- [x] Add the `OutlinedButton.icon('Panorama Carousel')` and swap one `_FeatureItem`
- [x] Create `lib/widgets/panorama/panorama_seam_overlay.dart` — `Row` of `Expanded`, borders + tile numbers
- [x] Create `lib/widgets/panorama/panorama_preview.dart` — `AspectRatio(canvasRatio)` + `Stack(background, photo)` + overlay; Fit uses `Transform.scale` + `BoxFit.contain`, Fill uses `BoxFit.cover`; both apply `Transform.translate` for `seamOffset`
- [x] Create `lib/widgets/panorama/panorama_tile_count_selector.dart` — pill row + canvas-ratio hint + consequence line
- [x] Create `lib/widgets/panorama/panorama_fit_mode_toggle.dart` — `SegmentedButton<PanoramaFitMode>`
- [x] Create `lib/screens/panorama_editor_screen.dart` — app bar, preview, controls in a **scroll view**, disabled export button; background/scale/blur absent in Fill
- [ ] 🚦 **GATE** — wide photo → live preview with seam guides; tile count, Fit/Fill, scale and seam-nudge all reflow correctly. Portrait photo → snackbar on Home, **no navigation**. *(Not yet run end-to-end on device/emulator with a real wide photo — flag for follow-up before Step 3.)*
- [x] `flutter analyze` clean + commit

**Step 2 — UX polish** *(post-review additions on top of the original preview-only editor; not in the original architecture section, added after a UI/UX pass over the built screens)*

- [x] Rename the "Auto-positioned" seam badge to "Suggested"/"Custom" — the original wording implied the seam was AI-placed, which it isn't (`_SeamOffsetBadge` in `panorama_editor_screen.dart`)
- [x] Add icon-only reset controls (`_ResetButton`) for the seam offset and zoom sliders, dispatching `ResetPanoramaSeamOffsetEvent`/`ResetPanoramaScaleEvent`; add `PanoramaSettings.defaultScale` as the shared reset target
- [x] Give sliders visible segment ticks — `SliderTheme` override (`RoundSliderTickMarkShape`, explicit tick colors, `trackGap`) in `labeled_slider.dart`; reduce the zoom slider's divisions so segments render at Material 3's tick-visibility threshold
- [x] Fix the live preview occupying too little of the viewport — give it a guaranteed `Expanded(flex:)` budget instead of shrinking to leftover space
- [x] Stop showing tile counts the photo's resolution can't support as disabled pills; hide them entirely and add an info icon next to the "Tiles" label (`Row` + `spaceBetween`) that shows a snackbar explaining the cap on tap — supersedes the "disabled with a reason" approach originally planned for Step 5
- [x] Extract `lib/widgets/panorama/panorama_canvas.dart` (`PanoramaCanvas`) — the background+photo composited layer shared by the in-editor preview and the new full-screen preview, with no seam overlay baked in
- [x] Build `lib/screens/panorama_instagram_preview_screen.dart` — a full-screen swipeable preview of each tile as it'll appear in Instagram's carousel (no seam lines), slicing one wide `PanoramaCanvas` per tile via `OverflowBox` + `Transform.translate` rather than rendering N separate images
- [x] Move `Export` out of the main editor into the preview screen; the editor's pinned footer action becomes a single `Preview` button that opens the preview screen, which pops back (handing control to the editor's existing `BlocConsumer`) once `ExportPanoramaEvent` is dispatched
- [x] Add Instagram-style post chrome to the preview screen — avatar/handle header row, action-icon row (like/comment/send/repost/bookmark), a caption line, "liked by"/"view comments"/timestamp lines, and an on-image tile counter badge + dot indicator (replacing a separate dot-indicator app-bar row)
- [x] Add a light/dark toggle to the preview screen's app bar that swaps `AppTheme.light()`/`AppTheme.dark()` for that screen only (via a local `Theme` wrapper), defaulting to the app's current theme mode and never touching `PreferencesBloc`
- [x] Add haptic feedback (`HapticFeedback.selectionClick()`) to `ControlButton.onTap` (covers every pill-style button app-wide) and to slider `onChangeEnd`
- [ ] 🚦 **GATE** — on device: confirm the new preview screen's swipe/theme-toggle/export hand-off, and the hidden-tile-count info icon, all behave as designed
- [x] `flutter analyze` + `dart format` clean

**Step 3 — Export**

- [x] Add `PanoramaExportPhase` + `PanoramaExportProgress` to `export_service.dart`. **Deviation:** `PanoramaExportPhase` went to `lib/models/enums.dart` per the Step 1 convention note (all enums live there) and the architecture section's explicit instruction; `PanoramaExportProgress` got its own `lib/models/panorama_export_progress.dart` rather than living inline in `export_service.dart`, consistent with `panorama_spec.dart`/`panorama_settings.dart` being separate model files
- [x] Add `exportPanorama` — **reverse loop** with the do-not-fix comment, forward-counting `saved`, no `preserveMetadata`
- [x] Confirm temp dir creation and `finally` cleanup match `exportPhotos`
- [x] Add `PanoramaExportingState`, `PanoramaExportedState`, `PanoramaErrorState(message, previous)`
- [x] Add `_onExportPanorama` with `WakelockPlus.enable()/disable()` — **no** `emit(error) → delay → emit(previous)` cycling
- [x] Add `_onDismissPanoramaError` → emits event-carried `previous`
- [x] Create `lib/widgets/panorama/panorama_processing_view.dart` — indeterminate for `rendering`, determinate for `saving`
- [x] Create `lib/widgets/panorama/panorama_export_button.dart` — "Export N tiles" + the EXIF note
- [x] Add the success bottom sheet with the **numbered tap-order grid** (real widgets sized to tile count), Home / View Photos
- [x] 🚦 **GATE (blocking, device-only)** — export 4 tiles, open Instagram, confirm the grid reads `[1][2][3][4]` left-to-right and tapping in that order produces a correct carousel. **If Instagram orders by capture date rather than tap sequence, flip the loop to forward and update the success-sheet copy before continuing**. *Verified on a real device — export confirmed working, reverse-save order reads correctly in Instagram.*
- [x] `flutter analyze` clean

**Step 4 — Share-intent entry**

- [x] Add `SharedPhotoModeSelectionState(AssetEntity)` to `photo_state.dart`
- [x] Add the `freshSingle` + eligibility branch at the tail of `_onExternalMediaShared`, before the merge
- [x] Create `lib/widgets/home/create_mode_dialog.dart` — `barrierDismissible: false` + `PopScope(canPop: false)`, three exits, panorama option shows `suggestedTiles`
- [x] Add the dialog branch to the listener; Frame routes via `PhotosSelectedEvent` (keep **one** `Navigator.push(EditorScreen)` call site). **Deviation:** implemented showing `CreateModeDialog` entirely in `BlocConsumer.builder` rather than splitting between a `listenWhen`-gated `listener` clause and a separate builder-side recovery check. `builder` runs on every emitted state (unlike `listener`, which `listenWhen` can skip) *and* re-runs when `ModalRoute.of(context)`'s `isCurrent` flips — calling `ModalRoute.of(context)` inside `build()` subscribes to that flip via its `InheritedWidget`. That single call site naturally covers both the immediate case (Home already current at the transition) and the dangling-recovery case (Home becomes current later), and the `isCurrent` condition is self-gating: once the dialog's own route is pushed, Home stops being current, so the check can't double-fire. Adding the `listenWhen` clause on top would have raced with this and shown two stacked dialogs for the immediate case, so it was not added.
- [x] Add dangling-state recovery: when Home becomes current again, if `PhotoBloc.state is SharedPhotoModeSelectionState`, show the dialog (builder-side / post-frame, **not** the listener) — see deviation note above; same code path handles both cases.
- [ ] Test: cold-start share of one wide photo → dialog appears
- [ ] Test: warm share of one wide photo → dialog appears
- [ ] Test: Cancel → returns Home, bloc cleared, no editor
- [ ] Test: ineligible single share → straight to framer, no dialog · 2+ photos shared → straight to framer, no dialog
- [ ] 🚦 **GATE** — warm share **while an editor is open**: no dialog, no second editor, and the photo is acknowledged on returning Home. Then `flutter analyze` + commit

**Step 5 — Smart defaults** *(each item is independently droppable if it doesn't earn its place)*

- [x] Add `ImageProcessor.computeEdgeEnergyProfile(Uint8List thumbnailBytes, {int samples = 600})` — grayscale, per-column gradient, normalise, resample
- [x] Create `lib/models/panorama_seams.dart` with `bestSeamOffset(...)` — pure Dart, no isolate
- [x] Implement the Fit coordinate mapping (letterbox rect; seams outside the photo score **zero**)
- [x] Implement the Fill coordinate mapping (through the crop window). **Deviation:** the single `photoSpanFraction` parameter sketched in the architecture section only covers Fit's geometry (a sub-span of canvas mapping to the full source). Fill needed more inputs to be correct: `_coverCropResize`'s own branching means Fill has two distinct sub-cases — when the canvas is wider-aspect than the source (the common panorama case), the crop window already spans the full source width and the seam-nudge has **zero effect** on where a seam lands; only when the source is wider-aspect than the canvas does the crop window genuinely shift with offset. `bestSeamOffset` takes `fitMode`/`scale`/`sourceAspect`/`canvasRatio` directly and replicates both `_overlayScaledImage` and `_coverCropResize`'s math exactly rather than a single pre-derived span, so it can express both sub-cases. Verified against a synthetic energy profile with a known spike (confirmed the optimizer moves the seam off it, and that Fill's two sub-cases behave as derived) before wiring into the bloc.
- [x] Add `energyProfile` to `PanoramaReadyState`, **excluded from `props`**
- [x] Fetch the thumbnail via `AssetEntity.thumbnailDataWithSize` (not `originBytes`) in `_onPanoramaSourceSelected` and seed `settings.seamOffset`
- [x] Re-run `bestSeamOffset` in `_onUpdateTileCount` and `_onUpdateFitMode`
- [x] Add the `seamOffsetIsManual` guard so dragging the slider stops re-optimisation; reset on a new source (implicit — `_onPanoramaSourceSelected` always constructs a fresh `PanoramaSettings`, which defaults `seamOffsetIsManual` to `false`)
- [ ] 🚦 **GATE** — on a photo with an obvious vertical edge (pole, building corner), confirm seams land **off** it in both Fit and Fill. This is where a coordinate-mapping bug shows up as "subtly wrong" rather than obviously broken
- [x] Add the per-tile coverage calculation and the empty-tile advice line (names the tiles **and** the suggested count)
- [x] Add the per-slide resolution readout. **Superseded during the Step 2 UX-polish pass:** counts above `maxTiles` were originally rendered disabled-with-a-reason; they're now hidden entirely, with an info icon next to the "Tiles" label explaining the cap on tap (see Step 2 — UX polish)
- [x] Create `lib/widgets/editor/panorama_suggestion_banner.dart`; show in `editor_screen.dart` when `photos.length == 1 && eligible`; `[Try it]` hands off to `PanoramaBloc`, `[✕]` dismisses for the session only
- [x] `flutter analyze` clean

**Step 6 — Wrap-up**

- [ ] Update `CLAUDE.md` — panorama import path, the second bloc, the reverse-export rule, and the `offsetX` convention
- [ ] Move Panorama from "Coming Soon" to shipped in `README.md`
- [ ] Change this section's heading from `🚧 PLANNED` to `✅ COMPLETED` and fill in a real **Status:** line
- [ ] Test end to end on a real stitched panorama (≥6:1) **and** a plain 16:9 phone shot

---

## 🎯 **Key Benefits**

1. **Engine reuse, not duplication** - the N×0.8 canvas insight means background, scale and blur come from the existing framer pipeline verbatim; only the slice step and the cover-fit path are new code.
2. **Padding + panorama, combined** - Fit mode is literally the framer's padding feature applied to a wide canvas, which is what makes White/Black/Blur meaningful for panoramas rather than a separate concept.
3. **Correct carousel order** - sequential export plus zero-padded `_pano_NN_of_N` filenames means the tiles land in the gallery in the order Instagram will show them, which is the difference between the feature working and silently producing a scrambled panorama.
4. **Zero regression risk to the framer** - a separate bloc and a separate export method mean the existing progress contract, batching and EXIF behaviour are untouched.
5. **Honest previews** - the preview reproduces the export maths in widgets, so what the user sees is what they get, at 60fps, on the widest canvas in the app.
6. **One eligibility implementation** - `PanoramaSpec.evaluate` serves both entry points with identical user-facing copy.

**Next Steps:**
1. Execute Step 0 and verify the warm-share fix on an Android device
2. Work through Steps 1–4 in order, keeping the app runnable at each step
3. Test with a real stitched panorama (very wide, e.g. 6:1) and a plain 16:9 phone shot
4. **Verify tile order in the Instagram carousel picker on a real device** — the reverse-save decision rests on Instagram ordering slides by tap sequence rather than capture date. Do this at the end of Step 3, before building the share entry
5. Verify the two share edge cases explicitly: Cancel on the dialog, and a warm share arriving while an editor is open
6. Update `README.md` roadmap when the module ships

**V2 Candidates (explicitly out of scope):**
- Face-aware seam placement - ML Kit face detection instead of edge energy. Deliberately rejected for V1: a heavy new dependency for a landscape-photography use case where the gradient profile already finds faces, horizons, poles and buildings
- Vertical crop control in Fill mode - when the canvas is *wider* than the source, we centre-crop top and bottom with no way to say "keep the horizon". Rare (needs a high tile count on a modest source) but currently unaddressed
- Free pan/zoom reframe - a draggable crop rect over the canvas (V1 ships the 1-D seam-nudge slider instead)
- Per-tile scrub preview - tap the strip to inspect tiles at full size, since the fit-to-width preview is only ~112pt tall at 4 tiles and ~45pt at 10
- Direct "Share to Instagram" handoff - hand N images to the share sheet instead of relying on the user to pick them in order
- Tile overlap - a small shared margin between tiles for perceptual continuity
- Non-4:5 tile ratios - 1:1 tiles for a squarer carousel
- "Cover tile" - a first tile that reads well standalone in the profile grid

