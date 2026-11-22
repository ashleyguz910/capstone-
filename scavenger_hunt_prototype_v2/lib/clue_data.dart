class Clue {
  final int id;
  final String title;
  final String description;
  final String hint;
  final String solution;

  const Clue({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.solution,
  });
}

class ClueData {
  static const List<Clue> clues = [
    Clue(
      id: 1,
      title: 'Clue 1',
      description: 'This is placeholder clue 1.',
      hint: 'This is a hint for clue 1.',
      solution: '1234',
    ),
    Clue(
      id: 2,
      title: 'Clue 2',
      description: 'This is placeholder clue 2.',
      hint: 'This is a hint for clue 2.',
      solution: 'clue',
    ),
    Clue(
      id: 3,
      title: 'Clue 3',
      description: 'This is placeholder clue 3.',
      hint: 'This is a hint for clue 3.',
      solution: 'clue123',
    ),
  ];
}
