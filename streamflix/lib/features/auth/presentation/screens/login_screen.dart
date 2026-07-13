import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:streamflix/core/network/dio_client.dart';
import 'package:streamflix/features/auth/presentation/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _isLoading = false;
  String? _statusMessage;
  StreamSubscription<String>? _authSub;

  Timer? _resendTimer;
  int _resendCountdown = 30;
  
  String? _finalSessionString;

  @override
  void initState() {
    super.initState();
    _authSub = TelegramClientService().authStateStream.listen((event) {
      if (event.startsWith('error:') && mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = event.substring(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusMessage ?? 'Unknown error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (event == 'ready' && mounted) {
        setState(() {
          _statusMessage = 'Telegram connected. Ready to login.';
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _otpFocusNode.dispose();
    _passwordFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  void _goToPage(int page) {
    if (mounted) {
      setState(() => _currentPage = page);
      _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  String _formatTelegramError(String errorMsg) {
    if (errorMsg.contains('PHONE_CODE_INVALID')) {
      return 'The verification code is incorrect. Please check the code and try again.';
    } else if (errorMsg.contains('PHONE_CODE_EXPIRED')) {
      return 'The verification code has expired. Please request a new one.';
    } else if (errorMsg.contains('PHONE_NUMBER_INVALID')) {
      return 'The phone number you entered is invalid. Please check the country code and digits.';
    } else if (errorMsg.contains('FLOOD_WAIT_')) {
      return 'Too many attempts. Please wait a while before trying again.';
    } else if (errorMsg.contains('PASSWORD_HASH_INVALID') || errorMsg.contains('SRP_PASSWORD_INVALID')) {
      return 'The 2-Step Verification password you entered is incorrect.';
    }
    return errorMsg.replaceAll('Exception: ', '');
  }

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    
    // Add prefix if missing
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';

    setState(() { 
      _isLoading = true; 
      _statusMessage = 'Waiting for Telegram client...';
    });

    try {
      await TelegramClientService().sendCode(fullPhone);
      
      setState(() { _statusMessage = 'Code request sent. Waiting for confirmation...'; });

      final result = await TelegramClientService().authStateStream
          .firstWhere((e) => e == 'phoneCodeSent' || e.startsWith('error:'))
          .timeout(const Duration(seconds: 30), onTimeout: () => 'error:Timeout waiting for code');
      
      if (result == 'phoneCodeSent') {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Code sent! Check your Telegram app.';
          });
          _startResendTimer();
          _goToPage(2);
          _otpFocusNode.requestFocus();
        }
      } else {
        throw Exception(result.substring(6));
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatTelegramError(e.toString())), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleSignIn() async {
    final otp = _otpController.text.trim();
    if (otp.length < 5) return;

    setState(() { 
      _isLoading = true;
      _statusMessage = 'Verifying code...';
    });
    
    final phone = _phoneController.text.trim();
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';

    try {
      await TelegramClientService().signIn(fullPhone, otp);
      
      final result = await TelegramClientService().authStateStream
          .firstWhere((e) => e == 'signedIn' || e == 'passwordNeeded' || e.startsWith('error:'))
          .timeout(const Duration(seconds: 30), onTimeout: () => 'error:Timeout during sign-in');
      
      if (result == 'passwordNeeded') {
        if (mounted) {
          setState(() => _isLoading = false);
          _goToPage(3); // Go to password page
        }
        return;
      }

      if (result != 'signedIn') {
        throw Exception(result.substring(6));
      }

      final session = TelegramClientService().sessionString;
      if (session != null) {
        if (mounted) {
          setState(() { _statusMessage = 'Syncing session...'; });
        }
        
        try {
          final box = Hive.box('authBox');
          String? deviceId = box.get('device_id');
          if (deviceId == null) {
            deviceId = 'fl_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
            box.put('device_id', deviceId);
          }
          
          final userObj = TelegramClientService().userObj;
          if (userObj == null) {
             final rawMsg = TelegramClientService().lastRawMsg;
             throw Exception('User object from GramJS worker is null. Raw msg from JS: $rawMsg');
          }

          String deviceDetail = 'Unknown Device';
          if (!kIsWeb) {
            final deviceInfo = DeviceInfoPlugin();
            if (defaultTargetPlatform == TargetPlatform.android) {
              final androidInfo = await deviceInfo.androidInfo;
              deviceDetail = '${androidInfo.brand} ${androidInfo.model}';
            } else if (defaultTargetPlatform == TargetPlatform.iOS) {
              final iosInfo = await deviceInfo.iosInfo;
              deviceDetail = iosInfo.utsname.machine;
            }
          }

          final dio = ref.read(dioProvider);
          final response = await dio.post(
            '/api/auth/telegram/sync-client-session',
            data: {
              'sessionString': session,
              'user': userObj,
              'device': {
                'deviceId': deviceId,
                'browser': kIsWeb ? 'Flutter Web' : 'Flutter Native',
                'os': kIsWeb ? 'Web' : defaultTargetPlatform.name,
                'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name,
                'userAgent': 'StreamFlix Flutter App ($deviceDetail)',
              }
            },
          );
          
          if (response.statusCode == 200 && response.data['success'] == true) {
            final sessionToken = response.data['sessionToken'];
            if (sessionToken != null) box.put('sessionToken', sessionToken);
            if (response.data['user'] != null) box.put('user', response.data['user']);
            
            _finalSessionString = session;
            if (mounted) {
              setState(() => _isLoading = false);
              _goToPage(4); // Go to success page
            }
          } else {
            throw Exception(response.data['error'] ?? 'Unknown backend error');
          }
        } on DioException catch (e) {
          final errorMessage = e.response?.data?['error'] ?? e.message;
          throw Exception('Backend sync failed: $errorMessage');
        } catch (e) {
          throw Exception('Failed to sync session: $e');
        }
      } else {
        throw Exception('Session was null after sign-in');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatTelegramError(e.toString())), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handlePasswordSubmit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() { 
      _isLoading = true;
      _statusMessage = 'Checking password...';
    });

    try {
      await TelegramClientService().checkPassword(password);
      
      final result = await TelegramClientService().authStateStream
          .firstWhere((e) => e == 'signedIn' || e.startsWith('error:'))
          .timeout(const Duration(seconds: 30), onTimeout: () => 'error:Timeout checking password');
      
      if (result != 'signedIn') {
        throw Exception(result.substring(6));
      }

      final session = TelegramClientService().sessionString;
      if (session != null) {
        if (mounted) {
          setState(() { _statusMessage = 'Syncing session...'; });
        }
        
        try {
          final box = Hive.box('authBox');
          String? deviceId = box.get('device_id');
          if (deviceId == null) {
            deviceId = 'fl_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
            box.put('device_id', deviceId);
          }
          
          final userObj = TelegramClientService().userObj;
          if (userObj == null) {
             final rawMsg = TelegramClientService().lastRawMsg;
             throw Exception('User object from GramJS worker is null. Raw msg from JS: $rawMsg');
          }

          String deviceDetail = 'Unknown Device';
          if (!kIsWeb) {
            final deviceInfo = DeviceInfoPlugin();
            if (defaultTargetPlatform == TargetPlatform.android) {
              final androidInfo = await deviceInfo.androidInfo;
              deviceDetail = '${androidInfo.brand} ${androidInfo.model}';
            } else if (defaultTargetPlatform == TargetPlatform.iOS) {
              final iosInfo = await deviceInfo.iosInfo;
              deviceDetail = iosInfo.utsname.machine;
            }
          }

          final dio = ref.read(dioProvider);
          final response = await dio.post(
            '/api/auth/telegram/sync-client-session',
            data: {
              'sessionString': session,
              'user': userObj,
              'device': {
                'deviceId': deviceId,
                'browser': kIsWeb ? 'Flutter Web' : 'Flutter Native',
                'os': kIsWeb ? 'Web' : defaultTargetPlatform.name,
                'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name,
                'userAgent': 'StreamFlix Flutter App ($deviceDetail)',
              }
            },
          );
          
          if (response.statusCode == 200 && response.data['success'] == true) {
            final sessionToken = response.data['sessionToken'];
            if (sessionToken != null) box.put('sessionToken', sessionToken);
            if (response.data['user'] != null) box.put('user', response.data['user']);
            
            _finalSessionString = session;
            if (mounted) {
              setState(() => _isLoading = false);
              _goToPage(4); // Go to success page
            }
          } else {
            throw Exception(response.data['error'] ?? 'Unknown backend error');
          }
        } catch (e) {
          throw Exception('Failed to sync session: $e');
        }
      } else {
        throw Exception('Session was null after sign-in');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildTopLogo() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          'STREAMFLIX',
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
            color: AppColors.netflixRed,
            fontSize: 56,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStepper(int stepCount, int activeStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(stepCount, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index <= activeStep ? AppColors.netflixRed : Colors.white24,
          ),
        );
      }),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.netflixRed, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIntroPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text('Welcome to StreamFlix', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Login or sign up using your Telegram account\nto continue watching your favorite content.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
          const SizedBox(height: 50),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 48, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    const Text('Login with Telegram', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    _buildFeatureItem(Icons.security_outlined, 'Secure & Private', 'We never share your number with anyone.'),
                    _buildFeatureItem(Icons.flash_on_rounded, 'Fast & Easy', 'Login in just a few taps using Telegram.'),
                    _buildFeatureItem(Icons.devices_outlined, 'Seamless Experience', 'Access your watchlist and resume across devices.'),
                  ],
                ),
              ),
              Positioned(
                top: -28,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.telegram, color: AppColors.netflixRed, size: 28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _goToPage(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.telegram, size: 24),
                  SizedBox(width: 8),
                  Text('Continue with Telegram', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 14),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  text: 'By continuing, you agree to our ',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  children: [
                    TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.netflixRed)),
                    TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy.', style: TextStyle(color: AppColors.netflixRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhonePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => _goToPage(0),
            ),
          ),
          const SizedBox(height: 12),
          _buildStepper(3, 0),
          const SizedBox(height: 40),
          const Text('Enter Your Phone Number', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('We\'ll send you a verification code\non Telegram.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _phoneController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                prefixIcon: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇳', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text('+91', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: Colors.white38, size: 20),
              SizedBox(width: 12),
              Text('We\'ll never share your number\nwith anyone.', style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBoxes() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final String char = _otpController.text.length > index ? _otpController.text[index] : '';
            final bool isFocused = _otpController.text.length == index || (_otpController.text.length == 5 && index == 4);
            return Container(
              width: 50,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused ? AppColors.netflixRed : Colors.white10,
                  width: isFocused ? 1.5 : 1,
                ),
              ),
              child: Text(
                char,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              keyboardType: TextInputType.number,
              maxLength: 5,
              autofocus: true,
              decoration: const InputDecoration(counterText: "", border: InputBorder.none),
              onChanged: (val) {
                setState(() {});
                if (val.length == 5) {
                  _handleSignIn();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                _otpController.clear();
                _goToPage(1);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildStepper(3, 1),
          const SizedBox(height: 40),
          const Text('Enter Verification Code', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('We\'ve sent a 5-digit code to your\nTelegram app.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
          const SizedBox(height: 40),
          _buildOtpBoxes(),
          const SizedBox(height: 32),
          Text(
            _resendCountdown > 0 ? 'Resend code in 00:${_resendCountdown.toString().padLeft(2, '0')}' : 'Resend code',
            style: TextStyle(
              color: _resendCountdown > 0 ? Colors.white38 : AppColors.netflixRed, 
              fontSize: 13, 
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading || _otpController.text.length < 5 ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: Colors.white38, size: 18),
              SizedBox(width: 12),
              Text('Check your Telegram messages\n(not SMS).', style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                _passwordController.clear();
                _goToPage(2);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildStepper(4, 2),
          const SizedBox(height: 40),
          const Text('Two-Step Verification', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Your account is protected with an additional password.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.white38),
              ),
              onSubmitted: (_) => _handlePasswordSubmit(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePasswordSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.transparent, size: 20),
              onPressed: null,
            ),
          ),
          const SizedBox(height: 12),
          _buildStepper(3, 2),
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 2),
            ),
            child: const Icon(Icons.check, color: AppColors.netflixRed, size: 64),
          ),
          const SizedBox(height: 40),
          const Text('You\'re All Set!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Login successful. Enjoy unlimited\nmovies, TV shows and more.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_finalSessionString != null) {
                  ref.read(authStateProvider.notifier).login(_finalSessionString!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Let\'s Go', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: Colors.white38, size: 20),
              SizedBox(width: 12),
              Text('You can manage your account\nin Telegram settings.', style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/new_login_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopLogo(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildIntroPage(),
                      _buildPhonePage(),
                      _buildOtpPage(),
                      _buildPasswordPage(),
                      _buildSuccessPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
