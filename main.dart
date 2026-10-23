import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MashinaryarApp());
}

const Color navy = Color(0xFF17324D);
const Color teal = Color(0xFF087E8B);
const Color bg = Color(0xFFF4F7FA);

// ============================================================================
// 1. DATA MODELS (مدل‌های داده ساختاریافته)
// ============================================================================

class AppUser {
  String id;
  String personnelCode;
  String name;
  String role;
  String specialty;
  String contractType;
  String password;
  double timelyScore;
  double qualityScore;
  double safetyScore;
  List<String> scoreLogs;

  AppUser({
    required this.id,
    required this.personnelCode,
    required this.name,
    required this.role,
    required this.specialty,
    required this.contractType,
    this.password = '1234',
    this.timelyScore = 85,
    this.qualityScore = 85,
    this.safetyScore = 90,
    List<String>? scoreLogs,
  }) : scoreLogs = scoreLogs ?? [];

  double totalScore(ScoringFormula formula) {
    final totalWeight =
        formula.timelyWeight + formula.qualityWeight + formula.safetyWeight;
    if (totalWeight <= 0) return 0;
    return ((timelyScore * formula.timelyWeight) +
            (qualityScore * formula.qualityWeight) +
            (safetyScore * formula.safetyWeight)) /
        totalWeight;
  }
}

class EquipmentItem {
  String tag;
  String name;
  String unit;
  String type;

  EquipmentItem({
    required this.tag,
    required this.name,
    required this.unit,
    this.type = 'پمپ / دوار',
  });

  String get displayLabel => '$tag — $name ($unit)';
}

class WorkOrder {
  String workOrderNumber;
  String permitNumber;
  String maintenanceType;
  String tag;
  String title;
  String status;
  String priority;
  String details;
  String failureCause;
  String spareParts;
  List<String> assignedPersonnelNames;
  String createdBy;
  String approvedBy;
  String createdAt;

  WorkOrder({
    required this.workOrderNumber,
    this.permitNumber = '',
    this.maintenanceType = 'CM (اصلاحی)',
    required this.tag,
    required this.title,
    required this.status,
    required this.priority,
    this.details = '',
    this.failureCause = '',
    this.spareParts = '',
    List<String>? assignedPersonnelNames,
    this.createdBy = 'کارشناس ماشینری',
    this.approvedBy = '',
    required this.createdAt,
  }) : assignedPersonnelNames = assignedPersonnelNames ?? [];
}

class DailyActivityRow {
  String equipmentTag;
  String workOrderNumber;
  String activityDescription;
  List<String> personnelNames;
  String sparePartsUsed;
  double hours;

  DailyActivityRow({
    required this.equipmentTag,
    this.workOrderNumber = '',
    required this.activityDescription,
    required this.personnelNames,
    this.sparePartsUsed = '',
    required this.hours,
  });
}

class DailyShiftReport {
  String id;
  String shiftTitle;
  String reportDate;
  String submittedBy;
  bool isApproved;
  String approvedBy;
  List<DailyActivityRow> activities;

  DailyShiftReport({
    required this.id,
    required this.shiftTitle,
    required this.reportDate,
    required this.submittedBy,
    this.isApproved = false,
    this.approvedBy = '',
    required this.activities,
  });

  double get totalHours =>
      activities.fold(0.0, (sum, item) => sum + item.hours);
}

class ScoringFormula {
  double timelyWeight;
  double qualityWeight;
  double safetyWeight;

  ScoringFormula({
    this.timelyWeight = 30,
    this.qualityWeight = 40,
    this.safetyWeight = 30,
  });
}

// ============================================================================
// 2. APPLICATION ROOT
// ============================================================================

class MashinaryarApp extends StatelessWidget {
  const MashinaryarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ماشینریار',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: navy,
          secondary: teal,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentTab = 0;
  bool isLoggedIn = true;
  bool onlineSyncEnabled = true;

  final List<String> contractTypes = [
    'رسمی',
    'قراردادی (مدت‌معین)',
    'پیمانکاری (ارکان ثالث)',
    'روزمزد / پروژه‌ای',
  ];

  ScoringFormula scoringFormula = ScoringFormula();

  late List<AppUser> users;
  late AppUser currentUser;
  late List<EquipmentItem> equipments;
  late List<WorkOrder> orders;
  late List<DailyShiftReport> dailyReports;

