# InstaFrame

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android"/>
  <img src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white" alt="iOS"/>
  <img src="https://img.shields.io/badge/Open%20Source-000000?style=for-the-badge&logo=github&logoColor=white" alt="Open Source"/>
  <img src="https://img.shields.io/badge/MIT-License-blue?style=for-the-badge" alt="MIT License"/>
</p>

> A simple, open-source photo framing tool designed specifically for Instagram content creators. Transform multiple photos with consistent framing, aspect ratios, and backgrounds in one seamless workflow.

## 📱 What is InstaFrame?

InstaFrame is a mobile app that simplifies photo preparation for Instagram creators. Instead of editing photos one by one, apply consistent framing to multiple photos at once - perfect for creating uniform carousels where each photo stands alone with professional borders and backgrounds.

### 🖼️ **Current: Framer Module**
The core functionality allows you to select multiple photos and apply consistent Instagram-optimized framing with white, black, or blur backgrounds.

### 🎞️ **Coming Soon: Photo Strip Module (V2.0)**
A planned feature to transform multiple photos into seamless carousel strips that flow together as one continuous visual story, automatically sliced into Instagram slides.

### 🎯 Key Features

#### 📸 **Core Features**
- **Multi-Photo Selection**: Select up to 30 photos from your gallery at once
- **Batch Export**: Process and save all photos simultaneously
- **Dark Mode**: Beautiful Material 3 theming with auto/light/dark modes
- **Smart Settings**: Remembers your preferences across sessions

#### 🖼️ **Framer Module (Current)**
- **Live Preview Carousel**: Swipe through photos with real-time preview of changes
- **Aspect Ratio Presets**: 6 Instagram-optimized ratios (4:5 Portrait, 1:1 Square, 16:9 Landscape, 9:16 Story, 3:4 Classic, 4:3 Classic)
- **Background Options**: White, Black, or intelligent Blur backgrounds
- **Scale Control**: Precise control over photo sizing (50-100%)
- **Blur Intensity**: Adjustable blur strength for extended backgrounds

#### 🎞️ **Photo Strip Module (Coming Soon in V2.0)**
- **Seamless Carousel Creation**: Transform multiple photos into flowing visual stories
- **Height-First Algorithm**: Content dictates the length, automatically sliced into Instagram slides
- **Gap Control**: Adjust spacing between images (0px for seamless)
- **Border Radius**: Round image corners within the strip
- **Container Controls**: Global padding and background options

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.10.4 or higher)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (iOS support coming soon)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/instaframe.git
   cd instaframe
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### 📦 Build for Release

```bash
# Build APK for Android
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release
```

## 📥 Download & Install

