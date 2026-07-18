import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/features/splash/splash_initializer.dart';
import 'package:streamflix/features/auth/presentation/providers/auth_provider.dart';
import 'package:streamflix/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:streamflix/core/constants/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    _glowOpacityAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSplash();
  }

  Future<void> _startSplash() async {
    // Wait for the first frame to render before hiding the native splash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // Start intro animation
    final introFuture = _introController.forward();
    
    // Start pulse after intro finishes, if we're still waiting
    introFuture.then((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Run heavy initialization concurrently with the intro animation
    final initFuture = SplashInitializer.initialize();

    // Wait for BOTH the intro animation and the initialization to finish
    await Future.wait([introFuture, initFuture]);

    if (mounted) {
      _pulseController.stop();
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final isAuthenticated = ref.read(authStateProvider);
    final hasSeenOnboarding = ref.read(onboardingStateProvider);

    if (!hasSeenOnboarding) {
      context.go(RouteNames.onboarding);
    } else if (isAuthenticated) {
      context.go(RouteNames.home);
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The glow bloom behind the logo
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _pulseController]),
              builder: (context, child) {
                // Base opacity from intro (fades in), pulsed after
                final baseOpacity = _fadeAnimation.value;
                final pulseOpacity = _introController.isCompleted ? _glowOpacityAnimation.value : 0.4;
                final opacity = baseOpacity * pulseOpacity;

                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.netflixRed.withOpacity(opacity),
                        blurRadius: 120,
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Transparent Splash Artwork (scales up and fades in over the glow)
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                'assets/splash_screen_transparent.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
