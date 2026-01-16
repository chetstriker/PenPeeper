@echo off
REM Copy theme files to Windows build output
if exist "build\windows\x64\runner\Release" (
    if not exist "build\windows\x64\runner\Release\Themes" mkdir "build\windows\x64\runner\Release\Themes"
    xcopy /Y /I "Themes\*.penTheme" "build\windows\x64\runner\Release\Themes\"
    echo Themes copied to Release build
)

if exist "build\windows\x64\runner\Debug" (
    if not exist "build\windows\x64\runner\Debug\Themes" mkdir "build\windows\x64\runner\Debug\Themes"
    xcopy /Y /I "Themes\*.penTheme" "build\windows\x64\runner\Debug\Themes\"
    echo Themes copied to Debug build
)
