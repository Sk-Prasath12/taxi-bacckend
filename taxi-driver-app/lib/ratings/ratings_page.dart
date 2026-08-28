import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  final double _overallRating = 4.87;
  final int _totalRides = 1234;
  final int _totalReviews = 856;
  
  final Map<int, int> _ratingDistribution = {
    5: 650,
    4: 150,
    3: 40,
    2: 10,
    1: 6,
  };

  final List<Map<String, dynamic>> _recentReviews = [
    {
      'id': 1,
      'passengerName': 'John D.',
      'rating': 5,
      'comment': 'Excellent driver! Very professional and courteous. The car was clean and comfortable.',
      'date': 'Today, 2:30 PM',
      'rideId': '#TRX-12345',
      'avatar': 'JD',
    },
    {
      'id': 2,
      'passengerName': 'Sarah M.',
      'rating': 5,
      'comment': 'Great experience! Smooth ride and safe driving. Highly recommended!',
      'date': 'Yesterday, 8:45 PM',
      'rideId': '#TRX-12344',
      'avatar': 'SM',
    },
    {
      'id': 3,
      'passengerName': 'Michael R.',
      'rating': 4,
      'comment': 'Good service. Driver was on time. Only minor issue was traffic.',
      'date': 'Mar 9, 2026',
      'rideId': '#TRX-12343',
      'avatar': 'MR',
    },
    {
      'id': 4,
      'passengerName': 'Emily W.',
      'rating': 5,
      'comment': 'Perfect! Best taxi service I\'ve experienced. Will definitely book again.',
      'date': 'Mar 8, 2026',
      'rideId': '#TRX-12342',
      'avatar': 'EW',
    },
    {
      'id': 5,
      'passengerName': 'David L.',
      'rating': 5,
      'comment': 'Very friendly driver and clean vehicle. Excellent navigation skills.',
      'date': 'Mar 7, 2026',
      'rideId': '#TRX-12341',
      'avatar': 'DL',
    },
  ];

  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratings & Reviews'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Reviews')),
              const PopupMenuItem(value: '5', child: Row(children: [Icon(Icons.star, size: 18), SizedBox(width: 8), Text('5 Stars')])),
              const PopupMenuItem(value: '4', child: Row(children: [Icon(Icons.star, size: 18), SizedBox(width: 8), Text('4 Stars')])),
              const PopupMenuItem(value: '3', child: Row(children: [Icon(Icons.star, size: 18), SizedBox(width: 8), Text('3 Stars')])),
              const PopupMenuItem(value: 'low', child: Text('Low Ratings')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Rating Card
              _buildOverallRatingCard(),
              const SizedBox(height: 24),

              // Rating Distribution
              _buildRatingDistribution(),
              const SizedBox(height: 24),

              // Achievements Badge
              _buildAchievementsBadge(),
              const SizedBox(height: 24),

              // Reviews Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$_totalReviews reviews',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reviews List
              ..._recentReviews.map((review) => _buildReviewCard(review)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallRatingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    'Your Rating',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _overallRating.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardDark,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < _overallRating.floor() ? Icons.star : Icons.star_border,
                        color: AppColors.cardDark,
                        size: 28,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalRides total rides',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rating Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ..._ratingDistribution.entries.map((entry) {
            final percentage = (entry.value / _totalReviews) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${entry.key}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.star,
                    size: 18,
                    color: entry.key >= 4 ? AppColors.green : AppColors.textMuted,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          entry.key >= 4 ? AppColors.green : Colors.grey,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 50,
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAchievementsBadge() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: AppColors.cardDark,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Rated Driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You\'re in the top 5% of drivers in your area!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🏆 Platinum Driver',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardDark,
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

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                radius: 24,
                child: Text(
                  review['avatar'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['passengerName'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review['date'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 20,
                    color: index < (review['rating'] as int)
                        ? AppColors.green
                        : Colors.grey[300],
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            review['comment'] as String,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 14, color: AppColors.green),
                    const SizedBox(width: 6),
                    Text(
                      review['rideId'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thanking passenger...')),
                  );
                },
                icon: const Icon(Icons.favorite_border, size: 18),
                label: const Text('Thank'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
