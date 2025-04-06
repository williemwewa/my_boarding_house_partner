import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';
import 'package:my_boarding_house_partner/screens/auth/verification_screen.dart';
import 'package:my_boarding_house_partner/services/auth_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({Key? key}) : super(key: key);

  @override
  _PhoneLoginScreenState createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthenticationService();

  String _verificationId = '';
  String? _completePhoneNumber;
  bool _isLoading = false;
  bool _isResendingCode = false;
  String _selectedCountryCode = 'ZM';
  int? _forceResendingToken;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCodeToPhoneNumber() async {
    setState(() {
      _isLoading = true;
    });

    if (_completePhoneNumber == null || _completePhoneNumber!.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Please enter a valid phone number');
      return;
    }

    final PhoneVerificationCompleted verificationCompleted = (PhoneAuthCredential credential) async {
      try {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) {
          // Success handled in auth state listener in AuthProvider
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Sign in failed. Please try again.');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    };

    final PhoneVerificationFailed verificationFailed = (FirebaseAuthException authException) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar(authException.message ?? 'Verification failed. Please try again.');
      }
    };

    final PhoneCodeSent codeSent = (String verificationId, int? forceResendingToken) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _verificationId = verificationId;
          _forceResendingToken = forceResendingToken;
        });
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => OTPVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: _completePhoneNumber!,
                  forceResendingToken: forceResendingToken,
                  isLandlordApp: true, // This is the landlord/admin app
                ),
          ),
        );
      }
    };

    final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout = (String verificationId) {
      if (mounted) {
        _verificationId = verificationId;
        setState(() {
          _isLoading = false;
        });
      }
    };

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _completePhoneNumber!,
        timeout: const Duration(seconds: 60),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        forceResendingToken: _forceResendingToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('An error occurred. Please check your connection and try again.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  void _onContinuePressed() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      await _sendCodeToPhoneNumber();
    }
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
                  LinearProgressIndicator(value: 0.5, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)),
                  const SizedBox(height: 24),

                  // Header
                  const Text("Partner Login", style: TextStyle(fontSize: 28.0, color: AppTheme.primaryColor, fontWeight: FontWeight.bold, height: 1.2)),
                  const SizedBox(height: 12),
                  Text("Please enter your phone number to sign in to your landlord or admin account", style: TextStyle(fontSize: 16.0, color: Colors.grey.shade700)),
                  const SizedBox(height: 32),

                  // Phone input
                  Form(
                    key: _formKey,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 10, spreadRadius: 0)]),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IntlPhoneField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your phone number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2B7E), width: 2)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          initialCountryCode: _selectedCountryCode,
                          onChanged: (phone) {
                            _completePhoneNumber = phone.completeNumber;
                          },
                          onCountryChanged: (country) {
                            setState(() {
                              _selectedCountryCode = country.code;
                            });
                          },
                          dropdownIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1F2B7E)),
                          flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 16),
                          disableLengthCheck: false,
                          flagsButtonMargin: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onContinuePressed,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2.5)) : const Text("Continue", style: TextStyle(fontSize: 18.0, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700), const SizedBox(width: 8), Expanded(child: Text("Partner Access Only:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade800)))],
                        ),
                        const SizedBox(height: 8),
                        Text("• This login is for landlords and administrators only\n• If you're a student, please use the Student App\n• Contact support if you need assistance with your account", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.grey.shade700, height: 1.5)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            // Navigate to contact support
                          },
                          child: const Text("Need Help? Contact Support", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2B7E), decoration: TextDecoration.underline)),
                        ),
                      ],
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