### Latest Release
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/your-username/instaframe?style=for-the-badge)](https://github.com/your-username/instaframe/releases/latest)
[![GitHub Release Downloads](https://img.shields.io/github/downloads/your-username/instaframe/total?style=for-the-badge)](https://github.com/your-username/instaframe/releases)

**Download the latest APK:**
1. Go to [Releases](https://github.com/your-username/instaframe/releases)
2. Download the latest `InstaFrame-vX.X.X.apk` file
3. Install on your Android device

### Installation Instructions
1. **Enable Unknown Sources**: On Android, go to Settings > Apps > Special access > Install unknown apps
2. **Download APK**: From the [latest release](https://github.com/your-username/instaframe/releases/latest)
3. **Install**: Open the downloaded APK file and follow the installation prompts
4. **Grant Permissions**: Allow camera/gallery access when prompted

*Note: APK installation requires Android 8.0+ and enabling installation from unknown sources.*

### Creating a New Release

For maintainers: Use the automated release script to build and publish new versions:

```bash
# Create a new release (this will trigger GitHub Actions)
./scripts/create_release.sh 1.0.0

# Or manually:
# 1. Build APK
flutter build apk --release

# 2. Rename with version
mv build/app/outputs/flutter-apk/app-release.apk InstaFrame-v1.0.0.apk

# 3. Create git tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 4. GitHub Actions will automatically create the release
```

*Note: Replace `your-username` in URLs with your actual GitHub username*

## 🎨 How to Use

### 🖼️ **Current: Framer Module**
1. **Select Photos**: Tap "Select Photos" to choose up to 30 images from your gallery
2. **Choose Aspect Ratio**: Pick from 6 Instagram-optimized presets (4:5, 1:1, etc.)
3. **Adjust Scale**: Use the slider to control photo size within the frame (50-100%)
4. **Select Background**: Choose White, Black, or Blur for the frame background
5. **Fine-tune Blur** (when blur selected): Adjust blur intensity (1-100)
6. **Export All**: Process and save all photos to your gallery with one tap

### 🎞️ **Coming Soon: Photo Strip Module (V2.0)**
A new module that will allow you to:
- Select a sequence of photos
- Create seamless carousel strips that flow together
- Automatically slice into Instagram-optimized slides
- Control gaps, borders, and container settings

## 🏗️ Architecture

InstaFrame follows clean architecture principles with BLoC pattern for state management:

```
lib/
├── blocs/                    # BLoC state management
│   ├── photo_bloc/          # Photo editing workflow (Framer)
│   └── preferences_bloc/    # App settings & preferences
├── models/                  # Data models
│   ├── aspect_ratio.dart    # Aspect ratio definitions
│   ├── photo_settings.dart  # Processing settings
│   └── user_preferences.dart # App preferences
├── screens/                 # UI screens
│   ├── home_screen.dart     # Landing page
│   ├── editor_screen.dart   # Main editing interface (Framer)
│   ├── photo_picker_screen.dart # Gallery picker
│   └── preferences_screen.dart  # Settings
├── services/                # Business logic
│   ├── image_processor.dart # Photo processing engine
│   ├── export_service.dart  # Batch export functionality
│   ├── preferences_service.dart # Settings persistence
│   └── feedback_service.dart # User feedback system
├── widgets/                 # Reusable UI components
│   ├── editor/             # Editor-specific widgets
│   └── preferences/        # Settings widgets
└── theme/                  # Material 3 theming
    └── app_theme.dart      # Color schemes & typography
```

*Note: Photo Strip module components (strip_bloc, strip_editor_screen, etc.) will be added in V2.0*

### 🛠️ Key Technologies

- **Flutter**: Cross-platform UI framework
- **BLoC Pattern**: Predictable state management
- **Photo Manager**: Native gallery access
- **Image Package**: High-performance image processing
- **Google Sans**: Modern, readable typography
- **Material 3**: Latest design system

## 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

### Ways to Contribute

- 🐛 **Bug Reports**: Found a bug? [Open an issue](https://github.com/your-username/instaframe/issues)
- 💡 **Feature Requests**: Have an idea? [Suggest it](https://github.com/your-username/instaframe/issues)
- 🔧 **Code Contributions**: Fix bugs or add features
- 📖 **Documentation**: Improve docs or add examples
- 🧪 **Testing**: Help test on different devices

### Development Setup

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following our coding standards
4. **Test thoroughly** on multiple devices
5. **Submit a pull request**

### Coding Standards

- Follow Flutter's [official style guide](https://flutter.dev/docs/development/tools/formatting)
- Use meaningful variable and function names
- Add comprehensive documentation (`///` comments)
- Write tests for new features
- Follow the existing BLoC naming conventions (Events end with "Event", States end with "State")

## 📋 Roadmap

### ✅ Version 1.0 - Core Framer (Released)
- Multi-photo selection and import
- Live preview carousel with GPU acceleration
- 6 aspect ratio presets (4:5, 1:1, 16:9, 9:16, 3:4, 4:3)
- Scale and blur intensity controls
- White/Black/Blur backgrounds
- Batch export with isolate processing
- Material 3 theming with dark mode
- Performance optimized (zero main thread blocking)

### 🔄 Version 2.0 - Multi-Module Suite (In Development)
- **Module Selector Screen**: Choose between Framer and Photo Strip tools
- **Photo Strip Module**: Seamless carousel creation
  - Height-first algorithm for automatic slide generation
  - Gap and border radius controls
  - Global padding and background options
  - EXIF metadata preservation across slices
- **Enhanced Architecture**: Separate StripBloc for Photo Strip workflow
- **Improved Navigation**: Clean module selection flow

### 🚀 Version 2.1 (Future)
- Custom preset saving for both modules
- Fine-tuning controls (position alignment)
- Palette generator for suggested background colors
- Performance optimizations for Photo Strip

### 💎 Version 3.0+ (Long-term)
- Advanced export options (PNG/JPG, quality settings)
- Share menu integration
- iOS support
- Premium backgrounds (gradients, patterns)
- Watermarking features
- Cloud backup for presets
- Monetization options

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ for Instagram content creators
- Special thanks to the Flutter and Dart communities
- Icons and assets used are either custom or from open-source libraries

## 📞 Support

- 📧 **Email**: rishabms80@gmail.com
- 🐛 **Issues**: [GitHub Issues](https://github.com/your-username/instaframe/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/your-username/instaframe/discussions)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/rishabms">Rishab Sanjay</a>
</p>
