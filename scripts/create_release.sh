#!/bin/bash

# InstaFrame Release Script
# Builds APK (if needed) and creates a GitHub release tag

set -e

# ----------------------------
# Colors
# ----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 InstaFrame Release Script${NC}"

# ----------------------------
# Args
# ----------------------------
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: Please provide a version number${NC}"
    echo -e "${YELLOW}Usage: $0 <version> [--force]${NC}"
    echo -e "${YELLOW}Example: $0 1.2.4 --force${NC}"
    exit 1
fi

VERSION="$1"
FORCE_BUILD=false

if [[ "$2" == "--force" ]]; then
    FORCE_BUILD=true
fi

TAG="v${VERSION}"
APK_NAME="InstaFrame-v${VERSION}.apk"

echo -e "${BLUE}📦 Preparing release ${TAG}${NC}"

# ----------------------------
# APK build logic
# ----------------------------
if [[ -f "${APK_NAME}" && "${FORCE_BUILD}" == false ]]; then
    echo -e "${GREEN}✅ APK already exists: ${APK_NAME}${NC}"
    echo -e "${GREEN}♻️ Reusing existing APK (use --force to rebuild)${NC}"
else
    if [[ -f "${APK_NAME}" ]]; then
        echo -e "${YELLOW}⚠️ APK exists but --force specified. Rebuilding...${NC}"
    else
        echo -e "${YELLOW}🏗️ APK not found. Building...${NC}"
    fi

    echo -e "${YELLOW}🔧 Installing dependencies...${NC}"
    flutter clean
    flutter pub get

    echo -e "${YELLOW}🏗️ Building APK...${NC}"
    flutter build apk --release

    mv build/app/outputs/flutter-apk/app-release.apk "${APK_NAME}"

    echo -e "${GREEN}✅ APK built: ${APK_NAME}${NC}"
fi

# ----------------------------
# GitHub authentication (forced)
# ----------------------------
if [ -z "$GITHUB_PAT" ]; then
    echo -e "${RED}❌ GITHUB_PAT not set. Aborting.${NC}"
    exit 1
fi

echo -e "${YELLOW}🔐 Configuring GitHub authentication...${NC}"

git config user.name "Rishab"
git config user.email "rishabms80@gmail.com"

ORIGINAL_REMOTE=$(git remote get-url origin)
git remote set-url origin "https://Rishab-ms:${GITHUB_PAT}@github.com/Rishab-ms/InstaFramer.git"

# ----------------------------
# Git tagging
# ----------------------------
if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo -e "${RED}❌ Git tag ${TAG} already exists. Aborting.${NC}"
    git remote set-url origin "$ORIGINAL_REMOTE"
    exit 1
fi

echo -e "${YELLOW}🏷️ Creating git tag...${NC}"
git tag -a "${TAG}" -m "Release ${TAG}"

echo -e "${YELLOW}📤 Pushing tag to GitHub...${NC}"
git push origin "${TAG}"

# Restore remote
git remote set-url origin "$ORIGINAL_REMOTE"

# ----------------------------
# Done
# ----------------------------
echo -e "${GREEN}🎉 Release ${TAG} created successfully!${NC}"
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "  1. GitHub Actions will run automatically"
echo -e "  2. Review release at:"
echo -e "     https://github.com/Rishab-ms/InstaFramer/releases"
echo -e "  3. Publish release & upload ${APK_NAME}"

if command -v open &> /dev/null; then
    open "https://github.com/Rishab-ms/InstaFramer/releases"
fi

