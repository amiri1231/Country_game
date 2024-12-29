import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _friendEmailController = TextEditingController();

  List<String> friends = [];
  List<String> friendRequests = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  // load
  Future<void> _loadFriends() async {
    setState(() => isLoading = true);
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          friends = List<String>.from(userDoc.data()?['friends'] ?? []);
          friendRequests = List<String>.from(userDoc.data()?['friendRequests'] ?? []);
        });
      }
    }
    setState(() => isLoading = false);
  }

  // send request
  Future<void> _sendFriendRequest(String friendEmail) async {
    if (friendEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final friendQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: friendEmail)
          .limit(1)
          .get();

      if (friendQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      final friendId = friendQuery.docs.first.id;

      // duplicate check
      final friendDoc = friendQuery.docs.first.data();
      if ((friendDoc['friendRequests'] ?? []).contains(user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request already sent')),
        );
        return;
      }

      await _firestore.collection('users').doc(friendId).update({
        'friendRequests': FieldValue.arrayUnion([user.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  //accept
  Future<void> _acceptFriendRequest(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final friendDocRef = _firestore.collection('users').doc(friendId);

        transaction.update(userDocRef, {
          'friendRequests': FieldValue.arrayRemove([friendId]),
          'friends': FieldValue.arrayUnion([friendId]),
        });
        transaction.update(friendDocRef, {
          'friends': FieldValue.arrayUnion([user.uid]),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );

      _loadFriends();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // decline
  Future<void> _declineFriendRequest(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'friendRequests': FieldValue.arrayRemove([friendId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined.')),
      );

      _loadFriends();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _friendEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Friend\'s Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () =>
                        _sendFriendRequest(_friendEmailController.text.trim()),
                    child: const Text('Send Friend Request'),
                  ),
                  const Divider(height: 30),
                  const Text(
                    'Friend Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: friendRequests.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(friendRequests[index]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () =>
                                    _acceptFriendRequest(friendRequests[index]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () =>
                                    _declineFriendRequest(friendRequests[index]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 30),
                  const Text(
                    'Your Friends',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(friends[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
