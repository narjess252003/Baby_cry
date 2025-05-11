import 'package:flutter/material.dart';
import 'CryAnalysisPage.dart';
import 'MainDashboardPage.dart'; // Make sure this page exists
import 'app_localizations.dart';
import 'db/database_helper.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final String phone;

  OTPVerificationPage({
    required this.email,
    required this.password,
    required this.phone,
  });

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  String _otpCode = '';
  final dbHelper = DatabaseHelper();
  bool _isLoading = false;

  Future<void> _verifyOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        bool isValid = await dbHelper.verifyOTP(widget.email, _otpCode);

        if (isValid) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).translate(
                'verification_successful')),
          ));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CryAnalysisPage(
                    userInfo: {
                      'email': widget.email,
                      'phone': widget.phone,
                      'password': widget.password,
                    },
                  ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('invalid_otp')),
          ));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${AppLocalizations.of(context).translate(
              'verification_failed')}: $e"),
        ));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xEC8A6AC3), // fallback background color
      appBar: AppBar(
        title: Text(
          "🔐 ${AppLocalizations.of(context).translate('otp_verification')}",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xAA9575CD), // Watery purple with transparency
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background GIF
          Positioned.fill(
            child: Image.asset(
              'assets/art5.gif',
              fit: BoxFit.cover,
            ),
          ),
          // Form content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context).translate(
                            'enter_otp_sent_to'),
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.email,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Color(0xFF4E4165), // Dark purple
                        ),
                      ),
                      SizedBox(height: 24),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).translate('otp'),
                          labelStyle: TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          filled: true,
                          fillColor: Color(0xFFF1E6FA), // Light purple background
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Color(0xFFAB47BC),
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle( // 👈 This controls the text color inside the field
                          color: Colors.grey[800], // Dark grey
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (value) => value == null || value.isEmpty
                            ? AppLocalizations.of(context).translate('enter_otp')
                            : null,
                        onChanged: (value) => _otpCode = value,
                      ),

                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOTP,
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                          AppLocalizations.of(context).translate('verify'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xCBB39DDB),
                          // Calmer soft purple
                          padding: EdgeInsets.symmetric(vertical: 14,
                              horizontal: 60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}