  @override
  void initState() {
    super.initState();
    _initSampleData();
  }

  void _initSampleData() {
    users = [
      AppUser(id: 'U1', personnelCode: '1001', name: 'مهندس رضایی (مدیر)', role: 'مدیر سیستم', specialty: 'مدیریت ماشینری', contractType: 'رسمی', timelyScore: 95, qualityScore: 96, safetyScore: 98),
      AppUser(id: 'U2', personnelCode: '2045', name: 'مهندس کریمی', role: 'کارشناس ماشینری', specialty: 'تجهیزات دوار', contractType: 'رسمی', timelyScore: 90, qualityScore: 92, safetyScore: 94),
      AppUser(id: 'U3', personnelCode: '3012', name: 'استاد بهرامی (سرپرست)', role: 'تأییدکننده', specialty: 'سرپرست شیفت مکانیک', contractType: 'قراردادی (مدت‌معین)', timelyScore: 88, qualityScore: 91, safetyScore: 95),
      AppUser(id: 'U4', personnelCode: '4108', name: 'علی محمدی (مکانیک ۱)', role: 'تعمیرکار', specialty: 'مکانیک پمپ و کمپرسور', contractType: 'پیمانکاری (ارکان ثالث)', timelyScore: 84, qualityScore: 88, safetyScore: 86),
    ];
    currentUser = users.first;

    equipments = [
      EquipmentItem(tag: 'P_32007', name: 'پمپ خوراک واحد ۳۲۰', unit: 'واحد ۳۲۰'),
      EquipmentItem(tag: 'P_32053', name: 'پمپ رزرو سیرکولاسیون', unit: 'واحد ۳۲۰'),
      EquipmentItem(tag: 'P_21002', name: 'پمپ تقویت فشار ۲۱۰', unit: 'واحد ۲۱۰'),
      EquipmentItem(tag: 'P_17003', name: 'پمپ سرویس خنک‌کننده', unit: 'واحد ۱۷۰'),
    ];

    orders = [
      WorkOrder(
        workOrderNumber: '4050132007',
        permitNumber: 'PRM-1405-112',
        tag: 'P_32007',
        title: 'نصب و هم‌راستاسازی با لیزر',
        status: 'در حال انجام',
        priority: 'بالا',
        details: 'ارتعاش بالای یاتاقان سمت کوپلینگ؛ نیاز به بررسی شفت و لاینینگ مجدد.',
        spareParts: 'شیم استیل ۰.۲ و ۰.۵ میلی‌متر',
        assignedPersonnelNames: ['علی محمدی (مکانیک ۱)'],
        createdBy: 'مهندس کریمی',
        createdAt: '۱۴۰۵/۰۷/۲۸',
      ),
    ];

    dailyReports = [
      DailyShiftReport(
        id: 'REP-101',
        shiftTitle: 'روزکار',
        reportDate: '۱۴۰۵/۰۷/۳۰',
        submittedBy: 'علی محمدی (مکانیک ۱)',
        isApproved: true,
        approvedBy: 'استاد بهرامی (سرپرست)',
        activities: [
          DailyActivityRow(
            equipmentTag: 'P_32007',
            activityDescription: 'باز کردن گارد کوپلینگ و هم‌راستاسازی اولیه',
            personnelNames: ['علی محمدی (مکانیک ۱)'],
            sparePartsUsed: 'شیم استیل',
            hours: 4.5,
          ),
        ],
      ),
    ];
  }

  List<WorkOrder> get visibleOrders {
    if (currentUser.role == 'تعمیرکار') {
      return orders.where((o) => o.assignedPersonnelNames.contains(currentUser.name)).toList();
    }
    return orders;
  }

  bool get canCreateWorkOrder =>
      currentUser.role == 'مدیر سیستم' ||
      currentUser.role == 'کارشناس ماشینری' ||
      currentUser.role == 'تأییدکننده';

