class QuizQuestion {
  const QuizQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.topic,
  });

  final String text;
  final List<String> options;
  final int correctIndex;
  final String? topic;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      text: json['text'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? [])
          .map((o) => o.toString())
          .toList(),
      correctIndex: (json['correct_index'] as num?)?.toInt() ?? 0,
      topic: json['topic'] as String?,
    );
  }
}
