import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedProfileIndex = 0;

  final List<Map<String, dynamic>> _profiles = [
    {
      'name': 'Vaibhav',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/0/0b/Netflix-avatar.png',
      'color': Colors.blueAccent,
    },
    {
      'name': 'Kids',
      'avatar': 'https://wallpapers.com/images/hd/netflix-profile-pictures-1000-x-1000-2qo9h82134t9nv0i.jpg',
      'color': Colors.amber,
    },
    {
      'name': 'Guest',
      'avatar': 'https://wallpapers.com/images/hd/netflix-profile-pictures-1000-x-1000-vnl1thqee0xo496c.jpg',
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Who\'s Watching?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Profile selector row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_profiles.length + 1, (index) {
                    if (index == _profiles.length) {
                      // Add Profile button
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.backgroundCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final p = _profiles[index];
                    final isSelected = index == _selectedProfileIndex;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedProfileIndex = index;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to profile: ${p['name']}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 66 : 60,
                              height: isSelected ? 66 : 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.netflixRed : Colors.transparent,
                                  width: 2.5,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(p['avatar']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p['name'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 24),

                // Settings Cards
                _buildSettingsSection(
                  title: 'Device & Connections',
                  children: [
                    _buildSettingsTile(
                      icon: Icons.wifi,
                      title: 'Streaming Connection Mode',
                      subtitle: 'Direct playback (libmpv native)',
                    ),
                    _buildSettingsTile(
                      icon: Icons.high_quality,
                      title: 'Video Quality',
                      subtitle: 'Original source format (upto 4K)',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSettingsSection(
                  title: 'Application Preferences',
                  children: [
                    _buildSettingsTile(
                      icon: Icons.closed_caption,
                      title: 'Subtitles Default Language',
                      subtitle: 'English / SRT Auto-select',
                    ),
                    _buildSettingsTile(
                      icon: Icons.delete_sweep,
                      title: 'Clear Cache',
                      subtitle: 'Free memory of buffered artwork',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache cleared successfully'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // App version text
                Text(
                  'StreamFlix Client v2.1.0 • Profile: ${_profiles[_selectedProfileIndex]['name']}',
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Sign Out / Exit
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Exit session/app
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Session closed. Goodbye!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text('Exit Session', style: AppTextStyles.buttonSmall),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
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
}
