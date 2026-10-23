import 'package:flutter_test/flutter_test.dart';
import 'package:bloom/domain.dart';

void main() {
  test('Dose scaling preserves cumulative totals and stage times', () {
    final recipe = newRecipe('test', defaultEquipment());
    final steps = scaleSteps(recipe['steps'], 250, 333);
    expect(steps.map((s) => s['time']), [0, 45, 75, 105]);
    expect(steps.map((s) => s['water']), [60, 167, 260, 333]);
    expect(validateSteps(steps, 333, 180), isNull);
    expect(ratio(recipe), '1:16,7');
  });
  test(
    'The timer changes at exact boundaries and continues past the target',
    () {
      final recipe = newRecipe('test', defaultEquipment());
      expect(currentStep(recipe, 44), 0);
      expect(currentStep(recipe, 45), 1);
      expect(currentStep(recipe, 75), 2);
      expect(currentStep(recipe, 105), 3);
      expect(currentStep(recipe, 240), 3);
      expect(clock(240), '4:00');
    },
  );
  test('Invalid cumulative pours and times are rejected', () {
    expect(
      validateSteps(
        [
          {'time': 0, 'water': 45},
          {'time': 45, 'water': 44},
        ],
        250,
        180,
      ),
      isNotNull,
    );
    expect(
      validateSteps(
        [
          {'time': 0, 'water': 45},
          {'time': 45, 'water': 249},
        ],
        250,
        180,
      ),
      isNotNull,
    );
    expect(
      validateSteps(
        [
          {'time': 1, 'water': 250},
        ],
        250,
        180,
      ),
      isNotNull,
    );
    expect(
      validateSteps(
        [
          {'time': 0, 'water': 45},
          {'time': 180, 'water': 250},
        ],
        250,
        180,
      ),
      isNotNull,
    );
  });
}
