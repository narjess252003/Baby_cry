import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class MotherInfo {
  final int id;
  final String email;
  final String phoneNumber;
  final String dateOfBirth;
  final int age;
  final String nationality;
  final String jobStatus;
  final String jobTitle;
  final String timeOutsideHome;
  final String additionalInfo;
  final String? profileImagePath;

  MotherInfo({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.age,
    required this.nationality,
    required this.jobStatus,
    required this.jobTitle,
    required this.timeOutsideHome,
    required this.additionalInfo,
    this.profileImagePath,
  });

  factory MotherInfo.fromJson(Map<String, dynamic> json) {
    return MotherInfo(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      dateOfBirth: json['date_of_birth'] ?? '',
      age: json['age'] ?? 0,
      nationality: json['nationality'] ?? '',
      jobStatus: (json['job_status'] == 1) ? 'Employed' : 'Unemployed',
      jobTitle: json['job_title'] ?? '',
      timeOutsideHome: json['time_outside_home'] ?? '',
      additionalInfo: json['additional_info'] ?? '',
      profileImagePath: json['profile_picture'],
    );
  }
}
class MotherProfilePage extends StatefulWidget {
  final int motherId;

  const MotherProfilePage({Key? key, required this.motherId}) : super(key: key);

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage> with SingleTickerProviderStateMixin {
  late Future<MotherInfo?> motherInfoFuture;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    motherInfoFuture = fetchMotherProfile(widget.motherId);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _loadImagePath();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<int?> getMotherId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('mother_id');
  }

  Future<void> _loadImagePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? path = prefs.getString('profile_image');
    if (path != null) {
      setState(() {
        _profileImage = File(path);
      });
    }
  }

  Future<MotherInfo?> fetchMotherProfile(int id) async {
    final url = Uri.parse('http://192.168.1.10:5000/api/mother/$id');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MotherInfo.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.10:5000/api/mother/${widget.motherId}/upload_profile_pic'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('profile_image', pickedFile.path);

        setState(() {
          motherInfoFuture = fetchMotherProfile(widget.motherId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to upload image")));
      }
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget profileItem(String label, String value) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Mother Profile"),
        backgroundColor: const Color(0xFF6A4C9C),
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),

      ),
      body: FutureBuilder<MotherInfo?>(
        future: motherInfoFuture,  // Use motherInfoFuture for data fetching
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          } else if (snapshot.hasError) {
            return const Center(child: Text("Failed to load profile"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Profile not found"));
          } else {
            final mother = snapshot.data!;
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/art5.gif',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.black.withOpacity(0.1)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : (mother.profileImagePath != null && mother.profileImagePath!.isNotEmpty)
                                  ? NetworkImage(mother.profileImagePath!)
                                  : const AssetImage('assets/mother_avatar.png') as ImageProvider,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        profileItem("📧 Email", mother.email),
                        profileItem("📱 Phone Number", mother.phoneNumber),
                        profileItem("📅 Date of Birth", mother.dateOfBirth),
                        profileItem("🎂 Age", mother.age.toString()),
                        profileItem("🌍 Nationality", mother.nationality),
                        profileItem("👩‍💼 Job Status", mother.jobStatus),
                        profileItem("💼 Job Title", mother.jobTitle),
                        profileItem("⏰ Time Outside Home", mother.timeOutsideHome),
                        profileItem("📝 Additional Info", mother.additionalInfo),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(
                                  motherInfo: mother,
                                  motherId: mother.id,
                                ),
                              ),
                            );

                            if (result == true) {
                              setState(() {
                                motherInfoFuture = fetchMotherProfile(widget.motherId); // Refresh profile data
                              });
                            }
                          },
                          child: Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}



class EditProfilePage extends StatefulWidget {
  final MotherInfo motherInfo;
  final int motherId;

  const EditProfilePage({Key? key, required this.motherInfo, required this.motherId}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController dobController;
  late TextEditingController nationalityController;
  late TextEditingController jobStatusController;
  late TextEditingController jobTitleController;
  late TextEditingController timeOutsideHomeController;
  late TextEditingController additionalInfoController;
  late TextEditingController ageController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.motherInfo.email ?? '');
    phoneController = TextEditingController(text: widget.motherInfo.phoneNumber ?? '');
    dobController = TextEditingController(text: widget.motherInfo.dateOfBirth ?? '');
    nationalityController = TextEditingController(text: widget.motherInfo.nationality ?? '');
    jobStatusController = TextEditingController(text: widget.motherInfo.jobStatus ?? '');
    jobTitleController = TextEditingController(text: widget.motherInfo.jobTitle ?? '');
    timeOutsideHomeController = TextEditingController(text: widget.motherInfo.timeOutsideHome ?? '');
    additionalInfoController = TextEditingController(text: widget.motherInfo.additionalInfo ?? '');
    ageController = TextEditingController(text: widget.motherInfo.age.toString());
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    dobController.dispose();
    nationalityController.dispose();
    jobStatusController.dispose();
    jobTitleController.dispose();
    timeOutsideHomeController.dispose();
    additionalInfoController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Future<int?> getMotherId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('mother_id');
  }

  Future<void> updateMotherProfile() async {
    final motherId = await getMotherId();

    if (motherId == null) {
      print('Mother ID not found.');
      return;
    }

    final url = Uri.parse('http://192.168.1.10:5000/api/mother/update/$motherId');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': emailController.text,
        'phone_number': phoneController.text,
        'date_of_birth': dobController.text,
        'age': ageController.text,
        'nationality': nationalityController.text,
        'job_status': jobStatusController.text,
        'job_title': jobTitleController.text,
        'time_outside_home': timeOutsideHomeController.text,
        'additional_info': additionalInfoController.text,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MotherProfilePage(motherId: motherId)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(0.6), // Very light transparent white
        elevation: 0,
      ),
      body: Stack(
        children: [
          // GIF background
          SizedBox.expand(
            child: Image.asset(
              "assets/art5.gif",
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.white.withOpacity(0.2), // Light layer over GIF for readability
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
            child: Column(
              children: [
                _buildTextField(emailController, "Email"),
                _buildTextField(phoneController, "Phone Number"),
                _buildTextField(dobController, "Date of Birth"),
                _buildTextField(nationalityController, "Nationality"),
                _buildTextField(jobStatusController, "Job Status"),
                _buildTextField(jobTitleController, "Job Title"),
                _buildTextField(timeOutsideHomeController, "Time Outside Home"),
                _buildTextField(additionalInfoController, "Additional Info"),
                _buildTextField(ageController, "Age", keyboardType: TextInputType.number),
                const SizedBox(height: 30),
                MaterialButton(
                  onPressed: updateMotherProfile,
                  color: const Color(0xFFE1BEE7), // Light calm purple
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black87),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black26),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.deepPurpleAccent),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.7),
        ),
        keyboardType: keyboardType,
      ),
    );
  }
}
