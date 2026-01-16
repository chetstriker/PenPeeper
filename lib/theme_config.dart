// PenPeeper Theme Configuration
// This file contains all colors, icons, images, and fonts used in the application
// Modify values here to create custom themes

import 'package:flutter/material.dart';
import 'theme_loader.dart';
import 'gradient_config.dart';

class AppTheme {
  static void resetInitialized() {
    // Reset method for theme reloading
  }

  // ===== COLORS =====

  // Primary Colors - Used for main interactive elements, buttons, links
  static Color primaryColor = const Color(0xFF4FC3F7);
  static Color secondaryColor = const Color(0xFF29B6F6);

  // Background Colors - Used for scaffolds, containers, cards
  static Color scaffoldBackground = const Color(0xFF1E1E1E);
  static Color surfaceColor = const Color(0xFF2B2B2B);
  static Color cardBackground = const Color(0xFF2B2B2B);
  static Color inputBackground = const Color(0xFF3C3C3C);
  static Color darkBackground = const Color(0xFF0D1117);
  static Color mediumBackground = const Color(0xFF21262D);

  // Text Colors - Used for all text elements
  static Color textPrimary = const Color(0xFFE0E0E0);
  static Color textSecondary = const Color(0xFFB0B0B0);
  static Color textTertiary = const Color(0xFF888888);
  static Color textMuted = const Color(0xFF8B949E);

  // Icon Colors - Used for icon elements
  static Color iconSecondary = const Color(0xFF888888);
  static Color textOnPrimary = const Color(0xFF000000);
  static Color textOnSecondary = const Color(0xFF000000);

  // Border Colors - Used for outlines, dividers, borders
  static Color borderPrimary = const Color(0xFF4A4A4A);
  static Color borderSecondary = const Color(0xFF30363D);

  // Status Colors - Used for alerts, warnings, errors, success
  static Color errorColor = Colors.red;
  static Color warningColor = Colors.orange;
  static Color successColor = Colors.green;
  static Color infoColor = const Color(0xFF4FC3F7);

  // Scan Button Colors - Used for scan action buttons
  static Color scanAddColor = Colors.red;
  static Color scanNmapColor = Colors.orange;
  static Color scanNiktoColor = Colors.yellow;
  static Color scanSearchsploitColor = Colors.green;
  static Color scanWhatwebColor = Colors.blue;
  static Color scanEnum4linuxColor = Colors.indigo;
  static Color scanFfufColor = Colors.purple;
  static Color scanSnmpColor = Colors.teal;
  static Color scanProcessNmapColor = Colors.red;
  static Color scanSambaLdapColor = Colors.brown;
  static Color scanCyanColor = Colors.cyan;

  // Magic Button Colors
  static Color magicButtonColor = const Color(0xFF0077BE);

  // Search Filter Colors - Used for "Search by" PopupMenuButtons
  static Color searchOsBorderColor = Colors.lightBlue;
  static IconData searchOsIcon = Icons.circle;
  static Color searchOsIconColor = Colors.lightBlue;
  static Color searchOsDividerColor = Colors.lightBlue;

  static Color searchVendorBorderColor = const Color(0xFFFBC02D);
  static IconData searchVendorIcon = Icons.circle;
  static Color searchVendorIconColor = const Color(0xFFFBC02D);
  static Color searchVendorDividerColor = const Color(0xFFFBC02D);

  static Color searchBannerBorderColor = Colors.red;
  static IconData searchBannerIcon = Icons.circle;
  static Color searchBannerIconColor = Colors.red;
  static Color searchBannerDividerColor = Colors.red;

  static Color searchScanTypeBorderColor = Colors.green;
  static IconData searchScanTypeIcon = Icons.circle;
  static Color searchScanTypeIconColor = Colors.green;
  static Color searchScanTypeDividerColor = Colors.green;

  static Color searchTagBorderColor = Colors.purple;
  static IconData searchTagIcon = Icons.label;
  static Color searchTagIconColor = Colors.purple;
  static Color searchTagDividerColor = Colors.purple;

  // Dialog Colors - Used for dialogs and modals
  static IconData deviceSearchIcon = Icons.search;
  static Color deviceSearchIconColor = const Color(0xFF4FC3F7);

