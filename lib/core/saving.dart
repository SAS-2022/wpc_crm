import 'package:flutter/material.dart';

/// Number of saves in progress anywhere in the app (repository writes run
/// through [saving]); [SavingBar] shows a progress bar while it's above 0.
final savingCount = ValueNotifier<int>(0);

/// Runs [write] and shows the app-wide progress bar until it finishes.
Future<T> saving<T>(Future<T> Function() write) async {
  savingCount.value++;
  try {
    return await write();
  } finally {
    savingCount.value--;
  }
}

/// Thin progress bar along the top of the app while something is saving
/// (in `MaterialApp.builder`, over every screen and dialog).
class SavingBar extends StatelessWidget {
  const SavingBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: savingCount,
                builder: (context, n, _) => AnimatedOpacity(
                  opacity: n > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: SafeArea(
                    bottom: false,
                    child: n > 0 ? const LinearProgressIndicator(minHeight: 3) : const SizedBox(height: 3),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

/// A button label that turns into a small spinner while [busy] (the button
/// keeps its size).
class BusyLabel extends StatelessWidget {
  const BusyLabel({super.key, required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!busy) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: child),
        const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}

/// Spinner in place of a button's icon while busy.
Widget busyIcon(bool busy, Widget icon) =>
    busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : icon;
