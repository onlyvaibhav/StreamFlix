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
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'cannot_connect';
      }
      if (error.response?.statusCode != null) {
        return 'server_error';
      }
    }
    
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('connectionerror') || 
        errorStr.contains('cannot connect') ||
        errorStr.contains('unable to connect') ||
        errorStr.contains('connection timeout') ||
        errorStr.contains('socketexception')) {
      return 'cannot_connect';
    }
    if (errorStr.contains('server error') || 
        errorStr.contains('unexpected response') ||
        errorStr.contains('format') ||
        errorStr.contains('typeerror') ||
        errorStr.contains('null is not a subtype')) {
      return 'server_error';
    }

    return 'unknown_error';
  }

  @override
  Widget build(BuildContext context) {
    final state = _getErrorState(error);
    
    IconData icon;
    String title;
    String subtitle;
    
    if (state == 'cannot_connect') {
      icon = Icons.wifi_off_outlined;
      title = "Can't connect to StreamFlix";
      subtitle = "Make sure your server is running and you're on the same network.";
    } else if (state == 'server_error') {
      icon = Icons.warning_amber_outlined;
      title = "Something went wrong";
      subtitle = "The server returned an unexpected response.";
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
