import 'package:flutter/material.dart';
import '../../models/recovery_task.dart';
import '../../models/wellbeing_score.dart';
import '../../theme/app_theme.dart';
import '../../widgets/task_tile.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/storage.dart';
import '../../core/services/sync_service.dart';
import '../../core/onboarding/models/feature_keys.dart';
import '../../core/onboarding/models/onboarding_step.dart';
import '../../core/onboarding/feature_tour_controller.dart';
import '../../core/onboarding/widgets/help_guide_button.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RecoveryTask> _apiTasks = [];
  bool _isLoading = true;
  PillarType? _selectedPillarFilter;

  final GlobalKey _phaseTabsKey = GlobalKey();
  final GlobalKey _pillarFilterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTasks();
  }

  void startTour({bool force = false}) => _startTour(force: force);

  void _startTour({bool force = false}) {
    FeatureTour.start(
      context,
      featureKey: FeatureKeys.tasks,
      force: force,
      steps: [
        OnboardingStep(
          targetKey: _phaseTabsKey,
          title: 'Nhiệm Vụ Thích Nghi',
          description: 'Hoàn thành các thử thách phục hồi mỗi ngày để rèn luyện thói quen và nhận điểm thưởng.',
          icon: Icons.flag_rounded,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    if (AppConstants.useMockApi) {
      setState(() {
        _apiTasks = RecoveryTask.defaultTasks;
        _isLoading = false;
      });
      return;
    }

    try {
      final res = await ApiClient.instance.get('/tasks');

      if (mounted) {
        final List<dynamic> data = res.data;
        await StorageUtil.saveCachedTasks(data);
        setState(() {
          _apiTasks = data.map((item) => RecoveryTask.fromJson(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback to local cached tasks if available, otherwise default
        final cached = StorageUtil.getCachedTasks();
        if (cached != null && cached.isNotEmpty) {
          setState(() {
            _apiTasks = cached
                .map((item) => RecoveryTask.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _apiTasks = RecoveryTask.defaultTasks;
            _isLoading = false;
          });
        }
      }
    }
  }

  void _toggleTask(RecoveryTask task) async {
    // Optimistic UI update
    setState(() {
      task.isCompleted = !task.isCompleted;
    });

    // Cập nhật lại bộ nhớ cache ngoại tuyến
    await StorageUtil.saveCachedTasks(_apiTasks.map((t) => t.toJson()).toList());

    if (AppConstants.useMockApi) return;

    try {
      await ApiClient.instance.post('/tasks/${task.id}/toggle');
    } catch (e) {
      // Khi mất mạng: KHÔNG rollback UI! Đưa vào hàng đợi sao lưu lên database
      await SyncService.instance.enqueueSync(
        type: 'task_toggle',
        payload: {
          'task_id': task.id,
          'is_completed': task.isCompleted,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Đã cập nhật ngoại tuyến. Sẽ tự động sao lưu khi có mạng.'),
                ),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepTasks = _filterTasks(_apiTasks.where((t) => t.phase == InternPhase.preparation).toList());
    final adaptTasks = _filterTasks(_apiTasks.where((t) => t.phase == InternPhase.adaptation).toList());
    final sustainTasks = _filterTasks(_apiTasks.where((t) => t.phase == InternPhase.sustain).toList());

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, color: AppTheme.primaryLight, size: 22),
            SizedBox(width: 8),
            Text('Nhiệm Vụ Theo Chặng'),
          ],
        ),
        actions: [
          HelpGuideButton(
            onTap: () => _startTour(force: true),
            tooltip: 'Xem hướng dẫn Nhiệm vụ',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadTasks,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: KeyedSubtree(
            key: _phaseTabsKey,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelColor: AppTheme.onSurfaceMuted(context),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: '1. Chuẩn bị', icon: Icon(Icons.backpack_outlined, size: 18)),
                Tab(text: '2. Hòa nhập', icon: Icon(Icons.handshake_outlined, size: 18)),
                Tab(text: '3. Duy trì', icon: Icon(Icons.rocket_launch_outlined, size: 18)),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Pillar Filter Chips
                KeyedSubtree(
                  key: _pillarFilterKey,
                  child: _buildPillarFilterBar(),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPhaseList(prepTasks, 'preparation', 'Giai đoạn trước ngày đi làm: Chuẩn bị hành trang, tâm thế & an toàn 5S.'),
                      _buildPhaseList(adaptTasks, 'adaptation', 'Tháng đầu làm quen: Nhịp ca kíp, giãn cơ vai gáy, mở rộng giao tiếp.'),
                      _buildPhaseList(sustainTasks, 'sustain', 'Tháng 2-3 duy trì: Thể lực bền bỉ, chống kiệt sức và tối ưu hóa năng suất.'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<RecoveryTask> _filterTasks(List<RecoveryTask> tasks) {
    if (_selectedPillarFilter == null) return tasks;
    return tasks.where((t) => t.pillar == _selectedPillarFilter).toList();
  }

  Widget _buildPillarFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Tất cả trụ cột', style: TextStyle(fontSize: 12)),
              selected: _selectedPillarFilter == null,
              onSelected: (_) => setState(() => _selectedPillarFilter = null),
              selectedColor: AppTheme.primary,
              checkmarkColor: Colors.white,
              backgroundColor: AppTheme.surfaceAltColor(context),
              labelStyle: TextStyle(
                color: _selectedPillarFilter == null ? Colors.white : AppTheme.onSurfaceSecondary(context),
                fontSize: 12,
              ),
              side: BorderSide(color: _selectedPillarFilter == null ? AppTheme.primary : AppTheme.borderColor(context)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...PillarType.values.map((pillar) {
            final info = PillarInfo.registry[pillar]!;
            final isSelected = _selectedPillarFilter == pillar;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(info.icon, size: 14, color: isSelected ? Colors.white : info.color),
                label: Text(info.title.split(' ')[0], style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.onSurface(context))),
                selected: isSelected,
                onSelected: (val) => setState(() => _selectedPillarFilter = val ? pillar : null),
                selectedColor: info.color,
                checkmarkColor: Colors.white,
                backgroundColor: AppTheme.surfaceAltColor(context),
                side: BorderSide(color: isSelected ? info.color : AppTheme.borderColor(context)),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPhaseList(List<RecoveryTask> tasks, String phaseKey, String phaseDesc) {
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final progress = tasks.isEmpty ? 0.0 : completedCount / tasks.length;
    final pctText = (progress * 100).toInt();

    return Column(
      children: [
        // Progress header card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: AppTheme.cardDecorationFor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tiến độ hoàn thành', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedCount/${tasks.length} ($pctText%)',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.surfaceAltColor(context),
                  color: AppTheme.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phaseDesc,
                style: TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceMuted(context), height: 1.3),
              ),
            ],
          ),
        ),

        // Task List
        Expanded(
          child: tasks.isEmpty
              ? const Center(child: Text('Không có nhiệm vụ nào trong bộ lọc này.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskTile(
                      key: ValueKey(task.id),
                      task: task,
                      onToggle: () => _toggleTask(task),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
