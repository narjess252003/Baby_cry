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

import 'app_localizations.dart';
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
  String getLocalizedMessage(String key, BuildContext context) {
    return AppLocalizations.of(context).translate('${key}_message');
  }

  String getEmoji(String key) {
    switch (key) {
      case "hungry": return "🍼";
      case "tired": return "😴";
      case "belly_pain": return "🤕";
      case "discomfort": return "😣";
      case "burping": return "🤭";
      default: return "🔍";
    }
  }


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

        String message = getLocalizedMessage(predictedCry, context);
        String emoji = getEmoji(predictedCry);

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
              AppLocalizations.of(context).translate('cry_analysis_title'),
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
                tooltip: AppLocalizations.of(context).translate('open_tools'),
                onPressed: () {
                  setState(() {
                    _showDrawer = !_showDrawer;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.child_care, color: Colors.white),
                tooltip: AppLocalizations.of(context).translate('choose_baby'),
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
                                  _isRecording
                                      ? AppLocalizations.of(context)!.translate("recording")
                                      : AppLocalizations.of(context)!.translate("record"),
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
                                  AppLocalizations.of(context)!.translate("upload_audio"),
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
                                _isPlaying
                                    ? AppLocalizations.of(context)!.translate("playing")
                                    : AppLocalizations.of(context)!.translate("play"),
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
                            AppLocalizations.of(context)!.translate("analyze_cry"),
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
                            "${AppLocalizations.of(context)!.translate("file")}: ${_recordingPath.split('/').last}",
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
                              AppLocalizations.of(context).translate('tools_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Add Baby Button
                            ListTile(
                              leading: const Icon(Icons.add_circle, color: Colors.white),
                              title: Text(
                                AppLocalizations.of(context).translate('add_baby'),
                                style: const TextStyle(color: Colors.white),
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
                              leading: const Icon(Icons.account_circle, color: Colors.white),
                              title: Text(
                                AppLocalizations.of(context).translate('mother_profile'),
                                style: const TextStyle(color: Colors.white),
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
                                      content: Text(AppLocalizations.of(context).translate('mother_not_logged_in')),
                                    ),
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 20),

                            ListTile(
                              leading: const Icon(Icons.insert_chart, color: Colors.white),
                              title: Text(
                                AppLocalizations.of(context).translate('baby_health'),
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BabyHealthInputPage(babyId: _connectedBabyId!),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            ListTile(
                              leading: const Icon(Icons.insert_chart, color: Colors.white),
                              title: Text(
                                AppLocalizations.of(context).translate('cry_stats'),
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ResultsPredictedPage()),
                                );
                              },
                            ),

                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.white),
                              title: Text(
                                AppLocalizations.of(context).translate('logout'),
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () async {
                                await logout();
                              },
                            ),

                            const Spacer(),
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

class BabyHealthInputPage extends StatefulWidget {
  final String babyId;

  BabyHealthInputPage({required this.babyId});

  @override
  _BabyHealthInputPageState createState() => _BabyHealthInputPageState();
}

class _BabyHealthInputPageState extends State<BabyHealthInputPage> {
  final _temperatureController = TextEditingController();
  final _weightController = TextEditingController();
  final _vaccineNameController = TextEditingController();
  DateTime? _vaccinationDate;
  String? _connectedBabyId;

  @override
  void initState() {
    super.initState();
    _loadConnectedBabyDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌸 Animated Watercolor Background
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/art5.gif"), // Add your GIF in assets
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🌟 Foreground Content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Card(
              color: Colors.white.withOpacity(0.85),
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "Baby Health Input",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildInputField("Temperature (°C)", _temperatureController),
                    const SizedBox(height: 16),

                    _buildInputField("Weight (kg)", _weightController),
                    const SizedBox(height: 16),

                    _buildInputField("Vaccine Name", _vaccineNameController),
                    const SizedBox(height: 16),

                    // 📅 Vaccination Date Picker
                    Row(
                      children: [
                        Icon(Icons.date_range, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text(
                          _vaccinationDate == null
                              ? 'Select Vaccination Date'
                              : 'Vaccination Date: ${_vaccinationDate!.toString().split(' ')[0]}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.calendar_today, color: Colors.deepPurple),
                          onPressed: () async {
                            DateTime? date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                _vaccinationDate = date;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 🚀 Submit Button
                    _buildAnimatedButton(
                      label: 'Submit',
                      color: Colors.blueGrey,
                      onPressed: _submitHealthData,
                    ),
                    const SizedBox(height: 12),

                    // 📊 View History Button
                    _buildAnimatedButton(
                      label: 'View Baby Health History',
                      color: Colors.deepPurpleAccent,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BabyHealthHistoryPage(babyId: widget.babyId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 💬 Text Field Builder
  Widget _buildInputField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.deepPurple.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
    );
  }

  // ✨ Animated Button Builder
  Widget _buildAnimatedButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14),
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 5,
        ),
        onPressed: onPressed,
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _loadConnectedBabyDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _connectedBabyId = prefs.getString('connected_baby_id');
  }

  Future<void> _submitHealthData() async {
    final temperature = double.tryParse(_temperatureController.text);
    final weight = double.tryParse(_weightController.text);
    final vaccineName = _vaccineNameController.text;
    final vaccinationDate = _vaccinationDate;

    if (temperature == null || weight == null || vaccineName.isEmpty || vaccinationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields correctly')));
      return;
    }

    final url = Uri.parse('http://192.168.1.10:5000/api/baby-health');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'baby_id': int.parse(widget.babyId),
        'temperature': temperature,
        'weight': weight,
        'vaccine_name': vaccineName,
        'vaccination_date': vaccinationDate.toIso8601String().split('T')[0],
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data saved successfully!')));
      _temperatureController.clear();
      _weightController.clear();
      _vaccineNameController.clear();
      setState(() {
        _vaccinationDate = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save data')));
    }
  }
}

class BabyHealthHistoryPage extends StatefulWidget {
  final String babyId;

  BabyHealthHistoryPage({required this.babyId});

  @override
  _BabyHealthHistoryPageState createState() => _BabyHealthHistoryPageState();
}

class _BabyHealthHistoryPageState extends State<BabyHealthHistoryPage> {
  late Future<Map<String, dynamic>> _healthData;
  bool _showChartView = true;

  @override
  void initState() {
    super.initState();
    _healthData = _fetchHealthData();
  }

  Future<Map<String, dynamic>> _fetchHealthData() async {
    final url = Uri.parse('http://192.168.1.10:5000/baby-health-history/${widget.babyId}');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load health data');
    }
  }

  List<FlSpot> _createSpots(List<dynamic> list, String key) {
    List<FlSpot> spots = [];
    for (int i = 0; i < list.length; i++) {
      final value = list[i][key];
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), double.tryParse(value.toString()) ?? 0.0));
      }
    }
    return spots;
  }

  List<String> _extractDates(List<dynamic> list) {
    return list.map<String>((e) => e['record_date'] ?? e['vaccination_date'] ?? "").toList();
  }

  Widget _buildLineChart(List<dynamic> list, String key, String label, Color color) {
    final spots = _createSpots(list, key);
    final dates = _extractDates(list);

    if (spots.isEmpty) return Text("No $label data available", style: TextStyle(color: Colors.white70));

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < dates.length) {
                    return Text(
                      dates[index].split("T")[0],
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    );
                  }
                  return Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.white38),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.white24, strokeWidth: 0.5),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.white24, strokeWidth: 0.5),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              gradient: LinearGradient(colors: [color, color.withOpacity(0.4)]),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: FlDotData(show: true),
              isStrokeCapRound: true,
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final date = idx < dates.length ? dates[idx].split("T")[0] : "";
                  return LineTooltipItem(
                    '$label: ${spot.y}\nDate: $date',
                    TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Text("Baby's Health History", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_showChartView ? Icons.list : Icons.show_chart, color: Colors.white),
            onPressed: () {
              setState(() {
                _showChartView = !_showChartView;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _healthData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.white));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data available', style: TextStyle(color: Colors.white)));
          } else {
            final data = snapshot.data!;
            final tempList = data['temperature'] as List<dynamic>;
            final weightList = data['weight'] as List<dynamic>;
            final vaccineList = data['vaccination'] as List<dynamic>;

            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _showChartView
                    ? [
                  Text("📈 Temperature", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  _buildLineChart(tempList, 'temperature', 'Temp (°C)', Colors.redAccent),
                  SizedBox(height: 20),
                  Text("⚖️ Weight", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  _buildLineChart(weightList, 'weight', 'Weight (kg)', Colors.greenAccent),
                ]
                    : [
                  Text("📋 Temperature Records", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ...tempList.map((entry) => ListTile(
                    tileColor: Colors.blueGrey.shade800,
                    title: Text("Temp: ${entry['temperature']} °C", style: TextStyle(color: Colors.white)),
                    subtitle: Text("Date: ${entry['record_date']}", style: TextStyle(color: Colors.white70)),
                  )),
                  Divider(color: Colors.white70),
                  Text("📋 Weight Records", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ...weightList.map((entry) => ListTile(
                    tileColor: Colors.blueGrey.shade800,
                    title: Text("Weight: ${entry['weight']} kg", style: TextStyle(color: Colors.white)),
                    subtitle: Text("Date: ${entry['record_date']}", style: TextStyle(color: Colors.white70)),
                  )),
                  Divider(color: Colors.white70),
                  Text("💉 Vaccination Records", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ...vaccineList.map((entry) => ListTile(
                    tileColor: Colors.blueGrey.shade800,
                    title: Text("Vaccine: ${entry['vaccine_name']}", style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      "Date: ${entry['vaccination_date']}, Status: ${entry['status']}",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}



