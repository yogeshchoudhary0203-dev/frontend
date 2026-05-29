import 'package:flutter/material.dart';

/// Global route observer — subscribe to detect when a screen is covered
/// by a pushed route (e.g. to pause video players).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
