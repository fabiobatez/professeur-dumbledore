#!/bin/bash
set -e

echo "Current directory: $(pwd)"

# Install Flutter
if [ -d "flutter" ]; then
  echo "Flutter directory exists, skipping clone..."
else
  echo "Cloning Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

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