  bool get isAdmin => currentUser.role == 'مدیر سیستم';

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return LoginScreen(
        users: users,
        onLogin: (user) => setState(() {
          currentUser = user;
          isLoggedIn = true;
          currentTab = 0;
        }),
      );
    }

    final List<Widget> pages = [
      DashboardTab(
        orders: visibleOrders,
        allOrders: orders,
        dailyReports: dailyReports,
        currentUser: currentUser,
        equipments: equipments,
        users: users,
        onNewOrder: _openNewOrderDialog,
        onOpenOrderDetail: _openOrderDetail,
      ),
      DailyReportTab(
        reports: dailyReports,
        equipments: equipments,
        orders: orders,
        users: users,
        currentUser: currentUser,
        onAddReport: (rep) => setState(() => dailyReports.insert(0, rep)),
        onApproveReport: (rep) => setState(() {
          rep.isApproved = true;
          rep.approvedBy = currentUser.name;
        }),
      ),
      PeopleScoreTab(
        users: users,
        contractTypes: contractTypes,
        formula: scoringFormula,
        currentUser: currentUser,
        onUpdateUserScore: (user, timely, quality, safety, reason) {
          setState(() {
            user.timelyScore = timely;
            user.qualityScore = quality;
            user.safetyScore = safety;
            user.scoreLogs.insert(0, 'امتیاز جدید ویرایش شد (علت: $reason)');
          });
        },
      ),
      ReportsExportTab(
        orders: orders,
        dailyReports: dailyReports,
        users: users,
        contractTypes: contractTypes,
        equipments: equipments,
        formula: scoringFormula,
        currentUser: currentUser,
      ),
      if (isAdmin)
        AdminPanelTab(
          users: users,
          contractTypes: contractTypes,
          equipments: equipments,
          formula: scoringFormula,
          onAddContractType: (ct) => setState(() {
            if (!contractTypes.contains(ct)) contractTypes.add(ct);
          }),
          onRemoveContractType: (ct) => setState(() {
            if (contractTypes.length > 1) contractTypes.remove(ct);
          }),
          onAddUser: (u) => setState(() => users.add(u)),
          onAddEquipment: (eq) => setState(() {
            equipments.removeWhere((e) => e.tag.toUpperCase() == eq.tag.toUpperCase());
            equipments.insert(0, eq);
          }),
          onBulkAddEquipments: (list) => setState(() {
            for (final eq in list) {
              equipments.removeWhere((e) => e.tag.toUpperCase() == eq.tag.toUpperCase());
              equipments.add(eq);
            }
          }),
        ),
    ];

    if (currentTab >= pages.length) currentTab = 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ماشینریار (نسخه عملیاتی)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${currentUser.name} • ${currentUser.role}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          PopupMenuButton<AppUser>(
            icon: const Icon(Icons.switch_account_outlined),
            onSelected: (u) => setState(() {
              currentUser = u;
              if (!isAdmin && currentTab == 4) currentTab = 0;
            }),
            itemBuilder: (_) => users.map((u) => PopupMenuItem<AppUser>(value: u, child: Text('${u.name} (${u.role})'))).toList(),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => setState(() => isLoggedIn = false)),
        ],
      ),
      body: pages[currentTab],
      floatingActionButton: (currentTab == 0 && canCreateWorkOrder)
          ? FloatingActionButton.extended(
              backgroundColor: teal,
              foregroundColor: Colors.white,
              onPressed: _openNewOrderDialog,
              icon: const Icon(Icons.add),
              label: const Text('ثبت دستورکار جدید'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (idx) => setState(() => currentTab = idx),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'داشبورد'),
          const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'گزارش روزانه'),
          const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'پرسنل'),
          const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'خروجی'),
          if (isAdmin) const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'مدیریت'),
        ],
      ),
    );
  }

  Future<void> _openNewOrderDialog() async {
    final result = await Navigator.push<WorkOrder>(
      context,
      MaterialPageRoute(builder: (_) => NewWorkOrderScreen(equipments: equipments, users: users, currentUser: currentUser)),
    );
    if (result != null) setState(() => orders.insert(0, result));
  }

  Future<void> _openOrderDetail(WorkOrder order) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(order: order, currentUser: currentUser, users: users, onChanged: () => setState(() {}))),
    );
    setState(() {});
  }
}

