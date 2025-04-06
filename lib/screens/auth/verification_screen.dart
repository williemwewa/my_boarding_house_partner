import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_boarding_house_partner/screens/landloard/landlord_dashboard.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/screens/auth/profile_setup_screen.dart';
import 'package:my_boarding_house_partner/screens/admin/admin_dashboard.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? forceResendingToken;
  final bool isLandlordApp;

  const OTPVerificationScreen({Key? key, required this.verificationId, required this.phoneNumber, this.forceResendingToken, this.isLandlordApp = true}) : super(key: key);

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  bool _canResend = false;

  // Add timer instance variable
  Timer? _timer;

  // Add verification ID state so we can update it
  late String _verificationId;
  int? _forceResendingToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _forceResendingToken = widget.forceResendingToken;
    _startResendTimer();
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });

    // Cancel existing timer if any
    _timer?.cancel();

    // Create a periodic timer instead of using recursion
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendTimer -= 1;
        });

        if (_resendTimer <= 0) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _canResend = true;
            });
          }
        }
      } else {
        timer.cancel(); // Cancel if not mounted
      }
    });
  }

  void _verifyOTP() async {
    String otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      _showErrorSnackBar('Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId, // Use the updated verification ID
        smsCode: otp,
      );

      // Sign in with the credential
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null && mounted) {
        // Check if the user is new or has a profile
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

        // Wait for authProvider to update user info
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        bool isNewUser = await authProvider.checkIfNewUser();
        print('Is a new user $isNewUser');

        if (isNewUser) {
          _showSuccessSnackBar('Successfully verified! Please complete your profile.');
          // Navigate to profile setup
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const UserProfileSetupScreen()), (route) => false);
        } else {
          _showSuccessSnackBar('Successfully verified!');

          // Navigate based on user role
          if (authProvider.userRole == UserRole.landlord) {
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LandlordDashboard()), (route) => false);
          } else if (authProvider.userRole == UserRole.admin) {
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AdminDashboard()), (route) => false);
          } else {
            // If somehow a student logs in to landlord app, send to profile setup
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const UserProfileSetupScreen()), (route) => false);
          }
        }
      } else if (mounted) {
        _showErrorSnackBar('An error occurred. Please try again later.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'The OTP you entered is incorrect. Please try again.';
      } else {
        errorMessage = e.message ?? 'An error occurred. Please try again later.';
      }

      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
    });

    try {
      // Implement proper resend code functionality
      final PhoneVerificationCompleted verificationCompleted = (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          // Navigate based on user info
          if (mounted) {
            // Will be handled by auth state listener
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('Sign in failed. Please try again.');
          }
        } finally {
          if (mounted) {
            setState(() {
              _isResending = false;
            });
          }
        }
      };

      final PhoneVerificationFailed verificationFailed = (FirebaseAuthException authException) {
        if (mounted) {
          setState(() {
            _isResending = false;
          });
          _showErrorSnackBar(authException.message ?? 'Verification failed. Please try again.');
        }
      };

      final PhoneCodeSent codeSent = (String verificationId, int? forceResendingToken) {
        if (mounted) {
          setState(() {
            _isResending = false;
            _verificationId = verificationId; // Update the verification ID
            _forceResendingToken = forceResendingToken; // Update the token
          });
          _startResendTimer(); // Restart the timer
          _showSuccessSnackBar('A new verification code has been sent.');
        }
      };

      final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout = (String verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isResending = false;
          });
        }
      };

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        forceResendingToken: _forceResendingToken, // Use the token for resending
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to resend code. Please try again.');
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Format the phone number to show only last 4 digits for privacy
    if (phoneNumber.length > 4) {
      return '${phoneNumber.substring(0, phoneNumber.length - 4).replaceAll(RegExp(r'[0-9]'), '*')}${phoneNumber.substring(phoneNumber.length - 4)}';
    }
    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, iconTheme: const IconThemeData(color: AppTheme.primaryColor), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  LinearProgressIndicator(value: 0.75, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)),
                  const SizedBox(height: 24),

                  // Header
                  const Text("Verification Code", style: TextStyle(fontSize: 28.0, color: AppTheme.primaryColor, fontWeight: FontWeight.bold, height: 1.2)),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 16.0, color: Colors.grey.shade700, height: 1.5),
                      children: [const TextSpan(text: "Enter the 6-digit code sent to "), TextSpan(text: _formatPhoneNumber(widget.phoneNumber), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OTP input
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 10, spreadRadius: 0)]),
                    padding: const EdgeInsets.all(16),
                    child: PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      autoDismissKeyboard: true,
                      animationType: AnimationType.fade,
                      enableActiveFill: true,
                      autoFocus: true,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(8),
                        fieldHeight: 50,
                        fieldWidth: 45,
                        activeFillColor: Colors.grey.shade50,
                        selectedFillColor: Colors.grey.shade100,
                        inactiveFillColor: Colors.grey.shade50,
                        activeColor: const Color(0xFF1F2B7E),
                        selectedColor: const Color(0xFF1F2B7E),
                        inactiveColor: Colors.grey.shade300,
                        borderWidth: 1.5,
                      ),
                      onChanged: (value) {},
                      onCompleted: (value) {
                        // Auto-verify when all 6 digits are entered
                        if (value.length == 6 && !_isLoading) {
                          _verifyOTP();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2.5)) : const Text("Verify", style: TextStyle(fontSize: 18.0, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resend code
                  Center(
                    child: Column(
                      children: [
                        Text("Didn't receive the code?", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        _isResending
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F2B7E)), strokeWidth: 2.0))
                            : TextButton(onPressed: _canResend ? _resendCode : null, child: Text(_canResend ? "Resend Code" : "Resend Code in $_resendTimer seconds", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _canResend ? const Color(0xFF1F2B7E) : Colors.grey.shade500))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Having trouble?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                              const SizedBox(height: 4),
                              Text("Make sure you've entered the correct phone number and check your SMS inbox for the verification code.", style: TextStyle(fontSize: 13, color: Colors.blue.shade800, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Change number option
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1F2B7E)),
                      label: const Text("Change Phone Number", style: TextStyle(fontSize: 15, color: Color(0xFF1F2B7E), fontWeight: FontWeight.w500)),
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
