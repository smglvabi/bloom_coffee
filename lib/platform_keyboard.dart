import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';

/// Gives iOS number pads a dismiss action without covering form controls.
class IosKeyboardAccessory extends StatelessWidget {
  final Widget child;

  const IosKeyboardAccessory({super.key, required this.child});

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (Theme.of(context).platform != TargetPlatform.iOS ||
        media.viewInsets.bottom == 0) {
      return child;
    }
    final accessoryHeight = math.max(height, media.textScaler.scale(14) + 16);
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaQuery(
          data: media.copyWith(
            viewInsets: media.viewInsets.copyWith(
              bottom: media.viewInsets.bottom + accessoryHeight,
            ),
          ),
          child: child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: media.viewInsets.bottom,
          height: accessoryHeight,
          child: Material(
            color: context.colors.bg,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.colors.line)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('ios-keyboard-done'),
                  onPressed: () =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  child: const Text('Готово'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
