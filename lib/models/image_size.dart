import 'package:equatable/equatable.dart';

class ImageSize extends Equatable {
  final int width;
  final int height;

  const ImageSize({required this.width, required this.height});

  @override
  List<Object?> get props => [width, height];

  ImageSize copyWith({int? width, int? height}) {
    return ImageSize(width: width ?? this.width, height: height ?? this.height);
  }

  Map<String, dynamic> toJson() {
    return {'width': width, 'height': height};
  }

  factory ImageSize.fromJson(Map<String, dynamic> json) {
    return ImageSize(
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }
}
