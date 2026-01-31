#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Installing Flutter..."

# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Run flutter doctor to download dependencies
flutter doctor -v

echo "Enabling Web..."
flutter config --enable-web

echo "Getting dependencies..."
flutter pub get

echo "Building Web App..."
# Build web release
flutter build web --release --no-tree-shake-icons

echo "Build complete."
