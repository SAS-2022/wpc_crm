import 'package:flutter/widgets.dart';

// Text size by screen (user request 2026-10-22): Flutter's default sizes made
// buttons and fields on phones look stuffed (e.g. "Colour by" on the map), so
// narrow screens get slightly smaller text. The phone's own text-size setting
// still counts, within [minTextScale]–[maxTextScale].

/// Largest text size taken from the phone's accessibility setting: larger
/// system fonts (up to 200 %) broke tiles, cards and map overlays.
const maxTextScale = 1.2;

/// Smallest overall text size, so text stays easy to read.
const minTextScale = 0.85;

/// Text size for a screen [width] (logical pixels): small phones 90 %,
/// phones 94 %, tablets and computers 100 %.
double screenTextFactor(double width) => width < 360
    ? 0.90
    : width < 600
        ? 0.94
        : 1.0;

/// The phone's text scale × [screenTextFactor], kept within
/// [minTextScale]–[maxTextScale].
TextScaler appTextScaler(TextScaler system, double width) =>
    TextScaler.linear((system.scale(14) / 14 * screenTextFactor(width)).clamp(minTextScale, maxTextScale));
