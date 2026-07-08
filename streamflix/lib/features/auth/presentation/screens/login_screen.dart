import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:streamflix/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController(text: '+91');
  final _otpController = TextEditingController();
  
  bool _codeSent = false;
  bool _isLoading = false;
  String? _statusMessage;
  StreamSubscription<String>? _authSub;

  @override
  void initState() {
    super.initState();
    // Listen for error events from GramJS so we can show them and stop loading
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
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone == '+91') return;

    setState(() { 
      _isLoading = true; 
      _statusMessage = 'Waiting for Telegram client...';
    });

    try {
      // sendCode internally awaits isReady, so it won't fire too early
      await TelegramClientService().sendCode(phone);
      
      setState(() { _statusMessage = 'Code request sent. Waiting for confirmation...'; });

      // Wait for either 'phoneCodeSent' or an error
      final result = await TelegramClientService().authStateStream
          .firstWhere((e) => e == 'phoneCodeSent' || e.startsWith('error:'))
          .timeout(const Duration(seconds: 30), onTimeout: () => 'error:Timeout waiting for code');
      
      if (result == 'phoneCodeSent') {
        if (mounted) {
          setState(() {
            _codeSent = true;
            _isLoading = false;
            _statusMessage = 'Code sent! Check your Telegram app.';
          });
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
          SnackBar(content: Text('Failed to send code: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleSignIn() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;

    setState(() { 
      _isLoading = true;
      _statusMessage = 'Verifying code...';
    });

    try {
      await TelegramClientService().signIn(_phoneController.text.trim(), otp);
      
      // Wait for either 'signedIn' or an error
      final result = await TelegramClientService().authStateStream
          .firstWhere((e) => e == 'signedIn' || e.startsWith('error:'))
          .timeout(const Duration(seconds: 30), onTimeout: () => 'error:Timeout during sign-in');
      
      if (result == 'signedIn') {
        final session = TelegramClientService().sessionString;
        if (session != null) {
          ref.read(authStateProvider.notifier).login(session);
          // Router will redirect automatically
        } else {
          throw Exception('Session was null after sign-in');
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
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top - 
                           MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Text(
                    'S',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.netflixRed,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'StreamFlix',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 120),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.transparent, AppColors.netflixRed, Colors.transparent],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Link your Telegram account\nfor direct streaming',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Status message
                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          if (_isLoading) ...[
                            const SizedBox(
                              height: 14, width: 14,
                              child: CircularProgressIndicator(color: AppColors.netflixRed, strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                          ] else ...[
                            const Icon(Icons.info_outline, color: Colors.white38, size: 16),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  if (!_codeSent) ...[
                    // Phone input
                    TextField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Colors.white38),
                        hintText: '+91 98765 43210',
                        hintStyle: const TextStyle(color: Colors.white12),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.netflixRed, width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white38),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.netflixRed,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.netflixRed.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              height: 20, width: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Send Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else ...[
                    // OTP input
                    TextField(
                      controller: _otpController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        labelStyle: const TextStyle(color: Colors.white38),
                        hintText: '• • • • •',
                        hintStyle: const TextStyle(color: Colors.white12, letterSpacing: 8),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.netflixRed, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.netflixRed,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.netflixRed.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              height: 20, width: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Verify & Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _codeSent = false;
                          _otpController.clear();
                          _statusMessage = null;
                        });
                      },
                      child: const Text('← Change Phone Number', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ),
                  ],

                  const SizedBox(height: 48),
                  const Text(
                    'StreamFlix uses Telegram\'s MTProto for\ndirect, zero-latency streaming.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
