import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackMyOrderPage extends StatefulWidget {
  const TrackMyOrderPage({super.key});

  @override
  State<TrackMyOrderPage> createState() => _TrackMyOrderPageState();
}

class _TrackMyOrderPageState extends State<TrackMyOrderPage> {
  late GoogleMapController mapController;

  // Example location: pickup point in Beirut
  static const LatLng pickupPointLocation = LatLng(33.8938, 35.5018);

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('pickup_point'),
      position: pickupPointLocation,
      infoWindow: InfoWindow(
        title: 'Wasle Pickup Point',
        snippet: 'Order is ready here',
      ),
    ),
  };

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    const orderId = 'ORD-1024';
    const orderStatus = 'Arrived at Pickup Point';
    const eta = 'Ready for pickup';
    const pickupPointName = 'Wasle Pickup Point - Beirut';
    const pickupPointAddress = 'Hamra Main Street, Beirut';

    return Scaffold(
      appBar: AppBar(title: const Text('Track My Order'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: pickupPointLocation,
                zoom: 15,
              ),
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
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
                children: const [
                  Text(
                    'Order Tracking',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text('Order ID: ORD-1024', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  Text(
                    'Status: Arrived at Pickup Point',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('ETA: Ready for pickup', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  Text(
                    'Pickup Point: Wasle Pickup Point - Beirut',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Address: Hamra Main Street, Beirut',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
