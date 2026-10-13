// lib/core/review_sheet.dart
// Star rating + feedback tags + optional comment after a completed booking.
// IDENTICAL in both apps. The server accepts one review per side per booking.

import 'package:flutter/material.dart';

import 'job_api.dart';
import 'job_models.dart';

class ReviewSheet extends StatefulWidget {
  final Booking booking;
  final bool asCustomer;
  final Color accent;

  const ReviewSheet({
    super.key,
    required this.booking,
    required this.asCustomer,
    this.accent = const Color(0xFF7C3AED),
  });

  String get otherName => asCustomer ? booking.helperName : booking.customerName;

  /// Returns true if a review was submitted.
  static Future<bool> show(
      BuildContext context, {
        required Booking booking,
        required bool asCustomer,
        Color accent = const Color(0xFF7C3AED),
      }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ReviewSheet(booking: booking, asCustomer: asCustomer, accent: accent),
    );
    return r == true;
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  int _stars = 0;
  final Set<String> _tags = {};
  final _comment = TextEditingController();
  bool _saving = false;
  String? _error;

  List<ReviewTag> get _all => widget.asCustomer ? customerToHelperTags : helperToCustomerTags;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Tap the stars to give a rating.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await JobApi.instance.submitReview(
        booking: widget.booking,
        asCustomer: widget.asCustomer,
        rating: _stars,
        tags: _tags.toList(),
        comment: _comment.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show positive tags for 4–5 stars, negative for 1–2, both for 3.
    final visible = _all.where((t) {
      if (_stars == 0) return t.positive;
      if (_stars >= 4) return t.positive;
      if (_stars <= 2) return !t.positive;
      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Rate ${widget.otherName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(
            widget.asCustomer
                ? 'Your rating decides which helpers appear first for other customers.'
                : 'Your rating helps other helpers know what to expect.',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final on = i < _stars;
              return IconButton(
                iconSize: 40,
                onPressed: () => setState(() {
                  _stars = i + 1;
                  _tags.removeWhere((id) => !visibleIds(_stars).contains(id));
                }),
                icon: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: on ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB)),
              );
            }),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visible.map((t) {
              final sel = _tags.contains(t.id);
              final c = t.positive ? const Color(0xFF059669) : const Color(0xFFDC2626);
              return FilterChip(
                label: Text(t.label),
                selected: sel,
                onSelected: (v) => setState(() => v ? _tags.add(t.id) : _tags.remove(t.id)),
                selectedColor: c.withValues(alpha: 0.12),
                checkmarkColor: c,
                side: BorderSide(color: sel ? c : const Color(0xFFE5E7EB)),
                labelStyle: TextStyle(color: sel ? c : const Color(0xFF374151), fontWeight: FontWeight.w600),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Anything else? (optional)',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Center(child: Text('Later')),
          ),
        ]),
      ),
    );
  }

  Set<String> visibleIds(int stars) => _all
      .where((t) => stars >= 4 ? t.positive : stars <= 2 ? !t.positive : true)
      .map((t) => t.id)
      .toSet();
}