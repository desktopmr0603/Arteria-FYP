import 'package:flutter/material.dart';
import 'package:arteria/l10n/app_localizations.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final List<Map<String, String>> faqItems = [
      {'question': l10n.faqAlertsQuestion, 'answer': l10n.faqAlertsAnswer},
      {
        'question': l10n.faqDoctorReplacementQuestion,
        'answer': l10n.faqDoctorReplacementAnswer,
      },
      {
        'question': l10n.faqShareDataQuestion,
        'answer': l10n.faqShareDataAnswer,
      },
      {'question': l10n.faqSecurityQuestion, 'answer': l10n.faqSecurityAnswer},
      {
        'question': l10n.faqDataTrainingQuestion,
        'answer': l10n.faqDataTrainingAnswer,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.faqTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        itemCount: faqItems.length,
        itemBuilder: (context, index) {
          final item = faqItems[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  item['question']!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                iconColor: theme.primaryColor,
                collapsedIconColor: theme.iconTheme.color?.withOpacity(0.7),
                children: [
                  Text(
                    item['answer']!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
