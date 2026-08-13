import 'package:flutter/material.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';
import 'package:walkpenang/views/widgets/star_rating.dart';

/// Screen 05 — "Write a Review".
///
/// Pops with the created [Review] on success so the detail screen can insert
/// it without refetching.
class WriteReviewView extends StatefulWidget {
  const WriteReviewView({
    super.key,
    required this.place,
    required this.repository,
    this.authorName = 'You',
  });

  final Place place;
  final PlaceRepository repository;
  final String authorName;

  @override
  State<WriteReviewView> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewView> {
  final TextEditingController _bodyController = TextEditingController();

  int _rating = 0;
  int _photoCount = 0;
  bool _submitting = false;
  String? _error;

  /// Only shown after a failed submit attempt, so the form doesn't scold the
  /// user before they've done anything.
  bool _validated = false;

  static const int _minBodyLength = 10;
  static const int _maxBodyLength = 500;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  String? get _validationError {
    if (_rating == 0) return 'Choose a star rating before submitting.';
    if (_bodyController.text.trim().length < _minBodyLength) {
      return 'Write at least $_minBodyLength characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _validated = true);

    final String? invalid = _validationError;
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
        photoCount: _photoCount,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Review submitted')));
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Write a Review',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            Text(
              widget.place.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: DiscoveryColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.place.address,
              style:
              theme.textTheme.bodySmall?.copyWith(color: DiscoveryColors.inkMuted),
            ),
            const SizedBox(height: 28),

            Text('Your rating', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            StarRatingInput(
              rating: _rating,
              onChanged: (int value) => setState(() {
                _rating = value;
                if (_validated) _error = _validationError;
              }),
            ),
            const SizedBox(height: 4),
            Text(
              ratingCaption(_rating),
              style:
              theme.textTheme.bodySmall?.copyWith(color: DiscoveryColors.inkMuted),
            ),
            const SizedBox(height: 28),

            Text('Your review', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              enabled: !_submitting,
              maxLines: 6,
              maxLength: _maxBodyLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_validated) setState(() => _error = _validationError);
              },
              decoration: InputDecoration(
                hintText: 'Share your experience with other travellers...',
                contentPadding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),

            Text(
              'Add photos (optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: List<Widget>.generate(4, (int index) {
                final bool filled = index < _photoCount;
                final bool isAddSlot = index == _photoCount;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _PhotoSlot(
                    filled: filled,
                    showAdd: isAddSlot,
                    onTap: isAddSlot ? _addPhoto : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            if (_error != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6D6D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Color(0xFF8B3A3A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B3A3A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
    );
  }

  /// Placeholder for the real picker. Wiring up image_picker is a separate
  /// task — this keeps the slot UI honest without pretending to upload.
  void _addPhoto() {
    if (_photoCount >= 3) return;
    setState(() => _photoCount++);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Photo slot reserved — picker not wired up yet'),
        ),
      );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.filled,
    required this.showAdd,
    this.onTap,
  });

  final bool filled;
  final bool showAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: filled ? DiscoveryColors.creamDeep : DiscoveryColors.cream,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          filled
              ? Icons.image_outlined
              : showAdd
              ? Icons.add
              : null,
          size: 20,
          color: DiscoveryColors.inkMuted,
        ),
      ),
    );
  }
}
