#!/bin/bash

# -----------------------
# CONFIGURATION
# -----------------------
TAG=$1                  # Example: v1.0.0
CHECK_ONLY=$2
TITLE="Revision $TAG"   # Release title
KANJI_DIR="kanji"
DIST_DIR="dist"
ZIP_PATH="$DIST_DIR/kanjis.zip"
# -----------------------

# Validate arguments
if [ -z "$TAG" ] || [ -z "$ZIP_PATH" ]; then
  echo "Usage: $0 <tag> [--status]"
  exit 1
fi

# -----------------------
# GENERATE ZIP
# -----------------------
mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/kanjis.zip"
echo "Generating ZIP from kanji/ → $ZIP_PATH"
zip -j "$ZIP_PATH" "$KANJI_DIR"/*.json >/dev/null 2>&1

# -----------------------
# DETECT CHANGES
# -----------------------
# From last tag to HEAD
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  RANGE="HEAD"
else
  RANGE="$LAST_TAG..HEAD"
fi

# Added and modified files
NEW_FILES=$(git diff --name-status $RANGE | grep '^A' | awk '{print $2}')
MODIFIED_FILES=$(git diff --name-status $RANGE | grep '^M' | awk '{print $2}')

# -----------------------
# FILTER CHANGES
# -----------------------
# New JSON → New Kanji
NEW_KANJI=$(echo "$NEW_FILES" | grep '\.json$' | awk -F/ '{print $NF}' | sed 's/\.json//')

# Modified JSON → Updated Kanji
UPDATED_KANJI=$(echo "$MODIFIED_FILES" | grep '\.json$' | awk -F/ '{print $NF}' | sed 's/\.json//')

# README.md
README_UPDATED=$(echo "$MODIFIED_FILES" | grep 'README.md')

# Other changes (excluding .json and README.md)
OTHER_CHANGES=$(echo -e "$NEW_FILES\n$MODIFIED_FILES" | grep -v '\.json$' | grep -v 'README.md')

# -----------------------
# BUILD DESCRIPTION
# -----------------------
DESCRIPTION=""

if [ -n "$NEW_KANJI" ]; then
  DESCRIPTION="$DESCRIPTION- New Kanji: $(echo $NEW_KANJI | tr ' ' ', ')\n"
fi

if [ -n "$README_UPDATED" ]; then
  DESCRIPTION="$DESCRIPTION- Update README\n"
fi

if [ -n "$UPDATED_KANJI" ]; then
  DESCRIPTION="$DESCRIPTION- Update Kanji: $(echo $UPDATED_KANJI | tr ' ' ', ')\n"
fi

if [ -n "$OTHER_CHANGES" ]; then
  CLEANED=$(echo "$OTHER_CHANGES" | sed '/^$/d')
  COUNT=$(echo "$OTHER_CHANGES" | wc -l)
  if [ "$COUNT" -eq 1 ]; then
    LINE="- Other changes: $CLEANED"
  else
    LINE="- Other changes: $(echo "$CLEANED" | paste -sd ',' - | sed 's/,$//')"
  fi
  DESCRIPTION="$DESCRIPTION$LINE\n"
fi

# -----------------------
# PRINT OR CREATE RELEASE
# -----------------------
echo -e "=============================="
echo -e "Description that would be used:"
echo -e "=============================="
echo -e "$DESCRIPTION"

if [ "$CHECK_ONLY" != "--status" ]; then
  echo -e "Creating release $TAG..."
  gh release create "$TAG" "$ZIP_PATH" \
    --title "$TITLE" \
    --notes "$(printf '%b' "$DESCRIPTION")"
  echo "Release $TAG created successfully."
  echo "Description: $DESCRIPTION"
else
  echo -e "\n--status enabled: release will not be created."
fi

