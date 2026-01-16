#!/bin/bash
# Copy theme files to Linux/macOS build output

# Linux
if [ -d "build/linux/x64/release/bundle" ]; then
    mkdir -p "build/linux/x64/release/bundle/Themes"
    cp Themes/*.penTheme "build/linux/x64/release/bundle/Themes/"
    echo "Themes copied to Linux release build"
fi

# macOS Debug
if [ -d "build/macos/Build/Products/Debug/penpeeper.app/Contents/Resources" ]; then
    mkdir -p "build/macos/Build/Products/Debug/penpeeper.app/Contents/Resources/Themes"
    cp Themes/*.penTheme "build/macos/Build/Products/Debug/penpeeper.app/Contents/Resources/Themes/"
    echo "Themes copied to macOS debug build"
fi

# macOS Release
if [ -d "build/macos/Build/Products/Release/penpeeper.app/Contents/Resources" ]; then
    mkdir -p "build/macos/Build/Products/Release/penpeeper.app/Contents/Resources/Themes"
    cp Themes/*.penTheme "build/macos/Build/Products/Release/penpeeper.app/Contents/Resources/Themes/"
    echo "Themes copied to macOS release build"
fi
