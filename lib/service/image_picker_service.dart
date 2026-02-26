// lib/service/image_picker_service.dart
//
// Wraps image_picker with a bottom sheet so user can choose Camera or Gallery.
// Returns a dart:io File or null if cancelled.
//
// Required package in pubspec.yaml:
//   image_picker: ^1.1.2

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  ImagePickerService._();
  static final instance = ImagePickerService._();

  final _picker = ImagePicker();

  // ── Main entry point — shows Camera / Gallery bottom sheet ───────────────
  Future<File?> pickWithSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SourceSheet(),
    );
    if (source == null) return null;
    return _pick(source);
  }

  // ── Pick from a specific source ──────────────────────────────────────────
  Future<File?> pickFromCamera()  => _pick(ImageSource.camera);
  Future<File?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<File?> _pick(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth:  800,
        maxHeight: 800,
        imageQuality: 85, // 0–100: good balance of quality vs upload size
      );
      if (xFile == null) return null;
      return File(xFile.path);
    } catch (e) {
      debugPrint('[ImagePickerService] error: $e');
      return null;
    }
  }
}

// ── Bottom sheet UI ───────────────────────────────────────────────────────────
class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 42, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Upload Profile Photo',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a clear, recent photo of yourself',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),

          const SizedBox(height: 24),

          Row(children: [
            // Camera
            Expanded(
              child: _SourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                subtitle: 'Take a new photo',
                color: const Color(0xFF7C3AED),
                bg: const Color(0xFFEDE9FE),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ),
            const SizedBox(width: 14),
            // Gallery
            Expanded(
              child: _SourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                subtitle: 'Pick from photos',
                color: const Color(0xFF0891B2),
                bg: const Color(0xFFE0F2FE),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Cancel
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color, bg;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.70))),
        ]),
      ),
    );
  }
}