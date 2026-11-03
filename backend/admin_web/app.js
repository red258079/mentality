/**
 * ==============================================================================
 * ENIGMA ADMIN PORTAL — JAVASCRIPT APPLICATION CORE
 * ==============================================================================
 * Hệ sinh thái Quản trị Sức khỏe & Thích nghi Thực tập sinh Enigma
 * - Quản lý sinh viên & chỉ số 5 trụ cột
 * - Trung tâm phát hiện & can thiệp nguy cơ kiệt sức (Burnout Alert)
 * - Quản lý cẩm nang RAG AI & Nhiệm vụ 3 giai đoạn
 * - Tự động kết nối Live FastAPI (8000) hoặc chế độ Demo Data mượt mà
 */

(function () {
  'use strict';

  // URL Máy chủ Render Cloud Production của ứng dụng Enigma
  const RENDER_CLOUD_URL = 'https://mentality-38jh.onrender.com';

  function getInitialApiUrl() {
    // Tự động nhận diện thông minh 100%:
    // - Khi mở trên http://localhost:8000/admin-web/ -> Tự gọi http://localhost:8000
    // - Khi mở trên https://mentality-38jh.onrender.com/admin-web/ -> Tự gọi https://mentality-38jh.onrender.com
    if (window.location.origin && window.location.origin !== 'null' && !window.location.origin.startsWith('file:')) {
      return window.location.origin;
    }
    const saved = localStorage.getItem('enigma_api_url');
    if (saved) return saved;
    return RENDER_CLOUD_URL;
  }

  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // ─── Application State ────────────────────────────────────────────────────────
  const STATE = {
    apiBaseUrl: getInitialApiUrl(),
    adminToken: localStorage.getItem('enigma_admin_token') || null,
    isDemoMode: false,
    activeTab: 'dashboard',
    activeTaskPhase: 'preparation',
    
    // Data Caches
    stats: null,
    students: [],
    alerts: [],
    articles: [],
    tasks: [],
    notifications: [],
    feed: [],
    pendingCatalog: [],
    approvedUniversities: [],
    approvedCompanies: [],
    studentPillFilter: 'all',
    studentsViewMode: localStorage.getItem('enigma_students_view_mode') || 'grouped',
    selectedUniversity: '',
    selectedCompany: '',
    collapsedUniGroups: new Set(),
    allGroupsCollapsed: false,

    // Chart instances
    charts: {
      pillars: null,
      stress: null,
      trend: null,
    }
  };

  // ─── DOM References ───────────────────────────────────────────────────────────
  const DOM = {
    // Navigation
    navItems: document.querySelectorAll('.nav-item'),
    tabPanes: document.querySelectorAll('.tab-pane'),
    pageTitle: document.getElementById('page-title'),
    pageSubtitle: document.getElementById('page-subtitle'),
    connectionPill: document.getElementById('connection-pill'),
    statusIndicator: document.getElementById('status-indicator'),
    statusLabel: document.getElementById('status-label'),
    toggleDataModeBtn: document.getElementById('toggle-data-mode-btn'),
    btnRefresh: document.getElementById('btn-refresh'),
    btnQuickBroadcast: document.getElementById('btn-quick-broadcast'),
    mobileMenuBtn: document.getElementById('mobile-menu-btn'),
    sidebarToggleBtn: document.getElementById('sidebar-toggle'),
    sidebar: document.getElementById('sidebar'),

    // Badges
    navBadgeStudents: document.getElementById('nav-badge-students'),
    navBadgeAlerts: document.getElementById('nav-badge-alerts'),
    navBadgeArticles: document.getElementById('nav-badge-articles'),
    quickAlertCount: document.getElementById('quick-alert-count'),

    // KPI Values
    kpiTotalStudents: document.getElementById('kpi-total-students'),
    kpiCheckinsToday: document.getElementById('kpi-checkins-today'),
    kpiCheckinRate: document.getElementById('kpi-checkin-rate'),
    kpiBurnoutRisk: document.getElementById('kpi-burnout-risk'),
    kpiCompletedTasks: document.getElementById('kpi-completed-tasks'),

    // Dashboard Lists
    dashboardFeedList: document.getElementById('dashboard-feed-list'),
    dashboardWatchlist: document.getElementById('dashboard-watchlist'),

    // Students Directory & University Groups
    studentsSearchInput: document.getElementById('students-search-input'),
    studentsFilterUniversity: document.getElementById('students-filter-university'),
    studentsFilterCompany: document.getElementById('students-filter-company'),
    studentsFilterPhase: document.getElementById('students-filter-phase'),
    studentsFilterRisk: document.getElementById('students-filter-risk'),
    studentsTbody: document.getElementById('students-tbody'),
    studentsFlatWrapper: document.getElementById('students-flat-wrapper'),
    studentsGroupedContainer: document.getElementById('students-grouped-container'),
    universityChipsBar: document.getElementById('university-chips-bar'),
    viewModeGroupedBtn: document.getElementById('view-mode-grouped'),
    viewModeFlatBtn: document.getElementById('view-mode-flat'),
    btnToggleAllGroups: document.getElementById('btn-toggle-all-groups'),
    btnToggleAllText: document.getElementById('btn-toggle-all-text'),
    btnExportStudents: document.getElementById('btn-export-students'),

    // Burnout Alert Center
    burnoutCardsContainer: document.getElementById('burnout-cards-container'),
    navBadgeCrisis: document.getElementById('nav-badge-crisis'),
    crisisFlagsTbody: document.getElementById('crisis-flags-tbody'),

    // Handbook
    handbookSearchInput: document.getElementById('handbook-search-input'),
    handbookFilterCategory: document.getElementById('handbook-filter-category'),
    handbookFilterStatus: document.getElementById('handbook-filter-status'),
    handbookArticlesContainer: document.getElementById('handbook-articles-container'),
    btnCreateArticle: document.getElementById('btn-create-article'),

    // Tasks
    taskPhaseSwitcher: document.getElementById('task-phase-switcher'),
    tasksTbody: document.getElementById('tasks-tbody'),
    btnCreateTask: document.getElementById('btn-create-task'),

    // Broadcast
    broadcastForm: document.getElementById('broadcast-form'),
    notificationHistoryList: document.getElementById('notification-history-list'),

    // Pending Catalog Review
    navBadgePending: document.getElementById('nav-badge-pending'),
    pendingSearchInput: document.getElementById('pending-search-input'),
    pendingFilterType: document.getElementById('pending-filter-type'),
    btnRefreshPending: document.getElementById('btn-refresh-pending'),
    pendingTbody: document.getElementById('pending-tbody'),

    // Settings & Account
    settingApiUrl: document.getElementById('setting-api-url'),
    settingAdminAccount: document.getElementById('setting-admin-account'),
    btnSaveSettings: document.getElementById('btn-save-settings'),
    btnTestConnection: document.getElementById('btn-test-connection'),
    btnExportJson: document.getElementById('btn-export-json'),
    btnClearCache: document.getElementById('btn-clear-cache'),
    btnAdminLogout: document.getElementById('btn-admin-logout'),
    btnSettingsLogout: document.getElementById('btn-settings-logout'),

    // Login Screen
    loginScreen: document.getElementById('login-screen'),
    appContainer: document.getElementById('app-container'),
    loginForm: document.getElementById('admin-login-form'),
    loginEmail: document.getElementById('admin-login-email'),
    loginPassword: document.getElementById('admin-login-password'),
    loginError: document.getElementById('admin-login-error'),
    btnLoginSubmit: document.getElementById('btn-admin-login-submit'),

    // Modals
    userModal: document.getElementById('user-modal'),
    articleModal: document.getElementById('article-modal'),
    articleForm: document.getElementById('article-form'),
    taskModal: document.getElementById('task-modal'),
    taskForm: document.getElementById('task-form'),
    interventionModal: document.getElementById('intervention-modal'),
    interventionForm: document.getElementById('intervention-form'),

    // Student Filter Controls
    studentsPillButtons: document.querySelectorAll('.filter-pills-bar .pill-btn'),
    studentsStatCards: document.querySelectorAll('.students-stat-strip .stat-mini-card'),

    // Toast
    toastContainer: document.getElementById('toast-container'),
  };

  // ─── Toast System ─────────────────────────────────────────────────────────────
  function showToast(message, type = 'info', duration = 3500) {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    let iconSvg = '';
    if (type === 'success') {
      iconSvg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>';
    } else if (type === 'error') {
      iconSvg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#f43f5e" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>';
    } else {
      iconSvg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';
    }

    toast.innerHTML = `${iconSvg}<span></span>`;
    const msgSpan = toast.querySelector('span');
    if (msgSpan) {
      msgSpan.textContent = message;
    }
    DOM.toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(100%)';
      setTimeout(() => toast.remove(), 300);
    }, duration);
  }

  // ─── Tab Title Dictionary ─────────────────────────────────────────────────────
  const TAB_TITLES = {
    dashboard: {
      title: 'Tổng Quan Dashboard',
      subtitle: 'Theo dõi trạng thái 5 trụ cột sức khỏe và rủi ro kiệt sức của thực tập sinh',
    },
    students: {
      title: 'Quản Lý Sinh Viên Thực Tập',
      subtitle: 'Danh bạ sinh viên, phân loại theo doanh nghiệp, giai đoạn và chỉ số sức khỏe',
    },
    pending: {
      title: 'Duyệt Đơn Vị Đề Xuất (Chờ Duyệt)',
      subtitle: 'Xem xét phê duyệt, gộp vào đơn vị chuẩn hóa hoặc từ chối các trường và công ty do sinh viên đề xuất',
    },
    crisis: {
      title: 'Trung Tâm Cảnh Báo Khủng Hoảng (AI Chat)',
      subtitle: 'Theo dõi các trường hợp bộc lộ nguy cơ tự hại trong AI Chat và cập nhật tiến độ xử lý an toàn',
    },
    burnout: {
      title: 'Trung Tâm Cảnh Báo Kiệt Sức',
      subtitle: 'Sàng lọc nguy cơ stress cao, thiếu ngủ ca đêm và đưa ra can thiệp kịp thời',
    },
    handbook: {
      title: 'Cẩm Nang Thực Tập & Huấn Luyện AI RAG',
      subtitle: 'Kho tri thức kinh nghiệm cựu sinh viên, phân loại 5 trụ cột và vector hóa',
    },
    tasks: {
      title: 'Nhiệm Vụ Thích Nghi 3 Giai Đoạn',
      subtitle: 'Lộ trình phát triển: Chuẩn bị ➔ Hòa nhập doanh nghiệp ➔ Duy trì & Bứt phá',
    },
    notifications: {
      title: 'Trung Tâm Phát Loa & Thông Báo',
      subtitle: 'Gửi lời nhắc nhở sinh hoạt, Gacha quotes và thông báo khẩn tới ứng dụng sinh viên',
    },
    settings: {
      title: 'Cấu Hình Hệ Thống & Kết Nối API',
      subtitle: 'Cài đặt máy chủ Backend, mã token quản trị và xuất dữ liệu báo cáo',
    },
  };

  // ─── Tab Switching ────────────────────────────────────────────────────────────
  function switchTab(tabName) {
    if (!TAB_TITLES[tabName]) return;
    STATE.activeTab = tabName;

    DOM.navItems.forEach(item => {
      item.classList.toggle('active', item.dataset.tab === tabName);
    });

    DOM.tabPanes.forEach(pane => {
      pane.classList.toggle('active', pane.id === `pane-${tabName}`);
    });

    DOM.pageTitle.textContent = TAB_TITLES[tabName].title;
    DOM.pageSubtitle.textContent = TAB_TITLES[tabName].subtitle;

    // Render tab content on switch if needed
    if (tabName === 'dashboard') {
      renderDashboardCharts();
    } else if (tabName === 'students') {
      renderStudentsTable();
    } else if (tabName === 'crisis') {
      renderCrisisFlagsTable();
    } else if (tabName === 'burnout') {
      renderBurnoutCards();
    } else if (tabName === 'handbook') {
      renderHandbookArticles();
    } else if (tabName === 'tasks') {
      renderTasksTable();
    } else if (tabName === 'notifications') {
      renderNotificationHistory();
    } else if (tabName === 'pending') {
      loadPendingCatalog();
    }

    // Close mobile sidebar
    DOM.sidebar.classList.remove('mobile-open');
  }

  // ─── Rich Mock / Demo Data Generator ──────────────────────────────────────────
  function getMockData() {
    const mockStudents = [
      {
        id: "sv-bdu-01",
        student_id: "23050067",
        full_name: "Khang Duy",
        email: "duyvsh1234@gmail.com",
        university: "Đại Học Bình Dương",
        major: "Công nghệ thông tin (CNTT)",
        company_name: "LG Display Hải Phòng",
        department: "Kỹ thuật Phần mềm & Test",
        work_shift: "day_12h",
        current_phase: "preparation",
        current_streak: 5,
        latest_stress_level: 5,
        latest_sleep_hours: 6.0,
        is_high_risk: true,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 65, physical: 70, mental: 50, social: 75, career: 85 },
        created_at: "2026-10-09T13:50:28Z"
      },
      {
        id: "sv-bdu-02",
        student_id: "23050010",
        full_name: "Châu Gia Bảo",
        email: "23050010@student.bdu.edu.vn",
        university: "Đại Học Bình Dương",
        major: "Công nghệ thông tin (CNTT)",
        company_name: "LG Display Hải Phòng",
        department: "Phòng Tự động hóa Dây chuyền",
        work_shift: "night_12h",
        current_phase: "adaptation",
        current_streak: 12,
        latest_stress_level: 2,
        latest_sleep_hours: 7.2,
        is_high_risk: false,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 80, physical: 75, mental: 80, social: 70, career: 85 },
        created_at: "2026-10-12T14:32:09Z"
      },
      {
        id: "sv-101",
        student_id: "B21DCCN045",
        full_name: "Nguyễn Minh Khang",
        email: "khang.nm@ptit.edu.vn",
        university: "Học viện CNBCVT",
        major: "Công nghệ thông tin",
        company_name: "LG Display Hải Phòng",
        department: "Kỹ thuật Module Màn hình",
        current_phase: "adaptation",
        current_streak: 14,
        latest_stress_level: 2,
        latest_sleep_hours: 7.5,
        is_high_risk: false,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 75, physical: 80, mental: 70, social: 85, career: 90 },
        created_at: "2026-09-01T08:00:00Z"
      },
      {
        id: "sv-102",
        student_id: "B21DCCN189",
        full_name: "Trần Thị Thùy Linh",
        email: "linh.ttt@hust.edu.vn",
        university: "ĐH Bách Khoa Hà Nội",
        major: "Kỹ thuật Điện tử",
        company_name: "LG Display Hải Phòng",
        department: "Chất lượng sản phẩm (QA)",
        current_phase: "adaptation",
        current_streak: 8,
        latest_stress_level: 5,
        latest_sleep_hours: 4.2,
        is_high_risk: true,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 50, physical: 60, mental: 45, social: 65, career: 70 },
        created_at: "2026-09-05T09:30:00Z"
      },
      {
        id: "sv-103",
        student_id: "B21DCCN312",
        full_name: "Lê Hoàng Long",
        email: "long.lh@utc.edu.vn",
        university: "ĐH Giao Thông Vận Tải",
        major: "Kỹ thuật Cơ điện tử",
        company_name: "LG Display Hải Phòng",
        department: "Bảo trì Thiết bị ESD",
        current_phase: "preparation",
        current_streak: 21,
        latest_stress_level: 1,
        latest_sleep_hours: 8.0,
        is_high_risk: false,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 85, physical: 85, mental: 80, social: 75, career: 80 },
        created_at: "2026-09-10T10:15:00Z"
      },
      {
        id: "sv-104",
        student_id: "B21DCCN408",
        full_name: "Phạm Quốc Tuấn",
        email: "tuan.pq@hust.edu.vn",
        university: "ĐH Bách Khoa Hà Nội",
        major: "Tự động hóa",
        company_name: "LG Display Hải Phòng",
        department: "Dây chuyền Cleanroom ca đêm",
        current_phase: "adaptation",
        current_streak: 4,
        latest_stress_level: 4,
        latest_sleep_hours: 4.8,
        is_high_risk: true,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 55, physical: 65, mental: 50, social: 60, career: 75 },
        created_at: "2026-09-12T14:20:00Z"
      },
      {
        id: "sv-105",
        student_id: "B21DCCN512",
        full_name: "Hoàng Thảo My",
        email: "my.ht@neu.edu.vn",
        university: "ĐH Kinh Tế Quốc Dân",
        major: "Quản trị Nhân lực",
        company_name: "LG Display Hải Phòng",
        department: "Phòng Nhân sự Thực tập sinh",
        current_phase: "sustain",
        current_streak: 30,
        latest_stress_level: 2,
        latest_sleep_hours: 7.0,
        is_high_risk: false,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 70, physical: 75, mental: 75, social: 90, career: 85 },
        created_at: "2026-08-20T11:00:00Z"
      },
      {
        id: "sv-106",
        student_id: "B21DCCN620",
        full_name: "Đặng Quang Huy",
        email: "huy.dq@phenikaa.edu.vn",
        university: "ĐH Phenikaa",
        major: "Kỹ thuật Điều khiển",
        company_name: "LG Display Hải Phòng",
        department: "Vận hành máy tự động",
        current_phase: "adaptation",
        current_streak: 2,
        latest_stress_level: 4,
        latest_sleep_hours: 5.2,
        is_high_risk: true,
        is_active: true,
        role: "student",
        initial_scores: { sleep: 60, physical: 60, mental: 55, social: 70, career: 70 },
        created_at: "2026-09-18T16:45:00Z"
      }
    ];

    const mockAlerts = [
      {
        journal_id: "j-001",
        user_id: "sv-102",
        full_name: "Trần Thị Thùy Linh",
        student_id: "B21DCCN189",
        email: "linh.ttt@hust.edu.vn",
        company_name: "LG Display Hải Phòng",
        department: "Chất lượng sản phẩm (QA)",
        current_phase: "adaptation",
        journal_date: new Date().toISOString().split('T')[0],
        stress_level: 5,
        sleep_hours: 4.2,
        physical_symptoms: ["Đau đầu", "Chóng mặt", "Mỏi mắt phòng sạch"],
        note: "Hôm qua ca đêm đổi ca đột ngột, tiếng ồn ký túc xá khiến mình không ngủ được, vào ca hoa mắt suýt làm rơi mẫu kính.",
        ai_sentiment: "very_negative",
        risk_level: "critical",
        intervention_recommended: "Cần cố vấn tâm lý gọi điện can thiệp và hỗ trợ chuyển phòng ký túc xá yên tĩnh."
      },
      {
        journal_id: "j-002",
        user_id: "sv-104",
        full_name: "Phạm Quốc Tuấn",
        student_id: "B21DCCN408",
        email: "tuan.pq@hust.edu.vn",
        company_name: "LG Display Hải Phòng",
        department: "Dây chuyền Cleanroom ca đêm",
        current_phase: "adaptation",
        journal_date: new Date().toISOString().split('T')[0],
        stress_level: 4,
        sleep_hours: 4.8,
        physical_symptoms: ["Đau khớp cổ chân", "Căng cơ vai gáy"],
        note: "Đứng giày chống tĩnh điện ESD 12 tiếng liên tục gan bàn chân sưng tấy, không biết có chịu nổi hết tuần không.",
        ai_sentiment: "negative",
        risk_level: "warning",
        intervention_recommended: "Gợi ý cẩm nang lót giày y tế silicon và bài tập ngâm chân nước ấm giảm phù nề."
      },
      {
        journal_id: "j-003",
        user_id: "sv-106",
        full_name: "Đặng Quang Huy",
        student_id: "B21DCCN620",
        email: "huy.dq@phenikaa.edu.vn",
        company_name: "LG Display Hải Phòng",
        department: "Vận hành máy tự động",
        current_phase: "adaptation",
        journal_date: new Date(Date.now() - 86400000).toISOString().split('T')[0],
        stress_level: 4,
        sleep_hours: 5.2,
        physical_symptoms: ["Mất ngủ", "Lo âu đánh giá"],
        note: "Tuần sau có bài kiểm tra thao tác máy 5S của Line Leader, lo lắng không vượt qua kỳ thực tập.",
        ai_sentiment: "negative",
        risk_level: "warning",
        intervention_recommended: "Kết nối với Mentor cựu sinh viên cùng trường để được hướng dẫn mẹo thi 5S."
      }
    ];

    const mockArticles = [
      {
        id: "art-1",
        title: "Quy tắc 5S và An toàn lao động tại nhà máy LG Display",
        summary: "Hướng dẫn thực hành 5S và bảo hộ lao động ESD trong ca làm việc nhà máy.",
        content: "Quy tắc 5S bao gồm: Sàng lọc (Seiri), Sắp xếp (Seiton), Sạch sẽ (Seiso), Săn sóc (Seiketsu), Sẵn sàng (Shitsuke). Tuân thủ nghiêm ngặt đồ bảo hộ chống tĩnh điện và báo ngay cho Line Leader khi máy gặp sự cố.",
        category: "career",
        author_name: "Ban Cố vấn Thực tập",
        status: "published",
        helpful_count: 38,
        view_count: 142,
        tags: ["5s", "an-toan", "lg-display"],
        created_at: "2026-09-01T08:00:00Z"
      },
      {
        id: "art-2",
        title: "Bí quyết cân bằng nhịp sinh học và giấc ngủ khi đổi ca đêm",
        summary: "Kinh nghiệm ngủ sâu sau ca đêm và giảm thiểu kiệt sức nhịp sinh học.",
        content: "Khi tan ca sáng 8h trở về phòng, hãy đeo kính râm tránh ánh nắng mặt trời làm giảm tiết Melatonin. Dùng rèm cản sáng 100%, nhiệt độ phòng 22-24 độ C và ngâm chân nước ấm 15 phút.",
        category: "sleep",
        author_name: "Ban Cố vấn Tâm lý",
        status: "published",
        helpful_count: 45,
        view_count: 210,
        tags: ["giac-ngu", "ca-dem", "phuc-hoi"],
        created_at: "2026-09-03T10:00:00Z"
      },
      {
        id: "art-3",
        title: "Kỹ thuật Hít thở Box Breathing 4-4-4-4 hạ căng thẳng tức thì",
        summary: "Phương pháp hạ nhịp tim và ổn định tâm trí trong 3 phút khi bị quá tải áp lực.",
        content: "Hít vào 4 giây -> Nín thở 4 giây -> Thở ra nhẹ nhàng 4 giây -> Giữ nín thở 4 giây. Thực hiện 4 chu kỳ giúp kích hoạt hệ thần kinh đối giao cảm, lập tức lấy lại bình tĩnh.",
        category: "mental",
        author_name: "ThS. Tâm lý học Ứng dụng",
        status: "published",
        helpful_count: 52,
        view_count: 280,
        tags: ["hit-tho", "box-breathing", "giam-stress"],
        created_at: "2026-09-05T09:00:00Z"
      },
      {
        id: "art-4",
        title: "Mẹo giảm đau chân khi mang giày bảo hộ ESD đứng ca 12 tiếng",
        summary: "Bí kíp từ các anh chị khóa trước: lót giày silicon y tế và nâng cao chân khi ngủ.",
        content: "Mua sẵn 2 đôi miếng lót giày silicon có đệm vòm bàn chân. Sau khi tan ca, dùng dầu xoa bóp vuốt ngược bắp chân và kê cao chân trên gối 20cm khi ngủ để máu hồi lưu về tim.",
        category: "physical",
        author_name: "CLB Cựu Thực tập sinh",
        status: "published",
        helpful_count: 67,
        view_count: 315,
        tags: ["giay-esd", "dau-chan", "the-chat"],
        created_at: "2026-09-08T14:00:00Z"
      },
      {
        id: "art-5",
        title: "Quy ước sinh hoạt phòng ký túc xá lệch ca làm việc",
        summary: "Thống nhất giờ giấc và nguyên tắc tôn trọng lẫn nhau khi người làm ca ngày, người làm ca đêm.",
        content: "Thỏa thuận rõ nguyên tắc đóng cửa nhẹ tay, dùng tai nghe, không bật đèn trần phòng ngủ khi có bạn đang ngủ bù ca đêm. Chuẩn bị sẵn bịt tai chống ồn và bịt mắt 3D.",
        category: "social",
        author_name: "Ban Quản lý KTX",
        status: "published",
        helpful_count: 29,
        view_count: 175,
        tags: ["ktx", "phong-tro", "giao-tiep"],
        created_at: "2026-09-12T16:00:00Z"
      }
    ];

    const mockTasks = [
      {
        id: "tsk-1",
        title: "Tìm hiểu bản đồ nhà máy và nội quy phòng sạch ESD",
        description: "Ghi nhớ các cổng an ninh, vị trí tủ đồ locker, phòng thay đồ bảo hộ vô trùng và tuyến xe bus đưa đón.",
        phase: "preparation",
        pillar: "career",
        duration_minutes: 20,
        unlock_day: 1,
        is_active: true,
        completed_count: 118
      },
      {
        id: "tsk-2",
        title: "Chuẩn bị bộ vật dụng thích nghi giấc ngủ ca đêm",
        description: "Chuẩn bị rèm cản sáng, bịt tai chống ồn, kính râm và bình giữ nhiệt 1 lít.",
        phase: "preparation",
        pillar: "sleep",
        duration_minutes: 30,
        unlock_day: 2,
        is_active: true,
        completed_count: 95
      },
      {
        id: "tsk-3",
        title: "Làm quen với Line Leader và bạn cùng ca làm việc",
        description: "Chủ động chào hỏi, lưu số điện thoại khẩn cấp của Trưởng ca và Cố vấn trường.",
        phase: "adaptation",
        pillar: "social",
        duration_minutes: 15,
        unlock_day: 5,
        is_active: true,
        completed_count: 82
      },
      {
        id: "tsk-4",
        title: "Thực hành giãn cơ 3 phút sau giờ ăn trưa",
        description: "Thực hiện chuỗi bài tập xoay cổ tay, giãn cơ thắt lưng và bắp chân chống co rút.",
        phase: "adaptation",
        pillar: "physical",
        duration_minutes: 5,
        unlock_day: 7,
        is_active: true,
        completed_count: 76
      },
      {
        id: "tsk-5",
        title: "Tổng kết bài học kinh nghiệm tuần đầu vào sổ tay",
        description: "Viết ra 3 điều làm tốt và 2 lỗi sai thao tác cần cải thiện cho tuần tiếp theo.",
        phase: "sustain",
        pillar: "career",
        duration_minutes: 25,
        unlock_day: 14,
        is_active: true,
        completed_count: 54
      }
    ];

    const mockNotifications = [
      {
        id: "notif-1",
        title: "Nhắc nhở nạp năng lượng sau ca đêm",
        body: "Các bạn vừa hoàn thành ca đêm hãy uống một cốc nước ấm, ăn nhẹ và nghỉ ngơi trong phòng tối nhé!",
        type: "system",
        sent_at: "2026-10-13T07:30:00Z"
      },
      {
        id: "notif-2",
        title: "Cẩm nang mới: Giảm đau chân khi mang giày ESD",
        body: "Đã có bài viết hướng dẫn chi tiết cách chọn lót giày và massage chân từ cựu sinh viên trong mục Cẩm nang.",
        type: "new_article",
        sent_at: "2026-10-12T18:00:00Z"
      },
      {
        id: "notif-3",
        title: "Duy trì chuỗi Streak điểm danh tuần này",
        body: "Chúc mừng các bạn đã duy trì chuỗi 7 ngày liên tiếp! Hãy tiếp tục nhận Gacha quote mỗi sáng.",
        type: "streak_warning",
        sent_at: "2026-10-11T08:15:00Z"
      }
    ];

    return {
      stats: {
        total_users: 125,
        total_students: 120,
        today_checkins: 88,
        checkin_rate: 73.3,
        total_articles: mockArticles.length,
        total_tasks: mockTasks.length,
        total_completed_tasks: 425,
        burnout_risk_count: 3,
        low_sleep_count: 7,
        intern_phases: {
          preparation: 35,
          adaptation: 62,
          sustain: 23
        },
        pillar_averages: {
          sleep: 68.5,
          physical: 71.2,
          mental: 64.0,
          social: 76.4,
          career: 82.1
        }
      },
      students: mockStudents,
      alerts: mockAlerts,
      articles: mockArticles,
      tasks: mockTasks,
      notifications: mockNotifications
    };
  }

  // ─── Auth & Screen Control Helpers ────────────────────────────────────────────
  function showLoginScreen(errorMessage = '') {
    if (DOM.loginScreen) DOM.loginScreen.style.display = 'flex';
    if (DOM.appContainer) DOM.appContainer.style.display = 'none';
    if (DOM.loginError) {
      if (errorMessage) {
        DOM.loginError.textContent = errorMessage;
        DOM.loginError.style.display = 'block';
      } else {
        DOM.loginError.textContent = '';
        DOM.loginError.style.display = 'none';
      }
    }
    if (DOM.loginPassword) DOM.loginPassword.value = '';
  }

  function hideLoginScreen() {
    if (DOM.loginScreen) DOM.loginScreen.style.display = 'none';
    if (DOM.appContainer) DOM.appContainer.style.display = 'flex';
    if (DOM.loginError) DOM.loginError.style.display = 'none';
  }

  function updateAdminProfileUI() {
    try {
      const userStr = localStorage.getItem('enigma_admin_user');
      if (userStr) {
        const user = JSON.parse(userStr);
        const displayName = user.full_name || user.email || 'Quản Trị Viên';
        const elName = document.getElementById('admin-display-name');
        const elAvatar = document.getElementById('admin-avatar');
        if (elName) elName.textContent = displayName;
        if (elAvatar) elAvatar.textContent = (user.full_name ? user.full_name.charAt(0) : 'A').toUpperCase();
        if (DOM.settingAdminAccount) DOM.settingAdminAccount.value = `${displayName} (${user.email || ''})`;
      }
    } catch (e) {
      console.warn('Không thể đọc thông tin admin_user:', e);
    }
  }

  function logoutAdmin() {
    localStorage.removeItem('enigma_admin_token');
    localStorage.removeItem('enigma_admin_user');
    STATE.adminToken = null;
    showToast('Đã đăng xuất tài khoản quản trị.', 'info');
    showLoginScreen();
  }

  // ─── API Fetcher with Automatic Bearer Header & 401 Interception ───────────────
  async function apiFetch(endpoint, options = {}) {
    if (!STATE.adminToken) {
      showLoginScreen('Vui lòng đăng nhập bằng tài khoản quản trị để tiếp tục.');
      return null;
    }

    const url = `${STATE.apiBaseUrl}${endpoint}`;
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${STATE.adminToken}`,
      ...(options.headers || {})
    };

    try {
      const response = await fetch(url, { ...options, headers });
      if (!response.ok) {
        if (response.status === 401) {
          console.warn(`[AUTH] 401 Unauthorized khi gọi ${endpoint}. Chuyển về màn hình đăng nhập.`);
          localStorage.removeItem('enigma_admin_token');
          localStorage.removeItem('enigma_admin_user');
          STATE.adminToken = null;
          showLoginScreen('Phiên làm việc đã hết hạn hoặc không có quyền quản trị (401). Vui lòng đăng nhập lại.');
          return null;
        }
        let errDetail = `HTTP ${response.status}: ${response.statusText}`;
        try {
          const errBody = await response.json();
          if (errBody && errBody.detail) errDetail = errBody.detail;
        } catch (_) {}
        const error = new Error(errDetail);
        error.status = response.status;
        throw error;
      }
      return await response.json();
    } catch (err) {
      console.warn(`[API] Gọi thất bại tới ${endpoint}:`, err.message);
      if (options.method && options.method !== 'GET') {
        showToast(err.message, 'error');
      }
      return null;
    }
  }

  // ─── Initial Data Loader ──────────────────────────────────────────────────────
  async function loadAllData() {
    // 1. Thử kết nối API live
    const liveStats = await apiFetch('/admin/stats');
    
    if (liveStats) {
      // Backend đang chạy tốt!
      STATE.isDemoMode = false;
      DOM.statusIndicator.className = 'status-indicator live';
      const isRender = STATE.apiBaseUrl.includes('onrender.com');
      DOM.statusLabel.textContent = isRender ? 'Render Cloud (Live)' : `Live API (${new URL(STATE.apiBaseUrl).host})`;
      DOM.toggleDataModeBtn.textContent = 'Đổi sang Demo';
      STATE.stats = liveStats;

      // Fetch live collections
      const [students, alerts, articles, tasks, notifications, feed] = await Promise.all([
        apiFetch('/admin/users'),
        apiFetch('/admin/burnout-alerts'),
        apiFetch('/admin/handbook'),
        apiFetch('/admin/tasks'),
        apiFetch('/admin/notifications/history'),
        apiFetch('/admin/feed')
      ]);

      await loadPendingCatalog();

      STATE.students = students || [];
      STATE.alerts = alerts || [];
      STATE.articles = articles || [];
      STATE.tasks = tasks || [];
      STATE.notifications = notifications || [];
      STATE.feed = feed || [];
      showToast('Đã đồng bộ dữ liệu từ máy chủ Enigma Backend!', 'success');
    } else {
      // Tự động chuyển sang chế độ Demo Data phong phú
      STATE.isDemoMode = true;
      DOM.statusIndicator.className = 'status-indicator demo';
      DOM.statusLabel.textContent = 'Chế Độ Demo Data (Mượt mà)';
      DOM.toggleDataModeBtn.textContent = 'Thử Kết Nối Live';

      const mock = getMockData();
      STATE.stats = mock.stats;
      STATE.students = mock.students;
      STATE.alerts = mock.alerts;
      STATE.articles = mock.articles;
      STATE.tasks = mock.tasks;
      STATE.notifications = mock.notifications;
      STATE.feed = [];
      showToast('Đang hiển thị chế độ Dữ liệu Demo trực quan!', 'info');
    }

    // Cập nhật UI
    updateBadges();
    renderKPIs();
    renderDashboardLists();
    renderDashboardCharts();
    renderStudentsTable();
    renderBurnoutCards();
    renderHandbookArticles();
    renderTasksTable();
    renderNotificationHistory();
  }

  // ─── Render Badges & KPIs ─────────────────────────────────────────────────────
  function updateBadges() {
    const alertCount = (STATE.alerts || []).length;
    DOM.navBadgeStudents.textContent = STATE.students.length || '--';
    DOM.navBadgeAlerts.textContent = alertCount || '0';
    DOM.navBadgeArticles.textContent = STATE.articles.length || '--';
    DOM.quickAlertCount.textContent = `${alertCount} Ca Cảnh Báo`;
  }

  function renderKPIs() {
    const s = STATE.stats;
    if (!s) return;

    DOM.kpiTotalStudents.textContent = s.total_students || s.total_users || 0;
    DOM.kpiCheckinsToday.textContent = s.today_checkins || 0;
    DOM.kpiCheckinRate.textContent = `${s.checkin_rate || 0}% tỷ lệ`;
    DOM.kpiBurnoutRisk.textContent = s.burnout_risk_count || 0;
    DOM.kpiCompletedTasks.textContent = s.total_completed_tasks || 0;
  }

  // ─── Render Dashboard Feed & Watchlist ────────────────────────────────────────
  function renderDashboardLists() {
    // 1. Feed hoạt động & Gacha Quote thực tế từ database
    const feedItems = (STATE.feed && STATE.feed.length > 0)
      ? STATE.feed
      : [
          { user: "Nguyễn Minh Khang (B21DCCN045)", quote: "Vượt qua thử thách hôm nay sẽ là niềm tự hào của ngày mai.", time: "10 phút trước" },
          { user: "Trần Thị Thùy Linh (B21DCCN189)", quote: "Hít thở sâu 4 giây và thả lỏng bắp cơ vai gáy.", time: "25 phút trước" },
          { user: "Lê Hoàng Long (B21DCCN312)", quote: "An toàn lao động và 5S là nguyên tắc số một.", time: "42 phút trước" },
          { user: "Phạm Quốc Tuấn (B21DCCN408)", quote: "Uống đủ nước để duy trì sự tỉnh táo trong ca dài.", time: "1 giờ trước" }
        ];

    DOM.dashboardFeedList.innerHTML = feedItems.map(item => {
      const userText = escapeHtml(item.user || `${item.full_name || 'Sinh viên'} (${item.student_id || 'SV'})`);
      const initial = (item.full_name || item.user || 'S').charAt(0);
      const quoteText = escapeHtml(item.quote || 'Chúc bạn ca làm việc an toàn và năng lượng!');
      
      let timeText = item.time || '';
      if (!timeText && item.created_at) {
        try {
          const d = new Date(item.created_at);
          timeText = d.toLocaleDateString('vi-VN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });
        } catch (_) {
          timeText = item.checkin_date || 'Gần đây';
        }
      } else if (!timeText) {
        timeText = item.checkin_date || 'Hôm nay';
      }

      const catBadge = item.category 
        ? `<span class="badge badge-subtle text-xs" style="margin-left:6px">${escapeHtml(item.category)}</span>` 
        : '';

      return `
        <div class="feed-item">
          <div class="avatar">${escapeHtml(initial)}</div>
          <div class="feed-content">
            <div class="feed-user">
              <span>${userText} ${catBadge}</span>
              <span class="feed-time">${escapeHtml(timeText)}</span>
            </div>
            <p class="feed-quote">"${quoteText}"</p>
          </div>
        </div>
      `;
    }).join('');

    // 2. Watchlist kiệt sức
    const alertList = STATE.alerts || [];
    if (alertList.length === 0) {
      DOM.dashboardWatchlist.innerHTML = `<p class="text-subtle text-center py-4">Hiện không có sinh viên nào trong vùng nguy cơ cao.</p>`;
    } else {
      DOM.dashboardWatchlist.innerHTML = alertList.slice(0, 3).map(a => `
        <div class="watchlist-item">
          <div class="watchlist-info">
            <h4>${escapeHtml(a.full_name || 'Chưa có tên')} (${escapeHtml(a.student_id || 'Chưa có MSSV')})</h4>
            <p>${escapeHtml(a.company_name || 'Chưa có')} — Mức Stress: <strong class="text-danger">${a.stress_level}/5</strong> | Ngủ: ${a.sleep_hours !== null && a.sleep_hours !== undefined ? `${a.sleep_hours}h` : 'Chưa có dữ liệu giấc ngủ'}</p>
          </div>
          <button class="btn btn-sm btn-danger-outline" onclick="window.EnigmaApp.openIntervention('${escapeHtml(a.user_id)}')">Can Thiệp</button>
        </div>
      `).join('');
    }
  }

  // ─── Render Charts with Chart.js ──────────────────────────────────────────────
  function renderDashboardCharts() {
    const s = STATE.stats || {
      pillar_averages: { sleep: 68, physical: 72, mental: 62, social: 76, career: 82 }
    };

    // 1. Radar Chart: 5 Trụ Cột Sức Khỏe
    const ctxPillars = document.getElementById('chart-pillars');
    if (ctxPillars) {
      if (STATE.charts.pillars) STATE.charts.pillars.destroy();

      STATE.charts.pillars = new Chart(ctxPillars, {
        type: 'radar',
        data: {
          labels: ['Giấc Ngủ (Sleep)', 'Thể Chất (Physical)', 'Tâm Lý (Mental)', 'Xã Hội (Social)', 'Sự Nghiệp (Career)'],
          datasets: [{
            label: 'Điểm Trung Bình Khóa Sinh Viên',
            data: [
              s.pillar_averages.sleep,
              s.pillar_averages.physical,
              s.pillar_averages.mental,
              s.pillar_averages.social,
              s.pillar_averages.career
            ],
            backgroundColor: 'rgba(99, 102, 241, 0.25)',
            borderColor: '#6366f1',
            borderWidth: 2,
            pointBackgroundColor: '#06b6d4',
            pointBorderColor: '#fff',
            pointHoverBackgroundColor: '#fff',
            pointHoverBorderColor: '#06b6d4',
            pointRadius: 4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            r: {
              min: 0,
              max: 100,
              ticks: { stepSize: 20, color: '#64748b', backdropColor: 'transparent' },
              grid: { color: 'rgba(51, 65, 85, 0.4)' },
              angleLines: { color: 'rgba(51, 65, 85, 0.5)' },
              pointLabels: {
                color: '#cbd5e1',
                font: { size: 11, family: 'Plus Jakarta Sans', weight: '600' }
              }
            }
          },
          plugins: {
            legend: { display: false }
          }
        }
      });
    }

    // 2. Bar Chart: Phân bổ mức độ Stress
    const ctxStress = document.getElementById('chart-stress');
    if (ctxStress) {
      if (STATE.charts.stress) STATE.charts.stress.destroy();

      STATE.charts.stress = new Chart(ctxStress, {
        type: 'bar',
        data: {
          labels: ['1: Bình thản', '2: Nhẹ nhàng', '3: Trung bình', '4: Căng thẳng', '5: Rất căng thẳng'],
          datasets: [{
            label: 'Số lượng sinh viên',
            data: [28, 45, 32, 12, 3],
            backgroundColor: [
              '#10b981',
              '#34d399',
              '#f59e0b',
              '#f97316',
              '#f43f5e'
            ],
            borderRadius: 6
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            x: {
              grid: { display: false },
              ticks: { color: '#94a3b8', font: { size: 11 } }
            },
            y: {
              grid: { color: 'rgba(51, 65, 85, 0.3)' },
              ticks: { color: '#94a3b8', font: { size: 11 } }
            }
          },
          plugins: {
            legend: { display: false }
          }
        }
      });
    }

    // 3. Line Chart: Xu hướng 7 ngày
    const ctxTrend = document.getElementById('chart-trend');
    if (ctxTrend) {
      if (STATE.charts.trend) STATE.charts.trend.destroy();

      STATE.charts.trend = new Chart(ctxTrend, {
        type: 'line',
        data: {
          labels: ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ Nhật'],
          datasets: [
            {
              label: 'Số lượt điểm danh',
              data: [82, 85, 78, 92, 89, 70, 88],
              borderColor: '#06b6d4',
              backgroundColor: 'rgba(6, 182, 212, 0.1)',
              fill: true,
              tension: 0.35,
              yAxisID: 'y'
            },
            {
              label: 'Giờ ngủ TB (h)',
              data: [6.8, 6.9, 6.5, 7.1, 6.7, 7.4, 7.2],
              borderColor: '#10b981',
              backgroundColor: 'transparent',
              borderDash: [5, 5],
              tension: 0.35,
              yAxisID: 'y1'
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { mode: 'index', intersect: false },
          scales: {
            x: {
              grid: { color: 'rgba(51, 65, 85, 0.2)' },
              ticks: { color: '#94a3b8' }
            },
            y: {
              type: 'linear',
              display: true,
              position: 'left',
              grid: { color: 'rgba(51, 65, 85, 0.3)' },
              ticks: { color: '#06b6d4' }
            },
            y1: {
              type: 'linear',
              display: true,
              position: 'right',
              grid: { drawOnChartArea: false },
              ticks: { color: '#10b981' },
              min: 4,
              max: 9
            }
          },
          plugins: {
            legend: { display: false }
          }
        }
      });
    }
  }

  // ─── University Normalization Helper ──────────────────────────────────────────
  function getStudentUniLabel(s) {
    if (s.university_name && s.university_name.trim() && s.university_name.trim() !== 'Chưa phân loại') {
      return s.university_name.trim();
    }
    return 'Chưa phân loại';
  }

  // ─── Render University Quick Chips ───────────────────────────────────────────
  function renderUniversityChips() {
    if (!DOM.universityChipsBar) return;

    const countsMap = new Map();
    let totalAll = 0;
    STATE.students.forEach(s => {
      totalAll++;
      const uniLabel = getStudentUniLabel(s);
      const groupKey = uniLabel;
      if (!countsMap.has(groupKey)) {
        countsMap.set(groupKey, {
          key: groupKey,
          label: uniLabel,
          count: 0,
          companies: new Set()
        });
      }
      const entry = countsMap.get(groupKey);
      entry.count++;
      if (s.company_id && s.company_name) {
        entry.companies.add(s.company_name);
      }
    });

    let chipsHtml = `
      <button type="button" class="uni-chip ${STATE.selectedUniversity === '' ? 'active' : ''}" data-uni-key="">
        <span>Tất Cả Các Trường</span>
        <span class="chip-count">${totalAll}</span>
      </button>
    `;

    countsMap.forEach(item => {
      const isActive = STATE.selectedUniversity === item.label;
      const compLabel = item.companies.size > 0 ? [...item.companies].join(', ') : 'Chưa chọn nơi thực tập';
      chipsHtml += `
        <button type="button" class="uni-chip ${isActive ? 'active' : ''}" data-uni-key="${escapeHtml(item.label)}">
          <span>🏛️ ${escapeHtml(item.label)}</span>
          <small class="text-muted" style="margin-left: 2px;">(${escapeHtml(compLabel)})</small>
          <span class="chip-count">${item.count}</span>
        </button>
      `;
    });

    DOM.universityChipsBar.innerHTML = chipsHtml;

    DOM.universityChipsBar.querySelectorAll('.uni-chip').forEach(btn => {
      btn.addEventListener('click', () => {
        const uniKey = btn.getAttribute('data-uni-key') || '';
        window.EnigmaApp.selectUniPill(uniKey);
      });
    });
  }

  // ─── Update University & Company Dropdowns ────────────────────────────────────
  function updateUniversityDropdowns() {
    if (!DOM.studentsFilterUniversity || !DOM.studentsFilterCompany) return;

    const universities = [...new Set(STATE.students.map(s => getStudentUniLabel(s)))].sort();
    const companies = [...new Set(STATE.students.map(s => (s.company_id && s.company_name) ? s.company_name : 'Chưa chọn nơi thực tập'))].sort();

    const currentUni = DOM.studentsFilterUniversity.value;
    const currentComp = DOM.studentsFilterCompany.value;

    DOM.studentsFilterUniversity.innerHTML = '<option value="">Tất cả các trường</option>' +
      universities.map(u => `<option value="${escapeHtml(u)}" ${u === currentUni ? 'selected' : ''}>${escapeHtml(u)}</option>`).join('');

    DOM.studentsFilterCompany.innerHTML = '<option value="">Tất cả công ty thực tập</option>' +
      companies.map(c => `<option value="${escapeHtml(c)}" ${c === currentComp ? 'selected' : ''}>${escapeHtml(c)}</option>`).join('');
  }

  // ─── Render Single Student Row ────────────────────────────────────────────────
  function renderStudentRow(s, phaseNames) {
    let stressDisplay = '<span class="text-subtle">—</span>';
    if (s.latest_stress_level !== null && s.latest_stress_level !== undefined) {
      const lvl = s.latest_stress_level;
      const cls = lvl >= 4 ? 'stress-badge-danger' : (lvl === 3 ? 'stress-badge-warning' : 'stress-badge-success');
      stressDisplay = `<span class="status-chip ${cls}"><span class="chip-dot"></span>Mức ${lvl}/5</span>`;
    }

    const phaseDisplay = s.current_phase
      ? (phaseNames[s.current_phase] || `<span class="status-chip">${escapeHtml(s.current_phase)}</span>`)
      : '<span class="text-subtle">—</span>';

    const shiftPill = s.work_shift === 'night_12h' 
      ? '<span class="shift-badge shift-night">🌙 Ca đêm (20h-8h)</span>' 
      : (s.work_shift === 'office_8h' 
        ? '<span class="shift-badge shift-office">💼 Hành chính</span>' 
        : (s.work_shift === 'day_12h' 
          ? '<span class="shift-badge shift-day">☀️ Ca ngày (8h-20h)</span>' 
          : ''));

    let sleepDisplay = '<span class="text-subtle">—</span>';
    if (s.latest_sleep_hours !== null && s.latest_sleep_hours !== undefined) {
      if (s.latest_sleep_hours < 5) {
        sleepDisplay = `<span class="status-chip sleep-danger" title="Ngủ dưới 5h/ngày">⚠️ ${s.latest_sleep_hours}h</span>`;
      } else {
        sleepDisplay = `<span class="sleep-val">${s.latest_sleep_hours}h</span>`;
      }
    }

    const streakCount = s.current_streak || 0;
    const streakDisplay = streakCount > 0
      ? `<span class="streak-badge-active">🔥 ${streakCount} ngày</span>`
      : `<span class="text-subtle">0 ngày</span>`;

    const statusDisplay = s.is_active 
      ? '<span class="status-chip status-active"><span class="chip-dot"></span>Hoạt động</span>' 
      : '<span class="status-chip status-locked"><span class="chip-dot"></span>Bị khóa</span>';

    return `
      <tr>
        <td>
          <div class="user-cell">
            <div class="avatar">${escapeHtml(s.full_name ? s.full_name.charAt(0) : 'U')}</div>
            <div>
              <h4>${escapeHtml(s.full_name || 'Chưa có tên')}</h4>
              <p>${escapeHtml(s.email || '')}</p>
            </div>
          </div>
        </td>
        <td>
          <strong>${escapeHtml(s.student_id || 'Chưa có')}</strong>
          <p class="text-muted" style="margin-bottom: 2px;">${escapeHtml(s.major || 'Chưa có ngành')}</p>
          ${s.university_pending_name ? `<span class="badge badge-warning" style="display:inline-block; margin-top:2px; font-size:11px;" title="Trường do sinh viên đề xuất đang chờ duyệt">⏳ Đề xuất: ${escapeHtml(s.university_pending_name)}</span>` : ''}
          ${(!s.university_id && s.university && s.university.trim() && s.university.trim() !== 'Chưa phân loại' && !s.university_pending_name) ? `<small class="text-subtle" style="font-size: 11px; display: block;">Gốc: ${escapeHtml(s.university.trim())}</small>` : ''}
        </td>
        <td>
          <strong>${escapeHtml((s.company_id && s.company_name) ? s.company_name : 'Chưa chọn nơi thực tập')}</strong>
          ${s.company_pending_name ? `<span class="badge badge-warning" style="display:inline-block; margin-top:2px; font-size:11px;" title="Nơi thực tập do sinh viên đề xuất đang chờ duyệt">⏳ Đề xuất: ${escapeHtml(s.company_pending_name)}</span>` : ''}
          <p class="text-muted" style="margin-bottom:2px">${escapeHtml(s.department || 'Chưa có ban')}</p>
          ${shiftPill}
        </td>
        <td>${phaseDisplay}</td>
        <td>${stressDisplay}</td>
        <td>${sleepDisplay}</td>
        <td>${streakDisplay}</td>
        <td>${statusDisplay}</td>
        <td class="text-right">
          <div class="table-actions">
            <button type="button" class="btn-tb-intervene" title="Gửi can thiệp tâm lý & lời khuyên cho sinh viên này" onclick="window.EnigmaApp.openIntervention('${escapeHtml(s.id)}')">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
              </svg>
              <span>Can Thiệp</span>
            </button>
            <button type="button" class="btn-tb-detail" title="Xem chi tiết hồ sơ" onclick="window.EnigmaApp.openUserDetail('${escapeHtml(s.id)}')">
              <span>Chi Tiết</span>
            </button>
          </div>
        </td>
      </tr>
    `;
  }

  // ─── Render Students Directory (Grouped by University & Workplace) ─────────────
  function renderStudentsTable() {
    // 1. Cập nhật số liệu trên 4 thẻ Quick Stat Strip
    const totalCount = STATE.students.length;
    const highRiskCount = STATE.students.filter(s => s.is_high_risk || (s.latest_stress_level !== null && s.latest_stress_level >= 4)).length;
    const nightShiftCount = STATE.students.filter(s => s.work_shift === 'night_12h').length;
    const streakActiveCount = STATE.students.filter(s => (s.current_streak || 0) > 0).length;

    const elTotal = document.getElementById('sq-total-students');
    const elRisk = document.getElementById('sq-high-risk');
    const elNight = document.getElementById('sq-night-shift');
    const elStreak = document.getElementById('sq-streak-active');

    if (elTotal) elTotal.textContent = totalCount;
    if (elRisk) elRisk.textContent = highRiskCount;
    if (elNight) elNight.textContent = nightShiftCount;
    if (elStreak) elStreak.textContent = streakActiveCount;

    // Cập nhật thanh chips và dropdowns
    renderUniversityChips();
    updateUniversityDropdowns();

    // 2. Lọc dữ liệu sinh viên
    const search = DOM.studentsSearchInput ? DOM.studentsSearchInput.value.toLowerCase().trim() : '';
    const phase = DOM.studentsFilterPhase ? DOM.studentsFilterPhase.value : '';
    const risk = DOM.studentsFilterRisk ? DOM.studentsFilterRisk.value : '';
    const pill = STATE.studentPillFilter || 'all';
    const filterUni = STATE.selectedUniversity || (DOM.studentsFilterUniversity ? DOM.studentsFilterUniversity.value : '');
    const filterComp = STATE.selectedCompany || (DOM.studentsFilterCompany ? DOM.studentsFilterCompany.value : '');

    let filtered = STATE.students.filter(s => {
      const uniName = getStudentUniLabel(s);
      const compName = (s.company_id && s.company_name) ? s.company_name : 'Chưa chọn nơi thực tập';

      // University Filter
      if (filterUni && uniName.toLowerCase() !== filterUni.toLowerCase()) {
        return false;
      }

      // Company Filter
      if (filterComp && compName.toLowerCase() !== filterComp.toLowerCase()) {
        return false;
      }

      // Search
      const matchSearch = !search ||
        (s.full_name && s.full_name.toLowerCase().includes(search)) ||
        (s.student_id && s.student_id.toLowerCase().includes(search)) ||
        (s.email && s.email.toLowerCase().includes(search)) ||
        (s.major && s.major.toLowerCase().includes(search)) ||
        (s.department && s.department.toLowerCase().includes(search)) ||
        (compName && compName.toLowerCase().includes(search)) ||
        (uniName && uniName.toLowerCase().includes(search));

      // Phase dropdown
      const matchPhase = !phase || s.current_phase === phase;

      // Risk dropdown
      let matchRisk = true;
      if (risk === 'high') matchRisk = s.is_high_risk || (s.latest_stress_level !== null && s.latest_stress_level >= 4);
      if (risk === 'active') matchRisk = s.is_active;

      // Filter Pill
      let matchPill = true;
      if (pill === 'high_risk') {
        matchPill = s.is_high_risk || (s.latest_stress_level !== null && s.latest_stress_level >= 4);
      } else if (pill === 'night_shift') {
        matchPill = s.work_shift === 'night_12h';
      } else if (pill === 'streak') {
        matchPill = (s.current_streak || 0) > 0;
      } else if (pill === 'active') {
        matchPill = s.is_active;
      }

      return matchSearch && matchPhase && matchRisk && matchPill;
    });

    const phaseNames = {
      preparation: '<span class="status-chip phase-prep">1. Chuẩn Bị</span>',
      adaptation: '<span class="status-chip phase-adapt">2. Hòa Nhập</span>',
      sustain: '<span class="status-chip phase-sustain">3. Duy Trì</span>'
    };

    // Kiểm tra trường hợp không tìm thấy kết quả
    if (filtered.length === 0) {
      if (DOM.studentsGroupedContainer) {
        DOM.studentsGroupedContainer.innerHTML = `
          <div class="card p-6 text-center text-subtle">
            🔍 Không tìm thấy sinh viên hoặc trường nào phù hợp với bộ lọc tìm kiếm hiện tại.
          </div>
        `;
      }
      if (DOM.studentsTbody) {
        DOM.studentsTbody.innerHTML = `
          <tr>
            <td colspan="9" class="text-center py-6 text-subtle">
              Không tìm thấy sinh viên nào phù hợp với điều kiện lọc hiện tại.
            </td>
          </tr>
        `;
      }
      return;
    }

    // ─── CHẾ ĐỘ 1: GOM NHÓM THEO TRƯỜNG & NƠI THỰC TẬP (Mặc định) ───────────────
    if (STATE.studentsViewMode === 'grouped') {
      if (DOM.studentsFlatWrapper) DOM.studentsFlatWrapper.style.display = 'none';
      if (DOM.studentsGroupedContainer) DOM.studentsGroupedContainer.style.display = 'flex';

      // Gom nhóm sinh viên theo university_name với nhóm tường minh "Chưa phân loại"
      const groupsMap = new Map();
      filtered.forEach(s => {
        const uniLabel = getStudentUniLabel(s);
        const isUnassigned = (uniLabel === 'Chưa phân loại');
        const groupKey = isUnassigned ? 'unassigned' : uniLabel;
        const groupLabel = isUnassigned ? 'Chưa phân loại' : uniLabel;
        if (!groupsMap.has(groupKey)) {
          groupsMap.set(groupKey, {
            id: groupKey,
            name: groupLabel,
            isUnassigned: isUnassigned,
            students: []
          });
        }
        groupsMap.get(groupKey).students.push(s);
      });

      let groupCardsHtml = '';
      let groupIndex = 0;
      groupsMap.forEach((groupData, groupKey) => {
        const uniName = groupData.name;
        const studentsInGroup = groupData.students;
        const safeKey = String(groupKey).replace(/[^A-Za-z0-9_-]/g, '_');
        const slug = `grp_${groupIndex++}_${safeKey}`;
        const isCollapsed = STATE.collapsedUniGroups.has(slug);

        const totalInUni = studentsInGroup.length;
        const nightShiftsInUni = studentsInGroup.filter(s => s.work_shift === 'night_12h').length;
        const highRiskInUni = studentsInGroup.filter(s => s.is_high_risk || (s.latest_stress_level !== null && s.latest_stress_level >= 4)).length;
        
        // Liệt kê công ty tiếp nhận và chuyên ngành
        const companies = [...new Set(studentsInGroup.map(s => (s.company_id && s.company_name) ? s.company_name : 'Chưa chọn nơi thực tập'))].join(', ');
        const majors = [...new Set(studentsInGroup.map(s => s.major).filter(Boolean))].join(', ') || 'Kỹ thuật / Công nghệ';

        // Nhãn phụ hiển thị văn bản gốc của trường nếu là nhóm Chưa phân loại
        let rawSchoolsSub = '';
        if (groupData.isUnassigned) {
          const rawTexts = [...new Set(studentsInGroup.map(s => s.university && s.university.trim()).filter(Boolean))].filter(t => t !== 'Chưa phân loại');
          if (rawTexts.length > 0) {
            rawSchoolsSub = ` &bull; <small class="text-subtle">Văn bản gốc: ${escapeHtml(rawTexts.join(', '))}</small>`;
          }
        }

        groupCardsHtml += `
          <div class="uni-group-card ${isCollapsed ? 'collapsed' : ''} ${groupData.isUnassigned ? 'uni-group-unassigned' : ''}" id="uni-group-${slug}">
            <div class="uni-group-header" onclick="window.EnigmaApp.toggleUniGroup('${slug}')">
              <div class="uni-group-title-col">
                <div class="uni-icon-box" style="${groupData.isUnassigned ? 'background: rgba(245, 158, 11, 0.15); color: #f59e0b;' : ''}">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 21h18"/>
                    <path d="M5 21V7l7-4 7 4v14"/>
                    <path d="M9 21v-6a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v6"/>
                  </svg>
                </div>
                <div>
                  <div class="uni-title-row">
                    <h3 class="uni-name">${escapeHtml(uniName)}</h3>
                    ${groupData.isUnassigned ? '<span class="status-chip stress-badge-warning" style="font-size: 11px; margin-left: 6px;">Chưa phân loại</span>' : ''}
                    <span class="uni-cohort-tag">🏢 Nơi thực tập: <strong>${escapeHtml(companies)}</strong></span>
                  </div>
                  <p class="uni-subtitle">
                    Chuyên ngành: <span class="uni-major-tag">${escapeHtml(majors)}</span>${rawSchoolsSub}
                  </p>
                </div>
              </div>

              <div class="uni-group-stats">
                <div class="uni-stat-pill">
                  <span class="uni-stat-num">${totalInUni}</span>
                  <span class="uni-stat-lbl">Sinh viên</span>
                </div>
                ${nightShiftsInUni > 0 ? `
                  <div class="uni-stat-pill shift-night">
                    <span class="uni-stat-num">🌙 ${nightShiftsInUni}</span>
                    <span class="uni-stat-lbl">Ca đêm</span>
                  </div>
                ` : ''}
                ${highRiskInUni > 0 ? `
                  <div class="uni-stat-pill risk-danger">
                    <span class="uni-stat-num">🚨 ${highRiskInUni}</span>
                    <span class="uni-stat-lbl">Cần can thiệp</span>
                  </div>
                ` : `
                  <div class="uni-stat-pill status-safe">
                    <span class="uni-stat-num">🛡️ Ổn định</span>
                    <span class="uni-stat-lbl">Tâm lý tốt</span>
                  </div>
                `}
                <button type="button" class="uni-collapse-btn" aria-label="Mở rộng hoặc thu gọn đoàn thực tập">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M6 9l6 6 6-6"/>
                  </svg>
                </button>
              </div>
            </div>

            <div class="uni-group-body">
              <div class="table-wrapper">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th style="width: 220px;">Sinh Viên</th>
                      <th style="width: 150px;">MSSV / Ngành</th>
                      <th style="width: 180px;">Công Ty & Ca Làm</th>
                      <th style="width: 130px;">Giai Đoạn</th>
                      <th style="width: 110px;">Stress Gần Nhất</th>
                      <th style="width: 90px;">Giờ Ngủ</th>
                      <th style="width: 95px;">Chuỗi Streak</th>
                      <th style="width: 105px;">Trạng Thái</th>
                      <th style="width: 165px;" class="text-right">Hành Động Cố Vấn</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${studentsInGroup.map(s => renderStudentRow(s, phaseNames)).join('')}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        `;
      });

      if (DOM.studentsGroupedContainer) {
        DOM.studentsGroupedContainer.innerHTML = groupCardsHtml;
      }
    } 
    // ─── CHẾ ĐỘ 2: BẢNG TOÀN BỘ (Flat Table) ────────────────────────────────────
    else {
      if (DOM.studentsGroupedContainer) DOM.studentsGroupedContainer.style.display = 'none';
      if (DOM.studentsFlatWrapper) DOM.studentsFlatWrapper.style.display = 'block';

      if (DOM.studentsTbody) {
        DOM.studentsTbody.innerHTML = filtered.map(s => renderStudentRow(s, phaseNames)).join('');
      }
    }
  }

  // ─── Render Burnout Alert Cards ───────────────────────────────────────────────
  function renderBurnoutCards() {
    const alertList = STATE.alerts || [];

    if (alertList.length === 0) {
      DOM.burnoutCardsContainer.innerHTML = `
        <div class="card p-6 text-center text-subtle" style="grid-column: 1 / -1;">
          🎉 Tuyệt vời! Hiện tại không có sinh viên nào rơi vào ngưỡng cảnh báo kiệt sức trầm trọng.
        </div>
      `;
      return;
    }

    DOM.burnoutCardsContainer.innerHTML = alertList.map(a => {
      const companyDept = [a.company_name, a.department].filter(Boolean).map(escapeHtml).join(' — ') || 'Chưa có';
      const phaseText = a.current_phase ? ` &bull; Giai đoạn: ${escapeHtml(a.current_phase)}` : ' &bull; Giai đoạn: Chưa có';
      const noteHtml = a.note 
        ? `"${escapeHtml(a.note)}"` 
        : '<span class="text-subtle">Không có ghi chú</span>';

      return `
      <div class="burnout-card ${a.risk_level}">
        <div class="burnout-card-header">
          <div>
            <h3 class="burnout-student-name">${escapeHtml(a.full_name || 'Chưa có tên')}</h3>
            <p class="text-subtle">${escapeHtml(a.student_id || 'Chưa có MSSV')} — ${companyDept}${phaseText}</p>
          </div>
          <span class="badge ${a.risk_level === 'critical' || a.risk_level === 'danger' ? 'badge-danger pulse-dot' : 'badge-amber'}">
            ${a.risk_level === 'critical' || a.risk_level === 'danger' ? 'RỦI RO ĐỎ' : 'CẢNH BÁO'}
          </span>
        </div>

        <div class="burnout-metrics-row">
          <div class="metric-badge-box">
            <span class="label">Mức Stress</span>
            <span class="val text-danger">${a.stress_level}/5</span>
          </div>
          <div class="metric-badge-box">
            <span class="label">Giờ Ngủ</span>
            <span class="val text-danger">${a.sleep_hours !== null && a.sleep_hours !== undefined ? `${a.sleep_hours}h` : 'Chưa có dữ liệu giấc ngủ'}</span>
          </div>
          <div class="metric-badge-box">
            <span class="label">AI Sentiment</span>
            <span class="val">${escapeHtml(a.ai_sentiment || 'Chưa có')}</span>
          </div>
        </div>

        <div class="symptoms-tags">
          ${(a.physical_symptoms || []).map(sym => `<span class="symptom-tag">⚠️ ${escapeHtml(sym)}</span>`).join('')}
        </div>

        <div class="burnout-note-quote">
          ${noteHtml}
        </div>

        <div class="card-footer-actions mt-auto">
          <button class="btn btn-sm btn-primary btn-block" onclick="window.EnigmaApp.openIntervention('${escapeHtml(a.user_id)}')">
            📞 Gửi Can Thiệp Tâm Lý & Lời Khuyên
          </button>
        </div>
      </div>
    `;
    }).join('');
  }

  // ─── Render Handbook Articles ─────────────────────────────────────────────────
  function renderHandbookArticles() {
    const search = DOM.handbookSearchInput.value.toLowerCase().trim();
    const cat = DOM.handbookFilterCategory.value;
    const stat = DOM.handbookFilterStatus.value;

    let filtered = STATE.articles.filter(art => {
      const matchSearch = !search ||
        (art.title && art.title.toLowerCase().includes(search)) ||
        (art.summary && art.summary.toLowerCase().includes(search)) ||
        (art.content && art.content.toLowerCase().includes(search));

      const matchCat = cat === 'all' || !cat || art.category === cat;
      const matchStat = !stat || art.status === stat;

      return matchSearch && matchCat && matchStat;
    });

    if (filtered.length === 0) {
      DOM.handbookArticlesContainer.innerHTML = `
        <div class="card p-6 text-center text-subtle" style="grid-column: 1 / -1;">
          Không tìm thấy bài viết cẩm nang nào. Nhấn "Thêm Bài Mới" để tạo bài viết đầu tiên!
        </div>
      `;
      return;
    }

    const catLabels = {
      sleep: '🌙 1. Giấc Ngủ',
      physical: '💪 2. Thể Chất',
      mental: '🧘 3. Tâm Lý',
      social: '🤝 4. Xã Hội',
      career: '🚀 5. Sự Nghiệp'
    };

    DOM.handbookArticlesContainer.innerHTML = filtered.map(art => `
      <div class="article-card">
        <span class="article-category-badge">${catLabels[art.category] || escapeHtml(art.category)}</span>
        <h3 class="article-card-title">${escapeHtml(art.title)}</h3>
        <p class="article-card-summary">${escapeHtml(art.summary || art.content.slice(0, 120) + '...')}</p>
        
        <div class="article-meta-row">
          <span>Tác giả: <strong>${escapeHtml(art.author_name || 'Cố vấn')}</strong></span>
          <div class="article-actions">
            <button class="btn btn-sm btn-secondary" onclick="window.EnigmaApp.editArticle('${escapeHtml(art.id)}')">Sửa</button>
            <button class="btn btn-sm btn-danger-outline" onclick="window.EnigmaApp.deleteArticle('${escapeHtml(art.id)}')">Xóa</button>
          </div>
        </div>
      </div>
    `).join('');
  }

  // ─── Render Tasks Table ───────────────────────────────────────────────────────
  function renderTasksTable() {
    const currentPhase = STATE.activeTaskPhase;
    const filtered = STATE.tasks.filter(t => t.phase === currentPhase);

    if (filtered.length === 0) {
      DOM.tasksTbody.innerHTML = `
        <tr>
          <td colspan="7" class="text-center py-6 text-subtle">
            Chưa có nhiệm vụ nào cho giai đoạn này.
          </td>
        </tr>
      `;
      return;
    }

    const pillarIcons = {
      sleep: '🌙 Giấc ngủ',
      physical: '💪 Thể chất',
      mental: '🧘 Tâm lý',
      social: '🤝 Xã hội',
      career: '🚀 Sự nghiệp'
    };

    DOM.tasksTbody.innerHTML = filtered.map(t => `
      <tr>
        <td>
          <strong>${escapeHtml(t.title)}</strong>
          <p class="text-muted">${escapeHtml(t.description)}</p>
        </td>
        <td><span class="badge badge-info">${pillarIcons[t.pillar] || escapeHtml(t.pillar)}</span></td>
        <td>⏱️ ${t.duration_minutes || 15} phút</td>
        <td>📅 Ngày thứ ${t.unlock_day || 1}</td>
        <td>✅ ${t.completed_count || 0} lượt</td>
        <td>
          ${t.is_active 
            ? '<span class="badge badge-emerald">Hoạt động</span>' 
            : '<span class="badge badge-subtle">Ẩn</span>'}
        </td>
        <td class="text-right">
          <button class="btn btn-sm btn-secondary" onclick="window.EnigmaApp.editTask('${escapeHtml(t.id)}')">Sửa</button>
        </td>
      </tr>
    `).join('');
  }

  // ─── Render Notification History ──────────────────────────────────────────────
  function renderNotificationHistory() {
    if (STATE.notifications.length === 0) {
      DOM.notificationHistoryList.innerHTML = `<p class="text-subtle text-center py-4">Chưa có thông báo nào được phát.</p>`;
      return;
    }

    DOM.notificationHistoryList.innerHTML = STATE.notifications.map(n => `
      <div class="history-item">
        <h4>📢 ${escapeHtml(n.title)}</h4>
        <p>${escapeHtml(n.body)}</p>
        <div class="history-meta">
          <span>Loại: <strong>${escapeHtml(n.type)}</strong></span>
          <span>${new Date(n.sent_at || Date.now()).toLocaleTimeString()} - ${new Date(n.sent_at || Date.now()).toLocaleDateString()}</span>
        </div>
      </div>
    `).join('');
  }

  // ─── User Detail Modal Handler ────────────────────────────────────────────────
  async function openUserDetail(userId) {
    let user = STATE.students.find(s => s.id === userId);
    if (!user) return;

    // Lấy thêm chi tiết từ API nếu có
    const detail = await apiFetch(`/admin/users/${userId}`);
    if (detail && detail.user) {
      user = { ...user, ...detail.user, ...detail.profile };
    }

    document.getElementById('um-fullname').textContent = user.full_name || 'Chưa có tên';
    document.getElementById('um-student-id').textContent = user.student_id || 'Chưa có';
    document.getElementById('um-phase').textContent = `Giai đoạn: ${user.current_phase || 'Chưa có'}`;
    document.getElementById('um-avatar').textContent = user.full_name ? user.full_name.charAt(0) : 'U';
    document.getElementById('um-name-card').textContent = user.full_name || 'Chưa có tên';
    document.getElementById('um-email').textContent = user.email || 'Chưa có';
    const shiftText = user.work_shift === 'night_12h' 
      ? '🌙 Ca đêm (20h-8h)' 
      : (user.work_shift === 'office_8h' 
        ? '💼 Hành chính' 
        : (user.work_shift === 'day_12h' 
          ? '☀️ Ca ngày (8h-20h)' 
          : 'Chưa có ca làm'));
    const companyDisplay = escapeHtml((user.company_id && user.company_name) ? user.company_name : 'Chưa chọn nơi thực tập');
    const deptDisplay = escapeHtml(user.department || 'Chưa có');
    document.getElementById('um-company').innerHTML = `${companyDisplay} — ${deptDisplay} &bull; <span class="text-white">${shiftText}</span>`;

    // 5 Pillars scores
    const scores = (detail && detail.profile && detail.profile.initial_scores) || user.initial_scores || { sleep: 70, physical: 65, mental: 60, social: 75, career: 80 };
    document.getElementById('um-pillar-scores').innerHTML = `
      <div class="pillar-score-row"><span>🌙 Giấc ngủ (Sleep):</span><strong>${scores.sleep}/100</strong></div>
      <div class="pillar-score-row"><span>💪 Thể chất (Physical):</span><strong>${scores.physical}/100</strong></div>
      <div class="pillar-score-row"><span>🧘 Tâm lý (Mental):</span><strong>${scores.mental}/100</strong></div>
      <div class="pillar-score-row"><span>🤝 Xã hội (Social):</span><strong>${scores.social}/100</strong></div>
      <div class="pillar-score-row"><span>🚀 Sự nghiệp (Career):</span><strong>${scores.career}/100</strong></div>
    `;

    // Nhật ký thực tế của sinh viên (hiển thị toàn bộ lịch sử từ API nếu có)
    const journalList = (detail && Array.isArray(detail.journals) && detail.journals.length > 0)
      ? detail.journals
      : [];

    if (journalList.length > 0) {
      document.getElementById('um-journals-list').innerHTML = journalList.map(j => {
        const stressDisplay = (j.stress_level !== null && j.stress_level !== undefined)
          ? `${j.stress_level}/5`
          : 'Chưa có dữ liệu';
        const sleepDisplay = (j.sleep_hours !== null && j.sleep_hours !== undefined)
          ? `${j.sleep_hours}h`
          : 'Chưa có dữ liệu giấc ngủ';
        const dateDisplay = escapeHtml(j.journal_date || 'Gần nhất');
        const noteDisplay = j.note 
          ? `"${escapeHtml(j.note)}"` 
          : '<span class="text-subtle">Không có ghi chú</span>';
        const symptomsHtml = (j.physical_symptoms && j.physical_symptoms.length > 0)
          ? `<div class="symptoms-tags my-1">${j.physical_symptoms.map(sym => `<span class="symptom-tag text-xs">⚠️ ${escapeHtml(sym)}</span>`).join('')}</div>`
          : '';

        return `
          <div class="ujournal-item mb-2">
            <div class="flex justify-between text-xs text-muted mb-1">
              <span>📅 ${dateDisplay}</span>
              <span>Stress: <strong>${stressDisplay}</strong> | Ngủ: <strong>${sleepDisplay}</strong></span>
            </div>
            ${symptomsHtml}
            <p class="text-xs">${noteDisplay}</p>
          </div>
        `;
      }).join('');
    } else {
      const hasSingleJournal = (user.latest_stress_level !== null && user.latest_stress_level !== undefined) ||
                               (user.latest_sleep_hours !== null && user.latest_sleep_hours !== undefined) ||
                               Boolean(user.latest_journal_date) ||
                               Boolean(user.latest_note);

      if (!hasSingleJournal) {
        document.getElementById('um-journals-list').innerHTML = `
          <p class="text-subtle text-center py-4 text-xs">Chưa có nhật ký</p>
        `;
      } else {
        const stressDisplay = (user.latest_stress_level !== null && user.latest_stress_level !== undefined)
          ? `${user.latest_stress_level}/5`
          : 'Chưa có dữ liệu';
        const sleepDisplay = (user.latest_sleep_hours !== null && user.latest_sleep_hours !== undefined)
          ? `${user.latest_sleep_hours}h`
          : 'Chưa có dữ liệu giấc ngủ';
        const dateDisplay = escapeHtml(user.latest_journal_date || 'Gần nhất');
        const noteDisplay = user.latest_note 
          ? `"${escapeHtml(user.latest_note)}"` 
          : '<span class="text-subtle">Không có ghi chú</span>';

        document.getElementById('um-journals-list').innerHTML = `
          <div class="ujournal-item">
            <div class="flex justify-between text-xs text-muted mb-1">
              <span>📅 ${dateDisplay}</span>
              <span>Stress: <strong>${stressDisplay}</strong> | Ngủ: <strong>${sleepDisplay}</strong></span>
            </div>
            <p class="text-xs">${noteDisplay}</p>
          </div>
        `;
      }
    }

    // Toggle status button
    const btnToggle = document.getElementById('um-btn-toggle-status');
    btnToggle.textContent = user.is_active ? 'Khóa Tài Khoản' : 'Mở Khóa Tài Khoản';
    btnToggle.onclick = async () => {
      const newStatus = !user.is_active;
      await apiFetch(`/admin/users/${user.id}/status`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: newStatus })
      });
      user.is_active = newStatus;
      showToast(`Đã ${newStatus ? 'mở khóa' : 'khóa'} tài khoản ${user.full_name}`, 'success');
      renderStudentsTable();
      DOM.userModal.classList.remove('open');
    };

    // Can thiệp tâm lý button inside detail drawer
    const btnIntervention = document.getElementById('um-btn-send-intervention');
    if (btnIntervention) {
      btnIntervention.onclick = () => {
        DOM.userModal.classList.remove('open');
        openInterventionModal(user.id);
      };
    }

    DOM.userModal.classList.add('open');
  }

  // ─── Modal Close Listeners ────────────────────────────────────────────────────
  document.querySelectorAll('[data-close-modal]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const modalId = btn.getAttribute('data-close-modal');
      const targetModal = document.getElementById(modalId);
      if (targetModal) targetModal.classList.remove('open');
    });
  });

  // ─── Broadcast Notification Form ──────────────────────────────────────────────
  DOM.broadcastForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const title = document.getElementById('notif-title').value.trim();
    const body = document.getElementById('notif-body').value.trim();
    const type = document.getElementById('notif-type').value;
    const target = document.getElementById('notif-target').value;

    const payload = { title, body, type, target_role: target };

    await apiFetch('/admin/notifications/broadcast', {
      method: 'POST',
      body: JSON.stringify(payload)
    });

    // Add to local state
    STATE.notifications.unshift({
      id: `notif-${Date.now()}`,
      title,
      body,
      type,
      sent_at: new Date().toISOString()
    });

    showToast(`Đã phát thông báo thành công tới sinh viên!`, 'success');
    DOM.broadcastForm.reset();
    renderNotificationHistory();
  });

  // ─── Handbook Form & Modals ───────────────────────────────────────────────────
  DOM.btnCreateArticle.addEventListener('click', () => {
    document.getElementById('art-id').value = '';
    document.getElementById('art-title').value = '';
    document.getElementById('art-summary').value = '';
    document.getElementById('art-content').value = '';
    document.getElementById('art-tags').value = '';
    document.getElementById('article-modal-title').textContent = 'Thêm Bài Viết Cẩm Nang Mới & Đồng Bộ AI';
    DOM.articleModal.classList.add('open');
  });

  DOM.articleForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const artId = document.getElementById('art-id').value;
    const title = document.getElementById('art-title').value.trim();
    const category = document.getElementById('art-category').value;
    const status = document.getElementById('art-status').value;
    const summary = document.getElementById('art-summary').value.trim();
    const content = document.getElementById('art-content').value.trim();
    const tags = document.getElementById('art-tags').value.split(',').map(t => t.trim()).filter(Boolean);

    const payload = { title, category, status, summary, content, tags };

    if (artId) {
      // Update
      await apiFetch(`/admin/handbook/${artId}`, { method: 'PUT', body: JSON.stringify(payload) });
      const idx = STATE.articles.findIndex(a => a.id === artId);
      if (idx !== -1) {
        STATE.articles[idx] = { ...STATE.articles[idx], ...payload };
      }
      showToast('Đã cập nhật bài viết cẩm nang!', 'success');
    } else {
      // Create
      const res = await apiFetch('/admin/handbook', { method: 'POST', body: JSON.stringify(payload) });
      const newArt = {
        id: (res && res.id) || `art-${Date.now()}`,
        author_name: 'Quản Trị Viên',
        helpful_count: 0,
        view_count: 1,
        ...payload
      };
      STATE.articles.unshift(newArt);
      showToast('Đã xuất bản bài viết và đồng bộ vào ChromaDB RAG!', 'success');
    }

    DOM.articleModal.classList.remove('open');
    renderHandbookArticles();
    updateBadges();
  });

  // ─── Export Functions ─────────────────────────────────────────────────────────
  DOM.btnExportStudents.addEventListener('click', () => {
    const csvRows = [
      ['MSSV', 'Ho Va Ten', 'Email', 'Truong', 'Cong Ty', 'Giai Doan', 'Stress', 'Gio Ngu', 'Streak', 'Trang Thai'].join(',')
    ];

    STATE.students.forEach(s => {
      csvRows.push([
        s.student_id || '',
        `"${(s.full_name || '').replace(/"/g, '""')}"`,
        s.email || '',
        `"${(s.university || '').replace(/"/g, '""')}"`,
        `"${(s.company_name || 'Chưa có').replace(/"/g, '""')}"`,
        s.current_phase || 'Chưa có',
        (s.latest_stress_level !== null && s.latest_stress_level !== undefined) ? s.latest_stress_level : 'Chưa có dữ liệu',
        (s.latest_sleep_hours !== null && s.latest_sleep_hours !== undefined) ? s.latest_sleep_hours : 'Chưa có dữ liệu',
        s.current_streak || 0,
        s.is_active ? 'Active' : 'Locked'
      ].join(','));
    });

    const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `Enigma_Danh_Sach_Sinh_Vien_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    showToast('Đã xuất file CSV danh sách sinh viên!', 'success');
  });

  DOM.btnExportJson.addEventListener('click', () => {
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(STATE, null, 2));
    const dlAnchorElem = document.createElement('a');
    dlAnchorElem.setAttribute("href", dataStr);
    dlAnchorElem.setAttribute("download", `Enigma_Export_${new Date().toISOString().split('T')[0]}.json`);
    dlAnchorElem.click();
    showToast('Đã xuất dữ liệu toàn hệ thống sang định dạng JSON!', 'success');
  });

  // ─── Settings Handlers ────────────────────────────────────────────────────────
  DOM.btnSaveSettings.addEventListener('click', () => {
    const newUrl = DOM.settingApiUrl.value.trim();
    STATE.apiBaseUrl = newUrl;
    localStorage.setItem('enigma_api_url', newUrl);
    showToast('Đã lưu cấu hình kết nối API!', 'success');
    if (STATE.adminToken) {
      loadAllData();
    }
  });

  if (DOM.btnAdminLogout) {
    DOM.btnAdminLogout.addEventListener('click', logoutAdmin);
  }

  if (DOM.btnSettingsLogout) {
    DOM.btnSettingsLogout.addEventListener('click', logoutAdmin);
  }

  DOM.btnTestConnection.addEventListener('click', async () => {
    showToast('Đang kiểm tra kết nối tới Backend...', 'info');
    const res = await apiFetch('/admin/stats');
    if (res) {
      showToast('Kết nối thành công tới FastAPI Server!', 'success');
    } else {
      showToast('Không thể kết nối. Kiểm tra xem FastAPI đã chạy trên cổng này chưa.', 'error');
    }
  });

  DOM.btnClearCache.addEventListener('click', () => {
    localStorage.clear();
    showToast('Đã xóa bộ nhớ đệm. Đang tải lại...', 'info');
    setTimeout(() => location.reload(), 1000);
  });

  // ─── Quick Advice Templates for Psychological Intervention ───────────────────
  const INTERVENTION_TEMPLATES = {
    sleep: {
      title: "Lời khuyên phục hồi nhịp sinh học & giấc ngủ ca đêm",
      type: "recovery",
      message: "Chào em, Thầy/Cô thấy em vừa hoàn thành ca kíp căng thẳng và số giờ ngủ gần đây khá ít. Em hãy nhớ kéo rèm phòng tối, uống một ly nước ấm và dành ít nhất 7-8 tiếng nghỉ ngơi để phục hồi thể lực nhé!"
    },
    stress: {
      title: "Hỗ trợ giảm căng thẳng & kỹ thuật thở sâu",
      type: "counseling",
      message: "Chào em, Thầy/Cô nhận thấy mức độ căng thẳng của em đang tăng. Em hãy thử bài tập thở 4-4-4 (Box Breathing) 3 phút, thả lỏng vai gáy và đừng ngần ngại chia sẻ nếu gặp khó khăn trong công việc nhé."
    },
    counseling: {
      title: "Mời hẹn gặp trao đổi 1-1 cùng Cố vấn thực tập",
      type: "counseling",
      message: "Chào em, Cố vấn thực tập trường muốn hẹn gặp em trao đổi ngắn 15 phút (trực tiếp tại văn phòng hoặc online) để lắng nghe và hỗ trợ em giải quyết các vướng mắc trong ca làm. Em phản hồi lại tin nhắn này nhé!"
    },
    physical: {
      title: "Hướng dẫn bảo vệ cơ xương khớp & chân khi mang giày ESD",
      type: "recovery",
      message: "Chào em, khi làm việc trong phòng sạch hoặc đứng dây chuyền dài với giày ESD, em hãy chú ý thay lót giày êm ái, ngâm chân nước ấm buổi tối và thực hiện bài giãn cơ thắt lưng theo cẩm nang Enigma nhé!"
    },
    cheer: {
      title: "Lời động viên tinh thần từ Nhà trường & Cố vấn",
      type: "mentor",
      message: "Chào em, giai đoạn thực tập này là cơ hội lớn để em rèn luyện bản lĩnh và tích lũy kinh nghiệm. Thầy/Cô và nhà trường luôn đồng hành, chúc em một ca làm việc an toàn và tràn đầy năng lượng!"
    }
  };

  function openInterventionModal(userId) {
    const user = STATE.students.find(s => s.id === userId) || {};
    const name = user.full_name || 'Sinh viên';

    // Populate student target card
    const elUserId = document.getElementById('im-user-id');
    const elName = document.getElementById('im-name');
    const elAvatar = document.getElementById('im-avatar');
    const elStudentId = document.getElementById('im-student-id');
    const elPhase = document.getElementById('im-phase');
    const elWorkplace = document.getElementById('im-workplace');
    const elStress = document.getElementById('im-stress-pill');
    const elSleep = document.getElementById('im-sleep-pill');
    const elStreak = document.getElementById('im-streak-pill');

    if (elUserId) elUserId.value = user.id || userId;
    if (elName) elName.textContent = name;
    if (elAvatar) elAvatar.textContent = name.charAt(0);
    if (elStudentId) elStudentId.textContent = user.student_id || 'Chưa có MSSV';
    
    const phaseMap = {
      preparation: 'Giai đoạn 1: Chuẩn bị',
      adaptation: 'Giai đoạn 2: Hòa nhập',
      sustain: 'Giai đoạn 3: Duy trì'
    };
    if (elPhase) elPhase.textContent = phaseMap[user.current_phase] || 'Chưa phân giai đoạn';
    
    const shiftMap = {
      night_12h: 'Ca đêm (20h-8h)',
      day_12h: 'Ca ngày (8h-20h)',
      office_8h: 'Hành chính (8h-17h)'
    };
    const workplaceText = `${(user.company_id && user.company_name) ? user.company_name : 'Chưa chọn nơi thực tập'} • ${shiftMap[user.work_shift] || 'Chưa có ca làm'}`;
    if (elWorkplace) elWorkplace.textContent = workplaceText;

    const stressText = (user.latest_stress_level !== null && user.latest_stress_level !== undefined)
      ? `Stress: <strong>${user.latest_stress_level}/5</strong>`
      : 'Stress: <strong>Chưa có</strong>';
    if (elStress) elStress.innerHTML = stressText;

    const sleepText = (user.latest_sleep_hours !== null && user.latest_sleep_hours !== undefined)
      ? `Giấc ngủ: <strong>${user.latest_sleep_hours}h</strong>`
      : 'Giấc ngủ: <strong>Chưa có</strong>';
    if (elSleep) elSleep.innerHTML = sleepText;

    if (elStreak) elStreak.innerHTML = `Streak: <strong>${user.current_streak || 0} ngày</strong>`;

    // Chọn lời khuyên mặc định thông minh theo chỉ số sức khỏe của sinh viên
    const defaultTemplate = (user.latest_sleep_hours !== null && user.latest_sleep_hours < 5)
      ? INTERVENTION_TEMPLATES.sleep
      : ((user.latest_stress_level !== null && user.latest_stress_level >= 4)
          ? INTERVENTION_TEMPLATES.stress
          : INTERVENTION_TEMPLATES.cheer);

    document.getElementById('im-title').value = defaultTemplate.title;
    document.getElementById('im-type').value = defaultTemplate.type;
    document.getElementById('im-message').value = defaultTemplate.message;
    document.getElementById('im-char-count').textContent = `${defaultTemplate.message.length}/500 ký tự`;

    document.querySelectorAll('.quick-template-chip').forEach(c => c.classList.remove('active'));

    if (DOM.interventionModal) {
      DOM.interventionModal.classList.add('open');
    }
  }

  // Lắng nghe chọn mẫu lời khuyên nhanh
  document.querySelectorAll('.quick-template-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.quick-template-chip').forEach(c => c.classList.remove('active'));
      btn.classList.add('active');
      const tKey = btn.dataset.template;
      const tpl = INTERVENTION_TEMPLATES[tKey];
      if (tpl) {
        document.getElementById('im-title').value = tpl.title;
        document.getElementById('im-type').value = tpl.type;
        document.getElementById('im-message').value = tpl.message;
        document.getElementById('im-char-count').textContent = `${tpl.message.length}/500 ký tự`;
      }
    });
  });

  const imTextarea = document.getElementById('im-message');
  if (imTextarea) {
    imTextarea.addEventListener('input', () => {
      document.getElementById('im-char-count').textContent = `${imTextarea.value.length}/500 ký tự`;
    });
  }

  // Xử lý gửi Form Can Thiệp Tâm Lý
  if (DOM.interventionForm) {
    DOM.interventionForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const userId = document.getElementById('im-user-id').value;
      const title = document.getElementById('im-title').value.trim();
      const message = document.getElementById('im-message').value.trim();
      const interventionType = document.getElementById('im-type').value;
      const priority = document.getElementById('im-priority').value;

      const user = STATE.students.find(s => s.id === userId);
      const studentName = user ? user.full_name : 'sinh viên';

      showToast(`Đang gửi can thiệp tâm lý tới ${studentName}...`, 'info');

      const res = await apiFetch('/admin/interventions', {
        method: 'POST',
        body: JSON.stringify({
          user_id: userId,
          title,
          message,
          intervention_type: interventionType,
          priority
        })
      });

      if (res && res.message) {
        showToast(res.message, 'success');
      } else {
        showToast(`Đã gửi thông điệp can thiệp thành công tới ${studentName}!`, 'success');
      }

      DOM.interventionModal.classList.remove('open');
    });
  }

  // ─── Filter Pills Bar & Stat Mini Cards Listeners ─────────────────────────────
  document.querySelectorAll('.filter-pills-bar .pill-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.filter-pills-bar .pill-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      STATE.studentPillFilter = btn.dataset.pill;

      // Đồng bộ trạng thái active với stat mini cards
      document.querySelectorAll('.students-stat-strip .stat-mini-card').forEach(card => {
        if (card.dataset.pillFilter === STATE.studentPillFilter) {
          card.classList.add('active');
        } else {
          card.classList.remove('active');
        }
      });
      renderStudentsTable();
    });
  });

  document.querySelectorAll('.students-stat-strip .stat-mini-card').forEach(card => {
    card.addEventListener('click', () => {
      document.querySelectorAll('.students-stat-strip .stat-mini-card').forEach(c => c.classList.remove('active'));
      card.classList.add('active');
      STATE.studentPillFilter = card.dataset.pillFilter;

      // Đồng bộ trạng thái active với pill buttons
      document.querySelectorAll('.filter-pills-bar .pill-btn').forEach(btn => {
        if (btn.dataset.pill === STATE.studentPillFilter) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
      });
      renderStudentsTable();
    });
  });

  // ─── Quick Event Listeners ────────────────────────────────────────────────────
  DOM.navItems.forEach(item => {
    item.addEventListener('click', () => switchTab(item.dataset.tab));
  });

  DOM.btnRefresh.addEventListener('click', () => {
    showToast('Đang làm mới dữ liệu...', 'info');
    loadAllData();
  });

  DOM.btnQuickBroadcast.addEventListener('click', () => {
    switchTab('notifications');
  });

  DOM.toggleDataModeBtn.addEventListener('click', () => {
    STATE.isDemoMode = !STATE.isDemoMode;
    loadAllData();
  });

  DOM.mobileMenuBtn.addEventListener('click', () => {
    DOM.sidebar.classList.toggle('mobile-open');
  });

  if (DOM.sidebarToggleBtn) {
    DOM.sidebarToggleBtn.addEventListener('click', () => {
      DOM.sidebar.classList.toggle('collapsed');
      const isCollapsed = DOM.sidebar.classList.contains('collapsed');
      localStorage.setItem('enigma_sidebar_collapsed', isCollapsed ? '1' : '0');
    });
  }

  // Khôi phục trạng thái thu gọn menu nếu đã lưu trước đó
  if (localStorage.getItem('enigma_sidebar_collapsed') === '1') {
    DOM.sidebar.classList.add('collapsed');
  }

  DOM.taskPhaseSwitcher.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => {
      DOM.taskPhaseSwitcher.querySelectorAll('button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      STATE.activeTaskPhase = btn.dataset.phase;
      renderTasksTable();
    });
  });

  DOM.studentsSearchInput.addEventListener('input', renderStudentsTable);
  DOM.studentsFilterPhase.addEventListener('change', renderStudentsTable);
  DOM.studentsFilterRisk.addEventListener('change', renderStudentsTable);

  if (DOM.studentsFilterUniversity) {
    DOM.studentsFilterUniversity.addEventListener('change', (e) => {
      STATE.selectedUniversity = e.target.value;
      renderUniversityChips();
      renderStudentsTable();
    });
  }

  if (DOM.studentsFilterCompany) {
    DOM.studentsFilterCompany.addEventListener('change', (e) => {
      STATE.selectedCompany = e.target.value;
      renderStudentsTable();
    });
  }

  if (DOM.viewModeGroupedBtn && DOM.viewModeFlatBtn) {
    DOM.viewModeGroupedBtn.addEventListener('click', () => {
      STATE.studentsViewMode = 'grouped';
      localStorage.setItem('enigma_students_view_mode', 'grouped');
      DOM.viewModeGroupedBtn.classList.add('active');
      DOM.viewModeFlatBtn.classList.remove('active');
      renderStudentsTable();
    });

    DOM.viewModeFlatBtn.addEventListener('click', () => {
      STATE.studentsViewMode = 'flat';
      localStorage.setItem('enigma_students_view_mode', 'flat');
      DOM.viewModeFlatBtn.classList.add('active');
      DOM.viewModeGroupedBtn.classList.remove('active');
      renderStudentsTable();
    });
  }

  if (DOM.btnToggleAllGroups) {
    DOM.btnToggleAllGroups.addEventListener('click', () => {
      window.EnigmaApp.toggleAllGroups();
    });
  }

  DOM.handbookSearchInput.addEventListener('input', renderHandbookArticles);
  DOM.handbookFilterCategory.addEventListener('change', renderHandbookArticles);
  DOM.handbookFilterStatus.addEventListener('change', renderHandbookArticles);

  // ─── Pending Catalog Management ───────────────────────────────────────────────
  async function loadPendingCatalog() {
    const [pendingRes, approvedUnis, approvedComps] = await Promise.all([
      apiFetch('/admin/catalog/pending'),
      apiFetch('/catalog/universities?limit=50'),
      apiFetch('/catalog/companies?limit=50')
    ]);

    const items = Array.isArray(pendingRes) ? pendingRes : (pendingRes && pendingRes.items ? pendingRes.items : []);
    STATE.pendingCatalog = items;

    // Cache approved targets for merge dropdown
    STATE.approvedUniversities = Array.isArray(approvedUnis) ? approvedUnis : [];
    STATE.approvedCompanies = Array.isArray(approvedComps) ? approvedComps : [];

    // Fallback if approved lists are empty: harvest from STATE.students
    if (STATE.approvedUniversities.length === 0 && STATE.students.length > 0) {
      const uniMap = new Map();
      STATE.students.forEach(s => {
        if (s.university_id && s.university_name && s.university_name !== 'Chưa phân loại') {
          uniMap.set(s.university_id, { id: s.university_id, name: s.university_name, short_name: s.university_short_name });
        }
      });
      STATE.approvedUniversities = Array.from(uniMap.values());
    }

    if (STATE.approvedCompanies.length === 0 && STATE.students.length > 0) {
      const compMap = new Map();
      STATE.students.forEach(s => {
        if (s.company_id && s.company_name && s.company_name !== 'Chưa chọn nơi thực tập') {
          compMap.set(s.company_id, { id: s.company_id, name: s.company_name });
        }
      });
      STATE.approvedCompanies = Array.from(compMap.values());
    }

    // Update counters & badge
    const totalCount = items.length;
    const uniCount = items.filter(it => it.type === 'university').length;
    const compCount = items.filter(it => it.type === 'company').length;

    if (DOM.navBadgePending) {
      DOM.navBadgePending.textContent = totalCount;
      DOM.navBadgePending.style.display = totalCount > 0 ? 'inline-flex' : 'none';
    }

    const elTotal = document.getElementById('pending-count-total');
    const elUni = document.getElementById('pending-count-uni');
    const elComp = document.getElementById('pending-count-comp');
    if (elTotal) elTotal.textContent = totalCount;
    if (elUni) elUni.textContent = uniCount;
    if (elComp) elComp.textContent = compCount;

    renderPendingCatalog();
  }

  function renderPendingCatalog() {
    const tbody = document.getElementById('pending-tbody');
    if (!tbody) return;

    const search = DOM.pendingSearchInput ? DOM.pendingSearchInput.value.toLowerCase().trim() : '';
    const typeFilter = DOM.pendingFilterType ? DOM.pendingFilterType.value : '';

    const items = (STATE.pendingCatalog || []).filter(item => {
      if (typeFilter && item.type !== typeFilter) return false;
      if (search) {
        const name = (item.name || '').toLowerCase();
        const code = (item.code || '').toLowerCase();
        const shortName = (item.short_name || '').toLowerCase();
        const subName = (item.submitted_by && item.submitted_by.full_name ? item.submitted_by.full_name : '').toLowerCase();
        const subEmail = (item.submitted_by && item.submitted_by.email ? item.submitted_by.email : '').toLowerCase();
        return name.includes(search) || code.includes(search) || shortName.includes(search) || subName.includes(search) || subEmail.includes(search);
      }
      return true;
    });

    if (items.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="6" class="text-center py-8">
            <div style="padding: 2.5rem 1rem; color: var(--text-muted);">
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" style="margin: 0 auto 0.75rem auto; opacity: 0.5;">
                <circle cx="12" cy="12" r="10"/>
                <path d="M9 12l2 2 4-4"/>
              </svg>
              <h4 style="font-weight: 600; margin-bottom: 0.25rem;">Không có mục nào đang chờ duyệt</h4>
              <p style="font-size: 0.825rem;">Tất cả các trường đại học và nơi thực tập do sinh viên đề xuất đã được xử lý hoàn tất.</p>
            </div>
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = items.map(item => {
      const isUni = item.type === 'university';
      const typeBadge = isUni
        ? `<span class="badge badge-primary"><span style="margin-right:4px;">🏛️</span>Trường ĐH</span>`
        : `<span class="badge badge-info"><span style="margin-right:4px;">🏢</span>Nơi thực tập</span>`;

      const approvedList = isUni ? STATE.approvedUniversities : STATE.approvedCompanies;
      const optionsHtml = approvedList
        .filter(target => target.id !== item.id)
        .map(target => `<option value="${escapeHtml(target.id)}">${escapeHtml(target.name)}${target.short_name ? ' (' + escapeHtml(target.short_name) + ')' : ''}</option>`)
        .join('');

      const submitterHtml = item.submitted_by
        ? `<strong>${escapeHtml(item.submitted_by.full_name || 'Sinh viên')}</strong><br><small class="text-subtle">${escapeHtml(item.submitted_by.email || '')}</small>`
        : `<span class="text-subtle">Hệ thống / Ẩn danh</span>`;

      let createdDate = '—';
      if (item.created_at) {
        try {
          const d = new Date(item.created_at);
          createdDate = d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
        } catch (_) {
          createdDate = item.created_at;
        }
      }

      const userCount = item.user_count !== undefined ? item.user_count : (item.count || 0);

      return `
        <tr>
          <td>${typeBadge}</td>
          <td>
            <strong>${escapeHtml(item.name)}</strong>
            <small class="text-subtle" style="display: block; margin-top: 2px;">Mã: ${escapeHtml(item.code || 'USER-XX')}${item.short_name ? ' · Viết tắt: ' + escapeHtml(item.short_name) : ''}</small>
          </td>
          <td>${submitterHtml}</td>
          <td><span class="text-subtle" style="font-size: 0.8rem;">${escapeHtml(createdDate)}</span></td>
          <td class="text-center">
            <span class="badge ${userCount > 0 ? 'badge-primary' : 'badge-subtle'}">${userCount} SV</span>
          </td>
          <td class="text-right">
            <div style="display: flex; gap: 6px; align-items: center; justify-content: flex-end; flex-wrap: wrap;">
              <button type="button" class="btn btn-sm btn-success" title="Phê duyệt đơn vị này vào danh mục chính thức" onclick="window.EnigmaApp.reviewCatalog('${escapeHtml(item.type)}', '${escapeHtml(item.id)}', 'approve')">
                ✓ Duyệt
              </button>

              <div style="display: inline-flex; gap: 3px; align-items: center;">
                <select id="merge-target-${escapeHtml(item.id)}" class="select-control select-sm" style="max-width: 140px;" title="Chọn đơn vị chuẩn hóa để gộp vào">
                  <option value="">Gộp vào...</option>
                  ${optionsHtml}
                </select>
                <button type="button" class="btn btn-sm btn-secondary" title="Gộp các sinh viên sang đơn vị chuẩn hóa và xóa mục này" onclick="window.EnigmaApp.reviewCatalog('${escapeHtml(item.type)}', '${escapeHtml(item.id)}', 'merge')">
                  Gộp
                </button>
              </div>

              <button type="button" class="btn btn-sm btn-danger-outline" title="Từ chối đề xuất và gỡ liên kết sinh viên" onclick="window.EnigmaApp.reviewCatalog('${escapeHtml(item.type)}', '${escapeHtml(item.id)}', 'reject')">
                ✕ Từ chối
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  async function reviewCatalog(type, id, action) {
    const item = (STATE.pendingCatalog || []).find(it => String(it.id) === String(id));
    const name = item ? item.name : (type === 'university' ? 'trường đại học' : 'nơi thực tập');
    let targetCanonicalId = null;

    if (action === 'merge') {
      const selectEl = document.getElementById(`merge-target-${id}`);
      targetCanonicalId = selectEl ? selectEl.value : '';
      if (!targetCanonicalId) {
        showToast('Vui lòng chọn đơn vị chuẩn hóa trong danh sách "Gộp vào..." trước khi thực hiện.', 'warning');
        return;
      }
      const targetName = selectEl.options[selectEl.selectedIndex].text;
      const ok = window.confirm(
        `Xác nhận GỘP ĐƠN VỊ:\n\n` +
        `Bạn có chắc chắn muốn gộp "${name}" vào "${targetName}"?\n\n` +
        `Tất cả sinh viên đang liên kết với "${name}" sẽ được chuyển sang "${targetName}". Mục chờ duyệt này sẽ được xóa vĩnh viễn.`
      );
      if (!ok) return;
    } else if (action === 'reject') {
      const ok = window.confirm(
        `Xác nhận TỪ CHỐI ĐỀ XUẤT:\n\n` +
        `Bạn có chắc chắn muốn từ chối đề xuất "${name}"?\n\n` +
        `Mục đề xuất sẽ bị xóa và các sinh viên đang liên kết sẽ được đặt về trạng thái "Chưa phân loại".`
      );
      if (!ok) return;
    } else if (action === 'approve') {
      const ok = window.confirm(`Xác nhận PHÊ DUYỆT:\n\nPhê duyệt "${name}" thành đơn vị chính thức trong hệ thống?`);
      if (!ok) return;
    }

    showToast(`Đang xử lý ${action === 'approve' ? 'phê duyệt' : (action === 'merge' ? 'gộp' : 'từ chối')}...`, 'info');

    const res = await apiFetch('/admin/catalog/review', {
      method: 'POST',
      body: JSON.stringify({
        entity_type: type,
        entity_id: id,
        action: action,
        target_canonical_id: targetCanonicalId || null
      })
    });

    if (res && res.message) {
      showToast(res.message, 'success');
      // Refresh pending catalog
      await loadPendingCatalog();

      // Refresh student list after action as required
      const updatedStudents = await apiFetch('/admin/users');
      if (updatedStudents) {
        STATE.students = updatedStudents;
        renderStudentsTable();
        updateBadges();
      }
    }
  }

  // Listeners for pending review controls
  if (DOM.pendingSearchInput) {
    DOM.pendingSearchInput.addEventListener('input', renderPendingCatalog);
  }
  if (DOM.pendingFilterType) {
    DOM.pendingFilterType.addEventListener('change', renderPendingCatalog);
  }
  if (DOM.btnRefreshPending) {
    DOM.btnRefreshPending.addEventListener('click', () => {
      showToast('Đang tải lại danh mục chờ duyệt...', 'info');
      loadPendingCatalog();
    });
  }

  const statPendingAll = document.getElementById('stat-pending-all');
  const statPendingUni = document.getElementById('stat-pending-uni');
  const statPendingComp = document.getElementById('stat-pending-comp');

  if (statPendingAll && DOM.pendingFilterType) {
    statPendingAll.addEventListener('click', () => {
      DOM.pendingFilterType.value = '';
      statPendingAll.classList.add('active');
      if (statPendingUni) statPendingUni.classList.remove('active');
      if (statPendingComp) statPendingComp.classList.remove('active');
      renderPendingCatalog();
    });
  }
  if (statPendingUni && DOM.pendingFilterType) {
    statPendingUni.addEventListener('click', () => {
      DOM.pendingFilterType.value = 'university';
      statPendingUni.classList.add('active');
      if (statPendingAll) statPendingAll.classList.remove('active');
      if (statPendingComp) statPendingComp.classList.remove('active');
      renderPendingCatalog();
    });
  }
  if (statPendingComp && DOM.pendingFilterType) {
    statPendingComp.addEventListener('click', () => {
      DOM.pendingFilterType.value = 'company';
      statPendingComp.classList.add('active');
      if (statPendingAll) statPendingAll.classList.remove('active');
      if (statPendingUni) statPendingUni.classList.remove('active');
      renderPendingCatalog();
    });
  }

  // ─── Public Window API for inline onclick handlers ───────────────────────────
  
  // ─── Crisis Flags Management (AI Chat Guardrail) ───────────────────────────
  async function loadCrisisFlags() {
    if (!STATE.adminToken) return;
    try {
      const data = await apiFetch('/admin/crisis-flags');
      if (Array.isArray(data)) {
        STATE.crisisFlags = data;
        const newCount = data.filter(f => f.status === 'new').length;
        if (DOM.navBadgeCrisis) {
          DOM.navBadgeCrisis.textContent = newCount;
          DOM.navBadgeCrisis.style.display = newCount > 0 ? 'inline-block' : 'none';
        }
        if (STATE.activeTab === 'crisis') {
          renderCrisisFlagsTable();
        }
      }
    } catch (e) {
      console.warn('Không thể tải crisis flags:', e);
    }
  }

  function renderCrisisFlagsTable() {
    if (!DOM.crisisFlagsTbody) return;
    const flags = STATE.crisisFlags || [];
    if (flags.length === 0) {
      DOM.crisisFlagsTbody.innerHTML = `
        <tr>
          <td colspan="6" class="text-center text-subtle p-6">
            🎉 Không có cảnh báo khủng hoảng nào cần xử lý.
          </td>
        </tr>
      `;
      return;
    }

    DOM.crisisFlagsTbody.innerHTML = flags.map(f => {
      const isNew = f.status === 'new';
      const statusBadge = isNew
        ? '<span class="badge badge-danger pulse-dot">MỚI (CHƯA XỬ LÝ)</span>'
        : f.status === 'contacted'
          ? '<span class="badge badge-warning">ĐÃ LIÊN HỆ</span>'
          : '<span class="badge badge-success">ĐÃ GIẢI QUYẾT</span>';

      const tierBadge = f.tier === 'explicit'
        ? '<span class="badge badge-danger">NGHIÊM TRỌNG (EXPLICIT)</span>'
        : '<span class="badge badge-amber">CẦN CHÚ Ý (AMBIGUOUS)</span>';

      return `
        <tr>
          <td><small class="text-subtle">${escapeHtml(f.created_at ? f.created_at.slice(0, 16).replace('T', ' ') : 'Vừa xong')}</small></td>
          <td>
            <strong>${escapeHtml(f.full_name || 'Sinh viên')}</strong><br>
            <small class="text-subtle">MSSV: ${escapeHtml(f.student_id || 'Chưa có')} | ${escapeHtml(f.email || '')}</small>
          </td>
          <td>${tierBadge}</td>
          <td>${statusBadge}</td>
          <td>
            <input type="text" id="flag-note-${escapeHtml(f.id)}" class="input-control input-sm" style="width: 220px;" 
                   value="${escapeHtml(f.admin_note || '')}" placeholder="Ghi chú người xử lý...">
          </td>
          <td>
            <div class="btn-group">
              ${isNew ? `
                <button class="btn btn-sm btn-primary" onclick="window.EnigmaApp.updateCrisisStatus('${escapeHtml(f.id)}', 'contacted')">
                  📞 Đã Liên Hệ
                </button>
              ` : ''}
              ${f.status !== 'resolved' ? `
                <button class="btn btn-sm btn-success" onclick="window.EnigmaApp.updateCrisisStatus('${escapeHtml(f.id)}', 'resolved')">
                  ✓ Hoàn Tất
                </button>
              ` : `
                <button class="btn btn-sm btn-secondary" onclick="window.EnigmaApp.updateCrisisStatus('${escapeHtml(f.id)}', 'contacted')">
                  Mở Lại
                </button>
              `}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }


  window.EnigmaApp = {
        refreshCrisisFlags: async () => {
      await loadCrisisFlags();
      showToast('Đã làm mới danh sách cảnh báo khủng hoảng!', 'success');
    },
    updateCrisisStatus: async (flagId, newStatus) => {
      const noteInput = document.getElementById(`flag-note-${flagId}`);
      const adminNote = noteInput ? noteInput.value.trim() : '';
      const res = await apiFetch(`/admin/crisis-flags/${flagId}`, {
        method: 'PUT',
        body: JSON.stringify({ status: newStatus, admin_note: adminNote })
      });
      if (res) {
        showToast(`Đã cập nhật trạng thái cảnh báo sang: ${newStatus}`, 'success');
        await loadCrisisFlags();
      }
    },
    openUserDetail,
    openIntervention: (userId) => {
      openInterventionModal(userId);
    },
    toggleUniGroup: (groupSlug) => {
      const card = document.getElementById(`uni-group-${groupSlug}`);
      if (!card) return;
      if (card.classList.contains('collapsed')) {
        card.classList.remove('collapsed');
        STATE.collapsedUniGroups.delete(groupSlug);
      } else {
        card.classList.add('collapsed');
        STATE.collapsedUniGroups.add(groupSlug);
      }
    },
    selectUniPill: (uniName) => {
      STATE.selectedUniversity = uniName;
      if (DOM.studentsFilterUniversity) {
        DOM.studentsFilterUniversity.value = uniName;
      }
      renderUniversityChips();
      renderStudentsTable();
    },
    toggleAllGroups: () => {
      const cards = document.querySelectorAll('.uni-group-card');
      if (!cards.length) return;
      STATE.allGroupsCollapsed = !STATE.allGroupsCollapsed;
      cards.forEach(card => {
        const slug = card.id.replace('uni-group-', '');
        if (STATE.allGroupsCollapsed) {
          card.classList.add('collapsed');
          STATE.collapsedUniGroups.add(slug);
        } else {
          card.classList.remove('collapsed');
          STATE.collapsedUniGroups.delete(slug);
        }
      });
      if (DOM.btnToggleAllText) {
        DOM.btnToggleAllText.textContent = STATE.allGroupsCollapsed ? 'Mở Rộng Tất Cả' : 'Thu Gọn Tất Cả';
      }
    },
    editArticle: (artId) => {
      const art = STATE.articles.find(a => a.id === artId);
      if (!art) return;
      document.getElementById('art-id').value = art.id;
      document.getElementById('art-title').value = art.title;
      document.getElementById('art-category').value = art.category;
      document.getElementById('art-status').value = art.status;
      document.getElementById('art-summary').value = art.summary || '';
      document.getElementById('art-content').value = art.content || '';
      document.getElementById('art-tags').value = (art.tags || []).join(', ');
      document.getElementById('article-modal-title').textContent = 'Chỉnh Sửa Bài Viết Cẩm Nang';
      DOM.articleModal.classList.add('open');
    },
    deleteArticle: async (artId) => {
      if (confirm('Bạn có chắc muốn xóa bài viết cẩm nang này không?')) {
        await apiFetch(`/admin/handbook/${artId}`, { method: 'DELETE' });
        STATE.articles = STATE.articles.filter(a => a.id !== artId);
        showToast('Đã xóa bài viết cẩm nang!', 'success');
        renderHandbookArticles();
        updateBadges();
      }
    },
    editTask: (taskId) => {
      const task = STATE.tasks.find(t => t.id === taskId);
      if (!task) return;
      document.getElementById('task-id').value = task.id;
      document.getElementById('task-title').value = task.title;
      document.getElementById('task-phase').value = task.phase;
      document.getElementById('task-pillar').value = task.pillar;
      document.getElementById('task-duration').value = task.duration_minutes || 15;
      document.getElementById('task-unlock-day').value = task.unlock_day || 1;
      document.getElementById('task-desc').value = task.description || '';
      document.getElementById('task-modal-title').textContent = 'Chỉnh Sửa Nhiệm Vụ Thích Nghi';
      DOM.taskModal.classList.add('open');
    },
    reviewCatalog
  };

  // ─── Login Form Submission Handler ───────────────────────────────────────────
  if (DOM.loginForm) {
    DOM.loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = (DOM.loginEmail ? DOM.loginEmail.value : '').trim();
      const password = (DOM.loginPassword ? DOM.loginPassword.value : '').trim();

      if (!email || !password) {
        if (DOM.loginError) {
          DOM.loginError.textContent = 'Vui lòng nhập đầy đủ email và mật khẩu.';
          DOM.loginError.style.display = 'block';
        }
        return;
      }

      if (DOM.btnLoginSubmit) {
        DOM.btnLoginSubmit.disabled = true;
        DOM.btnLoginSubmit.innerHTML = '<span>Đang xác thực...</span>';
      }
      if (DOM.loginError) DOM.loginError.style.display = 'none';

      try {
        const resp = await fetch(`${STATE.apiBaseUrl}/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password })
        });

        const data = await resp.json().catch(() => ({}));

        if (!resp.ok) {
          const msg = data.detail || 'Email hoặc mật khẩu không chính xác.';
          if (DOM.loginError) {
            DOM.loginError.textContent = msg;
            DOM.loginError.style.display = 'block';
          }
          return;
        }

        const userRole = (data.user && data.user.role) ? (data.user.role.value || data.user.role) : '';
        if (userRole !== 'admin') {
          if (DOM.loginError) {
            DOM.loginError.textContent = `Tài khoản (${data.user.email}) có phân quyền sinh viên, không có quyền quản trị viên. Vui lòng đăng nhập bằng tài khoản Admin.`;
            DOM.loginError.style.display = 'block';
          }
          return;
        }

        // Lưu JWT token của tài khoản admin
        localStorage.setItem('enigma_admin_token', data.access_token);
        localStorage.setItem('enigma_admin_user', JSON.stringify(data.user));
        STATE.adminToken = data.access_token;

        updateAdminProfileUI();
        hideLoginScreen();
        showToast(`Đăng nhập thành công! Xin chào ${data.user.full_name || data.user.email}`, 'success');
        await loadAllData();
      } catch (err) {
        if (DOM.loginError) {
          DOM.loginError.textContent = `Không thể kết nối tới máy chủ (${err.message}). Vui lòng thử lại.`;
          DOM.loginError.style.display = 'block';
        }
      } finally {
        if (DOM.btnLoginSubmit) {
          DOM.btnLoginSubmit.disabled = false;
          DOM.btnLoginSubmit.innerHTML = '<span>Đăng Nhập Quản Trị</span>';
        }
      }
    });
  }

  // ─── Initialize App on Page Load ──────────────────────────────────────────────
  
  // Periodic auto-refresh for crisis flags (every 30 seconds)
  setInterval(() => {
    if (STATE.adminToken && !STATE.isDemoMode) {
      loadCrisisFlags();
    }
  }, 30000);

  document.addEventListener('DOMContentLoaded', () => {
    if (!STATE.adminToken) {
      showLoginScreen();
    } else {
      updateAdminProfileUI();
      hideLoginScreen();
      loadAllData();
    }
  });

})();
