import 'package:flutter/material.dart';
import 'clue_data.dart';
import 'database_service.dart';

class ClueScreen extends StatefulWidget {
  const ClueScreen({super.key});

  @override
  State<ClueScreen> createState() => _ClueScreenState();
}

class _ClueScreenState extends State<ClueScreen> {
  final DatabaseService _database = DatabaseService();
  final TextEditingController _answerController = TextEditingController();

  late Future<Map<String, dynamic>?> _progressFuture;

  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadProgress() {
    _progressFuture = _database.getUserProgress();
  }

  Future<void> _submitAnswer(Clue clue) async {
    final answer = _answerController.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an answer.')));
      return;
    }

    // Check the answer, ignoring capitalization.
    if (answer.toLowerCase() != clue.solution.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect answer. Try again!')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Save the completed clue to Firestore.
      await _database.completeClue(clue.id);

      _answerController.clear();

      if (!mounted) return;

      setState(() {
        _loadProgress();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${clue.title} completed!')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save progress. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // Displays the status of an individual clue.
  Widget _buildClueStatus(Clue clue, bool isCompleted, bool isCurrent) {
    if (isCompleted) {
      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 32,
          ),
          title: Text(
            clue.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Completed'),
          trailing: const Icon(Icons.verified, color: Colors.green),
        ),
      );
    }

    if (isCurrent) {
      return Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.blue,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      clue.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Chip(
                    label: Text('Current'),
                    backgroundColor: Color(0xFFDCEBFF),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(clue.description, style: const TextStyle(fontSize: 16)),

              const SizedBox(height: 20),

              TextField(
                controller: _answerController,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Enter your answer',
                  prefixIcon: Icon(Icons.edit),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: isSubmitting ? null : () => _submitAnswer(clue),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Answer'),
              ),
            ],
          ),
        ),
      );
    }

    // Locked clue.
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock, color: Colors.grey, size: 30),
        title: Text(
          clue.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        subtitle: const Text('Complete the previous clue to unlock'),
      ),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scavenger Hunt'), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Unable to load your progress.'));
          }

          final progress = snapshot.data!;

          // Safely convert completed clue IDs into integers.
          final rawCompletedClues = progress['completedClueIds'];

          final List<int> completedClues = rawCompletedClues is List
              ? rawCompletedClues
                    .map((id) => int.tryParse(id.toString()))
                    .whereType<int>()
                    .where((id) => id >= 1 && id <= ClueData.clues.length)
                    .toSet()
                    .toList()
              : [];

          completedClues.sort();

          final totalClues = ClueData.clues.length;
          final completedCount = completedClues.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your Hunt Progress',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  '$completedCount of $totalClues clues completed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: completedCount / totalClues,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),

                const SizedBox(height: 24),

                if (completedCount == totalClues)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 75,
                            color: Colors.amber,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Congratulations!',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You have completed the Downtown '
                            'Scavenger Hunt!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Text(
                  'Clue Checklist',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                ...ClueData.clues.map((clue) {
                  final isCompleted = completedClues.contains(clue.id);

                  final isCurrent =
                      !isCompleted && clue.id == completedCount + 1;

                  return _buildClueStatus(clue, isCompleted, isCurrent);
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