// ============================================================================
// 3. LOGIN SCREEN
// ============================================================================
class LoginScreen extends StatefulWidget {
  final List<AppUser> users;
  final ValueChanged<AppUser> onLogin;
  const LoginScreen({super.key, required this.users, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final codeCtrl = TextEditingController(text: '1001');
  final passCtrl = TextEditingController(text: '1234');
  String errorMsg = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.precision_manufacturing, size: 52, color: teal),
                  const Text('سامانه جامع ماشینریار', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
                  const SizedBox(height: 22),
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'کد پرسنلی', prefixIcon: Icon(Icons.badge_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور', prefixIcon: Icon(Icons.lock_outline))),
                  if (errorMsg.isNotEmpty) Text(errorMsg, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: teal),
                    onPressed: () {
                      final found = widget.users.where((u) => u.personnelCode == codeCtrl.text.trim() && u.password == passCtrl.text.trim());
                      if (found.isEmpty) setState(() => errorMsg = 'کد یا رمز اشتباه است');
                      else widget.onLogin(found.first);
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('ورود به سامانه'),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 6,
                    children: widget.users.map((u) => ActionChip(label: Text('${u.role}: ${u.name}'), onPressed: () => widget.onLogin(u))).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. TAB 1: DASHBOARD
// ============================================================================
class DashboardTab extends StatefulWidget {
  final List<WorkOrder> orders;
  final List<WorkOrder> allOrders;
  final List<DailyShiftReport> dailyReports;
  final AppUser currentUser;
  final List<EquipmentItem> equipments;
  final List<AppUser> users;
  final VoidCallback onNewOrder;
  final ValueChanged<WorkOrder> onOpenOrderDetail;

  const DashboardTab({
    super.key,
    required this.orders,
    required this.allOrders,
    required this.dailyReports,
    required this.currentUser,
    required this.equipments,
    required this.users,
    required this.onNewOrder,
    required this.onOpenOrderDetail,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String searchQuery = '';
  String statusFilter = 'همه';

  @override
  Widget build(BuildContext context) {
    final filteredOrders = widget.orders.where((o) {
      final matchesStatus = statusFilter == 'همه' || o.status == statusFilter;
      final matchesSearch = searchQuery.isEmpty || o.workOrderNumber.contains(searchQuery) || o.tag.contains(searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [const Text('کل دستورکارها'), Text('${widget.allOrders.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                Column(children: [const Text('گزارش‌های شیفت'), Text('${widget.dailyReports.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: teal))]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(labelText: 'جستجوی دستورکار', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => searchQuery = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['همه', 'جدید', 'در حال انجام', 'منتظر تأیید', 'تکمیل‌شده']
                .map((st) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(label: Text(st), selected: statusFilter == st, onSelected: (_) => setState(() => statusFilter = st)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        ...filteredOrders.map((o) => Card(
              child: ListTile(
                onTap: () => widget.onOpenOrderDetail(o),
                title: Text('${o.tag} — ${o.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('کد: ${o.workOrderNumber} | وضعیت: ${o.status}\nنفرات: ${o.assignedPersonnelNames.join(", ")}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_left),
              ),
            )),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }
}

// ============================================================================
// 5. NEW WORK ORDER FORM
// ============================================================================
class NewWorkOrderScreen extends StatefulWidget {
  final List<EquipmentItem> equipments;
  final List<AppUser> users;
  final AppUser currentUser;
  const NewWorkOrderScreen({super.key, required this.equipments, required this.users, required this.currentUser});
  @override
  State<NewWorkOrderScreen> createState() => _NewWorkOrderScreenState();
}

class _NewWorkOrderScreenState extends State<NewWorkOrderScreen> {
  final woNumberCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  String? selectedTag;
  List<String> selectedPersonnel = [];

  @override
  void initState() {
    super.initState();
    woNumberCtrl.text = '4050${(100000 + Random().nextInt(899999))}';
    if (widget.equipments.isNotEmpty) selectedTag = widget.equipments.first.tag;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت دستورکار جدید')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: woNumberCtrl, decoration: const InputDecoration(labelText: 'شماره دستورکار (۱۰ رقمی)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedTag,
            decoration: const InputDecoration(labelText: 'تگ تجهیز'),
            items: widget.equipments.map((e) => DropdownMenuItem(value: e.tag, child: Text(e.displayLabel))).toList(),
            onChanged: (v) => setState(() => selectedTag = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'عنوان کار تعمیراتی')),
          const SizedBox(height: 16),
          const Text('نفرات انجام‌دهنده:'),
          Wrap(
            spacing: 6,
            children: widget.users.map((u) => FilterChip(
                  selected: selectedPersonnel.contains(u.name),
                  label: Text(u.name),
                  onSelected: (v) => setState(() { v ? selectedPersonnel.add(u.name) : selectedPersonnel.remove(u.name); }),
                )).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.isEmpty || selectedTag == null) return;
              Navigator.pop(context, WorkOrder(
                workOrderNumber: woNumberCtrl.text,
                tag: selectedTag!,
                title: titleCtrl.text,
                status: 'جدید',
                priority: 'متوسط',
                assignedPersonnelNames: selectedPersonnel,
                createdBy: widget.currentUser.name,
                createdAt: '۱۴۰۵/۰۷/۳۰',
              ));
            },
            child: const Text('ذخیره و ثبت دستورکار'),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// 6. WORK ORDER DETAIL
// ============================================================================
class WorkOrderDetailScreen extends StatefulWidget {
  final WorkOrder order;
  final AppUser currentUser;
  final List<AppUser> users;
  final VoidCallback onChanged;
  const WorkOrderDetailScreen({super.key, required this.order, required this.currentUser, required this.users, required this.onChanged});
  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  late TextEditingController detailsCtrl;

  @override
  void initState() {
    super.initState();
    detailsCtrl = TextEditingController(text: widget.order.details);
  }

  void _changeStatus(String status) {
    setState(() {
      widget.order.status = status;
      widget.order.details = detailsCtrl.text;
    });
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('وضعیت به $status تغییر یافت')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('دستورکار ${widget.order.workOrderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تگ تجهیز: ${widget.order.tag}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('عنوان: ${widget.order.title}'),
                  Text('وضعیت فعلی: ${widget.order.status}', style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: detailsCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'شرح خرابی و اقدامات')),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              ElevatedButton(onPressed: () => _changeStatus('در حال انجام'), child: const Text('در حال انجام')),
              ElevatedButton(onPressed: () => _changeStatus('منتظر قطعه'), child: const Text('منتظر قطعه')),
              ElevatedButton(onPressed: () => _changeStatus('منتظر تأیید'), child: const Text('ارسال برای تأیید')),
              if (widget.currentUser.role == 'مدیر سیستم' || widget.currentUser.role == 'تأییدکننده')
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green), onPressed: () => _changeStatus('تکمیل‌شده'), child: const Text('تأیید نهایی')),
            ],
          )
        ],
      ),
    );
  }
}

// ============================================================================
// 7. TAB 2: DAILY REPORT FORM
// ============================================================================
class DailyReportTab extends StatefulWidget {
  final List<DailyShiftReport> reports;
  final List<EquipmentItem> equipments;
  final List<WorkOrder> orders;
  final List<AppUser> users;
  final AppUser currentUser;
  final ValueChanged<DailyShiftReport> onAddReport;
  final ValueChanged<DailyShiftReport> onApproveReport;
  const DailyReportTab({super.key, required this.reports, required this.equipments, required this.orders, required this.users, required this.currentUser, required this.onAddReport, required this.onApproveReport});
  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  String shiftTitle = 'روزکار';
  final actCtrl = TextEditingController();
  String? selectedTag;

  @override
  void initState() {
    super.initState();
    if (widget.equipments.isNotEmpty) selectedTag = widget.equipments.first.tag;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFE0F2F1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ثبت گزارش شیفت جدید', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(labelText: 'تگ تجهیز کار شده'),
                  items: widget.equipments.map((e) => DropdownMenuItem(value: e.tag, child: Text(e.displayLabel))).toList(),
                  onChanged: (v) => setState(() => selectedTag = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: actCtrl, decoration: const InputDecoration(labelText: 'شرح کار انجام شده')),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    if (actCtrl.text.isEmpty || selectedTag == null) return;
                    widget.onAddReport(DailyShiftReport(
                      id: 'R${Random().nextInt(9999)}',
                      shiftTitle: shiftTitle,
                      reportDate: '۱۴۰۵/۰۷/۳۰',
                      submittedBy: widget.currentUser.name,
                      activities: [DailyActivityRow(equipmentTag: selectedTag!, activityDescription: actCtrl.text, personnelNames: [widget.currentUser.name], hours: 2.0)],
                    ));
                    actCtrl.clear();
                  },
                  child: const Text('ثبت در گزارش شیفت'),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('گزارش‌های ثبت‌شده:'),
        ...widget.reports.map((r) => Card(
              child: ListTile(
                title: Text('شیفت: ${r.shiftTitle} (${r.reportDate})'),
                subtitle: Text('توسط: ${r.submittedBy}\nفعالیت: ${r.activities.first.activityDescription}'),
                isThreeLine: true,
                trailing: r.isApproved ? const Icon(Icons.check_circle, color: Colors.green) : (widget.currentUser.role == 'مدیر سیستم' ? TextButton(onPressed: () => widget.onApproveReport(r), child: const Text('تأیید')) : const Icon(Icons.pending_actions)),
              ),
            ))
      ],
    );
  }
}

// ============================================================================
// 8. TAB 3: PERSONNEL
// ============================================================================
class PeopleScoreTab extends StatelessWidget {
  final List<AppUser> users;
  final List<String> contractTypes;
  final ScoringFormula formula;
  final AppUser currentUser;
  final Function onUpdateUserScore;
  const PeopleScoreTab({super.key, required this.users, required this.contractTypes, required this.formula, required this.currentUser, required this.onUpdateUserScore});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: users.map((u) => Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: navy, child: Text(u.totalScore(formula).toInt().toString(), style: const TextStyle(color: Colors.white))),
              title: Text(u.name),
              subtitle: Text('قرارداد: ${u.contractType} | تخصص: ${u.specialty}'),
              trailing: const Icon(Icons.star, color: Colors.amber),
            ),
          )).toList(),
    );
  }
}

