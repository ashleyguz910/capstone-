import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get userId {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  DocumentReference<Map<String, dynamic>> get userDocument {
    return _db.collection('users').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> get leaderboardDocument {
    return _db.collection('leaderboard').doc(userId);
  }

  // Retrieve the current user's progress from Firestore.
  Future<Map<String, dynamic>?> getUserProgress() async {
    final snapshot = await userDocument.get();
    return snapshot.data();
  }

  // Convert stored clue IDs into integers safely.
  List<int> _convertClueIds(dynamic rawClues) {
    if (rawClues is! List) {
      return [];
    }

    return rawClues
        .map((id) => int.tryParse(id.toString()))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
  }

  // Complete a clue and update the leaderboard at the same time.
  Future<void> completeClue(int clueNumber) async {
    await _db.runTransaction((transaction) async {
      // Retrieve the user's document.
      final userSnapshot = await transaction.get(userDocument);

      if (!userSnapshot.exists) {
        throw Exception('User progress document not found.');
      }

      final data = userSnapshot.data()!;
      final username = data['username'];

      if (username is! String || username.isEmpty) {
        throw Exception('User profile is missing a username.');
      }

      final completedClues = _convertClueIds(data['completedClueIds']);

      // Prevent completing the same clue twice.
      if (completedClues.contains(clueNumber)) {
        return;
      }

      // Require the previous clue to be completed first.
      if (clueNumber != completedClues.length + 1) {
        throw Exception('Complete the previous clue first.');
      }

      completedClues.add(clueNumber);

      final newPoints = completedClues.length * 100;

      // Update the private user profile.
      transaction.update(userDocument, {
        'completedClueIds': completedClues,
        'completedClues': completedClues.length,
        'points': newPoints,
      });

      // Update the public leaderboard entry.
      transaction.set(leaderboardDocument, {
        'displayName': username,
        'points': newPoints,
      });
    });
  }

  // Reset the user's progress and leaderboard score.
  Future<void> resetProgress() async {
    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocument);

      if (!userSnapshot.exists) {
        throw Exception('User progress document not found.');
      }

      final username = userSnapshot.data()!['username'];

      if (username is! String || username.isEmpty) {
        throw Exception('User profile is missing a username.');
      }

      // Reset private user progress.
      transaction.update(userDocument, {
        'completedClueIds': [],
        'completedClues': 0,
        'points': 0,
      });

      // Reset the public leaderboard score.
      transaction.set(leaderboardDocument, {
        'displayName': username,
        'points': 0,
      });
    });
  }
}
