#!/bin/bash
# Post-install script for PenPeeper
# Updates desktop database so the application appears in menus immediately

# Update desktop database (if available)
if command -v update-desktop-database &> /dev/null; then
    echo "Updating desktop database..."
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# Update icon cache (if available)
if command -v gtk-update-icon-cache &> /dev/null; then
    echo "Updating icon cache..."
    gtk-update-icon-cache -f -t /usr/share/pixmaps 2>/dev/null || true
fi

echo "PenPeeper has been installed successfully!"
echo "You can now launch it from your application menu or by running 'penpeeper' in the terminal."
