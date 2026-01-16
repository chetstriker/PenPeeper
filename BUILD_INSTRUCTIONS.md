# Build Instructions

## Setup (Run First)

Before building the application for any platform, ensure you have the Flutter SDK installed and run the following commands in the project root to clean and install dependencies:
 ```bash
 
 
 flutter clean
 flutter pub get
 ```

## Building for Windows

1. Build the application:
   ```powershell
   flutter build windows --release
   ```

2. Copy theme files to the build output:
   ```powershell
   .\copy_themes.bat
   ```

3. The executable and themes will be in: `build\windows\x64\runner\Release\`
   To run the compiled executable:
   ```powershell
   .\build\windows\x64\runner\Release\penpeeper.exe
   ```

## Building for Linux

1. Build the application:
   ```bash
   flutter build linux --release
   flutter build web --release --wasm
   ```

2. Copy theme files to the build output:
   ```bash
   chmod +x copy_themes.sh
   ./copy_themes.sh
   ```

3. The executable and themes will be in: `build/linux/x64/release/bundle/`

   Run as desktop app with GUI:
   ```bash
   ./build/linux/x64/release/bundle/penpeeper
   ```

   Run in terminal and control via webpage remotely:
   ```bash
   ./build/linux/x64/release/bundle/penpeeper --term
   ```
   (Navigate to web page at http://YOUR_LINUX_IP:8808/)

## Building for macOS

1. Build the application:
   ```bash
   flutter build macos --release
   ```

2. Copy theme files to the build output:
   ```bash
   chmod +x copy_themes.sh
   ./copy_themes.sh
   ```

3. The compiled app will be in: `build/macos/Build/Products/Release/penpeeper.app`
   
   To run the compiled executable directly from terminal:
   ```bash
   ./build/macos/Build/Products/Release/penpeeper.app/Contents/MacOS/penpeeper
   ```


## Creating Custom Themes

Users can create custom `.penTheme` files by:
1. Copying an existing theme file from the `Themes/` folder
2. Modifying the colors, icons, fonts, and spacing values
3. Saving it with a new name (e.g., `mytheme.penTheme`)
4. Placing it in the `Themes/` folder next to the executable

The application will automatically detect and load custom themes from the external `Themes/` folder, falling back to bundled themes if not found.
