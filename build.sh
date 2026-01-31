#!/bin/bash
set -e

echo "Current directory: $(pwd)"

# Install Flutter
# We remove the existing directory to ensure we install the specific version matching the local environment
rm -rf flutter

echo "Cloning Flutter (Specific Commit)..."
git clone https://github.com/flutter/flutter.git stable_flutter --depth 100
cd stable_flutter
# Checkout the specific revision c236373904 (Flutter 3.29.2) matching local environment
git checkout c236373904
cd ..
mv stable_flutter flutter

# Prepend to PATH to ensure our version is used instead of any system pre-installed version
export PATH="$(pwd)/flutter/bin:$PATH"

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

