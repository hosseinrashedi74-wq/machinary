import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MashinaryarApp());
}

const Color navy = Color(0xFF17324D);
const Color teal = Color(0xFF087E8B);
const Color bg = Color(0xFFF4F7FA);
const Color amberAccent = Color(0xFFD97706);

// ============================================================================
// 1. DATA MODELS (مدل‌های داده ساختاریافته و قابل توسعه)
// ============================================================================

class AppUser {
  String id;
  String personnelCode;
  String name;
  String role; // مدیر سیستم | کارشناس ماشینری | تأییدکننده | تعمیرکار
  String specialty; // مکانیک | تراشکار | پایپینگ | روانکار | ابزاردقیق
  String contractType; // رسمی | قراردادی | پیمانکاری | روزمزد و...
  String password;
  double timelyScore; // 0..100
  double qualityScore; // 0..100
  double safetyScore; // 0..100
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
    final totalWeight = formula.timelyWeight + formula.qualityWeight + formula.safetyWeight;
    if (totalWeight <= 0) return 0;
    return ((timelyScore * formula.timelyWeight) +
            (qualityScore * formula.qualityWeight) +
            (safetyScore * formula.safetyWeight)) /
        totalWeight;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personnelCode': personnelCode,
        'name': name,
        'role': role,
        'specialty': specialty,
        'contractType': contractType,
        'timelyScore': timelyScore,
        'qualityScore': qualityScore,
        'safetyScore': safetyScore,
        'scoreLogs': scoreLogs,
      };
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
  String workOrderNumber; // شماره دستورکار ۱۰ رقمی
  String permitNumber; // شماره پرمیت ایمنی
  String maintenanceType; // EM | PM | CM | Overhaul
  String tag; // تگ تجهیز
  String title; // عنوان کار
  String status; // جدید | در حال انجام | منتظر قطعه | منتظر تأیید | تکمیل‌شده | رد شده
  String priority; // عادی | متوسط | بالا | فوری
  String details; // شرح خرابی
  String failureCause; // علت خرابی
  String spareParts; // قطعات مصرفی
  List<String> assignedPersonnelNames; // نفرات انجام دهنده
  String createdBy;
  String approvedBy;
  String rejectionReason;
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
    this.rejectionReason = '',
    required this.createdAt,
  }) : assignedPersonnelNames = assignedPersonnelNames ?? [];
}

class DailyActivityRow {
  String equipmentTag; // تگ تجهیز کار شده
  String workOrderNumber; // شماره دستورکار ۱۰ رقمی مرتبط (اختیاری)
  String activityDescription; // شرح فعالیت انجام شده
  List<String> personnelNames; // نام نفرات انجام دهنده در جلوی هر کار
  String sparePartsUsed; // قطعات مصرفی
  double hours; // نفر-ساعت

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
  String shiftTitle; // هدینگ شیفت کاری: روزکار | شیفت صبح | شیفت عصر | شیفت شب
  String reportDate; // تاریخ گزارش
  String submittedBy; // ثبت کننده
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
  double timelyWeight; // پیش‌فرض 30
  double qualityWeight; // پیش‌فرض 40
  double safetyWeight; // پیش‌فرض 30
  String customNote;

  ScoringFormula({
    this.timelyWeight = 30,
    this.qualityWeight = 40,
    this.safetyWeight = 30,
    this.customNote = 'فرمول استاندارد: گزارش به‌موقع ۳۰٪ • کیفیت ۴۰٪ • ایمنی ۳۰٪',
  });
}

// ============================================================================
// 2. APPLICATION ROOT & CENTRAL STATE
// ============================================================================

class MashinaryarApp extends StatelessWidget {
  const MashinaryarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ماشینریار — نسخه عملیاتی',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: navy, secondary: teal),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
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
  String cloudServerUrl = 'https://api.mashinaryar-company.ir/v1/sync';

  // لیست پویا از انواع قرارداد (قابل ویرایش توسط مدیر سیستم)
  final List<String> contractTypes = [
    'رسمی',
    'قراردادی (مدت‌معین)',
    'پیمانکاری (ارکان ثالث)',
    'روزمزد / پروژه‌ای',
  ];

  // لیست نقش‌های سازمانی
  static const List<String> roles = [
    'مدیر سیستم',
    'کارشناس ماشینری',
    'تأییدکننده',
    'تعمیرکار',
  ];

  // فرمول امتیازدهی پویا (قابل ویرایش در پنل مدیریت)
  ScoringFormula scoringFormula = ScoringFormula();

  // لیست کاربران و پرسنل اولیه
  late List<AppUser> users;
  late AppUser currentUser;

  // لیست تگ تجهیزات (قابل جستجو و ورود گروهی از فایل)
  late List<EquipmentItem> equipments;

  // لیست دستورکارها (شامل شماره دستورکار ۱۰ رقمی)
  late List<WorkOrder> orders;

  // لیست گزارش‌های روزانه (با هدینگ شیفت کاری و ردیف‌های فعالیت)
  late List<DailyShiftReport> dailyReports;

  @override
  void initState() {
    super.initState();
    _initSampleData();
  }

