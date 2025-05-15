import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';


class AddBabiesPage extends StatefulWidget {
  @override
  _AddBabiesPageState createState() => _AddBabiesPageState();
}

class _AddBabiesPageState extends State<AddBabiesPage> {
  List<Baby> _babies = [];
  final String serverIp = 'http://192.168.1.10:5000';

  @override
  void initState() {
    super.initState();
    _loadBabies();
  }

  Future<int?> getMotherId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('mother_id');
  }

  Future<String?> _getProfilePictureUrl(String babyId) async {
    final response = await http.get(Uri.parse('$serverIp/get_baby_profile/$babyId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final profileUrl = data['profile_picture_url'];
      if (profileUrl != null && profileUrl.toString().isNotEmpty) {
        return '$serverIp$profileUrl?ts=${DateTime.now().millisecondsSinceEpoch}';
      }
    }
    return null;
  }

  Future<void> _loadBabies() async {
    final motherId = await getMotherId();
    if (motherId == null) {
      print("Mother ID not found");
      return;
    }

    final response = await http.get(Uri.parse('$serverIp/get_babies_by_mother/$motherId'));

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

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!.translate;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/hello2.jpeg',
              fit: BoxFit.cover,
            ),
          ),
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
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.white],
                  ).createShader(bounds),
                  child: Text(
                    tr("add_baby"),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_babies.isEmpty)
                  Text(
                    tr("no_babies_found"),
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  ..._babies.map((baby) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Color(0xFFF3E8FF),
                      elevation: 6,
                      shadowColor: Colors.purple.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          leading: FutureBuilder<String?>(
                            future: _getProfilePictureUrl(baby.id.toString()),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.deepPurple[200],
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }

                              final profileImageUrl = snapshot.data;
                              return CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.deepPurple[200],
                                backgroundImage: profileImageUrl != null
                                    ? NetworkImage(profileImageUrl)
                                    : null,
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
                              '${tr("age")}: ${baby.age}\n${tr("nationality")}: ${baby.nationality}',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.deepPurple[400],
                              ),
                            ),
                          ),
                          onTap: () async {
                            final shouldRefresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BabyProfilePage(
                                  babyId: baby.id,
                                  firstName: baby.firstName,
                                  lastName: baby.lastName,
                                  age: baby.age,
                                  nationality: baby.nationality,
                                  healthStatus: baby.healthStatus,
                                ),
                              ),
                            );

                            if (shouldRefresh == true) {
                              _loadBabies();
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => BabyCreationDialog(
              onBabyAdded: () {
                _loadBabies();
              },
            ),
          );
        },
        icon: Icon(Icons.add),
        label: Text(tr("baby")),
        backgroundColor: Colors.purple[900],
      ),
    );
  }
}



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

class BabyProfilePage extends StatefulWidget {
  final String babyId;
  final String firstName;
  final String lastName;
  final String age;
  final String nationality;
  final String healthStatus;

  BabyProfilePage({
    required this.babyId,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.nationality,
    required this.healthStatus,
  });

  @override
  _BabyProfilePageState createState() => _BabyProfilePageState();
}

