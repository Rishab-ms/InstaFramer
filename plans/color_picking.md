# Color Picking: Dominant-Color Backgrounds

**Goal:** instead of only White/Black/Blur, suggest up to 5-6 colors extracted from the photo itself as additional background options, so the framed/panorama result feels matched to the photo rather than generic.

**Status:** 📝 Planned — product direction agreed (see below), no code written yet.

**Related:** the panorama carousel editor is the first place this ships — see `plans/panorama_module.md`.

---

## 🎯 Product Decisions (settled — do not re-litigate)

1. **Rollout order: panorama editor first.** A panorama has exactly one source photo, so "colors from the photo" has an unambiguous meaning there. Ship the swatch-row UX and validate it before touching the batch framer, where the same phrase is ambiguous (see #2).
2. **Batch framer palette source: cover photo only.** The regular framer applies **one shared `PhotoSettings` across up to 30 photos** — that's the "consistent background" value prop. When this feature reaches the framer, extract the suggested palette from the first/cover photo only, and apply the chosen color uniformly across the whole batch.
   - **Explicitly rejected:** a different color per photo. It breaks batch consistency (a carousel where each tile has a differently-colored border reads as unintentional, not designed) and would need a per-photo settings model that doesn't exist today.
   - **Deferred, not rejected:** an aggregate palette sampled across several/all photos in the batch (see V2 Candidates) — more "representative," but more implementation cost for unclear benefit until there's real usage to learn from.
3. **Up to 5-6 suggested swatches**, shown as additional color chips alongside the existing White/Black/Blur pills — additive, not a replacement.
4. **Interaction mirrors the existing background pills** — tapping a swatch updates the live preview immediately, same as tapping White/Black/Blur today.

---

## 🧠 Why Panorama First (read this before building the framer version)

The regular framer's "one background for up to 30 photos" architecture means dominant-color extraction is only unambiguous once you've picked *whose* photo's colors to use (Product Decision #2). The panorama editor sidesteps that entirely — one source photo, one palette, no design question left to answer — so it's the right place to prove out the interaction (swatch row, live preview, selection state) before the batch framer's shared-setting question needs to be solved in code.

It also sidesteps the crash-risk question below for free: extraction cost is O(1) per panorama regardless of anything else, since there's only ever one photo to sample.

---

## ⚙️ Technical Plan

### Library

- Add **`palette_generator`** as a new dependency. It's the standard Flutter equivalent of Android's Palette API — extracts dominant / vibrant / muted / light-vibrant / dark-vibrant / light-muted swatches, which maps almost directly onto "5-6 suggested options."
- This is a deliberate exception to "prefer packages already in `pubspec.yaml`" (see CLAUDE.md's Engineering Principles) — correct perceptual color quantization (avoiding near-white/near-black noise, proper clustering) isn't a few lines of Dart, so hand-rolling it on top of the `image` package isn't worth it here.

### Where extraction runs

- **Off the main thread**, using the same `compute()` isolate discipline as `ImageProcessor` — never inline on the UI thread.
- On a **downscaled copy** of the source (~150-300px) — the same trick already used for blur backgrounds (`ImageProcessor` downscales to ~300px before blurring). Dominant color doesn't need full resolution, and this bounds cost regardless of source photo size.
- **Panorama flow:** run once in `PanoramaBloc._onPanoramaSourceSelected`, alongside the existing thumbnail fetch used for the seam-energy profile (`AssetEntity.thumbnailDataWithSize` — see `plans/panorama_module.md`'s Smart Defaults section) — reuse that same thumbnail fetch if the sizes overlap, rather than fetching the source twice.
- **Framer flow (later):** run once against the cover/first photo when the batch loads. Batch size (up to 30) is irrelevant to cost since only one photo is ever sampled — this is what keeps "will 30 photos crash the device" a non-issue: **don't extract from all N photos, ever.**
- If an aggregate palette (V2) is ever built, it must follow `ExportService`'s existing discipline instead of a naive loop: fixed small concurrent batches, discard decoded bytes immediately after extracting each photo's palette, and cap how many of the up-to-30 photos are actually sampled (e.g. first 5-10) rather than literally all of them.

### Model changes

- `BackgroundType` (`lib/models/enums.dart`, currently `white` / `black` / `extendedBlur`) gains a fourth variant carrying a `Color`, threaded through `PanoramaSettings` (and later `PhotoSettings`).
- The bloc's ready state gains a `List<Color> suggestedColors` (naming TBD), populated once extraction completes, for the UI to render as chips. Follows the same pattern as `PanoramaReadyState.energyProfile` in the panorama plan — derived purely from the source, and a candidate for exclusion from `props` if list comparison turns out to be a hot path.

### Caching

- Cache the extracted palette keyed by asset id, so rebuilds (slider drags, tab switches, carousel scrubs) don't re-run extraction.

---

## ❓ Open Questions (decide before writing code)

- Use `palette_generator`'s six named swatches as-is, or filter/dedupe (drop near-duplicates, require a minimum population share)?
- Where do the color chips sit relative to White/Black/Blur — appended after, or interleaved by some ranking?
- Does selecting a photo-color background hide/disable the blur-intensity slider the same way White/Black already do?

---

## V2 Candidates (explicitly out of scope for v1)

- **Aggregate/multi-photo palette** for the batch framer (Product Decision #2's rejected-for-now option B) — sample several of the up-to-30 photos and merge into one palette, instead of cover-photo-only.
- **Per-photo dynamic backgrounds** in the batch framer — would need a per-photo settings model; explicitly rejected as breaking the "consistent background" premise the framer exists for.
- **User-tunable palette** — a color wheel / eyedropper over the photo, instead of only pre-computed suggestions.
