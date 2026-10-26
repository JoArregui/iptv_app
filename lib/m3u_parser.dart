class M3U8Entry {
  final String? title;
  final String url;
  final String? category;

  const M3U8Entry({this.title, required this.url, this.category});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! M3U8Entry) return false;
    return url == other.url &&
        title == other.title &&
        category == other.category;
  }

  @override
  int get hashCode => Object.hash(url, title, category);

  @override
  String toString() =>
      'M3U8Entry(title: $title, url: $url, category: $category)';
}

List<M3U8Entry> parseM3U(String content, {Uri? baseUri}) {
  final entries = <M3U8Entry>[];
  String? pendingTitle;
  String? pendingCategory;

  for (final line in content.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.startsWith('#EXTINF')) {
      pendingTitle = _attribute(trimmed, 'tvg-name') ?? _displayName(trimmed);
      pendingCategory = _attribute(trimmed, 'group-title');
      continue;
    }

    if (trimmed.startsWith('#EXTGRP:')) {
      if (pendingTitle != null) {
        pendingCategory = trimmed.substring('#EXTGRP:'.length).trim();
      }
      continue;
    }

    if (trimmed.startsWith('#') || pendingTitle == null) continue;

    try {
      final streamUri = Uri.parse(trimmed);
      final resolvedUri = streamUri.hasScheme || baseUri == null
          ? streamUri
          : baseUri.resolveUri(streamUri);
      entries.add(M3U8Entry(
        title: pendingTitle.isEmpty ? null : pendingTitle,
        url: resolvedUri.toString(),
        category: pendingCategory?.isEmpty == true ? null : pendingCategory,
      ));
    } on FormatException {
      // Ignore malformed stream URLs and wait for the next entry.
    } finally {
      pendingTitle = null;
      pendingCategory = null;
    }
  }

  return entries;
}

String? _attribute(String line, String name) {
  return RegExp('(?:^|\\s)$name="([^"]*)"').firstMatch(line)?.group(1);
}

String? _displayName(String line) {
  var insideQuotes = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      insideQuotes = !insideQuotes;
    } else if (character == ',' && !insideQuotes) {
      final name = line.substring(index + 1).trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
}
