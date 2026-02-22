import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum BookingStatus { pending, active, completed, cancelled }

class BookingModel {
  final String id;
  final String serviceName;
  final String categoryName;
  final IconData serviceIcon;
  final Color serviceColor;
  final Color serviceBgColor;
  final BookingStatus status;
  final String helperName;
  final double? helperRating;
  final String address;
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final double baseAmount;
  final double? totalAmount;
  final String? helperImageUrl;
  final int? helperJobCount;
  final String? helperEmployeeId;
  final List<String>? tasksDone;

  const BookingModel({
    required this.id,
    required this.serviceName,
    required this.categoryName,
    required this.serviceIcon,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.status,
    required this.helperName,
    this.helperRating,
    required this.address,
    required this.scheduledAt,
    this.completedAt,
    required this.baseAmount,
    this.totalAmount,
    this.helperImageUrl,
    this.helperJobCount,
    this.helperEmployeeId,
    this.tasksDone,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DUMMY DATA
// ─────────────────────────────────────────────────────────────────────────────

final _dummyBookings = <BookingModel>[
  BookingModel(
    id: 'TS-9822',
    serviceName: 'Emergency Plumbing',
    categoryName: 'Home Services',
    serviceIcon: Icons.water_drop_outlined,
    serviceColor: const Color(0xFF7C3AED),
    serviceBgColor: const Color(0xFFEDE9FE),
    status: BookingStatus.active,
    helperName: 'Rajesh Kumar',
    helperRating: 4.8,
    helperJobCount: 500,
    helperEmployeeId: 'TS-EMP-442',
    address: '123 Maple Heights, Near Central Park',
    scheduledAt: DateTime(2024, 10, 24, 10, 30),
    baseAmount: 499,
    totalAmount: 734.80,
  ),
  BookingModel(
    id: 'TS-9910',
    serviceName: 'AC Repair',
    categoryName: 'Home Services',
    serviceIcon: Icons.ac_unit_outlined,
    serviceColor: const Color(0xFF0891B2),
    serviceBgColor: const Color(0xFFE0F2FE),
    status: BookingStatus.pending,
    helperName: 'Awaiting Assignment',
    address: 'Sector 12, Vaishali Nagar',
    scheduledAt: DateTime(2024, 10, 25, 14, 0),
    baseAmount: 350,
  ),
  BookingModel(
    id: 'TS-8821',
    serviceName: 'Electrical Repair',
    categoryName: 'Home Services',
    serviceIcon: Icons.bolt_outlined,
    serviceColor: const Color(0xFFD97706),
    serviceBgColor: const Color(0xFFFEF3C7),
    status: BookingStatus.completed,
    helperName: 'Amit Sharma',
    helperRating: 4.6,
    helperJobCount: 320,
    address: 'Tower 4, Green Valley Apartments',
    scheduledAt: DateTime(2024, 10, 20, 11, 0),
    completedAt: DateTime(2024, 10, 20, 12, 45),
    baseAmount: 599,
    totalAmount: 847.82,
    tasksDone: ['Panel Fuse Replacement', 'Socket Rewiring'],
  ),
  BookingModel(
    id: 'TS-8701',
    serviceName: 'Deep Cleaning',
    categoryName: 'Cleaning',
    serviceIcon: Icons.cleaning_services_outlined,
    serviceColor: const Color(0xFF0D9488),
    serviceBgColor: const Color(0xFFCCFBF1),
    status: BookingStatus.completed,
    helperName: 'Priya Patel',
    helperRating: 4.9,
    helperJobCount: 210,
    address: 'B-204, Shanti Complex',
    scheduledAt: DateTime(2024, 10, 15, 9, 0),
    completedAt: DateTime(2024, 10, 15, 13, 0),
    baseAmount: 799,
    totalAmount: 1050,
    tasksDone: ['Full House Sweep', 'Kitchen Deep Clean', 'Bathroom Scrub'],
  ),
  BookingModel(
    id: 'TS-8550',
    serviceName: 'Car Mechanic',
    categoryName: 'Vehicle Services',
    serviceIcon: Icons.car_repair,
    serviceColor: const Color(0xFF0284C7),
    serviceBgColor: const Color(0xFFE0F2FE),
    status: BookingStatus.cancelled,
    helperName: 'Not Assigned',
    address: 'Residency Road, Adajan',
    scheduledAt: DateTime(2024, 10, 10, 8, 0),
    baseAmount: 450,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// BOOKINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> get _current => _dummyBookings
      .where((b) =>
  b.status == BookingStatus.active ||
      b.status == BookingStatus.pending)
      .toList();

  List<BookingModel> get _completed => _dummyBookings
      .where((b) => b.status == BookingStatus.completed)
      .toList();

  List<BookingModel> get _cancelled => _dummyBookings
      .where((b) => b.status == BookingStatus.cancelled)
      .toList();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Column(
          children: [
            _BookingsHeader(tabController: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BookingsList(bookings: _current, emptyLabel: 'No active or pending bookings'),
                  _BookingsList(bookings: _completed, emptyLabel: 'No completed bookings yet'),
                  _BookingsList(bookings: _cancelled, emptyLabel: 'No cancelled bookings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER WITH TAB BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BookingsHeader extends StatelessWidget {
  final TabController tabController;
  const _BookingsHeader({required this.tabController});

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
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Bookings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Track & manage your service requests',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFC4B5FD),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick stats badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Column(
                      children: [
                        Text('2',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        Text('Active',
                            style: TextStyle(
                                color: Color(0xFFC4B5FD), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF9D8EC7),
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              indicator: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Current'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),

            // Bottom curve
            Container(
              height: 22,
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
// BOOKINGS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _BookingsList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyLabel;
  const _BookingsList(
      {required this.bookings, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return _EmptyState(label: emptyLabel);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: bookings.length,
      itemBuilder: (_, i) {
        final b = bookings[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: b.status == BookingStatus.active
              ? _ActiveBookingCard(booking: b)
              : b.status == BookingStatus.completed
              ? _CompletedBookingCard(booking: b)
              : _BookingCard(booking: b),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE BOOKING CARD — prominent, with live indicator
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveBookingCard extends StatefulWidget {
  final BookingModel booking;
  const _ActiveBookingCard({required this.booking});

  @override
  State<_ActiveBookingCard> createState() => _ActiveBookingCardState();
}

class _ActiveBookingCardState extends State<_ActiveBookingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return GestureDetector(
      onTap: () => _openDetails(context, b),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B0764), Color(0xFF5B21B6), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(
                    0.30 + 0.15 * _pulse.value),
                blurRadius: 20 + 8 * _pulse.value,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: service + status
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          const Text('IN PROGRESS',
                              style: TextStyle(
                                  color: Color(0xFF86EFAC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8)),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text('#${b.id}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 14),

              // Helper info
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      color: Color(0xFFC4B5FD), size: 15),
                  const SizedBox(width: 6),
                  Text(b.helperName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  if (b.helperRating != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFBBF24), size: 13),
                    const SizedBox(width: 2),
                    Text('${b.helperRating}',
                        style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                  const Spacer(),
                  if (b.helperEmployeeId != null)
                    Text(b.helperEmployeeId!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 10)),
                ],
              ),
              const SizedBox(height: 10),

              // Address + time
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFFC4B5FD), size: 14),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(b.address,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: Color(0xFFC4B5FD), size: 14),
                  const SizedBox(width: 5),
                  Text(
                      '${_formatDate(b.scheduledAt)} · ${_formatTime(b.scheduledAt)}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12)),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _OutlineButton(
                      label: 'Track Helper',
                      icon: Icons.near_me_outlined,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilledButton(
                      label: 'View Details',
                      icon: Icons.info_outline_rounded,
                      onTap: () => _openDetails(context, b),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING / CANCELLED BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isPending = b.status == BookingStatus.pending;

    return GestureDetector(
      onTap: () => _openDetails(context, b),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: b.serviceColor.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon, color: b.serviceColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Text(b.helperName,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  _StatusBadge(status: b.status),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 1,
                color: const Color(0xFFF3F4F6),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(_formatDate(b.scheduledAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(_formatTime(b.scheduledAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  Text('₹${b.totalAmount?.toStringAsFixed(0) ?? b.baseAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: b.serviceColor)),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _openDetails(context, b),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: b.serviceColor.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text('View Details',
                        style: TextStyle(
                            color: b.serviceColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETED BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedBookingCard extends StatelessWidget {
  final BookingModel booking;
  const _CompletedBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;

    return GestureDetector(
      onTap: () => _openDetails(context, b),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon, color: b.serviceColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 12, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(b.helperName,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280))),
                          if (b.helperRating != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded,
                                size: 12, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 2),
                            Text('${b.helperRating}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFBBF24))),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  const _StatusBadge(status: BookingStatus.completed),
                ],
              ),

              if (b.tasksDone != null && b.tasksDone!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...b.tasksDone!.take(2).map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 11, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(task,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF374151))),
                      ),
                    ],
                  ),
                )),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL PAID',
                          style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(
                          '₹${b.totalAmount?.toStringAsFixed(2) ?? b.baseAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                    ],
                  ),
                  const Spacer(),
                  _SmallButton(
                    label: 'Rebook',
                    icon: Icons.replay_rounded,
                    color: b.serviceColor,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  _SmallButton(
                    label: 'Invoice',
                    icon: Icons.download_outlined,
                    color: const Color(0xFF6B7280),
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING DETAILS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

void _openDetails(BuildContext context, BookingModel b) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _BookingDetailsSheet(booking: b),
  );
}

class _BookingDetailsSheet extends StatelessWidget {
  final BookingModel booking;
  const _BookingDetailsSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Details',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 3),
                      Text('Order #${b.id}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
                _StatusBadge(status: b.status),
              ],
            ),

            const SizedBox(height: 20),

            // Service info
            _DetailSection(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(b.serviceIcon,
                        color: b.serviceColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(b.categoryName,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Helper details
            _DetailSection(
              label: 'ASSIGNED HELPER',
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: b.serviceBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded,
                        color: b.serviceColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.helperName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        if (b.helperJobCount != null)
                          Text('${b.helperJobCount}+ jobs done',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  if (b.helperRating != null)
                    Column(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFBBF24), size: 18),
                        Text('${b.helperRating}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1F2937))),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Address + time
            _DetailSection(
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'SERVICE ADDRESS',
                    value: b.address,
                    color: b.serviceColor,
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 14),
                  _DetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'REQUESTED TIME',
                    value:
                    '${_formatDate(b.scheduledAt)} · ${_formatTime(b.scheduledAt)}',
                    color: b.serviceColor,
                  ),
                  if (b.completedAt != null) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'COMPLETED AT',
                      value:
                      '${_formatDate(b.completedAt!)} · ${_formatTime(b.completedAt!)}',
                      color: const Color(0xFF059669),
                    ),
                  ],
                ],
              ),
            ),

            if (b.tasksDone != null && b.tasksDone!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _DetailSection(
                label: 'TASKS COMPLETED',
                child: Column(
                  children: b.tasksDone!
                      .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669)
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 13,
                              color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 10),
                        Text(t,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Payment summary
            _DetailSection(
              label: 'PAYMENT SUMMARY',
              child: Column(
                children: [
                  _PayRow(
                    label: '${b.serviceName} Base Fee',
                    value: '₹${b.baseAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _PayRow(
                    label: 'Taxes & Fees',
                    value: '₹35.80',
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1F2937))),
                      Text(
                          '₹${b.totalAmount?.toStringAsFixed(2) ?? b.baseAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: b.serviceColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('To be paid after service',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF9CA3AF))),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // CTA buttons
            if (b.status == BookingStatus.pending ||
                b.status == BookingStatus.active) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel Request',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_outlined,
                          size: 16, color: Colors.white),
                      label: const Text('Edit Request',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (b.status == BookingStatus.completed) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.replay_rounded,
                          size: 16, color: Colors.white),
                      label: const Text('Rebook Service',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline_rounded,
                          size: 16, color: Color(0xFF6B7280)),
                      label: const Text('Get Support',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    String label;
    IconData icon;

    switch (status) {
      case BookingStatus.active:
        color = const Color(0xFF059669);
        bg = const Color(0xFFD1FAE5);
        label = 'ACTIVE';
        icon = Icons.circle;
        break;
      case BookingStatus.pending:
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        label = 'PENDING';
        icon = Icons.circle;
        break;
      case BookingStatus.completed:
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFDBEAFE);
        label = 'DONE';
        icon = Icons.check_circle_outline_rounded;
        break;
      case BookingStatus.cancelled:
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEE2E2);
        label = 'CANCELLED';
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 7, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final Widget child;
  final String? label;
  const _DetailSection({required this.child, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.8)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937))),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  const _PayRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937))),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilledButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF7C3AED), size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton(
      {required this.label,
        required this.icon,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE), shape: BoxShape.circle),
              child: const Icon(Icons.calendar_today_outlined,
                  size: 36, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 18),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Your bookings will appear here\nonce you request a service.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _formatTime(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $period';
}