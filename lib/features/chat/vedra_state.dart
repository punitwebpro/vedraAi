part of 'vedra_answer.dart';

class _VedraAnswerState extends State<VedraAnswer> {
  Timer? _timer;
  int _shown = 0;

  int _next(String s, int from, int n) {
    var i = from;
    for (var w = 0; w < n; w++) {
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
      final s = widget.text;
      if (!mounted || _shown >= s.length) {
        t.cancel();
        return;
      }
      final n = (s.length / 900).ceil().clamp(1, 4).toInt();
      setState(() => _shown = _next(s, _shown, n));
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
      final raw = RegExp(r'^\s*(TITLE|SUMMARY|STEP|DIAGRAM)\s*:',
              caseSensitive: false)
          .hasMatch(full);
      if (raw) return const SizedBox.shrink();
      return SelectableText(
        _clean(shown) + (done ? '' : _cursor),
        style: const TextStyle(fontSize: 15.5, height: 1.6, color: _ink),
      );
    }

    if (!done) _putCursor(p);
    return _compose(p, done, widget.onOpenLink);
  }
}