class _BabyProfilePageState extends State<BabyProfilePage> {
  String? _profileImageUrl;
  final String serverIp = 'http://192.168.1.10:5000';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final response = await http.get(Uri.parse('$serverIp/get_baby_profile/${widget.babyId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final profileUrl = data['profile_picture_url'];
          if (profileUrl != null && profileUrl.toString().isNotEmpty) {
            _profileImageUrl = '$serverIp$profileUrl?ts=${DateTime.now().millisecondsSinceEpoch}';
          } else {
            _profileImageUrl = null;
          }
        });
      }
    } catch (e) {
      print("Failed to load profile data: $e");
    }
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$serverIp/update_profile_picture/${widget.babyId}'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));
    final response = await request.send();

    if (response.statusCode == 200) {
      await response.stream.bytesToString(); // Ensure server finished
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("profilePictureUpdated"))),
      );
      await _loadProfileData(); // Refresh image
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("profilePictureFailed"))),
      );
    }
  }

  Future<void> _deleteProfile() async {
    final response = await http.delete(Uri.parse('$serverIp/delete_baby/${widget.babyId}'));
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("profileDeleted"))),
      );
      Navigator.pop(context, true); // Signal parent to refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("profileDeleteFailed"))),
      );
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate("deleteProfile")),
        content: Text(AppLocalizations.of(context)!.translate("deleteProfileConfirm")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate("cancel")),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deleteProfile();
            },
            child: Text(AppLocalizations.of(context)!.translate("delete")),
          ),
        ],
      ),
    );
  }

  void _showModifyDialog() {
    final firstNameController = TextEditingController(text: widget.firstName);
    final lastNameController = TextEditingController(text: widget.lastName);
    final ageController = TextEditingController(text: widget.age);
    final nationalityController = TextEditingController(text: widget.nationality);
    final healthStatusController = TextEditingController(text: widget.healthStatus);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate("modify_profile")),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate("first_name"),
                ),
              ),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate("last_name"),
                ),
              ),
              TextField(
                controller: ageController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate("age"),
                ),
              ),
              TextField(
                controller: nationalityController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate("nationality"),
                ),
              ),
              TextField(
                controller: healthStatusController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate("health_status"),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate("cancel")),
          ),
          TextButton(
            onPressed: () async {
              final updatedData = {
                'first_name': firstNameController.text,
                'last_name': lastNameController.text,
                'age': ageController.text,
                'nationality': nationalityController.text,
                'health_status': healthStatusController.text,
              };

              final response = await http.put(
                Uri.parse('$serverIp/update_baby/${widget.babyId}'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(updatedData),
              );

              if (response.statusCode == 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.translate("profile_updated")),
                  ),
                );
                Navigator.pop(context); // Close dialog
                await _loadProfileData(); // Refresh local state
                Navigator.pop(context, true); // Notify parent
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.translate("profile_update_failed")),
                  ),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.translate("save_changes")),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/art5.gif', fit: BoxFit.cover),
          ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context, true), // Signal parent to refresh
                ),
                Expanded(
                  child: Text(
                    "${AppLocalizations.of(context)!.translate("profileTitle")}: ${widget.firstName} ${widget.lastName}",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.photo_album, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AlbumPage(babyId: widget.babyId)),
                    );
                  },
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0, left: 20, right: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.shade100,
                      blurRadius: 18,
                      spreadRadius: 8,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _updateProfilePicture,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.deepPurple[300],
                        backgroundImage: _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!, headers: {'Cache-Control': 'no-cache'})
                            : null,
                        child: _profileImageUrl == null
                            ? Text(widget.firstName[0], style: TextStyle(fontSize: 36, color: Colors.white))
                            : null,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '${widget.firstName} ${widget.lastName}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple[800]),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '${AppLocalizations.of(context)!.translate("age")}: ${widget.age}',
                      style: TextStyle(fontSize: 16, color: Colors.deepPurple[600]),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${AppLocalizations.of(context)!.translate("nationality")}: ${widget.nationality}',
                      style: TextStyle(fontSize: 16, color: Colors.deepPurple[600]),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${AppLocalizations.of(context)!.translate("baby_health")}: ${widget.healthStatus}',
                      style: TextStyle(fontSize: 16, color: Colors.deepPurple[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'edit',
            onPressed: _showModifyDialog,
            backgroundColor: Colors.deepPurple[900],
            child: Icon(Icons.edit, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.translate("modify_profile"),
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'delete',
            onPressed: _showDeleteDialog,
            backgroundColor: Colors.deepPurple[900],
            child: Icon(Icons.delete_forever, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.translate("delete_profile"),
          ),
        ],
      ),
    );
  }

}


class BabyCreationDialog extends StatefulWidget {
  final VoidCallback onBabyAdded;

  const BabyCreationDialog({required this.onBabyAdded, super.key});

  @override
  _BabyCreationDialogState createState() => _BabyCreationDialogState();
}

