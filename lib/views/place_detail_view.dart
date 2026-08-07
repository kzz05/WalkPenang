import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/views/write_review_view.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';
import 'package:walkpenang/views/widgets/star_rating.dart';

/// Screens 03 and 04 — location details, reviews, and the save-to-favourites
/// confirmation.
class PlaceDetailView extends StatefulWidget {
  const PlaceDetailView({
    super.key,
    required this.place,
    required this.favorites,
    required this.repository,
  });

  final Place place;
  final FavoritesController favorites;
  final PlaceRepository repository;

  @override
  State<PlaceDetailView> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailView> {
  List<Review> _reviews = const <Review>[];
  bool _loadingReviews = true;
  String? _reviewError;

  /// Shows the green "Saved to your favorites" banner from the mockup, but
  /// only right after the user saves — not on every visit.
  bool _showSavedBanner = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
      _reviewError = null;
    });

    try {
      final List<Review> reviews =
      await widget.repository.fetchReviews(widget.place.id);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loadingReviews = false;
      });
    } on ApiTimeoutException catch (error) {
      _handleReviewError(error.message);
    } on ApiFailureException catch (error) {
      _handleReviewError(error.message);
    } catch (_) {
      _handleReviewError("Couldn't load reviews.");
    }
  }

  void _handleReviewError(String message) {
    if (!mounted) return;
    setState(() {
      _reviewError = message;
      _loadingReviews = false;
    });
  }

  void _toggleFavorite() {
    final bool added = widget.favorites.toggle(widget.place);
    setState(() => _showSavedBanner = added);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(added ? 'Added to Favorites' : 'Removed from Favorites'),
          duration: const Duration(seconds: 2),
          width: 260,
        ),
      );
  }

  Future<void> _writeReview() async {
    final Review? submitted = await Navigator.of(context).push<Review>(
      MaterialPageRoute<Review>(
        builder: (BuildContext context) => WriteReviewView(
          place: widget.place,
          repository: widget.repository,
        ),
      ),
    );

    if (submitted == null || !mounted) return;
    // Show it immediately rather than refetching — the user just wrote it.
    setState(() => _reviews = <Review>[submitted, ..._reviews]);
  }

  @override
  Widget build(BuildContext context) {
    final Place place = widget.place;
    final ThemeData theme = Theme.of(context);
    final bool openNow = place.isOpenAt(DateTime.now());

    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.favorites,
        builder: (BuildContext context, _) {
          final bool isFavorite = widget.favorites.isFavorite(place);

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: DiscoveryColors.cream,
                leading: _CircleButton(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  _CircleButton(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.redAccent : DiscoveryColors.ink,
                    onPressed: _toggleFavorite,
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: place.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) =>
                        Container(color: DiscoveryColors.creamDeep),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                        Container(
                          color: place.category.color,
                          child: const Center(
                            child: Icon(
                              Icons.photo_outlined,
                              size: 40,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: DiscoveryColors.surface,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_showSavedBanner) ...<Widget>[
                        _SavedBanner(onDismiss: () {
                          setState(() => _showSavedBanner = false);
                        }),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        place.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DiscoveryColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          StarRating(rating: place.rating, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${place.rating.toStringAsFixed(1)} '
                                '(${place.reviewCountLabel} reviews)',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: DiscoveryColors.inkMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _Section(
                        title: 'Address',
                        child: Text(
                          place.address,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: DiscoveryColors.inkMuted),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Opening hours',
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: openNow
                                    ? DiscoveryColors.successBg
                                    : const Color(0xFFF6D6D6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                openNow ? 'Open now' : 'Closed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: openNow
                                      ? DiscoveryColors.successInk
                                      : const Color(0xFF8B3A3A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              place.hours.displayRange,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: DiscoveryColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildReviews(theme, place),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _writeReview,
                        child: const Text('Write a review'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviews(ThemeData theme, Place place) {
    if (_loadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: DiscoveryColors.tan)),
      );
    }

    if (_reviewError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_reviewError!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadReviews, child: const Text('Retry')),
        ],
      );
    }

    if (_reviews.isEmpty) {
      return Text(
        'No reviews yet. Be the first to write one.',
        style: theme.textTheme.bodySmall?.copyWith(color: DiscoveryColors.inkMuted),
      );
    }

    final DateTime now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Reviews (${_reviews.length} of ${place.reviewCountLabel})',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: DiscoveryColors.ink),
        ),
        const SizedBox(height: 12),
        ..._reviews.map((Review review) => _ReviewTile(
          review: review,
          now: now,
        )),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: DiscoveryColors.ink),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.now});

  final Review review;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: DiscoveryColors.creamDeep,
            child: Text(
              review.initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DiscoveryColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      review.authorName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      review.relativeTime(now),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: DiscoveryColors.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                StarRating(rating: review.rating.toDouble(), size: 12),
                const SizedBox(height: 6),
                Text(
                  review.body,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: DiscoveryColors.inkMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The green confirmation strip from screen 04.
class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: DiscoveryColors.successBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Saved to your favorites',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DiscoveryColors.successInk,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Revisit this place anytime from the Favorites tab.',
                  style: TextStyle(fontSize: 11, color: DiscoveryColors.successInk),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            iconSize: 16,
            color: DiscoveryColors.successInk,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.color = DiscoveryColors.ink,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: DiscoveryColors.cream.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: color,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
