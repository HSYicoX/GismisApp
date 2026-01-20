/// AnimeSchedule model representing anime update schedule.
class AnimeSchedule {
  const AnimeSchedule({required this.weekday, this.updateTime});

  factory AnimeSchedule.fromJson(Map<String, dynamic> json) {
    return AnimeSchedule(
      weekday: json['weekday'] as int,
      updateTime: json['update_time'] as String?,
    );
  }
  final int weekday; // 1-7 (Monday-Sunday)
  final String? updateTime;

  Map<String, dynamic> toJson() {
    return {'weekday': weekday, 'update_time': updateTime};
  }

  AnimeSchedule copyWith({int? weekday, String? updateTime}) {
    return AnimeSchedule(
      weekday: weekday ?? this.weekday,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeSchedule) return false;
    return weekday == other.weekday && updateTime == other.updateTime;
  }

  @override
  int get hashCode => Object.hash(weekday, updateTime);
}
