import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/pickup_point/data/pickup_point_repository.dart';

class PickupPointPage extends StatefulWidget {
  const PickupPointPage({super.key});

  @override
  State<PickupPointPage> createState() => _PickupPointPageState();
}

class _PickupPointPageState extends State<PickupPointPage> {
  final AuthService _authService = AuthService();
  final PickupPointRepository _repository = PickupPointRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _allPickupPoints = [];
  List<Map<String, dynamic>> _recentPickupPoints = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_refresh);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.getPickupPointsForSearch(),
        _authService.getCustomerRecentPickupPoints(),
      ]);

      final allPoints = List<Map<String, dynamic>>.from(results[0] as List);
      final recentPoints = List<Map<String, dynamic>>.from(results[1] as List);
      final pickupIds = allPoints
          .map((point) => point['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final usageById = await _repository.getPickupPointUsageCounts(pickupIds);
      final ratingSummaries = await _authService.getPickupPointRatingSummaries(
        pickupIds,
      );

      final enriched = allPoints.map((point) {
        final id = point['id']?.toString() ?? '';
        final summary = ratingSummaries[id] ?? const <String, dynamic>{};
        return {
          ...point,
          'usage_count': usageById[id] ?? 0,
          'rating_average': (summary['average'] as num?)?.toDouble() ?? 0.0,
          'rating_count': (summary['count'] as int?) ?? 0,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _allPickupPoints = enriched;
        _recentPickupPoints = recentPoints;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPickupPoints {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allPickupPoints.where((point) {
      if (query.isEmpty) return true;
      final haystack = [
        point['name'],
        point['address_text'],
        point['city'],
        point['area'],
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final aCityMatch =
          (a['city']?.toString().toLowerCase() ?? '').contains(query) ? 1 : 0;
      final bCityMatch =
          (b['city']?.toString().toLowerCase() ?? '').contains(query) ? 1 : 0;
      if (aCityMatch != bCityMatch) {
        return bCityMatch.compareTo(aCityMatch);
      }

      final aUsage = (a['usage_count'] as int?) ?? 0;
      final bUsage = (b['usage_count'] as int?) ?? 0;
      if (aUsage != bUsage) return bUsage.compareTo(aUsage);

      final aRating = (a['rating_average'] as num?)?.toDouble() ?? 0.0;
      final bRating = (b['rating_average'] as num?)?.toDouble() ?? 0.0;
      if (aRating != bRating) return bRating.compareTo(aRating);

      return (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase());
    });

    return filtered;
  }

  bool _isTopUsedInCity(Map<String, dynamic> point) {
    final city = point['city']?.toString().trim().toLowerCase() ?? '';
    if (city.isEmpty) return false;

    final usage = (point['usage_count'] as int?) ?? 0;
    final topUsage = _allPickupPoints
        .where(
          (item) => (item['city']?.toString().trim().toLowerCase() ?? '') == city,
        )
        .fold<int>(0, (max, item) {
          final count = (item['usage_count'] as int?) ?? 0;
          return count > max ? count : max;
        });

    return usage > 0 && usage == topUsage;
  }

  String _ratingLabel(Map<String, dynamic> point) {
    final rating = (point['rating_average'] as num?)?.toDouble() ?? 0.0;
    final count = (point['rating_count'] as int?) ?? 0;
    if (count == 0) return 'New';
    return '${rating.toStringAsFixed(1)} ($count)';
  }

  Widget _buildRecentSection() {
    if (_recentPickupPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Previously Used',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._recentPickupPoints.take(3).map(
          (point) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade50),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point['name']?.toString() ?? 'Pickup Point',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          point['address_text'],
                          point['city'],
                          point['area'],
                        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', '),
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildPickupPointCard(Map<String, dynamic> point) {
    final address = [
      point['address_text']?.toString().trim(),
      point['city']?.toString().trim(),
      point['area']?.toString().trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PickupPointDetailPage(pickupPoint: point),
        ),
      ).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.blue.shade50,
                child: (point['image_url']?.toString().trim().isNotEmpty ?? false)
                    ? Image.network(
                        point['image_url'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.store_mall_directory_outlined,
                          color: Colors.blue,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.store_mall_directory_outlined,
                        color: Colors.blue,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          point['name']?.toString() ?? 'Pickup Point',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF4E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '★ ${_ratingLabel(point)}',
                          style: const TextStyle(
                            color: Color(0xFFD4800A),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.isEmpty ? '-' : address,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((point['phone']?.toString().trim().isNotEmpty ?? false))
                        _miniChip(Icons.phone_outlined, point['phone'].toString()),
                      if (_isTopUsedInCity(point))
                        _miniChip(
                          Icons.local_fire_department_outlined,
                          'Top used in ${point['city'] ?? 'this city'}',
                          fg: Colors.green,
                          bg: Colors.green.shade50,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(
    IconData icon,
    String label, {
    Color fg = Colors.blue,
    Color? bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPickupPoints;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Pickup Points'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by pickup point, city, area, or address',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFDDE5F7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFDDE5F7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRecentSection(),
                  const Text(
                    'Search Results',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No pickup points match this search.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map(_buildPickupPointCard),
                ],
              ),
            ),
    );
  }
}

class PickupPointDetailPage extends StatefulWidget {
  final Map<String, dynamic> pickupPoint;

  const PickupPointDetailPage({super.key, required this.pickupPoint});

  @override
  State<PickupPointDetailPage> createState() => _PickupPointDetailPageState();
}

class _PickupPointDetailPageState extends State<PickupPointDetailPage> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pickupPointId = widget.pickupPoint['id']?.toString() ?? '';
      final reviews = await _authService.getPickupPointReviews(pickupPointId);
      final summaries = await _authService.getPickupPointRatingSummaries([
        pickupPointId,
      ]);
      final summary = summaries[pickupPointId] ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _averageRating = (summary['average'] as num?)?.toDouble() ?? 0.0;
        _reviewCount = (summary['count'] as int?) ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openReviewDialog() async {
    int rating = 5;
    final commentCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate This Pickup Point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = value),
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFD4800A),
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment or feedback',
                  hintText: 'How was the service?',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.submitPickupPointReview(
                    pickupPointId: widget.pickupPoint['id'].toString(),
                    rating: rating,
                    comment: commentCtrl.text,
                  );
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feedback submitted.')),
                  );
                  await _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    commentCtrl.dispose();
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F7)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.pickupPoint;
    final imageUrl = point['image_url']?.toString().trim() ?? '';
    final address = [
      point['address_text']?.toString().trim(),
      point['city']?.toString().trim(),
      point['area']?.toString().trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Pickup Point Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 200,
                    color: Colors.blue.shade50,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.store_mall_directory_outlined,
                              size: 56,
                              color: Colors.blue,
                            ),
                          )
                        : const Icon(
                            Icons.store_mall_directory_outlined,
                            size: 56,
                            color: Colors.blue,
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  point['name']?.toString() ?? 'Pickup Point',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip(
                        'Rating',
                        _reviewCount == 0 ? 'New' : _averageRating.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatChip('Reviews', '$_reviewCount'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        Icons.phone_outlined,
                        'Phone',
                        point['phone']?.toString() ?? '-',
                      ),
                      _infoRow(
                        Icons.location_on_outlined,
                        'Address',
                        address.isEmpty ? '-' : address,
                      ),
                      _infoRow(
                        Icons.schedule_outlined,
                        'Working Hours',
                        point['opening_hours']?.toString() ?? '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openReviewDialog,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Leave Rating & Feedback'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Customer Feedback',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_reviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'No feedback yet for this pickup point.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  ..._reviews.map((review) {
                    final rating = (review['rating'] as num?)?.toInt() ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  review['customer_name']?.toString() ?? 'Customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                List.generate(rating, (_) => '★').join(),
                                style: const TextStyle(
                                  color: Color(0xFFD4800A),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if ((review['comment']?.toString().trim().isNotEmpty ?? false)) ...[
                            const SizedBox(height: 8),
                            Text(
                              review['comment'].toString(),
                              style: const TextStyle(
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