  // Tab Colors - Used for tab content areas
  static Color detailsTabBackground = const Color(0xFF2B2B2B);
  static Color detailsTabBorder = const Color(0xFF4A4A4A);

  // Search Bar Colors - Used for search input fields
  static Color searchBarBorderColor = const Color(0xFF4A4A4A);
  static Color searchBarIconColor = const Color(0xFF4FC3F7);

  // Findings Navbar Colors - Used for findings screen navbar
  static Color findingsNavbarBackground = const Color(0xFF2B2B2B);
  static Color findingsNavbarBorder = const Color(0xFF4A4A4A);
  static IconData findingsTelnetIcon = Icons.terminal;
  static Color findingsTelnetIconColor = const Color(0xFF4FC3F7);
  static IconData findingsJumpIcon = Icons.launch;
  static Color findingsJumpIconColor = const Color(0xFF4FC3F7);
  static IconData findingsFlagIcon = Icons.flag;
  static Color findingsFlagIconColor = const Color(0xFF888888);

  // Action Button Colors - Used for device action buttons
  static Color actionInfoColor = Colors.orange;
  static Color actionJumpColor = Colors.green;
  static Color actionFlagColor = Colors.red;
  static Color actionViewRecordsColor = const Color(0xFF4FC3F7);
  static Color actionTelnetColor = const Color(0xFF4FC3F7);

  // Section Header Colors - Used for section containers
  static Color sectionHeaderColor = const Color(0xFF4FC3F7);
  static Color sectionHeaderSearchsploitColor = Colors.purple;
  static Color sectionHeaderFfufColor = Colors.cyan;
  static Color sectionHeaderSambaColor = Colors.brown;
  static Color sectionHeaderWhatwebColor = Colors.orange;
  static Color sectionHeaderNmapScriptsColor = Colors.blue;
  static Color sectionHeaderFlaggedColor = Colors.red;
  static Color flaggedItemBackground = const Color(0xFF3C3C3C);

  // Arrow Colors - Used for navigation arrows
  static Color arrowColor = const Color(0xFF4FC3F7);

  // Link Colors - Used for clickable links
  static Color linkColor = Colors.blue;

  // Delete Button Colors - Used for delete actions
  static Color deleteButtonColor = Colors.red;

  // Completion Status Colors - Used for FINDINGS redesign
  static Color completeStatusColor = Colors.green;
  static Color incompleteStatusColor = Colors.orange;
  static Color missingCriteriaColor = Colors.red;
  static Color completeBadgeColor = Colors.green;
  static Color incompleteBadgeColor = Colors.orange;
  static Color statusDropdownBackground = const Color(0xFF2B2B2B);
  static Color statusDropdownBorder = const Color(0xFF4A4A4A);

  // Gradient Colors - Used for backgrounds and decorative elements
  static List<Color> primaryGradient = [
    const Color(0xFF4FC3F7),
    const Color(0xFF29B6F6),
  ];
  static List<Color> backgroundGradient = [
    const Color(0xFF1A1A1A),
    const Color(0xFF0D1117),
  ];
  static List<Color> errorGradient = [Colors.red, Colors.black];

  // Terminal Colors - Used in telnet client
  static Color terminalBackground = const Color(0xFF0D1117);
  static Color terminalBorder = const Color(0xFF30363D);
  static Color terminalText = const Color(0xFFE6EDF3);

  // ===== GRADIENT CONFIGURATIONS =====

  // Border Gradients
  static GradientConfig? borderPrimaryGradient;
  static GradientConfig? borderSecondaryGradient;
  static GradientConfig? searchOsBorderGradient;
  static GradientConfig? searchVendorBorderGradient;
  static GradientConfig? searchBannerBorderGradient;
  static GradientConfig? searchScanTypeBorderGradient;
  static GradientConfig? searchTagBorderGradient;
  static GradientConfig? detailsTabBorderGradient;
  static GradientConfig? searchBarBorderGradient;
  static GradientConfig? findingsNavbarBorderGradient;
  static GradientConfig? terminalBorderGradient;

