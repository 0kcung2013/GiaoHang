class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.group,
    required this.question,
    required this.answer,
  });

  final String id;
  final String group;
  final String question;
  final String answer;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return '$group $question $answer'.toLowerCase().contains(normalized);
  }
}
