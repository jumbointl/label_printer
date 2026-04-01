// lib/src/models/label_history_item.dart
class LabelHistoryItem {
  final String name;
  final String code;
  final bool is40x25;   // para recordar si la usaste en 40x25
  final int copies;     // última cantidad usada (opcional)
  final DateTime savedAt;

  LabelHistoryItem({
    required this.name,
    required this.code,
    required this.is40x25,
    required this.copies,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'is40x25': is40x25,
    'copies': copies,
    'savedAt': savedAt.toIso8601String(),
  };

  factory LabelHistoryItem.fromJson(Map<String, dynamic> json) {
    return LabelHistoryItem(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      is40x25: (json['is40x25'] ?? false) as bool,
      copies: (json['copies'] ?? 1) as int,
      savedAt: DateTime.tryParse(json['savedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
