import 'dart:io';
import 'package:driver_app/auth/login_page.dart';
import 'package:driver_app/models/user_data.dart'; // Import your UserData model
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import 'earnings_page.dart';
import 'history_page.dart';
import 'settings_page.dart'; // Ensure SettingsPage is imported

class HomePage extends StatefulWidget {
  // Add constructor parameters for initial user data passed from SignupPage
  final UserData? initialUserData;
  final File? initialProfileImage;

  const HomePage({
    super.key,
    this.initialUserData,
    this.initialProfileImage,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Use UserData object to hold profile information
  // Initialize with dummy data, but initState will set it correctly.
  UserData _userData = UserData(
    username: 'Guest',
    email: 'guest@example.com',
    carModel: 'N/A',
    carColor: 'N/A',
    carNumber: 'N/A',
  );
  File? _profileImageFile; // Use a dedicated variable for the profile image
  bool _isOnline = false;

  GoogleMapController? _mapController;
  LatLng? _currentPosition; // To store current location

  @override
  void initState() {
    super.initState();
    // Prioritize data from the constructor (coming from SignupPage)
    if (widget.initialUserData != null) {
      _userData = widget.initialUserData!;
      _profileImageFile = widget.initialProfileImage;
      // If data is passed, it means we just signed up, so also
      // ensure Firebase reflects 'online' status (optional, but good for new users)
      _checkAndRequestLocationPermission(); // Always try to get location if online
    } else {
      // If no initial data is passed (e.g., user logged in, app restarted),
      // fetch the data from Firebase.
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final snapshot =
          await FirebaseDatabase.instance.ref().child("users").child(uid).get();
      final data = snapshot.value as Map?;

      setState(() {
        _userData = UserData.fromFirebase(data, user.email);
        _isOnline = data?['online'] ?? false;
        // IMPORTANT: If you store profile image URLs in Firebase,
        // you would fetch the URL here and then load the image (e.g., using CachedNetworkImage)
        // or download it to a temporary file and set _profileImageFile.
        // For this example, _profileImageFile is handled locally after pick.
      });
      // If online status is true after fetching, try to get location
      if (_isOnline) {
        _checkAndRequestLocationPermission();
      }
    }
  }

  // --- Location Handling ---
  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, we cannot request permissions.',
          ),
        ),
      );
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_currentPosition!),
        );
      }
    } catch (e) {
      print("Error getting current location: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
  }

  // --- Image Picking for Drawer Header ---
  // This method is for changing the profile image directly from the drawer.
  // It's separate from the settings page, but updates the same _profileImageFile.
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
    } else { // ImageSource.gallery
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
        _profileImageFile = File(picked.path);
        _userData.profileImage = _profileImageFile; // Update UserData model
      });
      // TODO: In a real app, upload this image to Firebase Storage here
      // and save the download URL to Firebase Database for persistence.
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

  // --- Navigation to Pages (especially SettingsPage with result handling) ---
  void _navigateTo(Widget page) async {
    if (page is SettingsPage) {
      // Pass current UserData and profile image to SettingsPage
      final updatedUserData = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            initialUserData: _userData,
            initialProfileImage: _profileImageFile,
          ),
        ),
      );

      // If SettingsPage returned updated UserData, update our local state
      if (updatedUserData != null && updatedUserData is UserData) {
        setState(() {
          _userData = updatedUserData;
          _profileImageFile = updatedUserData.profileImage; // Update image if changed
        });
      }
    } else {
      // For other pages (Earnings, History), just navigate
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
  }

  void _toggleOnlineStatus(bool val) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance
          .ref()
          .child("users/${user.uid}/online")
          .set(val);
    }
    setState(() {
      _isOnline = val;
      if (_isOnline) {
        _getCurrentLocation(); // Attempt to get location when going online
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Movana Driver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showImagePickerDialog, // Tap to change profile image
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[700],
                        backgroundImage: _profileImageFile != null
                            ? FileImage(_profileImageFile!)
                            : null, // Use _profileImageFile for display
                        child: _profileImageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 32,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Display username from _userData
                  Text(
                    _userData.username ?? "N/A",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Display email from _userData
                  Text(
                    _userData.email ?? "N/A",
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Car details from _userData
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.white70),
              title: const Text(
                'Car Model',
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                _userData.carModel ?? "N/A",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens, color: Colors.white70),
              title: const Text(
                'Car Color',
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                _userData.carColor ?? "N/A",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.confirmation_number,
                color: Colors.white70,
              ),
              title: const Text(
                'Car Number',
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                _userData.carNumber ?? "N/A",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const Divider(color: Colors.white30),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.white),
              title: const Text(
                'Earnings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _navigateTo(const EarningsPage()),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text(
                'Trip History',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _navigateTo(const TripHistoryPage()),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              // Pass current user data to SettingsPage
              onTap: () => _navigateTo(
                SettingsPage(
                  initialUserData: _userData,
                  initialProfileImage: _profileImageFile,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.black87,
                    title: const Text(
                      'Confirm Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Do you want to logout?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'No',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(
                            context,
                          ).pop(); // Close the dialog first
                          await FirebaseAuth.instance.signOut();
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Yes',
                          style: TextStyle(color: Colors.redAccent),
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
      body: _isOnline && _currentPosition != null
          ? Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 15.0,
                  ),
                  onMapCreated: _onMapCreated,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId("currentLocation"),
                      position: _currentPosition!,
                      infoWindow: const InfoWindow(title: "My Location"),
                    ),
                  },
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isOnline ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white70,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isOnline ? 'You are Online' : 'You are Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Switch(
                            value: _isOnline,
                            activeColor: Colors.green,
                            inactiveThumbColor: const Color.fromARGB(255, 238, 226, 226),
                            onChanged: _toggleOnlineStatus,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isOnline ? 'You are Online' : 'You are Offline',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Switch(
                    value: _isOnline,
                    activeColor: Colors.green,
                    inactiveThumbColor: const Color.fromARGB(
                      255,
                      237,
                      119,
                      119,
                      
                    ),
                    onChanged: _toggleOnlineStatus,
                  ),
                  if (_isOnline && _currentPosition == null)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  if (_isOnline && _currentPosition == null)
                    const Text(
                      'Fetching your location...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  if (!_isOnline)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'Go online to view the map and receive ride requests.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}