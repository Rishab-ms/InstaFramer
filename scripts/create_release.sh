#!/bin/bash

# InstaFrame Release Script
# This script builds the APK and creates a GitHub release

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 InstaFrame Release Script${NC}"

# Check if version is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: Please provide a version number${NC}"
    echo -e "${YELLOW}Usage: $0 <version>${NC}"
    echo -e "${YELLOW}Example: $0 1.0.0${NC}"
    exit 1
fi

VERSION=$1
TAG="v${VERSION}"

echo -e "${BLUE}📦 Building InstaFrame v${VERSION}${NC}"

# Clean and get dependencies
echo -e "${YELLOW}🔧 Installing dependencies...${NC}"
flutter clean
flutter pub get

# Build APK
echo -e "${YELLOW}🏗️ Building APK...${NC}"
flutter build apk --release

# Rename APK with version
APK_NAME="InstaFrame-v${VERSION}.apk"
mv build/app/outputs/flutter-apk/app-release.apk "${APK_NAME}"

echo -e "${GREEN}✅ APK built: ${APK_NAME}${NC}"

# Create git tag
echo -e "${YELLOW}🏷️ Creating git tag...${NC}"
git tag -a "${TAG}" -m "Release ${TAG}"

# Push tag to trigger GitHub Actions
echo -e "${YELLOW}📤 Pushing tag to GitHub...${NC}"
git push origin "${TAG}"

echo -e "${GREEN}🎉 Release ${TAG} created!${NC}"
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "  1. GitHub Actions will automatically build and create the release"
echo -e "  2. Go to https://github.com/your-username/instaframe/releases"
echo -e "  3. Edit the release notes and publish"
echo -e "  4. Users can now download ${APK_NAME} from the releases page"

# Optional: Open browser to releases page
if command -v open &> /dev/null; then
    echo -e "${BLUE}🌐 Opening releases page...${NC}"
    open "https://github.com/your-username/instaframe/releases"
fi
