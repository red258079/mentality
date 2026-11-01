import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../core/api/life_log_repository.dart';
import '../../core/utils/sleep_time_utils.dart';
import '../../core/utils/sleep_detector.dart';
import '../../core/services/sleep_sensor_service.dart';
import '../../core/services/workplace_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/utils/storage.dart';
import '../../core/onboarding/models/feature_keys.dart';
import '../../core/onboarding/models/onboarding_step.dart';
import '../../core/onboarding/feature_tour_controller.dart';
import '../../core/onboarding/widgets/help_guide_button.dart';

/// Pure function checking whether a given ISO date/timestamp string [iso]
/// corresponds to the same calendar day as [now] in the local time zone.
bool isSameLocalDay(String? iso, DateTime now) {
  if (iso == null || iso.trim().isEmpty) return false;
  try {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return false;
    final localDt = parsed.toLocal();
    final localNow = now.toLocal();
    return localDt.year == localNow.year &&
        localDt.month == localNow.month &&
        localDt.day == localNow.day;
  } catch (_) {
    return false;
  }
}

/// Màn hình Ghi Nhật Ký Sinh Hoạt — giờ ngủ, mức stress, triệu chứng
class LifeLogScreen extends StatefulWidget {
  const LifeLogScreen({super.key});

  @override
  State<LifeLogScreen> createState() => _LifeLogScreenState();
}

