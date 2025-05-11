import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ChooseBabyPage.dart';
import 'add_babies.dart'; // Make sure this file exists
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';

import 'mother_profile_page.dart';

class CryAnalysisPage extends StatefulWidget {
  final Map<String, dynamic> userInfo;


  CryAnalysisPage({required this.userInfo});

  @override
  _CryAnalysisPageState createState() => _CryAnalysisPageState();
}

class _CryAnalysisPageState extends State<CryAnalysisPage> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  String? _connectedBabyId;
  String? _babyName;
  String? _babyProfilePictureUrl;


  bool _showDrawer = false;

  bool _isRecording = false;
  bool _isPlaying = false;
  String _recordingPath = '';
  String _predictionResult = '';
  String? _selectedBabyId; // Add this to store selected baby id

  @override
  void initState() {
    super.initState();
    _init();
    _loadConnectedBabyDetails();
  }
  Future<String?> _getConnectedBabyId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('connected_baby_id');
  }
  Future<void> _loadConnectedBabyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _connectedBabyId = prefs.getString('connected_baby_id');
    });

    if (_connectedBabyId != null) {
      _getBabyDetails(_connectedBabyId!);
    }
  }
  // Function to fetch baby details (name and profile picture)
  Future<void> _getBabyDetails(String babyId) async {
    final response = await http.get(Uri.parse('http://192.168.1.10:5000/get_baby_details/$babyId'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        _babyName = '${data['first_name']} ${data['last_name']}';
        _babyProfilePictureUrl = 'http://192.168.1.10:5000${data['profile_picture_url']}';
      });
    } else {
      print('Failed to load baby details: ${response.body}');
    }
  }
  Map<String, Map<String, String>> _predictionMessages = {
    "hungry": {
      "message": "Your baby might be hungry",
      "emoji": "🍼"
    },
    "tired": {
      "message": "Your baby might be tired",
      "emoji": "😴"
    },
    "belly_pain": {
      "message": "Your baby may have belly pain",
      "emoji": "🤕"
    },
    "discomfort": {
      "message": "Your baby feels discomfort",
      "emoji": "😣"
    },
    "burping": {
      "message": "Your baby might need to burp",
      "emoji": "🤭"
    }
  };

  Future<void> _init() async {
    await _audioRecorder.openRecorder();
    await _audioPlayer.openPlayer();
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _pickWavFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _recordingPath = result.files.single.path!;
      });
    }
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.isDenied) {
      await _requestPermissions();
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '${dir.path}/cry_record.aac';

    await _audioRecorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.aacADTS, // ✅ Compatible partout
    );

    setState(() => _isRecording = true);
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _savePredictionToBackend(String prediction, String audioPath) async {
    // Retrieve the connected baby ID from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final babyId = prefs.getString('connected_baby_id');  // Getting the saved baby ID

    // Ensure the connected baby ID is valid before sending the request
    if (babyId == null) {
      print('❌ No baby connected. Cannot save prediction.');
      return;
    }

    final timestamp = DateTime.now().toIso8601String();  // Current timestamp

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.10:5000/save_prediction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'baby_id': babyId,  // Sending the connected baby ID
          'audio_path': audioPath,  // Path to the recorded audio
          'prediction': prediction,  // The predicted classification
          'timestamp': timestamp,  // The timestamp when the prediction was made
        }),
      );

      if (response.statusCode == 200) {
        print('Prediction and audio saved ✅');
      } else {
        print('❌ Error saving prediction: ${response.body}');
      }
    } catch (e) {
      print('❌ Error saving prediction: $e');
    }
  }


  Future<void> _stopRecording() async {
    await _audioRecorder.stopRecorder();
    setState(() => _isRecording = false);
  }

  Future<void> _startPlaying() async {
    await _audioPlayer.startPlayer(
      fromURI: _recordingPath,
      whenFinished: () => setState(() => _isPlaying = false),
    );
    setState(() => _isPlaying = true);
  }

  Future<void> _stopPlaying() async {
    await _audioPlayer.stopPlayer();
    setState(() => _isPlaying = false);
  }

  Future<void> _sendToApi() async {
    try {
      var uri = Uri.parse('http://192.168.1.10:5000/predict');
      var request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _recordingPath,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseBody);
        String predictedCry = jsonResponse['prediction'];

        String message = _predictionMessages[predictedCry]?['message'] ??
            "Unknown cry";
        String emoji = _predictionMessages[predictedCry]?['emoji'] ?? "🔍";

        setState(() {
          _predictionResult = "$emoji  $message";
        });

        // Save prediction to backend
        await _savePredictionToBackend(predictedCry, _recordingPath);
      } else {
        setState(() => _predictionResult = 'Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _predictionResult = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background GIF
        Positioned.fill(
          child: Image.asset(
            'assets/hello2.jpeg',
            fit: BoxFit.cover,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              "Cry Analysis",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black54,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                tooltip: 'Open tools',
                onPressed: () {
                  setState(() {
                    _showDrawer = !_showDrawer;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.child_care, color: Colors.white),
                tooltip: 'Choose a Baby',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChooseBabyPage()),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
          ),

          body: SingleChildScrollView(
            child: SlideInUp(
              duration: Duration(milliseconds: 700),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.1), Colors.purple.shade50.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Record & Upload (redesigned)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Record Button
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: _isRecording ? _stopRecording : _startRecording,
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.blueGrey, Colors.blueGrey],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blueGrey.withOpacity(0.4),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isRecording ? Icons.stop : Icons.mic,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  _isRecording ? "Recording..." : "Record",
                                  style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),

                            // Upload Button (now circular + icon only)
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickWavFile,
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.blueGrey, Colors.blueGrey],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blueGrey.withOpacity(0.4),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.file_upload,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Upload Audio",
                                  style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 25),

                        // Playback Button
                        GestureDetector(
                          onTap: _isPlaying ? _stopPlaying : _startPlaying,
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Colors.blueGrey, Colors.blueGrey],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.stop : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                _isPlaying ? "Playing..." : "Play",
                                style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 25),

                        // Analyze Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            elevation: 8,
                          ),
                          icon: Icon(Icons.analytics, color: Colors.white),
                          label: Text(
                            "Analyze Cry",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _sendToApi,
                        ),

                        SizedBox(height: 20),

                        if (_recordingPath.isNotEmpty)
                          Text(
                            "File: ${_recordingPath.split('/').last}",
                            style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                          ),

                        SizedBox(height: 20),

                        // Prediction Result
                        if (_predictionResult.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey,
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [

                                Text(
                                  _predictionResult,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blueGrey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        ),
            if (_showDrawer)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: MediaQuery.of(context).size.width * 0.65,
            child: GestureDetector(
              onTap: () {
                setState(() => _showDrawer = false);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Tools",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
                            // Add Baby Button
                            ListTile(
                              leading: Icon(Icons.add_circle, color: Colors.white),
                              title: Text(
                                "Add Baby",
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddBabiesPage()),
                                );
                              },
                            ),
                            // Mother Profile Button
                            ListTile(
                              leading: Icon(Icons.account_circle, color: Colors.white),
                              title: Text(
                                "Mother Profile",
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () async {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                int? motherId = prefs.getInt('mother_id');

                                if (motherId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MotherProfilePage(motherId: motherId),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Mother not logged in."),
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(height: 20),
                            ListTile(
                              leading: Icon(Icons.insert_chart, color: Colors.white),
                              title: Text("Baby Health", style: TextStyle(color: Colors.white)),
                              onTap: () {
                                // Navigate to the resultsPredicted page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BabyHealthApp(babyId: int.parse(_connectedBabyId!)),
                                  ),
                                );


                              },
                            ),
                            SizedBox(height: 20),
                            ListTile(
                              leading: Icon(Icons.insert_chart, color: Colors.white),
                              title: Text("Cry Stats", style: TextStyle(color: Colors.white)),
                              onTap: () {
                                // Navigate to the resultsPredicted page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ResultsPredictedPage()), // Replace with your results page
                                );
                              },
                            ),

                            ListTile(
                              leading: Icon(Icons.logout, color: Colors.white),
                              title: Text("Log out", style: TextStyle(color: Colors.white)),
                              onTap: () async {
                                // Call the logout method
                                await logout();
                              },
                            ),
                            Spacer(),

                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

      ],
    );
  }
}

