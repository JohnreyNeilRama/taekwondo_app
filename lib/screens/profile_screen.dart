import 'package:flutter/material.dart';

import '../widgets/brand_header.dart';
import '../widgets/empty_state_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Text(
                'Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              EmptyStateCard(
                icon: Icons.person_outline,
                title: 'Profile coming soon',
                message: 'Account details and settings will appear here.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
