import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/main.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  double fontSize = 16.0;
  
  final Map<String, String> themeColors = {
    'zinc': 'Zinc',
    'slate': 'Slate',
    'red': 'Red',
    'rose': 'Rose',
    'orange': 'Orange',
    'green': 'Green',
    'blue': 'Blue',
    'yellow': 'Yellow',
    'violet': 'Violet',
  };

  final Map<String, Color> themeColorPreview = {
    'zinc': const Color(0xFF71717A),
    'slate': const Color(0xFF64748B),
    'red': const Color(0xFFEF4444),
    'rose': const Color(0xFFF43F5E),
    'orange': const Color(0xFFF97316),
    'green': const Color(0xFF22C55E),
    'blue': const Color(0xFF3B82F6),
    'yellow': const Color(0xFFEAB308),
    'violet': const Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance Settings
              _buildAppearanceSection(),
              const SizedBox(height: 24),

              // About & Help
              _buildAboutSection(),
              const SizedBox(height: 24),

              // Danger Zone
              _buildDangerSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final themeManager = ThemeManager.of(context);
    final isDarkMode = themeManager?.isDarkMode ?? true;
    final selectedThemeColor = themeManager?.selectedThemeColor ?? 'zinc';
    
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Dark Mode Toggle
            _buildSettingTile(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
              trailing: FSwitch(
                value: isDarkMode,
                onChange: (value) {
                  themeManager?.onThemeChanged(isDarkMode: value);
                },
              ),
            ),
            
            // Theme Selection
            _buildSettingTile(
              icon: Icons.palette,
              title: 'Theme Color',
              subtitle: themeColors[selectedThemeColor] ?? 'Zinc',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: themeColorPreview[selectedThemeColor],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: () => _showThemeSelector(),
            ),
            
            // Font Size
            _buildSettingTile(
              icon: Icons.text_fields,
              title: 'Font Size',
              subtitle: 'Adjust text size: ${fontSize.round()}px',
              trailing: SizedBox(
                width: 120,
                child: Material(
                  color: Colors.transparent,
                  child: Slider(
                    value: fontSize,
                    min: 12,
                    max: 20,
                    divisions: 8,
                    onChanged: (value) {
                      setState(() {
                        fontSize = value;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSettingTile(
              icon: Icons.info,
              title: 'App Version',
              subtitle: '1.0.0 (Build 100)',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showVersionInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerSection() {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSettingTile(
              icon: Icons.delete_forever,
              title: 'Clear All Data',
              subtitle: 'Remove all stored data (irreversible)',
              titleColor: Colors.red,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
              onTap: () => _showClearDataDialog(),
            ),
            
            _buildSettingTile(
              icon: Icons.restore,
              title: 'Reset to Defaults',
              subtitle: 'Reset all settings to default values',
              titleColor: Colors.orange,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
              onTap: () => _showResetDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  // Dialog methods
  void _showThemeSelector() {
    final themeManager = ThemeManager.of(context);
    final selectedThemeColor = themeManager?.selectedThemeColor ?? 'zinc';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme Color'),
        content: Material(
          child: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: themeColors.entries.map((entry) {
                final isSelected = entry.key == selectedThemeColor;
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: themeColorPreview[entry.key],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    themeManager?.onThemeChanged(themeColor: entry.key);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Theme changed to ${entry.value}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('StoreHSK'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            Text('Build: 100'),
            Text('Flutter Version: 3.0.0'),
            SizedBox(height: 16),
            Text('© 2026 StoreHSK. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your data including inventory, '
          'analytics, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // Implement data clearing logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared successfully')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('This will reset all settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              _resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    final themeManager = ThemeManager.of(context);
    setState(() {
      fontSize = 16.0;
    });
    themeManager?.onThemeChanged(isDarkMode: true, themeColor: 'zinc');
  }
}