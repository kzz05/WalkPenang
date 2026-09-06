// Map & GPS ↔ Walking & Carbon seam — the gate a route has to pass before it
// can take the app's one journey slot.
//
// Tapping Route used to push RouteSummaryView unconditionally. A tourist
// already walking to Chew Jetty who minimised that journey, wandered back to
// the map and tapped Route on somewhere else lost the walk silently: the new
// journey's start() disposed the old controller, and the kilometres, the
// elapsed time and the mini bar went with it. Nothing asked, nothing said.
//
// So every route entry now goes through here first.

import 'package:flutter/material.dart';

import '../../controllers/journey_session.dart';
import '../../theme/app_theme.dart';

/// Whether the caller may open a route to [destinationId].
///
/// Returns true only when the journey slot is free to be taken — either it
/// was free already, or the tourist has just agreed to give up the journey
/// occupying it (in which case that journey is abandoned before this returns,
/// so the route screen never opens over a session still holding the old
/// walk).
///
/// Returns false in the two cases where the current journey is kept:
///
///  * the tourist chose "Keep Current Journey";
///  * the route is to the destination they are *already* walking to, which is
///    not a replacement at all. Starting a second journey to the same place
///    would throw away the distance and time already covered to get part of
///    the way there, so the existing journey is re-opened instead — the same
///    thing tapping the mini bar does. No warning is shown, because nothing
///    is being lost.
///
/// Nothing here saves, completes or rewards anything on any path.
Future<bool> confirmRouteOverActiveJourney(
  BuildContext context, {
  required String destinationId,
}) async {
  final session = JourneySession.instance;
  final active = session.controller;

  if (active == null) return true;

  if (active.routeSummary.destinationId == destinationId) {
    // Resume rather than restart. A no-op if the journey's own screen is
    // already on top, which is the only state where it is not minimised.
    session.expand();
    return false;
  }

  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Start a new journey?'),
      content: Text(
        'You already have an active journey to '
        '${active.routeSummary.destinationName}. Starting a new route will '
        'end your current journey without awarding points.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Keep Current Journey',
            style: AppType.button.copyWith(fontSize: 14),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'End & Start New Journey',
            style: AppType.button.copyWith(
              fontSize: 14,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    ),
  );

  if (!(replace ?? false)) return false;

  // Cancel-then-release, never a bare end(): the old journey has to be
  // latched closed before the new route can start building the next one.
  session.abandon();
  return true;
}
