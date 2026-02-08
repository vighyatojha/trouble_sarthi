import 'package:flutter/material.dart';

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  static List<ServiceModel> getAllServices() {
    return [
      ServiceModel(
        id: 'household',
        name: 'Household Work',
        description:
        'Cleaning, cooking, gardening, and general home maintenance services for your daily needs.',
        icon: Icons.home,
        color: const Color(0xFF6B5CE7),
      ),
      ServiceModel(
        id: 'industrial',
        name: 'Industrial Work',
        description:
        'Factory maintenance, equipment handling, and industrial support services for businesses.',
        icon: Icons.factory,
        color: const Color(0xFF6B5CE7),
      ),
      ServiceModel(
        id: 'vehicle',
        name: 'Vehicle Repair',
        description:
        'Expert mechanics for cars, bikes, and other vehicles at your doorstep with quality service.',
        icon: Icons.directions_car,
        color: const Color(0xFF6B5CE7),
      ),
      ServiceModel(
        id: 'electrical',
        name: 'Electrical Repair',
        description:
        'Professional electricians for all your electrical appliance needs and wiring solutions.',
        icon: Icons.electrical_services,
        color: const Color(0xFF6B5CE7),
      ),
      ServiceModel(
        id: 'plumbing',
        name: 'Plumbing Services',
        description:
        'Quick solutions for all your plumbing and water-related issues with skilled plumbers.',
        icon: Icons.plumbing,
        color: const Color(0xFF6B5CE7),
      ),
      ServiceModel(
        id: 'other',
        name: 'Other Services',
        description:
        'Carpenter, painter, handyman, and various other professional services for all your needs.',
        icon: Icons.build,
        color: const Color(0xFF6B5CE7),
      ),
    ];
  }
}

class HelperModel {
  final String id;
  final String name;
  final String serviceType;
  final double rating;
  final int completedJobs;
  final bool isAvailable;
  final double pricePerHour;
  final String phoneNumber;
  final String experience;
  final String location;
  final String? profileImage;
  final List<String> skills;

  HelperModel({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.rating,
    required this.completedJobs,
    required this.isAvailable,
    required this.pricePerHour,
    required this.phoneNumber,
    required this.experience,
    required this.location,
    this.profileImage,
    required this.skills,
  });

  // Firebase conversion methods
  factory HelperModel.fromFirestore(Map<String, dynamic> data, String id) {
    return HelperModel(
      id: id,
      name: data['name'] ?? '',
      serviceType: data['serviceType'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      completedJobs: data['completedJobs'] ?? 0,
      isAvailable: data['isAvailable'] ?? false,
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      phoneNumber: data['phoneNumber'] ?? '',
      experience: data['experience'] ?? '',
      location: data['location'] ?? '',
      profileImage: data['profileImage'],
      skills: List<String>.from(data['skills'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'serviceType': serviceType,
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

  // Sample data for testing (remove when connected to Firebase)
  static List<HelperModel> getSampleHelpers(String serviceType) {
    return [
      HelperModel(
        id: '1',
        name: 'Rajesh Kumar',
        serviceType: serviceType,
        rating: 4.5,
        completedJobs: 120,
        isAvailable: true,
        pricePerHour: 200,
        phoneNumber: '+91 98765 43210',
        experience: '5 years',
        location: 'Surat, Gujarat',
        skills: ['Professional', 'Experienced', 'Reliable'],
      ),
      HelperModel(
        id: '2',
        name: 'Amit Patel',
        serviceType: serviceType,
        rating: 4.8,
        completedJobs: 200,
        isAvailable: false,
        pricePerHour: 250,
        phoneNumber: '+91 98765 43211',
        experience: '7 years',
        location: 'Surat, Gujarat',
        skills: ['Expert', 'Fast Service', 'Quality Work'],
      ),
      HelperModel(
        id: '3',
        name: 'Suresh Shah',
        serviceType: serviceType,
        rating: 4.3,
        completedJobs: 85,
        isAvailable: true,
        pricePerHour: 180,
        phoneNumber: '+91 98765 43212',
        experience: '3 years',
        location: 'Surat, Gujarat',
        skills: ['Affordable', 'Punctual', 'Skilled'],
      ),
    ];
  }
}

