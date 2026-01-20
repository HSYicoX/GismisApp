/// HotQuestion model representing AI-generated suggested questions.
class HotQuestion {
  const HotQuestion({
    required this.topic,
    required this.question,
    required this.rank,
  });

  factory HotQuestion.fromJson(Map<String, dynamic> json) {
    return HotQuestion(
      topic: json['topic'] as String,
      question: json['question'] as String,
      rank: json['rank'] as int,
    );
  }
  final String topic;
  final String question;
  final int rank;

  Map<String, dynamic> toJson() {
    return {'topic': topic, 'question': question, 'rank': rank};
  }

  HotQuestion copyWith({String? topic, String? question, int? rank}) {
    return HotQuestion(
      topic: topic ?? this.topic,
      question: question ?? this.question,
      rank: rank ?? this.rank,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HotQuestion) return false;
    return topic == other.topic &&
        question == other.question &&
        rank == other.rank;
  }

  @override
  int get hashCode => Object.hash(topic, question, rank);
}
