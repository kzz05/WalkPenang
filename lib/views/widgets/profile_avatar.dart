import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A tourist's profile picture, or their initials when they have none.
///
/// Not [WpAvatar]: that falls back to a generic person icon, which would make
/// every photo-less tourist look like the same person — on a leaderboard, and
/// equally in a list of reviews. Initials keep them distinguishable at a
/// glance, which is the one thing both surfaces have to do.
///
/// Extracted from `LeaderboardAvatar`, which now delegates here. It used to
/// take a whole `LeaderboardEntryModel` while reading only two fields off it,
/// so reusing it for reviews would have coupled the Discovery module to
/// Module 5's model for the sake of a URL and a string.
///
/// No cache-busting is needed on [photoUrl]. `moderateProfileImage` mints a
/// fresh download token on every upload, so a changed photo is a changed URL,
/// and `cached_network_image` keys its disk cache on exactly that.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.radius = 20,
    this.ringColor,
  });

  /// Null when the tourist has no photo, or has not been resolved yet.
  final String? photoUrl;

  /// Shown whenever there is no image to show — including while one loads and
  /// when it fails.
  final String initials;

  final double radius;

  /// Ring drawn around the avatar — the podium colour, or null for no ring.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final String? url = photoUrl;

    final Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.backgroundDeep,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: url == null
              ? _initials()
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  // Both fall back to the initials rather than to a spinner or
                  // a broken-image icon: a row that briefly shows the wrong
                  // thing is worse here than one that never changes.
                  placeholder: (BuildContext context, String url) =>
                      _initials(),
                  errorWidget:
                      (BuildContext context, String url, Object error) =>
                          _initials(),
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
        initials,
        style: AppType.heading.copyWith(
          fontSize: radius * 0.8,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}
