# Data Directory Migration Guide for PenPeeper

## Overview

The PenPeeper application has been refactored to use platform-specific user data directories instead of storing all data in the current working directory. This change is necessary for proper distribution as a Linux package and better follows platform conventions.

## Platform-Specific Data Locations

### Linux
- **Data Directory**: `~/.local/share/penpeeper/`
- **Database**: `~/.local/share/penpeeper/penpeeper.db`
- **Uploads**: `~/.local/share/penpeeper/uploads/`
- **Themes**: `~/.local/share/penpeeper/Themes/`
- **Config**: `~/.local/share/penpeeper/config.json`
- **Logs**: `~/.local/share/penpeeper/debug.logs`
- **Temp Files**: `/tmp/penpeeper_scans/`

### macOS
- **Data Directory**: `~/Library/Application Support/com.penpeeper.app/`
- **Database**: `~/Library/Application Support/com.penpeeper.app/penpeeper.db`
- **Uploads**: `~/Library/Application Support/com.penpeeper.app/uploads/`
- **Themes**: `~/Library/Application Support/com.penpeeper.app/Themes/`
- **Config**: `~/Library/Application Support/com.penpeeper.app/config.json`
- **Logs**: `~/Library/Application Support/com.penpeeper.app/debug.logs`
- **Temp Files**: `$TMPDIR/penpeeper_scans/`

### Windows
- **Data Directory**: `%APPDATA%\penpeeper\` (typically `C:\Users\Username\AppData\Roaming\penpeeper\`)
- **Database**: `%APPDATA%\penpeeper\penpeeper.db`
- **Uploads**: `%APPDATA%\penpeeper\uploads\`
- **Themes**: `%APPDATA%\penpeeper\Themes\`
- **Config**: `%APPDATA%\penpeeper\config.json`
- **Logs**: `%APPDATA%\penpeeper\debug.logs`
- **Temp Files**: `%TEMP%\penpeeper_scans\`

### Web
- **Database**: IndexedDB (via API calls)
- **Uploads/Themes**: Memory/API storage

## Automatic Migration

The application automatically detects legacy data in the current directory and migrates it to the new location on first run. This includes:

- SQLite database (including WAL files)
- Uploads directory
- Config file
- Custom themes

## Files Updated

### Core Services
- ✅ `lib/services/app_paths_service.dart` - **NEW** Centralized path management
- ✅ `lib/main.dart` - Initialize paths service at startup
- ✅ `lib/database_helper.dart` - Use new database path
- ✅ `lib/database/connection/database_connection.dart` - Use new database path
- ✅ `lib/platform/database/desktop_database_service.dart` - Use new database path
- ✅ `lib/database/isolate/database_write_service.dart` - Use new database path in isolate

### Image Management
- ✅ `lib/services/image_manager.dart` - Use new uploads paths

### Theme Management
- ✅ `lib/theme_loader.dart` - Use new themes paths (user + bundled)

### Configuration & Logging
- ✅ `lib/services/config_service.dart` - Use new config path
- ✅ `lib/utils/debug_logger.dart` - Use new debug log path

### Scan Services (Temporary Files)
- ✅ `lib/services/nmap_scan_service.dart` - Use temp scan directory
- ✅ `lib/services/nikto_scan_service.dart` - Use temp scan directory
- ✅ `lib/services/ffuf_scan_service.dart` - Use temp scan directory
- ✅ `lib/services/whatweb_scan_service.dart` - Use temp scan directory
- ✅ `lib/services/enum4linux_scan_service.dart` - Use temp scan directory
- ✅ `lib/services/searchsploit_scan_service.dart` - Use temp scan directory
- ✅ `lib/services/snmp_scan_service.dart` - Use temp scan directory (WSL support)

### Repositories
- ✅ `lib/repositories/project_repository.dart` - Use new uploads path for deletion

### Server & API Routes
- ✅ `lib/server/routes/system_routes.dart` - Updated themes and uploads API routes
- ✅ `lib/server/api_router.dart` - Updated debug logging and image serving routes

### Export/Import Services
- ✅ `lib/services/export_import/import_service.dart` - Extract to new uploads path
- ✅ `lib/services/export_import/file_extractor.dart` - Extract to correct paths
- ✅ `lib/services/export_import/archive_service.dart` - Read from correct paths

### Helpers & Utilities
- ✅ `lib/utils/image_path_helper.dart` - Helper for resolving image paths

### Files with Directory.current (No changes needed)
These files use `Directory.current` for appropriate reasons:
- `lib/services/scan_orchestrator.dart` - Working directory for scan processes
- `lib/services/process_monitor.dart` - Process monitoring
- `lib/services/readiness_check_service.dart` - Tool detection in PATH
- `lib/device_icon_helper.dart` - Icon lookup (has fallbacks)
- Various scan services - Already updated to use temp directories

## Bundled vs User Data

### Bundled Themes (Read-Only)
Themes that ship with the application are stored in:
- Linux package: `/usr/share/penpeeper/Themes/` or similar
- macOS: Inside the app bundle
- Windows: Next to the executable

### User Themes (Writable)
Users can add custom themes to the writable themes directory which takes precedence over bundled themes.

## Testing Checklist

### Desktop (Linux/macOS/Windows)
- [ ] First run creates data directories
- [ ] Legacy data is migrated automatically
- [ ] Database operations work correctly
- [ ] Image uploads work and are stored in correct location
- [ ] Image display works (reads from correct location)
- [ ] Themes load correctly (both bundled and user themes)
- [ ] Config file is read/written correctly
- [ ] Debug logging works
- [ ] Scan temporary files are created in temp directory
- [ ] Scan temporary files are cleaned up
- [ ] Project deletion removes uploads folder
- [ ] Export/import preserves uploads
- [ ] Reports include images correctly

### Web
- [ ] API calls work for database operations
- [ ] Image uploads via API work
- [ ] Themes are loaded via API

## Dependencies Added

- `path_provider: ^2.1.5` - For getting platform-specific directories

## Breaking Changes

### For End Users
- **None** - Automatic migration handles moving old data

### For Developers
- All file path operations must now use `AppPathsService()` instead of `Directory.current.path`
- The `AppPathsService` must be initialized in `main()` before any database operations
- Temporary scan files now go to a dedicated temp directory instead of current directory

## Benefits

1. **Proper Linux Package Support**: Data can be separated from read-only installation
2. **Platform Conventions**: Follows standard data storage conventions for each OS
3. **User Data Protection**: Data is stored in user-specific directories
4. **Multi-User Support**: Each user has their own data on shared systems
5. **Cleaner Installation**: No data files mixed with application files

## Rollback

If you need to rollback to the old behavior (not recommended):
1. Remove the `AppPathsService` initialization from `main.dart`
2. Revert all path service calls to use `Directory.current.path`
3. Remove the `path_provider` dependency

## Support

For issues or questions about this migration, please file an issue at:
https://github.com/anthropics/claude-code/issues
