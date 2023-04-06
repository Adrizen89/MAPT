import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config.dart';

final FirebaseFirestore firestore = FirebaseFirestore.instance;
final CollectionReference markersRef = firestore.collection('markers');

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
    apiKey: api_key,
    authDomain: authDomain,
    projectId: projectId,
    storageBucket: storageBucket,
    messagingSenderId: messagingSenderId,
    appId: appId,
  ));
  runApp(MaterialApp(
    home: MapSample(),
  ));
}

class MapSample extends StatefulWidget {
  const MapSample({Key? key}) : super(key: key);

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  late GoogleMapController mapController;
  Location location = Location();
  LocationData? currentLocation;
  final Set<Marker> _markers = {};
  bool _popupOpen = false;

  Future<void> _getLocation() async {
    try {
      currentLocation = await location.getLocation();
      setState(() {});
      print('Lat: ${currentLocation?.latitude}');
      print('lng: ${currentLocation?.longitude}');
      if (currentLocation != null) {
        setState(() {
          _markers.add(Marker(
            markerId: MarkerId("MyLocation"),
            position:
                LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Votre position',
              snippet:
                  'Lat: ${currentLocation!.latitude}, Lng: ${currentLocation!.longitude}',
            ),
          ));
        });
      }
    } catch (e) {
      print('Error: ${e.toString()}');
    }
  }

  StreamSubscription<QuerySnapshot>? markersStream;

  Future<void> loadMarkers() async {
    markersStream = markersRef.snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        for (final markerDoc in snapshot.docs) {
          final Map<String, dynamic> data =
              markerDoc.data() as Map<String, dynamic>;
          final double latitude = data['latitude'] as double;
          final double longitude = data['longitude'] as double;
          final String title = data['title'] as String;
          final String description = data['description'] as String;

          final Marker marker = Marker(
            markerId: MarkerId(markerDoc.id),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(title: title, snippet: description),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
          );

          setState(() {
            _markers.add(marker);
          });
        }
      } else {
        setState(() {
          _markers.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    markersStream?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
    loadMarkers();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onMapTap(LatLng location) {
    _onInfoWindowTap(location);
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId(location.toString()),
        position: location,
        infoWindow: InfoWindow(
          title: 'Nouveau marqueur',
          snippet: 'Cliquez pour ajouter une description',
          onTap: () {
            _onInfoWindowTap(location);
          },
        ),
      ));
    });
  }

  bool _markerAdded = false;

  void _onInfoWindowTap(LatLng location) async {
    TextEditingController titleController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    setState(() {
      _popupOpen = true;
    });
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter un marqueur'),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Annuler'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _markerAdded = false;
                _popupOpen = false;
              });
            },
          ),
          TextButton(
            child: Text('Ajouter'),
            onPressed: () async {
              String title = titleController.text;
              String description = descriptionController.text;
              if (title.isEmpty || description.isEmpty) {
                return;
              }
              await FirebaseFirestore.instance.collection('markers').add({
                'title': title,
                'description': description,
                'latitude': location.latitude,
                'longitude': location.longitude,
              });
              Navigator.of(context).pop();
              setState(() {
                _markerAdded = true;
                _popupOpen = false;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return currentLocation == null
        ? Center(
            child: CircularProgressIndicator(),
          )
        : GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(currentLocation!.latitude ?? 37.4219999,
                  currentLocation!.longitude ?? -122.0840575),
              zoom: 11.0,
            ),
            markers: _markers,
            onTap: _popupOpen == false ? _onMapTap : null,
          );
  }
}
