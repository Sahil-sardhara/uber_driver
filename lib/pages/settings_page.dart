import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final uid = _auth.currentUser!.uid;
    final snapshot = await _dbRef.child('users/$uid').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['PhoneNumber'] ?? '';
        _profileImageUrl = data['profileImage'];
        _isLoading = false;
      });
    }
  }

  Future<void> updateProfile() async {
    final uid = _auth.currentUser!.uid;
    await _dbRef.child('drivers/$uid').update({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phonenumber': _phoneController.text.trim(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  Future<void> uploadProfileImage() async {
    final uid = _auth.currentUser!.uid;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final ref = FirebaseStorage.instance.ref().child(
      'driverProfileImages/$uid.jpg',
    );
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await _dbRef.child('drivers/$uid/profileImage').set(url);
    setState(() {
      _profileImageUrl = url;
    });

    // Update drawer if needed
    // You can use a provider or callback to update other widgets
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: uploadProfileImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : const AssetImage('assets/images/profile.jpg')
                                    as ImageProvider,
                        child: const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(Icons.edit, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildTextField('Name', _nameController),
                    buildTextField(
                      'Email',
                      _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    buildTextField(
                      'Phone Number',
                      _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: updateProfile,
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () => _auth.signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }
}