class _LifeLogScreenState extends State<LifeLogScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Form values
  int _stressLevel = 2;
  double _sleepHours = 7.0;
  String? _shiftType;
  final List<String> _selectedSymptoms = [];
  final _noteController = TextEditingController();
  int? _waterIntakeMl;

  // Suggested bedtime & wake time based on shift / auto-sensor
  TimeOfDay _suggestedBedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _suggestedWakeTime = const TimeOfDay(hour: 6, minute: 30);
  bool _hasUserEditedTimes = false;
  bool _hasUserEditedSlider = false;
  bool _hasUserPickedShift = false;
  bool _shiftWasAutoInferred = false;

  // Sleep sensor & detection states
  bool _isUsagePermissionGranted = false;
  bool _isLoadingSleepData = false;
  ScreenGap? _detectedSleepGap;
  bool _isHighConfidence = false;
  List<String> _confidenceReasons = [];
  List<ScreenEvent> _cachedScreenEvents = [];

  // States
  bool _isLoading = false;
  bool _hasCompletedToday = false;
  Map<String, dynamic>? _todayLifeLogData;

  // Feature onboarding tour keys
  final GlobalKey _sleepSuggestionKey = GlobalKey();
  final GlobalKey _sleepSliderKey = GlobalKey();
  final GlobalKey _shiftChipsKey = GlobalKey();
  final GlobalKey _saveButtonKey = GlobalKey();
  final GlobalKey _reminderCardKey = GlobalKey();
  bool _hasAutoRunTour = false;

  // Tab controller for history vs new entry
  late TabController _tabController;

  // Pre-loaded history
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = true;

  static const _symptoms = [
    {'icon': '🦴', 'label': 'Đau vai gáy'},
    {'icon': '🔩', 'label': 'Đau lưng'},
    {'icon': '😵', 'label': 'Đau đầu'},
    {'icon': '👁️', 'label': 'Mỏi mắt'},
    {'icon': '🦶', 'label': 'Đau chân'},
    {'icon': '🌡️', 'label': 'Chóng mặt'},
    {'icon': '🤢', 'label': 'Buồn nôn'},
    {'icon': '💤', 'label': 'Ngủ gật'},
  ];

  static const _stressLabels = ['', 'Bình thản 😌', 'Nhẹ nhàng 🙂', 'Trung bình 😐', 'Căng thẳng 😟', 'Rất căng 😰'];
  static const _stressColors = [
    Colors.transparent,
    AppTheme.accentMint,
    Color(0xFF34D399),
    AppTheme.accentAmber,
    Color(0xFFF97316),
    AppTheme.accentCoral,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _checkTodayLifeLog();
    _loadHistory();
    _loadSleepSensorData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-evaluate sleep data and permissions when user returns to app
      _checkTodayLifeLog();
      _loadSleepSensorData();
    }
  }

  Future<void> _checkTodayLifeLog() async {
    try {
      final res = await LifeLogRepository.getTodayLifeLog();
      final hasLog = res['has_log_today'] as bool? ?? false;
      final data = res['data'] as Map<String, dynamic>?;
      if (hasLog && data != null) {
        final dateStr = (data['date'] ?? data['journal_date'] ?? data['created_at']) as String?;
        if (isSameLocalDay(dateStr, DateTime.now())) {
          if (mounted) {
            setState(() {
              _todayLifeLogData = data;
              _hasCompletedToday = true;
            });
          }
          return;
        }
      }

      // If hasLog is false, date is missing, or not local today: keep form visible
      if (mounted) {
        setState(() {
          _hasCompletedToday = false;
        });
        _scheduleAutoTour();
      }
    } catch (e) {
      debugPrint('[LifeLogScreen] Lỗi kiểm tra nhật ký hôm nay: $e');
      if (mounted) {
        _scheduleAutoTour();
      }
    }
  }

  void _scheduleAutoTour() {
    if (_hasAutoRunTour) return;
    _hasAutoRunTour = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasCompletedToday && _tabController.index == 0) {
        _startTour(force: false);
      }
    });
  }

  void _startTour({bool force = false}) {
    if (_hasCompletedToday) {
      if (force && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn đã hoàn thành nhật ký hôm nay. Hướng dẫn chỉ áp dụng cho biểu mẫu ghi nhật ký.',
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }

    final allSteps = [
      OnboardingStep(
        targetKey: _sleepSuggestionKey,
        title: 'Gợi Ý Giấc Ngủ',
        description: 'Tự động nhận diện khung giờ ngủ từ cảm biến máy hoặc theo ca làm.',
        icon: Icons.auto_awesome_rounded,
      ),
      OnboardingStep(
        targetKey: _sleepSliderKey,
        title: 'Thời Gian Ngủ',
        description: 'Kéo thanh trượt để chỉnh số giờ bạn đã ngủ sau ca.',
        icon: Icons.linear_scale_rounded,
      ),
      OnboardingStep(
        targetKey: _shiftChipsKey,
        title: 'Ca Làm Việc',
        description: 'Chọn ca ngày hoặc ca đêm để tối ưu hóa nhịp sinh học.',
        icon: Icons.work_outline_rounded,
      ),
      OnboardingStep(
        targetKey: _saveButtonKey,
        title: 'Lưu Nhật Ký',
        description: 'Lưu lại mỗi ngày để theo dõi phục hồi và ngăn ngừa kiệt sức.',
        icon: Icons.save_rounded,
      ),
      OnboardingStep(
        targetKey: _reminderCardKey,
        title: 'Nhắc Nhở Hằng Ngày',
        description: 'Bật thông báo nhắc nhở để không quên ghi nhật ký đúng giờ.',
        icon: Icons.alarm_on_rounded,
      ),
    ];

    final steps = allSteps.where((s) => s.targetKey.currentContext != null).toList();
    if (steps.isEmpty) return;

    FeatureTour.start(
      context,
      featureKey: FeatureKeys.lifeLog,
      force: force,
      steps: steps,
    );
  }

  bool get _isLogQueuedOffline {
    if (_todayLifeLogData?['is_offline'] == true) {
      final dateStr = (_todayLifeLogData?['date'] ??
          _todayLifeLogData?['journal_date'] ??
          _todayLifeLogData?['created_at']) as String?;
      if (dateStr == null || isSameLocalDay(dateStr, DateTime.now())) {
        return true;
      }
    }
    try {
      final queue = StorageUtil.getSyncQueue();
      final now = DateTime.now();
      return queue.any((item) {
        if (item['type'] != 'life_log') return false;
        final timestamp = item['timestamp'] as String?;
        if (timestamp != null) {
          return isSameLocalDay(timestamp, now);
        }
        final payload = item['payload'] as Map<String, dynamic>?;
        final payloadDate = (payload?['date'] ?? payload?['journal_date']) as String?;
        if (payloadDate != null) {
          return isSameLocalDay(payloadDate, now);
        }
        final idStr = item['id'] as String?;
        if (idStr != null) {
          final ms = int.tryParse(idStr);
          if (ms != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(ms);
            return isSameLocalDay(dt.toIso8601String(), now);
          }
        }
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await LifeLogRepository.getHistory(days: 7);
      final entries = (data['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _history = entries; _historyLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _historyLoading = false; });
    }
  }

  Future<void> _saveLifeLog() async {
    setState(() { _isLoading = true; });

    try {
      final result = await LifeLogRepository.createLifeLog(
        stressLevel: _stressLevel,
        sleepHours: _sleepHours,
        shiftType: _shiftType,
        physicalSymptoms: _selectedSymptoms,
        moodNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        waterIntakeMl: _waterIntakeMl,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasCompletedToday = true;
          _todayLifeLogData = {
            ...result,
            'date': DateTime.now().toIso8601String(),
            'sleep_hours': _sleepHours,
            'shift_type': _shiftType,
            'stress_level': _stressLevel,
            'wellbeing_score': result['wellbeing_score'] ?? 80,
          };
          _hasUserEditedTimes = false;
          _hasUserEditedSlider = false;
          _hasUserPickedShift = false;
          _shiftWasAutoInferred = false;
        });
        _loadHistory(); // Refresh history
        ReminderService.onLifeLogSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.accentCoral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Nhật Ký Sinh Hoạt'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          HelpGuideButton(
            onTap: () => _startTour(force: true),
            tooltip: 'Xem hướng dẫn Nhật ký',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.onSurface(context),
          unselectedLabelColor: AppTheme.onSurfaceMuted(context),
          tabs: const [
            Tab(text: 'Ghi hôm nay', icon: Icon(Icons.edit_rounded, size: 18)),
            Tab(text: 'Lịch sử', icon: Icon(Icons.history_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _hasCompletedToday ? _buildCompletedTodayView() : _buildEntryForm(),
          _buildHistoryView(),
        ],
      ),
    );
  }

  // ─── Entry Form ─────────────────────────────────────────────────────────────

  Widget _buildEntryForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: _sleepSuggestionKey,
            child: _buildSleepSuggestionCard(),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('💤 Số giờ ngủ ca vừa rồi', formatHoursMinutes(_sleepHours)),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _sleepSliderKey,
            child: _buildSleepSlider(),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('🧠 Mức độ căng thẳng', _stressLabels[_stressLevel]),
          const SizedBox(height: 12),
          _buildStressSelector(),

          const SizedBox(height: 24),

          _buildSectionHeader(
            '🏭 Loại ca làm việc',
            _shiftType == 'day'
                ? (_shiftWasAutoInferred ? 'Ca ngày ☀️ (tự đoán)' : 'Ca ngày ☀️')
                : _shiftType == 'night'
                    ? (_shiftWasAutoInferred ? 'Ca đêm 🌙 (tự đoán)' : 'Ca đêm 🌙')
                    : 'Chưa chọn',
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _shiftChipsKey,
            child: _buildShiftSelector(),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('🦴 Triệu chứng thể chất', '${_selectedSymptoms.length} đã chọn'),
          const SizedBox(height: 12),
          _buildSymptomsGrid(),

          const SizedBox(height: 24),

          _buildSectionHeader('💧 Lượng nước uống', _waterIntakeMl != null ? '${_waterIntakeMl}ml' : 'Chưa ghi'),
          const SizedBox(height: 12),
          _buildWaterSelector(),

          const SizedBox(height: 24),

          _buildSectionHeader('📝 Ghi chú tâm trạng', ''),
          const SizedBox(height: 12),
          _buildNoteField(),

          const SizedBox(height: 24),
          KeyedSubtree(
            key: _reminderCardKey,
            child: _buildReminderCard(),
          ),

          const SizedBox(height: 24),
          KeyedSubtree(
            key: _saveButtonKey,
            child: _buildSaveButton(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (value.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _buildSleepSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _sleepColor(_sleepHours),
              thumbColor: _sleepColor(_sleepHours),
              inactiveTrackColor: AppTheme.borderColor(context),
              overlayColor: _sleepColor(_sleepHours).withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _sleepHours.clamp(0.0, 14.0),
              min: 0,
              max: 14,
              divisions: 56,
              onChanged: (v) => setState(() {
                _hasUserEditedSlider = true;
                _sleepHours = double.parse(v.toStringAsFixed(2));
              }),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0h', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted(context))),
              Text(_sleepQualityLabel(_sleepHours), style: TextStyle(fontSize: 12, color: _sleepColor(_sleepHours), fontWeight: FontWeight.w600)),
              Text('14h', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStressSelector() {
    return Row(
      children: List.generate(5, (i) {
        final level = i + 1;
        final isSelected = _stressLevel == level;
        final color = _stressColors[level];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _stressLevel = level),
            child: AnimatedContainer(
              duration: 200.ms,
              margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? color : AppTheme.borderColor(context), width: isSelected ? 2 : 1),
              ),
              child: Column(
                children: [
                  Text('$level', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isSelected ? color : AppTheme.onSurfaceMuted(context))),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildShiftSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildShiftChip('day', '☀️ Ca ngày', AppTheme.accentAmber)),
            const SizedBox(width: 12),
            Expanded(child: _buildShiftChip('night', '🌙 Ca đêm', AppTheme.sleepColor)),
          ],
        ),
        if (_shiftWasAutoInferred && _shiftType != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: _shiftType == 'day' ? AppTheme.accentAmber : AppTheme.sleepColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'ca được đoán tự động',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _shiftType == 'day' ? AppTheme.accentAmber : AppTheme.sleepColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShiftChip(String type, String label, Color color) {
    final isSelected = _shiftType == type;
    return GestureDetector(
      onTap: () => _onShiftChanged(isSelected ? null : type),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : AppTheme.borderColor(context), width: isSelected ? 2 : 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? color : AppTheme.onSurfaceSecondary(context),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ─── Sleep Sensor Data & Suggestion Card Helpers ─────────────────────────────

  Future<void> _loadSleepSensorData() async {
    if (!mounted) return;
    setState(() => _isLoadingSleepData = true);

    try {
      // 1. Check UsageStats permission
      final hasPermission =
          await SleepSensorService.instance.isUsagePermissionGranted();
      _isUsagePermissionGranted = hasPermission;

      // 2. Read soft signals: Charging and atDorm (foreground once)
      final chargingData =
          await SleepSensorService.instance.getChargingState();
      final isCharging = chargingData['isCharging'] as bool? ?? false;

      // GPS soft signal: evaluate current location once without prompting new permission
      bool isAtDorm = false;
      try {
        await WorkplaceService.instance
            .evaluateCurrentLocation(promptPermission: false);
        isAtDorm = WorkplaceService.instance.status == WorkplaceStatus.atDorm;
      } catch (_) {}

      if (!hasPermission) {
        // Fall back to shift defaults
        final defaults = SleepTimeUtils.defaultTimesForShift(_shiftType);
        _suggestedBedtime = defaults.bedtime;
        _suggestedWakeTime = defaults.wakeTime;
        _detectedSleepGap = null;
        _cachedScreenEvents = [];
        _isHighConfidence = false;
        _confidenceReasons = [];
        if (mounted) setState(() => _isLoadingSleepData = false);
        return;
      }

      // 3. Query last 24h screen events
      final events =
          await SleepSensorService.instance.getScreenEvents(hours: 24);
      _cachedScreenEvents = events;

      // 4. Detect the sleep gap with wide window (shiftType null) first
      final gap = SleepDetector.findLongestSleepGap(
        events,
        shiftType: _hasUserPickedShift ? _shiftType : null,
      );
      _detectedSleepGap = gap;

      if (gap != null) {
        // Auto-select _shiftType if user hasn't manually picked a shift chip
        if (!_hasUserPickedShift) {
          final inferred = SleepDetector.inferShiftTypeFromGapStart(gap.start);
          if (inferred != null) {
            _shiftType = inferred;
            _shiftWasAutoInferred = true;
          }
        }

        // Feed into suggested bedtime / wake time (unless user edited them with pickers)
        if (!_hasUserEditedTimes) {
          final localStart = gap.start.toLocal();
          final localEnd = gap.end.toLocal();
          _suggestedBedtime =
              TimeOfDay(hour: localStart.hour, minute: localStart.minute);
          _suggestedWakeTime =
              TimeOfDay(hour: localEnd.hour, minute: localEnd.minute);
        }

        // Automatically set _sleepHours to gap duration if user hasn't edited slider or pickers
        if (!_hasUserEditedTimes && !_hasUserEditedSlider) {
          _sleepHours = gap.durationHours.clamp(0.0, 14.0);
        }

        // Confidence calculation: show "Độ tin cậy cao" only when at least 2 signals agree
        final reasons = <String>[];
        if (isCharging) {
          reasons.add('Đang cắm sạc pin');
        }
        if (isAtDorm) {
          reasons.add('Tại phòng trọ / KTX');
        }

        _isHighConfidence = reasons.length >= 2;
        _confidenceReasons = reasons;
      } else {
        // Fall back to shift defaults when no gap found
        if (!_hasUserEditedTimes) {
          final defaults = SleepTimeUtils.defaultTimesForShift(_shiftType);
          _suggestedBedtime = defaults.bedtime;
          _suggestedWakeTime = defaults.wakeTime;
        }
        _isHighConfidence = false;
        _confidenceReasons = [];
      }
    } catch (e) {
      debugPrint('[LifeLogScreen] Lỗi tải dữ liệu cảm biến giấc ngủ: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSleepData = false);
      }
    }
  }

  Future<void> _requestUsagePermission() async {
    await SleepSensorService.instance.requestUsagePermission();
  }

  void _onShiftChanged(String? newShift) {
    setState(() {
      _hasUserPickedShift = true;
      _shiftWasAutoInferred = false;
      _shiftType = newShift;
      // Re-evaluate sleep gap for new shift if we have events
      ScreenGap? newGap;
      if (_cachedScreenEvents.isNotEmpty) {
        newGap = SleepDetector.findLongestSleepGap(
          _cachedScreenEvents,
          shiftType: newShift,
        );
      }
      _detectedSleepGap = newGap;
      if (newGap == null) {
        _isHighConfidence = false;
        _confidenceReasons = [];
      }
      if (!_hasUserEditedTimes) {
        if (newGap != null) {
          final start = newGap.start.toLocal();
          final end = newGap.end.toLocal();
          _suggestedBedtime = TimeOfDay(hour: start.hour, minute: start.minute);
          _suggestedWakeTime = TimeOfDay(hour: end.hour, minute: end.minute);
        } else {
          final defaults = SleepTimeUtils.defaultTimesForShift(newShift);
          _suggestedBedtime = defaults.bedtime;
          _suggestedWakeTime = defaults.wakeTime;
        }
      }
      if (!_hasUserEditedTimes && !_hasUserEditedSlider && newGap != null) {
        _sleepHours = newGap.durationHours.clamp(0.0, 14.0);
      }
    });
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _suggestedBedtime,
      helpText: 'Chọn giờ đi ngủ',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && picked != _suggestedBedtime) {
      setState(() {
        _suggestedBedtime = picked;
        _hasUserEditedTimes = true;
      });
    }
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _suggestedWakeTime,
      helpText: 'Chọn giờ thức dậy',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && picked != _suggestedWakeTime) {
      setState(() {
        _suggestedWakeTime = picked;
        _hasUserEditedTimes = true;
      });
    }
  }

  Widget _buildReminderCard() {
    final enabled = StorageUtil.isSleepReminderEnabled;
    final hour = StorageUtil.sleepReminderHour;
    final minute = StorageUtil.sleepReminderMinute;
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alarm_on_rounded,
            size: 20,
            color: enabled ? AppTheme.sleepColor : AppTheme.onSurfaceMuted(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhắc nhở ghi nhận giấc ngủ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  enabled ? 'Mỗi ngày lúc $timeStr (1 chạm)' : 'Đang tắt nhắc nhở',
                  style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                  helpText: 'Chọn giờ nhắc nhở giấc ngủ',
                  confirmText: 'Lưu',
                  cancelText: 'Hủy',
                );
                if (picked != null) {
                  await StorageUtil.setSleepReminderTime(picked.hour, picked.minute);
                  setState(() {});
                  await ReminderService.rescheduleAll();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.sleepColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.sleepColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Switch(
            value: enabled,
            activeColor: AppTheme.sleepColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) async {
              if (val) {
                final messenger = ScaffoldMessenger.of(context);
                final granted = await ReminderService.requestPermission(context: context);
                if (!granted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng cấp quyền thông báo trong cài đặt máy.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  await StorageUtil.setSleepReminderEnabled(false);
                  await ReminderService.cancelAll();
                  if (mounted) setState(() {});
                  return;
                }
                await StorageUtil.setSleepReminderEnabled(true);
                await ReminderService.rescheduleAll();
                if (mounted) setState(() {});
              } else {
                await StorageUtil.setSleepReminderEnabled(false);
                await ReminderService.cancelAll();
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSleepSuggestionCard() {
    final computedHours = calculateSleepDuration(_suggestedBedtime, _suggestedWakeTime);
    final durationFormatted = formatHoursMinutes(computedHours);
    final isNightShift = _shiftType == 'night';
    final hasAutoData = _detectedSleepGap != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF131D2E)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.sleepColor.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.sleepColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasAutoData ? Icons.auto_awesome_rounded : Icons.bedtime_outlined,
                  size: 20,
                  color: AppTheme.sleepColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          hasAutoData
                              ? 'Gợi ý giấc ngủ (tự động)'
                              : 'Gợi ý giấc ngủ theo ca',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (_detectedSleepGap != null && _isHighConfidence)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentMint.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.accentMint.withOpacity(0.5)),
                            ),
                            child: const Text(
                              'Độ tin cậy cao ✨',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAutoData
                          ? (_confidenceReasons.isNotEmpty
                              ? 'Tự động nhận diện (${_confidenceReasons.join(", ")})'
                              : 'Nhận diện từ thời gian tắt màn hình đêm qua')
                          : (isNightShift
                              ? 'Ca đêm (ngủ ban ngày)'
                              : 'Ca ngày / thông thường (ngủ ban đêm)'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingSleepData)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.sleepColor,
                  ),
                ),
            ],
          ),

          // Permission banner if Usage Access is not granted (Android only)
          if (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              !_isUsagePermissionGranted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bật quyền sử dụng để tự động phát hiện giờ ngủ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _requestUsagePermission,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Cấp quyền',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Suggestion text worded as suggestion (not fact)
          Text(
            'Gợi ý: bạn ngủ khoảng $durationFormatted',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasAutoData
                ? 'Dựa vào thời gian tắt màn hình đêm qua. Bạn có thể bấm vào giờ để sửa hoặc bấm Áp dụng để điền vào thanh trượt.'
                : 'Dựa vào khung giờ dự kiến. Bạn có thể bấm vào giờ để sửa hoặc bấm Áp dụng để điền vào thanh trượt.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceMuted(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // Time pickers row
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Giờ đi ngủ',
                  time: _suggestedBedtime,
                  icon: isNightShift ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                  onTap: _pickBedtime,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppTheme.onSurfaceMuted(context),
                ),
              ),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Giờ thức dậy',
                  time: _suggestedWakeTime,
                  icon: isNightShift ? Icons.bedtime_outlined : Icons.wb_sunny_outlined,
                  onTap: _pickWakeTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1-tap confirm button to fill _sleepHours in the form
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final appliedHours = computedHours.clamp(0.0, 14.0);
                setState(() {
                  _hasUserEditedSlider = true;
                  _sleepHours = appliedHours;
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      computedHours > 14.0
                          ? 'Đã đặt mức tối đa thanh trượt: ${formatHoursMinutes(appliedHours)} ngủ (tính ra $durationFormatted)'
                          : 'Đã cập nhật thanh trượt: ${formatHoursMinutes(appliedHours)} ngủ',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.sleepColor),
              label: Text(
                computedHours > 14.0
                    ? 'Áp dụng ${formatHoursMinutes(computedHours.clamp(0.0, 14.0))} (tối đa) vào nhật ký'
                    : 'Áp dụng $durationFormatted vào nhật ký',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.sleepColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.sleepColor.withOpacity(0.5)),
                backgroundColor: AppTheme.sleepColor.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.sleepColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurfaceMuted(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  SleepTimeUtils.formatTimeOfDay(time),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppTheme.onSurfaceMuted(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _symptoms.map((s) {
        final label = s['label']!;
        final emoji = s['icon']!;
        final isSelected = _selectedSymptoms.contains(label);
        return GestureDetector(
          onTap: () => setState(() {
            isSelected ? _selectedSymptoms.remove(label) : _selectedSymptoms.add(label);
          }),
          child: AnimatedContainer(
            duration: 150.ms,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentCoral.withOpacity(0.15) : AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? AppTheme.accentCoral : AppTheme.borderColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppTheme.accentCoral : AppTheme.onSurfaceSecondary(context), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWaterSelector() {
    final options = [500, 1000, 1500, 2000, 2500];
    return Row(
      children: options.map((ml) {
        final isSelected = _waterIntakeMl == ml;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _waterIntakeMl = isSelected ? null : ml),
            child: AnimatedContainer(
              duration: 150.ms,
              margin: EdgeInsets.only(right: ml < 2500 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.secondary.withOpacity(0.15) : AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? AppTheme.secondary : AppTheme.borderColor(context)),
              ),
              child: Column(children: [
                Text('💧', style: TextStyle(fontSize: isSelected ? 18 : 14)),
                Text(ml ~/ 1000 > 0 ? '${ml / 1000}L' : '${ml}ml',
                  style: TextStyle(fontSize: 10, color: isSelected ? AppTheme.secondary : AppTheme.onSurfaceMuted(context), fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      maxLength: 1000,
      style: TextStyle(color: AppTheme.onSurface(context), fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Ghi lại cảm xúc, suy nghĩ, hoặc sự kiện đặc biệt trong ca hôm nay...',
        hintStyle: TextStyle(color: AppTheme.onSurfaceMuted(context), fontSize: 13),
        filled: true,
        fillColor: AppTheme.surfaceAltColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.borderColor(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.borderColor(context))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryLight)),
        counterStyle: TextStyle(color: AppTheme.onSurfaceMuted(context), fontSize: 11),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveLifeLog,
        icon: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded),
        label: Text(_isLoading ? 'Đang lưu...' : 'Lưu Nhật Ký Hôm Nay'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ─── Completed Today View ───────────────────────────────────────────────────

  int _extractWellbeingScore(Map<String, dynamic> data) {
    if (data['wellbeing_score'] != null) {
      return (data['wellbeing_score'] as num).toInt();
    }
    final stress = (data['stress_level'] as num?)?.toInt() ?? 2;
    final sleep = (data['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final symptoms = (data['physical_symptoms'] as List?)?.length ?? 0;
    int score = 100 - (stress - 1) * 8;
    if (sleep < 5) {
      score -= 30;
    } else if (sleep < 6) {
      score -= 20;
    } else if (sleep < 7) {
      score -= 10;
    } else if (sleep >= 8) {
      score += 5;
    }
    if (symptoms > 0) score -= 15;
    return score.clamp(30, 100);
  }

  Widget _buildCompletedTodayView() {
    final data = _todayLifeLogData ?? {};
    final sleepHours = (data['sleep_hours'] as num?)?.toDouble() ?? 0.0;
    final shiftType = data['shift_type'] as String?;
    final stressLevel = (data['stress_level'] as num?)?.toInt() ?? 3;
    final wellbeingScore = _extractWellbeingScore(data);
    final isOfflineQueued = _isLogQueuedOffline;

    final shiftLabel = shiftType == 'day'
        ? 'Ca ngày ☀️'
        : shiftType == 'night'
            ? 'Ca đêm 🌙'
            : 'Không chia ca';

    final stressLabel = (stressLevel >= 1 && stressLevel <= 5)
        ? _stressLabels[stressLevel]
        : 'Mức $stressLevel';

    final riskAssessment = data['risk_assessment'] as Map<String, dynamic>? ??
        (data['risk_assessment'] as Map?)?.cast<String, dynamic>();
    final riskLevel = (riskAssessment?['level'] as String?)?.toUpperCase() ?? 'GREEN';
    final riskActions = ((riskAssessment?['recommended_actions'] ?? riskAssessment?['actions']) as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    Color riskColor = AppTheme.accentMint;
    String riskEmoji = '✅';
    if (riskLevel == 'YELLOW' || riskLevel == 'MEDIUM') {
      riskColor = AppTheme.accentAmber;
      riskEmoji = '⚠️';
    } else if (riskLevel == 'RED' || riskLevel == 'HIGH') {
      riskColor = AppTheme.accentCoral;
      riskEmoji = '🆘';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Completed Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentMint.withOpacity(0.14),
                  AppTheme.surfaceColor(context),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentMint.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentMint,
                  size: 52,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn đã hoàn thành nhật ký hôm nay ✅',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Điểm sức khỏe hôm nay: $wellbeingScore/100',
                  style: TextStyle(
                    fontSize: 14,
                    color: _wellbeingColor(wellbeingScore),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isOfflineQueued) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 14, color: AppTheme.accentAmber),
                        SizedBox(width: 6),
                        Text(
                          'đang chờ đồng bộ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(curve: Curves.easeOutBack),

          const SizedBox(height: 16),

          // Detailed metrics row 1: Giấc ngủ & Ca làm việc
          Row(
            children: [
              Expanded(
                child: _buildResultMetric(
                  'Giấc ngủ',
                  '💤',
                  formatHoursMinutes(sleepHours),
                  AppTheme.sleepColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultMetric(
                  'Ca làm việc',
                  shiftType == 'night' ? '🌙' : '☀️',
                  shiftLabel,
                  shiftType == 'night' ? AppTheme.sleepColor : AppTheme.accentAmber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detailed metrics row 2: Stress & Điểm sức khỏe
          Row(
            children: [
              Expanded(
                child: _buildResultMetric(
                  'Mức stress',
                  '🧠',
                  stressLabel,
                  _stressColors[stressLevel.clamp(1, 5)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultMetric(
                  'Sức khỏe',
                  '💖',
                  '$wellbeingScore/100',
                  _wellbeingColor(wellbeingScore),
                ),
              ),
            ],
          ),

          // AI Risk Assessment & actions (when available from save result or cache)
          if (riskAssessment != null && (riskActions.isNotEmpty || riskAssessment.isNotEmpty)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: riskColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(riskEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'AI Agent đánh giá: $riskLevel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: riskColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (riskActions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...riskActions.take(3).map((action) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.arrow_right_rounded, color: riskColor, size: 18),
                              Expanded(
                                child: Text(
                                  action,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.onSurfaceSecondary(context),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, end: 0),
          ],

          const SizedBox(height: 20),

          // Information banner explaining once per day
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.onSurfaceMuted(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nhật ký sinh hoạt được ghi nhận 1 lần mỗi ngày. Bạn có thể xem lại lịch sử các ngày trước ở tab Lịch sử bên cạnh.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultMetric(String label, String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted(context))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // ─── History View ────────────────────────────────────────────────────────────

  Widget _buildHistoryView() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_rounded, color: AppTheme.onSurfaceMuted(context), size: 60),
          const SizedBox(height: 12),
          Text('Chưa có nhật ký nào', style: TextStyle(color: AppTheme.onSurfaceMuted(context), fontSize: 16)),
          const SizedBox(height: 8),
          Text('Bắt đầu ghi hôm nay để theo dõi sức khỏe!', style: TextStyle(color: AppTheme.onSurfaceMuted(context), fontSize: 12)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final entry = _history[i];
        return _buildHistoryCard(entry);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final stressColor = Color(int.parse('0xFF${_stressHex(entry['stress_level'] as int? ?? 2)}'));
    final sleepColor = _sleepColor(entry['sleep_hours'] as double? ?? 7.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: stressColor.withOpacity(0.15)),
          child: Center(child: Text(entry['stress_emoji'] as String? ?? '😐', style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry['date'] as String? ?? '', style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted(context))),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.psychology_rounded, color: stressColor, size: 14),
            const SizedBox(width: 4),
            Text(entry['stress_label'] as String? ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stressColor)),
            const SizedBox(width: 12),
            Icon(Icons.bedtime_rounded, color: sleepColor, size: 14),
            const SizedBox(width: 4),
            Text(formatHoursMinutes(entry['sleep_hours'] as double? ?? 0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sleepColor)),
          ]),
          if ((entry['physical_symptoms'] as List?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Triệu chứng: ${(entry['physical_symptoms'] as List).join(", ")}',
                style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.surfaceAltColor(context), borderRadius: BorderRadius.circular(8)),
          child: Text(entry['ai_sentiment'] as String? ?? 'neutral', style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceSecondary(context))),
        ),
      ]),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Color _sleepColor(double hours) {
    if (hours >= 8) return AppTheme.accentMint;
    if (hours >= 7) return const Color(0xFF34D399);
    if (hours >= 6) return AppTheme.accentAmber;
    return AppTheme.accentCoral;
  }

  String _sleepQualityLabel(double hours) {
    if (hours >= 8) return 'Tuyệt vời ✨';
    if (hours >= 7) return 'Tốt 👍';
    if (hours >= 6) return 'Tạm ổn 😐';
    if (hours >= 5) return 'Thiếu ngủ 😟';
    return 'Rất thiếu ngủ 😰';
  }

  Color _wellbeingColor(int score) {
    if (score >= 80) return AppTheme.accentMint;
    if (score >= 60) return AppTheme.accentAmber;
    return AppTheme.accentCoral;
  }

  String _stressHex(int level) {
    const hexes = ['', '10B981', '34D399', 'F59E0B', 'F97316', 'EF4444'];
    return level > 0 && level <= 5 ? hexes[level] : 'F59E0B';
  }
}
