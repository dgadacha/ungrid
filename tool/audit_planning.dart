import 'dart:io';
import 'dart:convert';
import 'package:ungrid/game/models/level.dart';
import 'package:ungrid/game/engine/planning_difficulty.dart';

void main() {
  final rows =
      jsonDecode(
            File('assets/levels/campaign_v3_solutions.json').readAsStringSync(),
          )['levels']
          as List;
  var count = 0;
  for (final row in rows) {
    final p = PlanningDifficulty.measure(
      Level.fromJson(row),
      (row['solution'] as List).cast<String>(),
    );
    if (p.accepts) count++;
    if (row['id'] == 81 || p.accepts) {
      stdout.writeln('${row['id']} ${p.toJson()}');
    }
  }
  stdout.writeln('Acceptés: $count / 100');
}
