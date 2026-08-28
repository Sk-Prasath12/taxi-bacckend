import 'package:flutter/material.dart';

class RatingBottomSheet extends StatefulWidget {
  final Future<void> Function(int rating, String review) onSubmit;

  const RatingBottomSheet({super.key, required this.onSubmit});

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  int selectedRating = 0;
  final TextEditingController reviewController = TextEditingController();
  bool _submitting = false;

  Widget buildStar(int index) {
    return GestureDetector(
      onTap: _submitting
          ? null
          : () {
              setState(() {
                selectedRating = index;
              });
            },
      child: Icon(
        index <= selectedRating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 32,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting || selectedRating == 0) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(selectedRating, reviewController.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rate your ride',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => buildStar(index + 1)),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: reviewController,
                  enabled: !_submitting,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a review (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: selectedRating == 0 || _submitting ? null : _submit,
                    child: Text(_submitting ? 'Submitting...' : 'Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