// ============================================================================
// 9. TAB 4: REPORTS EXPORT
// ============================================================================
class ReportsExportTab extends StatelessWidget {
  final List<WorkOrder> orders;
  final List<DailyShiftReport> dailyReports;
  final List<AppUser> users;
  final List<String> contractTypes;
  final List<EquipmentItem> equipments;
  final ScoringFormula formula;
  final AppUser currentUser;
  const ReportsExportTab({super.key, required this.orders, required this.dailyReports, required this.users, required this.contractTypes, required this.equipments, required this.formula, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {
          final csv = users.map((u) => '${u.personnelCode},${u.name},${u.contractType}').join('\n');
          Clipboard.setData(ClipboardData(text: csv));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خروجی اکسل در کلیپ‌بورد کپی شد.')));
        },
        icon: const Icon(Icons.copy),
        label: const Text('کپی خروجی داده‌ها'),
      ),
    );
  }
}

// ============================================================================
// 10. TAB 5: ADMIN PANEL
// ============================================================================
class AdminPanelTab extends StatefulWidget {
  final List<AppUser> users;
  final List<String> contractTypes;
  final List<EquipmentItem> equipments;
  final ScoringFormula formula;
  final ValueChanged<String> onAddContractType;
  final ValueChanged<String> onRemoveContractType;
  final ValueChanged<AppUser> onAddUser;
  final ValueChanged<EquipmentItem> onAddEquipment;
  final ValueChanged<List<EquipmentItem>> onBulkAddEquipments;
  const AdminPanelTab({super.key, required this.users, required this.contractTypes, required this.equipments, required this.formula, required this.onAddContractType, required this.onRemoveContractType, required this.onAddUser, required this.onAddEquipment, required this.onBulkAddEquipments});
  @override
  State<AdminPanelTab> createState() => _AdminPanelTabState();
}

class _AdminPanelTabState extends State<AdminPanelTab> {
  final nameCtrl = TextEditingController();
  final tagCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تعریف تجهیز جدید', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: 'تگ تجهیز (مثل P-101)')),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    if (tagCtrl.text.isNotEmpty) widget.onAddEquipment(EquipmentItem(tag: tagCtrl.text, name: 'تجهیز جدید', unit: 'عمومی'));
                    tagCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تجهیز اضافه شد')));
                  },
                  child: const Text('افزودن تجهیز'),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تعریف پرسنل جدید', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) widget.onAddUser(AppUser(id: 'U${Random().nextInt(99)}', personnelCode: '9999', name: nameCtrl.text, role: 'تعمیرکار', specialty: 'مکانیک', contractType: 'پیمانکاری'));
                    nameCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کاربر اضافه شد')));
                  },
                  child: const Text('افزودن پرسنل'),
                )
              ],
            ),
          ),
        )
      ],
    );
  }
}
