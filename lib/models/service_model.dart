import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← ADD THIS

class HelperModel {
  final String id;
  final String name;
  final String serviceType;
  final String category;
  final String? subcategory;
  final double rating;
  final int completedJobs;
  final bool isAvailable;
  final double pricePerHour;
  final String phoneNumber;
  final String experience;
  final String location;
  final String? profileImage;
  final List<String> skills;
  final IconData icon;
  final Color color;
  final DateTime? lastOnlineAt;      // ← ADD: tracks when helper went offline

  HelperModel({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.category,
    this.subcategory,
    required this.rating,
    required this.completedJobs,
    required this.isAvailable,
    required this.pricePerHour,
    required this.phoneNumber,
    required this.experience,
    required this.location,
    this.profileImage,
    required this.skills,
    this.icon = Icons.home_repair_service,
    this.color = const Color(0xFF4A90D9),
    this.lastOnlineAt,                // ← ADD
  });

  // ── How long the helper has been offline ─────────────────────────────────
  Duration get offlineDuration {
    if (isAvailable || lastOnlineAt == null) return Duration.zero;
    return DateTime.now().difference(lastOnlineAt!);
  }

  // ── Is booking blocked? (offline for less than 1 hour) ───────────────────
  bool get isBookingBlocked {
    if (isAvailable) return false;
    return offlineDuration.inMinutes < 60;
  }

  // ── Earliest time user can book (lastOnlineAt + 1 hour) ──────────────────
  DateTime? get bookableFrom {
    if (lastOnlineAt == null) return null;
    return lastOnlineAt!.add(const Duration(hours: 1));
  }

  factory HelperModel.fromFirestore(Map<String, dynamic> data, String id) {
    final jobs = data['completedJobs'] ?? data['totalJobs'] ?? 0;
    final phone = data['phoneNumber'] ?? data['phone'] ?? '';
    final rawLocation = data['location'] ?? '';
    final location = (rawLocation is String &&
        rawLocation.isNotEmpty &&
        !rawLocation.contains('[object'))
        ? rawLocation
        : (data['area'] ?? 'Location not set');

    final serviceType = data['serviceType'] ?? '';

    // ── Resolve isAvailable: check both isAvailable and isOnline ─────────
    final isAvailable = (data['isAvailable'] == true) ||
        (data['isOnline'] == true) ||
        (data['status'] == 'online') ||
        (data['status'] == 'active');

    // ── Parse lastOnlineAt from Firestore Timestamp ───────────────────────
    DateTime? lastOnlineAt;
    final raw = data['lastOnlineAt'] ?? data['lastSeenAt'] ?? data['offlineAt'];
    if (raw != null) {
      if (raw is Timestamp) {
        lastOnlineAt = raw.toDate();
      } else if (raw is String) {
        lastOnlineAt = DateTime.tryParse(raw);
      }
    }

    return HelperModel(
      id: id,
      name: data['name'] ?? '',
      serviceType: serviceType,
      category: data['category'] ?? '',
      subcategory: data['subcategory'],
      rating: (data['rating'] ?? 0).toDouble(),
      completedJobs: (jobs as num).toInt(),
      isAvailable: isAvailable,
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      phoneNumber: phone,
      experience: data['experience'] ?? '',
      location: location,
      profileImage: data['profileImage'] ?? data['profileUrl'],
      skills: List<String>.from(data['skills'] ?? []),
      icon: _iconForService(serviceType),
      color: _colorForService(serviceType),
      lastOnlineAt: lastOnlineAt,
    );
  }

  static IconData _iconForService(String s) {
    final t = s.toLowerCase();
    if (t.contains('plumb') || t.contains('water')) return Icons.plumbing;
    if (t.contains('electric')) return Icons.electrical_services;
    if (t.contains('clean')) return Icons.cleaning_services;
    if (t.contains('ac') || t.contains('air')) return Icons.ac_unit;
    if (t.contains('carpen')) return Icons.carpenter;
    if (t.contains('paint')) return Icons.format_paint;
    if (t.contains('pest')) return Icons.bug_report;
    if (t.contains('vehicle') || t.contains('car')) return Icons.directions_car;
    return Icons.home_repair_service;
  }

  static Color _colorForService(String s) {
    final t = s.toLowerCase();
    if (t.contains('plumb') || t.contains('water')) return const Color(0xFF2196F3);
    if (t.contains('electric')) return const Color(0xFFFFC107);
    if (t.contains('clean')) return const Color(0xFF4CAF50);
    if (t.contains('ac') || t.contains('air')) return const Color(0xFF00BCD4);
    if (t.contains('carpen')) return const Color(0xFF795548);
    if (t.contains('paint')) return const Color(0xFF9C27B0);
    if (t.contains('pest')) return const Color(0xFFFF5722);
    if (t.contains('vehicle') || t.contains('car')) return const Color(0xFF607D8B);
    return const Color(0xFF4A90D9);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'serviceType': serviceType,
      'category': category,
      'subcategory': subcategory,
      'rating': rating,
      'completedJobs': completedJobs,
      'isAvailable': isAvailable,
      'pricePerHour': pricePerHour,
      'phoneNumber': phoneNumber,
      'experience': experience,
      'location': location,
      'profileImage': profileImage,
      'skills': skills,
    };
  }

  static List<HelperModel> getSampleHelpers(String serviceType) {
    return [
      HelperModel(
        id: '1', name: 'Rajesh Kumar', serviceType: serviceType,
        category: 'Home Services', subcategory: serviceType,
        rating: 4.5, completedJobs: 120, isAvailable: true,
        pricePerHour: 200, phoneNumber: '+91 98765 43210',
        experience: '5 years', location: 'Surat, Gujarat',
        skills: ['Professional', 'Experienced', 'Reliable'],
        icon: _iconForService(serviceType), color: _colorForService(serviceType),
      ),
      HelperModel(
        id: '2', name: 'Amit Patel', serviceType: serviceType,
        category: 'Home Services', subcategory: serviceType,
        rating: 4.8, completedJobs: 200, isAvailable: false,
        pricePerHour: 250, phoneNumber: '+91 98765 43211',
        experience: '7 years', location: 'Surat, Gujarat',
        skills: ['Expert', 'Fast Service', 'Quality Work'],
        icon: _iconForService(serviceType), color: _colorForService(serviceType),
        lastOnlineAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      HelperModel(
        id: '3', name: 'Suresh Shah', serviceType: serviceType,
        category: 'Home Services', subcategory: serviceType,
        rating: 4.3, completedJobs: 85, isAvailable: true,
        pricePerHour: 180, phoneNumber: '+91 98765 43212',
        experience: '3 years', location: 'Surat, Gujarat',
        skills: ['Affordable', 'Punctual', 'Skilled'],
        icon: _iconForService(serviceType), color: _colorForService(serviceType),
      ),
    ];
  }
}