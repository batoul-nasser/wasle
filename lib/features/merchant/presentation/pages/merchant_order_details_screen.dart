import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wasle/core/utils/app_date_time.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> initialOrder;

  const MerchantOrderDetailsScreen({
    super.key,
    required this.initialOrder,
  });

  @override
  State<MerchantOrderDetailsScreen> createState() =>
      _MerchantOrderDetailsScreenState();
}

class _MerchantOrderDetailsScreenState
    extends State<MerchantOrderDetailsScreen> {
  final OrdersService _ordersService = OrdersService();

  late Map<String, dynamic> _order;
  List<Map<String, dynamic>> _events = [];
  String? _companyName;
  Map<String, String>? _pickupPointDetails;
  Map<String, String>? _destinationPickupPointDetails;

  bool _loading = true;
  bool _loadingTimeline = true;
  bool _loadingAssignment = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.initialOrder);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingTimeline = true;
        _loadingAssignment = true;
      });
    }

    try {
      final orderId = _safe(_order['id'], fallback: '');

      if (orderId.isNotEmpty) {
        final refreshedOrder = await _ordersService.getOrderById(orderId);
        if (refreshedOrder != null) {
          _order = Map<String, dynamic>.from(refreshedOrder);
        }
      }

      await Future.wait([
        _loadTimeline(),
        _loadAssignmentDetails(),
        _loadPickupPointDetails(),
        _loadDestinationPickupPointDetails(),
      ]);
    } catch (_) {
      // keep current snapshot
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadTimeline() async {
    try {
      final orderId = _safe(_order['id'], fallback: '');

      if (orderId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _events = [];
          _loadingTimeline = false;
        });
        return;
      }

      final events = await _ordersService.getOrderEvents(orderId);

      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(events);
        _loadingTimeline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = [];
        _loadingTimeline = false;
      });
    }
  }

  Future<void> _loadAssignmentDetails() async {
    try {
      final companyId = _safe(_order['delivery_company_id'], fallback: '');

      if (companyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _companyName = null;
          _loadingAssignment = false;
        });
        return;
      }

      final companyName = await _ordersService.getCompanyNameById(companyId);

      if (!mounted) return;
      setState(() {
        _companyName = companyName;
        _loadingAssignment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _companyName = null;
        _loadingAssignment = false;
      });
    }
  }

  Future<void> _loadPickupPointDetails() async {
    try {
      final pickupPointId = _safe(_order['pickup_point_id'], fallback: '');

      if (pickupPointId.isEmpty || pickupPointId == '-') {
        if (!mounted) return;
        setState(() {
          _pickupPointDetails = null;
        });
        return;
      }

      final details = await _ordersService.getPickupPointById(pickupPointId);

      if (!mounted) return;
      setState(() {
        _pickupPointDetails = details;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickupPointDetails = null;
      });
    }
  }

  Future<void> _loadDestinationPickupPointDetails() async {
    try {
      final pickupPointId = _safe(
        _order['destination_pickup_point_id'],
        fallback: '',
      );

      if (pickupPointId.isEmpty || pickupPointId == '-') {
        if (!mounted) return;
        setState(() {
          _destinationPickupPointDetails = null;
        });
        return;
      }

      final details = await _ordersService.getPickupPointById(pickupPointId);

      if (!mounted) return;
      setState(() {
        _destinationPickupPointDetails = details;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destinationPickupPointDetails = null;
      });
    }
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _tryParseDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  String _detailText(Map<String, String>? details, List<String> keys) {
    if (details == null) return '';

    for (final key in keys) {
      final value = details[key]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  String get _notesText {
    final raw = _order['notes']?.toString() ?? '';
    return raw.trim();
  }

  String get _merchantNotesDisplay {
    final text = _notesText;
    if (text.isEmpty) return '-';

    const marker = '=== MERCHANT NOTES ===';
    final markerIndex = text.toLowerCase().indexOf(marker.toLowerCase());

    if (markerIndex >= 0) {
      final merchantNotes = text.substring(markerIndex + marker.length).trim();
      return merchantNotes.isEmpty ? '-' : merchantNotes;
    }

    final containsSystemRouting =
        text.contains('=== ROUTING DETAILS ===') ||
        text.contains('Pickup source type:') ||
        text.contains('Dropoff type:') ||
        text.contains('Assigned delivery company:');

    if (containsSystemRouting) return '-';

    return text;
  }

  String? _extractNoteField(String label) {
    final text = _notesText;
    if (text.isEmpty) return null;

    final match = RegExp(
      '^${RegExp.escape(label)}\\s*:\\s*(.+)\$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(text);

    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? _extractAnyNoteField(List<String> labels) {
    for (final label in labels) {
      final value = _extractNoteField(label);
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  _MapCoords? _parseCoordsText(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final parts = value.split(',');
    if (parts.length != 2) return null;

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());

    if (lat == null || lng == null) return null;
    return _MapCoords(lat: lat, lng: lng);
  }

  Future<void> _openLocationInMaps({
    String? coordinatesText,
    String? address,
  }) async {
    Uri? uri;

    final coords = _parseCoordsText(coordinatesText);
    if (coords != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${coords.lat},${coords.lng}',
      );
    } else if (address != null && address.trim().isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}',
      );
    }

    if (uri == null) {
      _showSafeSnack('No valid location found.');
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      _showSafeSnack('Unable to open maps.');
    }
  }

  Future<void> _openSourceInMaps() async {
    await _openLocationInMaps(
      coordinatesText: _pickupSourceCoordinatesDisplay,
      address: _pickupSourceAddressDisplay,
    );
  }

  Future<void> _openDestinationInMaps() async {
    await _openLocationInMaps(
      coordinatesText: _dropoffCoordinatesDisplay,
      address: _dropoffAddressDisplay,
    );
  }

  String _labelFromKey(String value) {
    return value
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String get _currentStatus {
    return _safe(_order['status'], fallback: 'created').toLowerCase();
  }

  bool get _canCancel {
    const cancellableStatuses = {
      'created',
      'pending',
      'confirmed_by_merchant',
      'ready_for_driver_pickup',
      'assigned',
      'assigned_to_company',
      'assigned_to_driver',
      'pending_driver_receipt',
      'driver_received_order',
    };
    return cancellableStatuses.contains(_currentStatus);
  }

  bool get _hasPayment {
    return _order['_payment'] != null ||
        _safe(_order['payment_method'], fallback: '').isNotEmpty ||
        _safe(_order['payment_amount'], fallback: '').isNotEmpty;
  }

  String get _paymentMethodLabel {
    final method = _safe(_order['payment_method'], fallback: '').toLowerCase();
    switch (method) {
      case 'cash_at_pickup':
      case 'cod':
        return 'Cash at Pickup';
      case 'whish_online':
        return 'Whish Online';
      case 'card':
        return 'Card';
      default:
        return method.isEmpty ? 'Payment' : _labelFromKey(method);
    }
  }

  String get _paymentStatusLabel {
    final status = _safe(_order['payment_status'], fallback: 'pending');
    return _labelFromKey(status);
  }

  String get _paymentAmountLabel {
    final amount = _order['payment_amount'];
    if (amount is num) return '\$${amount.toStringAsFixed(2)}';
    final text = _safe(amount, fallback: '');
    return text.isEmpty ? '-' : '\$$text';
  }

  bool get _hasPickupPoint {
    final pickupPointId = _safe(_order['pickup_point_id'], fallback: '');
    return pickupPointId.isNotEmpty && pickupPointId != '-';
  }

  String get _pickupMethodLabel {
    return _hasPickupPoint ? 'Pickup Point' : 'From Store';
  }

  String get _pickupPointDisplay {
    final pickupPointName = _detailText(
      _pickupPointDetails,
      ['name', 'display_name', 'title'],
    );
    final pickupPointAddress = _detailText(
      _pickupPointDetails,
      ['address', 'address_text', 'subtitle', 'location', 'area'],
    );

    if (pickupPointName.isNotEmpty) {
      if (pickupPointAddress.isNotEmpty) {
        return '$pickupPointName — $pickupPointAddress';
      }
      return pickupPointName;
    }

    return '-';
  }

  String get _pickupSourceTypeDisplay {
    final raw = _safe(_order['pickup_source_type'], fallback: '').toLowerCase();

    if (raw == 'pickup_point') return 'Pickup Point';
    if (raw == 'store') return 'Store';

    final fromNotes = _extractNoteField('Pickup source type');
    if (fromNotes != null && fromNotes.trim().isNotEmpty) {
      return _labelFromKey(fromNotes);
    }

    return _pickupMethodLabel;
  }

  String get _pickupSourceDisplay {
    final fromNotes = _extractNoteField('Pickup source');
    if (fromNotes != null) return fromNotes;

    if (_hasPickupPoint && _pickupPointDisplay != '-') {
      return _pickupPointDisplay;
    }

    return 'Store';
  }

  String get _pickupSourceAddressDisplay {
    final fromNotes = _extractNoteField('Pickup source address');
    if (fromNotes != null) return fromNotes;

    final pickupAddress = _detailText(
      _pickupPointDetails,
      ['address', 'address_text', 'subtitle', 'location', 'area'],
    );
    if (pickupAddress.isNotEmpty) return pickupAddress;

    return '-';
  }

  String get _pickupSourceCoordinatesDisplay {
    final fromNotes = _extractNoteField('Pickup source coordinates');
    if (fromNotes != null) return fromNotes;

    final lat = _safeDouble(_detailText(_pickupPointDetails, ['lat', 'latitude']));
    final lng = _safeDouble(_detailText(_pickupPointDetails, ['lng', 'longitude']));
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }

    return '-';
  }

  String get _dropoffTypeRaw {
    final direct = _safe(_order['dropoff_type'], fallback: '').toLowerCase();
    if (direct.isNotEmpty) return direct;

    final fromNotes = _extractNoteField('Dropoff type');
    if (fromNotes != null && fromNotes.trim().isNotEmpty) {
      return fromNotes
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('-', '_');
    }

    return 'home';
  }

  bool get _isHomeDelivery {
    final type = _dropoffTypeRaw;
    return type == 'home' ||
        type == 'home_delivery' ||
        type == 'customer_home' ||
        type.contains('home');
  }

  bool get _isSpecificPickupDestination {
    final type = _dropoffTypeRaw;
    return type == 'pickup_point_specific' ||
        type == 'specific_pickup_point' ||
        type == 'specific_pickup' ||
        (type.contains('pickup') && type.contains('specific'));
  }

  bool get _hasDestinationPickupPoint {
    final id = _safe(_order['destination_pickup_point_id'], fallback: '');
    return id.isNotEmpty && id != '-';
  }

  String _destinationPickupPointName({bool withAddress = false}) {
    final name = _detailText(
      _destinationPickupPointDetails,
      ['name', 'display_name', 'title'],
    );
    final address = _detailText(
      _destinationPickupPointDetails,
      ['address', 'address_text', 'subtitle', 'location', 'area'],
    );

    if (name.isNotEmpty && withAddress && address.isNotEmpty) {
      return '$name — $address';
    }

    if (name.isNotEmpty) return name;
    if (address.isNotEmpty) return address;

    final fromNotes = _extractAnyNoteField([
      'Destination pickup point',
      'Destination pickup point name',
      'Option 2 pickup point',
      'Backup pickup point',
      'Backup pickup point if customer unavailable',
      'Backup pickup',
      'Option 2 — Pickup Point if Customer is Unavailable',
      'If customer is not at home, send order to this pickup point',
    ]);

    if (fromNotes != null && fromNotes.trim().isNotEmpty) {
      return fromNotes;
    }

    final dropoff = _extractNoteField('Dropoff destination');
    if (dropoff != null &&
        dropoff.trim().isNotEmpty &&
        dropoff.trim().toLowerCase() != 'pickup point' &&
        dropoff.trim().toLowerCase() != 'specific pickup point') {
      return dropoff;
    }

    return _hasDestinationPickupPoint ? 'Pickup Point' : '-';
  }

  String _destinationPickupPointAddress({bool allowNameFallback = false}) {
    final address = _detailText(
      _destinationPickupPointDetails,
      ['address', 'address_text', 'subtitle', 'location', 'area'],
    );
    final name = _detailText(
      _destinationPickupPointDetails,
      ['name', 'display_name', 'title'],
    );

    if (address.isNotEmpty) return address;

    final fromNotes = _extractAnyNoteField([
      'Destination pickup point address',
      'Destination pickup address',
      'Option 2 pickup point address',
      'Option 2 address',
      'Backup pickup point address',
      'Backup pickup address',
    ]);

    if (fromNotes != null && fromNotes.trim().isNotEmpty) return fromNotes;
    if (allowNameFallback && name.isNotEmpty) return name;

    return _hasDestinationPickupPoint ? 'Pickup Point' : '-';
  }

  String _destinationPickupPointCoordinates() {
    final lat = _safeDouble(
      _detailText(_destinationPickupPointDetails, ['lat', 'latitude']),
    );
    final lng = _safeDouble(
      _detailText(_destinationPickupPointDetails, ['lng', 'longitude']),
    );

    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }

    final fromNotes = _extractAnyNoteField([
      'Destination pickup point coordinates',
      'Destination pickup coordinates',
      'Option 2 pickup point coordinates',
      'Option 2 coordinates',
      'Backup pickup point coordinates',
      'Backup pickup coordinates',
    ]);

    if (fromNotes != null && fromNotes.trim().isNotEmpty) return fromNotes;

    return '-';
  }

  String get _dropoffTypeDisplay {
    if (_isHomeDelivery) return 'Home Delivery';
    if (_isSpecificPickupDestination) return 'Specific Pickup Point';

    final raw = _dropoffTypeRaw;
    return raw.isEmpty ? 'Home Delivery' : _labelFromKey(raw);
  }

  String get _homeDeliveryAddressDisplay {
    final direct = _safe(_order['customer_address_text'], fallback: '');
    if (direct.isNotEmpty) return direct;

    final requested = _extractNoteField('Customer requested address');
    if (requested != null && requested.trim().isNotEmpty) return requested;

    final dropoff = _extractNoteField('Dropoff address');
    if (dropoff != null && dropoff.trim().isNotEmpty) return dropoff;

    return 'No address provided';
  }

  String get _homeDeliveryCoordinatesDisplay {
    if (_hasPinnedLocation) return _mapCoordinatesDisplay;

    final requested = _extractNoteField('Customer requested coordinates');
    if (requested != null && requested.trim().isNotEmpty) return requested;

    final dropoff = _extractNoteField('Dropoff coordinates');
    if (dropoff != null && dropoff.trim().isNotEmpty) return dropoff;

    return '-';
  }

  String get _specificDestinationPickupPointDisplay {
    final point = _destinationPickupPointName(withAddress: false);
    if (point != '-') return point;

    final fromNotes = _extractNoteField('Dropoff destination');
    if (fromNotes != null && fromNotes.trim().isNotEmpty) return fromNotes;

    return 'Pickup Point';
  }

  String get _specificDestinationAddressDisplay {
    final address = _destinationPickupPointAddress(allowNameFallback: true);
    if (address != '-') return address;

    final fromNotes = _extractNoteField('Dropoff address');
    if (fromNotes != null && fromNotes.trim().isNotEmpty) return fromNotes;

    return '-';
  }

  String get _specificDestinationCoordinatesDisplay {
    final coords = _destinationPickupPointCoordinates();
    if (coords != '-') return coords;

    final fromNotes = _extractNoteField('Dropoff coordinates');
    if (fromNotes != null && fromNotes.trim().isNotEmpty) return fromNotes;

    return '-';
  }

  String get _dropoffDestinationDisplay {
    if (_isHomeDelivery) return 'Customer Map Pin';
    return _specificDestinationPickupPointDisplay;
  }

  String get _dropoffAddressDisplay {
    if (_isHomeDelivery) return _homeDeliveryAddressDisplay;
    return _specificDestinationAddressDisplay;
  }

  String get _backupPickupTitleDisplay {
    if (_isHomeDelivery && _hasDestinationPickupPoint) {
      final fromDetails = _destinationPickupPointName(withAddress: false);
      if (fromDetails != '-') return fromDetails;
    }

    final fromNotes = _extractAnyNoteField([
      'Backup pickup point',
      'Backup pickup',
      'Option 2 — Pickup Point if Customer is Unavailable',
      'If customer is not at home, send order to this pickup point',
    ]);

    if (fromNotes != null) return fromNotes;
    return '-';
  }

  String get _backupPickupAddressDisplay {
    if (_isHomeDelivery && _hasDestinationPickupPoint) {
      final fromDetails = _destinationPickupPointAddress();
      if (fromDetails != '-') return fromDetails;
    }

    final fromNotes = _extractAnyNoteField([
      'Option 2 pickup point address',
      'Option 2 address',
      'Backup pickup point address',
      'Backup pickup address',
    ]);

    if (fromNotes != null) return fromNotes;
    return '-';
  }

  String get _backupPickupCoordinatesDisplay {
    if (_isHomeDelivery && _hasDestinationPickupPoint) {
      final fromDetails = _destinationPickupPointCoordinates();
      if (fromDetails != '-') return fromDetails;
    }

    final fromNotes = _extractAnyNoteField([
      'Option 2 pickup point coordinates',
      'Option 2 coordinates',
      'Backup pickup point coordinates',
      'Backup pickup coordinates',
    ]);

    if (fromNotes != null) return fromNotes;
    return '-';
  }

  bool get _hasBackupPickup {
    return _isHomeDelivery &&
        (_hasDestinationPickupPoint ||
            _backupPickupTitleDisplay != '-' ||
            _backupPickupAddressDisplay != '-' ||
            _backupPickupCoordinatesDisplay != '-');
  }

  Future<void> _openBackupPickupInMaps() async {
    await _openLocationInMaps(
      coordinatesText: _backupPickupCoordinatesDisplay,
      address: _backupPickupAddressDisplay != '-'
          ? _backupPickupAddressDisplay
          : (_backupPickupTitleDisplay != '-' ? _backupPickupTitleDisplay : null),
    );
  }

  String get _packageDescriptionDisplay {
    return _safe(_order['parcel_description'], fallback: '-');
  }

  String get _itemCountDisplay {
    final value = _order['item_count'];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  String get _weightDisplay {
    final value = _order['estimated_weight'];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : '$text kg';
  }

  String get _volumeDisplay {
    final value = _order['estimated_volume'];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : '$text cm³';
  }

  double? get _customerLat => _safeDouble(_order['customer_lat']);
  double? get _customerLng => _safeDouble(_order['customer_lng']);

  bool get _hasPinnedLocation => _customerLat != null && _customerLng != null;

  String get _mapCoordinatesDisplay {
    if (!_hasPinnedLocation) return '-';
    return '${_customerLat!.toStringAsFixed(6)}, ${_customerLng!.toStringAsFixed(6)}';
  }

  String get _dropoffCoordinatesDisplay {
    if (_isHomeDelivery) return _homeDeliveryCoordinatesDisplay;
    return _specificDestinationCoordinatesDisplay;
  }

  bool get _hasSourceLocationLink {
    return _pickupSourceCoordinatesDisplay != '-' ||
        _pickupSourceAddressDisplay != '-';
  }

  bool get _hasDestinationLocationLink {
    if (_isHomeDelivery) {
      return _homeDeliveryCoordinatesDisplay != '-' ||
          _homeDeliveryAddressDisplay != 'No address provided';
    }

    return _specificDestinationCoordinatesDisplay != '-' ||
        _specificDestinationAddressDisplay != '-';
  }

  Future<void> _openInMaps() async {
    if (!_hasPinnedLocation) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_customerLat!},${_customerLng!}',
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      _showSafeSnack('Unable to open maps.');
    }
  }

  List<Map<String, dynamic>> get _timelineEvents {
    final sorted = List<Map<String, dynamic>>.from(_events)
      ..sort((a, b) {
        final aDate = _tryParseDate(a['created_at']);
        final bDate = _tryParseDate(b['created_at']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;
        return aDate.compareTo(bDate);
      });

    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final event in sorted) {
      final type = _safe(event['event_type'], fallback: 'event');
      final createdAt = _safe(event['created_at'], fallback: '');
      final note = _safe(event['note'], fallback: '');
      final key = '$type|$createdAt|$note';

      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(event);
    }

    return result;
  }

  Map<String, dynamic>? _latestEventOfTypes(List<String> types) {
    final set = types.map((e) => e.toLowerCase()).toSet();

    for (final event in _timelineEvents.reversed) {
      final type = _safe(event['event_type'], fallback: '').toLowerCase();
      if (set.contains(type)) return event;
    }

    return null;
  }

  String _titleize(String value) {
    return value
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String? _extractResolutionFromNote(String note) {
    final match = RegExp(
      r'resolution\s*:\s*([a-zA-Z _-]+)',
      caseSensitive: false,
    ).firstMatch(note);

    if (match != null) {
      final raw = (match.group(1) ?? '').trim();
      if (raw.isNotEmpty) {
        return _titleize(raw.replaceAll('_', ' '));
      }
    }

    final lower = note.toLowerCase();

    if (lower.contains('return to store') ||
        lower.contains('returned to store') ||
        lower.contains('returning to store') ||
        lower.contains('returned to merchant') ||
        lower.contains('returning to merchant')) {
      return 'Return to Merchant';
    }

    if (lower.contains('rescheduled') || lower.contains('reschedule')) {
      return 'Rescheduled';
    }

    if (lower.contains('pickup point')) {
      return 'Pickup Point Drop';
    }

    return null;
  }

  String? get _rootReason {
    final failed = _latestEventOfTypes(['delivery_failed', 'failed']);
    final failedNote = _safe(failed?['note'], fallback: '').toLowerCase();

    if (failedNote.contains('customer not available')) {
      return 'Customer not available';
    }

    if (failed != null) {
      return 'Delivery failed';
    }

    if (_currentStatus == 'cancelled') return 'Cancellation requested';

    if (_currentStatus == 'dropped_at_pickup_point') {
      return 'Dropped at pickup point';
    }

    if (_currentStatus == 'rescheduled') {
      return 'Delivery rescheduled';
    }

    if (_currentStatus == 'returned_to_store' ||
        _currentStatus == 'returned_to_merchant') {
      return 'Returned to merchant';
    }

    if (_currentStatus == 'returning' ||
        _currentStatus == 'returning_to_store' ||
        _currentStatus == 'return_in_progress') {
      return 'Returning to merchant';
    }

    return null;
  }

  String? get _rootResolution {
    for (final event in _timelineEvents.reversed) {
      final note = _safe(event['note'], fallback: '');
      final resolution = _extractResolutionFromNote(note);
      if (resolution != null) return resolution;
    }

    if (_currentStatus == 'dropped_at_pickup_point') {
      return 'Pickup Point Drop';
    }

    if (_currentStatus == 'rescheduled') {
      return 'Rescheduled';
    }

    if (_currentStatus == 'returned_to_store' ||
        _currentStatus == 'returned_to_merchant') {
      return 'Return to Merchant Completed';
    }

    if (_currentStatus == 'returning' ||
        _currentStatus == 'returning_to_store' ||
        _currentStatus == 'return_in_progress') {
      return 'Return to Merchant In Progress';
    }

    if (_currentStatus == 'cancelled') {
      final cancelled = _latestEventOfTypes(['cancelled']);
      final note = _safe(cancelled?['note'], fallback: '');
      if (note.toLowerCase().startsWith('reason:')) {
        return note.substring(7).trim();
      }
      return 'Cancellation recorded';
    }

    return null;
  }

  bool get _hasException => _rootReason != null;

  String _eventTitle(String raw) {
    switch (raw.toLowerCase()) {
      case 'order_created':
        return 'Order Created';
      case 'confirmed_by_merchant':
        return 'Confirmed by Merchant';
      case 'ready_for_driver_pickup':
        return 'Ready for Driver Pickup';
      case 'pending_driver_receipt':
        return 'Pending Driver Receipt';
      case 'driver_received_order':
        return 'Driver Received Order';
      case 'assigned_to_company':
        return 'Assigned to Company';
      case 'assigned_to_driver':
        return 'Assigned to Driver';
      case 'picked_up':
        return 'Picked Up';
      case 'picked_up_from_merchant':
        return 'Picked Up from Merchant';
      case 'in_transit':
        return 'In Transit';
      case 'in_transit_to_pickup_point':
        return 'In Transit to Pickup Point';
      case 'arrived_at_pickup_point':
        return 'Arrived at Pickup Point';
      case 'stored_at_pickup_point':
        return 'Stored at Pickup Point';
      case 'ready_for_customer_pickup':
        return 'Ready for Customer Pickup';
      case 'picked_up_by_customer':
        return 'Picked Up by Customer';
      case 'dropped_at_pickup_point':
        return 'Dropped at Pickup Point';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'delivery_failed':
      case 'failed':
        return 'Delivery Failed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      case 'customer_not_available':
        return 'Customer Not Available';
      case 'returning':
      case 'returning_to_store':
      case 'return_in_progress':
        return 'Returning to Merchant';
      case 'returned_to_store':
      case 'returned_to_merchant':
        return 'Returned to Merchant';
      case 'note_added':
        return 'Note Added';
      case 'agent_cash_collected':
        return 'Cash Collected';
      case 'remittance_sent':
        return 'Remittance Sent';
      default:
        return _labelFromKey(raw);
    }
  }

  String _formatDate(dynamic value) {
    return AppDateTime.format(value);
  }

  void _showSafeSnack(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<String?> _openCancellationReasonPage() async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _CancellationReasonScreen(),
      ),
    );
  }

  Future<void> _requestCancellation() async {
    if (_actionLoading) return;

    if (!_canCancel) {
      _showSafeSnack('This order can only be cancelled before pickup.');
      return;
    }

    final reason = await _openCancellationReasonPage();

    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _actionLoading = true);

    try {
      await _ordersService.requestCancellation(
        orderId: _safe(_order['id'], fallback: ''),
        reason: reason.trim(),
      );

      await _loadDetails();

      if (!mounted) return;
      _showSafeSnack('Order cancelled successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSafeSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;
    final trackingCode = _safe(_order['tracking_code']);
    final companyId = _safe(_order['delivery_company_id'], fallback: '');
    final hasCompany = companyId.isNotEmpty && companyId != '-';
    final branchId = _safe(_order['branch_id'], fallback: '');

    return Scaffold(
      backgroundColor: _W.bg,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  _HeaderCard(
                    customerName: _safe(
                      _order['customer_name'],
                      fallback: 'Customer',
                    ),
                    customerPhone: _safe(_order['customer_phone']),
                    trackingCode: trackingCode,
                    status: status,
                  ),
                  const SizedBox(height: 12),
                  if (_hasException) ...[
                    _ExceptionBanner(
                      reason: _rootReason,
                      resolution: _rootResolution,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    icon: Icons.receipt_long_outlined,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Order Summary',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Order ID', value: _safe(_order['id'])),
                        _InfoRow(
                          label: 'Tracking Code',
                          value: trackingCode,
                          valueColor: _W.blue,
                        ),
                        _InfoRow(
                          label: 'Status',
                          child: _StatusBadge(status: status),
                        ),
                        _InfoRow(
                          label: 'Created At',
                          value: _formatDate(_order['created_at']),
                        ),
                        _InfoRow(
                          label: 'Updated At',
                          value: _formatDate(_order['updated_at']),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_hasPayment) ...[
                    _SectionCard(
                      icon: Icons.payments_outlined,
                      iconColor: _W.green,
                      iconBg: _W.greenLt,
                      title: 'Payment Information',
                      child: Column(
                        children: [
                          _InfoRow(label: 'Method', value: _paymentMethodLabel),
                          _InfoRow(
                            label: 'Status',
                            value: _paymentStatusLabel,
                            valueColor: _W.amber,
                          ),
                          _InfoRow(
                            label: 'Amount',
                            value: _paymentAmountLabel,
                            valueColor: _W.blue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    icon: Icons.person_outline,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Customer Information',
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Name',
                          value: _safe(
                            _order['customer_name'],
                            fallback: 'Customer',
                          ),
                        ),
                        _InfoRow(
                          label: 'Phone',
                          value: _safe(_order['customer_phone']),
                          valueColor: _W.blue,
                        ),
                        if (_safe(_order['customer_email'], fallback: '')
                            .isNotEmpty)
                          _InfoRow(
                            label: 'Email',
                            value: _safe(_order['customer_email']),
                            valueColor: _W.blue,
                          ),
                        if (_merchantNotesDisplay != '-')
                          _InfoRow(
                            label: 'Notes',
                            value: _merchantNotesDisplay,
                            valueColor: _W.gray,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.route_outlined,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Delivery Information',
                    child: _buildDeliveryInformation(branchId),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: _W.slate,
                    iconBg: _W.slateLt,
                    title: 'Package Information',
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Description',
                          value: _packageDescriptionDisplay,
                        ),
                        _InfoRow(
                          label: 'Item Count',
                          value: _itemCountDisplay,
                        ),
                        _InfoRow(
                          label: 'Weight',
                          value: _weightDisplay,
                        ),
                        _InfoRow(
                          label: 'Volume',
                          value: _volumeDisplay,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: _W.green,
                    iconBg: _W.greenLt,
                    title: 'Assignment Information',
                    child: _loadingAssignment
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: _W.blue,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AssignmentBanner(
                                hasCompany: hasCompany,
                                title: hasCompany
                                    ? 'Order is assigned to a delivery company.'
                                    : 'This order is still waiting for assignment.',
                                subtitle: hasCompany
                                    ? 'Company details are now available below.'
                                    : 'Once a company accepts it, assignment details will appear here.',
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: 'Delivery Company',
                                value: hasCompany
                                    ? ((_companyName?.trim().isNotEmpty ?? false)
                                        ? _companyName!
                                        : companyId)
                                    : 'Waiting for assignment',
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.timeline_outlined,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Order Timeline',
                    child: _loadingTimeline
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: _W.blue,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : _timelineEvents.isEmpty
                            ? Text(
                                'No timeline events yet.',
                                style: _t(
                                  13,
                                  FontWeight.w500,
                                  color: _W.gray,
                                ),
                              )
                            : Column(
                                children: List.generate(_timelineEvents.length, (
                                  i,
                                ) {
                                  final event = _timelineEvents[i];
                                  final title = _eventTitle(
                                    _safe(event['event_type'], fallback: 'event'),
                                  );
                                  final note = _safe(event['note'], fallback: '');
                                  final createdAt = _formatDate(
                                    event['created_at'],
                                  );

                                  return _TimelineStep(
                                    title: title,
                                    subtitle: note.isEmpty
                                        ? createdAt
                                        : '$createdAt\n$note',
                                    isLast: i == _timelineEvents.length - 1,
                                  );
                                }),
                              ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.bolt_outlined,
                    iconColor: _W.slate,
                    iconBg: _W.slateLt,
                    title: 'Merchant Actions',
                    child: Column(
                      children: [
                        _ActionBtn(
                          icon: Icons.cancel_outlined,
                          label: status == 'cancelled'
                              ? 'Cancellation Submitted'
                              : 'Request Cancellation',
                          sublabel: status == 'cancelled'
                              ? 'This order is already cancelled.'
                              : _canCancel
                                  ? 'Cancel this order before pickup.'
                                  : 'Cancellation is closed after pickup.',
                          color: _W.red,
                          bg: _W.redLt,
                          borderColor: _W.red.withOpacity(0.18),
                          onTap: (_actionLoading || status == 'cancelled')
                              ? null
                              : _requestCancellation,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDeliveryInformation(String branchId) {
    final blocks = <Widget>[
      _RouteBlock(
        icon: Icons.storefront_outlined,
        title: 'Pickup Source',
        badge: _pickupSourceTypeDisplay,
        rows: [
          _RouteInfoItem(label: 'Source', value: _pickupSourceDisplay),
          _RouteInfoItem(label: 'Address', value: _pickupSourceAddressDisplay),
          _RouteInfoItem(
            label: 'Coordinates',
            value: _pickupSourceCoordinatesDisplay,
            valueColor: _pickupSourceCoordinatesDisplay != '-' ? _W.blue : null,
          ),
        ],
        actionLabel: _hasSourceLocationLink ? 'Open source in maps' : null,
        onAction: _hasSourceLocationLink ? _openSourceInMaps : null,
      ),
    ];

    if (_isHomeDelivery) {
      blocks.addAll([
        const SizedBox(height: 12),
        _RouteBlock(
          icon: Icons.home_outlined,
          title: 'Option 1 — Home Delivery',
          badge: 'Customer map pin',
          rows: [
            _RouteInfoItem(label: 'Destination', value: 'Customer address'),
            _RouteInfoItem(label: 'Address', value: _homeDeliveryAddressDisplay),
            _RouteInfoItem(
              label: 'Coordinates',
              value: _homeDeliveryCoordinatesDisplay,
              valueColor:
                  _homeDeliveryCoordinatesDisplay != '-' ? _W.blue : null,
            ),
          ],
          actionLabel: _hasDestinationLocationLink ? 'Open option 1 in maps' : null,
          onAction: _hasDestinationLocationLink ? _openDestinationInMaps : null,
        ),
        const SizedBox(height: 12),
        _RouteBlock(
          icon: Icons.store_mall_directory_outlined,
          title: 'Option 2 — Backup Pickup Point',
          badge: 'If customer is unavailable',
          rows: [
            _RouteInfoItem(
              label: 'Pickup Point',
              value: _backupPickupTitleDisplay == '-'
                  ? 'Not selected'
                  : _backupPickupTitleDisplay,
            ),
            _RouteInfoItem(
              label: 'Address',
              value: _backupPickupAddressDisplay == '-'
                  ? 'No backup address saved'
                  : _backupPickupAddressDisplay,
            ),
            _RouteInfoItem(
              label: 'Coordinates',
              value: _backupPickupCoordinatesDisplay,
              valueColor:
                  _backupPickupCoordinatesDisplay != '-' ? _W.blue : null,
            ),
          ],
          actionLabel: _hasBackupPickup ? 'Open option 2 in maps' : null,
          onAction: _hasBackupPickup ? _openBackupPickupInMaps : null,
        ),
      ]);
    } else {
      blocks.addAll([
        const SizedBox(height: 12),
        _RouteBlock(
          icon: Icons.store_mall_directory_outlined,
          title: 'Destination',
          badge: _dropoffTypeDisplay,
          rows: [
            _RouteInfoItem(
              label: 'Pickup Point',
              value: _specificDestinationPickupPointDisplay,
            ),
            _RouteInfoItem(
              label: 'Address',
              value: _specificDestinationAddressDisplay,
            ),
            _RouteInfoItem(
              label: 'Coordinates',
              value: _specificDestinationCoordinatesDisplay,
              valueColor:
                  _specificDestinationCoordinatesDisplay != '-' ? _W.blue : null,
            ),
          ],
          actionLabel: _hasDestinationLocationLink ? 'Open destination in maps' : null,
          onAction: _hasDestinationLocationLink ? _openDestinationInMaps : null,
        ),
      ]);
    }

    if (branchId.isNotEmpty && branchId != '-') {
      blocks.addAll([
        const SizedBox(height: 12),
        _InfoRow(label: 'Branch', value: branchId),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _W.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _W.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _W.border, width: 1.5),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 22,
              color: _W.navy,
            ),
          ),
        ),
      ),
      leadingWidth: 60,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Details', style: _t(17, FontWeight.w900)),
          Text(
            'Track & manage this delivery',
            style: _t(11.5, FontWeight.w500, color: _W.gray),
          ),
        ],
      ),
    );
  }
}

class _CancellationReasonScreen extends StatefulWidget {
  const _CancellationReasonScreen();

  @override
  State<_CancellationReasonScreen> createState() =>
      _CancellationReasonScreenState();
}

class _CancellationReasonScreenState extends State<_CancellationReasonScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _W.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Cancellation Reason', style: _t(18, FontWeight.w900)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _W.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _W.border, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why are you cancelling this order?',
                              style: _t(15, FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Write a clear reason before submitting.',
                              style: _t(
                                13,
                                FontWeight.w500,
                                color: _W.gray,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _controller,
                              minLines: 3,
                              maxLines: 4,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                hintText: 'Customer requested cancellation...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: const Text('Submit Cancellation'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapCoords {
  final double lat;
  final double lng;

  const _MapCoords({
    required this.lat,
    required this.lng,
  });
}

class _W {
  _W._();

  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const blue = Color(0xFF1A56DB);
  static const blueDark = Color(0xFF1044C4);
  static const blueLt = Color(0xFFEBF0FD);
  static const navy = Color(0xFF0B1D3F);
  static const gray = Color(0xFF6B7A99);
  static const border = Color(0xFFDDE5F7);
  static const green = Color(0xFF0BA360);
  static const greenLt = Color(0xFFE6F7EF);
  static const red = Color(0xFFE53054);
  static const redLt = Color(0xFFFDEAED);
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
  static const slateLt = Color(0xFFF1F4FC);
  static const white60 = Color(0x99FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white07 = Color(0x12FFFFFF);
}

TextStyle _t(
  double size,
  FontWeight w, {
  Color color = _W.navy,
  double? height,
  double? spacing,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

BoxDecoration _cardDecor({double radius = 20}) {
  return BoxDecoration(
    color: _W.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _W.border, width: 1.5),
  );
}

class _AssignmentBanner extends StatelessWidget {
  final bool hasCompany;
  final String title;
  final String subtitle;

  const _AssignmentBanner({
    required this.hasCompany,
    required this.title,
    required this.subtitle,
  });

  Color get _bg => hasCompany ? _W.greenLt : _W.blueLt;
  Color get _fg => hasCompany ? _W.green : _W.blue;
  IconData get _icon =>
      hasCompany ? Icons.check_circle_outline : Icons.hourglass_top_outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fg.withOpacity(0.18), width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 18, color: _fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(13, FontWeight.w800, color: _fg)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _t(12, FontWeight.w500, color: _fg, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final String trackingCode;
  final String status;

  const _HeaderCard({
    required this.customerName,
    required this.customerPhone,
    required this.trackingCode,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_W.blueDark, _W.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: _W.white07,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _W.white13,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trackingCode,
                          style: _t(20, FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          customerName,
                          style: _t(13, FontWeight.w600, color: _W.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customerPhone,
                          style: _t(12.5, FontWeight.w500, color: _W.white60),
                        ),
                        const SizedBox(height: 10),
                        _WhiteStatusBadge(status: status),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteStatusBadge extends StatelessWidget {
  final String status;

  const _WhiteStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _W.white20,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: _t(12, FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _ExceptionBanner extends StatelessWidget {
  final String? reason;
  final String? resolution;

  const _ExceptionBanner({this.reason, this.resolution});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _W.redLt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _W.red.withOpacity(0.18), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _W.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_outlined,
              size: 18,
              color: _W.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason ?? 'Exception Outcome',
                  style: _t(13.5, FontWeight.w800, color: _W.red),
                ),
                if (resolution != null && resolution!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Resolution: $resolution',
                    style: _t(12, FontWeight.w500, color: _W.red, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: _t(14.5, FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? child;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _t(12, FontWeight.w600, color: _W.gray)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: child ??
                      Text(
                        value ?? '-',
                        style: _t(
                          13,
                          FontWeight.w700,
                          color: valueColor ?? _W.navy,
                        ),
                      ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: _t(12, FontWeight.w600, color: _W.gray),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: child ??
                    Text(
                      value ?? '-',
                      style: _t(
                        13,
                        FontWeight.w700,
                        color: valueColor ?? _W.navy,
                      ),
                      textAlign: TextAlign.right,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteInfoItem {
  final String label;
  final String value;
  final Color? valueColor;

  const _RouteInfoItem({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class _RouteBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final List<_RouteInfoItem> rows;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _RouteBlock({
    required this.icon,
    required this.title,
    required this.badge,
    required this.rows,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows
        .where((row) => row.value.trim().isNotEmpty)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _W.slateLt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _W.border, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _W.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _W.border),
                ),
                child: Icon(icon, size: 18, color: _W.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _t(14, FontWeight.w900)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _W.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _W.border),
                        ),
                        child: Text(
                          badge,
                          style: _t(11.5, FontWeight.w800, color: _W.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...visibleRows.map((row) => _RouteInfoRow(item: row)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.map_outlined, size: 17),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _W.blue,
                  side: const BorderSide(color: _W.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteInfoRow extends StatelessWidget {
  final _RouteInfoItem item;

  const _RouteInfoRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 360;

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: _t(11.5, FontWeight.w700, color: _W.gray),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: _t(
                    13,
                    FontWeight.w800,
                    color: item.valueColor ?? _W.navy,
                    height: 1.35,
                  ),
                  softWrap: true,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  item.label,
                  style: _t(11.5, FontWeight.w700, color: _W.gray),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.value,
                  style: _t(
                    13,
                    FontWeight.w800,
                    color: item.valueColor ?? _W.navy,
                    height: 1.35,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _statusColor(status).withOpacity(0.25),
        ),
      ),
      child: Text(
        _statusLabel(status),
        style: _t(11.5, FontWeight.w800, color: _statusColor(status)),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _W.blue,
                shape: BoxShape.circle,
                border: Border.all(color: _W.blueLt, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: _W.blueLt,
                margin: const EdgeInsets.symmetric(vertical: 3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(13, FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _t(12, FontWeight.w500, color: _W.gray, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bg;
  final Color borderColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withOpacity(0.10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _t(14, FontWeight.w700, color: color)),
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: _t(
                          12,
                          FontWeight.w500,
                          color: color,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'created':
      return 'Created';
    case 'pending':
      return 'Pending';
    case 'confirmed_by_merchant':
      return 'Confirmed by Merchant';
    case 'ready_for_driver_pickup':
      return 'Ready for Driver Pickup';
    case 'pending_driver_receipt':
      return 'Pending Driver Receipt';
    case 'driver_received_order':
      return 'Driver Received Order';
    case 'assigned':
      return 'Assigned';
    case 'assigned_to_company':
      return 'Assigned to Company';
    case 'assigned_to_driver':
      return 'Assigned to Driver';
    case 'picked_up':
      return 'Picked Up';
    case 'picked_up_from_merchant':
      return 'Picked Up from Merchant';
    case 'in_transit':
      return 'In Transit';
    case 'in_transit_to_pickup_point':
      return 'In Transit to Pickup Point';
    case 'arrived_at_pickup_point':
      return 'Arrived at Pickup Point';
    case 'stored_at_pickup_point':
      return 'Stored at Pickup Point';
    case 'ready_for_customer_pickup':
      return 'Ready for Customer Pickup';
    case 'picked_up_by_customer':
      return 'Picked Up by Customer';
    case 'dropped_at_pickup_point':
      return 'Dropped at Pickup Point';
    case 'delivered':
    case 'completed':
      return 'Delivered';
    case 'delivery_failed':
    case 'failed':
      return 'Delivery Failed';
    case 'cancelled':
      return 'Cancelled';
    case 'rescheduled':
      return 'Rescheduled';
    case 'returning':
    case 'returning_to_store':
    case 'return_in_progress':
      return 'Returning to Merchant';
    case 'returned_to_store':
    case 'returned_to_merchant':
      return 'Returned to Merchant';
    case 'customer_not_available':
      return 'Customer Not Available';
    default:
      return s
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

Color _statusColor(String s) {
  final status = s.toLowerCase();

  if (status == 'delivered' ||
      status == 'completed' ||
      status == 'ready_for_customer_pickup' ||
      status == 'picked_up_by_customer' ||
      status == 'stored_at_pickup_point' ||
      status == 'dropped_at_pickup_point') {
    return _W.green;
  }

  if (status == 'delivery_failed' ||
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'customer_not_available') {
    return _W.red;
  }

  if (status == 'returning' ||
      status == 'returning_to_store' ||
      status == 'return_in_progress' ||
      status == 'returned_to_store' ||
      status == 'returned_to_merchant' ||
      status == 'rescheduled') {
    return _W.amber;
  }

  if (status == 'assigned' ||
      status == 'assigned_to_company' ||
      status == 'assigned_to_driver' ||
      status == 'in_transit' ||
      status == 'in_transit_to_pickup_point' ||
      status == 'picked_up' ||
      status == 'picked_up_from_merchant' ||
      status == 'confirmed_by_merchant' ||
      status == 'ready_for_driver_pickup' ||
      status == 'pending_driver_receipt' ||
      status == 'driver_received_order' ||
      status == 'arrived_at_pickup_point') {
    return _W.blue;
  }

  return _W.slate;
}

Color _statusBg(String s) {
  final status = s.toLowerCase();

  if (status == 'delivered' ||
      status == 'completed' ||
      status == 'ready_for_customer_pickup' ||
      status == 'picked_up_by_customer' ||
      status == 'stored_at_pickup_point' ||
      status == 'dropped_at_pickup_point') {
    return _W.greenLt;
  }

  if (status == 'delivery_failed' ||
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'customer_not_available') {
    return _W.redLt;
  }

  if (status == 'returning' ||
      status == 'returning_to_store' ||
      status == 'return_in_progress' ||
      status == 'returned_to_store' ||
      status == 'returned_to_merchant' ||
      status == 'rescheduled') {
    return _W.amberLt;
  }

  if (status == 'assigned' ||
      status == 'assigned_to_company' ||
      status == 'assigned_to_driver' ||
      status == 'in_transit' ||
      status == 'in_transit_to_pickup_point' ||
      status == 'picked_up' ||
      status == 'picked_up_from_merchant' ||
      status == 'confirmed_by_merchant' ||
      status == 'ready_for_driver_pickup' ||
      status == 'pending_driver_receipt' ||
      status == 'driver_received_order' ||
      status == 'arrived_at_pickup_point') {
    return _W.blueLt;
  }

  return _W.slateLt;
}