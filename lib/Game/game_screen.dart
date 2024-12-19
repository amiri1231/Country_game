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
  bool isLoading = false;
  int roundNumber = 1;
  bool gameOver = false;
  bool isTimerActive = false;

  TextEditingController guessController = TextEditingController();
  late StreamSubscription _gameStreamSubscription;
  late Timer _timer;
  int remainingTime = 50;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

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

        // start timer
        if (!isTimerActive && players.length == 2 && currentPlayer == _auth.currentUser?.uid) {
          _startTimer();
        }
      }
    });
  }

  void _startTimer() {
    setState(() {
      isTimerActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          _endTurn();
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submitGuess() async {
    if (guessController.text.isEmpty) return;

    final user = _auth.currentUser;
    if (user != null && currentPlayer == user.uid) {
      if (!_isGuessValid(guessController.text)) return;

      final gameRef = _firestore.collection('games').doc(widget.gameId);
      final nextPlayer = players.firstWhere((player) => player != user.uid);

      // paues timer
      _pauseTimer();

      //update online firestoer
      await gameRef.update({
        'currentWord': guessController.text,
        'currentTurn': nextPlayer,
        'roundNumber': roundNumber + 1,
      });

      guessController.clear();

      // resume for next player
      _resumeTimer();
    }
  }

  // pause
  void _pauseTimer() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    setState(() {
      isTimerActive = false;
    });
  }

  // resume 
  void _resumeTimer() {
    setState(() {
      isTimerActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          _endTurn();
          timer.cancel();
        }
      });
    });
  }

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

  void _endTurn() {
    setState(() {
      isTimerActive = false;
    });
  }

  @override
  void dispose() {
    _gameStreamSubscription.cancel();
    if (_timer.isActive) _timer.cancel();
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
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // show lobby code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Lobby Code: ${lobbyCode ?? 'Loading...'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),

            //show current word
            Center(
              child: Text(
                'Current Word: ${currentWord?.isEmpty ?? true ? 'No word yet' : currentWord}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            if (gameOver) ...[
              const Center(
                child: Text(
                  'Game Over!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ] else ...[
              Text('Round: $roundNumber', style: const TextStyle(fontSize: 18, color: Colors.white)),
              Text('Players: ${players.length} / 2', style: const TextStyle(fontSize: 18, color: Colors.white)),
              Text('Time Left: $remainingTime seconds', style: const TextStyle(fontSize: 18, color: Colors.white)),

              if (players.length < 2) ...[
                const Center(
                  child: Text(
                    'Waiting for player 2 to join...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ] else if (currentPlayer == _auth.currentUser?.uid) ...[
                TextField(
                  controller: guessController,
                  decoration: const InputDecoration(
                    labelText: 'Your Guess',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitGuess,
                  child: const Text('Submit Guess'),
                ),
              ] else ...[
                const Center(
                  child: Text(
                    'Waiting for other player to guess...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
