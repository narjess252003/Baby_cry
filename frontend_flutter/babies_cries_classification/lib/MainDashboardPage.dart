import 'package:flutter/material.dart';

class MainDashboardPage extends StatefulWidget {
  final int babyId;
  final Map<String, dynamic> userInfo;

  const MainDashboardPage({ required this.userInfo, required this.babyId});

  @override
  _MainDashboardPageState createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  String selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Albym Baby', style: TextStyle(color: Colors.deepPurple)),
        actions: [
          DropdownButton<String>(
            value: selectedLanguage,
            icon: Icon(Icons.language, color: Colors.deepPurple),
            underline: SizedBox(),
            dropdownColor: Colors.white,
            onChanged: (value) {
              setState(() => selectedLanguage = value!);
            },
            items: ['English', 'Français', 'العربية']
                .map((lang) => DropdownMenuItem(
              value: lang,
              child: Text(lang),
            ))
                .toList(),
          ),
          SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade100,
                  Colors.pink.shade100,
                  Colors.white,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildDashboardTile(Icons.person_add, 'Add Baby', _onAddBaby),
                _buildDashboardTile(Icons.child_care, 'Choose Baby', _onChooseBaby),
                _buildDashboardTile(Icons.hearing, 'Analyze Cry', _onAnalyzeCry),
                _buildDashboardTile(Icons.history, 'View History', _onViewHistory),
                _buildDashboardTile(Icons.photo_album, 'Baby Album', _onBabyAlbum),
                _buildDashboardTile(Icons.medical_services, 'Medical Info', _onMedicalInfo),
                _buildDashboardTile(Icons.settings, 'Settings / Profile', _onSettings),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddBaby,
        icon: Icon(Icons.add),
        label: Text('Add Baby'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildDashboardTile(IconData icon, String label, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.deepPurple),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddBaby() {
    Navigator.pushNamed(context, '/addBaby', arguments: widget.userInfo);
  }

  void _onChooseBaby() {
    Navigator.pushNamed(context, '/chooseBaby', arguments: widget.userInfo);
  }

  void _onAnalyzeCry() {
    Navigator.pushNamed(context, '/analyzeCry', arguments: {
      'babyId': widget.babyId,
      'userInfo': widget.userInfo,
    });
  }

  void _onViewHistory() {
    Navigator.pushNamed(context, '/viewHistory', arguments: widget.babyId);
  }

  void _onBabyAlbum() {
    Navigator.pushNamed(context, '/babyAlbum', arguments: widget.babyId);
  }

  void _onMedicalInfo() {
    Navigator.pushNamed(context, '/medicalInfo', arguments: widget.babyId);
  }

  void _onSettings() {
    Navigator.pushNamed(context, '/settings', arguments: widget.userInfo);
  }
}
