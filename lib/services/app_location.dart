import 'dart:async';
import 'package:location/location.dart' as loc;

/// Singleton that holds the device's live GPS coordinates.
/// Call [init] once (e.g. on homepage load) and the stream keeps
/// lat/lon up-to-date automatically while the app is open.
class AppLocation {
  static final AppLocation _i = AppLocation._();
  factory AppLocation() => _i;
  AppLocation._();

  double? lat;
  double? lon;

  final _location = loc.Location();
  StreamSubscription<loc.LocationData>? _sub;
  bool _streaming = false;

  // How many screens currently need the live stream (Service_favorite_screen,
  // shops_favorite_screen, ...). Since those live in separate bottom-nav tabs
  // that stay mounted in the background, a naive "stop on my dispose" would
  // kill the stream out from under a sibling tab still using it — so we only
  // actually stop once the last consumer has released it.
  int _consumers = 0;

  /// Call from a consuming screen's initState (paired with [removeConsumer]
  /// in its dispose) to keep the stream alive for exactly as long as at
  /// least one such screen is mounted.
  void addConsumer() => _consumers++;

  void removeConsumer() {
    if (_consumers > 0) _consumers--;
    if (_consumers == 0) stop();
  }

  /// Returns true if we have a valid lat/lon after this call.
  Future<bool> init() async {
    // Already have a fix — just ensure stream is running
    if (lat != null && lon != null) {
      _ensureStream();
      return true;
    }
    try {
      // 1. Service enabled?
      bool svcEnabled = await _location.serviceEnabled();
      if (!svcEnabled) {
        svcEnabled = await _location.requestService();
        if (!svcEnabled) return false;
      }

      // 2. Permission?
      var perm = await _location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await _location.requestPermission();
        if (perm != loc.PermissionStatus.granted) return false;
      }

      // 3. Initial fix — getLocation() (a one-shot request) is known to hang
      // indefinitely on iOS in some environments, even with permission
      // granted and location services enabled. Start the live stream first
      // (a separate native code path) so we have a fallback source, then
      // try the one-shot call with a timeout; if it doesn't return in time,
      // fall back to the stream's first event instead of hanging forever.
      _ensureStream();
      try {
        final data =
            await _location.getLocation().timeout(const Duration(seconds: 6));
        lat = data.latitude;
        lon = data.longitude;
      } catch (_) {
        if (lat == null || lon == null) {
          final data = await _location.onLocationChanged.first
              .timeout(const Duration(seconds: 6));
          lat = data.latitude;
          lon = data.longitude;
        }
      }

      return lat != null && lon != null;
    } catch (_) {
      return false;
    }
  }

  void _ensureStream() {
    if (_streaming) return;
    _streaming = true;
    _sub = _location.onLocationChanged.listen((data) {
      lat = data.latitude;
      lon = data.longitude;
    });
  }

  String? get locationString =>
      lat != null && lon != null ? '$lat,$lon' : null;

  void stop() {
    _sub?.cancel();
    _sub = null;
    _streaming = false;
  }
}
