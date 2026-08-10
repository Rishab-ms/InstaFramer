import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../models/panorama_settings.dart';
import 'panorama_canvas.dart';
import 'panorama_seam_overlay.dart';

/// In-editor panorama preview: the composited [PanoramaCanvas] with the
/// seam grid drawn on top, sized to the full canvas aspect ratio. See the
/// "UI" section of the panorama plan for the export ↔ widget correspondence
/// table the canvas compositing mirrors.
class PanoramaPreview extends StatelessWidget {
  final AssetEntity source;
  final PanoramaSettings settings;

  const PanoramaPreview({
    super.key,
    required this.source,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: settings.canvasRatio,
      // Clip so a translated photo can't paint outside the canvas bounds —
      // mirrors `copyCrop` self-clamping the export's canvas.
      child: ClipRect(
        // Paint order matters: the canvas (background bars/blur + photo)
        // sits behind, and the seam overlay must be topmost so its borders
        // and tile-number badges are always visible over both.
        child: Stack(
          fit: StackFit.expand,
          children: [
            PanoramaCanvas(source: source, settings: settings),
            PanoramaSeamOverlay(tileCount: settings.tileCount),
          ],
        ),
      ),
    );
  }
}
