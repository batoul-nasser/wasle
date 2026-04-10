import 'package:flutter/material.dart';

class PickupPointPage extends StatelessWidget {
  const PickupPointPage({super.key});

  @override
  Widget build(BuildContext context) {
    const pickupPointName = 'Wasle Pickup Point - Beirut';
    const pickupPointPhone = '+961 70 123 456';
    const pickupPointAddress = 'Hamra Main Street, Beirut';

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Point'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pickup Point Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text('Name: $pickupPointName', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text('Phone: $pickupPointPhone', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text(
                'Address: $pickupPointAddress',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
