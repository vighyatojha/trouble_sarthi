import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
            child: Column(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'About Trouble Sarthi',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connecting Communities, Solving Problems',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // About Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Our Mission',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5F3F),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Trouble Sarthi is your local helper network, connecting communities with skilled professionals for household and industrial needs. From home to industry, we provide fast, affordable, and reliable solutions.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'What We Do',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5F3F),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We provide fast, affordable, and reliable solutions by delivering user-centric digital solutions with expertise in Java, C, and C++. Our platform specializes in household work, industrial support, vehicle repair, electrical and plumbing services, and various other professional services.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Meet Our Founders
                const Text(
                  'Meet Our Founders',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5F3F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Founders Cards
                _buildFounderCard(
                  initials: 'HP',
                  name: 'Harsh Pravin Patil',
                  role: 'Co-Founder & Developer',
                  description:
                  'A third-year BCA student dedicated to fostering community connections through innovative technology. Passionate about delivering user-centric digital solutions with expertise in Java, C, and C++.',
                  color: const Color(0xFF6B5CE7),
                ),
                const SizedBox(height: 20),
                _buildFounderCard(
                  initials: 'VO',
                  name: 'Vighyat Ojha',
                  role: 'Co-Founder & Developer',
                  description:
                  'A third-year BCA student committed to building scalable and efficient web and mobile applications. Proficient in Python, Flutter, and JavaScript. Expert in Android app development, with expertise in SQLite and MySQL database management. Possesses foundational skills in prompt engineering to enhance AI-driven solutions.',
                  color: const Color(0xFF6B5CE7),
                ),
                const SizedBox(height: 20),
                _buildFounderCard(
                  initials: 'PS',
                  name: 'Praful Saindane',
                  role: 'Co-Founder & Full Stack Developer',
                  description:
                  'A third-year BCA student with a passion for developing robust, cross-platform applications. Skilled in PHP, Python, JavaScript, and TypeScript with a focus on creating seamless and scalable solutions.',
                  color: const Color(0xFF6B5CE7),
                ),

                const SizedBox(height: 32),

                // Why Choose Us
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why Choose Trouble Sarthi?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D5F3F),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBulletPoint('Quick response from local helpers'),
                      _buildBulletPoint('Affordable prices with no hidden fees'),
                      _buildBulletPoint('Verified and experienced professionals'),
                      _buildBulletPoint('Easy online booking platform'),
                      _buildBulletPoint('Wide range of services'),
                      _buildBulletPoint('Community-focused approach'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFounderCard({
    required String initials,
    required String name,
    required String role,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D5F3F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            role,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
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
                fontSize: 15,
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