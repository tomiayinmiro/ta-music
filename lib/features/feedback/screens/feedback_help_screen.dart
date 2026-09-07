import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/faq_list.dart';
import '../widgets/feedback_form.dart';

/// "Feedback & Help" — reached from the nav drawer, right after Settings.
/// No Stitch design exists for this screen (see DESIGN_MAP.md); built from
/// sonic_sanctuary_2 tokens, reusing the same widget patterns as Settings
/// and the manual lyrics editor.
class FeedbackHelpScreen extends StatelessWidget {
  const FeedbackHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Feedback & Help'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Help'),
              Tab(text: 'Feedback'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FaqList(),
            FeedbackForm(),
          ],
        ),
      ),
    );
  }
}
