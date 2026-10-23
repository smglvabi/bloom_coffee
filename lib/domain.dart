import 'dart:convert';
import 'dart:math';

typedef Json = Map<String, dynamic>;
String uid() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
Json clone(Json value) => jsonDecode(jsonEncode(value)) as Json;
double number(dynamic value) => (value as num).toDouble();
String amount(num value) =>
    (value == value.roundToDouble()
            ? value.toInt().toString()
            : ((value * 10).round() / 10).toStringAsFixed(1))
        .replaceAll('.', ',');
String clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
String dateLabel(String? date) {
  if (date == null || date.isEmpty) return 'Не указана';
  final d = DateTime.parse(date).toLocal();
  const months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String ratio(Json recipe) =>
    '1:${amount(number(recipe['water']) / number(recipe['dose']))}';
const ratings = ['Понравилось', 'Нормально', 'Не понравилось'];

Json defaultEquipment() => {
  'id': 'default',
  'name': 'Мой V60',
  'grinder': 'Timemore C3',
  'unit': 'кликов',
  'dripper': 'V60',
  'size': '02',
  'filter': 'Hario, бумажный',
  'water': 'Фильтрованная',
};

Json newRecipe(String packId, Json equipment) => {
  'id': uid(),
  'packId': packId,
  'name': 'Мой V60',
  'method': 'V60',
  'dose': 15.0,
  'water': 250.0,
  'temperature': 93.0,
  'grinder': equipment['grinder'],
  'grind': '18',
  'unit': equipment['unit'],
  'dripper': '${equipment['dripper']} ${equipment['size']}',
  'filter': equipment['filter'],
  'brewWater': equipment['water'],
  'duration': 180,
  'steps': [
    {'time': 0, 'water': 45},
    {'time': 45, 'water': 125},
    {'time': 75, 'water': 195},
    {'time': 105, 'water': 250},
  ],
};

/// Cumulative targets are scaled independently, with the final target exact.
List<Json> scaleSteps(List<dynamic> steps, double oldWater, double newWater) {
  if (steps.isEmpty) {
    return [
      {'time': 0, 'water': newWater.round()},
    ];
  }
  return [
    for (var i = 0; i < steps.length; i++)
      {
        'time': steps[i]['time'],
        'water': i == steps.length - 1
            ? newWater.round()
            : (number(steps[i]['water']) / oldWater * newWater).round(),
      },
  ];
}

int currentStep(Json recipe, int elapsed) {
  final steps = recipe['steps'] as List;
  var index = 0;
  for (var i = 0; i < steps.length; i++) {
    if (elapsed >= (steps[i]['time'] as int)) index = i;
  }
  return index;
}

String? validateSteps(List<Json> steps, double water, int duration) {
  if (steps.isEmpty) return 'Добавьте хотя бы одно вливание.';
  if (steps.first['time'] != 0) {
    return 'Первое вливание должно начинаться в 0:00.';
  }
  var previousTime = -1;
  var previousWater = 0.0;
  for (final step in steps) {
    final time = step['time'] as int;
    final target = number(step['water']);
    if (time <= previousTime || time >= duration) {
      return 'Время этапов должно возрастать и быть меньше общего времени.';
    }
    if (target <= previousWater || target > water) {
      return 'Суммарный вес должен возрастать и не превышать массу воды.';
    }
    previousTime = time;
    previousWater = target;
  }
  if (previousWater != water) {
    return 'Последний этап должен совпадать с общей массой воды.';
  }
  return null;
}

class InsufficientCoffee implements Exception {
  final double remaining;
  InsufficientCoffee(this.remaining);
}
