import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  ImagePickerService._();
  static final ImagePickerService instance = ImagePickerService._();

  final ImagePicker _picker = ImagePicker();

  // ── Pick from gallery ─────────────────────────────────────────────────────

  Future<File?> pickFromGallery({
    int imageQuality = 75,
    double maxWidth = 600,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      // ignore: avoid_print
      print('[ImagePicker] Gallery error: $e');
      return null;
    }
  }

  // ── Pick from camera ──────────────────────────────────────────────────────

  Future<File?> pickFromCamera({
    int imageQuality = 75,
    double maxWidth = 600,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      // ignore: avoid_print
      print('[ImagePicker] Camera error: $e');
      return null;
    }
  }

  // ── Show bottom sheet to choose source ───────────────────────────────────
  // Call this from any screen — returns the picked File or null

  Future<File?> pickWithSourceSheet(BuildContext context) async {
    File? result;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Choose Photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),

              // Gallery option
              _SheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () async {
                  Navigator.pop(ctx);
                  result = await pickFromGallery();
                },
              ),
              const SizedBox(height: 12),

              // Camera option
              _SheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () async {
                  Navigator.pop(ctx);
                  result = await pickFromCamera();
                },
              ),
              const SizedBox(height: 12),

              // Cancel
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return result;
  }
}

// ── Bottom sheet option tile ──────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F3FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4F46E5), size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}