import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profilePictureUrl;
  String? _username;
  String? _country;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchLocation();
  }

  Future<void> _loadUserProfile() async { 
    final user = FirebaseAuth.instance.currentUser;
     if (user != null) 
     { final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() { _username = user.email;
      _profilePictureUrl = userData['profilePictureUrl'];
      _country = userData['country'];
       });
        }
         }

  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    String country = placemarks.isNotEmpty && placemarks[0].country != null
        ? placemarks[0].country!
        : 'Unknown';

    setState(() {
      _country = country;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'country': _country,
      });
    }
  }

  // Pick and Upload Profile Picture
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Profile Picture Source'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
          ],
        );
      },
    );

    if (pickedSource == null) return;

    final XFile? image = await picker.pickImage(source: pickedSource);
    if (image != null) {
      await _uploadProfilePicture(File(image.path));
    }
  }

  Future<void> _uploadProfilePicture(File image) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}.jpg');

        // Upload the file
        await storageRef.putFile(image);
        String downloadUrl = await storageRef.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profilePictureUrl': downloadUrl,
        });

        setState(() {
          _profilePictureUrl = downloadUrl;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      } else {
        throw Exception('User is not authenticated');
      }
    } catch (e) {
      print("Error uploading image: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profilePictureUrl != null
                        ? NetworkImage(_profilePictureUrl!)
                        : null,
                    child: _profilePictureUrl == null
                        ? const Icon(Icons.person, size: 70, color: Colors.grey)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                    onPressed: _pickImage,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Username
              Text(
                _username ?? 'Guest',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // Location
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 5),
                  Text(
                    _country != null ? 'Location: $_country' : 'Fetching location...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Save Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () {
                        _showSnackBar('Profile saved successfully!');
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