class _BabyCreationDialogState extends State<BabyCreationDialog> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();

  String ageUnit = 'Months';
  String? selectedHealthStatus;

  final List<String> healthStatuses = [
    'Healthy',
    'Underweight',
    'Overweight',
    'Sick',
    'Premature',
    'Disabled',
    'Other'
  ];

  Future<int?> getMotherId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('mother_id');
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      backgroundColor: const Color(0xFFEDE7F6), // Soft calm purple
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add New Baby',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A148C), // Dark purple
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: firstNameController,
                style: const TextStyle(color: Color(0xFF4A148C)),
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(color: Color(0xFF4A148C)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastNameController,
                style: const TextStyle(color: Color(0xFF4A148C)),
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(color: Color(0xFF4A148C)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF4A148C)),
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        labelStyle: TextStyle(color: Color(0xFF4A148C)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: ageUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        labelStyle: TextStyle(color: Color(0xFF4A148C)),
                        border: OutlineInputBorder(),
                      ),
                      items: ['Months', 'Years'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: const TextStyle(color: Color(0xFF4A148C))),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          ageUnit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nationalityController,
                readOnly: true,
                style: const TextStyle(color: Color(0xFF4A148C)),
                decoration: const InputDecoration(
                  labelText: 'Nationality',
                  labelStyle: TextStyle(color: Color(0xFF4A148C)),
                  border: OutlineInputBorder(),
                  suffixIcon:
                  Icon(Icons.arrow_drop_down, color: Color(0xFF4A148C)),
                ),
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: false,
                    onSelect: (Country country) {
                      nationalityController.text =
                      '${country.flagEmoji} ${country.name}';
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedHealthStatus,
                decoration: const InputDecoration(
                  labelText: 'Health Status',
                  labelStyle: TextStyle(color: Color(0xFF4A148C)),
                  border: OutlineInputBorder(),
                ),
                items: healthStatuses.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status,
                        style: const TextStyle(color: Color(0xFF4A148C))),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedHealthStatus = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF4A148C))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A148C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final motherId = await getMotherId();
                      if (motherId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Mother ID not found. Please login again.')),
                        );
                        return;
                      }

                      final int age = int.tryParse(ageController.text) ?? 0;
                      final body = jsonEncode({
                        "first_name": firstNameController.text,
                        "last_name": lastNameController.text,
                        "age": age,
                        "age_unit": ageUnit,
                        "nationality": nationalityController.text,
                        "health_status": selectedHealthStatus ?? '',
                        "mother_id": motherId,
                      });

                      final response = await http.post(
                        Uri.parse("http://192.168.1.10:5000/add_baby"),
                        headers: {"Content-Type": "application/json"},
                        body: body,
                      );

                      if (response.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Baby added successfully!')),
                        );
                        widget.onBabyAdded(); // callback
                        Navigator.of(context).pop(); // close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddBabiesPage()),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add baby.')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  class AlbumPage extends StatefulWidget {
  final String babyId;

  AlbumPage({required this.babyId});

  @override
  _AlbumPageState createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _images = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.10:5000/get_pictures?baby_id=${widget.babyId}'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _images = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.1.10:5000/upload_picture'),
    );
    request.fields['baby_id'] = widget.babyId;
    request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

    final response = await request.send();
    setState(() => _isLoading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image added!'), backgroundColor: Colors.deepPurple),
      );
      _fetchImages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.purple[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            Center(
              child: Text(
                "Add Image",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.deepPurple),
              title: Text("Take a photo", style: TextStyle(color: Colors.deepPurple)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.deepPurple),
              title: Text("Choose from gallery", style: TextStyle(color: Colors.deepPurple)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDetail(String imageUrl, String date) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black,
              ),
              child: SingleChildScrollView(  // Added SingleChildScrollView here
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(imageUrl),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Added on: $date",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      label: Text("Close"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      appBar: AppBar(
        title: Text('Baby Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.deepPurple[200],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple[200]))
          : _images.isEmpty
          ? Center(
        child: Text('No images yet.', style: TextStyle(color: Colors.deepPurple, fontSize: 16)),
      )
          : SingleChildScrollView( // Wrap the Column in SingleChildScrollView
        child: Column( // Column used to arrange widgets vertically
          children: [
            GridView.builder(
              padding: const EdgeInsets.all(12),
              shrinkWrap: true, // Allows GridView to take as much space as needed
              physics: NeverScrollableScrollPhysics(), // Disable scrolling within the GridView itself
              itemCount: _images.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final image = _images[index];
                return GestureDetector(
                  onTap: () => _showImageDetail(image['url'], image['date']),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(image['url'], fit: BoxFit.cover),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        color: Colors.black45,
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.parse(image['date'])),
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addImage',
        backgroundColor: Colors.deepPurple[200],
        onPressed: _showImagePickerOptions,
        child: Icon(Icons.add_a_photo),
        tooltip: 'Add an image',
      ),
    );
  }
}



