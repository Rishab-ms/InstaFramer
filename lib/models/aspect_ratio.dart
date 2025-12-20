enum AspectRatioType {
  portrait, // 4:5
  square, // 1:1
}

extension AspectRatioExtension on AspectRatioType {
  String get displayName {
    switch (this) {
      case AspectRatioType.portrait:
        return '4:5 Portrait';
      case AspectRatioType.square:
        return '1:1 Square';
    }
  }

  double get ratio {
    switch (this) {
      case AspectRatioType.portrait:
        return 4 / 5; // 0.8
      case AspectRatioType.square:
        return 1.0;
    }
  }
}

