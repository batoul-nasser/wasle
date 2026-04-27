import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class UpdateLocationScreen extends StatefulWidget {
  const UpdateLocationScreen({super.key});

  @override
  State<UpdateLocationScreen> createState() => _UpdateLocationScreenState();
}

class _UpdateLocationScreenState extends State<UpdateLocationScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? errorText;
  String? driverId;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        setState(() {
          isLoading = false;
          errorText = 'User not found';
        });
        return;
      }

      final driver = await _authService.getDriverByProfileId(user.id);

      if (driver == null) {
        setState(() {
          isLoading = false;
          errorText = 'Driver not found';
        });
        return;
      }

      final currentDriverId = driver['id'].toString();

      final location = await _authService.getDriverLocationByDriverId(
        currentDriverId,
      );

      latController.text = location?['lat']?.toString() ?? '';
      lngController.text = location?['lng']?.toString() ?? '';

      setState(() {
        driverId = currentDriverId;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _saveLocation() async {
    if (driverId == null) return;

    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());

    try {
      setState(() {
        isSaving = true;
      });

      await _authService.upsertDriverLocation(
        driverId: driverId!,
        lat: lat,
        lng: lng,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    latController.dispose();
    lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Update Location'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 40),
                  const SizedBox(height: 10),
                  Text(errorText!),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadLocation,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Update Your Location',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.my_location),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _saveLocation,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(isSaving ? 'Saving...' : 'Save Location'),
                  ),
                ),
              ],
            ),
    );
  }
}
