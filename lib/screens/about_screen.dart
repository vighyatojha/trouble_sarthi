import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2D5F3F),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'About Us',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2D5F3F),
                      Color(0xFF3D7F5F),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.info_outline,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Mission Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Mission',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5F3F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Trouble Sarthi is your local helper network, connecting communities with skilled professionals. From home to industry, we provide fast, affordable, and reliable solutions.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Founders Section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                'Meet Our Founders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D5F3F),
                ),
              ),
            ),
          ),

          // Founders Cards
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildFounderCard(
                  initials: 'HP',
                  name: 'Harsh Pravin Patil',
                  role: 'Co-Founder & Developer',
                  description:
                  'Third-year BCA student dedicated to fostering community connections through innovative technology.',
                  color: const Color(0xFF6B5CE7),
                ),
                const SizedBox(height: 16),
                _buildFounderCard(
                  initials: 'VO',
                  name: 'Vighyat Ojha',
                  role: 'Co-Founder & Developer',
                  description:
                  'BCA student committed to building scalable web and mobile applications with expertise in Python, Flutter, and JavaScript.',
                  color: const Color(0xFF6B5CE7),
                ),
                const SizedBox(height: 16),
                _buildFounderCard(
                  initials: 'PS',
                  name: 'Praful Saindane',
                  role: 'Co-Founder & Full Stack Developer',
                  description:
                  'BCA student with passion for developing robust cross-platform applications using PHP, Python, and TypeScript.',
                  color: const Color(0xFF6B5CE7),
                ),
              ],
            ),
          ),

          // Why Choose Us Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why Choose Us?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5F3F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitItem('Quick response from local helpers'),
                  _buildBenefitItem('Affordable with no hidden fees'),
                  _buildBenefitItem('Verified professionals'),
                  _buildBenefitItem('Easy online booking'),
                  _buildBenefitItem('Wide range of services'),
                  _buildBenefitItem('Community-focused'),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  static Widget _buildFounderCard({
    required String initials,
    required String name,
    required String role,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5F3F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            size: 20,
            color: Color(0xFF7FDB6A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}