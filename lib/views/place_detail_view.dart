import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';
import 'package:walkpenang/views/widgets/review_submission_modal.dart';
import 'package:walkpenang/views/widgets/star_rating.dart';

/// Screens 03–05 — location details, reviews, favourites (T-FD03.1, T-FD03.2,
/// T-FD05.1, T-FD05.2).
///
/// Every optional field is guarded: a listing with no photos, no hours, no
/// contact and no price range still renders sensibly rather than crashing or
/// showing empty rows (T-FD03.3).
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
  State<PlaceDetailView> createState() => _PlaceDetailViewState();
}

class _PlaceDetailViewState extends State<PlaceDetailView> {
  final PageController _photoController = PageController();

  List<Review> _reviews = const <Review>[];
  bool _loadingReviews = true;
  String? _reviewError;
  int _photoIndex = 0;

  /// Shows the green banner from screen 04, but only right after saving.
  bool _showSavedBanner = false;

  /// T-FD05.2 — the running average, updated locally as reviews come in so
  /// the figure moves without a refetch.
  late RatingSummary _summary = widget.repository.ratingFor(widget.place);

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
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

  /// Opens the place's real Google Maps listing — its actual rating and
  /// reviews, not the placeholder ones seeded into our own Firestore. Free:
  /// just a maps search deep link, no Places API key or billing involved.
  Future<void> _openGoogleMapsReviews() async {
    final Uri uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${widget.place.name}, ${widget.place.address}',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _toggleFavorite() {
    final bool added = widget.favorites.toggle(widget.place);
    setState(() => _showSavedBanner = added);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(added ? 'Added to Favorites' : 'Removed from Favorites'),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
  }

  Future<void> _writeReview() async {
    final Review? submitted = await ReviewSubmissionModal.show(
      context,
      place: widget.place,
      repository: widget.repository,
    );

    if (submitted == null || !mounted) return;

    setState(() {
      // Show it immediately — the user just wrote it, no need to refetch.
      _reviews = <Review>[submitted, ..._reviews];
      // T-FD05.2 — fold the new rating into the average.
      _summary = _summary.withReview(submitted.rating);
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Review submitted'),
          duration: Duration(seconds: 2),
          margin: EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Place place = widget.place;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.favorites,
        builder: (BuildContext context, _) {
          final bool isFavorite = widget.favorites.isFavorite(place);

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 260,
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
                  background: _buildPhotoCarousel(place),
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
                        _SavedBanner(
                          onDismiss: () =>
                              setState(() => _showSavedBanner = false),
                        ),
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
                          StarRating(rating: _summary.average, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${_summary.displayAverage} '
                                '(${Place.formatCount(_summary.count)} reviews)',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: DiscoveryColors.inkMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _openGoogleMapsReviews,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'See real reviews on Google Maps',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: DiscoveryColors.tanDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.open_in_new,
                                size: 13,
                                color: DiscoveryColors.tanDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (place.hasDescription) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          place.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: DiscoveryColors.inkMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
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
                      _buildHours(theme, place),
                      if (place.priceRange != null) ...<Widget>[
                        const SizedBox(height: 20),
                        _Section(
                          title: 'Typical spend',
                          child: Text(
                            place.priceRange!.display,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: DiscoveryColors.inkMuted),
                          ),
                        ),
                      ],
                      if (!place.contact.isEmpty) ...<Widget>[
                        const SizedBox(height: 20),
                        _buildContact(theme, place),
                      ],
                      const SizedBox(height: 24),
                      _buildReviews(theme),
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

  /// T-FD03.1 — swipeable gallery, with a dot indicator when there's more
  /// than one photo. Falls back to a category-coloured panel when the
  /// listing has no photos at all (T-FD03.3).
  Widget _buildPhotoCarousel(Place place) {
    if (!place.hasPhotos) {
      return Container(
        color: place.category.color,
        child: const Center(
          child: Icon(
            Icons.photo_outlined,
            size: 44,
            color: Colors.white70,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _photoController,
          itemCount: place.photoUrls.length,
          onPageChanged: (int index) => setState(() => _photoIndex = index),
          itemBuilder: (BuildContext context, int index) {
            return CachedNetworkImage(
              imageUrl: place.photoUrls[index],
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (BuildContext context, String url) =>
                  Container(color: DiscoveryColors.creamDeep),
              errorWidget: (BuildContext context, String url, Object error) =>
                  Container(
                    color: place.category.color,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 32,
                        color: Colors.white70,
                      ),
                    ),
                  ),
            );
          },
        ),
        if (place.photoUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                place.photoUrls.length,
                    (int index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: index == _photoIndex ? 18 : 6,
                  decoration: BoxDecoration(
                    color: index == _photoIndex
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// T-FD03.2 — open/closed from the device clock. A listing with no
  /// published hours says so rather than claiming to be closed (T-FD03.3).
  Widget _buildHours(ThemeData theme, Place place) {
    if (!place.hasHours) {
      return _Section(
        title: 'Opening hours',
        child: Text(
          'Hours not available',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: DiscoveryColors.inkMuted),
        ),
      );
    }

    final bool openNow = place.isOpenAt(DateTime.now());

    return _Section(
      title: 'Opening hours',
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: openNow
                  ? DiscoveryColors.successBg
                  : DiscoveryColors.errorBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              openNow ? 'Open now' : 'Closed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: openNow
                    ? DiscoveryColors.successInk
                    : DiscoveryColors.errorInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            place.hours!.displayRange,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: DiscoveryColors.inkMuted),
          ),
        ],
      ),
    );
  }

  /// T-FD03.1 — phone and website, each rendered only when present.
  Widget _buildContact(ThemeData theme, Place place) {
    return _Section(
      title: 'Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (place.contact.hasPhone)
            _ContactRow(
              icon: Icons.phone_outlined,
              label: place.contact.phone!,
            ),
          if (place.contact.hasWebsite) ...<Widget>[
            if (place.contact.hasPhone) const SizedBox(height: 8),
            _ContactRow(
              icon: Icons.language_outlined,
              label: place.contact.website!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviews(ThemeData theme) {
    if (_loadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: DiscoveryColors.tan),
        ),
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
        style: theme.textTheme.bodySmall
            ?.copyWith(color: DiscoveryColors.inkMuted),
      );
    }

    final DateTime now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Reviews (${_reviews.length} of ${Place.formatCount(_summary.count)})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: DiscoveryColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        ..._reviews.map((Review review) =>
            _ReviewTile(review: review, now: now)),
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: DiscoveryColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: DiscoveryColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DiscoveryColors.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: DiscoveryColors.inkMuted,
                    height: 1.45,
                  ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: DiscoveryColors.successInk,
                  ),
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