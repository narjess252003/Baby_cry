import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'db/database_helper.dart';

class ProfilePage extends StatelessWidget {
  final int userId;

  ProfilePage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper().getBabyById(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen(context);
        } else if (snapshot.hasError) {
          return _buildErrorScreen(context, snapshot.error);
        } else if (!snapshot.hasData || snapshot.data == null) {
          return _buildNoDataScreen(context);
        } else {
          final userInfo = snapshot.data!;
          return _buildProfileScreen(context, userInfo);
        }
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('baby_profile')),
        backgroundColor: Colors.blue[800],
      ),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, Object? error) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('baby_profile')),
        backgroundColor: Colors.blue[800],
      ),
      body: Center(
        child: Text(
          '${AppLocalizations.of(context).translate('error')}: $error',
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildNoDataScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('baby_profile')),
        backgroundColor: Colors.blue[800],
      ),
      body: Center(
        child: Text(
          AppLocalizations.of(context).translate('no_user_data_found'),
          style: TextStyle(color: Colors.grey[600], fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildProfileScreen(BuildContext context, Map<String, dynamic> userInfo) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('baby_profile')),
        backgroundColor: Colors.blue[800],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.blue[600]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildUserInfo(context, userInfo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate(''),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black.withOpacity(0.2),
              ),
            ],
          ),
        ),
        Divider(color: Colors.white, thickness: 1.5),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUserInfo(BuildContext context, Map<String, dynamic> userInfo) {
    return Column(
      children: [
        _buildListTile(
          icon: Icons.person,
          title: AppLocalizations.of(context).translate('full_name'),
          subtitle: userInfo['full_name'] ?? AppLocalizations.of(context).translate('no_name_provided'),
        ),
        _buildListTile(
          icon: Icons.cake,
          title: AppLocalizations.of(context).translate('age'),
          subtitle: userInfo['age']?.toString() ?? AppLocalizations.of(context).translate('age_not_provided'),
        ),
        _buildListTile(
          icon: Icons.flag,
          title: AppLocalizations.of(context).translate('nationality'),
          subtitle: userInfo['nationality'] ?? AppLocalizations.of(context).translate('nationality_not_provided'),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required String subtitle}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[800]),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
