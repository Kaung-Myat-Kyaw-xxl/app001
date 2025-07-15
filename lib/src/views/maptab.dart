import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app001/src/providers/geodata.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../helpers/helpers.dart';
import '../maps/mapview001.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  MapTabState createState() => MapTabState();
}

class MapTabState extends State<MapTab> with WidgetsBindingObserver {
  // GPS Declare >>>>
  late LocationNotifier
      locationNotifierProvider; // Provider Declaration and init
  final Location location = Location();
  late StreamSubscription<LocationData> locationSubscription;
  // GPS Declare -------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // lifecycle observer
    initGeoData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // lifecycle observer
    locationSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lifecycle
    super.didChangeAppLifecycleState(state);
    logger.e("LifeCycle State: $state");
    if (state == AppLifecycleState.paused) {
      bg();
    } else if (state == AppLifecycleState.resumed) {
    } else if (state == AppLifecycleState.inactive) {
      bg();
    }
  }

  Future<void> bg() async {
    if (GeoData.tripStarted) {
      await location.enableBackgroundMode(enable: true);
    } else {
      await location.enableBackgroundMode(enable: false);
    }
  }

  Future<void> initGeoData() async {
    GeoData.currentLat = GeoData.defaultLat;
    GeoData.currentLng = GeoData.defaultLng;
    try {
      locationNotifierProvider =
          Provider.of<LocationNotifier>(context, listen: false);
      if (await GeoData.chkPermissions(location)) {
        await location.changeSettings(
            accuracy: LocationAccuracy.high,
            interval: GeoData.interval,
            distanceFilter: GeoData.distance);
        locationSubscription =
            location.onLocationChanged.listen((LocationData currentLocation) {
          changeLocations(currentLocation);
        });
        if (GeoData.listenChanges == false) locationSubscription.pause();
      } else {
        logger.i("Permission Denied");
      }
    } catch (e) {
      logger.i("Exception (initGeoData): $e");
    }
  }

  void changeLocations(LocationData currentLocation) {
    //listen to location changes
    try {
      DateTime dt = DateTime.now();
      GeoData.updateLocation(
          currentLocation.latitude!, currentLocation.longitude!, dt);
      setState(() {
        locationNotifierProvider.updateLoc1(
            currentLocation.latitude!, currentLocation.longitude!, dt);
      });
      if (GeoData.centerMap) {
        locationNotifierProvider.mapController.move(
            LatLng(locationNotifierProvider.loc01.lat,
                locationNotifierProvider.loc01.lng),
            GeoData.zoom);
      }
      if (GeoData.showLatLng) {
        logger.i(
            "(${GeoData.counter}) ${currentLocation.latitude} x ${currentLocation.longitude}");
      }
    } catch (e) {
      logger.i("Exception (changeLocations): $e");
    }
  }

  void moveHere() async {
    // butten event
    try {
      var locationData = await GeoData.getCurrentLocation(location);
      if (locationData != null) {
        locationNotifierProvider.updateLoc1(
            GeoData.currentLat, GeoData.currentLng, GeoData.currentDtime);
        locationNotifierProvider.mapController.move(
            LatLng(locationNotifierProvider.loc01.lat,
                locationNotifierProvider.loc01.lng),
            GeoData.zoom);
        MyHelpers.showIt(
          "\n${locationNotifierProvider.loc01.lat}\n${locationNotifierProvider.loc01.lng}",
          label: "You are here",
        );
      } else {
        logger.i("Invalid Location!");
      }
    } catch (e) {
      logger.i("Exception (moveHere): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MapView001();
  }
}