  void _initSampleData() {
    users = [
      AppUser(
        id: 'U1',
        personnelCode: '1001',
        name: 'مهندس رضایی (مدیر)',
        role: 'مدیر سیستم',
        specialty: 'مدیریت ماشینری',
        contractType: 'رسمی',
        timelyScore: 95,
        qualityScore: 96,
        safetyScore: 98,
      ),
      AppUser(
        id: 'U2',
        personnelCode: '2045',
        name: 'مهندس کریمی',
        role: 'کارشناس ماشینری',
        specialty: 'تجهیزات دوار',
        contractType: 'رسمی',
        timelyScore: 90,
        qualityScore: 92,
        safetyScore: 94,
      ),
      AppUser(
        id: 'U3',
        personnelCode: '3012',
        name: 'استاد بهرامی (سرپرست)',
        role: 'تأییدکننده',
        specialty: 'سرپرست شیفت مکانیک',
        contractType: 'قراردادی (مدت‌معین)',
        timelyScore: 88,
        qualityScore: 91,
        safetyScore: 95,
      ),
      AppUser(
        id: 'U4',
        personnelCode: '4108',
        name: 'علی محمدی (مکانیک ۱)',
        role: 'تعمیرکار',
        specialty: 'مکانیک پمپ و کمپرسور',
        contractType: 'پیمانکاری (ارکان ثالث)',
        timelyScore: 84,
        qualityScore: 88,
        safetyScore: 86,
        scoreLogs: ['ثبت اولیه در سیستم: امتیاز ۸۶'],
      ),
      AppUser(
        id: 'U5',
        personnelCode: '4119',
        name: 'حسن عباسی (مکانیک ۲)',
        role: 'تعمیرکار',
        specialty: 'مکانیک و هم‌راستاسازی',
        contractType: 'پیمانکاری (ارکان ثالث)',
        timelyScore: 76,
        qualityScore: 80,
        safetyScore: 78,
        scoreLogs: ['ثبت اولیه در سیستم: امتیاز ۷۸'],
      ),
      AppUser(
        id: 'U6',
        personnelCode: '4205',
        name: 'مهدی نادری (تکنسین ۱)',
        role: 'تعمیرکار',
        specialty: 'تراشکاری و مکانیکال سیل',
        contractType: 'قراردادی (مدت‌معین)',
        timelyScore: 90,
        qualityScore: 94,
        safetyScore: 92,
        scoreLogs: ['ثبت اولیه در سیستم: امتیاز ۹۲'],
      ),
    ];

    currentUser = users.first;

    equipments = [
      EquipmentItem(tag: 'P_32007', name: 'پمپ خوراک واحد ۳۲۰', unit: 'واحد ۳۲۰', type: 'پمپ گریز از مرکز'),
      EquipmentItem(tag: 'P_32053', name: 'پمپ رزرو سیرکولاسیون', unit: 'واحد ۳۲۰', type: 'پمپ دوار'),
      EquipmentItem(tag: 'P_21002', name: 'پمپ تقویت فشار ۲۱۰', unit: 'واحد ۲۱۰', type: 'پمپ طبقاتی'),
      EquipmentItem(tag: 'P_17003', name: 'پمپ سرویس خنک‌کننده', unit: 'واحد ۱۷۰', type: 'پمپ سانتریفیوژ'),
      EquipmentItem(tag: 'C_32001', name: 'کمپرسور گاز فرآیندی', unit: 'واحد ۳۲۰', type: 'کمپرسور'),
      EquipmentItem(tag: 'T_17005', name: 'توربین بخار درایور پمپ', unit: 'واحد ۱۷۰', type: 'توربین'),
    ];

    orders = [
      WorkOrder(
        workOrderNumber: '4050132007',
        permitNumber: 'PRM-1405-112',
        maintenanceType: 'CM (اصلاحی)',
        tag: 'P_32007',
        title: 'نصب و هم‌راستاسازی (Alignment) با لیزر',
        status: 'در حال انجام',
        priority: 'بالا',
        details: 'ارتعاش بالای یاتاقان سمت کوپلینگ؛ نیاز به بررسی شفت و لاینینگ مجدد.',
        failureCause: 'عدم هم‌راستایی پس از تعویض کوپلینگ',
        spareParts: 'شیم استیل ۰.۲ و ۰.۵ میلی‌متر، پیچ پایه',
        assignedPersonnelNames: ['علی محمدی (مکانیک ۱)', 'مهدی نادری (تکنسین ۱)'],
        createdBy: 'مهندس کریمی',
        createdAt: '۱۴۰۵/۰۷/۲۸',
      ),
      WorkOrder(
        workOrderNumber: '4050132053',
        permitNumber: 'PRM-1405-118',
        maintenanceType: 'PM (پیشگیرانه)',
        tag: 'P_32053',
        title: 'مونتاژ پمپ رزرو و تست چرخش دستی',
        status: 'جدید',
        priority: 'متوسط',
        details: 'آماده‌سازی پمپ رزرو جهت جایگزینی در سرویس.',
        failureCause: 'برنامه دوره‌ای PM',
        spareParts: 'اورینگ ویتون، گسکت فلنج، گریس نسوز',
        assignedPersonnelNames: ['حسن عباسی (مکانیک ۲)'],
        createdBy: 'مهندس کریمی',
        createdAt: '۱۴۰۵/۰۷/۲۹',
      ),
      WorkOrder(
        workOrderNumber: '4050121002',
        permitNumber: 'PRM-1405-095',
        maintenanceType: 'EM (اضطراری)',
        tag: 'P_21002',
        title: 'تعویض مکانیکال سیل و بیرینگ پمپ رزرو',
        status: 'منتظر قطعه',
        priority: 'متوسط',
        details: 'نشتی شدید از ناحیه سیل؛ بیرینگ شماره 6310 نیاز به تأمین از انبار دارد.',
        failureCause: 'خوردگی سطوح سیل و استهلاک بیرینگ',
        spareParts: 'مکانیکال سیل تک‌فنر، بلبرینگ 6310 C3',
        assignedPersonnelNames: ['مهدی نادری (تکنسین ۱)'],
        createdBy: 'مهندس رضایی (مدیر)',
        createdAt: '۱۴۰۵/۰۷/۲۷',
      ),
      WorkOrder(
        workOrderNumber: '4050117003',
        permitNumber: 'PRM-1405-120',
        maintenanceType: 'Overhaul (اساسی)',
        tag: 'P_17003',
        title: 'مونتاژ نهایی و نصب در موقعیت سایت',
        status: 'منتظر تأیید',
        priority: 'بالا',
        details: 'مونتاژ کامل در کارگاه مرکزی انجام و روی شاسی نصب گردید. آماده تحویل به سرپرست.',
        failureCause: 'فرسودگی پروانه و بوش شفت',
        spareParts: 'پروانه برنزی، بوش شفت، پکینگ گرافیتی',
        assignedPersonnelNames: ['علی محمدی (مکانیک ۱)', 'حسن عباسی (مکانیک ۲)'],
        createdBy: 'مهندس کریمی',
        createdAt: '۱۴۰۵/۰۷/۳۰',
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
            workOrderNumber: '4050132007',
            activityDescription: 'باز کردن گارد کوپلینگ، کنترل لقی شفت و انجام هم‌راستاسازی اولیه',
            personnelNames: ['علی محمدی (مکانیک ۱)', 'مهدی نادری (تکنسین ۱)'],
            sparePartsUsed: 'شیم استیل ۰.۲ میلی‌متر (۴ عدد)',
            hours: 4.5,
          ),
          DailyActivityRow(
            equipmentTag: 'P_17003',
            workOrderNumber: '4050117003',
            activityDescription: 'بستن فلنج‌های مکش و دهش و تحویل جهت تست گرم',
            personnelNames: ['علی محمدی (مکانیک ۱)', 'حسن عباسی (مکانیک ۲)'],
            sparePartsUsed: 'گسکت اسپیرال وند ۲ اینچ (۲ عدد)، پیچ و مهره استدبولت',
            hours: 3.5,
          ),
        ],
      ),
      DailyShiftReport(
        id: 'REP-102',
        shiftTitle: 'شیفت صبح',
        reportDate: '۱۴۰۵/۰۷/۳۰',
        submittedBy: 'مهدی نادری (تکنسین ۱)',
        isApproved: false,
        activities: [
          DailyActivityRow(
            equipmentTag: 'P_21002',
            workOrderNumber: '4050121002',
            activityDescription: 'دمونتاژ محفظه بیرینگ هوزینگ و اندازه‌گیری تلرانس شفت در کارگاه',
            personnelNames: ['مهدی نادری (تکنسین ۱)'],
            sparePartsUsed: 'کاسه‌نمد 45x65x8، محلول شستشوی صنعتی',
            hours: 5.0,
          ),
        ],
      ),
    ];
  }

  // فیلتر دستورکارها بر اساس نقش کاربر جاری
  List<WorkOrder> get visibleOrders {
    if (currentUser.role == 'تعمیرکار') {
      final myOrders = orders
          .where((o) => o.assignedPersonnelNames.contains(currentUser.name))
          .toList();
      return myOrders.isEmpty ? orders : myOrders;
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
            user.scoreLogs.insert(
              0,
              'توسط ${currentUser.name}: امتیاز جدید ${user.totalScore(scoringFormula).toStringAsFixed(1)} (علت: $reason)',
            );
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
          onlineSyncEnabled: onlineSyncEnabled,
          cloudServerUrl: cloudServerUrl,
          onAddContractType: (ct) => setState(() {
            if (!contractTypes.contains(ct)) contractTypes.add(ct);
          }),
          onRemoveContractType: (ct) => setState(() {
            if (contractTypes.length > 1) contractTypes.remove(ct);
          }),
          onAddUser: (u) => setState(() => users.add(u)),
          onDeleteUser: (u) => setState(() => users.removeWhere((x) => x.id == u.id)),
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
          onUpdateFormula: (newFormula) => setState(() => scoringFormula = newFormula),
          onToggleSync: (val, url) => setState(() {
            onlineSyncEnabled = val;
            cloudServerUrl = url;
          }),
        ),
    ];

    if (currentTab >= pages.length) {
      currentTab = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.precision_manufacturing, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ماشینریار (نسخه عملیاتی)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${currentUser.name} • نقش: ${currentUser.role} (${currentUser.contractType})',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // نشانگر وضعیت اتصال اینترنت و همگام‌سازی
          Tooltip(
            message: onlineSyncEnabled
                ? 'متصل به شبکه (همگام‌سازی آنلاین فعال)'
                : 'حالت آفلاین (ذخیره در حافظه دستگاه)',
            child: IconButton(
              icon: Icon(
                onlineSyncEnabled ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: onlineSyncEnabled ? Colors.greenAccent : Colors.amberAccent,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(onlineSyncEnabled
                        ? 'همگام‌سازی آنلاین فعال است. داده‌ها بین همکاران به اشتراک گذاشته می‌شوند.'
                        : 'حالت آفلاین فعال است.'),
                  ),
                );
              },
            ),
          ),
          // تغییر سریع کاربر/نقش برای تست راحت‌تر
          PopupMenuButton<AppUser>(
            tooltip: 'تغییر سریع کاربر / نقش',
            icon: const Icon(Icons.switch_account_outlined),
            onSelected: (u) => setState(() {
              currentUser = u;
              if (!isAdmin && currentTab == 4) currentTab = 0;
            }),
            itemBuilder: (_) => [
              const PopupMenuItem<AppUser>(
                enabled: false,
                child: Text('تغییر کاربر فعال (تست سطح دسترسی):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: teal)),
              ),
              ...users.map(
                (u) => PopupMenuItem<AppUser>(
                  value: u,
                  child: Row(
                    children: [
                      Icon(
                        u.id == currentUser.id ? Icons.radio_button_checked : Icons.person_outline,
                        color: u.id == currentUser.id ? teal : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${u.name} (${u.role})', style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'خروج به صفحه ورود',
            icon: const Icon(Icons.logout),
            onPressed: () => setState(() => isLoggedIn = false),
          ),
        ],
      ),
      body: pages[currentTab],
      floatingActionButton: (currentTab == 0 && canCreateWorkOrder)
          ? FloatingActionButton.extended(
              backgroundColor: teal,
              foregroundColor: Colors.white,
              onPressed: _openNewOrderDialog,
              icon: const Icon(Icons.add),
              label: const Text('ثبت دستورکار ۱۰ رقمی'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (idx) => setState(() => currentTab = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'داشبورد',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'گزارش روزانه',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'پرسنل و قرارداد',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'خروجی Excel/PDF',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'پنل مدیریت',
            ),
        ],
      ),
    );
  }

  Future<void> _openNewOrderDialog() async {
    final result = await Navigator.push<WorkOrder>(
      context,
      MaterialPageRoute(
        builder: (_) => NewWorkOrderScreen(
          equipments: equipments,
          users: users,
          currentUser: currentUser,
          onQuickAddEquipment: (eq) => setState(() => equipments.insert(0, eq)),
        ),
      ),
    );
    if (result != null) {
      setState(() => orders.insert(0, result));
    }
  }

  Future<void> _openOrderDetail(WorkOrder order) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailScreen(
          order: order,
          currentUser: currentUser,
          users: users,
          onChanged: () => setState(() {}),
        ),
      ),
    );
    setState(() {});
  }
}

