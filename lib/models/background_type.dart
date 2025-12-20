enum BackgroundType {
  white,
  black,
  extendedBlur,
}

extension BackgroundTypeExtension on BackgroundType {
  String get displayName {
    switch (this) {
      case BackgroundType.white:
        return 'White';
      case BackgroundType.black:
        return 'Black';
      case BackgroundType.extendedBlur:
        return 'Blur';
    }
  }
}

