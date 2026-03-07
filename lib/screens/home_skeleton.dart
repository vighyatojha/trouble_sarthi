// home_skeleton.dart
// Skeleton loading + No-Internet screen for Trouble Sarthi home page.
// Import this in home_screen.dart:  import 'home_skeleton.dart';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER BOX — animated shimmer placeholder
// ─────────────────────────────────────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_anim.value - 0.5).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.5).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFFE8E8F0),
              Color(0xFFF5F5FF),
              Color(0xFFE8E8F0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;
  const _ShimmerCircle({required this.size});

  @override
  Widget build(BuildContext context) => ShimmerBox(
    width: size,
    height: size,
    borderRadius: BorderRadius.circular(size / 2),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SKELETON SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HomeSkeletonScreen extends StatelessWidget {
  const HomeSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _SkeletonHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ShimmerBox(
                width: double.infinity,
                height: 50,
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: ShimmerBox(
                width: double.infinity,
                height: 92,
                borderRadius: BorderRadius.circular(22)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                    child: ShimmerBox(
                        width: double.infinity,
                        height: 92,
                        borderRadius: BorderRadius.circular(18))),
                const SizedBox(width: 12),
                Expanded(
                    child: ShimmerBox(
                        width: double.infinity,
                        height: 92,
                        borderRadius: BorderRadius.circular(18))),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: List.generate(3, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  child: ShimmerBox(
                      width: double.infinity,
                      height: 54,
                      borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              ShimmerBox(width: 130, height: 22, borderRadius: BorderRadius.circular(6)),
              const SizedBox(width: 8),
              ShimmerBox(width: 32, height: 22, borderRadius: BorderRadius.circular(20)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.32,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, __) => ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(24)),
              childCount: 12,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _SkeletonHowItWorks()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: ShimmerBox(
                width: double.infinity,
                height: 180,
                borderRadius: BorderRadius.circular(28)),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 75)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 100, height: 18, borderRadius: BorderRadius.circular(8)),
                        const SizedBox(height: 8),
                        ShimmerBox(width: 200, height: 22, borderRadius: BorderRadius.circular(8)),
                        const SizedBox(height: 10),
                        ShimmerBox(width: 140, height: 28, borderRadius: BorderRadius.circular(20)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ShimmerCircle(size: 46),
                ],
              ),
            ),
            Container(
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6FB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON HOW IT WORKS
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonHowItWorks extends StatelessWidget {
  const _SkeletonHowItWorks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ShimmerBox(width: 130, height: 22, borderRadius: BorderRadius.circular(6)),
            const SizedBox(width: 8),
            ShimmerBox(width: 80, height: 22, borderRadius: BorderRadius.circular(20)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: List.generate(3, (i) {
                final isLast = i == 2;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        _ShimmerCircle(size: 46),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 30,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: const Color(0xFFE8E8F0),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 6),
                            ShimmerBox(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 4),
                            ShimmerBox(width: 160, height: 12, borderRadius: BorderRadius.circular(4)),
                            if (!isLast) const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NO INTERNET SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HomeNoInternetScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  const HomeNoInternetScreen({super.key, this.onRetry});

  @override
  State<HomeNoInternetScreen> createState() => _HomeNoInternetScreenState();
}

class _HomeNoInternetScreenState extends State<HomeNoInternetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildOfflineHeader(),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _opacity,
                    child: ScaleTransition(scale: _scale, child: child),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _NoWifiIcon(),
                        const SizedBox(height: 28),
                        const Text(
                          'No Internet Connection',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Looks like you\'re offline.\nCheck your Wi-Fi or mobile data\nand try again.',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              _OfflineTip(
                                  icon: Icons.wifi_rounded,
                                  text: 'Turn Wi-Fi off and on again'),
                              SizedBox(height: 10),
                              _OfflineTip(
                                  icon: Icons.signal_cellular_alt_rounded,
                                  text: 'Check mobile data is enabled'),
                              SizedBox(height: 10),
                              _OfflineTip(
                                  icon: Icons.airplanemode_active_rounded,
                                  text: 'Disable Airplane Mode if active'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh_rounded,
                                size: 20, color: Colors.white),
                            label: const Text('Try Again',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.40)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 10, color: Color(0xFFFF6B6B)),
                          SizedBox(width: 5),
                          Text('OFFLINE MODE',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF6B6B),
                                  letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFEDE9FE), Color(0xFFC4B5FD), Color(0xFFA78BFA)],
                      ).createShader(bounds),
                      child: const Text('Trouble Sarthi',
                          style: TextStyle(
                              fontFamily: 'Saman',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED NO-WIFI ICON
// ─────────────────────────────────────────────────────────────────────────────

class _NoWifiIcon extends StatefulWidget {
  const _NoWifiIcon();

  @override
  State<_NoWifiIcon> createState() => _NoWifiIconState();
}

class _NoWifiIconState extends State<_NoWifiIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1.0 - _pulse.value).clamp(0.0, 0.3),
              child: Container(
                width: 110 * (0.7 + 0.3 * _pulse.value),
                height: 110 * (0.7 + 0.3 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFDC2626).withOpacity(0.3),
                      width: 2),
                ),
              ),
            ),
            Opacity(
              opacity: (0.8 - _pulse.value * 0.8).clamp(0.0, 0.4),
              child: Container(
                width: 82 * (0.8 + 0.2 * _pulse.value),
                height: 82 * (0.8 + 0.2 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDC2626).withOpacity(0.08),
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEE2E2), Color(0xFFFFCDD2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 38, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE TIP ROW
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineTip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _OfflineTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTIONAL: SUB-SERVICES SHEET SKELETON
// ─────────────────────────────────────────────────────────────────────────────

class SubServicesSheetSkeleton extends StatelessWidget {
  const SubServicesSheetSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: ShimmerBox(
                width: double.infinity,
                height: 86,
                borderRadius: BorderRadius.circular(20)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.86,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 9,
              itemBuilder: (_, __) => ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}