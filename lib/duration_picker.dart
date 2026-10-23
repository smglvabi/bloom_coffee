import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design.dart';
import 'domain.dart' show clock;

int? _parseDuration(String value) {
  final match = RegExp(r'^(\d{1,3}):([0-5]\d)$').firstMatch(value.trim());
  if (match == null) return null;
  return int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

/// A form field for a duration, chosen with wheels rather than a text keyboard.
/// The supplied controller is changed only when the user confirms the picker.
class DurationField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int minSeconds, maxSeconds;
  final String? helperText;
  final double fontSize;

  const DurationField({
    super.key,
    required this.controller,
    required this.label,
    required this.minSeconds,
    required this.maxSeconds,
    this.helperText,
    this.fontSize = 16,
  }) : assert(minSeconds >= 0),
       assert(maxSeconds >= minSeconds),
       assert(maxSeconds <= 59999);

  @override
  State<DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<DurationField> {
  final field = GlobalKey<FormFieldState<String>>();
  bool showingPicker = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
  }

  @override
  void didUpdateWidget(DurationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
      field.currentState?.didChange(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    super.dispose();
  }

  void _controllerChanged() {
    field.currentState?.didChange(widget.controller.text);
  }

  String? _validate(String? value) {
    final seconds = _parseDuration(value ?? '');
    if (seconds == null) return 'Выберите время';
    if (seconds < widget.minSeconds || seconds > widget.maxSeconds) {
      return 'Время от ${clock(widget.minSeconds)} до ${clock(widget.maxSeconds)}';
    }
    return null;
  }

  Future<void> _open() async {
    if (showingPicker) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => showingPicker = true);
    final initial =
        (_parseDuration(widget.controller.text) ?? widget.minSeconds).clamp(
          widget.minSeconds,
          widget.maxSeconds,
        );
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.bg,
      barrierLabel: 'Закрыть выбор времени',
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => _DurationPicker(
        title: widget.label,
        initialSeconds: initial,
        minSeconds: widget.minSeconds,
        maxSeconds: widget.maxSeconds,
      ),
    );
    if (!mounted) return;
    setState(() => showingPicker = false);
    if (result == null) return;
    final value = clock(result);
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    key: field,
    initialValue: widget.controller.text,
    validator: _validate,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    builder: (state) => Semantics(
      button: true,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          isFocused: showingPicker,
          isEmpty: false,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helperText,
            helperMaxLines: 3,
            errorText: state.errorText,
            errorMaxLines: 3,
            suffixIcon: Icon(
              Icons.unfold_more,
              color: context.colors.muted,
              size: 18,
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 28),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                state.value?.isNotEmpty == true ? state.value! : 'Выбрать',
                style: mono(widget.fontSize, context.colors.ink),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DurationPicker extends StatefulWidget {
  final String title;
  final int initialSeconds, minSeconds, maxSeconds;

  const _DurationPicker({
    required this.title,
    required this.initialSeconds,
    required this.minSeconds,
    required this.maxSeconds,
  });

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late final FixedExtentScrollController minutesController;
  late final FixedExtentScrollController secondsController;
  late int minutes, seconds;

  @override
  void initState() {
    super.initState();
    minutes = widget.initialSeconds ~/ 60;
    seconds = widget.initialSeconds % 60;
    minutesController = FixedExtentScrollController(initialItem: minutes);
    secondsController = FixedExtentScrollController(initialItem: seconds);
  }

  @override
  void dispose() {
    minutesController.dispose();
    secondsController.dispose();
    super.dispose();
  }

  bool get valid =>
      minutes * 60 + seconds >= widget.minSeconds &&
      minutes * 60 + seconds <= widget.maxSeconds;

  void _confirm() {
    // Read the actual visible selection, including during a ballistic fling.
    // jumpToItem cancels that motion before the sheet is dismissed.
    final pickedMinutes = minutesController.hasClients
        ? minutesController.selectedItem
        : minutes;
    final pickedSeconds = secondsController.hasClients
        ? secondsController.selectedItem
        : seconds;
    final result = pickedMinutes * 60 + pickedSeconds;
    minutesController.jumpToItem(pickedMinutes);
    secondsController.jumpToItem(pickedSeconds);
    if (result < widget.minSeconds || result > widget.maxSeconds) {
      setState(() {
        minutes = pickedMinutes;
        seconds = pickedSeconds;
      });
      return;
    }
    Navigator.pop(context, result);
  }

  Widget _wheel({
    required String keyName,
    required String semanticsLabel,
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required double itemExtent,
    required ValueChanged<int> onChanged,
  }) => Expanded(
    child: Semantics(
      label: semanticsLabel,
      child: CupertinoPicker.builder(
        key: ValueKey(keyName),
        scrollController: controller,
        itemExtent: itemExtent,
        childCount: count,
        diameterRatio: 1.5,
        squeeze: 1.05,
        useMagnifier: true,
        magnification: 1.1,
        selectionOverlay: null,
        onSelectedItemChanged: onChanged,
        itemBuilder: (context, index) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                index.toString().padLeft(2, '0'),
                style:
                    mono(
                      index == selected ? 34 : 28,
                      index == selected
                          ? context.colors.ink
                          : context.colors.muted,
                    ).copyWith(
                      fontWeight: index == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemExtent = math.max(
      56.0,
      MediaQuery.textScalerOf(context).scale(34) * 1.45,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
          maxWidth: 480,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'От ${clock(widget.minSeconds)} до ${clock(widget.maxSeconds)}',
                style: TextStyle(
                  color: valid ? colors.muted : colors.terra,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Мин',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      'Сек',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: itemExtent * 3.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: itemExtent,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: colors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Row(
                      children: [
                        _wheel(
                          keyName: 'duration-minutes',
                          semanticsLabel: 'Минуты',
                          controller: minutesController,
                          count: widget.maxSeconds ~/ 60 + 1,
                          selected: minutes,
                          itemExtent: itemExtent,
                          onChanged: (value) => setState(() => minutes = value),
                        ),
                        SizedBox(
                          width: 24,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(':', style: mono(34, colors.ink)),
                            ),
                          ),
                        ),
                        _wheel(
                          keyName: 'duration-seconds',
                          semanticsLabel: 'Секунды',
                          controller: secondsController,
                          count: 60,
                          selected: seconds,
                          itemExtent: itemExtent,
                          onChanged: (value) => setState(() => seconds = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!valid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Выберите время в указанном диапазоне.',
                    style: TextStyle(color: colors.terra, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('duration-confirm'),
                onPressed: valid ? _confirm : null,
                child: const Text('Готово'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('duration-cancel'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
