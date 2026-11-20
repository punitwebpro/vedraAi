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
  r'^(TITLE|SUMMARY|STEP|DIAGRAM|EXAMPLE|NOTE|CHART|IMAGE|VIDEO)\s*:\s*(.*)$',
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
      if (p.extra.isNotEmpty) p.extra[p.extra.length - 1] += _cursor;
    case 'step':
      if (p.steps.isNotEmpty) {
        final s = p.steps.last;
        if (s[1].isNotEmpty) {
          s[1] += _cursor;
        } else {
          s[0] += _cursor;
        }
      }
    case 'diagram':
      if (p.diagram.isNotEmpty) {
        final d = p.diagram.last;
        if (d[1].isNotEmpty) {
          d[1] += _cursor;
        } else {
          d[0] += _cursor;
        }
      }
  }
}

bool _isUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

class VedraAnswer extends StatefulWidget {
  final String text;

  /// true = word-by-word typing effect.
  final bool animate;

  /// true = server abhi token-by-token bhej raha hai (text badhta rahega).
  final bool streaming;

  /// Typing ke dauran scroll karne ke liye.
  final VoidCallback? onTick;

  /// Image/video par tap. url_launcher ka launchUrl yahan laga sakte ho.
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

class _VedraAnswerState extends State<VedraAnswer> {
  Timer? _timer;
  int _shown = 0;

  int _nextWord(String s, int from, int words) {
    var i = from;
    for (var w = 0; w < words; w++) {
      while (i < s.length && s[i] != ' ' && s[i] != '\n') {
        i++;
      }
      while (i < s.length && (s[i] == ' ' || s[i] == '\n')) {
        i++;
      }
      if (i >= s.length) return s.length;
    }
    return i;
  }

  void _ensureTimer() {
    if (!widget.animate) {
      _shown = widget.text.length;
      return;
    }
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final s = widget.text;
      if (_shown >= s.length) {
        t.cancel();
        return;
      }
      final words = (s.length / 900).ceil().clamp(1, 4).toInt();
      setState(() => _shown = _nextWord(s, _shown, words));
      widget.onTick?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    _ensureTimer();
  }

