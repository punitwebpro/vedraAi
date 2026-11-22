// lib/features/chat/vedra_answer.dart
//
// Vedra ke jawab ko Canva jaisa dikhata hai:
// headline card, summary, diagram, chart, image, video, step cards,
// example + note cards. Word-by-word typing aur streaming support.
//
// AI ko is format me jawab dene ke liye server prompt me ye likho:
//   TITLE: chhoti headline
//   SUMMARY: 2-3 line saaf explanation
//   DIAGRAM: Node1|chhota explain -> Node2|explain -> Node3|explain
//   CHART: Title|Label1=40;Label2=70;Label3=55
//   IMAGE: https://...jpg
//   VIDEO: https://youtube.com/watch?v=...
//   GEN: detailed English image prompt (nayi image banane ke liye)
//   STEP: Step title|Step ka detail      (kai baar)
//   EXAMPLE: ek asaan example
//   NOTE: ek zaroori baat

import 'dart:async';

import 'package:flutter/material.dart';

const _cursor = '\u258C';
const _ink = Color(0xFF16162B);
const _body = Color(0xFF474765);
const _violet = Color(0xFF7C3AED);
const _pink = Color(0xFFEC4899);
const _blue = Color(0xFF3B82F6);
const _soft = Color(0xFFF5F3FF);

const _palette = <Color>[
  Color(0xFF7C3AED),
  Color(0xFFEC4899),
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
];

final _keyRe = RegExp(
  r'^(TITLE|SUMMARY|STEP|DIAGRAM|EXAMPLE|NOTE|CHART|IMAGE|VIDEO|GEN)\s*:\s*(.*)$',
  caseSensitive: false,
);

String _clean(String s) {
  return s
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .replaceFirst(RegExp(r'^\s*#+\s*'), '')
      .trim();
}

List<String> _pair(String v) {
  final i = v.indexOf('|');
  if (i == -1) return [v.trim(), ''];
  return [v.substring(0, i).trim(), v.substring(i + 1).trim()];
}

class _Parsed {
  String title = '';
  String summary = '';
  String example = '';
  String note = '';
  String chart = '';
  String image = '';
  String video = '';
  String gen = '';
  String last = '';
  final List<List<String>> steps = [];
  final List<List<String>> diagram = [];
  final List<String> extra = [];
}

_Parsed? _parse(String text, bool done) {
  final p = _Parsed();
  final lines = text.split('\n');
  for (var n = 0; n < lines.length; n++) {
    final line = _clean(lines[n]);
    if (line.isEmpty) continue;
    final m = _keyRe.firstMatch(line);
    if (m == null) {
      if (!done && n == lines.length - 1) continue;
      p.extra.add(line);
      p.last = 'extra';
      continue;
    }
    final key = m.group(1)!.toUpperCase();
    final val = m.group(2)!.trim();
    p.last = key.toLowerCase();
    switch (key) {
      case 'TITLE':
        p.title = val;
      case 'SUMMARY':
        p.summary = val;
      case 'EXAMPLE':
        p.example = val;
      case 'NOTE':
        p.note = val;
      case 'CHART':
        p.chart = val;
      case 'IMAGE':
        p.image = val;
      case 'VIDEO':
        p.video = val;
      case 'GEN':
        p.gen = val;
      case 'DIAGRAM':
        for (final part in val.split('->')) {
          final t = part.trim();
          if (t.isEmpty) continue;
          p.diagram.add(_pair(t));
        }
      case 'STEP':
        p.steps.add(_pair(val));
    }
  }
  if (p.title.isEmpty && p.steps.isEmpty && p.diagram.isEmpty) return null;
  return p;
}

void _putCursor(_Parsed p) {
  switch (p.last) {
    case 'title':
      p.title += _cursor;
    case 'summary':
      p.summary += _cursor;
    case 'example':
      p.example += _cursor;
    case 'note':
      p.note += _cursor;
    case 'extra':
      if
