import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/widgets/background_glow.dart';

class CreateReviewScreen extends StatefulWidget {
  final String orderId;
  final String revieweeId;

  const CreateReviewScreen({
    super.key,
    required this.orderId,
    required this.revieweeId,
  });

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _rating = 5.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final reviewerId = supabase.auth.currentUser!.id;

      await supabase.from('reviews').insert({
        'order_id': widget.orderId,
        'reviewer_id': reviewerId,
        'reviewee_id': widget.revieweeId,
        'rating': _rating.toInt(),
        'comment': _commentController.text.trim(),
      });

      await supabase.rpc('update_engineer_rating', params: {
        'engineer_id': widget.revieweeId
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Спасибо за ваш отзыв!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оставить отзыв')),
      body: Stack(
        children: [
          const BackgroundGlow(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ваша оценка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                   Center(
                    child: Text('${_rating.toInt()} / 5', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryPink)),
                  ),
                  Slider(
                    value: _rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: kPrimaryPink,
                    label: _rating.round().toString(),
                    onChanged: (newRating) {
                      setState(() => _rating = newRating);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Комментарий (необязательно)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _commentController,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Расскажите о вашем опыте работы с инженером...',
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitReview,
                            child: const Text('Отправить отзыв'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}