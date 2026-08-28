import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}
