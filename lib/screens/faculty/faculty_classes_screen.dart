import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../services/faculty_service.dart';

class FacultyClassesScreen extends StatefulWidget {
  const FacultyClassesScreen({
    super.key,
  });

  @override
  State<FacultyClassesScreen> createState() =>
      _FacultyClassesScreenState();
}

class _FacultyClassesScreenState
    extends State<FacultyClassesScreen> {
  final FacultyService _service = FacultyService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sections = [];

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
      final dashboard = await _service.getDashboard();
      final rawSections = dashboard['sections'];

      if (!mounted) {
        return;
      }

      setState(() {
        _sections = rawSections is List
            ? rawSections
                .whereType<Map>()
                .map(
                  (item) => Map<String, dynamic>.from(item),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Classes'),
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
                  if (_error != null)
                    _buildErrorCard(),

                  if (_error != null)
                    const SizedBox(height: 12),

                  if (_sections.isEmpty &&
                      _error == null)
                    _buildEmptyState()
                  else if (_sections.isNotEmpty)
                    ..._buildSectionCards(),
                ],
              ),
            ),
    );
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
                _error ?? 'Unable to load classes.',
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

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 140),
      child: Center(
        child: Text(
          'No assigned classes found.',
        ),
      ),
    );
  }

  List<Widget> _buildSectionCards() {
    return [
      for (int index = 0;
          index < _sections.length;
          index++) ...[
        _buildClassCard(_sections[index]),
        if (index != _sections.length - 1)
          const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildClassCard(
    Map<String, dynamic> item,
  ) {
    final sectionName =
        item['section_name']?.toString().trim() ?? '';

    final studentCount =
        item['student_count']?.toString() ?? '0';

    final sectionId =
        item['section_id']?.toString() ?? '-';

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
            Icons.groups_rounded,
          ),
        ),
        title: Text(
          sectionName.isEmpty
              ? 'Section $sectionId'
              : 'Section $sectionName',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            '$studentCount students',
          ),
        ),
        trailing: Text(
          'ID: $sectionId',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
