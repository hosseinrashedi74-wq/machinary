import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MashinaryarApp());
}

const Color navy = Color(0xFF17324D);
const Color teal = Color(0xFF087E8B);
const Color bg = Color(0xFFF4F7FA);

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
  });

  double totalScore(ScoringFormula formula) {
    final totalWeight = formula.timelyWeight + formula.qualityWeight + formula.safetyWeight;
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

  EquipmentItem({
    required this.tag,
    required this.name,
    required this.unit,
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
    this.spareParts = '',
    List<String>? assignedPersonnelNames,
    this.createdBy = 'کارشناس ماشینری',
    this.approvedBy = '',
    required this.createdAt,
  }) : assignedPersonnelNames = assignedPersonnelNames ?? [];
}

class DailyActivityRow {
  String equipmentTag;
  String activityDescription;
  List<String> personnelNames;
  String sparePartsUsed;
  double hours;

  DailyActivityRow({
    required this.equipmentTag,
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
  List<DailyActivityRow> activities;

  DailyShiftReport({
    required this.id,
    required this.shiftTitle,
    required this.reportDate,
    required this.submittedBy,
    this.isApproved = false,
    required this.activities,
  });
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
        scaffoldBackgroundColor: bg,
        primaryColor: navy,
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 2,
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
  final contractTypes = ['رسمی', 'قراردادی', 'پیمانکاری', 'روزمزد'];
  final scoringFormula = ScoringFormula();

  late List<AppUser> users;
  late AppUser currentUser;
  late List<EquipmentItem> equipments;
  late List<WorkOrder> orders;
  late List<DailyShiftReport> dailyReports;

  @override
  void initState() {
    super.initState();
    users = [
      AppUser(id: 'U1', personnelCode: '1001', name: 'مهندس رضایی', role: 'مدیر سیستم', specialty: 'مدیریت ماشینری', contractType: 'رسمی'),
      AppUser(id: 'U2', personnelCode: '2045', name: 'مهندس کریمی', role: 'کارشناس ماشینری', specialty: 'تجهیزات دوار', contractType: 'رسمی'),
      AppUser(id: 'U3', personnelCode: '3012', name: 'استاد بهرامی', role: 'تأییدکننده', specialty: 'سرپرست شیفت', contractType: 'قراردادی'),
      AppUser(id: 'U4', personnelCode: '4108', name: 'علی محمدی', role: 'تعمیرکار', specialty: 'مکانیک پمپ', contractType: 'پیمانکاری'),
    ];
    currentUser = users.first;

    equipments = [
      EquipmentItem(tag: 'P_32007', name: 'پمپ خوراک ۳۲۰', unit: 'واحد ۳۲۰'),
      EquipmentItem(tag: 'P_32053', name: 'پمپ رزرو سیرکولاسیون', unit: 'واحد ۳۲۰'),
      EquipmentItem(tag: 'P_21002', name: 'پمپ ۲۱۰', unit: 'واحد ۲۱۰'),
      EquipmentItem(tag: 'P_17003', name: 'پمپ خنک‌کننده', unit: 'واحد ۱۷۰'),
    ];

    orders = [
      WorkOrder(
        workOrderNumber: '4050132007',
        permitNumber: 'PRM-1405-112',
        tag: 'P_32007',
        title: 'نصب و هم‌راستاسازی با لیزر',
        status: 'در حال انجام',
        priority: 'بالا',
        details: 'نیاز به شیم‌گذاری و لاینینگ شفت.',
        assignedPersonnelNames: ['علی محمدی'],
        createdAt: '۱۴۰۵/۰۷/۲۸',
      ),
      WorkOrder(
        workOrderNumber: '4050132053',
        permitNumber: 'PRM-1405-118',
        tag: 'P_32053',
        title: 'مونتاژ پمپ رزرو',
        status: 'جدید',
        priority: 'متوسط',
        assignedPersonnelNames: ['علی محمدی'],
        createdAt: '۱۴۰۵/۰۷/۲۹',
      ),
    ];

    dailyReports = [
      DailyShiftReport(
        id: 'REP-1',
        shiftTitle: 'روزکار',
        reportDate: '۱۴۰۵/۰۷/۳۰',
        submittedBy: 'علی محمدی',
        isApproved: true,
        activities: [
          DailyActivityRow(
            equipmentTag: 'P_32007',
            activityDescription: 'آچارکشی پیچ پایه و الاینمنت',
            personnelNames: ['علی محمدی'],
            sparePartsUsed: 'شیم استیل ۰.۲',
            hours: 4.0,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildDailyReport(),
      _buildPersonnel(),
      _buildReports(),
      if (currentUser.role == 'مدیر سیستم') _buildAdmin(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('ماشینریار (${currentUser.role})', style: const TextStyle(fontSize: 16)),
        actions: [
          PopupMenuButton<AppUser>(
            icon: const Icon(Icons.switch_account),
            onSelected: (u) => setState(() => currentUser = u),
            itemBuilder: (_) => users.map((u) => PopupMenuItem(value: u, child: Text(u.name))).toList(),
          ),
        ],
      ),
      body: pages[currentTab >= pages.length ? 0 : currentTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab >= pages.length ? 0 : currentTab,
        onTap: (i) => setState(() => currentTab = i),
        selectedItemColor: teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'داشبورد'),
          const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'گزارش شیفت'),
          const BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'پرسنل'),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'خروجی'),
          if (currentUser.role == 'مدیر سیستم')
            const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'مدیریت'),
        ],
      ),
    );
  }

  Widget _buildDashboard() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('دستورکارها: ${orders.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('گزارش شیفت: ${dailyReports.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: teal)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...orders.map((o) => Card(
                child: ListTile(
                  title: Text('${o.tag} — ${o.title}'),
                  subtitle: Text('شماره ۱۰ رقمی: ${o.workOrderNumber} | وضعیت: ${o.status}'),
                  trailing: Chip(label: Text(o.priority)),
                ),
              )),
        ],
      );

  Widget _buildDailyReport() => ListView(
        padding: const EdgeInsets.all(16),
        children: dailyReports
            .map((r) => Card(
                  child: ListTile(
                    title: Text('شیفت: ${r.shiftTitle} (${r.reportDate})'),
                    subtitle: Text('ثبت‌کننده: ${r.submittedBy}\nشرح: ${r.activities.first.activityDescription}'),
                  ),
                ))
            .toList(),
      );

  Widget _buildPersonnel() => ListView(
        padding: const EdgeInsets.all(16),
        children: users
            .map((u) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: navy,
                      child: Text(u.totalScore(scoringFormula).toInt().toString(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(u.name),
                    subtitle: Text('قرارداد: ${u.contractType} | تخصص: ${u.specialty}'),
                  ),
                ))
            .toList(),
      );

  Widget _buildReports() => Center(
        child: ElevatedButton.icon(
          onPressed: () {
            final csv = users.map((u) => '${u.personnelCode},${u.name},${u.contractType}').join('\n');
            Clipboard.setData(ClipboardData(text: csv));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خروجی کپی شد.')));
          },
          icon: const Icon(Icons.copy),
          label: const Text('کپی خروجی داده‌ها'),
        ),
      );

  Widget _buildAdmin() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('تنظیمات پایه و مدیریت نقش‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 8,
            children: contractTypes.map((c) => Chip(label: Text(c))).toList(),
          ),
        ],
      );
}
