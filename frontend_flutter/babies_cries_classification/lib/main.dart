import 'package:babies_cries_classification/register.dart';
import 'package:babies_cries_classification/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'AnimatedAppName.dart';
import 'ProfilePage.dart';
import 'add_babies.dart';
import 'app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = Locale('en'); // Default language is English

  // Function to change the app's language
  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale, // Dynamic locale
      supportedLocales: [
        Locale('en'), // English
        Locale('fr'), // French
        Locale('ar'), // Arabic
      ],
      localizationsDelegates: [
        AppLocalizations.delegate, // Ensure this delegate is properly registered
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        return supportedLocales.firstWhere(
              (supportedLocale) =>
          supportedLocale.languageCode == locale?.languageCode,
          orElse: () => Locale('en', ''),
        );
      },
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomePage(),
        '/add_babies': (context) =>AddBabiesPage(),
        '/mom-baby': (context) => MomAndBabyPage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),// Example user ID
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/profile') {
          final userId = settings.arguments as int?;
          if (userId == null) {
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: Center(child: Text("Error: Missing user ID")),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (context) => ProfilePage(userId: userId),
          );
        }
        return null;
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.blue[900],
      ),
    );
  }
}

class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String _selectedLanguage = 'en'; // Default language

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/art5.gif',
              fit: BoxFit.cover,
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedAppElements(),
                  SizedBox(height: 60),

                  // Start Button as Icon (Arrow)
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/mom-baby');
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade700,
                            Colors.blueAccent.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  SizedBox(height: 100), // To leave space before language picker
                ],
              ),
            ),
          ),

          // Language Picker (bottom of the screen)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('select_language') ?? 'Select Language:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white, // Better visibility on dark background
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black87,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  DropdownButton<String>(
                    dropdownColor: Colors.black87, // Dark dropdown background
                    value: _selectedLanguage,
                    items: ['en', 'fr', 'ar'].map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang,
                        child: Text(
                          lang == 'en' ? 'English' : lang == 'fr' ? 'Français' : 'عربي',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLanguage = newValue!;
                      });
                      MyApp.of(context)!.setLocale(Locale(_selectedLanguage));
                    },
                    underline: Container(),
                    icon: Icon(Icons.language, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}


class MomAndBabyPage extends StatefulWidget {
  @override
  _MomAndBabyPageState createState() => _MomAndBabyPageState();
}

class _MomAndBabyPageState extends State<MomAndBabyPage> {
  bool _showIntro = true;  // To control the visibility of the intro screen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background with GIF
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade700, Colors.blueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // GIF Background
            Positioned.fill(
              child: Image.asset(
                'assets/art.gif',
                fit: BoxFit.cover,
              ),
            ),
            // Content Section
            Column(
              children: [
                if (_showIntro) // Show intro screen with explanation
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Explanation window with a soft, watercolor-inspired design
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9), // Light, soft background
                            borderRadius: BorderRadius.circular(20), // Rounded corners for softness
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12, // Soft shadow for depth
                                blurRadius: 15,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Heading with a soft, flowing font and pastel color
                              Text(
                                AppLocalizations.of(context).translate('welcome') ?? 'Welcome to Baby Cries analysis App!',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6A4C9C), // Darker purple for better readability
                                  fontFamily: 'Dancing Script', // A soft, flowing script font
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 20),

                              // Description with a more readable, darker soft color
                              Text(
                                AppLocalizations.of(context).translate('description') ??
                                    'Welcome to Baby Cry App! This app is designed to help mothers understand their babies better by analyzing and classifying their cries. You can create your own account and add your baby\'s information to keep track of their health and emotions. The app will help you identify whether your baby is hungry, tired, in pain, or needs attention based on the sound of their cry. You can also monitor your baby\'s well-being over time and get valuable insights to ensure your little one is always happy and healthy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF5E4B8B), // Darker soft lavender for better readability
                                  fontFamily: 'Quicksand', // A clean, rounded font for a soft look
                                  height: 1.5, // More line height for readability
                                ),
                              ),
                              SizedBox(height: 40),

                              // Skip Intro button with a soft pastel color
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showIntro = false; // Skip the intro and show login/register buttons
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFB39DDB), // Light pastel purple for the button
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30), // Rounded corners for the button
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                  elevation: 5, // Subtle shadow for depth
                                ),
                                child: Text(
                                  AppLocalizations.of(context).translate('skip_intro') ?? 'Skip Intro',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Quicksand', // Soft, friendly font for the button
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  )
                else // After skipping, show login and register buttons
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Image
                          Image.asset(
                            'assets/mother.png',
                            width: 170,
                            height: 170,
                            fit: BoxFit.cover,
                          ),
                          SizedBox(height: 20),

                          // Buttons (Register and Log In)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white, // Text color
                                  backgroundColor: Color(0xFF9575CD), // Slightly darker purple (HEX code)
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30), // More rounded corners
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 35, vertical: 15), // More spacious padding
                                  elevation: 5, // Added shadow for a professional look
                                ),
                                child: Text(
                                  AppLocalizations.of(context).translate('register') ?? 'Register',
                                  style: TextStyle(
                                    fontSize: 18, // Bigger font size for better visibility
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Raleway', // Professional and clean font
                                    letterSpacing: 1.2, // Slight letter spacing for a more polished feel
                                  ),
                                ),
                              ),
                              SizedBox(width: 18),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/login');
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white, // Text color
                                  backgroundColor: Color(0xFF9575CD), // Slightly darker purple (HEX code)
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30), // More rounded corners
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 35, vertical: 15), // More spacious padding
                                  elevation: 5, // Added shadow for a professional look
                                ),
                                child: Text(
                                  AppLocalizations.of(context).translate('log_in') ?? 'Log In',
                                  style: TextStyle(
                                    fontSize: 18, // Bigger font size for better visibility
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Raleway', // Professional and clean font
                                    letterSpacing: 1.2, // Slight letter spacing for a more polished feel
                                  ),
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

