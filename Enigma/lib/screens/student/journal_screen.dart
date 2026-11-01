import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../core/api/life_log_repository.dart';
import '../../state/app_state.dart';
import '../../core/onboarding/models/feature_keys.dart';
import '../../core/onboarding/models/onboarding_step.dart';
import '../../core/onboarding/feature_tour_controller.dart';
import '../../core/onboarding/widgets/help_guide_button.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => JournalScreenState();
}

class JournalScreenState extends State<JournalScreen> {
  final GlobalKey _stressKey = GlobalKey();
  final GlobalKey _sleepKey = GlobalKey();
  final GlobalKey _symptomsKey = GlobalKey();
  final GlobalKey _noteKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  double _stressLevel = 3;
  double _sleepHours = 7;
  final TextEditingController _noteController = TextEditingController();
  final List<String> _symptoms = [
    'Đau vai gáy',
    'Mỏi mắt',
    'Khó tập trung',
    'Mất ngủ',
    'Căng thẳng',
    'Đau đầu',
    'Đau lưng',
    'Uể oải',
  ];
  final Set<String> _selectedSymptoms = {};

  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _hasLogToday = false;

  @override
  void initState() {
    super.initState();
    _checkTodayLog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        startTour(force: false);
      }
    });
  }

  void startTour({bool force = false}) {
    final allSteps = [
      OnboardingStep(
        targetKey: _stressKey,
        title: 'Mức Độ Căng Thẳng',
        description: 'Kéo thanh trượt để tự đánh giá mức độ căng thẳng sau ngày làm việc.',
        icon: Icons.psychology_rounded,
      ),
      OnboardingStep(
        targetKey: _sleepKey,
        title: 'Thời Gian Ngủ',
        description: 'Ghi lại số giờ bạn đã ngủ đêm qua để theo dõi khả năng hồi phục.',
        icon: Icons.bedtime_rounded,
      ),
      OnboardingStep(
        targetKey: _symptomsKey,
        title: 'Triệu Chứng Thể Chất',
        description: 'Chọn các biểu hiện mệt mỏi như đau vai gáy, mỏi mắt để nhận khuyến nghị.',
        icon: Icons.healing_rounded,
      ),
      OnboardingStep(
        targetKey: _noteKey,
        title: 'Ghi Chú Tâm Trạng',
        description: 'Viết vài dòng chia sẻ cảm xúc, suy nghĩ hoặc sự kiện đáng nhớ hôm nay.',
        icon: Icons.edit_note_rounded,
      ),
      OnboardingStep(
        targetKey: _saveKey,
        title: 'Lưu Nhật Ký',
        description: 'Nhấn để lưu lại dữ liệu và cập nhật biểu đồ sức khỏe trên Trang chủ.',
        icon: Icons.save_rounded,
      ),
    ];

    final steps = allSteps.where((s) => s.targetKey.currentContext != null).toList();
    if (steps.isEmpty) return;

    FeatureTour.start(
      context,
      featureKey: FeatureKeys.journal,
      force: force,
      steps: steps,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _checkTodayLog() async {
    try {
      final res = await LifeLogRepository.getTodayLifeLog();
      if (mounted) {
        if (res['has_log_today'] == true && res['data'] != null) {
          final data = res['data'] as Map<String, dynamic>;
          setState(() {
            _hasLogToday = true;
            _stressLevel = ((data['stress_level'] as num?)?.toDouble() ?? 3.0).clamp(1.0, 5.0);
            _sleepHours = ((data['sleep_hours'] as num?)?.toDouble() ?? 7.0).clamp(3.0, 12.0);
            _noteController.text = (data['note'] as String?) ?? '';
            final symptoms = (data['physical_symptoms'] as List?)?.cast<String>() ?? [];
            _selectedSymptoms.addAll(symptoms);
            _isInitialLoading = false;
          });
        } else {
          setState(() {
            _isInitialLoading = false;
          });
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

  Future<void> _submitJournal() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await LifeLogRepository.createLifeLog(
        stressLevel: _stressLevel.toInt(),
        sleepHours: _sleepHours,
        physicalSymptoms: _selectedSymptoms.toList(),
        moodNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (!mounted) return;

      // Notify AppState to refresh Home Dashboard and charts immediately
      context.read<AppState>().triggerRefresh();

      setState(() {
        _isLoading = false;
        _hasLogToday = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Đã lưu nhật ký sinh hoạt hôm nay! Điểm: ${result['wellbeing_score'] ?? 100}/100',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentMint,
          duration: const Duration(seconds: 2),
        ),
      );

      // Pop back to home after brief delay to let user see feedback
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu nhật ký: $e'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _stressLevel = 3;
      _sleepHours = 7;
      _selectedSymptoms.clear();
      _noteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật Ký Hôm Nay'),
        actions: [
          HelpGuideButton(
            onTap: () => startTour(force: true),
            tooltip: 'Xem hướng dẫn Nhật ký',
          ),
          if (_hasLogToday)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới / Nhập lại',
              onPressed: _resetForm,
            ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasLogToday)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentMint.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.accentMint.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.accentMint, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bạn đã ghi nhật ký hôm nay. Bạn có thể chỉnh sửa và lưu lại bất cứ lúc nào.',
                              style: TextStyle(fontSize: 12, color: AppTheme.accentMint, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  KeyedSubtree(
                    key: _stressKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mức độ căng thẳng', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppTheme.cardDecorationFor(context),
                          child: Column(
                            children: [
                              Slider(
                                value: _stressLevel,
                                min: 1,
                                max: 5,
                                divisions: 4,
                                activeColor: _getStressColor(_stressLevel),
                                label: _getStressLabel(_stressLevel),
                                onChanged: (val) => setState(() => _stressLevel = val),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Rất thoải mái', style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted(context))),
                                  Text(
                                    _getStressLabel(_stressLevel),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _getStressColor(_stressLevel),
                                    ),
                                  ),
                                  Text('Rất áp lực', style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted(context))),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  KeyedSubtree(
                    key: _sleepKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thời gian ngủ đêm qua', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppTheme.cardDecorationFor(context),
                          child: Column(
                            children: [
                              Text(
                                '${_sleepHours.toStringAsFixed(1)} giờ',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: AppTheme.sleepColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Slider(
                                value: _sleepHours,
                                min: 3,
                                max: 12,
                                divisions: 18,
                                activeColor: AppTheme.sleepColor,
                                onChanged: (val) => setState(() => _sleepHours = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  KeyedSubtree(
                    key: _symptomsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Triệu chứng nổi bật', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _symptoms.map((s) {
                            final isSelected = _selectedSymptoms.contains(s);
                            return FilterChip(
                              label: Text(s),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSymptoms.add(s);
                                  } else {
                                    _selectedSymptoms.remove(s);
                                  }
                                });
                              },
                              selectedColor: AppTheme.primary,
                              checkmarkColor: Colors.white,
                              backgroundColor: AppTheme.surfaceAltColor(context),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.onSurfaceSecondary(context),
                                fontSize: 12,
                              ),
                              side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.borderColor(context)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  KeyedSubtree(
                    key: _noteKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ghi chú thêm', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          maxLines: 4,
                          style: TextStyle(color: AppTheme.onSurface(context), fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Hôm nay bạn cảm thấy thế nào? (VD: Hơi mệt ca đêm, đau lưng...)',
                            hintStyle: TextStyle(color: AppTheme.onSurfaceMuted(context), fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.surfaceAltColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppTheme.borderColor(context)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppTheme.borderColor(context)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  KeyedSubtree(
                    key: _saveKey,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitJournal,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _hasLogToday ? 'Cập Nhật Nhật Ký' : 'Lưu Nhật Ký',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
    );
  }

  Color _getStressColor(double level) {
    if (level <= 2) return AppTheme.accentMint;
    if (level <= 3.5) return AppTheme.accentAmber;
    return AppTheme.accentCoral;
  }

  String _getStressLabel(double level) {
    if (level == 1) return 'Rất thoải mái';
    if (level == 2) return 'Khá ổn';
    if (level == 3) return 'Bình thường';
    if (level == 4) return 'Khá áp lực';
    return 'Rất áp lực';
  }
}
