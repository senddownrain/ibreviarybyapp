import 'package:flutter/material.dart';

const periodLabelMap = {
  'ordinary': 'Звычайны перыяд',
  'lent': 'Вялікі пост',
  'holyweek': 'Вялікі тыдзень',
  'easter': 'Велікодны перыяд',
  'advent': 'Адвэнт',
  'christmas': 'Перыяд Божага Нараджэння',
};

const weekdayLabelMap = {
  1: 'Нядзеля',
  2: 'Панядзелак',
  3: 'Аўторак',
  4: 'Серада',
  5: 'Чацвер',
  6: 'Пятніца',
  7: 'Субота',
};

const feastTypeLabelMap = {
  'solemnity': 'Урачыстасць',
  'feast': 'Свята',
  'memorial': 'Успамін',
};

const periodColors = {
  'ordinary': Colors.green,
  'advent': Colors.purple,
  'christmas': Colors.amber,
  'lent': Colors.purple,
  'holyweek': Colors.purple,
  'easter': Colors.amber,
};

enum LiturgicalOptionSource { period, dynamic, fixed }
