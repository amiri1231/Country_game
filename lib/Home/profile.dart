import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profilePictureUrl;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadProfilePicture(File(image.path));
    }
  }

  Future<void> _uploadProfilePicture(File image) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uniqueFileName = const Uuid().v4();
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/$uniqueFileName.png');

      print('Uploading image to Storage path: profile_pictures/$uniqueFileName.png');
      await storageRef.putFile(image);

      String downloadUrl = await storageRef.getDownloadURL();
      print('Image uploaded successfully. Download URL: $downloadUrl');

      setState(() {
        _profilePictureUrl = downloadUrl;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture uploaded successfully!')),
      );
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Profile Picture'),
                  ),
          ],
        ),
      ),
    );
  }
}
