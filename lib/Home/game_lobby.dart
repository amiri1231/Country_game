import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/Game/game_screen.dart';
import 'dart:math'; // For generating random lobby code

class GameLobbyPage extends StatefulWidget {
  const GameLobbyPage({super.key});

  @override
  _GameLobbyPageState createState() => _GameLobbyPageState();
}

class _GameLobbyPageState extends State<GameLobbyPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController lobbyCodeController = TextEditingController();

  // Generate a random 6-character lobby code
  String _generateLobbyCode() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return List.generate(6, (index) => characters[random.nextInt(characters.length)]).join();
  }

  Future<void> _createNewGame() async {
    final user = _auth.currentUser;

    if (user != null) {
      final gameId = _firestore.collection('games').doc().id;
      final lobbyCode = _generateLobbyCode();

      await _firestore.collection('games').doc(gameId).set({
        'gameId': gameId,
        'lobbyCode': lobbyCode,
        'players': [user.uid],
        'currentTurn': user.uid,
        'currentWord': '',
        'roundNumber': 1,
        'gameStatus': 'waiting'
      });

      Navigator.push(context, MaterialPageRoute(
        builder: (context) => GameScreen(gameId: gameId),
      ));
    }
  }

  Future<void> _joinGameByCode(String lobbyCode) async {
    final user = _auth.currentUser;

    if (user != null) {
      final querySnapshot = await _firestore
          .collection('games')
          .where('lobbyCode', isEqualTo: lobbyCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final gameData = querySnapshot.docs.first;
        final gameId = gameData['gameId'];

        await _firestore.collection('games').doc(gameId).update({
          'players': FieldValue.arrayUnion([user.uid]),
          'gameStatus': 'in_progress'
        });

        Navigator.push(context, MaterialPageRoute(
          builder: (context) => GameScreen(gameId: gameId),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Lobby Code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _createNewGame,
              child: const Text('Create New Game'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: lobbyCodeController,
              decoration: const InputDecoration(
                labelText: 'Enter Lobby Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _joinGameByCode(lobbyCodeController.text.trim()),
              child: const Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}
