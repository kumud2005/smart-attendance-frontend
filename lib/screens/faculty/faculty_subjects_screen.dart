import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../services/faculty_service.dart';

class FacultySubjectsScreen extends StatefulWidget {
  const FacultySubjectsScreen({
    super.key,
  });

  @override
  State<FacultySubjectsScreen> createState() =>
      _FacultySubjectsScreenState();
}

class _FacultySubjectsScreenState
    extends State<FacultySubjectsScreen> {
  final FacultyService _service = FacultyService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dashboard =
          await _service.getDashboard();

      final rawSubjects =
          dashboard['subjects'];

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = rawSubjects is List
            ? rawSubjects
                .whereType<Map>()
                .map(
                  (item) =>
                      Map<String, dynamic>.from(item),
                )
                .toList()
            : [];

        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _cleanErrorMessage(error);
      });
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  Widget _buildErrorCard() {
    return Card(
      color: AppColors.error.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error ??
                    'Unable to load subjects.',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(
    Map<String, dynamic> item,
  ) {
    final code =
        item['subject_code']
                ?.toString()
                .trim() ??
            '';

    final name =
        item['subject_name']
                ?.toString()
                .trim() ??
            '';

    final credits =
        item['credits']?.toString() ?? '-';

    final title = code.isEmpty
        ? (name.isEmpty
            ? 'Subject'
            : name)
        : name.isEmpty
            ? code
            : '$code - $name';

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceSoft,
          foregroundColor: AppColors.primary,
          child: Icon(
            Icons.menu_book_rounded,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            'Credits: $credits',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 140),
      child: Center(
        child: Text(
          'No assigned subjects found.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Subjects'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    _buildErrorCard(),
                    const SizedBox(height: 12),
                  ],

                  if (_subjects.isEmpty &&
                      _error == null)
                    _buildEmptyState(),

                  if (_subjects.isNotEmpty)
                    ..._buildSubjectCards(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildSubjectCards() {
    return [
      for (int index = 0;
          index < _subjects.length;
          index++) ...[
        _buildSubjectCard(
          _subjects[index],
        ),
        if (index != _subjects.length - 1)
          const SizedBox(height: 12),
      ],
    ];
  }
}