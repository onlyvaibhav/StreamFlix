import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_dimensions.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/network/connectivity_service.dart';

/// Reusable error widget with retry button supporting connection vs server error states
class AppErrorWidget extends ConsumerStatefulWidget {
  final Object error;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  ConsumerState<AppErrorWidget> createState() => _AppErrorWidgetState();
}

class _AppErrorWidgetState extends ConsumerState<AppErrorWidget> {
  bool _isRetrying = false;

  void _handleRetry() async {
    if (widget.onRetry == null || _isRetrying) return;
    setState(() => _isRetrying = true);
    widget.onRetry!();
    // Simulate a minimum delay to show the spinner
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRetrying = false);
  }

  String _getErrorState(Object error, bool isOffline) {
    if (isOffline) {
      return 'no_internet';
    }

    if (error is DioException) {
      final message = error.message?.toLowerCase() ?? '';
      final innerError = error.error?.toString().toLowerCase() ?? '';
      
      // Additional fallback checks just in case connectivity_plus misses it
      if (innerError.contains('failed host lookup') || 
          innerError.contains('network is unreachable') ||
          innerError.contains('no route to host') ||
          innerError.contains('connection aborted') ||
          message.contains('failed host lookup') ||
          message.contains('network is unreachable') ||
          message.contains('no route to host')) {
        return 'no_internet';
      }
      
      // Backend down / timeouts
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          innerError.contains('connection refused') ||
          (error.response != null && error.response!.statusCode != null && error.response!.statusCode! >= 500)) {
        return 'server_down';
      }
    }
    
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('failed to open http') || 
        errorStr.contains('stream') || 
        errorStr.contains('failed to load video')) {
      return 'stream_failed';
    }

    if (errorStr.contains('failed host lookup') || 
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no route to host')) {
      return 'no_internet';
    }
    if (errorStr.contains('connection refused') || 
        errorStr.contains('connection timeout') ||
        errorStr.contains('cannot connect') ||
        errorStr.contains('server error')) {
      return 'server_down';
    }

    return 'unknown_error';
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildOfflineError(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRetry?.call();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 24),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                children: [
                  TextSpan(text: "You're "),
                  TextSpan(text: "offline!", style: GoogleFonts.inter(color: AppColors.error)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Your Internet needs therapy.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              "It ghosted us again. Don't worry,\neven the best connections have their bad days.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 32),
            if (widget.onRetry != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _handleRetry,
                  icon: _isRetrying 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh),
                  label: Text(_isRetrying ? "Retrying..." : "Try Again", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go(RouteNames.downloads),
                icon: const Icon(Icons.download_rounded),
                label: Text("Go to Downloads", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white24, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("While we fix things...", style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildTipRow(Icons.air, "Take a deep breath. Seriously."),
                  _buildTipRow(Icons.directions_walk, "Stand up. Stretch. You're not a Wi-Fi router."),
                  _buildTipRow(Icons.favorite, "Talk to a human. They miss you."),
                  _buildTipRow(Icons.wifi_tethering_off, "If none of that works... blame your Internet. 😒"),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text("Good shows. Bad network. Happens to legends.", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text("We'll be back online soon. Pinky promise. 🤞", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildServerError(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRetry?.call();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 24),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                children: [
                  TextSpan(text: "Seems like server is\non "),
                  TextSpan(text: "snack break", style: GoogleFonts.inter(color: AppColors.error)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "We tried to talk to our backend, but it's busy enjoying\nsome snacks. Please try again in a few moments.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            if (widget.onRetry != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _handleRetry,
                  icon: _isRetrying 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh),
                  label: Text(_isRetrying ? "Retrying..." : "Try Again", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go(RouteNames.home),
                icon: const Icon(Icons.home_outlined),
                label: Text("Go to Home", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white24, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.fastfood_outlined, color: AppColors.error, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("What can you do?", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(
                          "You can check your internet connection or try again later. We'll be back from snack break soon! 😋",
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text("STREAMFLIX", style: GoogleFonts.inter(color: AppColors.error, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Sit tight, great content takes time. 🍿", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStreamError(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRetry?.call();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_rounded, size: 64, color: AppColors.error),
              const SizedBox(height: 24),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  children: [
                    TextSpan(text: "Stream is\n"),
                    TextSpan(text: "Unavailable", style: GoogleFonts.inter(color: AppColors.error)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We couldn't open the video stream.\nThe source file might be deleted or Telegram is disconnected.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              if (widget.onRetry != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _handleRetry,
                    icon: _isRetrying 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh),
                    label: Text(_isRetrying ? "Retrying..." : "Try Again", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text("Go Back", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white24, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    final state = _getErrorState(widget.error, isOffline);
    
    if (state == 'no_internet') {
      return _buildOfflineError(context);
    } else if (state == 'server_down') {
      return _buildServerError(context);
    } else if (state == 'stream_failed') {
      return _buildStreamError(context);
    }
    
    IconData icon = Icons.error_outline;
    String title = "An error occurred";
    String subtitle = widget.error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconXLarge * 1.5,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.spaceMedium),
            Text(
              title,
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceSmall),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: AppDimensions.spaceLarge),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _handleRetry,
                icon: _isRetrying 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
                label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.netflixRed,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceLarge,
                    vertical: AppDimensions.spaceMedium,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
