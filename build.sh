#!/bin/bash
set -e

echo "Current directory: $(pwd)"

# Install Flutter
# We remove the existing directory to ensure we install the specific version matching the local environment
rm -rf flutter

echo "Cloning Flutter 3.29.2..."
git clone https://github.com/flutter/flutter.git -b 3.29.2 --depth 1

export PATH="$PATH:$(pwd)/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Enabling Web..."
flutter config --enable-web

echo "Cleaning build..."
flutter clean

echo "Getting dependencies..."
flutter pub get

echo "Building Web App..."
# Running with --verbose to capture detailed logs in case of failure
flutter build web --release --no-tree-shake-icons --verbose

