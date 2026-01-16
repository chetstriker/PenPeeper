#!/bin/bash
cd "$(dirname "$0")"
flutter build linux --release
echo "Build complete. Restart the app to see changes."
