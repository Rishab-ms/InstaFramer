import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../models/panorama_settings.dart';
import '../models/panorama_spec.dart';
import '../theme/app_theme.dart';
import '../widgets/panorama/panorama_canvas.dart';
import '../widgets/panorama/panorama_export_button.dart';

/// Full-screen swipeable preview approximating what each panorama tile will
/// look like as an individual Instagram carousel slide — no seam lines, no
/// tile-number badges, just the photo one tile at a time with the same swipe
/// gesture Instagram's carousel uses, plus decorative post chrome (avatar,
/// like/comment/share/repost icons, a caption) so it reads as an actual post
/// rather than a bare image strip.
///
/// This is also where export actually happens — see [PanoramaExportButton]
/// below — on the idea that exporting is the decision made *after* checking
/// how the carousel will look, not before. Popping back to
/// `PanoramaEditorScreen` on export deliberately hands off to its existing
/// `BlocConsumer`, which already owns the exporting/success/error UI; this
/// screen doesn't duplicate any of that state handling.
///
/// Deliberately reuses [PanoramaCanvas] (the same widget-composited
/// background+photo layer the in-editor preview uses) sliced per tile,
/// rather than running the real `ImageProcessor.processPanorama` isolate —
/// this is a "what will this roughly look like" check, not a pixel-exact
/// render, and staying widget-composited keeps it instant to open.
///
/// The light/dark toggle in the app bar overrides [AppTheme] locally for
/// this screen only (via a [Theme] wrapper) — it never touches
/// `PreferencesBloc`, so previewing "how this looks in dark mode" doesn't
/// flip the rest of the app.
class PanoramaInstagramPreviewScreen extends StatefulWidget {
  final AssetEntity source;
  final PanoramaSettings settings;

  const PanoramaInstagramPreviewScreen({
    super.key,
    required this.source,
    required this.settings,
  });

  @override
  State<PanoramaInstagramPreviewScreen> createState() =>
      _PanoramaInstagramPreviewScreenState();
}

class _PanoramaInstagramPreviewScreenState
    extends State<PanoramaInstagramPreviewScreen> {
  int _page = 0;

  // Null until didChangeDependencies runs once, so the initial value can be
  // read from the ambient app theme (the "defaulting to the current app
  // mode" requirement) without depending on inherited widgets from initState.
  Brightness? _previewBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _previewBrightness ??= Theme.of(context).brightness;
  }

  void _toggleBrightness() {
    setState(() {
      _previewBrightness = _previewBrightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tileCount = widget.settings.tileCount;
    final isDark = _previewBrightness == Brightness.dark;
    final previewTheme = isDark ? AppTheme.dark() : AppTheme.light();

    return Theme(
      data: previewTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Preview'),
              actions: [
                IconButton(
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  tooltip: isDark
                      ? 'Preview in light mode'
                      : 'Preview in dark mode',
                  onPressed: _toggleBrightness,
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildPostHeader(theme),
                  Expanded(child: _buildMediaCarousel(tileCount, isDark)),
                  _buildPostChrome(context, theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Avatar + handle + overflow menu — the row that sits above the media on
  /// every real Instagram post.
  Widget _buildPostHeader(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'yourhandle',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
          const Spacer(),
          Icon(Icons.more_horiz, color: onSurface),
        ],
      ),
    );
  }

  /// The swipeable 4:5 media area, with a "current/total" pill and a dot
  /// indicator overlaid directly on the image — matching where Instagram
  /// actually puts carousel chrome, rather than in the app bar.
  Widget _buildMediaCarousel(int tileCount, bool isDark) {
    return Center(
      child: AspectRatio(
        aspectRatio: PanoramaSpec.tileRatio,
        child: ColoredBox(
          color: isDark ? Colors.black : Colors.white,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                itemCount: tileCount,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) =>
                    _buildTilePage(index, tileCount),
              ),
              if (tileCount > 1) ...[
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildCounterBadge(tileCount),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: _buildDotIndicator(tileCount),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterBadge(int tileCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${_page + 1}/$tileCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int tileCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tileCount, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }

  /// Decorative action row, caption and byline mimicking a real Instagram
  /// post — purely illustrative (none of the icons but Export do anything) —
  /// with the actual export action folded into the same surface so it reads
  /// as "the rest of the post" rather than a separate control.
  Widget _buildPostChrome(BuildContext context, ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(Icons.favorite_border, color: onSurface),
                const SizedBox(width: 14),
                Icon(Icons.chat_bubble_outline, color: onSurface),
                const SizedBox(width: 14),
                Icon(Icons.send_outlined, color: onSurface),
                const SizedBox(width: 14),
                Icon(Icons.repeat_rounded, color: onSurface),
                const Spacer(),
                Icon(Icons.bookmark_border, color: onSurface),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Liked by yourhandle and others',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                children: const [
                  TextSpan(
                    text: 'yourhandle  ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Some views need more than one frame 🌄'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              'View all 12 comments',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(
              'JUST NOW',
              style: theme.textTheme.labelSmall?.copyWith(
                color: onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: PanoramaExportButton(
              tileCount: widget.settings.tileCount,
              onExport: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// Slices the single wide [PanoramaCanvas] into a one-tile-wide window —
  /// rendering the whole canvas at `pageWidth * tileCount` and shifting it
  /// left by `pageWidth * index` inside an [OverflowBox], rather than
  /// building a separate cropped image per tile.
  Widget _buildTilePage(int index, int tileCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final pageHeight = constraints.maxHeight;
        final canvasWidth = pageWidth * tileCount;

        return ClipRect(
          child: OverflowBox(
            maxWidth: canvasWidth,
            minWidth: canvasWidth,
            maxHeight: pageHeight,
            minHeight: pageHeight,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-pageWidth * index, 0),
              child: SizedBox(
                width: canvasWidth,
                height: pageHeight,
                child: PanoramaCanvas(
                  source: widget.source,
                  settings: widget.settings,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
