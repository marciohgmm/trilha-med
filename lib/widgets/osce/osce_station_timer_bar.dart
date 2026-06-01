import 'package:flutter/material.dart';

import '../../models/osce_models.dart';
import 'osce_sync_timer.dart';

/// Cronômetro de 10 min em faixa própria (evita corte no AppBar).
class OsceStationTimerBar extends StatelessWidget {
  final OsceRoomModel room;
  final VoidCallback? onTimerEnded;

  const OsceStationTimerBar({
    super.key,
    required this.room,
    this.onTimerEnded,
  });

  @override
  Widget build(BuildContext context) {
    final showTimer = room.stationStarted ||
        room.status == OsceRoomStatus.running;
    if (!showTimer) return const SizedBox.shrink();

    final safe = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 + safe.left,
        8,
        12 + safe.right,
        4,
      ),
      child: OsceSyncTimer(
        room: room,
        expandWidth: true,
        onTimerEnded: onTimerEnded,
      ),
    );
  }
}
