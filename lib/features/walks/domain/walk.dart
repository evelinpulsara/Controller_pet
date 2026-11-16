import '../../../core/utils/geo_utils.dart';
import '../../tracking/domain/location_data.dart';

class Walk {
  final String id, petId;
  final DateTime start;
  final DateTime? end;
  final List<LocationData> points;
  const Walk({required this.id, required this.petId, required this.start, this.end, this.points = const []});

  bool get inProgress => end == null;
  Duration get duration => (end ?? DateTime.now()).difference(start);

  double get distanceMeters {
    var d = 0.0;
    for (var i = 1; i < points.length; i++) {
      d += GeoUtils.distanceMeters(
          points[i - 1].latitude, points[i - 1].longitude, points[i].latitude, points[i].longitude);
    }
    return d;
  }

  double get avgSpeedKmh {
    final h = duration.inSeconds / 3600;
    return h <= 0 ? 0 : (distanceMeters / 1000) / h;
  }

  Walk copyWith({DateTime? end, List<LocationData>? points}) =>
      Walk(id: id, petId: petId, start: start, end: end ?? this.end, points: points ?? this.points);

  Map<String, dynamic> toJson() => {
        'id': id, 'petId': petId, 'start': start.toIso8601String(), 'end': end?.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
      };
  factory Walk.fromJson(Map<String, dynamic> j) => Walk(
        id: j['id'], petId: j['petId'], start: DateTime.parse(j['start']),
        end: j['end'] == null ? null : DateTime.parse(j['end']),
        points: [for (final p in (j['points'] as List? ?? [])) LocationData.fromJson(Map<String, dynamic>.from(p))],
      );
}

abstract class WalkRepository {
  Future<List<Walk>> getWalks(String petId);
  Future<void> saveWalk(Walk walk);
  Future<void> deleteWalk(String id);
}
