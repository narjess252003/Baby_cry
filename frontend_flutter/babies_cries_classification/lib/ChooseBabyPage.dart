import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Baby {
  final String id;
  final String firstName;
  final String lastName;
  final String age;
  final String nationality;
  final String healthStatus;

  Baby({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.nationality,
    required this.healthStatus,
  });

  factory Baby.fromJson(Map<String, dynamic> json) {
    return Baby(
      id: json['id'].toString(),
      firstName: json['first_name'],
      lastName: json['last_name'],
      age: json['age'],
      nationality: json['nationality'],
      healthStatus: json['health_status'],
    );
  }
}

class ChooseBabyPage extends StatefulWidget {
  @override
  _ChooseBabyPageState createState() => _ChooseBabyPageState();
}

class _ChooseBabyPageState extends State<ChooseBabyPage> {
  List<Baby> _babies = [];
  final String serverIp = 'http://192.168.1.10:5000';
  String? _connectedBabyMessage;
  String? _connectedBabyId;
  String? _connectedBabyName;

  @override
  void initState() {
    super.initState();
    _loadBabies();
    _loadConnectedBabyId();
  }

  Future<int?> getMotherId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('mother_id');
  }

  // Function to fetch the profile picture URL for each baby
  Future<String?> _getProfilePictureUrl(String babyId) async {
    final response = await http.get(Uri.parse('$serverIp/get_baby_profile/$babyId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return '$serverIp${data['profile_picture_url']}';  // Assuming the API returns the relative URL for the profile image
    }
    return null;
  }

  Future<void> _loadBabies() async {
    final motherId = await getMotherId();
    if (motherId == null) {
      print("Mother ID not found");
      return;
    }

    final response = await http.get(
      Uri.parse('$serverIp/get_babies_by_mother/$motherId'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> babiesData = data['babies'];

      setState(() {
        _babies = babiesData.map((babyData) => Baby.fromJson(babyData)).toList();
      });
    } else {
      print('Failed to load babies: ${response.body}');
    }
  }

  // Load the connected baby ID from SharedPreferences
  Future<void> _loadConnectedBabyId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _connectedBabyId = prefs.getString('connected_baby_id');
    });
  }

  // Method to connect to a baby
  Future<void> _chooseBaby(String babyId) async {
    setState(() {
      _connectedBabyMessage = 'Connected to baby with ID: $babyId';
      _connectedBabyId = babyId;
    });

    // Save the connected baby ID to SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('connected_baby_id', babyId);
  }

  // Method to disconnect from a baby
  Future<void> _disconnectBaby(String babyId) async {
    setState(() {
      _connectedBabyMessage = 'Disconnected from baby with ID: $babyId';
      _connectedBabyId = null;
    });

    // Clear the connected baby ID from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('connected_baby_id');
  }

  // Method to save prediction to backend
  Future<void> _savePredictionToBackend(String prediction, String audioPath) async {
    final babyId = _connectedBabyId;
    if (babyId == null) {
      print('❌ No baby connected. Cannot save prediction.');
      return;
    }
    final timestamp = DateTime.now().toIso8601String();

    final response = await http.post(
      Uri.parse('$serverIp/save_prediction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'baby_id': babyId,
        'audio_path': audioPath,
        'prediction': prediction,
        'timestamp': timestamp,
      }),
    );

    if (response.statusCode == 200) {
      print('Prediction and audio saved ✅');
    } else {
      print('❌ Error saving prediction: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/hello2.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Custom header (replaces AppBar)
          Padding(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                ),
                SizedBox(width: 16),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      LinearGradient(
                        colors: [Colors.white, Colors.white],
                        // white to gold
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                  child: Text(
                    "Choose Baby",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Required for ShaderMask
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black26,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_babies.isEmpty)
                  Text(
                    'No babies found. Add a baby!',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  ..._babies.map((baby) {
                    bool isConnected = _connectedBabyId == baby.id;
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isConnected
                            ? BorderSide(color: Colors.green, width: 3)  // Highlight border for connected baby
                            : BorderSide.none,
                      ),
                      color: Color(0xFFF3E8FF), // Soft lavender background
                      elevation: 6,
                      shadowColor: Colors.purple.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          leading: FutureBuilder(
                            future: _getProfilePictureUrl(baby.id), // You'll need to create a function that fetches the image URL for each baby
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.deepPurple[200],
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.deepPurple[200],
                                  child: Text(
                                    baby.firstName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              final profileImageUrl = snapshot.data;
                              return CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.deepPurple[200],
                                backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                                child: profileImageUrl == null
                                    ? Text(
                                  baby.firstName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                    : null,
                              );
                            },
                          ),
                          title: Text(
                            '${baby.firstName} ${baby.lastName}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple[900],
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Age: ${baby.age}\nNationality: ${baby.nationality}',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.deepPurple[400],
                              ),
                            ),
                          ),
                          trailing: GestureDetector(
                            onTap: () {
                              if (isConnected) {
                                _disconnectBaby(baby.id);
                              } else {
                                _chooseBaby(baby.id);
                              }
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: isConnected ? Colors.green : Colors.blue,
                              child: Icon(
                                isConnected ? Icons.check : Icons.link,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
