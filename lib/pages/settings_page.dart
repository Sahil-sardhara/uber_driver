import 'dart:io';
import 'package:driver_app/models/user_data.dart'; // Import UserData model
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  final UserData initialUserData;
  final File? initialProfileImage;

  const SettingsPage({
    Key? key,
    required this.initialUserData,
    this.initialProfileImage,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UserData _currentUserData;
  File? _currentProfileImage;
  final _usernameController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserData = UserData(
      username: widget.initialUserData.username,
      email: widget.initialUserData.email,
      carModel: widget.initialUserData.carModel,
      carColor: widget.initialUserData.carColor,
      carNumber: widget.initialUserData.carNumber,
      profileImage: widget.initialProfileImage, // Pass the image file
    );
    _currentProfileImage = widget.initialProfileImage;

    _usernameController.text = _currentUserData.username ?? '';
    _carModelController.text = _currentUserData.carModel ?? '';
    _carColorController.text = _currentUserData.carColor ?? '';
    _carNumberController.text = _currentUserData.carNumber ?? '';
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();

    if (source == ImageSource.camera) {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')),
        );
        return;
      }
    } else {
      var status = await Permission.photos.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission denied')),
        );
        return;
      }
    }

    final picked = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _currentProfileImage = File(picked.path);
        _currentUserData.profileImage = _currentProfileImage; // Update UserData
      });
      // Here, you'd typically upload the image to Firebase Storage
      // and then save the download URL to Firebase Database for persistence.
      // For now, it's just updated locally.
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final updatedData = {
        'name': _usernameController.text.trim(),
        'carModel': _carModelController.text.trim(),
        'carColor': _carColorController.text.trim(),
        'carNumber': _carNumberController.text.trim(),
        // Note: Image upload and URL saving would happen here if implemented fully
      };

      try {
        await FirebaseDatabase.instance
            .ref()
            .child("users/${user.uid}")
            .update(updatedData);

        setState(() {
          _currentUserData.username = _usernameController.text.trim();
          _currentUserData.carModel = _carModelController.text.trim();
          _currentUserData.carColor = _carColorController.text.trim();
          _currentUserData.carNumber = _carNumberController.text.trim();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );

        // Pass the updated UserData back to the previous screen (HomePage)
        Navigator.pop(context, _currentUserData);
      } catch (e) {
        print("Error saving data: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Pass the current data back when going back
            Navigator.pop(context, _currentUserData);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImagePickerDialog,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: _currentProfileImage != null
                      ? FileImage(_currentProfileImage!)
                      : null,
                  child: _currentProfileImage == null
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person,
              readOnly: false,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: TextEditingController(text: _currentUserData.email),
              label: 'Email',
              icon: Icons.email,
              readOnly: true, // Email is usually not editable via settings
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _carModelController,
              label: 'Car Model',
              icon: Icons.directions_car,
              readOnly: false,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _carColorController,
              label: 'Car Color',
              icon: Icons.color_lens,
              readOnly: false,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _carNumberController,
              label: 'Car Number',
              icon: Icons.confirmation_number,
              readOnly: false,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.greenAccent),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}