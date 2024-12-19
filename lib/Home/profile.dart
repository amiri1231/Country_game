import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  String? _profilePictureUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // uer prfile
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _usernameController.text = userData['username'] ?? '';
      _profilePictureUrl = userData['profilePictureUrl'];
      setState(() {});
    }
  }

  // pick image gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadProfilePicture(File(image.path));
    }
  }

  // upload pic
  Future<void> _uploadProfilePicture(File image) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}.jpg');
        await storageRef.putFile(image);
        String downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profilePictureUrl': downloadUrl,
        });

        setState(() {
          _profilePictureUrl = downloadUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error uploading image: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  //update username
  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        // if the document does not exist create 
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'username': _usernameController.text,
            'profilePictureUrl': '', // Optional, initially empty
          });
        }

        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'username': _usernameController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        print("Error updating profile: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Display the profile picture
            if (_profilePictureUrl != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_profilePictureUrl!),
              )
            else
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            const SizedBox(height: 10),

            // Button to pick a new profile picture
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Change Profile Picture'),
            ),

            // Text field for the username
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 20),

            // Button to save the updated profile
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _updateProfile,
                    child: const Text('Save Changes'),
                  ),
          ],
        ),
      ),
    );
  }
}
