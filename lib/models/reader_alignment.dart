import 'package:flutter/painting.dart';

/// Stable Hive names. Applies only to semantic prose, never to an Office.
enum ReaderAlignment {
  start,
  justify;

  String get label => switch (this) {
    start => 'Па левым краі',
    justify => 'Па шырыні',
  };

  TextAlign get textAlign => switch (this) {
    start => TextAlign.start,
    justify => TextAlign.justify,
  };

  static ReaderAlignment fromStorage(Object? value) =>
      values.firstWhere((option) => option.name == value, orElse: () => start);
}
