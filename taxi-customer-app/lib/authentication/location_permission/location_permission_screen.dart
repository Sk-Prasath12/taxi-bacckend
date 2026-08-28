import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 120, color: Color(0xFFFDB813)),
            const SizedBox(height: 40),
            const Text(
              'Enable Location',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Please enable location permission to find rides near you and provide accurate pickup/drop-off.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 60),
            TaxiButton(
              text: 'ALLOW LOCATION',
              color: const Color(0xFFFDB813),
              textColor: Colors.black,
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enable location to proceed'),
                  ),
                );
              },
              child: const Text(
                'NOT NOW',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
