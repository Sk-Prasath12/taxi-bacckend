import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFDB813),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          FAQItem(
            question: 'How do I book a ride?',
            answer: 'To book a ride, open the app, enter your destination in the search bar, select your taxi type, and click "Book Now".',
          ),
          FAQItem(
            question: 'How can I change my payment method?',
            answer: 'Go to Payment Settings in your profile, where you can add, remove, or change your preferred payment method.',
          ),
          FAQItem(
            question: 'How do I cancel a ride?',
            answer: 'Find your ongoing ride in the "Live Order" section on the Home screen and click "Cancel Ride". Cancellation fees may apply depending on the timing.',
          ),
          FAQItem(
            question: 'Are there any cancellation fees?',
            answer: 'Cancellation fees are charged if you cancel a ride after the driver has reached the pickup location or has spent significant time traveling towards it.',
          ),
          FAQItem(
            question: 'How can I report a problem with a ride?',
            answer: 'Go to "Ride History", select the ride in question, and click "Report an Issue" or contact our live chat support.',
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const FAQItem({super.key, required this.question, required this.answer});

  @override
  State<FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onExpansionChanged: (isExpanded) {
          setState(() => _isExpanded = isExpanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text(
              widget.answer,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
