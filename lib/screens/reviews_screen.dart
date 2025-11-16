// lib/screens/reviews_screen.dart

import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReviewsScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ReviewsScreen({super.key, required this.userId, required this.userName});

  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final response = await supabase
        .from('reviews')
        .select('*, reviewer:profiles!reviews_reviewer_id_fkey(username, full_name)')
        .eq('reviewee_id', userId)
        .order('created_at', ascending: false);
    return response as List<Map<String, dynamic>>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Отзывы о $userName'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final reviews = snapshot.data!;
          if (reviews.isEmpty) {
            return const Center(child: Text('Отзывов пока нет'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return ReviewCard(reviewData: review);
            },
          );
        },
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> reviewData;

  const ReviewCard({super.key, required this.reviewData});

  @override
  Widget build(BuildContext context) {
    final reviewerName = reviewData['reviewer']?['full_name'] ?? 'Аноним';
    final rating = reviewData['rating'] as int;
    final comment = reviewData['comment'] as String?;
    final createdAt = DateTime.parse(reviewData['created_at']);

    return Card(
      color: Colors.grey.shade800.withOpacity(0.8),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kPrimaryPink,
                  child: Text(reviewerName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(timeago.format(createdAt, locale: 'ru'), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(comment, style: TextStyle(color: Colors.grey[300], height: 1.4)),
            ]
          ],
        ),
      ),
    );
  }
}