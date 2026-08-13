import 'package:flutter/material.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';
import 'package:walkpenang/views/widgets/star_rating.dart';

/// T-FD05.1 — the review sheet.
///
/// Presented as a modal bottom sheet rather than a full page so the place
/// stays visible behind it. Pops with the created [Review] on success, or
/// null if dismissed.
class ReviewSubmissionModal extends StatefulWidget {
  const ReviewSubmissionModal({
    super.key,
    required this.place,
    required this.repository,
    this.authorName = 'You',
  });

  final Place place;
  final PlaceRepository repository;
  final String authorName;

  /// Minimum characters before a review counts as written (T-FD05.3).
  static const int minBodyLength = 10;

  /// Hard cap enforced by the field and re-checked on submit (T-FD05.3).
  static const int maxBodyLength = 500;

  /// T-FD05.2 — the submission rules.
  ///
  /// Deliberately a static on the public widget rather than on the private
  /// State class, so the unit tests can call it without pumping any UI.
  /// Returns null when the review is valid, or the message to show.
  static String? validate({required int rating, required String body}) {
    if (rating < 1 || rating > 5) {
      return 'Choose a star rating before submitting.';
    }
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Write a few words about your visit.';
    }
    if (trimmed.length < minBodyLength) {
      return 'Write at least $minBodyLength characters.';
    }
    if (trimmed.length > maxBodyLength) {
      return 'Keep it under $maxBodyLength characters.';
    }
    return null;
  }

  static Future<Review?> show(
      BuildContext context, {
        required Place place,
        required PlaceRepository repository,
        String authorName = 'You',
      }) {
    return showModalBottomSheet<Review>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // Sits above the keyboard rather than behind it.
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ReviewSubmissionModal(
          place: place,
          repository: repository,
          authorName: authorName,
        ),
      ),
    );
  }

  @override
  State<ReviewSubmissionModal> createState() => _ReviewSubmissionModalState();
}

class _ReviewSubmissionModalState extends State<ReviewSubmissionModal> {
  final TextEditingController _bodyController = TextEditingController();

  int _rating = 0;
  bool _submitting = false;
  String? _error;

  /// Errors only appear after a failed submit, so the form doesn't scold the
  /// user before they've done anything.
  bool _validated = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  /// Re-runs validation only once the user has already tried to submit.
  void _revalidate() {
    if (!_validated) return;
    _error = ReviewSubmissionModal.validate(
      rating: _rating,
      body: _bodyController.text,
    );
  }

  Future<void> _submit() async {
    setState(() => _validated = true);

    final String? invalid = ReviewSubmissionModal.validate(
      rating: _rating,
      body: _bodyController.text,
    );
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final Review review = await widget.repository.submitReview(
        placeId: widget.place.id,
        rating: _rating,
        body: _bodyController.text.trim(),
        authorName: widget.authorName,
      );

      if (!mounted) return;
      Navigator.of(context).pop(review);
    } on ApiTimeoutException catch (error) {
      _handleError(error.message);
    } on ApiFailureException catch (error) {
      _handleError(error.message);
    } catch (_) {
      _handleError("Couldn't submit your review. Try again.");
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int length = _bodyController.text.trim().length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Write a review',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DiscoveryColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.place.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: DiscoveryColors.inkMuted),
              ),
              const SizedBox(height: 24),

              Text('Your rating', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Center(
                child: StarRatingInput(
                  rating: _rating,
                  onChanged: (int value) => setState(() {
                    _rating = value;
                    _revalidate();
                  }),
                ),
              ),
              Center(
                child: Text(
                  ratingCaption(_rating),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: DiscoveryColors.inkMuted),
                ),
              ),
              const SizedBox(height: 24),

              Text('Your review', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyController,
                enabled: !_submitting,
                maxLines: 5,
                maxLength: ReviewSubmissionModal.maxBodyLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(_revalidate),
                decoration: InputDecoration(
                  hintText: 'Share your experience with other travellers...',
                  contentPadding: const EdgeInsets.all(16),
                  // Counter is drawn below manually so it can show the
                  // minimum as well as the maximum.
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  length < ReviewSubmissionModal.minBodyLength
                      ? '${ReviewSubmissionModal.minBodyLength - length} more characters needed'
                      : '$length / ${ReviewSubmissionModal.maxBodyLength}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: DiscoveryColors.inkMuted),
                ),
              ),

              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DiscoveryColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: DiscoveryColors.errorInk,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: DiscoveryColors.errorInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Submit review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}