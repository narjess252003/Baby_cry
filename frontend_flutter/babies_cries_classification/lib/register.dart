import 'package:flutter/material.dart';
import 'package:babies_cries_classification/db/database_helper.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _fullName = '';
  String _password = '';
  int _age = 0;
  String _nationality = '';
  final dbHelper = DatabaseHelper(); // Updated for HTTP backend communication

  void _register() async {
    try {
      // Send registration data to the backend
      final response = await dbHelper.registerBaby(_fullName, _password, _age, _nationality);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Registration Successful!')),
      );
      Navigator.pop(context); // Navigate back to login
    } catch (e) {
      // Handle registration failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register Baby')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Full Name Field
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _fullName = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a full name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Password Field
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                onSaved: (value) => _password = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Age Field
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onSaved: (value) => _age = int.parse(value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter age';
                  }
                  return null;
                },
              ),
              SizedBox(height: 15),

              // Nationality Field
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nationality',
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _nationality = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter nationality';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Register Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _register(); // Call the register method
                  }
                },
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