  // Button Background Gradients
  static GradientConfig? scanAddButtonGradient;
  static GradientConfig? scanNmapButtonGradient;
  static GradientConfig? scanNiktoButtonGradient;
  static GradientConfig? scanSearchsploitButtonGradient;
  static GradientConfig? scanWhatwebButtonGradient;
  static GradientConfig? scanEnum4linuxButtonGradient;
  static GradientConfig? scanFfufButtonGradient;
  static GradientConfig? scanSnmpButtonGradient;
  static GradientConfig? scanProcessNmapButtonGradient;
  static GradientConfig? primaryButtonGradient;
  static GradientConfig? secondaryButtonGradient;
  static GradientConfig? actionButtonGradient;

  // ===== ICONS =====

  // App Icons - Material Icons used throughout the app
  static IconData appIcon = Icons.security;
  static IconData projectIcon = Icons.folder;
  static IconData projectIconOutlined = Icons.folder_outlined;
  static IconData addIcon = Icons.add;
  static IconData editIcon = Icons.edit;
  static IconData deleteIcon = Icons.delete;
  static IconData searchIcon = Icons.search;
  static IconData flagIcon = Icons.flag;
  static IconData errorIcon = Icons.error;
  static IconData terminalIcon = Icons.terminal;
  static IconData launchIcon = Icons.launch;
  static IconData closeIcon = Icons.close;
  static IconData linkIcon = Icons.link;
  static IconData saveIcon = Icons.save;
  static IconData computerIcon = Icons.computer;
  static IconData businessIcon = Icons.business;
  static IconData arrowForwardIcon = Icons.arrow_forward_ios;
  static IconData deviceUnknownIcon = Icons.device_unknown;

  // Completion Status Icons - Used for FINDINGS redesign
  static IconData completeStatusIcon = Icons.check_circle;
  static IconData incompleteStatusIcon = Icons.warning;
  static IconData missingCriteriaIcon = Icons.error_outline;
  static IconData statusDropdownIcon = Icons.arrow_drop_down;

  // Scan Icons - Icons for scan buttons
  static IconData scanAddIcon = Icons.search;
  static IconData scanNmapIcon = Icons.auto_fix_high;
  static IconData scanNiktoIcon = Icons.web;
  static IconData scanSearchsploitIcon = Icons.bug_report;
  static IconData scanWhatwebIcon = Icons.language;
  static IconData scanEnum4linuxIcon = Icons.folder_shared;
  static IconData scanFfufIcon = Icons.find_in_page;
  static IconData scanSnmpIcon = Icons.dns;
  static IconData scanProcessNmapIcon = Icons.storage;
  static IconData infoOutlineIcon = Icons.info_outline;
  static IconData fileDownloadIcon = Icons.file_download;
  static IconData keyboardArrowUpIcon = Icons.keyboard_arrow_up;
  static IconData keyboardArrowDownIcon = Icons.keyboard_arrow_down;
  static IconData circleIcon = Icons.circle;
  static IconData arrowDropDownIcon = Icons.arrow_drop_down;
  static IconData devicesIcon = Icons.devices;
  static IconData listIcon = Icons.list;
  static IconData listAltIcon = Icons.list_alt;
  static IconData locationOnIcon = Icons.location_on;
  static IconData settingsIcon = Icons.settings;

  // ===== IMAGES =====

  // Device Icon Images - PNG files in IconLocation folder
  // These are referenced via the icon_list.dart file
  // Path: IconLocation/*.png (relative to executable)
  static String deviceIconsPath = 'IconLocation';

  // ===== FONTS =====

  // Font Families - Used for different text styles
  static String defaultFontFamily = '';
  static String monospaceFontFamily = 'Consolas';

  // Font Sizes
  static double fontSizeSmall = 10.0;
  static double fontSizeBody = 12.0;
  static double fontSizeBodyMedium = 13.0;
  static double fontSizeBodyLarge = 14.0;
  static double fontSizeSubtitle = 16.0;
  static double fontSizeTitle = 18.0;
  static double fontSizeLargeTitle = 20.0;
  static double fontSizeHeading = 28.0;

  // Font Weights
  static FontWeight fontWeightRegular = FontWeight.w400;
  static FontWeight fontWeightMedium = FontWeight.w500;
  static FontWeight fontWeightSemiBold = FontWeight.w600;
  static FontWeight fontWeightBold = FontWeight.w700;

