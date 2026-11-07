import 'package:flutter/material.dart';

/// Language-neutral values persisted in the existing settings box.
enum ReaderTextAlignment {
  start,
  justify;

  TextAlign get textAlign => switch (this) {
    start => TextAlign.start,
    justify => TextAlign.justify,
  };

  String get label => switch (this) {
    start => 'Па левым краі',
    justify => 'Па шырыні',
  };

  static ReaderTextAlignment fromStorage(Object? value) =>
      value == 'justify' ? justify : start;
}

/// Intentional single line breaks identify verse, hymns and fixed responses.
/// Blank lines between prose paragraphs remain ordinary paragraph boundaries.
TextAlign readerProseAlignment(ReaderTextAlignment preference, String text) =>
    RegExp(r'(?<!\n)\n(?!\n)|\r').hasMatch(text)
    ? TextAlign.start
    : preference.textAlign;
