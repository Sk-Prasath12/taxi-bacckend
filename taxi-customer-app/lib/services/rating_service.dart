import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class RatingService {
  static Future<void> submitRating({
    required String token,
    required String rideId,
    required int rating,
    required String review,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/ratings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ride_id': rideId,
        'rating': rating,
        'review': review,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit rating');
    }
  }
}
