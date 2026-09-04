// ---------------------------------------------------------------------------
// leaderboard_row.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The pieces LeaderboardScreen is built from: the podium across the top and
// the ranked rows underneath.
//
// Like the rest of Module 5's widgets these calculate nothing. Ranks come
// from LeaderboardRanking, points from the award formula; this formats what
// it is handed.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/leaderboard_entry_model.dart';
import '../../theme/app_theme.dart';
import '../../views/widgets/wp_components.dart';

/// Colours for the three podium places.
///
/// Drawn from the shared palette rather than a private set of gold/silver/
/// bronze hex values — [AppColors.rewards] is already the app's points
/// colour, so first place being that colour ties the board to the points
/// badge the tourist sees everywhere else.
Color rankColor(int rank) {
  switch (rank) {
    case 1:
      return AppColors.rewards;
    case 2:
      return AppColors.placeholder;
    case 3:
      return AppColors.primaryDeep;
    default:
      return AppColors.outline;
  }
}

/// A tourist's profile picture, or their initials when they have none.
///
/// Not [WpAvatar]: that falls back to a generic person icon, which would make
/// every photo-less row on the board look like the same tourist. Initials
/// keep the rows distinguishable at a glance, which is the one thing a
/// leaderboard has to do.
class LeaderboardAvatar extends StatelessWidget {
  final LeaderboardEntryModel entry;
  final double radius;

  /// Ring drawn around the avatar — the podium colour, or null for no ring.
  final Color? ringColor;

  const LeaderboardAvatar({
    super.key,
    required this.entry,
    this.radius = 20,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = entry.photoUrl;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.backgroundDeep,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: photoUrl == null
              ? _initials()
              : CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  // Both fall back to the initials rather than to a spinner or
                  // a broken-image icon: a row that briefly shows the wrong
                  // thing is worse here than one that never changes.
                  placeholder: (context, url) => _initials(),
                  errorWidget: (context, url, error) => _initials(),
                ),
        ),
      ),
    );

    if (ringColor == null) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: avatar,
    );
  }

  Widget _initials() {
    return Container(
      color: AppColors.backgroundDeep,
      alignment: Alignment.center,
      child: Text(
        entry.initials,
        style: AppType.heading.copyWith(
          fontSize: radius * 0.8,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}

/// The top three, side by side, first place raised in the middle.
///
/// The centre-raised arrangement is the one people already read as a podium,
/// so the tourist with the most points is identifiable before a single number
/// is read — which is what the screen is for.
class LeaderboardPodium extends StatelessWidget {
  /// Up to three entries, best first. A shorter list renders that many
  /// places, so a board with two tourists on it does not draw an empty plinth.
  final List<RankedEntry> places;

  /// Highlighted as "you". Empty when nobody is signed in.
  final String currentUserId;

  const LeaderboardPodium({
    super.key,
    required this.places,
    this.currentUserId = '',
  });

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();

    final first = places.first;
    final second = places.length > 1 ? places[1] : null;
    final third = places.length > 2 ? places[2] : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _place(second)),
          const SizedBox(width: 10),
          Expanded(child: _place(first)),
          const SizedBox(width: 10),
          Expanded(child: _place(third)),
        ],
      ),
    );
  }

  /// An absent place renders as blank space of the same width, so the winner
  /// stays centred on a board with only one or two tourists on it.
  Widget _place(RankedEntry? ranked) {
    if (ranked == null) return const SizedBox.shrink();
    return _PodiumPlace(
      ranked: ranked,
      isCurrentUser: ranked.entry.userId == currentUserId,
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final RankedEntry ranked;
  final bool isCurrentUser;

  const _PodiumPlace({required this.ranked, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final color = rankColor(ranked.rank);
    final leader = ranked.isLeader;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A crown on first place only. The rank number is on the plinth
        // below, so this is the redundant cue that makes the winner readable
        // without reading — the whole reason the podium is here.
        if (leader) ...[
          Icon(Icons.emoji_events, size: 22, color: color),
          const SizedBox(height: 6),
        ],
        LeaderboardAvatar(
          entry: ranked.entry,
          radius: leader ? 32 : 26,
          ringColor: color,
        ),
        const SizedBox(height: 10),
        Text(
          isCurrentUser ? 'You' : ranked.entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(
            fontSize: 13,
            fontWeight: leader ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          // First place stands taller. The height difference is what carries
          // the ranking at a glance; the numbers only confirm it.
          padding: EdgeInsets.fromLTRB(8, leader ? 16 : 11, 8, leader ? 16 : 11),
          decoration: BoxDecoration(
            color: leader ? AppColors.surface : AppColors.card,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: isCurrentUser ? AppColors.primaryDeep : AppColors.outline,
              width: isCurrentUser ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ranked.rank}',
                style: AppType.stat.copyWith(
                  fontSize: leader ? 26 : 20,
                  color: leader ? AppColors.onSurface : color,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: WpMonoLabel(
                  '${ranked.entry.totalPoints} pts',
                  color: leader
                      ? AppColors.onSurfaceMuted
                      : AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One tourist as a row: rank, avatar, name, totals, points.
class LeaderboardRowTile extends StatelessWidget {
  final RankedEntry ranked;

  /// Drawn with the "you" treatment — an outlined card and the name replaced
  /// by "You", so a tourist can find themselves without reading every name.
  final bool isCurrentUser;

  /// Shown in place of the rank number when the tourist ranks below the page
  /// the board fetched, e.g. "50+". The exact position is not knowable from
  /// the client without counting everyone ahead of them, and inventing one
  /// would be worse than admitting the board stops here.
  final String? rankOverride;

  const LeaderboardRowTile({
    super.key,
    required this.ranked,
    this.isCurrentUser = false,
    this.rankOverride,
  });

  @override
  Widget build(BuildContext context) {
    final entry = ranked.entry;
    final color = rankColor(ranked.rank);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.backgroundDeep : AppColors.card,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: isCurrentUser ? AppColors.primaryDeep : AppColors.outline,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              rankOverride ?? '${ranked.rank}',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(
                fontWeight: FontWeight.w700,
                // Only the podium ranks are coloured. Colouring every rank
                // would make the top three stop reading as special.
                color: ranked.isPodium ? color : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          LeaderboardAvatar(
            entry: entry,
            radius: 18,
            ringColor: ranked.isPodium ? color : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCurrentUser ? 'You' : entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.totalCheckIns} '
                  '${entry.totalCheckIns == 1 ? "check-in" : "check-ins"} · '
                  '${entry.totalDistanceKm.toStringAsFixed(1)} km',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          WpMonoLabel('${entry.totalPoints} pts', color: AppColors.onPrimary),
        ],
      ),
    );
  }
}
