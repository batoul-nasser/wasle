import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackMyOrderPage extends StatefulWidget {
  const TrackMyOrderPage({super.key});

  @override
  State<TrackMyOrderPage> createState() => _TrackMyOrderPageState();
}

class _TrackMyOrderPageState extends State<TrackMyOrderPage> {
  GoogleMapController? mapController;
  final _db = Supabase.instance.client;
  late final Future<Map<String, dynamic>?> _trackingFuture = _loadTrackingData();

  Future<Map<String, dynamic>?> _loadTrackingData() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    final order = await _db
        .from('orders')
        .select(
          'id, tracking_code, status, created_at, '
          'dropoff_type, customer_address_text, '
          'destination_pickup_point_id, dropoff_location_lat, dropoff_location_lng',
        )
        .eq('customer_profile_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (order == null) return null;

    final destinationPickupId = order['destination_pickup_point_id']?.toString();
    Map<String, dynamic>? destinationPickup;
    if (destinationPickupId != null && destinationPickupId.isNotEmpty) {
      destinationPickup = await _db
          .from('pickup_points')
          .select('id, name, address_text, lat, lng')
          .eq('id', destinationPickupId)
          .maybeSingle();
    }

    return {'order': order, 'destination_pickup': destinationPickup};
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track My Order'), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _trackingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load tracking: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No orders found to track.'));
          }

          final order = Map<String, dynamic>.from(data['order'] as Map);
          final pickup =
              data['destination_pickup'] as Map<String, dynamic>?;
          final lat = (pickup?['lat'] as num?)?.toDouble() ??
              (order['dropoff_location_lat'] as num?)?.toDouble();
          final lng = (pickup?['lng'] as num?)?.toDouble() ??
              (order['dropoff_location_lng'] as num?)?.toDouble();
          final mapSupported = !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS) &&
              lat != null &&
              lng != null;

          return Column(
            children: [
              Expanded(
                flex: 5,
                child: mapSupported
                    ? GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('order_destination'),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(
                              title: pickup?['name']?.toString() ??
                                  'Order destination',
                            ),
                          ),
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                      )
                    : Container(
                        color: const Color(0xFFEFF3F8),
                        alignment: Alignment.center,
                        child: Text(
                          lat != null && lng != null
                              ? 'Destination: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                              : 'Destination map unavailable',
                        ),
                      ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Tracking',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Order: ${order['tracking_code']?.toString() ?? order['id']?.toString() ?? '-'}',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Status: ${order['status']?.toString() ?? '-'}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dropoff: ${pickup?['name']?.toString() ?? order['customer_address_text']?.toString() ?? 'Customer location'}',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Address: ${pickup?['address_text']?.toString() ?? order['customer_address_text']?.toString() ?? '-'}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
