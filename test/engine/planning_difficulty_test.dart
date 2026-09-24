import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/planning_difficulty.dart';
import 'package:ungrid/game/models/level.dart';

void main() {
  test(
    'le niveau 81 jugé trop facile ne passe plus le filtre de planification',
    () {
      final rows =
          jsonDecode(
                File(
                  'assets/levels/campaign_v3_solutions.json',
                ).readAsStringSync(),
              )['levels']
              as List;
      final row = rows[80] as Map<String, dynamic>;
      final result = PlanningDifficulty.measure(
        Level.fromJson(row),
        (row['solution'] as List).cast<String>(),
      );
      expect(result.deferredReturns, 1);
      expect(result.accepts, isFalse);
    },
  );
}
