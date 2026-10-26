import 'package:xml/xml.dart';

class EpgProgram {
  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;

  const EpgProgram({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });
}

List<EpgProgram> parseXmltv(String content) {
  final document = XmlDocument.parse(content);
  final programs = <EpgProgram>[];

  for (final node in document.findAllElements('programme')) {
    final channelId = node.getAttribute('channel')?.trim();
    final title = _elementText(node, 'title');
    final start = _parseXmltvDate(node.getAttribute('start'));
    final stop = _parseXmltvDate(node.getAttribute('stop'));

    if (channelId == null ||
        channelId.isEmpty ||
        title == null ||
        start == null ||
        stop == null ||
        !stop.isAfter(start)) {
      continue;
    }

    programs.add(
      EpgProgram(
        channelId: channelId,
        title: title,
        start: start,
        stop: stop,
        description: _elementText(node, 'desc'),
      ),
    );
  }

  programs.sort((a, b) => a.start.compareTo(b.start));
  return programs;
}

String? _elementText(XmlElement parent, String name) {
  for (final element in parent.findElements(name)) {
    final text = element.innerText.trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

DateTime? _parseXmltvDate(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2}):?(\d{2}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;

  try {
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6]!);
    final normalized = DateTime.utc(year, month, day, hour, minute, second);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day ||
        normalized.hour != hour ||
        normalized.minute != minute ||
        normalized.second != second) {
      return null;
    }

    if (match[7] == null) {
      return DateTime(year, month, day, hour, minute, second);
    }

    final offsetHours = int.parse(match[8]!);
    final offsetMinutes = int.parse(match[9]!);
    if (offsetHours > 23 || offsetMinutes > 59) return null;
    final offset = Duration(hours: offsetHours, minutes: offsetMinutes);
    return match[7] == '+'
        ? normalized.subtract(offset)
        : normalized.add(offset);
  } on FormatException {
    return null;
  }
}
