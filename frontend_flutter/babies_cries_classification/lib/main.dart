import 'package:babies_cries_classification/register.dart';
import 'package:babies_cries_classification/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';

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
  Locale _locale = Locale('en'); // Default language

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale, // Dynamic locale
      supportedLocales: [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/welcome', // Set the initial route
      routes: {
        '/welcome': (context) => WelcomePage(),
        '/mom-baby': (context) => MomAndBabyPage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.blue[900],
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[900]!, Colors.blueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Name
              Text(
                AppLocalizations.of(context).translate('app_name'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Get Started Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/mom-baby'); // Navigate to MomAndBabyPage
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('get_started'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MomAndBabyPage extends StatefulWidget {
  @override
  _MomAndBabyPageState createState() => _MomAndBabyPageState();
}

class _MomAndBabyPageState extends State<MomAndBabyPage> {
  String _selectedLanguage = 'en'; // Default language

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[900]!, Colors.blueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Language Selector at the Top
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: DropdownButton<String>(
                value: _selectedLanguage,
                items: [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedLanguage = newValue!;
                  });
                  MyApp.of(context)!.setLocale(Locale(_selectedLanguage));
                },
                style: TextStyle(color: Colors.white, fontSize: 18),
                dropdownColor: Colors.blue[800], // Dropdown background color
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image Above Buttons
                    Image.asset(
                      'assets/images/baby.png', // Replace with your image path
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover, // Adjust to fit the layout
                    ),
                    SizedBox(height: 20),

                    // Row for Buttons (Register and Log In)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register'); // Navigate to RegisterPage
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          child: Text(
                            AppLocalizations.of(context).translate('register'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 20), // Spacing between buttons
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login'); // Navigate to LoginPage
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          child: Text(
                            AppLocalizations.of(context).translate('log_in'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
