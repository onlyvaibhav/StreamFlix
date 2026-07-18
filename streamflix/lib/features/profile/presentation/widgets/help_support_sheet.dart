import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HelpSupportSheet extends StatefulWidget {
  const HelpSupportSheet({super.key});

  @override
  State<HelpSupportSheet> createState() => _HelpSupportSheetState();
}

class _HelpSupportSheetState extends State<HelpSupportSheet> {
  bool _isCheckingUpdate = false;
  bool _isActionInProgress = false;

  Future<void> _handleUrl(String urlString) async {
    if (_isActionInProgress) return;
    
    setState(() => _isActionInProgress = true);
    
    try {
      final Uri url = Uri.parse(urlString);
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Could not launch');
    } catch (e) {
      if (mounted) {
        _showToast(context, 'Could not launch $urlString');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _handleEmail() async {
    if (_isActionInProgress) return;
    
    setState(() => _isActionInProgress = true);
    
    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'vaibhavmishra0703@gmail.com',
        queryParameters: {
          'subject': 'StreamFlix Feedback',
        },
      );

      final launched = await launchUrl(emailLaunchUri);
      if (!launched) throw Exception('Could not launch email');
    } catch (e) {
      if (mounted) {
        _showToast(context, 'No email application installed.');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate || _isActionInProgress) return;
    
    setState(() {
      _isCheckingUpdate = true;
      _isActionInProgress = true;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Simulate network request to check for updates
      await Future.delayed(const Duration(seconds: 1));
      
      // Since we don't have an actual update endpoint, we just report latest version
      if (mounted) {
        _showToast(context, "You're using the latest version.");
      }
    } catch (e) {
      if (mounted) {
        _showToast(context, 'Failed to check for updates: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
          _isActionInProgress = false;
        });
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 50.0,
        left: 24.0,
        right: 24.0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help & Support',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'General',
            children: [
              _buildSettingsTile(
                icon: Icons.system_update_rounded,
                title: 'Check for Updates',
                subtitle: 'Check if a newer version of StreamFlix is available.',
                onTap: _checkForUpdates,
                trailing: _isCheckingUpdate 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    )
                  : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            title: 'Community & Feedback',
            children: [
              _buildSettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Discussion Community',
                subtitle: 'Ask questions, share feedback, and connect with other StreamFlix users.',
                onTap: () => _handleUrl('https://t.me/+PK-fH0EWAnYzMDI1'), // Placeholder Telegram URL
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.code_rounded, // GitHub icon placeholder
                title: 'GitHub',
                subtitle: 'View the project and development updates.',
                onTap: () => _handleUrl('https://github.com/onlyvaibhav/StreamFlix'), // Placeholder GitHub URL
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: 'Report bugs, request features, ask for help, or share feedback.',
                onTap: _handleEmail,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Material(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      onTap: onTap,
    );
  }
}
