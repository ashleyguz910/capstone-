import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'login_screen.dart';

void main() {
  runApp(const DowntownExplorer());
}

class DowntownExplorer extends StatelessWidget {
  const DowntownExplorer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Downtown Explorer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  LatLng? currentLocation;
  String statusMessage = 'Finding location...';

  // Get live location
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startTracking());
  }

  @override
  void dispose() {
    // Stop tracking when leaving screen
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> startTracking() async {
    try {
      // Check if GPS is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();

        setState(() {
          statusMessage = 'Please enable location services.';
        });

        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();

      // Request permission if needed
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          statusMessage = 'Location permission required.';
        });

        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }

        return;
      }

      // Check for location changes
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        final newLocation = LatLng(position.latitude, position.longitude);
        final bool isFirstUpdate = currentLocation == null;

        setState(() {
          currentLocation = newLocation;
          statusMessage = 'Tracking your location';
        });

          // Center the map the first time getting location
          if (isFirstUpdate) {
            _mapController.move(newLocation, 16);
          }
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Unable to retrieve location: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Compass
        title: const Icon(Icons.explore, size: 60),
        centerTitle: true,

        // Settings
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Implement Later
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(35.2784, -93.1338),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.downtown_explorer',
                ),
                if (currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                Expanded(
                  child: _navButton(Icons.leaderboard, 'Leaderboard', () {}),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Image.asset(
                    'assets/images/MainstreetLogo.png',
                    height: 50,
                  ),
                ),

                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _navButton(Icons.checklist, 'Checklist', () {}),
                      ),
                      Expanded (
                        child: _navButton(Icons.help, 'Hint', () {}),
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

  // Build button for the bottom navigation bar
  Widget _navButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
