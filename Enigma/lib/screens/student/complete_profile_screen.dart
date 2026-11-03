import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/services/workplace_service.dart';
import '../../core/utils/storage.dart';
import '../../models/catalog_item.dart';
import '../../navigation/student_nav.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';

class CompleteProfileScreen extends StatefulWidget {
  final bool isFromAuth;

  const CompleteProfileScreen({
    super.key,
    this.isFromAuth = false,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  CatalogItem? _selectedUniversity;
  String? _otherUniversityName;

  CatalogItem? _selectedCompany;
  String? _otherCompanyName;

  bool _isSaving = false;

  bool get _hasUniversity =>
      _selectedUniversity != null ||
      (_otherUniversityName != null && _otherUniversityName!.trim().isNotEmpty);

  bool get _hasCompany =>
      _selectedCompany != null ||
      (_otherCompanyName != null && _otherCompanyName!.trim().isNotEmpty);

  bool get _canSave => _hasUniversity || _hasCompany;

  Future<void> _handleSkip() async {
    await StorageUtil.setCompleteProfileSkipped(true);
    if (!mounted) return;

    if (widget.isFromAuth) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StudentNav()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSave() async {
    if (!_canSave || _isSaving) return;

    // Validate lengths if 'Khác' was entered
    if (_otherUniversityName != null && _otherUniversityName!.trim().isNotEmpty) {
      final len = _otherUniversityName!.trim().length;
      if (len < 2 || len > 255) {
        _showErrorSnackBar('Tên trường nhập tự do phải có độ dài từ 2 đến 255 ký tự.');
        return;
      }
    }

    if (_otherCompanyName != null && _otherCompanyName!.trim().isNotEmpty) {
      final len = _otherCompanyName!.trim().length;
      if (len < 2 || len > 255) {
        _showErrorSnackBar('Tên nơi thực tập nhập tự do phải có độ dài từ 2 đến 255 ký tự.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await ApiClient.updateCatalogProfile(
        universityId: _selectedUniversity?.id,
        otherUniversityName: _selectedUniversity == null ? _otherUniversityName?.trim() : null,
        companyId: _selectedCompany?.id,
        otherCompanyName: _selectedCompany == null ? _otherCompanyName?.trim() : null,
      );

      final uniData = response['university'] as Map<String, dynamic>?;
      final compData = response['company'] as Map<String, dynamic>?;

      final bool uniPending = uniData?['is_pending'] == true;
      final bool compPending = compData?['is_pending'] == true;
      final bool hasPending = uniPending || compPending;

      if (!mounted) return;

      // Reset skipped flag since user filled profile
      await StorageUtil.setCompleteProfileSkipped(false);

      if (!mounted) return;

      // Refresh current user in AuthState & WorkplaceService
      await Future.wait([
        context.read<AuthState>().refreshProfile(),
        WorkplaceService.instance.fetchProfile(),
      ]);

      if (!mounted) return;

      if (hasPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đã lưu thông tin! Đơn vị đề xuất của bạn đã gửi, quản trị viên sẽ duyệt.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cập nhật thông tin thành công!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (widget.isFromAuth) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentNav()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      String message;
      final statusCode = e.response?.statusCode;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        message = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      } else if (statusCode == 400 &&
          e.response?.data is Map &&
          e.response?.data['detail'] != null) {
        final detail = e.response?.data['detail'];
        message = detail is List ? detail.map((d) => d['msg']).join('\n') : detail.toString();
      } else if (statusCode != null && (statusCode == 404 || statusCode >= 500)) {
        message = 'Chưa lưu được. Vui lòng thử lại sau.';
      } else {
        message = 'Không kết nối được máy chủ. Vui lòng thử lại.';
      }
      _showErrorSnackBar(message);
    } catch (_) {
      _showErrorSnackBar('Không kết nối được máy chủ. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.accentCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openPicker({required bool isUniversity}) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogPickerSheet(
        isUniversity: isUniversity,
        initialSelectedItem: isUniversity ? _selectedUniversity : _selectedCompany,
        initialOtherName: isUniversity ? _otherUniversityName : _otherCompanyName,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isUniversity) {
          if (result.isOther) {
            _selectedUniversity = null;
            _otherUniversityName = result.otherName;
          } else {
            _selectedUniversity = result.catalogItem;
            _otherUniversityName = null;
          }
        } else {
          if (result.isOther) {
            _selectedCompany = null;
            _otherCompanyName = result.otherName;
          } else {
            _selectedCompany = result.catalogItem;
            _otherCompanyName = null;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppTheme.surfaceColor(context);
    final borderColor = AppTheme.borderColor(context);

    return PopScope(
      canPop: !widget.isFromAuth,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSkip();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Hoàn thiện hồ sơ',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _handleSkip,
              child: const Text(
                'Để sau',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.primaryLight,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card with gentle mental health welcome
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.accentMint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accentMint.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.accentMint.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: Color(0xFF2E7D32),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Chào mừng bạn đến với Enigma',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Chọn trường và nơi thực tập để quản trị viên hỗ trợ bạn phù hợp hơn. Bạn có thể bỏ qua.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppTheme.onSurfaceSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Title
                      Text(
                        'Thông tin đào tạo & thực tập',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurfaceSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 1. Trường Đại học Picker Card
                      _buildPickerCard(
                        title: 'Trường Đại học',
                        subtitle: 'Chọn trường của bạn hoặc thêm trường mới',
                        icon: Icons.school_rounded,
                        selectedValue: _selectedUniversity != null
                            ? _selectedUniversity!.displayName
                            : (_otherUniversityName != null ? 'Trường khác: $_otherUniversityName' : null),
                        isPending: _otherUniversityName != null,
                        onTap: () => _openPicker(isUniversity: true),
                        onClear: () {
                          setState(() {
                            _selectedUniversity = null;
                            _otherUniversityName = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Nơi thực tập Picker Card
                      _buildPickerCard(
                        title: 'Công ty / Nơi thực tập',
                        subtitle: 'Doanh nghiệp, nhà máy bạn đang thực tập',
                        icon: Icons.business_rounded,
                        selectedValue: _selectedCompany != null
                            ? _selectedCompany!.displayName
                            : (_otherCompanyName != null ? 'Nơi khác: $_otherCompanyName' : null),
                        isPending: _otherCompanyName != null,
                        onTap: () => _openPicker(isUniversity: false),
                        onClear: () {
                          setState(() {
                            _selectedCompany = null;
                            _otherCompanyName = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Gentle Note
                      Center(
                        child: Text(
                          'Bạn có thể bỏ qua và bổ sung bất kỳ lúc nào tại Trang chủ.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _handleSkip,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Để sau',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceSecondary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        onPressed: (_canSave && !_isSaving) ? _handleSave : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: _canSave ? 2 : 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Lưu thông tin',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? selectedValue,
    required bool isPending,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final surfaceColor = AppTheme.surfaceColor(context);
    final borderColor = AppTheme.borderColor(context);
    final isSelected = selectedValue != null && selectedValue.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.6) : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : AppTheme.accentSky.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (isSelected) ...[
                    Text(
                      selectedValue,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.hourglass_top_rounded, size: 12, color: AppTheme.accentAmber),
                          SizedBox(width: 4),
                          Text(
                            'Đề xuất mới (đang chờ duyệt)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentAmber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.onSurfaceMuted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              IconButton(
                onPressed: onClear,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppTheme.onSurfaceMuted(context),
                ),
                tooltip: 'Xóa lựa chọn',
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceMuted(context),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Searchable Catalog Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PickerResult {
  final bool isOther;
  final CatalogItem? catalogItem;
  final String? otherName;

  _PickerResult.catalog(this.catalogItem)
      : isOther = false,
        otherName = null;

  _PickerResult.other(this.otherName)
      : isOther = true,
        catalogItem = null;
}

class _CatalogPickerSheet extends StatefulWidget {
  final bool isUniversity;
  final CatalogItem? initialSelectedItem;
  final String? initialOtherName;

  const _CatalogPickerSheet({
    required this.isUniversity,
    this.initialSelectedItem,
    this.initialOtherName,
  });

  @override
  State<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<_CatalogPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();

  List<CatalogItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  bool _isTypingOther = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOtherName != null && widget.initialOtherName!.isNotEmpty) {
      _customNameController.text = widget.initialOtherName!;
      _isTypingOther = true;
    }
    _loadItems('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadItems(query.trim());
    });
  }

  String _mapCatalogFetchError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Không kết nối được máy chủ. Vui lòng thử lại.';
      }
      final statusCode = error.response?.statusCode;
      if (statusCode != null && (statusCode == 404 || statusCode >= 500)) {
        return "Hiện chưa tải được danh sách. Bạn có thể chọn 'Khác' hoặc bấm 'Để sau'.";
      }
    } else if (error is TimeoutException) {
      return 'Không kết nối được máy chủ. Vui lòng thử lại.';
    }
    return "Hiện chưa tải được danh sách. Bạn có thể chọn 'Khác' hoặc bấm 'Để sau'.";
  }

  Future<void> _loadItems(String q) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<CatalogItem> results;
      if (widget.isUniversity) {
        results = await ApiClient.searchUniversities(q);
      } else {
        results = await ApiClient.searchCompanies(q);
      }

      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapCatalogFetchError(e);
        });
      }
    }
  }

  void _submitCustomName() {
    final text = _customNameController.text.trim();
    if (text.length < 2 || text.length > 255) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên từ 2 đến 255 ký tự.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_PickerResult.other(text));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isUniversity ? 'Chọn trường đại học' : 'Chọn nơi thực tập';
    final otherLabel = widget.isUniversity
        ? 'Trường khác (chưa có trong danh sách)'
        : 'Công ty khác (chưa có trong danh sách)';
    final surfaceColor = AppTheme.surfaceColor(context);
    final borderColor = AppTheme.borderColor(context);

    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final availableHeight = (screenHeight - keyboardHeight).clamp(240.0, screenHeight);
    final sheetHeight = (availableHeight * 0.95).clamp(240.0, screenHeight * 0.85);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onSurfaceMuted(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.isUniversity
                      ? 'Tìm theo tên trường, viết tắt (VD: Bách Khoa)...'
                      : 'Tìm tên công ty, nhà máy...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _loadItems('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceColor(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Content List
            Expanded(
              child: _buildBody(otherLabel, borderColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String otherLabel, Color borderColor) {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
          _buildOtherItem(otherLabel),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentCoral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentCoral.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppTheme.accentCoral, size: 36),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurface(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Đóng'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _loadItems(_searchController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
          _buildOtherItem(otherLabel),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                _searchController.text.trim().isEmpty
                    ? 'Không có dữ liệu.'
                    : 'Không tìm thấy kết quả phù hợp.',
                style: TextStyle(
                  color: AppTheme.onSurfaceMuted(context),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
          _buildOtherItem(otherLabel),
        ],
      );
    }

    return ListView.separated(
      itemCount: _items.length + 1, // +1 for the last item "Khác"
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: borderColor.withValues(alpha: 0.5),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (ctx, index) {
        // The last item is always "Khác"
        if (index == _items.length) {
          return _buildOtherItem(otherLabel);
        }

        final item = _items[index];
        final isSelected = widget.initialSelectedItem?.id == item.id;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : AppTheme.borderColor(context).withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isUniversity ? Icons.account_balance_rounded : Icons.domain_rounded,
              size: 18,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceSecondary(context),
            ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppTheme.primary : AppTheme.onSurface(context),
            ),
          ),
          subtitle: (item.shortName != null || item.city != null)
              ? Text(
                  [item.shortName, item.city].where((s) => s != null && s.isNotEmpty).join(' • '),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted(context),
                  ),
                )
              : null,
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
              : null,
          onTap: () {
            Navigator.of(context).pop(_PickerResult.catalog(item));
          },
        );
      },
    );
  }

  Widget _buildOtherItem(String otherLabel) {
    final borderColor = AppTheme.borderColor(context);

    if (_isTypingOther) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.isUniversity ? 'Nhập tên trường của bạn' : 'Nhập tên nơi thực tập',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customNameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.isUniversity
                    ? 'Ví dụ: Đại học Bách Khoa TP.HCM'
                    : 'Ví dụ: Công ty TNHH Phần mềm ABC',
                filled: true,
                fillColor: AppTheme.surfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isTypingOther = false;
                      _customNameController.clear();
                    });
                  },
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitCustomName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.accentAmber.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add_circle_outline_rounded,
          size: 20,
          color: AppTheme.accentAmber,
        ),
      ),
      title: Text(
        otherLabel,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.accentAmber,
        ),
      ),
      subtitle: const Text(
        'Tự gõ tên nếu không tìm thấy trong danh sách trên',
        style: TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: () {
        setState(() {
          _isTypingOther = true;
        });
      },
    );
  }
}
