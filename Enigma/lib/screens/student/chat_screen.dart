import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../../widgets/chat_bubble.dart';
import '../../theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/api/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import '../../core/onboarding/models/feature_keys.dart';
import '../../core/onboarding/models/onboarding_step.dart';
import '../../core/onboarding/feature_tour_controller.dart';
import '../../core/onboarding/widgets/help_guide_button.dart';

class ChatScreen extends StatefulWidget {
  final String? initialContext;

  const ChatScreen({super.key, this.initialContext});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isLoadingSession = false;
  String? _sessionId;
  String? _sessionTitle;
  String? _riskWarning;

  final GlobalKey _quickTopicsKey = GlobalKey();
  final GlobalKey _inputAreaKey = GlobalKey();

  final List<String> _quickTopics = [
    'Quy tắc 5S & An toàn nhà máy',
    'Giảm đau chân giày bảo hộ ESD',
    'Bí quyết ngủ ngon khi đổi ca',
    'Xử lý bất đồng phòng trọ KTX',
    'Hít thở Box Breathing 4-4-4-4',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _addInitialMessage();
    _initSession();
    if (widget.initialContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage('Tôi muốn hỏi về: ${widget.initialContext}');
      });
    }
  }

  void startTour({bool force = false}) => _startTour(force: force);

  /// Prefills the chat input with [text] without auto-sending so the user
  /// can review or edit the question before pressing send.
  void askAbout(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _startTour({bool force = false}) {
    FeatureTour.start(
      context,
      featureKey: FeatureKeys.chat,
      force: force,
      steps: [
        OnboardingStep(
          targetKey: _inputAreaKey,
          title: 'Trợ Lý Thích Nghi AI',
          description: 'Hỏi đáp kỹ thuật an toàn nhà máy, mẹo phục hồi thể lực và tâm sự giải tỏa căng thẳng 24/7.',
          icon: Icons.psychology_rounded,
        ),
      ],
    );
  }

  Future<void> _initSession() async {
    if (AppConstants.useMockApi) return;
    try {
      final res = await ApiClient.instance.post('/chat/sessions', data: {'title': 'Tư vấn Thích nghi & Tâm lý'});
      if (mounted) {
        setState(() {
          _sessionId = res.data['id'];
          _sessionTitle = res.data['title'] ?? 'Tư vấn Thích nghi & Tâm lý';
        });
      }
    } catch (_) {}
  }

  void _resetSession() async {
    setState(() {
      _messages.clear();
      _sessionId = null;
      _sessionTitle = null;
      _riskWarning = null;
      _addInitialMessage();
    });
    await _initSession();
  }

  ChatMessage _buildInitialMessage() {
    return ChatMessage(
      id: 'init_welcome',
      content: 'Chào bạn! Mình là Enigma AI — Trợ lý Đồng hành Tâm lý & Thích nghi Thực tập tại LG Display. 💙\n\nBạn đang gặp khó khăn gì về nhịp ca kíp, sức khỏe đứng máy, quy trình làm việc hay cuộc sống ký túc xá không?',
      isUser: false,
      timestamp: DateTime.now(),
      suggestedReplies: [
        'Đau nhức chân khi mang giày ESD',
        'Mất ngủ sau khi làm ca đêm',
        'Ngại giao tiếp với Trưởng ca',
      ],
    );
  }

  void _addInitialMessage() {
    _messages.add(_buildInitialMessage());
  }

  Future<List<ChatSessionItem>> _fetchChatSessions() async {
    try {
      final res = await ApiClient.instance.get('/chat/sessions');
      if (res.data is List) {
        return (res.data as List).map((j) => ChatSessionItem.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Lỗi tải danh sách phiên trò chuyện: $e');
    }
    return [];
  }

  Future<void> _loadSession(ChatSessionItem session) async {
    setState(() {
      _isLoadingSession = true;
      _sessionId = session.id;
      _sessionTitle = session.title;
      _messages.clear();
      _riskWarning = null;
    });

    try {
      final res = await ApiClient.instance.get('/chat/sessions/${session.id}/messages');
      if (res.data is List) {
        final loaded = (res.data as List).map((m) => ChatMessage.fromJson(m)).toList();
        if (mounted) {
          setState(() {
            _messages.addAll(loaded.isNotEmpty ? loaded : [_buildInitialMessage()]);
            _isLoadingSession = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSession = false;
          _addInitialMessage();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải cuộc trò chuyện: $e')),
        );
      }
    }
  }

  String _formatSessionTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays == 0 && dt.day == now.day) {
      return 'Hôm nay ${DateFormat('HH:mm').format(dt)}';
    }
    if (diff.inDays <= 1 && dt.day == now.day - 1) {
      return 'Hôm qua ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('HH:mm • dd/MM/yyyy').format(dt);
  }

  Future<void> _openChatHistory() async {
    FocusScope.of(context).unfocus();
    List<ChatSessionItem>? sessions;
    bool isLoading = true;
    bool hasInitiatedFetch = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (historyCtx) => StatefulBuilder(
        builder: (ctx, setHistoryState) {
          if (!hasInitiatedFetch) {
            hasInitiatedFetch = true;
            _fetchChatSessions().then((data) {
              if (historyCtx.mounted) {
                setHistoryState(() {
                  sessions = data;
                  isLoading = false;
                });
              }
            }).catchError((_) {
              if (historyCtx.mounted) {
                setHistoryState(() {
                  sessions = [];
                  isLoading = false;
                });
              }
            });
          }

          final list = sessions ?? [];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.78,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
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
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_rounded, color: AppTheme.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Lịch Sử Trò Chuyện',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    // Nút Tạo đoạn chat mới
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(historyCtx);
                        _resetSession();
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'Đoạn chat mới',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Xem lại hoặc tiếp tục các phiên tư vấn đã lưu với Enigma AI',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                // Danh sách phiên
                if (isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (list.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Chưa có lịch sử trò chuyện',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Các cuộc trò chuyện với Enigma AI sẽ được lưu trữ tự động tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.onSurfaceSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final s = list[index];
                        final isActive = s.id == _sessionId;
                        final timeText = _formatSessionTime(s.updatedAt ?? s.createdAt);

                        return Container(
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.borderColor(context),
                              width: isActive ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Khu vực bấm để mở phiên (Tách biệt khỏi nút xóa)
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(historyCtx);
                                    if (!isActive) {
                                      _loadSession(s);
                                    }
                                  },
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? AppTheme.primary
                                                : AppTheme.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.forum_rounded,
                                            color: isActive ? Colors.white : AppTheme.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      s.title,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13.5,
                                                        color: isActive ? AppTheme.primary : null,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isActive) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primary.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'Đang mở',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppTheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.onSurfaceSecondary(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Nút Xóa phiên trò chuyện độc lập
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  color: Colors.red.shade400,
                                  splashRadius: 20,
                                  tooltip: 'Xóa cuộc trò chuyện',
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: historyCtx,
                                      builder: (dlgCtx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('Xóa cuộc trò chuyện?'),
                                        content: Text('Bạn có chắc chắn muốn xóa phiên trò chuyện "${s.title}" không? Dữ liệu trò chuyện sẽ không thể khôi phục.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dlgCtx, false),
                                            child: const Text('Hủy'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.accentCoral,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => Navigator.pop(dlgCtx, true),
                                            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      try {
                                        await ApiClient.instance.delete('/chat/sessions/${s.id}');
                                        if (historyCtx.mounted) {
                                          setHistoryState(() {
                                            sessions?.removeWhere((item) => item.id == s.id);
                                          });
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Đã xóa phiên trò chuyện "${s.title}"'),
                                              behavior: SnackBarBehavior.floating,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          if (s.id == _sessionId) {
                                            if (historyCtx.mounted) Navigator.pop(historyCtx);
                                            _resetSession();
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Không thể xóa: $e'),
                                              backgroundColor: Colors.red.shade700,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Tắt bàn phím sau khi gửi xong
    FocusScope.of(context).unfocus();

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    if (AppConstants.useMockApi || _sessionId == null) {
      // Giả lập streaming cho chế độ mock
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final mockWords = 'Cảm ơn bạn đã chia sẻ! Enigma khuyên bạn nên kết hợp kỹ thuật hít thở Box Breathing 4-4-4-4 và ngâm chân nước ấm sau ca làm để phục hồi năng lượng nhé.'.split(' ');

      final mockAi = ChatMessage(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        suggestedReplies: ['Bài tập giãn cơ vai gáy', 'Kinh nghiệm đổi ca'],
      );

      setState(() {
        _messages.add(mockAi);
        _isTyping = false;
      });

      for (final word in mockWords) {
        await Future.delayed(const Duration(milliseconds: 40));
        if (!mounted) return;
        setState(() {
          mockAi.content += '$word ';
        });
        _scrollToBottom();
      }
      return;
    }

    // Call FastAPI RAG API Endpoint (Hỗ trợ cả Streaming và Fallback với hiệu ứng gõ chữ mượt mà)
    try {
      final res = await ApiClient.instance.post(
        '/chat/sessions/$_sessionId/messages',
        data: {
          'content': text,
          'stress_level': 2,
          'sleep_hours': null,
          'recent_symptoms': [],
        },
      );

      if (!mounted) return;

      if (_sessionTitle == null ||
          _sessionTitle == 'Tư vấn Thích nghi & Tâm lý' ||
          _sessionTitle == 'Tư vấn Enigma AI') {
        setState(() {
          _sessionTitle = text.length > 35 ? '${text.substring(0, 35)}...' : text;
        });
      }

      final aiData = res.data['ai_message'];
      final fullContent = (aiData['content'] as String? ?? '').trim();
      final rawSources = res.data['rag_sources'] as List?;
      final riskAssessment = res.data['risk_assessment'] as Map<String, dynamic>?;

      List<RAGSource>? sources;
      if (rawSources != null && rawSources.isNotEmpty) {
        sources = rawSources.map((s) => RAGSource.fromJson(s)).toList();
      }

      if (riskAssessment != null && riskAssessment['level'] == 'RED') {
        setState(() {
          _riskWarning =
              'Cảnh báo: Phát hiện mức độ căng thẳng cao. Hãy liên hệ Y tế công ty hoặc Hotline 111 để được hỗ trợ.';
        });
      }

      // Tạo bubble rỗng và stream từng từ (Typewriter Animation) tức thì
      final aiMsg = ChatMessage(
        id: aiData['id']?.toString() ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        ragSources: sources,
      );

      setState(() {
        _messages.add(aiMsg);
        _isTyping = false;
      });

      // Hiệu ứng hiện từng từ nhanh chóng (18ms mỗi từ) tạo trải nghiệm AI Agent thực thụ
      final words = fullContent.split(' ');
      for (int i = 0; i < words.length; i++) {
        if (!mounted) return;
        setState(() {
          aiMsg.content += (i == 0 ? '' : ' ') + words[i];
        });
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: 18));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errDetail = 'Vui lòng kiểm tra lại kết nối mạng.';
      if (e.response?.data is Map) {
        errDetail = e.response?.data['detail']?.toString() ?? errDetail;
      } else if (e.response?.data is String) {
        errDetail = e.response?.data as String;
      }
      final errorMsg = ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Chưa thể kết nối tới máy chủ AI: $errDetail',
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMsg);
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _handleFeedback(ChatMessage msg, int feedback) async {
    setState(() {
      msg.feedback = feedback;
    });

    try {
      await ApiClient.instance.post(
        '/chat/messages/${msg.id}/feedback',
        data: {'feedback': feedback},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedback == 1 ? 'Cảm ơn bạn đã khen ngợi!' : 'Cảm ơn bạn đã góp ý để Enigma hoàn thiện hơn!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_rounded, color: AppTheme.primaryLight, size: 22),
                  SizedBox(width: 8),
                  Text('Trợ Lý Thích Nghi AI', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                ],
              ),
              if (_sessionTitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  _sessionTitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          actions: [
            if (isKeyboardOpen)
              IconButton(
                icon: const Icon(Icons.keyboard_hide_rounded),
                tooltip: 'Thu gọn bàn phím',
                onPressed: () => FocusScope.of(context).unfocus(),
              ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Lịch sử trò chuyện',
              onPressed: _openChatHistory,
            ),
            IconButton(
              icon: const Icon(Icons.add_comment_rounded),
              tooltip: 'Đoạn chat mới',
              onPressed: _resetSession,
            ),
            HelpGuideButton(
              onTap: () => _startTour(force: true),
              tooltip: 'Xem hướng dẫn Trợ lý AI',
            ),
          ],
        ),
        body: Column(
          children: [
            // Emergency / High Risk Banner
            if (_riskWarning != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.redAccent.withOpacity(0.15),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _riskWarning!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onPressed: () => setState(() => _riskWarning = null),
                    ),
                  ],
                ),
              ),
            ],

            // Quick Topic Chips Bar
            KeyedSubtree(
              key: _quickTopicsKey,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: _quickTopics.map((topic) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        label: Text(topic, style: TextStyle(fontSize: 12, color: AppTheme.onSurface(context))),
                        onPressed: () => _sendMessage(topic),
                        backgroundColor: AppTheme.surfaceAltColor(context),
                        side: BorderSide(color: AppTheme.borderColor(context)),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Messages List or Loading State
            if (_isLoadingSession)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 12),
                      Text(
                        'Đang tải cuộc trò chuyện...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return ChatBubble(
                      message: ChatMessage(
                        id: 'typing',
                        content: '',
                        isUser: false,
                        timestamp: DateTime.now(),
                        isLoading: true,
                      ),
                    ).animate().fade();
                  }

                  final msg = _messages[index];
                  return ChatBubble(
                    key: ValueKey(msg.id),
                    message: msg,
                    onSuggestionTap: _sendMessage,
                    onFeedbackTap: (fb) => _handleFeedback(msg, fb),
                  );
                },
              ),
            ),

            // Input Area
            KeyedSubtree(
              key: _inputAreaKey,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(color: AppTheme.onSurface(context), fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Nhập câu hỏi hoặc tâm sự khó khăn...',
                            hintStyle: TextStyle(color: AppTheme.onSurfaceMuted(context), fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.surfaceAltColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            suffixIcon: isKeyboardOpen
                                ? IconButton(
                                    icon: const Icon(Icons.keyboard_hide_rounded, size: 20),
                                    tooltip: 'Ẩn bàn phím',
                                    color: AppTheme.onSurfaceMuted(context),
                                    onPressed: () => FocusScope.of(context).unfocus(),
                                  )
                                : null,
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: () => _sendMessage(_controller.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
