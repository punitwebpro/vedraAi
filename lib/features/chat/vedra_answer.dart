import 'package:flutter/material.dart';

const Color _ink = Color(0xFF111111);
const Color _body = Color(0xFF3B3B3B);
const Color _soft = Color(0xFF777777);
const Color _line = Color(0xFFE3E3E3);

class _Parsed {
  String title = '';
  String summary = '';
  String example = '';
  String note = '';
  final List<List<String>> steps = [];
  final List<String> extra = [];
}

String _clean(String s) => s
    .replaceAll('**', '')
    .replaceAll('`', '')
    .replaceFirst(RegExp(r'^#+\s*'), '')
    .trim();

_Parsed? _parse(String text) {
  final p = _Parsed();
  final re = RegExp(
    r'^(TITLE|SUMMARY|STEP|EXAMPLE|NOTE)\s*:\s*(.*)$',
    caseSensitive: false,
  );
  for (final raw in text.split('\n')) {
    final line = _clean(raw);
    if (line.isEmpty) continue;
    final m = re.firstMatch(line);
    if (m == null) {
      p.extra.add(line);
      continue;
    }
    final key = m.group(1)!.toUpperCase();
    final val = m.group(2)!.trim();
    switch (key) {
      case 'TITLE':
        p.title = val;
      case 'SUMMARY':
        p.summary = val;
      case 'EXAMPLE':
        p.example = val;
      case 'NOTE':
        p.note = val;
      case 'STEP':
        final i = val.indexOf('|');
        if (i == -1) {
          p.steps.add([val, '']);
        } else {
          p.steps.add([val.substring(0, i).trim(), val.substring(i + 1).trim()]);
        }
    }
  }
  if (p.title.isEmpty && p.steps.isEmpty) return null;
  return p;
}

class VedraAnswer extends StatelessWidget {
  final String text;
  const VedraAnswer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = _parse(text);
    if (p == null) {
      return SelectableText(
        _clean(text),
        style: const TextStyle(fontSize: 15.5, height: 1.6, color: _ink),
      );
    }
    final kids = <Widget>[];
    if (p.title.isNotEmpty) {
      kids.add(SelectableText(
        p.title,
        style: const TextStyle(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ));
    }
    if (p.summary.isNotEmpty) {
      kids.add(const SizedBox(height: 10));
      kids.add(SelectableText(
        p.summary,
        style: const TextStyle(fontSize: 14.5, height: 1.65, color: _body),
      ));
    }
    if (p.steps.isNotEmpty) kids.add(const SizedBox(height: 18));
    for (var i = 0; i < p.steps.length; i++) {
      if (i > 0) kids.add(const _Arrow());
      kids.add(_StepCard(
        number: i + 1,
        title: p.steps[i][0],
        detail: p.steps[i][1],
      ));
    }
    if (p.example.isNotEmpty) {
      kids.add(const SizedBox(height: 16));
      kids.add(_InfoCard(icon: Icons.lightbulb_outline, text: p.example));
    }
    if (p.note.isNotEmpty) {
      kids.add(const SizedBox(height: 12));
      kids.add(_InfoCard(icon: Icons.info_outline, text: p.note, soft: true));
    }
    for (final e in p.extra) {
      kids.add(const SizedBox(height: 8));
      kids.add(SelectableText(
        e,
        style: const TextStyle(fontSize: 13.5, height: 1.6, color: _body),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: kids,
    );
  }
}

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
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
    return const SizedBox(
      height: 30,
      child: Center(
        child: Icon(Icons.arrow_downward, size: 18, color: _soft),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool soft;
  const _InfoCard({required this.icon, required this.text, this.soft = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft ? const Color(0xFFF6F6F6) : Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _soft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: soft ? 12.5 : 13.5,
                height: 1.6,
                color: soft ? _soft : _body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
