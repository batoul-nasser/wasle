import 'delivery_timeline_event.dart';
import 'driver_delivery.dart';

class DriverOrderDetails {
  final DriverDelivery delivery;
  final String? orderNotes;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final bool hasBackupPickupPoint;
  final String? backupPickupPointName;
  final String? backupPickupPointAddress;
  final double? backupPickupPointLat;
  final double? backupPickupPointLng;
  final String? homeDropoffAddress;
  final double? homeDropoffLat;
  final double? homeDropoffLng;
  final String? pickupOpeningHours;
  final List<DeliveryTimelineEvent> events;

  const DriverOrderDetails({
    required this.delivery,
    required this.orderNotes,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.hasBackupPickupPoint,
    required this.backupPickupPointName,
    required this.backupPickupPointAddress,
    required this.backupPickupPointLat,
    required this.backupPickupPointLng,
    required this.homeDropoffAddress,
    required this.homeDropoffLat,
    required this.homeDropoffLng,
    required this.pickupOpeningHours,
    required this.events,
  });
}
