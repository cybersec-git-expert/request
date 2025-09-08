# Flutter Email Verification Integration Guide

## Overview

This guide provides complete integration instructions for implementing the unified email verification system in Flutter applications. The system includes automatic verification detection, OTP sending/verification, and comprehensive admin management.

---

## Table of Contents

1. [Setup and Dependencies](#1-setup-and-dependencies)
2. [API Client Configuration](#2-api-client-configuration)
3. [Email Verification Widget](#3-email-verification-widget)
4. [Admin Management Interface](#4-admin-management-interface)
5. [Integration Examples](#5-integration-examples)
6. [Error Handling](#6-error-handling)
7. [Testing Guide](#7-testing-guide)
8. [Customization Options](#8-customization-options)

---

## 1. Setup and Dependencies

### pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.3.2
  shared_preferences: ^2.2.2
  provider: ^6.1.1
  flutter_spinkit: ^5.2.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2
  build_runner: ^2.4.7
```

### Installation
```bash
flutter pub get
flutter pub run build_runner build
```

---

## 2. API Client Configuration

### api_client.dart
```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  static const String baseUrl = 'http://localhost:3001'; // Change for production

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        _handleError(error);
        handler.next(error);
      },
    ));
  }

  void _handleError(DioException error) {
    print('API Error: ${error.message}');
    if (error.response?.statusCode == 401) {
      // Handle unauthorized access
      _clearTokenAndRedirectToLogin();
    }
  }

  Future<void> _clearTokenAndRedirectToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    // Navigate to login screen
  }

  Dio get dio => _dio;
}
```

### email_verification_service.dart
```dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class EmailVerificationService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> checkVerificationStatus(String email) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/email-verification/status/${Uri.encodeComponent(email)}',
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendOTP(String email, {String purpose = 'verification'}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/email-verification/send-otp',
        data: {
          'email': email,
          'purpose': purpose,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String otp,
    required String otpId,
    String purpose = 'verification',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/email-verification/verify-otp',
        data: {
          'email': email,
          'otp': otp,
          'otpId': otpId,
          'purpose': purpose,
        },
      );
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> listVerifiedEmails() async {
    try {
      final response = await _apiClient.dio.get('/api/email-verification/list');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      final message = error.response?.data?['message'] ?? error.message;
      return Exception(message);
    }
    return Exception('Unknown error occurred');
  }
}
```

---

## 3. Email Verification Widget

### email_verification_widget.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'email_verification_service.dart';

class EmailVerificationWidget extends StatefulWidget {
  final String email;
  final String purpose;
  final Function(bool verified, String? error)? onVerificationComplete;
  final Widget? customLoadingIndicator;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const EmailVerificationWidget({
    Key? key,
    required this.email,
    this.purpose = 'verification',
    this.onVerificationComplete,
    this.customLoadingIndicator,
    this.titleStyle,
    this.subtitleStyle,
  }) : super(key: key);

  @override
  State<EmailVerificationWidget> createState() => _EmailVerificationWidgetState();
}

class _EmailVerificationWidgetState extends State<EmailVerificationWidget> {
  final EmailVerificationService _verificationService = EmailVerificationService();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = true;
  bool _isVerified = false;
  bool _showOtpInput = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String? _errorMessage;
  String? _successMessage;
  String? _otpId;
  
  Timer? _resendTimer;
  int _resendCountdown = 0;
  
  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _verificationService.checkVerificationStatus(widget.email);
      
      if (!mounted) return;
      
      if (result['success'] && result['verified']) {
        setState(() {
          _isVerified = true;
          _successMessage = result['verificationMethod'] == 'registration'
              ? 'Email is already verified (registered email)'
              : 'Email is already verified';
        });
        widget.onVerificationComplete?.call(true, null);
      } else {
        setState(() {
          _showOtpInput = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _showOtpInput = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendOTP() async {
    if (!mounted) return;
    
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _verificationService.sendOTP(widget.email, purpose: widget.purpose);
      
      if (!mounted) return;
      
      if (result['success']) {
        if (result['alreadyVerified'] == true) {
          setState(() {
            _isVerified = true;
            _successMessage = result['message'];
          });
          widget.onVerificationComplete?.call(true, null);
        } else {
          setState(() {
            _otpId = result['otpId'];
            _successMessage = result['message'];
          });
          _startResendTimer();
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code';
      });
      return;
    }

    if (_otpId == null) {
      setState(() {
        _errorMessage = 'Please request a new verification code';
      });
      return;
    }

    if (!mounted) return;
    
    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      final result = await _verificationService.verifyOTP(
        email: widget.email,
        otp: otp,
        otpId: _otpId!,
        purpose: widget.purpose,
      );
      
      if (!mounted) return;
      
      if (result['success'] && result['emailVerified']) {
        setState(() {
          _isVerified = true;
          _successMessage = result['message'];
        });
        widget.onVerificationComplete?.call(true, null);
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Invalid verification code';
        });
        widget.onVerificationComplete?.call(false, _errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = errorMsg;
      });
      widget.onVerificationComplete?.call(false, errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _resendCountdown--;
      });
      
      if (_resendCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.customLoadingIndicator ?? const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Checking email verification status...',
            style: widget.subtitleStyle ?? Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Email Verified',
            style: widget.titleStyle ?? Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _successMessage ?? 'Your email has been verified successfully',
            style: widget.subtitleStyle ?? Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInputState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify Your Email',
          style: widget.titleStyle ?? Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send a verification code to:',
          style: widget.subtitleStyle ?? Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        // Send OTP Button or OTP Input
        if (_otpId == null) ...[
          ElevatedButton(
            onPressed: _isSendingOtp ? null : _sendOTP,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Verification Code'),
          ),
        ] else ...[
          // OTP Input Field
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Enter 6-digit code',
              hintText: '123456',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _errorMessage,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          
          // Verify Button
          ElevatedButton(
            onPressed: _isVerifyingOtp ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isVerifyingOtp
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify Code'),
          ),
          const SizedBox(height: 16),
          
          // Resend Button
          TextButton(
            onPressed: _resendCountdown > 0 || _isSendingOtp ? null : _sendOTP,
            child: Text(_resendCountdown > 0
                ? 'Resend code in ${_resendCountdown}s'
                : 'Resend verification code'),
          ),
        ],
        
        // Success Message
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
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
        ],
        
        // Error Message
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
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
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? _buildLoadingState()
          : _isVerified
              ? _buildVerifiedState()
              : _buildOtpInputState(),
    );
  }
}
```

---

## 4. Admin Management Interface

### admin_email_management_screen.dart
```dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_client.dart';

class AdminEmailManagementScreen extends StatefulWidget {
  const AdminEmailManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminEmailManagementScreen> createState() => _AdminEmailManagementScreenState();
}

class _AdminEmailManagementScreenState extends State<AdminEmailManagementScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _emails = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  Timer? _searchDebouncer;

  @override
  void initState() {
    super.initState();
    _loadEmailData();
    _loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmailData({int page = 1, String? search}) async {
    if (!mounted) return;
    
    setState(() {
      if (page == 1) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': 20,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await _apiClient.dio.get(
        '/api/admin/email-management/user-emails',
        queryParameters: queryParams,
      );

      if (!mounted) return;

      if (response.data['success']) {
        setState(() {
          if (page == 1) {
            _emails = List<Map<String, dynamic>>.from(response.data['emails']);
          } else {
            _emails.addAll(List<Map<String, dynamic>>.from(response.data['emails']));
          }
          _currentPage = response.data['pagination']['page'];
          _totalPages = response.data['pagination']['totalPages'];
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to load email data';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/email-management/stats');
      
      if (!mounted) return;
      
      if (response.data['success']) {
        setState(() {
          _stats = response.data['stats'];
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<void> _toggleEmailVerification(Map<String, dynamic> email) async {
    final newStatus = !email['is_verified'];
    
    try {
      final response = await _apiClient.dio.post(
        '/api/admin/email-management/toggle-verification',
        data: {
          'emailId': email['id'].toString(),
          'verified': newStatus,
        },
      );

      if (response.data['success']) {
        setState(() {
          email['is_verified'] = newStatus;
          if (newStatus) {
            email['verified_at'] = DateTime.now().toIso8601String();
          }
        });
        
        _showSnackBar(
          'Email verification ${newStatus ? 'enabled' : 'disabled'} successfully',
          Colors.green,
        );
        
        // Reload stats
        _loadStats();
      } else {
        _showSnackBar('Failed to update verification status', Colors.red);
      }
    } catch (e) {
      _showSnackBar(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        Colors.red,
      );
    }
  }

  void _onSearchChanged(String query) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSearching = true;
          _currentPage = 1;
        });
        _loadEmailData(search: query.isEmpty ? null : query);
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatItem('Total Emails', _stats!['total_emails'].toString()),
                _buildStatItem('Verified', _stats!['verified_emails'].toString(), Colors.green),
                _buildStatItem('Pending', _stats!['pending_emails'].toString(), Colors.orange),
                _buildStatItem('Registration Verified', _stats!['registration_verified'].toString()),
                _buildStatItem('OTP Verified', _stats!['otp_verified'].toString()),
                _buildStatItem('Business Emails', _stats!['business_emails'].toString()),
                _buildStatItem('Driver Emails', _stats!['driver_emails'].toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? Theme.of(context).primaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).primaryColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: (color ?? Theme.of(context).primaryColor).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailList() {
    if (_isLoading && _emails.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_emails.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No emails found'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _emails.length + (_currentPage < _totalPages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _emails.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: () => _loadEmailData(page: _currentPage + 1),
                child: const Text('Load More'),
              ),
            ),
          );
        }

        final email = _emails[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: email['is_verified'] ? Colors.green : Colors.orange,
              child: Icon(
                email['is_verified'] ? Icons.check : Icons.pending,
                color: Colors.white,
              ),
            ),
            title: Text(
              email['email_address'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${email['user_name'] ?? 'Unknown'}'),
                Text('Purpose: ${email['purpose'] ?? 'N/A'}'),
                if (email['verified_at'] != null)
                  Text('Verified: ${DateTime.parse(email['verified_at']).toLocal().toString().split('.')[0]}'),
                Text('Method: ${email['verification_method'] ?? 'N/A'}'),
              ],
            ),
            trailing: Switch(
              value: email['is_verified'],
              onChanged: (_) => _toggleEmailVerification(email),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Management'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadEmailData();
          await _loadStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsCards(),
              const SizedBox(height: 16),
              
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search emails or users',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),
              
              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Email List
              _buildEmailList(),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 5. Integration Examples

### Business Verification Screen
```dart
class BusinessVerificationScreen extends StatefulWidget {
  @override
  _BusinessVerificationScreenState createState() => _BusinessVerificationScreenState();
}

class _BusinessVerificationScreenState extends State<BusinessVerificationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _emailVerified = false;
  String? _verificationError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Verification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Business Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            if (_emailController.text.isNotEmpty) ...[
              EmailVerificationWidget(
                email: _emailController.text,
                purpose: 'business',
                onVerificationComplete: (verified, error) {
                  setState(() {
                    _emailVerified = verified;
                    _verificationError = error;
                  });
                },
              ),
            ],
            
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _emailVerified ? _proceedWithVerification : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _proceedWithVerification() {
    // Proceed with business verification
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NextVerificationStep()),
    );
  }
}
```

### Driver Verification Screen
```dart
class DriverVerificationScreen extends StatefulWidget {
  @override
  _DriverVerificationScreenState createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Verification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Driver Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            if (_emailController.text.isNotEmpty) ...[
              EmailVerificationWidget(
                email: _emailController.text,
                purpose: 'driver',
                titleStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                onVerificationComplete: (verified, error) {
                  if (verified) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Driver email verified successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## 6. Error Handling

### Custom Error Handler
```dart
class EmailVerificationErrorHandler {
  static String getDisplayMessage(String error) {
    if (error.contains('Invalid email format')) {
      return 'Please enter a valid email address';
    } else if (error.contains('Rate limit exceeded')) {
      return 'Too many attempts. Please try again later';
    } else if (error.contains('Invalid OTP')) {
      return 'Invalid verification code. Please try again';
    } else if (error.contains('OTP expired')) {
      return 'Verification code expired. Please request a new one';
    } else if (error.contains('Network')) {
      return 'Network error. Please check your connection';
    } else if (error.contains('Unauthorized')) {
      return 'Session expired. Please log in again';
    }
    return error;
  }

  static IconData getErrorIcon(String error) {
    if (error.contains('Network')) {
      return Icons.wifi_off;
    } else if (error.contains('Unauthorized')) {
      return Icons.lock;
    } else if (error.contains('Rate limit')) {
      return Icons.timer;
    }
    return Icons.error;
  }
}
```

### Enhanced Error Display Widget
```dart
class ErrorDisplayWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({
    Key? key,
    required this.error,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayMessage = EmailVerificationErrorHandler.getDisplayMessage(error);
    final icon = EmailVerificationErrorHandler.getErrorIcon(error);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            displayMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## 7. Testing Guide

### Unit Tests
```dart
// test/email_verification_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import '../lib/services/email_verification_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('EmailVerificationService', () {
    late EmailVerificationService service;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      service = EmailVerificationService();
      // Inject mock dio
    });

    test('should send OTP successfully', () async {
      // Arrange
      when(mockDio.post(any, data: anyNamed('data')))
          .thenAnswer((_) async => Response(
                data: {'success': true, 'otpId': 'test-otp-id'},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      // Act
      final result = await service.sendOTP('test@example.com');

      // Assert
      expect(result['success'], true);
      expect(result['otpId'], 'test-otp-id');
    });

    test('should verify OTP successfully', () async {
      // Arrange
      when(mockDio.post(any, data: anyNamed('data')))
          .thenAnswer((_) async => Response(
                data: {'success': true, 'emailVerified': true},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      // Act
      final result = await service.verifyOTP(
        email: 'test@example.com',
        otp: '123456',
        otpId: 'test-otp-id',
      );

      // Assert
      expect(result['success'], true);
      expect(result['emailVerified'], true);
    });
  });
}
```

### Widget Tests
```dart
// test/email_verification_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/email_verification_widget.dart';

void main() {
  group('EmailVerificationWidget', () {
    testWidgets('should display loading state initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailVerificationWidget(
              email: 'test@example.com',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Checking email verification status...'), findsOneWidget);
    });

    testWidgets('should display OTP input when email is not verified', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailVerificationWidget(
              email: 'test@example.com',
            ),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });
  });
}
```

### Integration Tests
```dart
// integration_test/email_verification_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:your_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Email Verification Flow', () {
    testWidgets('complete email verification flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to email verification screen
      await tester.tap(find.text('Verify Email'));
      await tester.pumpAndSettle();

      // Enter email
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pumpAndSettle();

      // Send OTP
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Enter OTP (in real test, you'd get this from test email)
      await tester.enterText(find.byKey(const Key('otp_input')), '123456');
      await tester.pumpAndSettle();

      // Verify OTP
      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check for success message
      expect(find.text('Email Verified'), findsOneWidget);
    });
  });
}
```

---

## 8. Customization Options

### Theme Customization
```dart
class EmailVerificationTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  static TextStyle get titleStyle => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static TextStyle get subtitleStyle => const TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );

  static InputDecoration get otpInputDecoration => InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
  );
}
```

### Custom Loading Indicator
```dart
class CustomLoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpinKitWave(
          color: Theme.of(context).primaryColor,
          size: 50.0,
        ),
        const SizedBox(height: 16),
        const Text('Verifying email...'),
      ],
    );
  }
}
```

### Custom Success Animation
```dart
class SuccessAnimation extends StatefulWidget {
  @override
  _SuccessAnimationState createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 80,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## Configuration

### Environment Configuration
```dart
class EmailVerificationConfig {
  static const String developmentBaseUrl = 'http://localhost:3001';
  static const String productionBaseUrl = 'https://api.requestmarketplace.com';
  
  static String get baseUrl {
    return const bool.fromEnvironment('dart.vm.product')
        ? productionBaseUrl
        : developmentBaseUrl;
  }
  
  static const int otpLength = 6;
  static const int resendCooldown = 60;
  static const int maxOtpAttempts = 3;
}
```

### Feature Flags
```dart
class EmailVerificationFeatures {
  static const bool autoVerifyRegistrationEmails = true;
  static const bool showResendTimer = true;
  static const bool enableAdminManagement = true;
  static const bool logVerificationEvents = true;
}
```

---

This comprehensive Flutter integration guide provides everything needed to implement the unified email verification system in your Flutter application. The modular design allows for easy customization and testing while maintaining consistency with the backend API.
