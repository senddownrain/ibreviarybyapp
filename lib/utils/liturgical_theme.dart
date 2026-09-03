import 'package:flutter/material.dart';
import 'package:mybrev_flutter/models/day.dart';

const liturgicalPeriodColors = <String, Color>{
  'ordinary': Color(0xFF4D8A5B),
  'advent': Color(0xFF7A57A7),
  'lent': Color(0xFF6F4A92),
  'holyweek': Color(0xFF5B3B83),
  'christmas': Color(0xFFB07A1E),
  'easter': Color(0xFFBD8A24),
};

const _solemnities = {'solemnitas', 'solemnity', 'урачыстасць', 'ўрачыстасць'};
const _feasts = {'festum', 'feast', 'свята'};
const _memorials = {
  'memoria',
  'memoria-ad-libitum',
  'memorial',
  'memory',
  'успамін',
};

Color liturgicalColorForDay(
  LiturgicalDay? day, {
  String fallbackPeriodType = 'ordinary',
}) {
  if (day?.field('_theme') == 'requiem' ||
      day?.field('_kind') == 'office-for-dead') {
    return const Color(0xFF67546B);
  }
  final rank = (day?.rank ?? day?.field('_feastType') ?? '')
      .trim()
      .toLowerCase();
  final feast = (day?.feast ?? '').toLowerCase().replaceFirst('feast-', '');
  final templates = day?.data['_templates'];
  final templateText = templates is List ? templates.join(' ') : '';
  final text = [
    day?.feastName,
    day?.title,
    day?.field('_currentVersion'),
    templateText,
  ].whereType<String>().join(' ').toLowerCase();
  final red =
      feast == 'pentecost' ||
      feast == 'heartofjesus' ||
      text.contains('мучан') ||
      text.contains('апостал') ||
      text.contains('martyr') ||
      text.contains('apostle') ||
      text.contains('святога духа') ||
      text.contains('духа святога') ||
      (text.contains('сэрц') && text.contains('езус'));
  if (red) return const Color(0xFFB33A3A);
  if (_solemnities.contains(rank)) return const Color(0xFFB88719);
  final marian = templateText.toLowerCase().contains('blessed-virgin-mary');
  if (rank.isNotEmpty && marian) return const Color(0xFF5E9EC5);
  if (_feasts.contains(rank) || _memorials.contains(rank)) {
    return const Color(0xFF8F7D52);
  }
  final period =
      day?.field('_contextPeriodType') ?? day?.periodType ?? fallbackPeriodType;
  return liturgicalPeriodColors[period] ?? const Color(0xFF55707C);
}
