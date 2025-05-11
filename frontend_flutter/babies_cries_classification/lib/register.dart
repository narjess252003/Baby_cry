import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:country_picker/country_picker.dart';
import 'app_localizations.dart';
import 'db/database_helper.dart';
import 'otp_screen.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();

  String _email = '';
  String _phone = '';
  String _password = '';
  DateTime? _birthDate;
  int? _age;
  String? _nationality;
  String? _profession;
  String? _timeOutside;
  String? _otherInfo;
  bool _isWorking = false;

  bool _isLoading = false;

  void _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    _age = age;
  }

  void _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      if (_birthDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('enter_birth_date'))),
        );
        return;
      }

      _calculateAge(_birthDate!);

      setState(() {
        _isLoading = true;
      });

      try {
        final formattedBirthDate = DateFormat('yyyy-MM-dd').format(_birthDate!);

        final response = await dbHelper.registerUser(
          email: _email,
          password: _password,
          phone: _phone,
          birthDate: _birthDate!,
          nationality: _nationality ?? '',
          profession: _profession ?? '',
          durationOutside: _timeOutside ?? '',
          additionalInfo: _otherInfo ?? '',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Registration successful')),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationPage(
              email: _email,
              password: _password,
              phone: _phone,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Color labelColor = Colors.black}) {
    return InputDecoration(
      labelText: AppLocalizations.of(context).translate(label),
      prefixIcon: Icon(icon, color: labelColor),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      labelStyle: TextStyle(color: labelColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('mother_account'), style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF6A4C9C),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/art5.gif', fit: BoxFit.cover),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeaderText(),
                  SizedBox(height: 20),
                  _buildTextField(
                    label: 'email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (val) => _email = val!,
                    labelColor: Color(0xFF5C4B8A),
                  ),
                  _buildPhoneField(),
                  _buildTextField(
                    label: 'password',
                    icon: Icons.lock,
                    obscureText: true,
                    onSaved: (val) => _password = val!,
                    labelColor: Color(0xFF5C4B8A),
                  ),
                  _buildDatePicker(),
                  _buildNationalityPicker(),
                  _buildWorkStatusDropdown(),
                  if (_isWorking) _buildTextField(
                    label: 'profession',
                    icon: Icons.work_outline,
                    onSaved: (val) => _profession = val!,
                    labelColor: Color(0xFF5C4B8A),
                  ),
                  _buildTextField(
                    label: 'time_outside',
                    icon: Icons.timer,
                    onSaved: (val) => _timeOutside = val!,
                    labelColor: Color(0xFF5C4B8A),
                  ),
                  _buildTextField(
                    label: 'other_info',
                    icon: Icons.info_outline,
                    onSaved: (val) => _otherInfo = val!,
                    labelColor: Color(0xFF5C4B8A),
                  ),
                  SizedBox(height: 20),
                  _buildRegisterButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context).translate('welcome_to_mother_account'),
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF3C2A8A), fontFamily: 'CuteFont'),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          AppLocalizations.of(context).translate('mother_account_info') ?? '',
          style: TextStyle(fontSize: 18, color: Color(0xFF5C4B8A), fontFamily: 'CuteFont'),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: IntlPhoneField(
        decoration: _inputDecoration('phone', Icons.phone, labelColor: Color(0xFF5C4B8A)),
        initialCountryCode: 'TN',
        onChanged: (phone) {
          _phone = phone.completeNumber;
        },
        style: TextStyle(color: Colors.black), // phone number text
        dropdownTextStyle: TextStyle(color: Colors.black), // country code text
      ),
    );
  }


  Widget _buildTextField({
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    required void Function(String?) onSaved,
    Color labelColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        decoration: _inputDecoration(label, icon, labelColor: labelColor),
        obscureText: obscureText,
        keyboardType: keyboardType,
        onSaved: onSaved,
        validator: (value) =>
        value == null || value.isEmpty ? AppLocalizations.of(context).translate('enter_$label') : null,
        style: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(1995),
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() => _birthDate = picked);
          }
        },
        child: InputDecorator(
          decoration: _inputDecoration('birth_date', Icons.cake, labelColor: Color(0xFF5C4B8A)),
          child: Row(
            children: [

              SizedBox(width: 10),
              Text(
                _birthDate != null
                    ? DateFormat('yyyy-MM-dd').format(_birthDate!)
                    : AppLocalizations.of(context).translate('select_birth_date'),
                style: TextStyle(fontSize: 16, color: _birthDate != null ? Colors.black : Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNationalityPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: false,
            onSelect: (Country country) {
              setState(() {
                _nationality = '${country.flagEmoji} ${country.name}';
              });
            },
          );
        },
        child: InputDecorator(
          decoration: _inputDecoration('nationality', Icons.public, labelColor: Color(0xFF5C4B8A)),
          child: Row(
            children: [

              SizedBox(width: 10),
              Text(
                _nationality ?? AppLocalizations.of(context).translate('select_nationality'),
                style: TextStyle(fontSize: 16, color: _nationality != null ? Colors.black : Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildWorkStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<bool>(
        decoration: InputDecoration(

          labelStyle: TextStyle(color: Color(0xFF5C4B8A)), // Dark purple label color
          filled: true,
          fillColor: Colors.white, // White background
          prefixIcon: Icon(Icons.work, color: Color(0xFF5C4B8A)), // Dark purple icon
        ),
        value: _isWorking,
        onChanged: (bool? value) {
          setState(() {
            _isWorking = value!;
          });
        },
        items: [
          DropdownMenuItem(
            child: Container(

              child: Text(
                AppLocalizations.of(context).translate('employed'),
                style: TextStyle(color: Color(0xFF5C4B8A)), // Dark purple text color
              ),
            ),
            value: true,
          ),
          DropdownMenuItem(
            child: Container(
              child: Text(
                AppLocalizations.of(context).translate('unemployed'),
                style: TextStyle(color: Color(0xFF5C4B8A)), // Dark purple text color
              ),
            ),
            value: false,
          ),
        ],
        validator: (value) => value == null ? AppLocalizations.of(context).translate('select_working_status') : null,
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF6A4C9C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      ),
      onPressed: _register,
      child: _isLoading
          ? CircularProgressIndicator(color: Colors.white)
          : Text(AppLocalizations.of(context).translate('register'), style: TextStyle(fontSize: 18)),
    );
  }
}
