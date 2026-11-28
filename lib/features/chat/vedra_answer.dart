// Vedra answer: Canva-style jawab.
import 'dart:async';

import 'package:flutter/material.dart';

part 'vedra_parse.dart';
part 'vedra_cards.dart';
part 'vedra_visuals.dart';
part 'vedra_media.dart';
part 'vedra_state.dart';
part 'vedra_compose.dart';

const _cursor = '\u258C';
const _ink = Color(0xFF16162B);
const _body = Color(0xFF474765);
const _violet = Color(0xFF7C3AED);
const _pink = Color(0xFFEC4899);
const _blue = Color(0xFF3B82F6);
const _soft = Color(0xFFF5F3FF);
const _line = Color(0xFFEAEAF2);
const _palette = <Color>[
  _violet,
  _pink,
  _blue,
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
];

class VedraAnswer extends StatefulWidget {
  final String text;
  final bool animate;
  final bool streaming;
  final VoidCallback? onTick;
  final void Function(String url)? onOpenLink;

  const VedraAnswer({
    super.key,
    required this.text,
    this.animate = false,
    this.streaming = false,
    this.onTick,
    this.onOpenLink,
  });

  @override
  State<VedraAnswer> createState() => _VedraAnswerState();
}
