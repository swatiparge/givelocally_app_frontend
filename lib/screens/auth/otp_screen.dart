import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:givelocally_app/services/auth_service.dart';
import 'package:givelocally_app/utils/constants.dart';
import 'location_confirmation_screen.dart';
import '../home/home_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  int _resendTimer = 60;
  bool _canResend = false;
  bool _disposed = false;  // ✅ Track disposal state

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _disposed = true;  // ✅ Mark as disposed FIRST
    _otpController.dispose();
    super.dispose();
  }

  // ==========================================
  // RESEND TIMER (FIXED)
  // ==========================================
  
  void _startResendTimer() {
    if (_disposed) return;  // ✅ Don't start if disposed
    
    if (mounted) {
      setState(() {
        _resendTimer = 60;
        _canResend = false;
      });
    }

    _runTimer();
  }

  void _runTimer() async {
    while (_resendTimer > 0 && !_disposed && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      
      if (_disposed || !mounted) break;
      
      setState(() {
        _resendTimer--;
        if (_resendTimer == 0) {
          _canResend = true;
        }
      });
    }
  }

  // ==========================================
  // VERIFY OTP
  // ==========================================
  
  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6 || _disposed) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      bool success = await authService.verifyOTP(otp);

      if (!mounted || _disposed) return;

      if (success) {
        // Check if new user
        if (authService.userModel?.name == null) {
          // New user → Location Setup (WF-14) → Profile Setup (WF-03)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LocationConfirmationScreen(),
            ),
          );
        } else {
          // Existing user → Home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      } else {
        _showError(authService.error ?? 'Invalid OTP');
        _otpController.clear();
      }
    } catch (e) {
      if (!mounted || _disposed) return;
      _showError(e.toString());
      _otpController.clear();
    } finally {
      if (mounted && !_disposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // RESEND OTP
  // ==========================================
  
  Future<void> _resendOTP() async {
    if (!_canResend || _disposed) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      bool success = await authService.sendOTPWithFirebase(widget.phoneNumber);

      if (!mounted || _disposed) return;

      if (success) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted || _disposed) return;
      _showError('Failed to resend OTP');
    } finally {
      if (mounted && !_disposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // SHOW ERROR
  // ==========================================
  
  void _showError(String message) {
    if (_disposed || !mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!_disposed) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              
              const Text(
                'Verify your phone',
                style: AppTextStyles.heading1,
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              Text(
                'We sent an OTP to ${widget.phoneNumber}',
                style: AppTextStyles.bodySecondary,
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // OTP INPUT
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: AppColors.background,
                  inactiveFillColor: AppColors.background,
                  selectedFillColor: AppColors.background,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  selectedColor: AppColors.primary,
                ),
                cursorColor: AppColors.primary,
                enableActiveFill: true,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                onCompleted: _verifyOTP,
                onChanged: (_) {},
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // RESEND OTP
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resendOTP,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Text(
                        'Resend OTP in $_resendTimer seconds',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // CHANGE NUMBER
              Center(
                child: TextButton(
                  onPressed: () {
                    if (!_disposed) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Change phone number',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
