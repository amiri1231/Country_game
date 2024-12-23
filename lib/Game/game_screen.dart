import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:country_game/guess/countries.dart';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? lobbyCode;
  String? currentWord;
  String? currentPlayer;
  List<String> players = [];
  bool gameOver = false;
  int roundNumber = 1;

  TextEditingController guessController = TextEditingController();
  late StreamSubscription _gameStreamSubscription;
  Timer? _timer;
  int remainingTime = 20;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  //start
  Future<void> _initializeGame() async {
    _gameStreamSubscription = _firestore
        .collection('games')
        .doc(widget.gameId)
        .snapshots()
        .listen((gameSnapshot) {
      if (gameSnapshot.exists) {
        final gameData = gameSnapshot.data() as Map<String, dynamic>;

        setState(() {
          lobbyCode = gameData['lobbyCode'];
          currentWord = gameData['currentWord'];
          currentPlayer = gameData['currentTurn'];
          players = List<String>.from(gameData['players']);
          roundNumber = gameData['roundNumber'];
          gameOver = gameData['gameStatus'] == 'finished';
        });

        // timer
        if (!gameOver && players.length == 2 && currentPlayer == _auth.currentUser?.uid) {
          _startTimer();
        } else {
          _pauseTimer();
        }
      }
    });
  }

  // Start Timer 
  void _startTimer() {
    _pauseTimer(); 

    setState(() {
      remainingTime = 20; 
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          _endGame('Time ran out! You lost the game.');
          timer.cancel();
        }
      });
    });
  }

  // pause Timer
  void _pauseTimer() {
    _timer?.cancel();
  }

  // submit Guess
  Future<void> _submitGuess() async {
    if (guessController.text.isEmpty) return;

    final user = _auth.currentUser;
    if (user != null && currentPlayer == user.uid) {
      if (!_isGuessValid(guessController.text)) return;

      final gameRef = _firestore.collection('games').doc(widget.gameId);
      final nextPlayer = players.firstWhere((player) => player != user.uid);

      await gameRef.update({
        'currentWord': guessController.text,
        'currentTurn': nextPlayer,
        'roundNumber': roundNumber + 1,
      });

      guessController.clear();
      _pauseTimer(); 
    }
  }

  // validate Guess functionn
  bool _isGuessValid(String guess) {
    if (guess.isEmpty) return false;

    guess = guess.trim().toLowerCase();

    bool isCountryInList = countriesList.any((country) => country.toLowerCase() == guess);
    if (!isCountryInList) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid guess! Country not in the list.')),
      );
      return false;
    }

    if (currentWord == null || currentWord!.isEmpty) return true;

    String lastLetterOfCurrentWord = currentWord!.substring(currentWord!.length - 1).toLowerCase();
    String firstLetterOfGuess = guess[0].toLowerCase();

    if (lastLetterOfCurrentWord != firstLetterOfGuess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The guess must start with "$lastLetterOfCurrentWord".')),
      );
      return false;
    }

    return true;
  }

  // End Game
  void _endGame(String message) {
    setState(() {
      gameOver = true;
    });
    _firestore.collection('games').doc(widget.gameId).update({
      'gameStatus': 'finished',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _gameStreamSubscription.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Screen'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/whitebg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Lobby Code: ${lobbyCode ?? 'Loading...'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Current Word: ${currentWord?.isEmpty ?? true ? 'No word yet' : currentWord}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            Text('Round: $roundNumber', style: const TextStyle(fontSize: 18, color: Colors.black)),
            Text('Players: ${players.length} / 2', style: const TextStyle(fontSize: 18, color: Colors.black)),
            Text('Time Left: $remainingTime seconds', style: const TextStyle(fontSize: 18, color: Colors.black)),
            const SizedBox(height: 20),
            if (gameOver) ...[
              const Center(
                child: Text(
                  'Game Over!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ] else if (currentPlayer == _auth.currentUser?.uid) ...[
              TextField(
                controller: guessController,
                decoration: const InputDecoration(
                  labelText: 'Your Guess',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitGuess,
                child: const Text('Submit Guess'),
              ),
            ] else ...[
              const Center(
                child: Text('Waiting for other player to guess...'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
