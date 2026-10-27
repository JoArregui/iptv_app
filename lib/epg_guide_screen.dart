import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'epg_parser.dart';
import 'm3u_parser.dart';

class EpgGuideState {
  const EpgGuideState({
    required this.channels,
    required this.programs,
    required this.isLoading,
    required this.statusMessage,
  });

  final List<M3U8Entry> channels;
  final List<EpgProgram> programs;
  final bool isLoading;
  final String statusMessage;
}

class EpgGuideScreen extends StatelessWidget {
  const EpgGuideScreen({
    required this.state,
    this.onConfigureSource,
    this.onRefresh,
    super.key,
  });

  final ValueListenable<EpgGuideState> state;
  final VoidCallback? onConfigureSource;
  final VoidCallback? onRefresh;

  static const _channelWidth = 124.0;
  static const _hourWidth = 96.0;
  static const _hoursInDay = 24;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EpgGuideState>(
      valueListenable: state,
      builder: (context, guideState, _) => _buildGuide(context, guideState),
    );
  }

  Widget _buildGuide(BuildContext context, EpgGuideState guideState) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day, now.hour);
    final dayEnd = dayStart.add(const Duration(hours: _hoursInDay));
    final channelsWithIds = guideState.channels
        .where((channel) => channel.tvgId?.trim().isNotEmpty == true)
        .toList();
    final availablePrograms = guideState.programs.where((program) {
      final localStart = program.start.toLocal();
      final localStop = program.stop.toLocal();
      return localStart.isBefore(dayEnd) && localStop.isAfter(dayStart);
    }).toList();
    final programsByChannel = <String, List<EpgProgram>>{};
    for (final program in availablePrograms) {
      programsByChannel
          .putIfAbsent(program.channelId.trim().toLowerCase(), () => [])
          .add(program);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guía de programación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar guía',
            onPressed: guideState.isLoading ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cambiar fuente EPG',
            onPressed: onConfigureSource,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: guideState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : channelsWithIds.isEmpty || guideState.programs.isEmpty
            ? _buildEmptyState(context, guideState.statusMessage)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _dateLabel(dayStart),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${availablePrograms.length} programas',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _channelWidth + _hoursInDay * _hourWidth,
                        child: Column(
                          children: [
                            _buildTimeRuler(context, dayStart),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: channelsWithIds.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final channel = channelsWithIds[index];
                                  final channelPrograms =
                                      programsByChannel[channel.tvgId!
                                          .trim()
                                          .toLowerCase()] ??
                                      [];
                                  return _buildChannelRow(
                                    context,
                                    channel,
                                    channelPrograms,
                                    dayStart,
                                    dayEnd,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTimeRuler(BuildContext context, DateTime start) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          SizedBox(
            width: _channelWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                'CANAL',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          ...List.generate(_hoursInDay, (hour) {
            return SizedBox(
              width: _hourWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hour.isEven
                      ? _timeLabel(start.add(Duration(hours: hour)))
                      : '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChannelRow(
    BuildContext context,
    M3U8Entry channel,
    List<EpgProgram> programs,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final title = channel.title ?? channel.tvgId ?? 'Canal';

    return SizedBox(
      height: 72,
      child: Row(
        children: [
          SizedBox(
            width: _channelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _hoursInDay * _hourWidth,
            child: ClipRect(
              child: Stack(
                children: [
                  for (final program in programs)
                    _buildProgramTile(context, program, dayStart, dayEnd),
                  if (programs.isEmpty)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          'Sin programas en este periodo',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramTile(
    BuildContext context,
    EpgProgram program,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final start = program.start.toLocal().isBefore(dayStart)
        ? dayStart
        : program.start.toLocal();
    final stop = program.stop.toLocal().isAfter(dayEnd)
        ? dayEnd
        : program.stop.toLocal();
    final left = start.difference(dayStart).inMinutes * _hourWidth / 60;
    final width = stop.difference(start).inMinutes * _hourWidth / 60;
    final now = DateTime.now();
    final isNow = !now.isBefore(start) && now.isBefore(stop);
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      left: left + 2,
      top: 7,
      bottom: 7,
      width: (width - 4).clamp(1, _hoursInDay * _hourWidth),
      child: Tooltip(
        message:
            '${_timeLabel(program.start.toLocal())}–${_timeLabel(program.stop.toLocal())}\n${program.title}${program.description == null ? '' : '\n${program.description}'}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: isNow
                ? colorScheme.primary.withValues(alpha: 0.24)
                : const Color(0xFF1A2833),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isNow ? colorScheme.primary : const Color(0xFF30414F),
            ),
          ),
          child: Text(
            program.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
              color: isNow ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onConfigureSource != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onConfigureSource,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Introducir URL XMLTV'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime start) =>
      'Próximas 24 horas · ${_timeLabel(start)} · ${start.day}/${start.month}/${start.year}';

  String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
