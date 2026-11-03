import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../state/app_state.dart';
import '../../state/auth_state.dart';
import '../../models/daily_checkin.dart';
import '../../theme/app_theme.dart';
import '../../core/api/life_log_repository.dart';
import '../../core/services/workplace_service.dart';
import '../../navigation/student_nav.dart';
import 'phq4_screener_screen.dart';
import '../../core/onboarding/models/feature_keys.dart';
import '../../core/onboarding/models/onboarding_step.dart';
import '../../core/onboarding/feature_tour_controller.dart';
import '../../core/onboarding/widgets/help_guide_button.dart';

/// Màn hình Điểm Danh + Nhận Thông Điệp Gacha
/// Tích hợp đầy đủ với API backend: điểm danh, streak, gacha message
class CheckinGachaScreen extends StatefulWidget {
  final MoodLevel? initialMood;
  const CheckinGachaScreen({super.key, this.initialMood});

  @override
  State<CheckinGachaScreen> createState() => CheckinGachaScreenState();
}

class CheckinGachaScreenState extends State<CheckinGachaScreen>
    with TickerProviderStateMixin {
  // GlobalKeys for Feature Onboarding Tour
  final GlobalKey _moodKey = GlobalKey();
  final GlobalKey _wheelKey = GlobalKey();

  // State
  bool _hasCheckedIn = false;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _gachaMessage;
  String? _gachaCategory;
  int _currentStreak = 0;
  int _longestStreak = 0;

  // Workplace & Geofence State
  WorkplaceProfile? _workplaceProfile;
  WorkplaceStatus _workplaceStatus = WorkplaceStatus.unknown;

  // Mood selection state
  String _selectedMood = 'neutral';
  final List<String> _selectedStressFactors = [];

  final _noteController = TextEditingController();

  // Animations
  late AnimationController _spinController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  late Animation<double> _spinAnimation;
  late Animation<double> _glowAnimation;

  bool _isSpinning = false;

  static const _moods = [
    {'key': 'great', 'emoji': '😄', 'label': 'Tuyệt vời', 'color': 0xFF10B981},
    {'key': 'good', 'emoji': '🙂', 'label': 'Tốt', 'color': 0xFF34D399},
    {
      'key': 'neutral',
      'emoji': '😐',
      'label': 'Bình thường',
      'color': 0xFFF59E0B,
    },
    {'key': 'tired', 'emoji': '😔', 'label': 'Mệt mỏi', 'color': 0xFFF97316},
    {
      'key': 'stressed',
      'emoji': '😰',
      'label': 'Căng thẳng',
      'color': 0xFFEF4444,
    },
  ];

  static const _factorsByMood = <String, List<String>>{
    'great': [
      '🎯 Hoàn thành mục tiêu',
      '🙌 Được ghi nhận',
      '🤝 Đồng nghiệp hỗ trợ',
      '😴 Ngủ đủ giấc',
      '💪 Cơ thể khỏe khoắn',
      '🎉 Có tin vui',
    ],
    'good': [
      '✅ Công việc thuận lợi',
      '🤝 Đồng nghiệp hỗ trợ',
      '😴 Ngủ đủ giấc',
      '🍲 Ăn uống đầy đủ',
      '💬 Trò chuyện vui vẻ',
      '🚶 Có thời gian nghỉ ngơi',
    ],
    'neutral': [
      '🏭 Ca làm như thường lệ',
      '⚖️ Khối lượng việc vừa sức',
      '🔁 Sinh hoạt quen thuộc',
      '🤔 Đang làm quen công việc',
      '🌤️ Chưa có gì đặc biệt',
      '💭 Nhiều suy nghĩ',
    ],
    'tired': [
      '🏭 Ca đêm',
      '⏰ Tăng ca kéo dài',
      '🦴 Đau vai gáy',
      '😴 Thiếu ngủ',
      '🦶 Đứng lâu / Đau chân',
      '🌡️ Nhiệt độ nhà máy',
    ],
    'stressed': [
      '⏰ Áp lực OT',
      '🏃 Chạy deadline',
      '🤔 Quy trình mới',
      '🔊 Tiếng ồn',
      '💬 Khó giao tiếp với đồng nghiệp',
      '💸 Lo lắng tài chính',
    ],
  };

  static const _factorPrompts = <String, String>{
    'great': 'Điều gì khiến hôm nay thật tuyệt vời?',
    'good': 'Điều gì giúp bạn cảm thấy tốt?',
    'neutral': 'Hôm nay của bạn diễn ra thế nào?',
    'tired': 'Điều gì khiến bạn mệt mỏi?',
    'stressed': 'Điều gì đang khiến bạn căng thẳng?',
  };

  static const _categoryIcons = {
    'motivation': Icons.rocket_launch_rounded,
    'sleep_recovery': Icons.bedtime_rounded,
    'physical_stretch': Icons.fitness_center_rounded,
    'social_connect': Icons.people_rounded,
    'mental_peace': Icons.spa_rounded,
  };

  static const _categoryColors = {
    'motivation': AppTheme.accentAmber,
    'sleep_recovery': AppTheme.sleepColor,
    'physical_stretch': AppTheme.physicalColor,
    'social_connect': AppTheme.socialColor,
    'mental_peace': AppTheme.mentalColor,
  };

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.initialMood?.apiKey ?? 'neutral';
    _initAnimations();
    _loadCheckinStatus();
    _loadWorkplaceData();
  }

  Future<void> _loadWorkplaceData() async {
    await WorkplaceService.instance.fetchCompanies();
    final prof = await WorkplaceService.instance.fetchProfile();
    final status = await WorkplaceService.instance.evaluateCurrentLocation(promptPermission: false);
    if (mounted) {
      setState(() {
        _workplaceProfile = prof;
        _workplaceStatus = status;
      });
    }
  }

  Future<void> _requestLocationAndUpdate() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Định vị GPS trên máy đang tắt. Vui lòng bật định vị!'),
            action: SnackBarAction(
              label: 'Bật GPS',
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng cấp quyền vị trí để tự động nhận diện công ty và trọ.')),
        );
      }
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quyền vị trí đã bị từ chối. Vui lòng mở Cài đặt để cấp quyền!'),
            action: SnackBarAction(
              label: 'Cài đặt',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    final newStatus = await WorkplaceService.instance.evaluateCurrentLocation(promptPermission: true);
    if (mounted) {
      setState(() {
        _workplaceStatus = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật vị trí làm việc thành công!')),
      );
    }
  }

  @override
  void didUpdateWidget(covariant CheckinGachaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasCheckedIn && !_isLoading && widget.initialMood != null) {
      _selectedMood = widget.initialMood!.apiKey;
      _selectedStressFactors.removeWhere(
        (factor) => !_factorsByMood[_selectedMood]!.contains(factor),
      );
    }
  }

  void _initAnimations() {
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.elasticOut,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _spinController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckinStatus() async {
    try {
      final data = await CheckinRepository.getTodayStatus();
      if (mounted) {
        setState(() {
          _hasCheckedIn = data['has_checked_in'] as bool? ?? false;
          _currentStreak = data['current_streak'] as int? ?? 0;
          _longestStreak = data['longest_streak'] as int? ?? 0;
          if (_hasCheckedIn) {
            _gachaMessage = data['gacha_message'] as String?;
            _selectedMood = data['mood'] as String? ?? _selectedMood;
          }
          _isInitialLoading = false;
        });
        final savedMood = CheckinMood.fromApi(data['mood'] as String?);
        if (_hasCheckedIn && savedMood != null) {
          context.read<AppState>().recordCheckin(
            savedMood,
            List<String>.from(data['stress_factors'] as List? ?? []),
            data['note'] as String? ?? '',
            streakDays: _currentStreak,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  void startTour({bool force = false}) => _startTour(force: force);

  void _startTour({bool force = false}) {
    FeatureTour.start(
      context,
      featureKey: FeatureKeys.checkin,
      force: force,
      steps: [
        OnboardingStep(
          targetKey: _wheelKey,
          title: 'Điểm Danh & Vòng Quay May Mắn',
          description: 'Ghi nhận cảm xúc ca làm và quay thưởng để nhận thông điệp tích cực hồi phục năng lượng.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }

  Future<void> _performCheckin() async {
    if (_isSpinning || _hasCheckedIn) return;

    // Start spin animation
    setState(() {
      _isSpinning = true;
      _isLoading = true;
    });
    _spinController.forward(from: 0);
    _particleController.forward(from: 0);

    try {
      final res = await CheckinRepository.performCheckin(
        mood: _selectedMood,
        stressFactors: _selectedStressFactors,
        note: _noteController.text.trim(),
      );

      // Wait for spin animation
      await Future.delayed(const Duration(milliseconds: 1600));

      if (mounted) {
        setState(() {
          _hasCheckedIn = true;
          _selectedMood = res['mood'] as String? ?? _selectedMood;
          _gachaMessage = res['gacha_message'] as String?;
          _gachaCategory = _extractCategory(
            res['gacha_message'] as String? ?? '',
          );
          _currentStreak = res['current_streak'] as int? ?? _currentStreak + 1;
          _longestStreak = res['longest_streak'] as int? ?? _longestStreak;
          _isLoading = false;
          _isSpinning = false;
        });

        context.read<AppState>().recordCheckin(
          CheckinMood.fromApi(_selectedMood)!,
          List<String>.from(
            res['stress_factors'] as List? ?? _selectedStressFactors,
          ),
          res['note'] as String? ?? _noteController.text.trim(),
          streakDays: _currentStreak,
        );
        context.read<AppState>().triggerRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSpinning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi điểm danh: $e'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  String _extractCategory(String message) {
    if (message.contains('ngủ') || message.contains('Melatonin')) {
      return 'sleep_recovery';
    }
    if (message.contains('giãn cơ') || message.contains('nước')) {
      return 'physical_stretch';
    }
    if (message.contains('Leader') || message.contains('Anh/Chị')) {
      return 'social_connect';
    }
    if (message.contains('hít thở') || message.contains('Box Breathing')) {
      return 'mental_peace';
    }
    return 'motivation';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Điểm Danh Hàng Ngày'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          HelpGuideButton(
            onTap: () => _startTour(force: true),
            tooltip: 'Xem hướng dẫn Điểm danh',
          ),
          IconButton(
            icon: Icon(
              Icons.home_rounded,
              color: AppTheme.onSurfaceSecondary(context),
            ),
            tooltip: 'Về trang chủ',
            onPressed: () => StudentNav.switchToTab(context, 0),
          ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Streak Hero Card
                    _buildStreakCard(),
                    const SizedBox(height: 16),

                    // Workplace & Smart Sleep Card
                    _buildWorkplaceSleepCard(),
                    const SizedBox(height: 16),

                    // PHQ-4 Medical Screening Banner
                    _buildPHQ4Banner(),
                    const SizedBox(height: 20),

                    if (!_hasCheckedIn) ...[
                      // Mood Selector
                      KeyedSubtree(key: _moodKey, child: _buildMoodSelector()),
                      const SizedBox(height: 16),

                      // Stress Factors
                      _buildStressFactorSelector(),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        enabled: !_isLoading,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú (tuỳ chọn)',
                          hintText: 'Bạn muốn chia sẻ thêm điều gì?',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Gacha Wheel & Spin Button
                      KeyedSubtree(key: _wheelKey, child: _buildGachaWheel()),
                      const SizedBox(height: 20),

                      // Spin Button
                      _buildSpinButton(),
                    ] else ...[
                      Text(
                        'Đã điểm danh hôm nay · ${CheckinMood.fromApi(_selectedMood)?.checkinLabel ?? ''}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      // Gacha Message Reveal
                      _buildGachaReveal(),
                      const SizedBox(height: 20),

                      // Done Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: const Text('Về trang chủ'),
                          onPressed: () => StudentNav.switchToTab(context, 0),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWorkplaceSleepCard() {
    final profile = _workplaceProfile;
    final companyName = profile?.companyName ?? 'LG Display Hải Phòng';
    final shift = profile?.workShift ?? 'day_12h';
    final shiftLabel = shift == 'night_12h'
        ? 'Ca đêm (20:00 – 08:00)'
        : (shift == 'office_8h' ? 'Hành chính (08:30 – 17:30)' : 'Ca ngày (08:00 – 20:00)');
    final estSleep = WorkplaceService.instance.calculateEstimatedSleepHours();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_workplaceStatus) {
      case WorkplaceStatus.atWorkplace:
        statusColor = const Color(0xFF10B981);
        statusText = 'Trong xưởng';
        statusIcon = Icons.factory_rounded;
        break;
      case WorkplaceStatus.atDorm:
        statusColor = const Color(0xFF38BDF8);
        statusText = 'Tại trọ / KTX';
        statusIcon = Icons.home_rounded;
        break;
      case WorkplaceStatus.outside:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Ngoài xưởng';
        statusIcon = Icons.directions_walk_rounded;
        break;
      case WorkplaceStatus.unknown:
        statusColor = Colors.grey;
        statusText = 'Bật vị trí';
        statusIcon = Icons.location_searching_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shiftLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.onSurfaceSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _showWorkplaceSetupModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text(
                        'Đổi ca',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _workplaceStatus == WorkplaceStatus.unknown
                      ? _requestLocationAndUpdate
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.sleepColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.sleepColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bedtime_rounded, size: 14, color: AppTheme.sleepColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Ngủ ~${estSleep.toStringAsFixed(1)}h',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.sleepColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<WorkplaceCompany?> _showCompanyPicker(
    BuildContext parentContext,
    String currentSelection,
    List<WorkplaceCompany> companiesList,
  ) async {
    return showModalBottomSheet<WorkplaceCompany>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(pickerCtx).size.height * 0.72,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(parentContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn Công Ty Thực Tập',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(pickerCtx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 20,
                  ),
                ],
              ),
              Text(
                'Hệ thống nạp tọa độ GPS trạm xưởng để tự động nhận diện ca làm',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceSecondary(parentContext),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: companiesList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final comp = companiesList[index];
                    final isSelected = comp.name == currentSelection;
                    return InkWell(
                      onTap: () => Navigator.pop(pickerCtx, comp),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : Theme.of(parentContext).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.borderColor(parentContext),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                comp.workplaceType == 'office'
                                    ? Icons.computer_rounded
                                    : (comp.workplaceType == 'custom'
                                        ? Icons.tune_rounded
                                        : Icons.factory_rounded),
                                color: isSelected ? Colors.white : AppTheme.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comp.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: isSelected ? AppTheme.primary : null,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    comp.address,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppTheme.onSurfaceSecondary(parentContext),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: Colors.grey.withValues(alpha: 0.35),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWorkplaceSetupModal() {
    final companies = WorkplaceService.instance.companies;
    final existingName = _workplaceProfile?.companyName.trim() ?? '';
    final existingType = _workplaceProfile?.workplaceType ?? '';
    WorkplaceCompany? matchedPreset;
    for (final c in companies) {
      if (c.id != 'custom' &&
          (c.name.toLowerCase() == existingName.toLowerCase() ||
              c.shortName.toLowerCase() == existingName.toLowerCase())) {
        matchedPreset = c;
        break;
      }
    }
    final customTemplate = companies.cast<WorkplaceCompany?>().firstWhere(
          (c) => c?.id == 'custom' || c?.workplaceType == 'custom',
          orElse: () => null,
        );
    final bool initIsCustom = existingType == 'custom' ||
        (existingName.isNotEmpty && matchedPreset == null);
    String selectedComp = initIsCustom
        ? (customTemplate?.name ?? 'Công ty khác (Tự định vị / Văn phòng)')
        : (matchedPreset?.name ??
            (companies.isNotEmpty ? companies.first.name : 'LG Display Hải Phòng'));
    final TextEditingController customCompanyCtrl = TextEditingController(
      text: (initIsCustom &&
              existingName != 'Công ty khác (Tự định vị / Văn phòng)' &&
              existingName != 'Công ty khác')
          ? existingName
          : '',
    );
    String selectedShift = _workplaceProfile?.workShift ?? 'day_12h';
    double? dormLat = _workplaceProfile?.dormLat;
    double? dormLng = _workplaceProfile?.dormLng;
    bool isSaving = false;
    bool isLocatingDorm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          WorkplaceCompany? currentCompany;
          try {
            currentCompany = companies.firstWhere((c) => c.name == selectedComp);
          } catch (_) {
            currentCompany = customTemplate;
          }
          final bool isCustomSelected =
              currentCompany?.id == 'custom' || currentCompany?.workplaceType == 'custom';

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thiết lập Môi trường & Ca làm việc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn công ty để tự động nạp tọa độ GPS và nhận diện lịch làm việc',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceSecondary(context)),
                ),
                const SizedBox(height: 18),
                // Chọn Công ty
                const Text('Công ty thực tập:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final chosen = await _showCompanyPicker(context, selectedComp, companies);
                    if (chosen != null) {
                      setModalState(() {
                        selectedComp = chosen.name;
                        // Tự động gán ca mặc định nếu ca hiện tại không phù hợp với công ty mới
                        if (chosen.availableShifts.isNotEmpty &&
                            !chosen.availableShifts.any((s) => s['id'] == selectedShift)) {
                          selectedShift = chosen.defaultShift;
                        }
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.borderColor(context),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedComp,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentCompany?.address ?? 'Chạm để chọn công ty thực tập',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.onSurfaceSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Đổi',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_right_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isCustomSelected) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customCompanyCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Tên công ty / văn phòng thực tập *',
                      hintText: 'Nhập tên công ty của bạn...',
                      prefixIcon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Chọn Ca làm
                const Text('Lịch ca kíp của bạn:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildShiftChoiceChip('day_12h', '☀️ Ca ngày\n(8h-20h)', selectedShift, (val) => setModalState(() => selectedShift = val)),
                    const SizedBox(width: 8),
                    _buildShiftChoiceChip('night_12h', '🌙 Ca đêm\n(20h-8h)', selectedShift, (val) => setModalState(() => selectedShift = val)),
                    const SizedBox(width: 8),
                    _buildShiftChoiceChip('office_8h', '💼 Hành chính\n(8h-17h)', selectedShift, (val) => setModalState(() => selectedShift = val)),
                  ],
                ),
                const SizedBox(height: 16),
                // Nút gán vị trí phòng trọ
                OutlinedButton.icon(
                  onPressed: (isSaving || isLocatingDorm) ? null : () async {
                    setModalState(() => isLocatingDorm = true);
                    try {
                      // 1. Kiểm tra GPS thiết bị
                      final isGpsOn = await Geolocator.isLocationServiceEnabled();
                      if (!isGpsOn) {
                        if (modalCtx.mounted) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            SnackBar(
                              content: const Text('Định vị GPS đang tắt. Vui lòng bật GPS trên máy!'),
                              action: SnackBarAction(
                                label: 'Bật GPS',
                                onPressed: () => Geolocator.openLocationSettings(),
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      // 2. Kiểm tra & xin quyền định vị
                      LocationPermission perm = await Geolocator.checkPermission();
                      if (perm == LocationPermission.denied) {
                        perm = await Geolocator.requestPermission();
                      }

                      if (perm == LocationPermission.denied) {
                        if (modalCtx.mounted) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            const SnackBar(content: Text('Vui lòng cấp quyền vị trí để ứng dụng lưu tọa độ phòng trọ!')),
                          );
                        }
                        return;
                      }

                      if (perm == LocationPermission.deniedForever) {
                        if (modalCtx.mounted) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            SnackBar(
                              content: const Text('Quyền vị trí đã bị từ chối. Vui lòng mở Cài đặt ứng dụng để cấp quyền!'),
                              action: SnackBarAction(
                                label: 'Cài đặt',
                                onPressed: () => Geolocator.openAppSettings(),
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      // 3. Lấy vị trí GPS
                      Position? pos;
                      try {
                        pos = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                          timeLimit: const Duration(seconds: 8),
                        );
                      } catch (_) {
                        pos = await Geolocator.getLastKnownPosition();
                      }

                      final foundPos = pos;
                      if (foundPos != null) {
                        setModalState(() {
                          dormLat = foundPos.latitude;
                          dormLng = foundPos.longitude;
                        });
                        if (modalCtx.mounted) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            const SnackBar(content: Text('Đã gán vị trí hiện tại làm Phòng trọ/KTX!')),
                          );
                        }
                      } else {
                        if (modalCtx.mounted) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            const SnackBar(content: Text('Không thể lấy tọa độ GPS lúc này. Vui lòng thử lại!')),
                          );
                        }
                      }
                    } catch (e) {
                      if (modalCtx.mounted) {
                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                          SnackBar(content: Text('Lỗi lấy vị trí: $e')),
                        );
                      }
                    } finally {
                      setModalState(() => isLocatingDorm = false);
                    }
                  },
                  icon: isLocatingDorm
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: Text(
                    isLocatingDorm
                        ? 'Đang lấy vị trí GPS...'
                        : (dormLat != null
                            ? '✅ Đã lưu vị trí trọ (${dormLat!.toStringAsFixed(3)}, ${dormLng!.toStringAsFixed(3)})'
                            : '📍 Đặt vị trí này làm Phòng trọ của tôi'),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      final String targetCompanyName = isCustomSelected
                          ? customCompanyCtrl.text.trim()
                          : selectedComp;
                      if (isCustomSelected && targetCompanyName.isEmpty) {
                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập tên công ty thực tập khi chọn Công ty khác!'),
                          ),
                        );
                        return;
                      }
                      final authState = context.read<AuthState>();
                      setModalState(() => isSaving = true);
                      final success = await WorkplaceService.instance.updateProfile(
                        companyId: currentCompany?.id,
                        companyName: targetCompanyName,
                        workplaceType: currentCompany?.workplaceType,
                        workShift: selectedShift,
                        dormLat: dormLat,
                        dormLng: dormLng,
                      );
                      if (!success) {
                        setModalState(() => isSaving = false);
                        if (modalCtx.mounted) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            SnackBar(
                              content: Text(
                                WorkplaceService.instance.lastError ??
                                    'Không thể cập nhật công ty thực tập.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadWorkplaceData();
                      final updatedProf = WorkplaceService.instance.profile;
                      if (updatedProf != null && updatedProf.companyName.isNotEmpty) {
                        await authState.syncWorkplaceCompany(
                          companyId: updatedProf.companyId,
                          companyName: updatedProf.companyName,
                        );
                      }
                      await authState.refreshProfile();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cập nhật hồ sơ thực tập thành công!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildShiftChoiceChip(String id, String label, String currentVal, Function(String) onSelect) {
    final isSelected = id == currentVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.borderColor(context)),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.onSurfaceSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPHQ4Banner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PHQ4ScreenerScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.14),
                AppTheme.accentMint.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon + Badge + Action Chip
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentMint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CHUẨN Y KHOA PHQ-4',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentMint,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Làm bài',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                'Sàng lọc sức khỏe tinh thần',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Text(
                'Khảo sát nhanh 30 giây chuẩn Đại học Columbia & Viện Y tế Quốc gia Hoa Kỳ (NIH)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceSecondary(context),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentAmber.withOpacity(0.15),
            AppTheme.accentCoral.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Fire streak icon with glow
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (_, child) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentAmber.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentAmber.withOpacity(
                      _glowAnimation.value * 0.4,
                    ),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: AppTheme.accentAmber,
                size: 36,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_currentStreak ngày liên tiếp 🔥',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentAmber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kỷ lục: $_longestStreak ngày • Tiếp tục phá vỡ!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hôm nay bạn cảm thấy thế nào?',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: _moods.map((mood) {
            final isSelected = _selectedMood == mood['key'];
            final color = Color(mood['color'] as int);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => setState(() {
                          _selectedMood = mood['key'] as String;
                          _selectedStressFactors.removeWhere(
                            (factor) => !_factorsByMood[_selectedMood]!
                                .contains(factor),
                          );
                        }),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.2)
                          : AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : AppTheme.borderColor(context),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mood['emoji'] as String,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            mood['label'] as String,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? color
                                  : AppTheme.onSurfaceMuted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    )
    .animate()
    .fadeIn(delay: 100.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0);
  }

  Widget _buildStressFactorSelector() {
    final factors = _factorsByMood[_selectedMood]!;
    final moodColor = Color(
      _moods.firstWhere((mood) => mood['key'] == _selectedMood)['color'] as int,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_factorPrompts[_selectedMood]} (tuỳ chọn)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceSecondary(context),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: factors.map((factor) {
            final isSelected = _selectedStressFactors.contains(factor);
            return GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => setState(() {
                      isSelected
                          ? _selectedStressFactors.remove(factor)
                          : _selectedStressFactors.add(factor);
                    }),
              child: AnimatedContainer(
                duration: 150.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? moodColor.withValues(alpha: 0.2)
                      : AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? moodColor
                        : AppTheme.borderColor(context),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  factor,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? moodColor
                        : AppTheme.onSurfaceSecondary(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildGachaWheel() {
    return RepaintBoundary(
      child: Center(
        child: AnimatedBuilder(
          animation: _spinAnimation,
          builder: (_, child) {
            return Transform.rotate(
              angle: _spinAnimation.value * 6.28 * 3, // 3 full rotations
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (_, __) => Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(
                          _glowAnimation.value * 0.5,
                        ),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
              // Wheel body
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppTheme.primary,
                      AppTheme.accentPurple,
                      AppTheme.secondary,
                      AppTheme.accentMint,
                      AppTheme.accentAmber,
                      AppTheme.primary,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Center icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceColor(context),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.accentAmber,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSpinning ? null : _performCheckin,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.stars_rounded, size: 22),
        label: Text(_isLoading ? 'Đang điểm danh...' : 'Quay & Điểm Danh!'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ).animate(delay: 400.ms).scale(curve: Curves.elasticOut),
    );
  }

  Widget _buildGachaReveal() {
    final category = _gachaCategory ?? 'motivation';
    final iconData = _categoryIcons[category] ?? Icons.auto_awesome_rounded;
    final categoryColor = _categoryColors[category] ?? AppTheme.accentAmber;

    return Column(
      children: [
        // Success Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentMint.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentMint.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accentMint,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Đã điểm danh! Streak: $_currentStreak ngày 🔥',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentMint,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.elasticOut),

        const SizedBox(height: 20),

        // Gacha Message Card
        if (_gachaMessage != null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  categoryColor.withOpacity(0.15),
                  AppTheme.surfaceColor(context),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: categoryColor.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Animated icon
                Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: categoryColor.withOpacity(0.2),
                      ),
                      child: Icon(iconData, color: categoryColor, size: 40),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 1500.ms,
                    )
                    .then()
                    .shimmer(color: categoryColor.withOpacity(0.3)),

                const SizedBox(height: 20),

                // Particle decorations
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['✨', '🌟', '💫', '⭐', '✨']
                      .map(
                        (e) => Text(e, style: const TextStyle(fontSize: 16))
                            .animate(
                              delay: Duration(
                                milliseconds: _gachaMessage!.length * 5,
                              ),
                            )
                            .scale(curve: Curves.elasticOut),
                      )
                      .toList(),
                ),

                const SizedBox(height: 16),

                // Message text
                Text(
                  _gachaMessage!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Category label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, color: categoryColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _getCategoryLabel(category),
                        style: TextStyle(
                          fontSize: 12,
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: 200.ms).scale(curve: Curves.elasticOut).fadeIn(),
      ],
    );
  }

  String _getCategoryLabel(String category) {
    const labels = {
      'motivation': 'Động lực',
      'sleep_recovery': 'Giấc ngủ',
      'physical_stretch': 'Thể chất',
      'social_connect': 'Kết nối',
      'mental_peace': 'Bình tâm',
    };
    return labels[category] ?? 'Thông điệp';
  }
}
