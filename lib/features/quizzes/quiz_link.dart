const _quizBaseUrl =
    'https://studyhubacademy.github.io/studyhub-app-web/quiz.html';

/// [termId], when given, tags the link so every attempt submitted through
/// it records which term it was shared for — set once by the owner at
/// share time, not guessed later from a submission timestamp.
String quizLinkFor(String quizId, {String? termId}) {
  final base = '$_quizBaseUrl?id=$quizId';
  return termId == null ? base : '$base&term=$termId';
}
