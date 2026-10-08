import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _error = '10 digit ka mobile number likhein');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (mounted) Navigator.of(context).pop();
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('PHONE ERROR: ${e.code} | ${e.message}');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.code == 'invalid-phone-number'
              ? 'Number sahi nahi hai'
              : e.code == 'too-many-requests'
              ? 'Bahut zyada try ho gaye, thodi der baad karein'
              : (e.message ?? 'OTP nahi bhej paye (${e.code})');
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _error = '6 digit ka OTP likhein');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint('OTP ERROR: ${e.code} | ${e.message}');
      setState(
        () => _error = e.code == 'invalid-verification-code'
            ? 'OTP galat hai'
            : (e.message ?? 'Verify nahi hua (${e.code})'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpStage = _verificationId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone se login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!otpStage)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6 digit OTP',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ElevatedButton(
              onPressed: _loading ? null : (otpStage ? _verifyOtp : _sendOtp),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(otpStage ? 'Verify OTP' : 'OTP bhejein'),
            ),
            if (otpStage)
              TextButton(
                onPressed: () => setState(() {
                  _verificationId = null;
                  _otpController.clear();
                }),
                child: const Text('Number badlein'),
              ),
          ],
        ),
      ),
    );
  }
}
