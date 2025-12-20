/// Aspect ratio data model for photo framing.
/// 
/// Represents an aspect ratio with its mathematical value, display information,
/// and UI presentation details. This model allows for easy addition of new
/// aspect ratios without modifying UI code.
class AspectRatio {
  /// Unique identifier for this aspect ratio
  final String id;
  
  /// Mathematical ratio value (width / height)
  final double ratio;
  
  /// Display name shown in UI (e.g., "4:5 Portrait")
  final String displayName;
  
  /// Short label for compact UI (e.g., "4:5")
  final String label;
  
  /// Icon to represent this aspect ratio
  final String iconName;
  
  /// Description for tooltips or help text
  final String? description;

  const AspectRatio({
    required this.id,
    required this.ratio,
    required this.displayName,
    required this.label,
    required this.iconName,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AspectRatio &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Predefined aspect ratios available in the app.
/// 
/// Add new aspect ratios here to make them available throughout the app.
/// The UI will automatically generate buttons for all ratios in this list.
class AspectRatios {
  AspectRatios._(); // Private constructor to prevent instantiation

  /// 4:5 Portrait - Instagram's standard portrait format
  static const portrait = AspectRatio(
    id: 'portrait_4_5',
    ratio: 4 / 5, // 0.8
    displayName: '4:5 Portrait',
    label: '4:5',
    iconName: 'crop_portrait',
    description: 'Instagram portrait format',
  );

  /// 1:1 Square - Instagram's classic square format
  static const square = AspectRatio(
    id: 'square_1_1',
    ratio: 1.0,
    displayName: '1:1 Square',
    label: '1:1',
    iconName: 'crop_square',
    description: 'Instagram square format',
  );

  /// 16:9 Landscape - Standard widescreen format
  static const landscape = AspectRatio(
    id: 'landscape_16_9',
    ratio: 16 / 9, // ~1.778
    displayName: '16:9 Landscape',
    label: '16:9',
    iconName: 'crop_landscape',
    description: 'Standard widescreen format',
  );

  /// 9:16 Vertical - Instagram Stories/Reels format
  static const story = AspectRatio(
    id: 'story_9_16',
    ratio: 9 / 16, // 0.5625
    displayName: '9:16 Story',
    label: '9:16',
    iconName: 'crop_portrait',
    description: 'Instagram Stories and Reels format',
  );

  /// 3:4 Portrait - Classic photo format
  static const classicPortrait = AspectRatio(
    id: 'portrait_3_4',
    ratio: 3 / 4, // 0.75
    displayName: '3:4 Portrait',
    label: '3:4',
    iconName: 'crop_portrait',
    description: 'Classic portrait format',
  );

  /// 4:3 Landscape - Classic photo format
  static const classicLandscape = AspectRatio(
    id: 'landscape_4_3',
    ratio: 4 / 3, // ~1.333
    displayName: '4:3 Landscape',
    label: '4:3',
    iconName: 'crop_landscape',
    description: 'Classic landscape format',
  );

  /// List of all available aspect ratios.
  /// 
  /// **To add a new aspect ratio:**
  /// 1. Define it as a static const above
  /// 2. Add it to this list
  /// 3. The UI will automatically display it!
  static const List<AspectRatio> all = [
    portrait,
    square,
    landscape,
    story,
    classicPortrait,
    classicLandscape,
  ];

  /// Get aspect ratio by ID
  static AspectRatio? findById(String id) {
    try {
      return all.firstWhere((ratio) => ratio.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Default aspect ratio when none is specified
  static const AspectRatio defaultRatio = portrait;
}
