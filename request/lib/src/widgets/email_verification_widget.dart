import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';

class EmailVerificationWidget extends StatefulWidget {
  final String email;
  final String purpose;
  final Function(bool verified, String? verificationSource)?
      onVerificationComplete;
  final bool showAutoVerificationStatus;

  const EmailVerificationWidget({
    Key? key,
    required this.email,
    this.purpose = 'verification',
    this.onVerificationComplete,
    this.showAutoVerificationStatus = true,
  }) : super(key: key);

  @override
  State<EmailVerificationWidget> createState() =>
      _EmailVerificationWidgetState();
}

class _EmailVerificationWidgetState extends State<EmailVerificationWidget> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isVerified = false;
  bool _otpSent = false;
  String? _otpId;
  String? _errorMessage;
  String? _successMessage;
  String? _verificationSource;
  int _remainingTime = 600; // 10 minutes
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// Check if email is already verified
  Future<void> _checkVerificationStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await ApiClient.instance.get(
          '/api/email-verification/status/${Uri.encodeComponent(widget.email)}');

      if (response.isSuccess) {
        final data = response.data;
        final bool verified = data['verified'] ?? false;

        if (verified) {
          setState(() {
            _isVerified = true;
            _verificationSource = data['verificationMethod'] ?? 'unknown';
            _successMessage = widget.showAutoVerificationStatus
                ? 'Email is already verified (${_verificationSource})'
                : 'Email verified';
          });

          widget.onVerificationComplete?.call(true, _verificationSource);
        }
      }
    } catch (e) {
      print('Error checking verification status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Send OTP to email
  Future<void> _sendOTP() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await ApiClient.instance.post(
        '/api/email-verification/send-otp',
        data: {
          'email': widget.email,
          'purpose': widget.purpose,
        },
      );

      if (response.isSuccess) {
        final data = response.data;

        if (data['alreadyVerified'] == true) {
          setState(() {
            _isVerified = true;
            _successMessage = 'Email is already verified';
          });
          widget.onVerificationComplete?.call(true, 'already_verified');
        } else {
          setState(() {
            _otpSent = true;
            _otpId = data['otpId'];
            _successMessage = 'Verification code sent to ${widget.email}';
            _remainingTime = data['expiresIn'] ?? 600;
            _canResend = false;
          });
          _startCountdown();
        }
      } else {
        setState(() {
          _errorMessage =
              response.message ?? 'Failed to send verification code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send verification code: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Verify OTP
  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await ApiClient.instance.post(
        '/api/email-verification/verify-otp',
        data: {
          'email': widget.email,
          'otp': _otpController.text,
          'otpId': _otpId,
          'purpose': widget.purpose,
        },
      );

      if (response.isSuccess) {
        setState(() {
          _isVerified = true;
          _verificationSource = 'otp';
          _successMessage = 'Email verified successfully!';
        });
        widget.onVerificationComplete?.call(true, _verificationSource);
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Invalid verification code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Start countdown timer
  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
        _startCountdown();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isVerified ? Icons.verified : Icons.email,
                  color: _isVerified ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Email Verification',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_isVerified)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Email: ${widget.email}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 16),

            // Show success message
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

            // Show error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            if (_successMessage != null || _errorMessage != null)
              const SizedBox(height: 16),

            // Show verification steps
            if (!_isVerified) ...[
              if (!_otpSent) ...[
                // Step 1: Send OTP
                Text(
                  'Click the button below to send a verification code to your email.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendOTP,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                        _isLoading ? 'Sending...' : 'Send Verification Code'),
                  ),
                ),
              ] else ...[
                // Step 2: Enter OTP
                Text(
                  'Enter the 6-digit code sent to your email:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (value.length == 6) {
                      _verifyOTP();
                    }
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _verifyOTP,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user),
                        label:
                            Text(_isLoading ? 'Verifying...' : 'Verify Code'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Resend option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _canResend
                          ? 'Didn\'t receive the code? '
                          : 'Resend code in ${_formatTime(_remainingTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_canResend)
                      TextButton(
                        onPressed: _sendOTP,
                        child: const Text('Resend'),
                      ),
                  ],
                ),
              ],
            ],

            // Verification status
            if (_isVerified &&
                widget.showAutoVerificationStatus &&
                _verificationSource != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Verified via: $_verificationSource',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