// ============================================================================
// 3. LOGIN SCREEN (صفحه ورود با کد پرسنلی یا انتخاب سریع نقش)
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.precision_manufacturing, size: 52, color: teal),
                    const SizedBox(height: 10),
                    const Text(
                      'سامانه جامع ماشینریار',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy),
                    ),
                    const Text(
                      'مدیریت دستورکارها، گزارش روزانه شیفت و ارزیابی پرسنل',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'کد پرسنلی',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'رمز عبور (پیش‌فرض: 1234)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(errorMsg, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        final found = widget.users.where(
                          (u) =>
                              u.personnelCode == codeCtrl.text.trim() &&
                              u.password == passCtrl.text.trim(),
                        );
                        if (found.isEmpty) {
                          setState(() => errorMsg = 'کد پرسنلی یا رمز عبور اشتباه است.');
                        } else {
                          widget.onLogin(found.first);
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('ورود به سامانه'),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'ورود سریع آزمایشی به تفکیک نقش سازمانی:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.users.map((u) {
                        return ActionChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: Text('${u.role}: ${u.name}', style: const TextStyle(fontSize: 11)),
                          onPressed: () => widget.onLogin(u),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. REUSABLE SEARCHABLE SELECTOR WIDGET (لیست بازشو قابل جستجو برای همه بخش‌ها)
// ============================================================================

Future<String?> showSearchablePicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? currentValue,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = items
              .where((x) => x.toLowerCase().contains(query.trim().toLowerCase()))
              .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (_, scrollController) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'جستجو کنید...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setModalState(() => query = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('موردی یافت نشد.'))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              final selected = item == currentValue;
                              return ListTile(
                                title: Text(item,
                                    style: TextStyle(
                                        fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                                trailing: selected
                                    ? const Icon(Icons.check_circle, color: teal)
                                    : null,
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ============================================================================
// 5. TAB 1: DASHBOARD & WORK ORDERS (داشبورد، جستجوی سراسری و دستورکارهای ۱۰ رقمی)
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
  String priorityFilter = 'همه';

  @override
  Widget build(BuildContext context) {
    final openCount = widget.allOrders.where((o) => o.status != 'تکمیل‌شده').length;
    final pendingApprovalCount =
        widget.allOrders.where((o) => o.status == 'منتظر تأیید').length;
    final todayReportsCount = widget.dailyReports.length;

    final filteredOrders = widget.orders.where((o) {
      final matchesStatus = statusFilter == 'همه' || o.status == statusFilter;
      final matchesPriority = priorityFilter == 'همه' || o.priority == priorityFilter;
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.workOrderNumber.toLowerCase().contains(q) ||
          o.tag.toLowerCase().contains(q) ||
          o.title.toLowerCase().contains(q) ||
          o.details.toLowerCase().contains(q) ||
          o.spareParts.toLowerCase().contains(q) ||
          o.assignedPersonnelNames.any((p) => p.toLowerCase().contains(q));
      return matchesStatus && matchesPriority && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خلاصه وضعیت واحد ماشینری',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
                  SizedBox(height: 3),
                  Text('پایش لحظه‌ای دستورکارهای ۱۰ رقمی، تگ تجهیزات و گزارش‌های شیفت',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                ],
              ),
            ),
            Chip(
              backgroundColor: const Color(0xFFE0F2F1),
              avatar: const Icon(Icons.verified_user, size: 16, color: teal),
              label: Text(widget.currentUser.role,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // کارت‌های آماری پویا (رفع باگ const در نسخه اولیه)
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'کل دستورکارها',
                value: '${widget.allOrders.length}',
                icon: Icons.build_circle_outlined,
                color: navy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'باز / فعال',
                value: '$openCount',
                icon: Icons.pending_actions,
                color: teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'منتظر تأیید سرپرست',
                value: '$pendingApprovalCount',
                icon: Icons.draw_outlined,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'گزارش‌های شیفت ثبت‌شده',
                value: '$todayReportsCount',
                icon: Icons.today,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // باکس جستجو و فیلتر سراسری دستورکارها
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'جستجوی دستورکار (شماره ۱۰ رقمی، تگ تجهیز، عنوان، نام تعمیرکار یا قطعه)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('فیلتر وضعیت: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      for (final st in [
                        'همه',
                        'جدید',
                        'در حال انجام',
                        'منتظر قطعه',
                        'منتظر تأیید',
                        'تکمیل‌شده'
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(st, style: const TextStyle(fontSize: 12)),
                            selected: statusFilter == st,
                            onSelected: (_) => setState(() => statusFilter = st),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('فهرست دستورکارها (${filteredOrders.length} مورد)',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy)),
            if (widget.currentUser.role != 'تعمیرکار')
              TextButton.icon(
                onPressed: widget.onNewOrder,
                icon: const Icon(Icons.add),
                label: const Text('ثبت دستورکار جدید'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (filteredOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('هیچ دستورکاری با این مشخصات یافت نشد.')),
            ),
          ),
        ...filteredOrders.map((o) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onOpenOrderDetail(o),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: navy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'شماره دستورکار: ${o.workOrderNumber}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12, color: navy),
                            ),
                          ),
                          Text(o.createdAt,
                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFE0F2F1),
                            child: Icon(Icons.precision_manufacturing, color: teal, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${o.tag} — ${o.title}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          const Icon(Icons.chevron_left, color: Colors.grey),
                        ],
                      ),
                      if (o.details.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'شرح: ${o.details}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, fontSize: 12.5),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildStatusChip(o.status),
                          Chip(
                            label: Text('اولویت: ${o.priority}',
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(o.maintenanceType, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (o.assignedPersonnelNames.isNotEmpty)
                            Chip(
                              avatar: const Icon(Icons.engineering, size: 15, color: teal),
                              label: Text(o.assignedPersonnelNames.join('، '),
                                  style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor = Colors.blueGrey.shade50;
    Color txtColor = Colors.blueGrey.shade800;
    if (status == 'در حال انجام') {
      bgColor = Colors.blue.shade50;
      txtColor = Colors.blue.shade800;
    } else if (status == 'منتظر تأیید') {
      bgColor = Colors.orange.shade50;
      txtColor = Colors.deepOrange.shade800;
    } else if (status == 'تکمیل‌شده') {
      bgColor = Colors.green.shade50;
      txtColor = Colors.green.shade800;
    } else if (status == 'منتظر قطعه') {
      bgColor = Colors.amber.shade50;
      txtColor = Colors.amber.shade900;
    }
    return Chip(
      backgroundColor: bgColor,
      label: Text(status,
          style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
            ],
          ),
        ),
      );
}

// ============================================================================
// 6. NEW WORK ORDER SCREEN (فرم ثبت دستورکار ۱۰ رقمی + انتخاب تگ قابل جستجو + نفرات + قطعات)
// ============================================================================

class NewWorkOrderScreen extends StatefulWidget {
  final List<EquipmentItem> equipments;
  final List<AppUser> users;
  final AppUser currentUser;
  final ValueChanged<EquipmentItem> onQuickAddEquipment;

  const NewWorkOrderScreen({
    super.key,
    required this.equipments,
    required this.users,
    required this.currentUser,
    required this.onQuickAddEquipment,
  });

  @override
  State<NewWorkOrderScreen> createState() => _NewWorkOrderScreenState();
}

class _NewWorkOrderScreenState extends State<NewWorkOrderScreen> {
  final formKey = GlobalKey<FormState>();
  final woNumberCtrl = TextEditingController();
  final permitCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final detailsCtrl = TextEditingController();
  final causeCtrl = TextEditingController();
  final sparePartsCtrl = TextEditingController();

  String? selectedTag;
  String priority = 'متوسط';
  String maintenanceType = 'CM (اصلاحی)';
  final List<String> selectedPersonnel = [];

  @override
  void initState() {
    super.initState();
    _generateTenDigitNumber();
    if (widget.equipments.isNotEmpty) {
      selectedTag = widget.equipments.first.tag;
    }
  }

  void _generateTenDigitNumber() {
    final rnd = Random();
    final suffix = (100000 + rnd.nextInt(899999)).toString();
    woNumberCtrl.text = '4050$suffix'; // 10 digits
  }

  @override
  void dispose() {
    woNumberCtrl.dispose();
    permitCtrl.dispose();
    titleCtrl.dispose();
    detailsCtrl.dispose();
    causeCtrl.dispose();
    sparePartsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final technicians = widget.users;

    return Scaffold(
      appBar: AppBar(title: const Text('ثبت دستورکار تعمیراتی جدید')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('مشخصات شناسه و تجهیز',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(height: 12),
            // شماره دستورکار ۱۰ رقمی اجباری
            TextFormField(
              controller: woNumberCtrl,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'شماره دستورکار (۱۰ رقمی اجباری) *',
                hintText: 'مثلاً 4050132007',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                suffixIcon: IconButton(
                  tooltip: 'تولید خودکار کد ۱۰ رقمی',
                  icon: const Icon(Icons.autorenew, color: teal),
                  onPressed: () => setState(_generateTenDigitNumber),
                ),
              ),
              validator: (v) {
                final val = (v ?? '').trim();
                if (!RegExp(r'^\d{10}$').hasMatch(val)) {
                  return 'شماره دستورکار باید دقیقاً ۱۰ رقم عددی باشد';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            // انتخاب تگ تجهیز از لیست قابل جستجو
            InkWell(
              onTap: () async {
                final labels = widget.equipments.map((e) => e.displayLabel).toList();
                final picked = await showSearchablePicker(
                  context: context,
                  title: 'انتخاب و جستجوی تگ تجهیز',
                  items: labels,
                );
                if (picked != null) {
                  final tag = picked.split(' — ').first.trim();
                  setState(() => selectedTag = tag);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تگ تجهیز (قابل جستجو) *',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                  suffixIcon: Icon(Icons.manage_search),
                ),
                child: Text(
                  selectedTag == null
                      ? 'برای جستجو و انتخاب تگ تجهیز ضربه بزنید'
                      : widget.equipments
                          .firstWhere(
                            (e) => e.tag == selectedTag,
                            orElse: () => EquipmentItem(tag: selectedTag!, name: '', unit: ''),
                          )
                          .displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: maintenanceType,
                    decoration: const InputDecoration(labelText: 'نوع تعمیرات'),
                    items: [
                      'EM (اضطراری)',
                      'PM (پیشگیرانه)',
                      'CM (اصلاحی)',
                      'Overhaul (اساسی)',
                    ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                    onChanged: (v) => setState(() => maintenanceType = v ?? 'CM (اصلاحی)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'اولویت'),
                    items: ['عادی', 'متوسط', 'بالا', 'فوری']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => priority = v ?? 'متوسط'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: permitCtrl,
              decoration: const InputDecoration(
                labelText: 'شماره پرمیت ایمنی (Permit)',
                hintText: 'مثلاً PRM-1405-125',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'عنوان کار تعمیراتی *',
                hintText: 'مثلاً تعویض بیرینگ و مکانیکال سیل',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'عنوان کار را وارد کنید' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'شرح کامل خرابی / دستورالعمل فنی',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: causeCtrl,
              decoration: const InputDecoration(
                labelText: 'علت خرابی (جهت ثبت در شناسنامه تجهیز)',
                hintText: 'مثلاً استهلاک طبیعی، عدم روانکاری، کاویتاسیون و...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: sparePartsCtrl,
              decoration: const InputDecoration(
                labelText: 'قطعات مصرفی / مورد نیاز',
                hintText: 'مثلاً بلبرینگ 6310، اورینگ ویتون، گسکت ۲ اینچ',
                prefixIcon: Icon(Icons.settings_suggest_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Text('انتخاب نفرات انجام‌دهنده / اکیپ مسئول:',
                style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: technicians.map((u) {
                final isSelected = selectedPersonnel.contains(u.name);
                return FilterChip(
                  selected: isSelected,
                  label: Text('${u.name} (${u.contractType})',
                      style: const TextStyle(fontSize: 12)),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedPersonnel.add(u.name);
                      } else {
                        selectedPersonnel.remove(u.name);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (selectedTag == null || selectedTag!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لطفاً تگ تجهیز را انتخاب کنید.')),
                  );
                  return;
                }
                final newOrder = WorkOrder(
                  workOrderNumber: woNumberCtrl.text.trim(),
                  permitNumber: permitCtrl.text.trim(),
                  maintenanceType: maintenanceType,
                  tag: selectedTag!,
                  title: titleCtrl.text.trim(),
                  status: 'جدید',
                  priority: priority,
                  details: detailsCtrl.text.trim(),
                  failureCause: causeCtrl.text.trim(),
                  spareParts: sparePartsCtrl.text.trim(),
                  assignedPersonnelNames: List<String>.from(selectedPersonnel),
                  createdBy: widget.currentUser.name,
                  createdAt: '۱۴۰۵/۰۷/۳۰',
                );
                Navigator.pop(context, newOrder);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('ثبت نهایی دستورکار ۱۰ رقمی'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. WORK ORDER DETAIL & WORKFLOW SCREEN (صفحه جزئیات، تغییر وضعیت و تأیید سرپرست)
// ============================================================================

class WorkOrderDetailScreen extends StatefulWidget {
  final WorkOrder order;
  final AppUser currentUser;
  final List<AppUser> users;
  final VoidCallback onChanged;

  const WorkOrderDetailScreen({
    super.key,
    required this.order,
    required this.currentUser,
    required this.users,
    required this.onChanged,
  });

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  late TextEditingController spareCtrl;
  late TextEditingController detailsCtrl;

  @override
  void initState() {
    super.initState();
    spareCtrl = TextEditingController(text: widget.order.spareParts);
    detailsCtrl = TextEditingController(text: widget.order.details);
  }

  @override
  void dispose() {
    spareCtrl.dispose();
    detailsCtrl.dispose();
    super.dispose();
  }

  void _changeStatus(String newStatus) {
    setState(() {
      widget.order.status = newStatus;
      widget.order.spareParts = spareCtrl.text.trim();
      widget.order.details = detailsCtrl.text.trim();
      if (newStatus == 'تکمیل‌شده') {
        widget.order.approvedBy = widget.currentUser.name;
      }
    });
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('وضعیت دستورکار به «$newStatus» تغییر یافت.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final role = widget.currentUser.role;
    final canApprove = role == 'مدیر سیستم' || role == 'تأییدکننده';

    return Scaffold(
      appBar: AppBar(title: Text('دستورکار ${o.workOrderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('کد ۱۰ رقمی: ${o.workOrderNumber}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: teal)),
                      Chip(label: Text(o.status)),
                    ],
                  ),
                  const Divider(),
                  _infoRow('تگ تجهیز:', o.tag),
                  _infoRow('عنوان کار:', o.title),
                  _infoRow('نوع تعمیرات:', o.maintenanceType),
                  _infoRow('اولویت:', o.priority),
                  _infoRow('شماره پرمیت:', o.permitNumber.isEmpty ? 'ثبت نشده' : o.permitNumber),
                  _infoRow('ثبت‌کننده:', '${o.createdBy} (${o.createdAt})'),
                  _infoRow(
                    'نفرات انجام‌دهنده:',
                    o.assignedPersonnelNames.isEmpty
                        ? 'تعیین نشده'
                        : o.assignedPersonnelNames.join(' ، '),
                  ),
                  if (o.approvedBy.isNotEmpty) _infoRow('تأییدکننده نهایی:', o.approvedBy),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('فیلدهای فنی و قطعات مصرفی (قابل تکمیل توسط تعمیرکار/کارشناس)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'شرح خرابی و اقدامات انجام‌شده'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: spareCtrl,
                    decoration: const InputDecoration(
                      labelText: 'قطعات مصرفی استفاده شده روی تجهیز',
                      prefixIcon: Icon(Icons.build_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          o.details = detailsCtrl.text.trim();
                          o.spareParts = spareCtrl.text.trim();
                        });
                        widget.onChanged();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('اطلاعات فنی و قطعات مصرفی بروزرسانی شد.')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('ذخیره تغییرات فنی'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('عملیات تغییر وضعیت دستورکار (متناسب با نقش شما):',
              style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _changeStatus('در حال انجام'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('شروع کار (در حال انجام)'),
              ),
              ElevatedButton.icon(
                onPressed: () => _changeStatus('منتظر قطعه'),
                icon: const Icon(Icons.hourglass_Empty),
                label: const Text('منتظر قطعه'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                onPressed: () => _changeStatus('منتظر تأیید'),
                icon: const Icon(Icons.send_and_archive_outlined),
                label: const Text('پایان تعمیر و ارسال جهت تأیید سرپرست'),
              ),
              if (canApprove) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () => _changeStatus('تکمیل‌شده'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('تأیید نهایی و بستن دستورکار (ویژه سرپرست/مدیر)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _changeStatus('در حال انجام'),
                  icon: const Icon(Icons.replay, color: Colors.red),
                  label: const Text('رد و بازگشت به تعمیرکار',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

// ============================================================================
// 8. TAB 2: DAILY SHIFT REPORT (گزارش روزانه با هدینگ شیفت، تگ تجهیز، نفرات جلوی هر کار و قطعات مصرفی)
// ============================================================================

class DailyReportTab extends StatefulWidget {
  final List<DailyShiftReport> reports;
  final List<EquipmentItem> equipments;
  final List<WorkOrder> orders;
  final List<AppUser> users;
  final AppUser currentUser;
  final ValueChanged<DailyShiftReport> onAddReport;
  final ValueChanged<DailyShiftReport> onApproveReport;

  const DailyReportTab({
    super.key,
    required this.reports,
    required this.equipments,
    required this.orders,
    required this.users,
    required this.currentUser,
    required this.onAddReport,
    required this.onApproveReport,
  });

  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  String selectedShiftHeading = 'روزکار';
  final dateCtrl = TextEditingController(text: '۱۴۰۵/۰۷/۳۰');
  String searchFilter = '';

  // کنترلرهای افزودن یک ردیف فعالیت به شیفت جاری
  String? rowTag;
  String? rowWorkOrder;
  final rowActivityCtrl = TextEditingController();
  final rowSparePartsCtrl = TextEditingController();
  final rowHoursCtrl = TextEditingController(text: '2.0');
  final List<String> rowPersonnel = [];

  final List<DailyActivityRow> draftActivities = [];

  @override
  void initState() {
    super.initState();
    if (widget.equipments.isNotEmpty) {
      rowTag = widget.equipments.first.tag;
    }
    rowPersonnel.add(widget.currentUser.name);
  }

  @override
  void dispose() {
    dateCtrl.dispose();
    rowActivityCtrl.dispose();
    rowSparePartsCtrl.dispose();
    rowHoursCtrl.dispose();
    super.dispose();
  }

  void _addActivityRowToShift() {
    if (rowTag == null || rowActivityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً تگ تجهیز و شرح فعالیت را وارد کنید.')),
      );
      return;
    }
    if (rowPersonnel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً حداقل یک نفر انجام‌دهنده برای این کار انتخاب کنید.')),
      );
      return;
    }
    final hrs = double.tryParse(rowHoursCtrl.text.trim()) ?? 1.0;
    setState(() {
      draftActivities.add(
        DailyActivityRow(
          equipmentTag: rowTag!,
          workOrderNumber: rowWorkOrder ?? '',
          activityDescription: rowActivityCtrl.text.trim(),
          personnelNames: List<String>.from(rowPersonnel),
          sparePartsUsed: rowSparePartsCtrl.text.trim(),
          hours: hrs,
        ),
      );
      rowActivityCtrl.clear();
      rowSparePartsCtrl.clear();
    });
  }

  void _submitFullShiftReport() {
    if (draftActivities.isEmpty) {
      // اگر کاربر ردیف را تایپ کرده ولی دکمه افزودن ردیف را نزده، خودکار اضافه کن
      if (rowActivityCtrl.text.trim().isNotEmpty && rowTag != null) {
        _addActivityRowToShift();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حداقل یک فعالیت به گزارش شیفت اضافه کنید.')),
        );
        return;
      }
    }
    final newRep = DailyShiftReport(
      id: 'REP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      shiftTitle: selectedShiftHeading,
      reportDate: dateCtrl.text.trim(),
      submittedBy: widget.currentUser.name,
      activities: List<DailyActivityRow>.from(draftActivities),
    );
    widget.onAddReport(newRep);
    setState(() => draftActivities.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('گزارش روزانه با هدینگ «$selectedShiftHeading» با موفقیت ثبت شد.'),
        backgroundColor: teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApprove =
        widget.currentUser.role == 'مدیر سیستم' || widget.currentUser.role == 'تأییدکننده';

    final filteredReports = widget.reports.where((r) {
      final q = searchFilter.trim().toLowerCase();
      if (q.isEmpty) return true;
      if (r.shiftTitle.toLowerCase().contains(q) ||
          r.reportDate.toLowerCase().contains(q) ||
          r.submittedBy.toLowerCase().contains(q)) {
        return true;
      }
      return r.activities.any((a) =>
          a.equipmentTag.toLowerCase().contains(q) ||
          a.activityDescription.toLowerCase().contains(q) ||
          a.sparePartsUsed.toLowerCase().contains(q) ||
          a.personnelNames.any((p) => p.toLowerCase().contains(q)));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بنر هدینگ شیفت کاری
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(12),
            border: const Border(right: BorderSide(color: teal, width: 6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'هدینگ گزارش روزانه: $selectedShiftHeading',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Chip(
                    backgroundColor: teal,
                    label: Text(
                      dateCtrl.text,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'ثبت کارکرد روزانه به تفکیک تگ تجهیز، شرح فعالیت، نفرات انجام‌دهنده و قطعات مصرفی',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // فرم ثبت گزارش روزانه
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedShiftHeading,
                        decoration: const InputDecoration(
                          labelText: 'انتخاب شیفت کاری (هدینگ گزارش)',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        items: ['روزکار', 'شیفت صبح', 'شیفت عصر', 'شیفت شب']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedShiftHeading = v ?? 'روزکار'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: dateCtrl,
                        decoration: const InputDecoration(labelText: 'تاریخ'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text('افزودن ردیف کار انجام‌شده روی تجهیز در این شیفت:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showSearchablePicker(
                            context: context,
                            title: 'جستجو و انتخاب تگ تجهیز',
                            items: widget.equipments.map((e) => e.displayLabel).toList(),
                          );
                          if (picked != null) {
                            setState(() => rowTag = picked.split(' — ').first.trim());
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تگ تجهیز کار شده *',
                            prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                          ),
                          child: Text(rowTag ?? 'انتخاب تگ تجهیز',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: rowHoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'ساعت کار'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rowActivityCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'شرح فعالیت انجام‌شده *',
                    hintText: 'مثلاً تعویض مکانیکال سیل و لاینینگ کوپلینگ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rowSparePartsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'قطعات مصرفی روی این تجهیز',
                    hintText: 'مثلاً بلبرینگ 6310، گسکت، شیم استیل و...',
                    prefixIcon: Icon(Icons.build_circle_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('نام نفرات انجام‌دهنده این کار (نمایش در جلوی شرح فعالیت):',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.users.map((u) {
                    final selected = rowPersonnel.contains(u.name);
                    return FilterChip(
                      selected: selected,
                      label: Text('${u.name} (${u.contractType})',
                          style: const TextStyle(fontSize: 11.5)),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            rowPersonnel.add(u.name);
                          } else {
                            rowPersonnel.remove(u.name);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _addActivityRowToShift,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('افزودن به جدول این شیفت'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: teal),
                      onPressed: _submitFullShiftReport,
                      icon: const Icon(Icons.send),
                      label: Text('ثبت نهایی گزارش «$selectedShiftHeading»'),
                    ),
                  ],
                ),
                if (draftActivities.isNotEmpty) ...[
                  const Divider(height: 22),
                  Text('ردیف‌های آماده ثبت در هدینگ «$selectedShiftHeading»:',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: teal)),
                  const SizedBox(height: 6),
                  ...draftActivities.asMap().entries.map((entry) {
                    final a = entry.value;
                    return ListTile(
                      dense: true,
                      tileColor: const Color(0xFFF0F9FA),
                      title: Text('${a.equipmentTag} — ${a.activityDescription}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'نفرات: ${a.personnelNames.join("، ")} | قطعات: ${a.sparePartsUsed.isEmpty ? "-" : a.sparePartsUsed} | ${a.hours} ساعت'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => draftActivities.removeAt(entry.key)),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // جستجو در آرشیو گزارش‌های روزانه
        TextField(
          decoration: const InputDecoration(
            labelText: 'جستجو در گزارش‌های روزانه (بر اساس شیفت، تگ تجهیز، نام نفرات یا قطعه مصرفی)',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => searchFilter = v),
        ),
        const SizedBox(height: 12),
        // نمایش گزارش‌های ثبت‌شده با هدینگ شیفت کاری و جدول فعالیت‌ها + نفرات روبه‌روی هر کار
        ...filteredReports.map((rep) => Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // هدینگ شیفت کاری در بالای هر کارت گزارش
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: navy,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined, color: Colors.amberAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'شیفت کاری: ${rep.shiftTitle}  |  تاریخ: ${rep.reportDate}',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: rep.isApproved ? Colors.green.shade600 : Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                rep.isApproved ? 'تأییدشده (${rep.approvedBy})' : 'منتظر تأیید سرپرست',
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                            if (canApprove && !rep.isApproved)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.greenAccent,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => widget.onApproveReport(rep),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('تأیید شیفت', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFE2ECF5)),
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('تگ تجهیز', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('شرح فعالیت انجام‌شده', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('نفرات انجام‌دهنده کار', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('قطعات مصرفی', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('ساعت', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: rep.activities.map((act) {
                              return DataRow(cells: [
                                DataCell(Text(act.equipmentTag,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: teal))),
                                DataCell(SizedBox(width: 210, child: Text(act.activityDescription))),
                                DataCell(SizedBox(
                                  width: 180,
                                  child: Text(act.personnelNames.join(' ، '),
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: navy)),
                                )),
                                DataCell(SizedBox(
                                  width: 150,
                                  child: Text(act.sparePartsUsed.isEmpty ? '—' : act.sparePartsUsed),
                                )),
                                DataCell(Text('${act.hours}')),
                              ]);
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ثبت‌کننده گزارش: ${rep.submittedBy} • مجموع نفر-ساعت شیفت: ${rep.totalHours} ساعت',
                          style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ============================================================================
// 9. TAB 3: PERSONNEL, CONTRACT TYPES & SCORING (پرسنل، فیلتر نوع قرارداد و امتیازدهی)
// ============================================================================

class PeopleScoreTab extends StatefulWidget {
  final List<AppUser> users;
  final List<String> contractTypes;
  final ScoringFormula formula;
  final AppUser currentUser;
  final void Function(AppUser user, double timely, double quality, double safety, String reason)
      onUpdateUserScore;

  const PeopleScoreTab({
    super.key,
    required this.users,
    required this.contractTypes,
    required this.formula,
    required this.currentUser,
    required this.onUpdateUserScore,
  });

  @override
  State<PeopleScoreTab> createState() => _PeopleScoreTabState();
}

class _PeopleScoreTabState extends State<PeopleScoreTab> {
  String selectedContractFilter = 'همه';
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isTechnician = widget.currentUser.role == 'تعمیرکار';
    final canEditScore =
        widget.currentUser.role == 'مدیر سیستم' || widget.currentUser.role == 'تأییدکننده';

    final baseList = isTechnician
        ? widget.users.where((u) => u.id == widget.currentUser.id).toList()
        : widget.users;

    final filteredUsers = baseList.where((u) {
      final matchesContract =
          selectedContractFilter == 'همه' || u.contractType == selectedContractFilter;
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.personnelCode.toLowerCase().contains(q) ||
          u.specialty.toLowerCase().contains(q) ||
          u.contractType.toLowerCase().contains(q);
      return matchesContract && matchesSearch;
    }).toList();

    final avgScore = filteredUsers.isEmpty
        ? 0.0
        : filteredUsers
                .map((u) => u.totalScore(widget.formula))
                .reduce((a, b) => a + b) /
            filteredUsers.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('پرسنل، نوع قرارداد و امتیازدهی عملکرد',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 4),
        Text(
          'فرمول فعال: گزارش به‌موقع ${widget.formula.timelyWeight.toInt()}٪ • کیفیت ${widget.formula.qualityWeight.toInt()}٪ • ایمنی ${widget.formula.safetyWeight.toInt()}٪',
          style: const TextStyle(color: teal, fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        if (!isTechnician)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'جستجوی نام پرسنل، کد پرسنلی، تخصص یا نوع قرارداد',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('فیلتر نوع قرارداد: ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        for (final ct in ['همه', ...widget.contractTypes])
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(ct, style: const TextStyle(fontSize: 12)),
                              selected: selectedContractFilter == ct,
                              onSelected: (_) => setState(() => selectedContractFilter = ct),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تعداد نفرات در این فیلتر: ${filteredUsers.length} نفر',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      Text(
                        'میانگین امتیاز قرارداد (${selectedContractFilter}): ${avgScore.toStringAsFixed(1)} از ۱۰۰',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: teal, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        ...filteredUsers.map((u) {
          final total = u.totalScore(widget.formula);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      child: Text(u.totalScore(widget.formula).toStringAsFixed(0)),
                    ),
                    title: Text('${u.name} (کد: ${u.personnelCode})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip(
                              backgroundColor: const Color(0xFFE0F2F1),
                              label: Text('قرارداد: ${u.contractType}',
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.bold, color: teal)),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text('نقش: ${u.role}', style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(u.specialty, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'به‌موقع: ${u.timelyScore.toInt()} • کیفیت: ${u.qualityScore.toInt()} • ایمنی: ${u.safetyScore.toInt()}',
                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(total.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold, color: teal)),
                        const Text('از ۱۰۰', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  if (canEditScore)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showEditScoreDialog(context, u),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('ثبت / اصلاح امتیاز توسط مدیر یا سرپرست'),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showEditScoreDialog(BuildContext context, AppUser user) {
    double timely = user.timelyScore;
    double quality = user.qualityScore;
    double safety = user.safetyScore;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('ارزیابی و اصلاح امتیاز: ${user.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نوع قرارداد: ${user.contractType}',
                    style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('گزارش به‌موقع (${widget.formula.timelyWeight.toInt()}٪): ${timely.toInt()}'),
                Slider(
                  value: timely,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => setDlgState(() => timely = v),
                ),
                Text('کیفیت فنی کار (${widget.formula.qualityWeight.toInt()}٪): ${quality.toInt()}'),
                Slider(
                  value: quality,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => setDlgState(() => quality = v),
                ),
                Text('رعایت ایمنی و پرمیت (${widget.formula.safetyWeight.toInt()}٪): ${safety.toInt()}'),
                Slider(
                  value: safety,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => setDlgState(() => safety = v),
                ),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'علت تغییر یا توضیح ارزیابی *',
                    hintText: 'مثلاً کیفیت عالی در اورهال پمپ P_17003',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                final reason =
                    reasonCtrl.text.trim().isEmpty ? 'ارزیابی دوره‌ای' : reasonCtrl.text.trim();
                widget.onUpdateUserScore(user, timely, quality, safety, reason);
                Navigator.pop(ctx);
              },
              child: const Text('ذخیره امتیاز'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 10. TAB 4: REPORTS & EXCEL / PDF EXPORT BY CONTRACT TYPE (گزارش‌ها و خروجی اکسل و PDF)
// ============================================================================

class ReportsExportTab extends StatefulWidget {
  final List<WorkOrder> orders;
  final List<DailyShiftReport> dailyReports;
  final List<AppUser> users;
  final List<String> contractTypes;
  final List<EquipmentItem> equipments;
  final ScoringFormula formula;
  final AppUser currentUser;

  const ReportsExportTab({
    super.key,
    required this.orders,
    required this.dailyReports,
    required this.users,
    required this.contractTypes,
    required this.equipments,
    required this.formula,
    required this.currentUser,
  });

  @override
  State<ReportsExportTab> createState() => _ReportsExportTabState();
}

class _ReportsExportTabState extends State<ReportsExportTab> {
  String reportCategory = 'امتیاز و عملکرد پرسنل (بر اساس نوع قرارداد)';
  String selectedContractType = 'همه';
  String selectedShift = 'همه';
  String exportPreviewText = '';

  void _generateExport({required String format}) {
    final StringBuffer sb = StringBuffer();

    if (reportCategory.startsWith('امتیاز')) {
      final filtered = widget.users.where((u) {
        return selectedContractType == 'همه' || u.contractType == selectedContractType;
      }).toList();

      sb.writeln('کد پرسنلی,نام و نام خانوادگی,نقش,تخصص,نوع قرارداد,گزارش به‌موقع,کیفیت کار,رعایت ایمنی,امتیاز کل (از ۱۰۰)');
      for (final u in filtered) {
        sb.writeln(
            '${u.personnelCode},${u.name},${u.role},${u.specialty},${u.contractType},${u.timelyScore.toInt()},${u.qualityScore.toInt()},${u.safetyScore.toInt()},${u.totalScore(widget.formula).toStringAsFixed(1)}');
      }
    } else if (reportCategory.startsWith('گزارش روزانه')) {
      sb.writeln('هدینگ شیفت,تاریخ,تگ تجهیز,شماره دستورکار,شرح فعالیت,نفرات انجام‌دهنده,نوع قرارداد نفرات,قطعات مصرفی,ساعت کار,وضعیت تأیید');
      for (final rep in widget.dailyReports) {
        if (selectedShift != 'همه' && rep.shiftTitle != selectedShift) continue;
        for (final act in rep.activities) {
          // بررسی فیلتر نوع قرارداد برای نفرات انجام دهنده
          final contractsOfAct = act.personnelNames.map((name) {
            final found = widget.users.where((u) => u.name == name);
            return found.isEmpty ? 'نامشخص' : found.first.contractType;
          }).toSet();

          if (selectedContractType != 'همه' && !contractsOfAct.contains(selectedContractType)) {
            continue;
          }

          sb.writeln(
              '${rep.shiftTitle},${rep.reportDate},${act.equipmentTag},${act.workOrderNumber},"${act.activityDescription}","${act.personnelNames.join(" | ")}","${contractsOfAct.join(" | ")}","${act.sparePartsUsed}",${act.hours},${rep.isApproved ? "تأییدشده" : "منتظر تأیید"}');
        }
      }
    } else {
      sb.writeln('شماره دستورکار ۱۰ رقمی,شماره پرمیت,تگ تجهیز,عنوان کار,نوع تعمیرات,اولویت,وضعیت,نفرات مسئول,قطعات مصرفی,تاریخ ثبت');
      for (final o in widget.orders) {
        if (selectedContractType != 'همه') {
          final hasContractMatch = o.assignedPersonnelNames.any((name) {
            final found = widget.users.where((u) => u.name == name);
            return found.isNotEmpty && found.first.contractType == selectedContractType;
          });
          if (!hasContractMatch) continue;
        }
        sb.writeln(
            '${o.workOrderNumber},${o.permitNumber},${o.tag},"${o.title}",${o.maintenanceType},${o.priority},${o.status},"${o.assignedPersonnelNames.join(" | ")}","${o.spareParts}",${o.createdAt}');
      }
    }

    setState(() {
      exportPreviewText = sb.toString();
    });

    Clipboard.setData(ClipboardData(text: exportPreviewText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: teal,
        content: Text(
          'خروجی $format با فیلتر قرارداد «$selectedContractType» تولید و در حافظه کپی شد (آماده ذخیره در Excel/PDF).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('مرکز گزارش‌گیری و خروجی Excel / PDF',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 4),
        const Text(
          'دریافت خروجی به تفکیک نوع قرارداد پرسنل، شیفت کاری، تگ تجهیزات و دستورکارهای ۱۰ رقمی',
          style: TextStyle(color: Colors.blueGrey, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: reportCategory,
                  decoration: const InputDecoration(
                    labelText: 'نوع گزارش مورد نیاز',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  items: [
                    'امتیاز و عملکرد پرسنل (بر اساس نوع قرارداد)',
                    'گزارش روزانه تعمیرات (با هدینگ شیفت، تگ و نفرات)',
                    'فهرست جامع دستورکارهای ۱۰ رقمی و قطعات مصرفی',
                  ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => reportCategory = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedContractType,
                        decoration: const InputDecoration(
                          labelText: 'فیلتر نوع قرارداد پرسنل',
                          prefixIcon: Icon(Icons.assignment_ind_outlined),
                        ),
                        items: ['همه', ...widget.contractTypes]
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedContractType = v ?? 'همه'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'فیلتر شیفت کاری',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        items: ['همه', 'روزکار', 'شیفت صبح', 'شیفت عصر', 'شیفت شب']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedShift = v ?? 'همه'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => _generateExport(format: 'Excel (CSV UTF-8)'),
                        icon: const Icon(Icons.table_view),
                        label: const Text('تولید خروجی Excel (اکسل)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: navy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => _generateExport(format: 'PDF چاپی'),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('تولید گزارش PDF رسمی'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (exportPreviewText.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('پیش‌نمایش داده‌های خروجی (فیلتر قرارداد: $selectedContractType)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: exportPreviewText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('متن جدول در کلیپ‌بورد کپی شد.')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('کپی جهت الصاق در اکسل'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      exportPreviewText,
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'monospace', fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// 11. TAB 5: ADMIN PANEL (پنل مدیریت: تعریف کاربر، نوع قرارداد، آپلود لیست تجهیزات، فرمول امتیاز)
// ============================================================================

class AdminPanelTab extends StatefulWidget {
  final List<AppUser> users;
  final List<String> contractTypes;
  final List<EquipmentItem> equipments;
  final ScoringFormula formula;
  final bool onlineSyncEnabled;
  final String cloudServerUrl;
  final ValueChanged<String> onAddContractType;
  final ValueChanged<String> onRemoveContractType;
  final ValueChanged<AppUser> onAddUser;
  final ValueChanged<AppUser> onDeleteUser;
  final ValueChanged<EquipmentItem> onAddEquipment;
  final ValueChanged<List<EquipmentItem>> onBulkAddEquipments;
  final ValueChanged<ScoringFormula> onUpdateFormula;
  final void Function(bool enabled, String url) onToggleSync;

  const AdminPanelTab({
    super.key,
    required this.users,
    required this.contractTypes,
    required this.equipments,
    required this.formula,
    required this.onlineSyncEnabled,
    required this.cloudServerUrl,
    required this.onAddContractType,
    required this.onRemoveContractType,
    required this.onAddUser,
    required this.onDeleteUser,
    required this.onAddEquipment,
    required this.onBulkAddEquipments,
    required this.onUpdateFormula,
    required this.onToggleSync,
  });

  @override
  State<AdminPanelTab> createState() => _AdminPanelTabState();
}

class _AdminPanelTabState extends State<AdminPanelTab> {
  // کنترلرهای تعریف نوع قرارداد جدید
  final newContractCtrl = TextEditingController();

  // کنترلرهای تعریف کاربر جدید
  final uCodeCtrl = TextEditingController();
  final uNameCtrl = TextEditingController();
  final uSpecCtrl = TextEditingController();
  final uPassCtrl = TextEditingController(text: '1234');
  String uRole = 'تعمیرکار';
  late String uContract;

  // کنترلرهای افزودن تکی یا گروهی تجهیزات (آپلود از فایل/متن اکسل)
  final eqTagCtrl = TextEditingController();
  final eqNameCtrl = TextEditingController();
  final eqUnitCtrl = TextEditingController(text: 'واحد ۳۲۰');
  final bulkEqCtrl = TextEditingController();

  // کنترلرهای فرمول امتیازدهی
  late TextEditingController wTimelyCtrl;
  late TextEditingController wQualityCtrl;
  late TextEditingController wSafetyCtrl;

  @override
  void initState() {
    super.initState();
    uContract = widget.contractTypes.first;
    wTimelyCtrl = TextEditingController(text: widget.formula.timelyWeight.toStringAsFixed(0));
    wQualityCtrl = TextEditingController(text: widget.formula.qualityWeight.toStringAsFixed(0));
    wSafetyCtrl = TextEditingController(text: widget.formula.safetyWeight.toStringAsFixed(0));
  }

  @override
  void dispose() {
    newContractCtrl.dispose();
    uCodeCtrl.dispose();
    uNameCtrl.dispose();
    uSpecCtrl.dispose();
    uPassCtrl.dispose();
    eqTagCtrl.dispose();
    eqNameCtrl.dispose();
    eqUnitCtrl.dispose();
    bulkEqCtrl.dispose();
    wTimelyCtrl.dispose();
    wQualityCtrl.dispose();
    wSafetyCtrl.dispose();
    super.dispose();
  }

  void _importBulkEquipments() {
    final raw = bulkEqCtrl.text.trim();
    if (raw.isEmpty) return;
    final lines = raw.split('\n');
    final List<EquipmentItem> parsed = [];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.contains(',')
          ? line.split(',')
          : (line.contains('\t') ? line.split('\t') : line.split('-'));
      final tag = parts[0].trim();
      final name = parts.length > 1 ? parts[1].trim() : 'تجهیز ماشینری';
      final unit = parts.length > 2 ? parts[2].trim() : 'واحد ماشینری';
      if (tag.isNotEmpty) {
        parsed.add(EquipmentItem(tag: tag, name: name, unit: unit));
      }
    }
    widget.onBulkAddEquipments(parsed);
    bulkEqCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: teal,
        content: Text('${parsed.length} تگ تجهیز جدید با موفقیت به لیست بازشو اضافه شد.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('پنل مدیریت جامع سیستم (ویژه مدیر سیستم)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 4),
        const Text(
          'تعریف کاربران، انواع قرارداد، آپلود گروهی لیست تگ تجهیزات و تنظیم فرمول امتیازدهی',
          style: TextStyle(color: Colors.blueGrey, fontSize: 12.5),
        ),
        const SizedBox(height: 14),

        // بخش ۱: مدیریت انواع قراردادها
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('۱. تعریف و مدیریت انواع قرارداد پرسنل',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.contractTypes.map((ct) {
                    return Chip(
                      label: Text(ct),
                      onDeleted: () => widget.onRemoveContractType(ct),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newContractCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان نوع قرارداد جدید (مثلاً قراردادی مستقیم، حجمی و...)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        final val = newContractCtrl.text.trim();
                        if (val.isNotEmpty) {
                          widget.onAddContractType(val);
                          newContractCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن قرارداد'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // بخش ۲: تعریف کاربر جدید توسط مدیر سیستم
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('۲. تعریف کاربر / همکار جدید و تخصیص نقش و نوع قرارداد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: uCodeCtrl,
                        decoration: const InputDecoration(labelText: 'کد پرسنلی *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: uNameCtrl,
                        decoration: const InputDecoration(labelText: 'نام و نام خانوادگی *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: uRole,
                        decoration: const InputDecoration(labelText: 'سطح دسترسی (نقش)'),
                        items: ['مدیر سیستم', 'کارشناس ماشینری', 'تأییدکننده', 'تعمیرکار']
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => uRole = v ?? 'تعمیرکار'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: widget.contractTypes.contains(uContract)
                            ? uContract
                            : widget.contractTypes.first,
                        decoration: const InputDecoration(labelText: 'نوع قرارداد شخص'),
                        items: widget.contractTypes
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => uContract = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: uSpecCtrl,
                        decoration: const InputDecoration(
                          labelText: 'تخصص (مثلاً مکانیک پمپ، تراشکار، پایپینگ)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: uPassCtrl,
                        decoration: const InputDecoration(labelText: 'رمز عبور اولیه'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: teal),
                  onPressed: () {
                    if (uCodeCtrl.text.trim().isEmpty || uNameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('کد پرسنلی و نام کاربر را وارد کنید.')),
                      );
                      return;
                    }
                    widget.onAddUser(
                      AppUser(
                        id: 'U-${DateTime.now().millisecondsSinceEpoch}',
                        personnelCode: uCodeCtrl.text.trim(),
                        name: uNameCtrl.text.trim(),
                        role: uRole,
                        specialty: uSpecCtrl.text.trim().isEmpty
                            ? 'مکانیک ماشینری'
                            : uSpecCtrl.text.trim(),
                        contractType: uContract,
                        password: uPassCtrl.text.trim(),
                      ),
                    );
                    uCodeCtrl.clear();
                    uNameCtrl.clear();
                    uSpecCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('کاربر جدید با موفقیت به سامانه اضافه شد.')),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('ثبت کاربر در سامانه'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // بخش ۳: مدیریت لیست بازشو تگ تجهیزات (افزودن تکی + ورود گروهی از فایل اکسل/CSV)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '۳. مدیریت لیست تگ تجهیزات (${widget.equipments.length} تجهیز فعال در لیست بازشو)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: eqTagCtrl,
                        decoration: const InputDecoration(
                            labelText: 'تگ تجهیز (مثلاً P_32099)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: eqNameCtrl,
                        decoration: const InputDecoration(labelText: 'شرح تجهیز'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        if (eqTagCtrl.text.trim().isEmpty) return;
                        widget.onAddEquipment(
                          EquipmentItem(
                            tag: eqTagCtrl.text.trim(),
                            name: eqNameCtrl.text.trim().isEmpty
                                ? 'تجهیز صنعتی'
                                : eqNameCtrl.text.trim(),
                            unit: eqUnitCtrl.text.trim(),
                          ),
                        );
                        eqTagCtrl.clear();
                        eqNameCtrl.clear();
                      },
                      child: const Text('افزودن تگ'),
                    ),
                  ],
                ),
                const Divider(height: 22),
                const Text(
                  'ورود گروهی تگ تجهیزات از فایل اکسل / CSV (کپی ستون‌های اکسل یا متن CSV):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: teal),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: bulkEqCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'هر خط یک تجهیز: تگ,نام تجهیز,واحد\nمثال:\nP_32088,پمپ خوراک بوستر,واحد ۳۲۰\nC_21004,کمپرسور هیدروژن,واحد ۲۱۰',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _importBulkEquipments,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('افزودن گروهی تگ‌ها به لیست بازشو'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // بخش ۴: تنظیمات فرمول امتیازدهی پویا
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('۴. تنظیم پویا ضرایب فرمول امتیازدهی پرسنل',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: wTimelyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'وزن گزارش به‌موقع (٪)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: wQualityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'وزن کیفیت کار (٪)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: wSafetyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'وزن ایمنی (٪)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    final t = double.tryParse(wTimelyCtrl.text.trim()) ?? 30;
                    final q = double.tryParse(wQualityCtrl.text.trim()) ?? 40;
                    final s = double.tryParse(wSafetyCtrl.text.trim()) ?? 30;
                    widget.onUpdateFormula(
                      ScoringFormula(timelyWeight: t, qualityWeight: q, safetyWeight: s),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فرمول امتیازدهی کل پرسنل بروزرسانی شد.')),
                    );
                  },
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('اعمال ضرایب جدید روی امتیازات'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}
