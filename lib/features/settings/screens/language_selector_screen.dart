import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/services/translation/mymemory_languages.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Full-screen searchable picker for the lyrics-translation target language
/// (Settings > Lyrics > Translation). Pops with the picked language's code,
/// the empty string `''` for the explicit "None" choice, or `null` if the
/// user backed out without picking — `''` and `null` are deliberately
/// distinct so the caller can tell "turn translation off" apart from
/// "nothing changed" (both would otherwise just be `null`).
class LanguageSelectorScreen extends StatefulWidget {
  const LanguageSelectorScreen({super.key, required this.selectedCode});

  final String? selectedCode;

  @override
  State<LanguageSelectorScreen> createState() => _LanguageSelectorScreenState();
}

class _LanguageSelectorScreenState extends State<LanguageSelectorScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = filterTranslationLanguages(_query);

    return AppScaffold(
      appBar: AppBar(title: const Text('Translation language')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search languages…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('None'),
                    subtitle: const Text('Translation off'),
                    trailing: widget.selectedCode == null
                        ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
                      child: Text(
                        'No languages match "$_query".',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  for (final lang in results)
                    ListTile(
                      title: Text(lang.englishName),
                      subtitle: lang.nativeName == lang.englishName ? null : Text(lang.nativeName),
                      trailing: widget.selectedCode == lang.code
                          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(lang.code),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
