import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
      home: const MapScreen(),
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
  bool isLoading = false;
  String statusMessage = 'Press the button to find your location';

  Future<void> getLocation() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Checking location permissions...';
    });

    try {
      // Check whether GPS is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        // Ask Android to open location settings
        await Geolocator.openLocationSettings();

        setState(() {
          statusMessage = 'Please enable location services and try again.';
        });

        return;
      }

      // Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      // Request permission if not already granted
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          statusMessage = 'Location permission is required to use the map.';
        });

        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }

        return;
      }

      // Retrieve current GPS coordinates
      Position position = await Geolocator.getCurrentPosition();

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        currentLocation = newLocation;
        statusMessage = 'Location found successfully!';
      });

      // Center map on user's location
      _mapController.move(newLocation, 16);
    } catch (e) {
      setState(() {
        statusMessage = 'Unable to retrieve location: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Downtown Explorer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Explore Downtown Russellville',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Find your location and start exploring!'),
              ],
            ),
          ),

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

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(statusMessage, textAlign: TextAlign.center),
                const SizedBox(height: 12),

                if (currentLocation != null) ...[
                  Text('Latitude: ${currentLocation!.latitude}'),
                  Text('Longitude: ${currentLocation!.longitude}'),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : getLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      isLoading ? 'Finding Location...' : 'Find My Location',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
