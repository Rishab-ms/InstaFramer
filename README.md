# InstaFrame

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android"/>
  <img src="https://img.shields.io/badge/Open%20Source-000000?style=for-the-badge&logo=github&logoColor=white" alt="Open Source"/>
  <img src="https://img.shields.io/badge/MIT-License-blue?style=for-the-badge" alt="MIT License"/>
</p>

> An open-source photo framing tool for Instagram. Apply the same aspect ratio, scale and background across a batch of photos in one pass.

## What is InstaFrame?

InstaFrame is a mobile app for preparing photos for Instagram. Instead of editing them one at a time, you frame a whole batch at once, which is what makes a carousel look like a set rather than a pile.

## Screenshots

<p align="center">
<b>Home</b>
</p>
<p align="center">
<img src="https://github.com/user-attachments/assets/77a347a6-40d7-4f7f-8a11-52a9cc5bf531" width="30%" />
</p>

<p align="center">
<b>Framer</b>
</p>
<p align="center">
<img src="https://github.com/user-attachments/assets/ef58b0d6-58c5-4993-ab04-08f354b7e4d1" width="30%" />
<img src="https://github.com/user-attachments/assets/86868119-cf7a-480c-a55f-7461372ed8d2" width="30%" />
<img src="https://github.com/user-attachments/assets/9de361d8-bbb0-416a-9552-275e6367b3d9" width="30%" />
</p>

<p align="center">
<b>Panorama</b>
</p>
<p align="center">
<img src="https://github.com/user-attachments/assets/bfdb0767-b605-40b4-ae2f-b530fa87eb4a" width="30%" />
<img src="https://github.com/user-attachments/assets/88b2801b-3bbc-4508-a151-6c662d5be934" width="30%" />
<img src="https://github.com/user-attachments/assets/b6839d2c-ba44-4eca-b7e1-3d6207377466" width="30%" />
</p>

## Download & Install

