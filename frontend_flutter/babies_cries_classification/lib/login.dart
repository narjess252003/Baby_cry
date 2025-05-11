import 'package:flutter/material.dart';
import 'package:babies_cries_classification/db/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'CryAnalysisPage.dart';
import 'app_localizations.dart'; // Import the localization helper

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? userInfo;
  final dbHelper = DatabaseHelper();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
  // Function to save the mother's ID in SharedPreferences
  Future<void> saveMotherId(int motherId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('mother_id', motherId); // Store the mother's ID as 'mother_id'
  }

  // Function to get the mother's ID from SharedPreferences
  Future<int?> getMotherId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('mother_id'); // Retrieve the mother's ID as 'mother_id'
  }
  void _login() async {
    // Get email and password input from the controllers
    final email = emailController.text;
    final password = passwordController.text;

    // Check if either email or password is null or empty
    if (email.isEmpty || password.isEmpty) {
      // Handle invalid input, e.g., show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email and password cannot be empty')),
      );
      return;
    }

    try {
      // Call login function in DB helper to check credentials
      final response = await dbHelper.loginUser(email, password);

      // Check if the response contains the expected fields
      if (response.containsKey('user') && response['user'] != null) {
        // Successfully logged in, navigate to CryAnalysisPage with user info
        int motherId = response['user']['id']; // Assuming the response contains the 'id' column
        await saveMotherId(motherId); // Save
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CryAnalysisPage(userInfo: response['user']),
          ),
        );
      } else {
        // Handle the case where 'user' is not found in the response
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed, user not found')),
        );
      }
    } catch (error) {
      // Handle the error case
      print("Error: $error");

      // Display error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during login')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('login')), // Traduction du titre
        backgroundColor: Color(0xFF6A4C9C), // Couleur pour l'AppBar
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/art5.gif', // Chemin vers le fichier GIF
              fit: BoxFit.cover, // S'assure que l'image couvre tout l'écran
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeaderText(),
                    SizedBox(height: 20),
                    _buildTextField(
                      label: 'email',
                      icon: Icons.email,
                      controller: emailController,
                    ),
                    _buildTextField(
                      label: 'password',
                      icon: Icons.lock,
                      controller: passwordController,
                      obscureText: true,
                    ),
                    SizedBox(height: 20),
                    _buildLoginButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscureText = false,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).translate(label),
          prefixIcon: Icon(icon),
          labelStyle: TextStyle(color: Color(0xFF5C4B8A)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFF6A4C9C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFF5C4B8A)),
          ),
        ),
        obscureText: obscureText,
        validator: (value) => value == null || value.isEmpty
            ? AppLocalizations.of(context).translate('enter_$label') // Validation avec message localisé
            : null,
        style: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context).translate('login'), // Texte de bienvenue
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF3C2A8A)),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A4C9C), Color(0xFF5C4B8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF5C4B8A).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _login, // Appel à la fonction de connexion
        child: Text(AppLocalizations.of(context).translate('login')), // Texte du bouton
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Color(0xFF5C4B8A), width: 2),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