  // ===== SPACING & SIZING =====

  static double borderRadiusSmall = 4.0;
  static double borderRadiusMedium = 6.0;
  static double borderRadiusLarge = 8.0;
  static double borderRadiusXLarge = 12.0;
  static double borderRadiusXXLarge = 16.0;

  static double iconSizeSmall = 16.0;
  static double iconSizeMedium = 18.0;
  static double iconSizeLarge = 20.0;
  static double iconSizeXLarge = 24.0;
  static double iconSizeXXLarge = 32.0;
  static double iconSizeXXXLarge = 48.0;

  // ===== THEME LOADING =====

  static String currentThemeName = 'Default';

  static Future<void> loadTheme([String themeName = 'Default']) async {
    currentThemeName = themeName;

    try {
      final themeData = await ThemeLoader.loadTheme(themeName);
      final colors = themeData['colors'];
      final icons = themeData['icons'];
      final fonts = themeData['fonts'];
      final spacing = themeData['spacing'];
      final images = themeData['images'];

      debugPrint('Loading Theme: $themeName');
      debugPrint('Raw Primary Color: ${colors['primaryColor']}');

      primaryColor = ThemeLoader.parseColor(colors['primaryColor']);
      debugPrint('Parsed Primary Color: $primaryColor');
      secondaryColor = ThemeLoader.parseColor(colors['secondaryColor']);
      scaffoldBackground = ThemeLoader.parseColor(colors['scaffoldBackground']);
      surfaceColor = ThemeLoader.parseColor(colors['surfaceColor']);
      cardBackground = ThemeLoader.parseColor(colors['cardBackground']);
      inputBackground = ThemeLoader.parseColor(colors['inputBackground']);
      darkBackground = ThemeLoader.parseColor(colors['darkBackground']);
      mediumBackground = ThemeLoader.parseColor(colors['mediumBackground']);
      textPrimary = ThemeLoader.parseColor(colors['textPrimary']);
      textSecondary = ThemeLoader.parseColor(colors['textSecondary']);
      textTertiary = ThemeLoader.parseColor(colors['textTertiary']);
      textMuted = ThemeLoader.parseColor(colors['textMuted']);
      iconSecondary = ThemeLoader.parseColor(
        colors['iconSecondary'] ?? colors['textTertiary'],
      );
      textOnPrimary = ThemeLoader.parseColor(colors['textOnPrimary']);
      textOnSecondary = ThemeLoader.parseColor(colors['textOnSecondary']);
      borderPrimary = ThemeLoader.parseColor(colors['borderPrimary']);
      borderSecondary = ThemeLoader.parseColor(colors['borderSecondary']);
      errorColor = ThemeLoader.parseColor(colors['errorColor']);
      warningColor = ThemeLoader.parseColor(colors['warningColor']);
      successColor = ThemeLoader.parseColor(colors['successColor']);
      infoColor = ThemeLoader.parseColor(colors['infoColor']);
      scanAddColor = ThemeLoader.parseColor(colors['scanAddColor']);
      scanNmapColor = ThemeLoader.parseColor(colors['scanNmapColor']);
      scanNiktoColor = ThemeLoader.parseColor(colors['scanNiktoColor']);
      scanSearchsploitColor = ThemeLoader.parseColor(
        colors['scanSearchsploitColor'],
      );
      scanWhatwebColor = ThemeLoader.parseColor(colors['scanWhatwebColor']);
      scanEnum4linuxColor = ThemeLoader.parseColor(
        colors['scanEnum4linuxColor'],
      );
      scanFfufColor = ThemeLoader.parseColor(colors['scanFfufColor']);
      scanSnmpColor = ThemeLoader.parseColor(colors['scanSnmpColor']);
      scanProcessNmapColor = ThemeLoader.parseColor(
        colors['scanProcessNmapColor'],
      );
      scanSambaLdapColor = ThemeLoader.parseColor(colors['scanSambaLdapColor']);
      scanCyanColor = ThemeLoader.parseColor(colors['scanCyanColor']);
      magicButtonColor = ThemeLoader.parseColor(
        colors['magicButtonColor'] ?? colors['primaryColor'],
      );
      searchOsBorderColor = ThemeLoader.parseColor(
        colors['searchOsBorderColor'],
      );
      searchOsIconColor = ThemeLoader.parseColor(colors['searchOsIconColor']);
      searchOsDividerColor = ThemeLoader.parseColor(
        colors['searchOsDividerColor'],
      );
      searchVendorBorderColor = ThemeLoader.parseColor(
        colors['searchVendorBorderColor'],
      );
      searchVendorIconColor = ThemeLoader.parseColor(
        colors['searchVendorIconColor'],
      );
      searchVendorDividerColor = ThemeLoader.parseColor(
        colors['searchVendorDividerColor'],
      );
      searchBannerBorderColor = ThemeLoader.parseColor(
        colors['searchBannerBorderColor'],
      );
      searchBannerIconColor = ThemeLoader.parseColor(
        colors['searchBannerIconColor'],
      );
      searchBannerDividerColor = ThemeLoader.parseColor(
        colors['searchBannerDividerColor'],
      );
      searchScanTypeBorderColor = ThemeLoader.parseColor(
        colors['searchScanTypeBorderColor'],
      );
      searchScanTypeIconColor = ThemeLoader.parseColor(
        colors['searchScanTypeIconColor'],
      );
      searchScanTypeDividerColor = ThemeLoader.parseColor(
        colors['searchScanTypeDividerColor'],
      );
      searchTagBorderColor = ThemeLoader.parseColor(
        colors['searchTagBorderColor'] ?? '#9C27B0',
      );
      searchTagIconColor = ThemeLoader.parseColor(
        colors['searchTagIconColor'] ?? '#9C27B0',
      );
      searchTagDividerColor = ThemeLoader.parseColor(
        colors['searchTagDividerColor'] ?? '#9C27B0',
      );
      deviceSearchIconColor = ThemeLoader.parseColor(
        colors['deviceSearchIconColor'],
      );
      detailsTabBackground = ThemeLoader.parseColor(
        colors['detailsTabBackground'],
      );
      detailsTabBorder = ThemeLoader.parseColor(colors['detailsTabBorder']);
      searchBarBorderColor = ThemeLoader.parseColor(
        colors['searchBarBorderColor'],
      );
      searchBarIconColor = ThemeLoader.parseColor(colors['searchBarIconColor']);
      findingsNavbarBackground = ThemeLoader.parseColor(
        colors['findingsNavbarBackground'],
      );
      findingsNavbarBorder = ThemeLoader.parseColor(
        colors['findingsNavbarBorder'],
      );
      findingsTelnetIconColor = ThemeLoader.parseColor(
        colors['findingsTelnetIconColor'],
      );
      findingsJumpIconColor = ThemeLoader.parseColor(
        colors['findingsJumpIconColor'],
      );
      findingsFlagIconColor = ThemeLoader.parseColor(
        colors['findingsFlagIconColor'],
      );
      actionInfoColor = ThemeLoader.parseColor(
        colors['actionInfoColor'] ?? colors['warningColor'],
      );
      actionJumpColor = ThemeLoader.parseColor(
        colors['actionJumpColor'] ?? colors['successColor'],
      );
      actionFlagColor = ThemeLoader.parseColor(
        colors['actionFlagColor'] ?? colors['errorColor'],
      );
      actionViewRecordsColor = ThemeLoader.parseColor(
        colors['actionViewRecordsColor'] ?? colors['primaryColor'],
      );
      actionTelnetColor = ThemeLoader.parseColor(
        colors['actionTelnetColor'] ?? colors['primaryColor'],
      );
      sectionHeaderColor = ThemeLoader.parseColor(
        colors['sectionHeaderColor'] ?? colors['primaryColor'],
      );
      sectionHeaderSearchsploitColor = ThemeLoader.parseColor(
        colors['sectionHeaderSearchsploitColor'] ?? '0xFF9C27B0',
      );
      sectionHeaderFfufColor = ThemeLoader.parseColor(
        colors['sectionHeaderFfufColor'] ?? '0xFF00BCD4',
      );
      sectionHeaderSambaColor = ThemeLoader.parseColor(
        colors['sectionHeaderSambaColor'] ?? '0xFF795548',
      );
      sectionHeaderWhatwebColor = ThemeLoader.parseColor(
        colors['sectionHeaderWhatwebColor'] ?? '0xFFFF9800',
      );
      sectionHeaderNmapScriptsColor = ThemeLoader.parseColor(
        colors['sectionHeaderNmapScriptsColor'] ?? '0xFF2196F3',
      );
      sectionHeaderFlaggedColor = ThemeLoader.parseColor(
        colors['sectionHeaderFlaggedColor'] ?? '0xFFF44336',
      );
      flaggedItemBackground = ThemeLoader.parseColor(
        colors['flaggedItemBackground'] ?? colors['inputBackground'],
      );
      arrowColor = ThemeLoader.parseColor(
        colors['arrowColor'] ?? colors['primaryColor'],
      );
      linkColor = ThemeLoader.parseColor(
        colors['linkColor'] ?? colors['infoColor'],
      );
      deleteButtonColor = ThemeLoader.parseColor(
        colors['deleteButtonColor'] ?? colors['errorColor'],
      );
      completeStatusColor = ThemeLoader.parseColor(
        colors['completeStatusColor'] ?? '#4CAF50',
      );
      incompleteStatusColor = ThemeLoader.parseColor(
        colors['incompleteStatusColor'] ?? '#FF9800',
      );
      missingCriteriaColor = ThemeLoader.parseColor(
        colors['missingCriteriaColor'] ?? '#F44336',
      );
      completeBadgeColor = ThemeLoader.parseColor(
        colors['completeBadgeColor'] ?? '#4CAF50',
      );
      incompleteBadgeColor = ThemeLoader.parseColor(
        colors['incompleteBadgeColor'] ?? '#FF9800',
      );
      statusDropdownBackground = ThemeLoader.parseColor(
        colors['statusDropdownBackground'] ?? colors['surfaceColor'],
      );
      statusDropdownBorder = ThemeLoader.parseColor(
        colors['statusDropdownBorder'] ?? colors['borderPrimary'],
      );
      final primaryGradientList = colors['primaryGradient'] as List;
      primaryGradient = primaryGradientList.length >= 2
          ? primaryGradientList.map((c) => ThemeLoader.parseColor(c)).toList()
          : [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)];

      final backgroundGradientList = colors['backgroundGradient'] as List;
      backgroundGradient = backgroundGradientList.length >= 2
          ? backgroundGradientList.map((c) => ThemeLoader.parseColor(c)).toList()
          : [const Color(0xFF1A1A1A), const Color(0xFF0D1117)];

      final errorGradientList = colors['errorGradient'] as List;
      errorGradient = errorGradientList.length >= 2
          ? errorGradientList.map((c) => ThemeLoader.parseColor(c)).toList()
          : [Colors.red, Colors.black];
      terminalBackground = ThemeLoader.parseColor(colors['terminalBackground']);
      terminalBorder = ThemeLoader.parseColor(colors['terminalBorder']);
      terminalText = ThemeLoader.parseColor(colors['terminalText']);

      // Load gradient configurations
      final borderGradients =
          themeData['borderGradients'] as Map<String, dynamic>?;
      if (borderGradients != null) {
        borderPrimaryGradient = ThemeLoader.parseGradientConfig(
          borderGradients['borderPrimary'],
        );
        borderSecondaryGradient = ThemeLoader.parseGradientConfig(
          borderGradients['borderSecondary'],
        );
        searchOsBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['searchOsBorder'],
        );
        searchVendorBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['searchVendorBorder'],
        );
        searchBannerBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['searchBannerBorder'],
        );
        searchScanTypeBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['searchScanTypeBorder'],
        );
        searchTagBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['searchTagBorder'],
        );
        detailsTabBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['detailsTabBorder'],
        );
        searchBarBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['searchBarBorder'],
        );
        findingsNavbarBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['findingsNavbarBorder'],
        );
        terminalBorderGradient = ThemeLoader.parseGradientConfig(
          borderGradients['terminalBorder'],
        );
      }

      final buttonGradients =
          themeData['buttonGradients'] as Map<String, dynamic>?;
      if (buttonGradients != null) {
        scanAddButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanAddButton'],
        );
        scanNmapButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanNmapButton'],
        );
        scanNiktoButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanNiktoButton'],
        );
        scanSearchsploitButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanSearchsploitButton'],
        );
        scanWhatwebButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanWhatwebButton'],
        );
        scanEnum4linuxButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanEnum4linuxButton'],
        );
        scanFfufButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanFfufButton'],
        );
        scanSnmpButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanSnmpButton'],
        );
        scanProcessNmapButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['scanProcessNmapButton'],
        );
        primaryButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['primaryButton'],
        );
        secondaryButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['secondaryButton'],
        );
        actionButtonGradient = ThemeLoader.parseGradientConfig(
          buttonGradients['actionButton'],
        );
      }

      appIcon = ThemeLoader.getIconData(icons['appIcon']);
      projectIcon = ThemeLoader.getIconData(icons['projectIcon']);
      projectIconOutlined = ThemeLoader.getIconData(
        icons['projectIconOutlined'],
      );
      addIcon = ThemeLoader.getIconData(icons['addIcon']);
      editIcon = ThemeLoader.getIconData(icons['editIcon']);
      deleteIcon = ThemeLoader.getIconData(icons['deleteIcon']);
      searchIcon = ThemeLoader.getIconData(icons['searchIcon']);
      flagIcon = ThemeLoader.getIconData(icons['flagIcon']);
      errorIcon = ThemeLoader.getIconData(icons['errorIcon']);
      terminalIcon = ThemeLoader.getIconData(icons['terminalIcon']);
      launchIcon = ThemeLoader.getIconData(icons['launchIcon']);
      closeIcon = ThemeLoader.getIconData(icons['closeIcon']);
      linkIcon = ThemeLoader.getIconData(icons['linkIcon']);
      saveIcon = ThemeLoader.getIconData(icons['saveIcon']);
      computerIcon = ThemeLoader.getIconData(icons['computerIcon']);
      businessIcon = ThemeLoader.getIconData(icons['businessIcon']);
      arrowForwardIcon = ThemeLoader.getIconData(icons['arrowForwardIcon']);
      deviceUnknownIcon = ThemeLoader.getIconData(icons['deviceUnknownIcon']);
      scanAddIcon = ThemeLoader.getIconData(icons['scanAddIcon']);
      scanNmapIcon = ThemeLoader.getIconData(icons['scanNmapIcon']);
      scanNiktoIcon = ThemeLoader.getIconData(icons['scanNiktoIcon']);
      scanSearchsploitIcon = ThemeLoader.getIconData(
        icons['scanSearchsploitIcon'],
      );
      scanWhatwebIcon = ThemeLoader.getIconData(icons['scanWhatwebIcon']);
      scanEnum4linuxIcon = ThemeLoader.getIconData(icons['scanEnum4linuxIcon']);
      scanFfufIcon = ThemeLoader.getIconData(icons['scanFfufIcon']);
      scanSnmpIcon = ThemeLoader.getIconData(icons['scanSnmpIcon']);
      scanProcessNmapIcon = ThemeLoader.getIconData(
        icons['scanProcessNmapIcon'],
      );
      infoOutlineIcon = ThemeLoader.getIconData(icons['infoOutlineIcon']);
      fileDownloadIcon = ThemeLoader.getIconData(icons['fileDownloadIcon']);
      keyboardArrowUpIcon = ThemeLoader.getIconData(
        icons['keyboardArrowUpIcon'],
      );
      keyboardArrowDownIcon = ThemeLoader.getIconData(
        icons['keyboardArrowDownIcon'],
      );
      circleIcon = ThemeLoader.getIconData(icons['circleIcon']);
      arrowDropDownIcon = ThemeLoader.getIconData(icons['arrowDropDownIcon']);
      devicesIcon = ThemeLoader.getIconData(icons['devicesIcon']);
      listIcon = ThemeLoader.getIconData(icons['listIcon']);
      listAltIcon = ThemeLoader.getIconData(icons['listAltIcon']);
      locationOnIcon = ThemeLoader.getIconData(icons['locationOnIcon']);
      settingsIcon = ThemeLoader.getIconData(
        icons['settingsIcon'] ?? icons['editIcon'],
      );
      searchOsIcon = ThemeLoader.getIconData(icons['searchOsIcon']);
      searchVendorIcon = ThemeLoader.getIconData(icons['searchVendorIcon']);
      searchBannerIcon = ThemeLoader.getIconData(icons['searchBannerIcon']);
      searchScanTypeIcon = ThemeLoader.getIconData(icons['searchScanTypeIcon']);
      searchTagIcon = ThemeLoader.getIconData(
        icons['searchTagIcon'] ?? 'label',
      );
      deviceSearchIcon = ThemeLoader.getIconData(icons['deviceSearchIcon']);
      findingsTelnetIcon = ThemeLoader.getIconData(icons['findingsTelnetIcon']);
      findingsJumpIcon = ThemeLoader.getIconData(icons['findingsJumpIcon']);
      findingsFlagIcon = ThemeLoader.getIconData(icons['findingsFlagIcon']);
      completeStatusIcon = ThemeLoader.getIconData(
        icons['completeStatusIcon'] ?? 'check_circle',
      );
      incompleteStatusIcon = ThemeLoader.getIconData(
        icons['incompleteStatusIcon'] ?? 'warning',
      );
      missingCriteriaIcon = ThemeLoader.getIconData(
        icons['missingCriteriaIcon'] ?? 'error_outline',
      );
      statusDropdownIcon = ThemeLoader.getIconData(
        icons['statusDropdownIcon'] ?? 'arrow_drop_down',
      );

      deviceIconsPath = images['deviceIconsPath'];

      defaultFontFamily = fonts['defaultFontFamily'];
      monospaceFontFamily = fonts['monospaceFontFamily'];
      fontSizeSmall = fonts['fontSizeSmall'];
      fontSizeBody = fonts['fontSizeBody'];
      fontSizeBodyMedium = fonts['fontSizeBodyMedium'];
      fontSizeBodyLarge = fonts['fontSizeBodyLarge'];
      fontSizeSubtitle = fonts['fontSizeSubtitle'];
      fontSizeTitle = fonts['fontSizeTitle'];
      fontSizeLargeTitle = fonts['fontSizeLargeTitle'];
      fontSizeHeading = fonts['fontSizeHeading'];
      fontWeightRegular = ThemeLoader.parseFontWeight(
        fonts['fontWeightRegular'],
      );
      fontWeightMedium = ThemeLoader.parseFontWeight(fonts['fontWeightMedium']);
      fontWeightSemiBold = ThemeLoader.parseFontWeight(
        fonts['fontWeightSemiBold'],
      );
      fontWeightBold = ThemeLoader.parseFontWeight(fonts['fontWeightBold']);

      borderRadiusSmall = spacing['borderRadiusSmall'];
      borderRadiusMedium = spacing['borderRadiusMedium'];
      borderRadiusLarge = spacing['borderRadiusLarge'];
      borderRadiusXLarge = spacing['borderRadiusXLarge'];
      borderRadiusXXLarge = spacing['borderRadiusXXLarge'];
      iconSizeSmall = spacing['iconSizeSmall'];
      iconSizeMedium = spacing['iconSizeMedium'];
      iconSizeLarge = spacing['iconSizeLarge'];
      iconSizeXLarge = spacing['iconSizeXLarge'];
      iconSizeXXLarge = spacing['iconSizeXXLarge'];
      iconSizeXXXLarge = spacing['iconSizeXXXLarge'];
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  // ===== THEME DATA =====

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: defaultFontFamily.isEmpty ? null : defaultFontFamily,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: textOnPrimary,
        onSecondary: textOnSecondary,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(color: cardBackground, elevation: 2),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: fontSizeLargeTitle,
          fontWeight: fontWeightSemiBold,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: fontSizeSubtitle,
        ),
        alignment: Alignment.center,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
          borderSide: BorderSide(color: borderPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
          borderSide: BorderSide(color: borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
          borderSide: BorderSide(color: primaryColor),
        ),
        hintStyle: TextStyle(color: textTertiary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textTertiary,
        indicatorColor: primaryColor,
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        subtitleTextStyle: TextStyle(color: textSecondary),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceColor),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(textPrimary),
          textStyle: WidgetStateProperty.all(
            TextStyle(color: textPrimary, fontSize: fontSizeBody),
          ),
        ),
      ),
    );
  }
}
