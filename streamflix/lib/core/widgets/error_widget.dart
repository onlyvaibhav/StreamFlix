import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_dimensions.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';

/// Reusable error widget with retry button supporting connection vs server error states
class AppErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  String _getErrorState(Object error) {
    if (error is DioException) {
      final message = error.message?.toLowerCase() ?? '';
      final innerError = error.error?.toString().toLowerCase() ?? '';
      
      // Check for No Internet (DNS failure or explicit network unreachable)
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

  @override
  Widget build(BuildContext context) {
    final state = _getErrorState(error);
    
    IconData icon;
    String title;
    String subtitle;
    
    if (state == 'no_internet') {
      icon = Icons.wifi_off_outlined;
      title = "Plot twist: The internet disappeared.";
      subtitle = "Reconnect and we'll get the show started.";
    } else if (state == 'server_down') {
      icon = Icons.dns_outlined;
      title = "Seems like Server is having Snacks";
      subtitle = "We couldn't reach the backend. Please try again later.";
    } else {
      icon = Icons.error_outline;
      title = "An error occurred";
      subtitle = error.toString();
    }

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
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spaceLarge),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
