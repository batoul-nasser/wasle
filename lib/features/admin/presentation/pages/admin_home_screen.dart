import 'package:flutter/material.dart';
import 'package:wasle/core/services/supabase_service.dart';
import 'package:wasle/features/agent/data/agent_service.dart';
import 'admin_create_agent_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  final AgentService _agentService = AgentService();
  late TabController _tabController;

  bool _loading = true;
  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _collectionHistory = [];
  List<Map<String, dynamic>> _pendingPickupPoints = [];
  double _totalPendingCash = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final agents = await _agentService.getAllAgents();
    final history = await _agentService.getCollectionHistory();
    final pending = await _agentService.getPickupPointsWithPendingCash();
    final total = await _agentService.getTotalPendingAgentCash();
    if (!mounted) return;
    setState(() {
      _agents = agents;
      _collectionHistory = history;
      _pendingPickupPoints = pending;
      _totalPendingCash = total;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout_outlined), onPressed: _signOut),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline), text: 'Agents'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Collections'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAgentsTab(),
                _buildCollectionsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WASLE ADMIN', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1)),
              SizedBox(height: 8),
              Text('Platform Overview', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Manage agents, monitor collections, and oversee operations.',
                  style: TextStyle(color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 24),
          // Stats
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _statCard(icon: Icons.people_outline, value: '${_agents.length}', label: 'Active Agents', color: Colors.blue),
              _statCard(icon: Icons.store_outlined, value: '${_pendingPickupPoints.length}', label: 'Locations Pending', color: Colors.orange),
              _statCard(icon: Icons.payments_outlined, value: '\$${_totalPendingCash.toStringAsFixed(0)}', label: 'Total to Collect', color: Colors.red),
              _statCard(icon: Icons.check_circle_outline, value: '${_collectionHistory.length}', label: 'Total Collected', color: Colors.green),
            ],
          ),
          // Pending pickup points
          if (_pendingPickupPoints.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Awaiting Agent Collection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._pendingPickupPoints.map((pp) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.store_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pp['name']?.toString() ?? 'Pickup Point',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(pp['address_text']?.toString() ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('${pp['order_count']} order${(pp['order_count'] as int? ?? 0) == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
                Text('\$${(pp['total_pending'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildAgentsTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _agents.isEmpty
            ? const Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No agents yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Create your first agent using the + button.', style: TextStyle(color: Colors.grey)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _agents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final agent = _agents[i];
                  final name = agent['full_name']?.toString() ?? 'Agent';
                  final phone = agent['phone']?.toString() ?? '';
                  final myCollections = _collectionHistory
                      .where((c) => c['agent_id']?.toString() == agent['id']?.toString())
                      .toList();
                  final totalCollected = myCollections.fold<double>(
                      0, (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0));

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Colors.grey)),
                        Text('${myCollections.length} collections · \$${totalCollected.toStringAsFixed(2)} total',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Text('active', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ),
                    ]),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AdminCreateAgentScreen()),
          );
          if (created == true) await _load();
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Agent'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCollectionsTab() {
    if (_collectionHistory.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No collections yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Agent collections will appear here once confirmed.', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _collectionHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _collectionHistory[i];
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final agentName = (item['profiles'] as Map?)?['full_name']?.toString() ?? 'Agent';
        final ppName = (item['pickup_points'] as Map?)?['name']?.toString() ?? 'Pickup Point';
        final note = item['note']?.toString() ?? '';
        final collectedAt = item['collected_at']?.toString() ?? '';

        DateTime? dt;
        try { dt = DateTime.parse(collectedAt).toLocal(); } catch (_) {}

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ppName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('by $agentName', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              Text('\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
            ]),
            if (note.isNotEmpty) ...[const SizedBox(height: 8), Text(note, style: const TextStyle(color: Colors.grey))],
            if (dt != null) ...[
              const SizedBox(height: 4),
              Text('${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ]),
        );
      },
    );
  }

  Widget _statCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }
}