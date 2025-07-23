import 'dart:async'; // Import for StreamSubscription
import 'dart:io';
import 'package:driver_app/auth/login_page.dart';
import 'package:driver_app/models/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart'; // Ensure this is imported for LatLng
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:driver_app/models/trip_request.dart'
    as trip; // Import your TripRequest model

import 'earnings_page.dart';
import 'history_page.dart'; // Assuming this is TripHistoryPage
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final UserData? initialUserData;
  final File? initialProfileImage;

  const HomePage({super.key, this.initialUserData, this.initialProfileImage});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum ServiceMode { driver, parcel }

class _HomePageState extends State<HomePage> {
  UserData _userData = UserData(
    username: 'Guest',
    email: 'guest@example.com',
    carModel: 'N/A',
    carColor: 'N/A',
    carNumber: 'N/A',
  );
  File? _profileImageFile;
  bool _isOnline = false;
  ServiceMode _selectedMode =
      ServiceMode.driver; // New state variable for toggle

  gmap.GoogleMapController? _mapController;
  gmap.LatLng? _currentPosition;

  StreamSubscription?
  _tripRequestStreamSubscription; // To manage the Firestore listener
  List<String> _declinedTripIds =
      []; // To store IDs of trips this driver declined

  @override
  void initState() {
    super.initState();
    if (widget.initialUserData != null) {
      _userData = widget.initialUserData!;
      _profileImageFile = widget.initialProfileImage;
      _checkAndRequestLocationPermission();
    } else {
      _fetchUserData();
    }
  }

