enum HealthType { vaccine, deworming, vet, medication }

class HealthRecord {
  final String id, petId, title;
  final HealthType type;
  final DateTime date;
  final DateTime? nextDue;
  final String notes;
  const HealthRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.date,
    this.nextDue,
    this.notes = '',
  });

  int? daysUntilDue([DateTime? now]) {
    if (nextDue == null) return null;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final due = DateTime(nextDue!.year, nextDue!.month, nextDue!.day);
    return due.difference(today).inDays;
  }

  bool get needsAttention => (daysUntilDue() ?? 999) <= 7;

  Map<String, dynamic> toJson() => {
        'id': id, 'petId': petId, 'type': type.name, 'title': title,
        'date': date.toIso8601String(), 'next': nextDue?.toIso8601String(), 'notes': notes,
      };
  factory HealthRecord.fromJson(Map<String, dynamic> j) => HealthRecord(
        id: j['id'], petId: j['petId'],
        type: HealthType.values.firstWhere((t) => t.name == j['type'], orElse: () => HealthType.vet),
        title: j['title'] ?? '', date: DateTime.parse(j['date']),
        nextDue: j['next'] == null ? null : DateTime.parse(j['next']), notes: j['notes'] ?? '');
}

abstract class HealthRepository {
  Future<List<HealthRecord>> getRecords(String petId);
  Future<void> saveRecord(HealthRecord record);
  Future<void> deleteRecord(String id);
}
