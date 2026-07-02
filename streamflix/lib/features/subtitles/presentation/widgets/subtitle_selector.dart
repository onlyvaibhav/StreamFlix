import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';

class SubtitleSelector extends ConsumerStatefulWidget {
  final String movieId;

  const SubtitleSelector({
    super.key,
    required this.movieId,
  });

  @override
  ConsumerState<SubtitleSelector> createState() => _SubtitleSelectorState();
}

class _SubtitleSelectorState extends ConsumerState<SubtitleSelector> {
  DateTime? _voiceHeardTime;
  DateTime? _subtitleAppearedTime;

  void _onVoiceHeard(double currentSubDelay, dynamic notifier) {
    final now = DateTime.now();
    setState(() {
      _voiceHeardTime = now;
    });
    
    if (_subtitleAppearedTime != null) {
      final diff = now.difference(_subtitleAppearedTime!).inMilliseconds / 1000.0;
      notifier.setSubtitleDelay(currentSubDelay + diff);
      setState(() {
        _voiceHeardTime = null;
        _subtitleAppearedTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quick Sync: Subtitles offset adjusted by ${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)}s'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice heard. Tap "Subtitle Appeared" when you see the matching text.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onSubtitleAppeared(double currentSubDelay, dynamic notifier) {
    final now = DateTime.now();
    setState(() {
      _subtitleAppearedTime = now;
    });
    
    if (_voiceHeardTime != null) {
      final diff = _voiceHeardTime!.difference(now).inMilliseconds / 1000.0;
      notifier.setSubtitleDelay(currentSubDelay + diff);
      setState(() {
        _voiceHeardTime = null;
        _subtitleAppearedTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quick Sync: Subtitles offset adjusted by ${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)}s'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle appeared. Tap "Voice Heard" when you hear the matching audio.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 24),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return Consumer(
              builder: (context, ref, _) {
                final playerState = ref.watch(moviePlayerProvider(widget.movieId));
                final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
                
                final audioTracks = playerState.trackInfo?.audioTracks ?? [];
                final embeddedSubs = playerState.trackInfo?.subtitleTracks ?? [];
                final externalSubs = playerState.externalSubtitles;

                final subDelay = playerState.subtitleDelay;
                final fontSize = playerState.subtitleFontSize;

                final signSub = subDelay >= 0 ? '+' : '';

                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AlertDialog(
                    backgroundColor: Colors.black.withValues(alpha: 0.75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                    ),
                    titlePadding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    actionsPadding: const EdgeInsets.only(bottom: 8, right: 16),
                    title: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.netflixRed),
                        const SizedBox(width: 10),
                        const Text('Audio & Subtitles', style: AppTextStyles.heading3),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    content: SizedBox(
                      width: 600,
                      height: 340,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column 1: Audio Selection & Audio Delay Sync & Quick Sync
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Audio Track',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ...List.generate(audioTracks.length, (idx) {
                                          final track = audioTracks[idx];
                                          final isSelected = playerState.currentAudioTrack == idx;
                                          final trackLabel = _formatAudioTrackLabel(track, idx);
                                          
                                          return _buildSelectorItem(
                                            label: trackLabel,
                                            isSelected: isSelected,
                                            onTap: () => notifier.switchAudioTrack(idx),
                                          );
                                        }),
                                        if (audioTracks.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            child: Text('No extra audio tracks available', style: TextStyle(color: Colors.white38, fontSize: 13)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 8),
                                
                                // Quick Sync Widget moved under Audio!
                                const Row(
                                  children: [
                                    Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Quick Sync',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap a button when the first event happens:',
                                  style: TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSyncActionBtn(
                                        icon: Icons.subtitles_outlined,
                                        label: 'Subtitle\nAppeared',
                                        isActive: _subtitleAppearedTime != null,
                                        onTap: () => _onSubtitleAppeared(subDelay, notifier),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSyncActionBtn(
                                        icon: Icons.volume_up_outlined,
                                        label: 'Voice\nHeard',
                                        isActive: _voiceHeardTime != null,
                                        onTap: () => _onVoiceHeard(subDelay, notifier),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 8),

                                // Subtitle font size adjustment
                                Text(
                                  'Subtitle Font Size: ${fontSize.round()}px',
                                  style: TextStyle(
                                    color: fontSize == 44.0 ? Colors.white70 : AppColors.netflixRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildAdjustPill(
                                      label: '-4px',
                                      onTap: () => notifier.setSubtitleFontSize(fontSize - 4),
                                    ),
                                    _buildAdjustPill(
                                      label: '-2px',
                                      onTap: () => notifier.setSubtitleFontSize(fontSize - 2),
                                    ),
                                    _buildResetPill(
                                      isEnabled: fontSize != 44.0,
                                      onTap: () => notifier.setSubtitleFontSize(44.0),
                                    ),
                                    _buildAdjustPill(
                                      label: '+2px',
                                      onTap: () => notifier.setSubtitleFontSize(fontSize + 2),
                                    ),
                                    _buildAdjustPill(
                                      label: '+4px',
                                      onTap: () => notifier.setSubtitleFontSize(fontSize + 4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 32),
                          
                          // Column 2: Subtitle List & Manual Sync
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Subtitles',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 8),
                                
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Subtitles Options
                                        _buildSelectorItem(
                                          label: 'Off',
                                          isSelected: playerState.currentSubtitleTrack == -1,
                                          onTap: () => notifier.switchSubtitleTrack(-1),
                                        ),
                                        
                                        if (embeddedSubs.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          const Text(
                                            'EMBEDDED',
                                            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                                          ),
                                          const SizedBox(height: 4),
                                          ...List.generate(embeddedSubs.length, (idx) {
                                            final track = embeddedSubs[idx];
                                            final isSelected = playerState.currentSubtitleTrack == idx;
                                            final trackLabel = _formatEmbeddedSubLabel(track, idx);
                                            
                                            return _buildSelectorItem(
                                              label: trackLabel,
                                              isSelected: isSelected,
                                              onTap: () => notifier.switchSubtitleTrack(idx, isExternal: false),
                                            );
                                          }),
                                        ],
                                        
                                        if (externalSubs.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          const Text(
                                            'EXTERNAL (DOWNLOADED)',
                                            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                                          ),
                                          const SizedBox(height: 4),
                                          ...List.generate(externalSubs.length, (idx) {
                                            final sub = externalSubs[idx];
                                            final virtualIndex = idx + 100;
                                            final isSelected = playerState.currentSubtitleTrack == virtualIndex;
                                            final trackLabel = _formatExternalSubLabel(sub);
                                            
                                            return _buildSelectorItem(
                                              label: trackLabel,
                                              isSelected: isSelected,
                                              onTap: () => notifier.switchSubtitleTrack(idx, isExternal: true),
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 8),

                                // Manual Adjust Widget (Subtitle offset)
                                Row(
                                  children: [
                                    const Text(
                                      'Subtitle Delay Offset',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$signSub${subDelay.toStringAsFixed(1)}s',
                                      style: TextStyle(
                                        color: subDelay == 0.0 ? Colors.white70 : Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildAdjustPill(
                                      label: '-0.5s',
                                      onTap: () => notifier.setSubtitleDelay(subDelay - 0.5),
                                    ),
                                    _buildAdjustPill(
                                      label: '-0.1s',
                                      onTap: () => notifier.setSubtitleDelay(subDelay - 0.1),
                                    ),
                                    _buildResetPill(
                                      isEnabled: subDelay != 0.0,
                                      onTap: () => notifier.setSubtitleDelay(0.0),
                                    ),
                                    _buildAdjustPill(
                                      label: '+0.1s',
                                      onTap: () => notifier.setSubtitleDelay(subDelay + 0.1),
                                    ),
                                    _buildAdjustPill(
                                      label: '+0.5s',
                                      onTap: () => notifier.setSubtitleDelay(subDelay + 0.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSyncActionBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? AppColors.netflixRed.withValues(alpha: 0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.netflixRed : Colors.white12,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? AppColors.netflixRed : Colors.white70, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustPill({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildResetPill({required bool isEnabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: 44,
        height: 28,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isEnabled ? Colors.white24 : Colors.white10),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.refresh_rounded,
          color: isEnabled ? Colors.white : Colors.white24,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildSelectorItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.netflixRed,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  String _formatAudioTrackLabel(dynamic track, int idx) {
    final parts = <String>[];
    parts.add(track.language != null && track.language.isNotEmpty ? track.language : 'Audio ${idx + 1}');
    
    if (track.codec != null && track.codec.isNotEmpty && track.codec != 'unknown') {
      parts.add(track.codec.toUpperCase());
    }
    
    if (track.channelLayout != null && track.channelLayout.isNotEmpty) {
      parts.add(track.channelLayout);
    } else if (track.channels > 0) {
      if (track.channels == 6) {
        parts.add('5.1');
      } else if (track.channels == 8) {
        parts.add('7.1');
      } else if (track.channels == 2) {
        parts.add('Stereo');
      } else {
        parts.add('${track.channels} ch');
      }
    }
    
    var label = parts.join(' • ');
    final tags = <String>[];
    if (track.isDefault == true) {
      tags.add('Default');
    }
    if (track.title != null && track.title.toLowerCase().contains('commentary')) {
      tags.add('Commentary');
    }
    
    if (tags.isNotEmpty) {
      label += ' (${tags.join(', ')})';
    }
    
    return label;
  }

  String _formatEmbeddedSubLabel(dynamic track, int idx) {
    final parts = <String>[];
    parts.add(track.language != null && track.language.isNotEmpty ? track.language : 'Sub ${idx + 1}');
    
    if (track.codec != null && track.codec.isNotEmpty && track.codec != 'unknown') {
      parts.add(track.codec.toUpperCase());
    }
    
    var label = parts.join(' • ');
    final tags = <String>[];
    if (track.isDefault == true) tags.add('Default');
    if (track.isForced == true) tags.add('Forced');
    
    if (tags.isNotEmpty) {
      label += ' (${tags.join(', ')})';
    }
    
    return label;
  }

  String _formatExternalSubLabel(dynamic sub) {
    final label = sub.label ?? sub.language ?? 'External Subtitle';
    final details = <String>[];
    details.add(sub.source);
    
    if (sub.rating != null && sub.rating.isNotEmpty) {
      details.add(sub.rating);
    }
    
    return '$label • ${details.join(' • ')}';
  }
}