### Latest Release
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/Rishab-ms/InstaFramer?include_prereleases&style=for-the-badge)](https://github.com/Rishab-ms/InstaFramer/releases/latest)
[![GitHub Release Downloads](https://img.shields.io/github/downloads/Rishab-ms/InstaFramer/total?style=for-the-badge)](https://github.com/Rishab-ms/InstaFramer/releases)

**Download the latest APK:**
1. Go to [Releases](https://github.com/Rishab-ms/InstaFramer/releases)
2. Download the latest `InstaFrame-vX.X.X.apk` file
3. Install on your Android device

### Installation Instructions
1. **Enable Unknown Sources**: On Android, go to Settings > Apps > Special access > Install unknown apps
2. **Download APK**: From the [latest release](https://github.com/Rishab-ms/InstaFramer/releases/latest)
3. **Install**: Open the downloaded APK file and follow the installation prompts
4. **Grant Permissions**: Allow camera/gallery access when prompted

*Note: APK installation requires Android 8.0+ and enabling installation from unknown sources. Since InstaFrame isn't on the Play Store, Android and Play Protect will show warnings during install (e.g. "Unsafe app blocked" or "Unrecognized app") — this happens for any sideloaded app and isn't a sign the file itself is unsafe. Tap "More details" > "Install anyway" to proceed.*

### Modules

| Module | What it does |
|---|---|
| **Framer** | Select multiple photos and apply consistent Instagram-optimized framing with white, black, or blur backgrounds. |
| **Panorama** | Split one wide or panoramic photo into several 4:5 tiles you upload as a carousel, so the shot reads as one continuous panorama when swiped — instead of a 16:9 or 21:9 image that gets shown tiny in the feed. |

### Coming Soon: Photo Strip Module (V2.0)
A planned feature to transform multiple photos into seamless carousel strips that flow together as one continuous visual story, automatically sliced into Instagram slides.

### Key Features

#### **Core Features**
- **Multi-Photo Selection**: Select up to 30 photos from your gallery at once
- **Share Menu Import**: Share photos to InstaFrame straight from your gallery or any other app (Android)
- **Batch Export**: Process and save all photos simultaneously
- **EXIF Preservation**: Camera, lens, and location metadata is carried over to exported photos (toggleable in Settings)
- **Dark Mode**: Material 3 theming with auto/light/dark modes
- **Smart Settings**: Remembers your preferences across sessions

#### **Framer Module (Current)**
- **Live Preview Carousel**: Swipe through photos with real-time preview of changes
- **Aspect Ratio Presets**: 6 Instagram-optimized ratios (4:5 Portrait, 1:1 Square, 16:9 Landscape, 9:16 Story, 3:4 Classic, 4:3 Classic)
- **Background Options**: White, Black, or intelligent Blur backgrounds
- **Scale Control**: Precise control over photo sizing (50-100%)
- **Blur Intensity**: Adjustable blur strength for extended backgrounds

#### **Panorama Module**
- **One Photo, One Carousel**: Slice a single wide shot into 4:5 tiles that swipe together as a continuous panorama
- **Smart Tile Count**: Suggests the number of tiles that best fits your photo, and lets you override it
- **Fit or Fill**: *Fit* keeps every pixel and pads the edges with White/Black/Blur; *Fill* crops edge-to-edge for a full-bleed look
- **Live Seam Guides**: See exactly where each tile boundary lands before you export
- **Horizontal Position**: Slide the photo left or right to choose where the tile boundaries fall
- **Vertical Position** (Fill only): Choose which band of the photo the crop keeps, with rule-of-thirds guides while you drag
- **Quality Readout**: Shows each slide's output resolution as you change the tile count, and warns when edge tiles would come out mostly empty
- **Guaranteed Order**: Tiles are saved so they appear left-to-right in Instagram's picker, ready to tap in sequence

#### **Photo Strip Module (Coming Soon in V2.0)**
- **Continuous Strips**: Lay several photos end to end and slice the result into slides
- **Height-First Algorithm**: Content dictates the length, automatically sliced into Instagram slides
- **Gap Control**: Adjust spacing between images (0px for seamless)
- **Border Radius**: Round image corners within the strip
- **Container Controls**: Global padding and background options

## Quick Start

### Prerequisites
- Flutter SDK 3.44 or higher (Dart 3.10.4 or higher)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (iOS support coming soon)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Rishab-ms/InstaFramer.git
   cd InstaFramer
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Build for Release

```bash
# Build APK for Android
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release
```

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

## How to Use

### **Current: Framer Module**
1. **Select Photos**: Tap "Select Photos" to choose up to 30 images from your gallery
2. **Choose Aspect Ratio**: Pick from 6 Instagram-optimized presets (4:5, 1:1, etc.)
3. **Adjust Scale**: Use the slider to control photo size within the frame (50-100%)
4. **Select Background**: Choose White, Black, or Blur for the frame background
5. **Fine-tune Blur** (when blur selected): Adjust blur intensity (1-100)
6. **Export All**: Process and save all photos to your gallery with one tap

*Tip: you can also share photos to InstaFrame from your gallery's share menu instead of picking them in-app.*

### **Panorama Module**
1. **Start a Panorama**: Tap "Create a Panorama Carousel" on the home screen, or share a single wide photo to InstaFrame and choose "Panorama Carousel" in the popup
2. **Set the Tile Count**: The app suggests the count that best fits your photo. Override it to trade padding for taller, more dramatic slices
3. **Choose Fit or Fill**: *Fit* keeps the whole photo and pads the edges; *Fill* crops to edge-to-edge with no bars
4. **Adjust the Frame** (Fit only): Pick a White, Black, or Blur background and fine-tune the scale
5. **Position the Photo**: It starts centred. Slide it left or right to move the tile boundaries, or up and down in Fill mode to pick which band the crop keeps
6. **Export Tiles**: Save all tiles to your gallery in one tap
7. **Upload in Order**: In Instagram, tap the tiles **left to right**. They're saved so the gallery grid already shows them in the right order, and numbered `_pano_01_of_04` so you can double-check

*Requires a landscape photo wider than 6:5 and at least 2160px wide. Camera and location metadata isn't preserved in panorama tiles.*

### **Coming Soon: Photo Strip Module (V2.0)**
A new module that will allow you to:
- Select a sequence of photos
- Create seamless carousel strips that flow together
- Automatically slice into Instagram-optimized slides
- Control gaps, borders, and container settings

## Architecture

InstaFrame follows clean architecture principles with BLoC pattern for state management:

```
lib/
├── blocs/                    # BLoC state management
│   ├── photo_bloc/          # Photo editing workflow (Framer)
│   ├── panorama_bloc/       # Panorama split workflow
│   └── preferences_bloc/    # App settings & preferences
├── models/                  # Data models
│   ├── aspect_ratio.dart    # Aspect ratio definitions
│   ├── photo_settings.dart  # Processing settings
│   ├── panorama_spec.dart   # Panorama constants & eligibility
│   ├── panorama_settings.dart # Tile count, fit mode, canvas sizing
│   └── user_preferences.dart # App preferences
├── screens/                 # UI screens
│   ├── home_screen.dart     # Landing page
│   ├── editor_screen.dart   # Main editing interface (Framer)
│   ├── panorama_editor_screen.dart # Panorama interface
│   ├── photo_picker_screen.dart # Gallery picker
│   └── preferences_screen.dart  # Settings
├── services/                # Business logic
│   ├── image_processor.dart # Photo processing engine (framing + panorama slicing)
│   ├── export_service.dart  # Batch & sequential export functionality
│   ├── preferences_service.dart # Settings persistence
│   └── feedback_service.dart # User feedback system
├── widgets/                 # Reusable UI components
│   ├── editor/             # Editor-specific widgets
│   ├── panorama/           # Panorama-specific widgets
│   ├── home/               # Home screen widgets
│   └── preferences/        # Settings widgets
└── theme/                  # Material 3 theming
    └── app_theme.dart      # Color schemes & typography
```

*Note: Photo Strip module components (strip_bloc, strip_editor_screen, etc.) are planned, not yet built. See `plans/implementation_plan.md` for the full spec.*

### Key Technologies

- **Flutter**: Cross-platform UI framework
- **BLoC Pattern**: Predictable state management
- **Photo Manager**: Native gallery access
- **Image Package**: High-performance image processing
- **Google Sans**: Modern, readable typography
- **Material 3**: Latest design system

## Contributing

Contributions are welcome.

### Ways to Contribute

- **Bug Reports**: Found a bug? [Open an issue](https://github.com/Rishab-ms/InstaFramer/issues)
- **Feature Requests**: Have an idea? [Suggest it](https://github.com/Rishab-ms/InstaFramer/issues)
- **Code Contributions**: Fix bugs or add features
- **Documentation**: Improve docs or add examples
- **Testing**: Help test on different devices

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

## Roadmap

### Version 1.0 - Core Framer (Released)
- Multi-photo selection and import
- Live preview carousel with GPU acceleration
- 6 aspect ratio presets (4:5, 1:1, 16:9, 9:16, 3:4, 4:3)
- Scale and blur intensity controls
- White/Black/Blur backgrounds
- Batch export with isolate processing
- Material 3 theming with dark mode
- Performance optimized (zero main thread blocking)
- Share menu import (Android)
- EXIF metadata preservation

### Panorama Module (Released)
- One wide photo → an N-tile 4:5 carousel
- Auto-suggested tile count with manual override
- Fit (pad with White/Black/Blur) and Fill (edge-to-edge crop) modes
- Live preview with seam guides and tile numbers
- Horizontal and vertical position controls, with rule-of-thirds guides on the vertical drag
- Live quality readout and empty-tile warnings
- Sequential, order-guaranteed export so the carousel reads correctly
- Share-intent entry: share one wide photo and pick Frame or Panorama
- In-framer suggestion when a very wide photo would letterbox badly
- Separate PanoramaBloc alongside PhotoBloc
- Background colors sampled from the photo's own palette, alongside White/Black/Blur

### Version 2.0 - Multi-Module Suite (In Development)
- **Module Selector Screen**: Choose between Framer, Panorama and Photo Strip tools, replacing the home screen's current text-link entry point for Panorama
- **Photo Strip Module**: Seamless carousel creation
  - Height-first algorithm for automatic slide generation
  - Gap and border radius controls
  - Global padding and background options
  - EXIF metadata preservation across slices
- **Enhanced Architecture**: Separate StripBloc alongside PhotoBloc and PanoramaBloc
- **Improved Navigation**: Clean module selection flow

### Version 2.1 (Future)
- Custom preset saving for all modules
- Performance optimizations for Photo Strip
- **Panorama refinements**: free pan/zoom reframe, per-tile scrub preview, tile overlap, non-4:5 tile ratios, standalone "cover tile"

### Version 3.0+ (Long-term)
- Advanced export options (PNG/JPG, quality settings)
- iOS support
- Premium backgrounds (gradients, patterns)
- Watermarking features
- Cloud backup for presets
- Monetization options

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built for Instagram content creators
- Special thanks to the Flutter and Dart communities
- Icons and assets used are either custom or from open-source libraries

## Support

- **Email**: rishabms80@gmail.com
- **Issues**: [GitHub Issues](https://github.com/Rishab-ms/InstaFramer/issues)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Rishab-ms">Rishab Sanjay</a>
</p>
