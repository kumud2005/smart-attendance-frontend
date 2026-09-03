import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_theme.dart';
import '../../services/admin_service.dart';

class AdminClassroomsScreen extends StatefulWidget {
  const AdminClassroomsScreen({
    super.key,
  });

  @override
  State<AdminClassroomsScreen> createState() =>
      _AdminClassroomsScreenState();
}

class _AdminClassroomsScreenState
    extends State<AdminClassroomsScreen> {
  final AdminService _adminService = AdminService();

  List<Map<String, dynamic>> _classrooms = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _statusFilter = 'ALL';

  int? _busyClassroomId;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  Future<void> _loadClassrooms() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final classrooms =
          await _adminService.getClassrooms();

      if (!mounted) {
        return;
      }

      setState(() {
        _classrooms = classrooms;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredClassrooms {
    final query = _searchQuery.trim().toLowerCase();

    return _classrooms.where((classroom) {
      final isActive = classroom['is_active'] == true;

      if (_statusFilter == 'ACTIVE' && !isActive) {
        return false;
      }

      if (_statusFilter == 'INACTIVE' && isActive) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        classroom['classroom_id'],
        classroom['building_name'],
        classroom['room_number'],
        classroom['latitude'],
        classroom['longitude'],
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  Future<void> _openClassroomForm({
    Map<String, dynamic>? classroom,
  }) async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClassroomFormDialog(
        adminService: _adminService,
        classroom: classroom,
      ),
    );

    if (!mounted || message == null) {
      return;
    }

    _showMessage(message);
    await _loadClassrooms();
  }

  Future<void> _changeActiveStatus(
    Map<String, dynamic> classroom,
  ) async {
    final classroomId =
        _asInt(classroom['classroom_id']);

    if (classroomId <= 0) {
      _showMessage(
        'Invalid classroom ID.',
        error: true,
      );
      return;
    }

    final isActive =
        classroom['is_active'] == true;

    if (isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Deactivate Classroom',
            ),
            content: Text(
              'Deactivate ${_classroomTitle(classroom)}?\n\n'
              'It will no longer appear when Faculty starts a new '
              'attendance session. Existing attendance history is preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                child: const Text(
                  'Deactivate',
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _busyClassroomId = classroomId;
    });

    try {
      final response = isActive
          ? await _adminService.deactivateClassroom(
              classroomId,
            )
          : await _adminService.activateClassroom(
              classroomId,
            );

      if (!mounted) {
        return;
      }

      _showMessage(
        response['message']?.toString() ??
            (isActive
                ? 'Classroom deactivated successfully.'
                : 'Classroom activated successfully.'),
      );

      await _loadClassrooms();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyClassroomId = null;
        });
      }
    }
  }

  Future<void> _deleteClassroom(
    Map<String, dynamic> classroom,
  ) async {
    final classroomId =
        _asInt(classroom['classroom_id']);

    if (classroomId <= 0) {
      _showMessage(
        'Invalid classroom ID.',
        error: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Permanently Delete Classroom',
          ),
          content: Text(
            'Delete ${_classroomTitle(classroom)} permanently?\n\n'
            'This is allowed only when the classroom has never been '
            'used by an attendance session. If attendance history exists, '
            'the server will block deletion and you should deactivate '
            'the classroom instead.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(
                Icons.delete_forever_rounded,
              ),
              label: const Text(
                'Delete Permanently',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busyClassroomId = classroomId;
    });

    try {
      final response =
          await _adminService.deleteClassroom(
        classroomId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        response['message']?.toString() ??
            'Classroom deleted successfully.',
      );

      await _loadClassrooms();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyClassroomId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Classroom Management',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh classrooms',
            onPressed:
                _isLoading ? null : _loadClassrooms,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 720;

            return RefreshIndicator(
              onRefresh: _loadClassrooms,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                  compact ? 14 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1250,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          compact: compact,
                        ),
                        const SizedBox(height: 18),
                        _buildFilters(
                          compact: compact,
                        ),
                        const SizedBox(height: 18),
                        if (_isLoading)
                          const _LoadingCard()
                        else if (_errorMessage !=
                            null)
                          _buildErrorCard()
                        else
                          _buildClassroomContent(
                            compact: compact,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool compact,
  }) {
    final activeCount = _classrooms
        .where(
          (item) =>
              item['is_active'] == true,
        )
        .length;

    final info = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Manage Classrooms',
          style: TextStyle(
            fontSize: compact ? 22 : 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add classroom locations and geofence settings used '
          'for attendance verification.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (!_isLoading &&
            _errorMessage == null) ...[
          const SizedBox(height: 8),
          Text(
            '${_classrooms.length} total • $activeCount active',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final addButton = FilledButton.icon(
      onPressed: () {
        _openClassroomForm();
      },
      icon: const Icon(
        Icons.add_location_alt_rounded,
      ),
      label: const Text(
        'Add Classroom',
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          info,
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: addButton,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(child: info),
        const SizedBox(width: 20),
        addButton,
      ],
    );
  }

  Widget _buildFilters({
    required bool compact,
  }) {
    final search = TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: const InputDecoration(
        labelText: 'Search classrooms',
        hintText:
            'Building, room or classroom ID',
        prefixIcon: Icon(
          Icons.search_rounded,
        ),
        border: OutlineInputBorder(),
      ),
    );

    final status = DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'ALL',
          child: Text('All'),
        ),
        DropdownMenuItem(
          value: 'ACTIVE',
          child: Text('Active'),
        ),
        DropdownMenuItem(
          value: 'INACTIVE',
          child: Text('Inactive'),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _statusFilter = value;
        });
      },
    );

    if (compact) {
      return Column(
        children: [
          search,
          const SizedBox(height: 12),
          status,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: search,
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 1,
          child: status,
        ),
      ],
    );
  }

  Widget _buildClassroomContent({
    required bool compact,
  }) {
    final classrooms =
        _filteredClassrooms;

    if (classrooms.isEmpty) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 52,
                  color:
                      AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No classrooms found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _classrooms.isEmpty
                      ? 'Add your first classroom to get started.'
                      : 'No classrooms match the current search or filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (compact) {
      return Column(
        children: [
          for (int index = 0;
              index < classrooms.length;
              index++) ...[
            _buildClassroomCard(
              classrooms[index],
            ),
            if (index !=
                classrooms.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      );
    }

    return _buildDesktopTable(
      classrooms,
    );
  }

  Widget _buildClassroomCard(
    Map<String, dynamic> classroom,
  ) {
    final classroomId =
        _asInt(classroom['classroom_id']);
    final isActive =
        classroom['is_active'] == true;
    final busy =
        _busyClassroomId == classroomId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        _classroomTitle(
                          classroom,
                        ),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Classroom ID $classroomId',
                        style: TextStyle(
                          color: AppColors
                              .textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(
                  isActive,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              title: 'Location',
              value:
                  '${_coordinate(classroom['latitude'])}, '
                  '${_coordinate(classroom['longitude'])}',
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.radar_rounded,
              title: 'Geofence radius',
              value:
                  '${_number(classroom['geofence_radius_meters'])} m',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            _openClassroomForm(
                              classroom:
                                  classroom,
                            );
                          },
                    icon: const Icon(
                      Icons.edit_rounded,
                    ),
                    label:
                        const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy
                        ? null
                        : () {
                            _changeActiveStatus(
                              classroom,
                            );
                          },
                    icon: busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            isActive
                                ? Icons
                                    .pause_circle_outline_rounded
                                : Icons
                                    .check_circle_outline_rounded,
                          ),
                    label: Text(
                      isActive
                          ? 'Deactivate'
                          : 'Activate',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        _deleteClassroom(
                          classroom,
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      AppColors.error,
                  side: BorderSide(
                    color: AppColors.error,
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                ),
                label: const Text(
                  'Delete Classroom',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 112,
          child: Text(
            title,
            style: TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(
    List<Map<String, dynamic>> classrooms,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Building')),
            DataColumn(label: Text('Room')),
            DataColumn(label: Text('Latitude')),
            DataColumn(label: Text('Longitude')),
            DataColumn(label: Text('Radius')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final classroom
                in classrooms)
              _buildDataRow(classroom),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(
    Map<String, dynamic> classroom,
  ) {
    final classroomId =
        _asInt(classroom['classroom_id']);
    final isActive =
        classroom['is_active'] == true;
    final busy =
        _busyClassroomId == classroomId;

    return DataRow(
      cells: [
        DataCell(
          Text(classroomId.toString()),
        ),
        DataCell(
          Text(
            classroom['building_name']
                    ?.toString() ??
                '-',
          ),
        ),
        DataCell(
          Text(
            classroom['room_number']
                    ?.toString() ??
                '-',
          ),
        ),
        DataCell(
          Text(
            _coordinate(
              classroom['latitude'],
            ),
          ),
        ),
        DataCell(
          Text(
            _coordinate(
              classroom['longitude'],
            ),
          ),
        ),
        DataCell(
          Text(
            '${_number(classroom['geofence_radius_meters'])} m',
          ),
        ),
        DataCell(
          _buildStatusChip(isActive),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit classroom',
                onPressed: busy
                    ? null
                    : () {
                        _openClassroomForm(
                          classroom:
                              classroom,
                        );
                      },
                icon: const Icon(
                  Icons.edit_rounded,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        _changeActiveStatus(
                          classroom,
                        );
                      },
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        isActive
                            ? Icons
                                .pause_circle_outline_rounded
                            : Icons
                                .check_circle_outline_rounded,
                      ),
                label: Text(
                  isActive
                      ? 'Deactivate'
                      : 'Activate',
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip:
                    'Delete classroom permanently',
                onPressed: busy
                    ? null
                    : () {
                        _deleteClassroom(
                          classroom,
                        );
                      },
                color: AppColors.error,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(
                alpha: 0.10,
              )
            : Colors.grey.withValues(
                alpha: 0.15,
              ),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: isActive
              ? Colors.green.shade700
              : Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 50,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load classrooms',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    'Unknown error.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadClassrooms,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _classroomTitle(
    Map<String, dynamic> classroom,
  ) {
    final building =
        classroom['building_name']
                ?.toString()
                .trim() ??
            '';
    final room =
        classroom['room_number']
                ?.toString()
                .trim() ??
            '';

    if (building.isEmpty) {
      return room.isEmpty
          ? 'Classroom'
          : 'Room $room';
    }

    if (room.isEmpty) {
      return building;
    }

    return '$building - Room $room';
  }

  String _coordinate(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(
            value?.toString() ?? '',
          );

    if (parsed == null) {
      return '-';
    }

    return parsed.toStringAsFixed(8);
  }

  String _number(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(
            value?.toString() ?? '',
          );

    if (parsed == null) {
      return '-';
    }

    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }

    return parsed.toStringAsFixed(2);
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error ? AppColors.error : null,
        ),
      );
  }
}

class _ClassroomFormDialog
    extends StatefulWidget {
  const _ClassroomFormDialog({
    required this.adminService,
    this.classroom,
  });

  final AdminService adminService;
  final Map<String, dynamic>? classroom;

  @override
  State<_ClassroomFormDialog>
      createState() =>
          _ClassroomFormDialogState();
}

class _ClassroomFormDialogState
    extends State<_ClassroomFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController
      _buildingController;
  late final TextEditingController
      _roomController;
  late final TextEditingController
      _latitudeController;
  late final TextEditingController
      _longitudeController;
  late final TextEditingController
      _radiusController;

  bool _saving = false;
  bool _gettingLocation = false;
  String? _locationMessage;

  bool get _isEditing =>
      widget.classroom != null;

  @override
  void initState() {
    super.initState();

    final classroom = widget.classroom;

    _buildingController =
        TextEditingController(
      text: classroom?['building_name']
              ?.toString() ??
          '',
    );

    _roomController =
        TextEditingController(
      text: classroom?['room_number']
              ?.toString() ??
          '',
    );

    _latitudeController =
        TextEditingController(
      text: _initialNumber(
        classroom?['latitude'],
      ),
    );

    _longitudeController =
        TextEditingController(
      text: _initialNumber(
        classroom?['longitude'],
      ),
    );

    _radiusController =
        TextEditingController(
      text: classroom == null
          ? '50'
          : _initialNumber(
              classroom[
                  'geofence_radius_meters'],
            ),
    );
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _roomController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation || _saving) {
      return;
    }

    setState(() {
      _gettingLocation = true;
      _locationMessage = null;
    });

    try {
      final position =
          await _getCurrentPosition();

      if (!mounted) {
        return;
      }

      _latitudeController.text =
          position.latitude
              .toStringAsFixed(8);

      _longitudeController.text =
          position.longitude
              .toStringAsFixed(8);

      setState(() {
        _locationMessage =
            'Current location captured '
            '(accuracy ±${position.accuracy.toStringAsFixed(1)} m).';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationMessage = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. '
        'Enable GPS/location and try again.',
      );
    }

    var permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator
              .requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Enable location permission for Smart Attendance '
        'from device or browser settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final latitude = double.parse(
      _latitudeController.text.trim(),
    );
    final longitude = double.parse(
      _longitudeController.text.trim(),
    );
    final radius = double.parse(
      _radiusController.text.trim(),
    );

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> response;

      if (_isEditing) {
        final classroomId = _asInt(
          widget.classroom?[
              'classroom_id'],
        );

        response = await widget
            .adminService
            .updateClassroom(
          classroomId: classroomId,
          buildingName:
              _buildingController.text,
          roomNumber:
              _roomController.text,
          latitude: latitude,
          longitude: longitude,
          geofenceRadiusMeters:
              radius,
        );
      } else {
        response = await widget
            .adminService
            .createClassroom(
          buildingName:
              _buildingController.text,
          roomNumber:
              _roomController.text,
          latitude: latitude,
          longitude: longitude,
          geofenceRadiusMeters:
              radius,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']
                ?.toString() ??
            (_isEditing
                ? 'Classroom updated successfully.'
                : 'Classroom created successfully.'),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error
                  .toString()
                  .replaceFirst(
                    'Exception: ',
                    '',
                  ),
            ),
            behavior:
                SnackBarBehavior.floating,
            backgroundColor:
                AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 620,
        ),
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing
                            ? 'Edit Classroom'
                            : 'Add Classroom',
                        style:
                            const TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop();
                            },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'The saved latitude, longitude and radius are used '
                  'by the attendance geofence.',
                  style: TextStyle(
                    color:
                        AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller:
                      _buildingController,
                  enabled: !_saving,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Building Name',
                    hintText:
                        'Example: CSE Building',
                    border:
                        OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons
                          .location_city_rounded,
                    ),
                  ),
                  validator: (value) {
                    final text =
                        value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Building name is required.';
                    }

                    if (text.length > 100) {
                      return 'Maximum 100 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller:
                      _roomController,
                  enabled: !_saving,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    labelText: 'Room Number',
                    hintText: 'Example: 305',
                    border:
                        OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons
                          .meeting_room_rounded,
                    ),
                  ),
                  validator: (value) {
                    final text =
                        value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Room number is required.';
                    }

                    if (text.length > 50) {
                      return 'Maximum 50 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed:
                      _gettingLocation ||
                              _saving
                          ? null
                          : _useCurrentLocation,
                  icon: _gettingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .my_location_rounded,
                        ),
                  label: Text(
                    _gettingLocation
                        ? 'Getting Location...'
                        : 'Use Current Location',
                  ),
                ),
                if (_locationMessage !=
                    null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _locationMessage!,
                    style: TextStyle(
                      color: AppColors
                          .textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final compact =
                        constraints.maxWidth <
                            480;

                    final latitude =
                        _coordinateField(
                      controller:
                          _latitudeController,
                      label: 'Latitude',
                      minimum: -90,
                      maximum: 90,
                    );

                    final longitude =
                        _coordinateField(
                      controller:
                          _longitudeController,
                      label: 'Longitude',
                      minimum: -180,
                      maximum: 180,
                    );

                    if (compact) {
                      return Column(
                        children: [
                          latitude,
                          const SizedBox(
                            height: 14,
                          ),
                          longitude,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: latitude,
                        ),
                        const SizedBox(
                          width: 14,
                        ),
                        Expanded(
                          child: longitude,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller:
                      _radiusController,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Geofence Radius (meters)',
                    hintText: '50',
                    helperText:
                        'Allowed range: 10 to 500 meters',
                    border:
                        OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.radar_rounded,
                    ),
                  ),
                  validator: (value) {
                    final parsed =
                        double.tryParse(
                      value?.trim() ?? '',
                    );

                    if (parsed == null) {
                      return 'Enter a valid radius.';
                    }

                    if (parsed < 10 ||
                        parsed > 500) {
                      return 'Radius must be between 10 and 500 meters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop();
                            },
                      child:
                          const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed:
                          _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons
                                      .save_rounded
                                  : Icons
                                      .add_rounded,
                            ),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : (_isEditing
                                ? 'Save Changes'
                                : 'Add Classroom'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coordinateField({
    required TextEditingController
        controller,
    required String label,
    required double minimum,
    required double maximum,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType:
          const TextInputType
              .numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        border:
            const OutlineInputBorder(),
        prefixIcon: const Icon(
          Icons.pin_drop_outlined,
        ),
      ),
      validator: (value) {
        final parsed = double.tryParse(
          value?.trim() ?? '',
        );

        if (parsed == null) {
          return 'Enter a valid $label.';
        }

        if (parsed < minimum ||
            parsed > maximum) {
          return '$label must be between '
              '${minimum.toInt()} and '
              '${maximum.toInt()}.';
        }

        return null;
      },
    );
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _initialNumber(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      final number = value.toDouble();

      if (number ==
          number.roundToDouble()) {
        return number
            .toInt()
            .toString();
      }

      return number.toString();
    }

    return value.toString();
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      ),
    );
  }
}