  @override
  void didUpdateWidget(covariant VedraAnswer old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      if (!widget.text.startsWith(old.text)) _shown = 0;
      _ensureTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.text;
    final reached = _shown >= full.length;
    final done = !widget.streaming && reached;
    final shown = reached ? full : full.substring(0, _shown);
    final p = _parse(shown, done);

    if (p == null) {
      final structured = RegExp(r'^\s*(TITLE|SUMMARY|STEP|DIAGRAM)\s*:',
              caseSensitive: false)
          .hasMatch(full);
      if (structured) return const SizedBox.shrink();
      return SelectableText(
        _clean(shown) + (done ? '' : _cursor),
        style: const TextStyle(fontSize: 15.5, height: 1.6, color: _ink),
      );
    }

    if (!done) _putCursor(p);

    final kids = <Widget>[];

    if (p.title.isNotEmpty) {
      kids.add(_HeadlineCard(title: p.title));
    }
    if (p.summary.isNotEmpty) {
      kids.add(const SizedBox(height: 14));
      kids.add(SelectableText(
        p.summary,
        style: const TextStyle(fontSize: 15, height: 1.65, color: _body),
      ));
    }
    if (p.diagram.length >= 2) {
      kids.add(const SizedBox(height: 16));
      kids.add(_DiagramView(nodes: p.diagram));
    }
    if (done && p.chart.isNotEmpty) {
      kids.add(const SizedBox(height: 16));
      kids.add(_ChartView(data: p.chart));
    }
    if (done && _isUrl(p.image)) {
      kids.add(const SizedBox(height: 16));
      kids.add(_ImageCard(url: p.image, onOpen: widget.onOpenLink));
    }
    if (done && _isUrl(p.video)) {
      kids.add(const SizedBox(height: 16));
      kids.add(_VideoCard(url: p.video, onOpen: widget.onOpenLink));
    }
    if (p.steps.isNotEmpty) kids.add(const SizedBox(height: 20));
    for (var i = 0; i < p.steps.length; i++) {
      if (i > 0) kids.add(const _Arrow());
      kids.add(_StepCard(
        number: i + 1,
        title: p.steps[i][0],
        detail: p.steps[i][1],
      ));
    }
    if (p.example.isNotEmpty) {
      kids.add(const SizedBox(height: 18));
      kids.add(_InfoCard(
        icon: Icons.lightbulb_outline,
        label: 'Example',
        text: p.example,
      ));
    }
    if (p.note.isNotEmpty) {
      kids.add(const SizedBox(height: 12));
      kids.add(_InfoCard(
        icon: Icons.info_outline,
        label: 'Yaad rakho',
        text: p.note,
        soft: true,
      ));
    }
    for (final e in p.extra) {
      kids.add(const SizedBox(height: 8));
      kids.add(SelectableText(
        e,
        style: const TextStyle(fontSize: 14, height: 1.6, color: _body),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: kids,
    );
  }
}

// ---------------------------------------------------------------------------
// Headline
// ---------------------------------------------------------------------------

class _HeadlineCard extends StatelessWidget {
  final String title;
  const _HeadlineCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_violet, _pink],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _violet.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'VEDRA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            title,
            style: const TextStyle(
              fontSize: 25,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diagram
// ---------------------------------------------------------------------------

class _DiagramView extends StatelessWidget {
  final List<List<String>> nodes;
  const _DiagramView({required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4DDFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 18, color: _violet),
              SizedBox(width: 8),
              Text(
                'Diagram',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < nodes.length; i++) ...[
            _DiagramNode(
              color: _palette[i % _palette.length],
              label: nodes[i][0],
              detail: nodes[i][1],
            ),
            if (i < nodes.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 26, color: _violet),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DiagramNode extends StatelessWidget {
  final Color color;
  final String label;
  final String detail;
  const _DiagramNode({
    required this.color,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.78)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            SelectableText(
              detail,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart  (CHART: Title|Label=40;Label2=70  ya  CHART: Label=40, Label2=70)
// ---------------------------------------------------------------------------

class _ChartView extends StatelessWidget {
  final String data;
  const _ChartView({required this.data});

  String get _title {
    final i = data.indexOf('|');
    return i == -1 ? '' : data.substring(0, i).trim();
  }

  String get _body {
    final i = data.indexOf('|');
    return i == -1 ? data : data.substring(i + 1);
  }

  List<MapEntry<String, double>> _items() {
    final out = <MapEntry<String, double>>[];
    for (final part in _body.split(RegExp(r'[,;]'))) {
      final t = part.trim();
      if (t.isEmpty) continue;
      final i = t.lastIndexOf(RegExp(r'[=:]'));
      if (i == -1) continue;
      final label = t.substring(0, i).trim();
      final v = double.tryParse(
          t.substring(i + 1).replaceAll('%', '').trim());
      if (label.isEmpty || v == null) continue;
      out.add(MapEntry(label, v));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (items.length < 2) return const SizedBox.shrink();
    final maxV = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAEAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 19, color: _blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _title.isEmpty ? 'Chart' : _title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BarRow(
                label: items[i].key,
                value: items[i].value,
                fraction: (items[i].value / safeMax).clamp(0.0, 1.0),
                color: _palette[i % _palette.length],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double fraction;
  final Color color;
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final txt =
        value == value.roundToDouble() ? value.toInt().toString() : '$value';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            Text(
              txt,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, c) {
          return Stack(
            children: [
              Container(
                height: 12,
                width: c.maxWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F7),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, f, _) => Container(
                  height: 12,
                  width: c.maxWidth * f,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.65)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image
// ---------------------------------------------------------------------------

class _ImageCard extends StatelessWidget {
  final String url;
  final void Function(String url)? onOpen;
  const _ImageCard({required this.url, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen == null ? null : () => onOpen!(url),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, prog) {
                if (prog == null) return child;
                return Container(
                  color: _soft,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: _violet),
                  ),
                );
              },
              errorBuilder: (context, err, st) => Container(
                color: _soft,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        size: 32, color: _violet),
                    SizedBox(height: 6),
                    Text('Image load nahi hui',
                        style: TextStyle(fontSize: 12.5, color: _body)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video  (YouTube thumbnail + play button; tap -> onOpenLink)
// ---------------------------------------------------------------------------

class _VideoCard extends StatelessWidget {
  final String url;
  final void Function(String url)? onOpen;
  const _VideoCard({required this.url, this.onOpen});

  String? _youtubeId() {
    final m = RegExp(
      r'(?:youtube\.com/(?:watch\?v=|shorts/|embed/)|youtu\.be/)([\w-]{11})',
    ).firstMatch(url);
    return m?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final id = _youtubeId();
    return GestureDetector(
      onTap: onOpen == null ? null : () => onOpen!(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1B4B), Color(0xFF581C87)],
                  ),
                ),
              ),
              if (id != null)
                Image.network(
                  'https://img.youtube.com/vi/$id/hqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                ),
              Container(color: Colors.black.withOpacity(0.25)),
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 38, color: _violet),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Video dekho',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Steps, arrow, info cards
// ---------------------------------------------------------------------------

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  const _StepCard({
    required this.number,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final color = _palette[(number - 1) % _palette.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [color, color.withOpacity(0.7)]),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    detail,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: _body,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 9),
          child: Icon(Icons.arrow_downward_rounded,
              size: 20, color: Color(0xFFB9A8F5)),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final bool soft;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.text,
    this.soft = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = soft ? _blue : const Color(0xFFF59E0B);
    final bg = soft ? const Color(0xFFEFF6FF) : const Color(0xFFFFF8E6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
