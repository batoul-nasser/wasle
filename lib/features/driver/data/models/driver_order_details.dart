import 'delivery_timeline_event.dart';
import 'driver_delivery.dart';

class DriverOrderDetails {
  final DriverDelivery delivery;
  final String? orderNotes;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? pickupOpeningHours;
  final List<DeliveryTimelineEvent> events;

  const DriverOrderDetails({
    required this.delivery,
    required this.orderNotes,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupOpeningHours,
    required this.events,
  });
}