class ResultsPredictedPage extends StatefulWidget {
  @override
  _ResultsPredictedPageState createState() => _ResultsPredictedPageState();
}

class _ResultsPredictedPageState extends State<ResultsPredictedPage> {
  Map<String, int> cryStats = {
    'hungry': 0,
    'tired': 0,
    'belly_pain': 0,
    'burping': 0,
    'discomfort': 0,
  };

  bool _isLoading = true;
  String _errorMessage = '';
  String? _connectedBabyId;
  String? _babyName;

  @override
  void initState() {
    super.initState();
    _loadConnectedBabyDetails();
  }

  Future<void> _loadConnectedBabyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _connectedBabyId = prefs.getString('connected_baby_id');

    if (_connectedBabyId != null) {
      await _fetchBabyName(_connectedBabyId!);
      await _fetchCryStats(_connectedBabyId!);
    } else {
      setState(() {
        _errorMessage = 'No baby selected. Please select a baby first.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBabyName(String babyId) async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.10:5000/get-baby/$babyId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _babyName = "${data['first_name']}${data['last_name']}";
        });
      } else {
        setState(() {
          _babyName = 'Unknown';
        });
      }
    } catch (e) {
      setState(() {
        _babyName = 'Error fetching name';
      });
    }
  }

  Future<void> _fetchCryStats(String babyId) async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.10:5000/get_cry_stats/$babyId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['stats'] != null) {
          setState(() {
            cryStats = Map<String, int>.from(data['stats']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'No cry statistics available.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load data.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Color _getColorForCryType(String cryType) {
    switch (cryType) {
      case 'hungry':
        return Colors.redAccent;
      case 'tired':
        return Colors.blueAccent;
      case 'belly_pain':
        return Colors.orangeAccent;
      case 'burping':
        return Colors.greenAccent;
      case 'discomfort':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  List<BarChartGroupData> _generateBarChartData() {
    List<BarChartGroupData> barData = [];
    int index = 0;

    cryStats.forEach((key, value) {
      barData.add(
        BarChartGroupData(
          x: index++,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              width: 20,
              color: _getColorForCryType(key),
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    });

    return barData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("Cry Statistics"),
        backgroundColor: Colors.grey[900],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cry Summary for Baby ${_babyName ?? ""}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cryStats.entries.map((entry) {
                return _buildCryStatCard(entry.key, entry.value);
              }).toList(),
            ),
            SizedBox(height: 30),
            Text(
              "Visual Chart of Predictions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 250, child: _buildBarChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildCryStatCard(String cryType, int count) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: _getColorForCryType(cryType).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColorForCryType(cryType), width: 1.2),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            cryType.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            "$count times",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final barData = _generateBarChartData();
    return BarChart(
      BarChartData(
        maxY: cryStats.values.reduce((a, b) => a > b ? a : b).toDouble() + 2,
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) => Text(value.toInt().toString()))),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                final cryType = cryStats.keys.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    cryType.replaceAll('_', '\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barData,
      ),
    );
  }
}
class BabyHealthApp extends StatelessWidget {
  final int babyId;
  const BabyHealthApp({super.key, required this.babyId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Health Tracker',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: HomePage(babyId: babyId),
    );
  }
}

class BabyHealthData {
  final double height;
  final double weight;
  final double temperature;
  final String vaccination;

  BabyHealthData({
    required this.height,
    required this.weight,
    required this.temperature,
    required this.vaccination,
  });

  Map<String, dynamic> toJson() => {
    'height': height,
    'weight': weight,
    'temperature': temperature,
    'vaccination': vaccination,
  };

  factory BabyHealthData.fromJson(Map<String, dynamic> json) {
    return BabyHealthData(
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      vaccination: json['vaccination'],
    );
  }
}

class HealthStorage {
  Future<void> saveData(int babyId, BabyHealthData data) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('health_$babyId', jsonEncode(data.toJson()));
  }

  Future<BabyHealthData?> loadData(int babyId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('health_$babyId');
    if (jsonString == null) return null;
    return BabyHealthData.fromJson(jsonDecode(jsonString));
  }
}

class HomePage extends StatelessWidget {
  final int babyId;
  const HomePage({super.key, required this.babyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Baby Health Tracker")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Enter Health Data"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InputPage(babyId: babyId),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("View Statistics"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsPage(babyId: babyId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class InputPage extends StatefulWidget {
  final int babyId;
  const InputPage({super.key, required this.babyId});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _vaccinationController = TextEditingController();

  void _saveData() async {
    if (_formKey.currentState!.validate()) {
      final data = BabyHealthData(
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        temperature: double.parse(_temperatureController.text),
        vaccination: _vaccinationController.text,
      );
      await HealthStorage().saveData(widget.babyId, data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data saved successfully!")),
      );
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _temperatureController.dispose();
    _vaccinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Baby Health Data")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Height (cm)"),
                validator: (value) => value!.isEmpty ? "Enter height" : null,
              ),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Weight (kg)"),
                validator: (value) => value!.isEmpty ? "Enter weight" : null,
              ),
              TextFormField(
                controller: _temperatureController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Temperature (°C)"),
                validator: (value) => value!.isEmpty ? "Enter temperature" : null,
              ),
              TextFormField(
                controller: _vaccinationController,
                decoration: const InputDecoration(labelText: "Vaccination info"),
                validator: (value) => value!.isEmpty ? "Enter vaccination info" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveData,
                child: const Text("Save"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class StatsPage extends StatelessWidget {
  final int babyId;
  const StatsPage({super.key, required this.babyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Health Statistics")),
      body: FutureBuilder<BabyHealthData?>(
        future: HealthStorage().loadData(babyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text("No data available"));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Height: ${data.height} cm", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text("Weight: ${data.weight} kg", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text("Temperature: ${data.temperature} °C", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text("Vaccination Info: ${data.vaccination}", style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        },
      ),
    );
  }
}