  @override
  void dispose() {
    _tripRequestStreamSubscription
        ?.cancel(); // Cancel listener when widget is disposed
    _mapController?.dispose();
    super.dispose();
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
        // Fetch declined trip IDs from Realtime Database if they exist
        if (data?['declinedTrips'] != null) {
          _declinedTripIds = List<String>.from(data!['declinedTrips']);
        }
      });

      if (_isOnline) {
        _checkAndRequestLocationPermission();
        _listenForTripRequests(); // Start listening if already online
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
        _currentPosition = gmap.LatLng(position.latitude, position.longitude);
      });
      if (_mapController != null) {
        _mapController!.animateCamera(
          gmap.CameraUpdate.newLatLng(_currentPosition!),
        );
      }
      // TODO: Update driver's location in Firebase Realtime Database
      // Example:
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseDatabase.instance.ref().child("users/${user.uid}/location").set(
          {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': ServerValue.timestamp, // Use server timestamp
          },
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

  void _onMapCreated(gmap.GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _mapController!.animateCamera(
        gmap.CameraUpdate.newLatLng(_currentPosition!),
      );
    }
  }

  // --- Image Picking for Drawer Header ---
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
        _profileImageFile = File(picked.path);
        _userData.profileImage = _profileImageFile;
      });
      // TODO: In a real app, upload this image to Firebase Storage here
      // and save the download URL to Firebase Database for persistence.
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
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

  // --- Navigation to Pages ---
  void _navigateTo(Widget page) async {
    if (page is SettingsPage) {
      final updatedUserData = await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => SettingsPage(
                initialUserData: _userData,
                initialProfileImage: _profileImageFile,
              ),
        ),
      );

      if (updatedUserData != null && updatedUserData is UserData) {
        setState(() {
          _userData = updatedUserData;
          _profileImageFile = updatedUserData.profileImage;
        });
      }
    } else {
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
        _listenForTripRequests(); // Start listening for requests
      } else {
        _tripRequestStreamSubscription?.cancel(); // Stop listening if offline
        _tripRequestStreamSubscription = null;
      }
    });
  }

  // --- Trip Request Handling ---
  void _listenForTripRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Cancel any existing listener before creating a new one
    _tripRequestStreamSubscription?.cancel();

    // Listen for pending trip requests not declined by this driver
    _tripRequestStreamSubscription = FirebaseFirestore.instance
        .collection('tripRequests')
        .where('status', isEqualTo: 'pending')
        // Exclude requests declined by this driver
        .where(
          'declinedBy',
          whereNotIn: _declinedTripIds.isEmpty ? ['_DUMMY_'] : _declinedTripIds,
        )
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isNotEmpty) {
              // Check for new requests that are not currently being displayed
              for (var doc in snapshot.docs) {
                final tripRequest = trip.TripRequest.fromFirestore(doc);
                // Only show if it's a new request and we're online
                if (tripRequest.status == 'pending' && _isOnline) {
                  // Ensure the trip is not already in the declined list
                  if (!_declinedTripIds.contains(tripRequest.tripId)) {
                    _showTripRequestDialog(tripRequest);
                    // You might want to break here or handle multiple requests
                    // differently (e.g., a queue). For now, it shows the first one.
                    break;
                  }
                }
              }
            }
          },
          onError: (error) {
            print("Error listening for trip requests: $error");
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error listening for trips: $error')),
            );
          },
        );
  }

  void _showTripRequestDialog(trip.TripRequest tripRequest) {
    // Only show if the dialog is not already open for this trip (or any trip)
    // and if the current user is online
    if (_isOnline && Navigator.of(context).canPop()) {
      // Check if a dialog is already open
      bool dialogIsOpen = false;
      Navigator.of(context).popUntil((route) {
        if (route is PopupRoute) {
          dialogIsOpen = true;
          return false; // Found a dialog, stop popping
        }
        return true; // Keep popping until a dialog is found or stack is empty
      });
      if (dialogIsOpen) return; // Don't show multiple dialogs
    }

    showDialog(
      context: context,
      barrierDismissible: false, // User must accept or decline
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'New Trip Request!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passenger: ${tripRequest.userName}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup: ${tripRequest.pickupAddress}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Destination: ${tripRequest.destinationAddress}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (tripRequest.fare != null)
                Text(
                  'Estimated Fare: \$${tripRequest.fare!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => _declineTrip(tripRequest.tripId),
              child: const Text(
                'Decline',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => _acceptTrip(tripRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptTrip(trip.TripRequest tripRequest) async {
    Navigator.of(context).pop(); // Close the dialog
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      return;
    }

    try {
      // Update trip status in Firestore
      await FirebaseFirestore.instance
          .collection('tripRequests')
          .doc(tripRequest.tripId)
          .update({
            'status': 'accepted',
            'driverId': currentUser.uid,
            'driverName': _userData.username, // Assuming username is available
            'driverCarModel': _userData.carModel,
            'driverCarColor': _userData.carColor,
            'driverCarNumber': _userData.carNumber,
            'acceptedAt': FieldValue.serverTimestamp(),
          });

      // Optionally, you can stop listening for new requests once one is accepted
      _tripRequestStreamSubscription?.cancel();
      _tripRequestStreamSubscription = null;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip accepted!')));

      // TODO: Navigate to a new page to show trip details and navigate with rider
      // For now, just a placeholder. You'll likely pass tripRequest to this new page.
      // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressPage(tripRequest: tripRequest)));
    } catch (e) {
      print("Error accepting trip: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept trip: $e')));
    }
  }

  Future<void> _declineTrip(String tripId) async {
    Navigator.of(context).pop(); // Close the dialog
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      return;
    }

    try {
      // Add tripId to the driver's declined list in Realtime Database
      // This helps filter out these requests so the driver doesn't see them again
      if (!_declinedTripIds.contains(tripId)) {
        setState(() {
          _declinedTripIds.add(tripId);
        });
        await FirebaseDatabase.instance
            .ref()
            .child("users/${currentUser.uid}/declinedTrips")
            .set(_declinedTripIds);
      }

      // Optionally, update the trip status in Firestore to 'declined' by this driver
      // This is less critical as the `isNotIn` filter will handle it, but can be useful
      // for analytics or if a rider needs to be notified of repeated declines.
      // You might need a more complex structure if multiple drivers can decline and
      // you want to track who declined it.
      // For simplicity, we just add it to driver's local declined list and rely on Firestore query.
      await FirebaseFirestore.instance
          .collection('tripRequests')
          .doc(tripId)
          .update({
            'declinedBy': FieldValue.arrayUnion([
              currentUser.uid,
            ]), // Add driver's UID to declinedBy array
            // Do NOT change status to 'declined' here, as other drivers might still see it as 'pending'
            // if it hasn't been accepted yet.
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip declined.')));

      // Restart listening for new trips, as this one is now filtered out
      _listenForTripRequests();
    } catch (e) {
      print("Error declining trip: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to decline trip: $e')));
    }
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
                    onTap: _showImagePickerDialog,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[700],
                        backgroundImage:
                            _profileImageFile != null
                                ? FileImage(_profileImageFile!)
                                : null,
                        child:
                            _profileImageFile == null
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
                  Text(
                    _userData.username ?? "N/A",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _userData.email ?? "N/A",
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
              onTap:
                  () => _navigateTo(
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
                  builder:
                      (_) => AlertDialog(
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
      body: Column(
        children: [
          // New: Toggle Button for Driver/Parcel
          Container(
            color: Colors.black, // Background for the toggle buttons
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: ToggleButtons(
                isSelected: [
                  _selectedMode == ServiceMode.driver,
                  _selectedMode == ServiceMode.parcel,
                ],
                onPressed: (int index) {
                  setState(() {
                    if (index == 0) {
                      _selectedMode = ServiceMode.driver;
                    } else {
                      _selectedMode = ServiceMode.parcel;
                    }
                    // You might want to refresh trip requests based on the selected mode
                    // e.g., if parcel requests are handled differently from driver requests.
                    // For now, _listenForTripRequests will continue to listen for all 'pending'
                    // requests, assuming they are universal or handled appropriately.
                    _listenForTripRequests();
                  });
                },
                color: Colors.white70, // Text color for unselected
                selectedColor: Colors.black, // Text color for selected
                fillColor: Colors.white, // Background color for selected
                borderColor: Colors.white30,
                selectedBorderColor: Colors.white,
                borderRadius: BorderRadius.circular(20),
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Driver', style: TextStyle(fontSize: 16)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Parcel', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
          // Remaining body content (map or offline message)
          Expanded(
            child:
                _isOnline && _currentPosition != null
                    ? Stack(
                      children: [
                        gmap.GoogleMap(
                          mapType: gmap.MapType.normal,
                          initialCameraPosition: gmap.CameraPosition(
                            target: _currentPosition!,
                            zoom: 15.0,
                          ),
                          onMapCreated: _onMapCreated,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                          compassEnabled: true,
                          markers: {
                            gmap.Marker(
                              markerId: const gmap.MarkerId("currentLocation"),
                              position: _currentPosition!,
                              infoWindow: const gmap.InfoWindow(
                                title: "My Location",
                              ),
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
                                    _isOnline
                                        ? 'You are Online'
                                        : 'You are Offline',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Switch(
                                    value: _isOnline,
                                    activeColor: Colors.green,
                                    inactiveThumbColor: const Color.fromARGB(
                                      255,
                                      238,
                                      226,
                                      226,
                                    ),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
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
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
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
          ),
        ],
      ),
    );
  }
}
