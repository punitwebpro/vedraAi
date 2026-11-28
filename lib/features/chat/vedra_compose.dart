part of 'vedra_answer.dart';

Widget _compose(_Parsed p, bool done, void Function(String)? open) {
  final k = <Widget>[];
  void gap(double h) => k.add(SizedBox(height: h));

  if (p.title.isNotEmpty) k.add(_Headline(p.title));
  if (p.summary.isNotEmpty) {
    gap(14);
    k.add(_txt(p.summary, 15, _body));
  }
  if (p.diagram.length >= 2) {
    gap(16);
    k.add(_Diagram(p.diagram));
  }
  if (done && p.chart.isNotEmpty) {
    gap(16);
    k.add(_Chart(p.chart));
  }
  if (done && _isUrl(p.image)) {
    gap(16);
    k.add(_Img(p.image, open));
  }
  if (done && p.gen.isNotEmpty) {
    gap(16);
    k.add(_Img(_genUrl(p.gen), open));
  }
  if (done && _isUrl(p.video)) {
    gap(16);
    k.add(_Video(p.video, open));
  }
  if (p.steps.isNotEmpty) gap(20);
  for (var i = 0; i < p.steps.length; i++) {
    if (i > 0) k.add(const _Arrow());
    k.add(_Step(i + 1, p.steps[i][0], p.steps[i][1]));
  }
  if (p.example.isNotEmpty) {
    gap(18);
    k.add(_Info(Icons.lightbulb_outline, 'Example', p.example,
        const Color(0xFFF59E0B), const Color(0xFFFFF8E6)));
  }
  if (p.note.isNotEmpty) {
    gap(12);
    k.add(_Info(Icons.info_outline, 'Yaad rakho', p.note, _blue,
        const Color(0xFFEFF6FF)));
  }
  for (final e in p.extra) {
    gap(8);
    k.add(_txt(e, 14, _body));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: k);
}
