import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:streamflix/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/widgets/netflix_avatar.dart';
import 'package:streamflix/features/profile/presentation/widgets/help_support_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final user = Hive.box('authBox').get('user') as Map?;
    
    // Fallback info if not logged in or missing data
    final String firstName = user?['firstName'] ?? 'Guest';

    return Scaffold(
      backgroundColor: Colors.black, // Netflix style
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.arrow_back, color: Colors.white),
        title: const Text(
          'Profiles & More',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatars Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Profile
                  _buildProfileAvatarColumn(
                    name: firstName,
                    useNetflixFace: true,
                    isActive: true,
                  ),
                  const SizedBox(width: 20),
                  // Kids Profile
                  _buildProfileAvatarColumn(
                    name: 'Kids',
                    useNetflixFace: true,
                  ),
                  const SizedBox(width: 20),
                  // Add Profile
                  _buildProfileAvatarColumn(
                    name: 'Add profile',
                    overrideColor: Colors.white.withValues(alpha: 0.1),
                    icon: Icons.add,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Manage Profiles
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit, color: Colors.white70, size: 16),
                label: const Text(
                  'Manage Profiles',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Big Buttons
              _buildBigTile(
                icon: Icons.playlist_add_check_rounded,
                title: 'My List',
                onTap: () {},
              ),
              const SizedBox(height: 8),
              _buildBigTile(
                icon: Icons.person_outline_rounded,
                title: 'Account',
                onTap: () => _showAccountSheet(context),
              ),
              const SizedBox(height: 8),
              _buildBigTile(
                icon: Icons.help_outline_rounded,
                title: 'Help',
                onTap: () => _showHelpSupportSheet(context),
              ),
              
              const SizedBox(height: 32),
              
              // Sign Out
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.backgroundLight,
                      title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            ref.read(authStateProvider.notifier).logout();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logged out successfully.'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Text('Sign Out', style: TextStyle(color: AppColors.netflixRed)),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatarColumn({
    required String name,
    bool isActive = false,
    bool useNetflixFace = false,
    IconData? icon,
    Widget? child,
    Color? overrideColor,
  }) {
    return Column(
      children: [
        NetflixAvatar(
          name: name,
          size: 72,
          isActive: isActive,
          useNetflixFace: useNetflixFace,
          icon: icon,
          child: child,
          overrideColor: overrideColor,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildBigTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return const SafeArea(child: HelpSupportSheet());
      },
    );
  }

  void _showAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsSection(
                title: 'Telegram Integration',
                children: [
                  ValueListenableBuilder<Box>(
                    valueListenable: Hive.box('authBox').listenable(keys: ['telegram_session']),
                    builder: (context, box, widget) {
                      final session = box.get('telegram_session') as String?;
                      final isLinked = session != null && session.isNotEmpty;
                      return _buildSettingsTile(
                        icon: Icons.telegram,
                        title: isLinked ? 'Telegram Linked' : 'Link Telegram Account',
                        subtitle: isLinked ? 'Ready for client-side streaming' : 'Authenticate to enable client-side streaming',
                        onTap: () {
                          if (!isLinked) {
                            Navigator.pop(context);
                            _showTelegramLoginDialog(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Telegram is already linked')),
                            );
                          }
                        },
                      );
                    }
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      onTap: onTap,
    );
  }

  void _showTelegramLoginDialog(BuildContext context) {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    bool codeSent = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.backgroundLight,
              title: const Text('Telegram Login', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!codeSent) ...[
                    const Text('Enter your phone number including country code (e.g. +1234567890)', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.netflixRed)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ] else ...[
                    const Text('Enter the code sent to your Telegram app', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'OTP Code',
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.netflixRed)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    if (!codeSent) {
                      final phone = phoneController.text.trim();
                      if (phone.isNotEmpty) {
                        await TelegramClientService().sendCode(phone);
                        // Wait for stream to emit 'phoneCodeSent'
                        TelegramClientService().authStateStream.firstWhere((e) => e == 'phoneCodeSent').then((_) {
                          setDialogState(() {
                            codeSent = true;
                          });
                        });
                      }
                    } else {
                      final otp = otpController.text.trim();
                      if (otp.isNotEmpty) {
                        await TelegramClientService().signIn(phoneController.text.trim(), otp);
                        TelegramClientService().authStateStream.firstWhere((e) => e == 'signedIn').then((_) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Telegram Login Successful!')),
                          );
                        });
                      }
                    }
                  },
                  child: Text(!codeSent ? 'Send Code' : 'Verify', style: const TextStyle(color: AppColors.netflixRed)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


