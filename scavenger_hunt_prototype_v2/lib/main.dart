import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'firebase_options.dart';
import 'clue_screen.dart';
import 'clue_data.dart';
import 'database_service.dart';
import 'leaderboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  // Get live location.
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startTracking());
  }

  @override
  void dispose() {
    // Stop tracking when leaving screen.
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> startTracking() async {
    try {
      // Check if GPS is enabled.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();

        setState(() {
          statusMessage = 'Please enable location services.';
        });

        return;
      }

      // Check permissions.
      LocationPermission permission = await Geolocator.checkPermission();

      // Request permission if needed.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          statusMessage = 'Location permission required.';
        });

        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }

        return;
      }

      // Check for location changes.
      _positionStream =
          Geolocator.getPositionStream(
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

            // Center the map the first time getting location.
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

  // Display the hint for the player's current clue.
  Future<void> _showCurrentHint() async {
    try {
      // Retrieve the player's saved progress.
      final progress = await DatabaseService().getUserProgress();

      if (!mounted) return;

      if (progress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load your progress.')),
        );
        return;
      }

      // Convert completed clue IDs into integers.
      final rawCompletedClues = progress['completedClueIds'];

      final completedClues = rawCompletedClues is List
          ? rawCompletedClues
                .map((id) => int.tryParse(id.toString()))
                .whereType<int>()
                .where((id) => id >= 1 && id <= ClueData.clues.length)
                .toSet()
          : <int>{};

      // Find the next clue that has not been completed.
      final nextClueId = completedClues.length + 1;

      // Check whether all clues are completed.
      if (nextClueId > ClueData.clues.length) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hunt Completed!'),
            content: const Text(
              'You have completed all the clues. '
              'There are no more hints available!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      final currentClue = ClueData.clues[nextClueId - 1];

      // Display the current clue's hint.
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text('${currentClue.title} Hint')),
            ],
          ),
          content: Text(currentClue.hint, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to retrieve hint. Please try again.'),
        ),
      );
    }
  }

  // Display the settings menu.
  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset Progress'),
              onTap: () {
                Navigator.pop(dialogContext);
                _confirmResetProgress();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log Out'),
              onTap: () {
                Navigator.pop(dialogContext);
                _logOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Ask the player to confirm before resetting progress.
  Future<void> _confirmResetProgress() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
          'Are you sure you want to reset your progress? '
          'All completed clues and points will be lost. '
          'Your account and username will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    try {
      await DatabaseService().resetProgress();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your scavenger hunt progress has been reset.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reset progress. Please try again.'),
        ),
      );
    }
  }

  // Sign out and return to the login screen.
  Future<void> _logOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Compass.
        title: const Icon(Icons.explore, size: 60),
        centerTitle: true,

        // Settings.
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
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

      // Bottom Navigation Bar.
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
                  child: _navButton(Icons.leaderboard, 'Leaderboard', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LeaderboardScreen(),
                      ),
                    );
                  }),
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
                        child: _navButton(Icons.checklist, 'Checklist', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ClueScreen(),
                            ),
                          );
                        }),
                      ),

                      Expanded(
                        child: _navButton(Icons.help, 'Hint', () {
                          _showCurrentHint();
                        }),
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

  // Build button for the bottom navigation bar.
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
