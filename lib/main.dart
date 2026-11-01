import 'dart:async';
import 'dart:io' show InternetAddress;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// اسم التطبيق حسب لغة هاتف المستخدم
String get appName =>
    WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar'
        ? 'أوف سايد'
        : 'Offside';

// مراقبة الرجوع من الصفحات كي نعيد وضع الشاشة الكاملة خارج مشغل الفيديو.
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
RouteObserver<ModalRoute<dynamic>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const Mal3abApp());
}

class Mal3abApp extends StatelessWidget {
  const Mal3abApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (_) => appName,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 1. شاشة البداية
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainHomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: AnimatedMeshGradient(
          colors: const [
            Color(0xFF0D1B2A),
            Color(0xFF1B263B),
            Color(0xFF415A77),
            Color(0xFF0D1B2A),
          ],
          options: AnimatedMeshGradientOptions(
            speed: 3.0,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. نموذج المباراة
// ==========================================
class MatchModel {
  final String sourceFixtureId;
  final String homeTeam;
  final String awayTeam;
  final String homeLogo;
  final String awayLogo;
  final DateTime matchTime;
  final String competitionName;
  final String competitionCode;
  final String matchDateKey;
  final String status;
  final int competitionPriority;

  const MatchModel({
    required this.sourceFixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogo,
    required this.awayLogo,
    required this.matchTime,
    required this.competitionName,
    required this.competitionCode,
    required this.matchDateKey,
    required this.status,
    required this.competitionPriority,
  });

  factory MatchModel.fromFirestore(
      Map<String, dynamic> json,
      ) {
    final rawTime = json['matchTime'];
    DateTime parsedTime;

    if (rawTime is Timestamp) {
      parsedTime = rawTime.toDate().toLocal();
    } else if (rawTime is DateTime) {
      parsedTime = rawTime.toLocal();
    } else if (rawTime is String) {
      parsedTime = DateTime.tryParse(rawTime)?.toLocal() ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    final rawPriority = json['competitionPriority'];
    final priority = rawPriority is num
        ? rawPriority.toInt()
        : _priorityForCompetition(
      (json['competitionCode'] ?? '').toString(),
    );

    return MatchModel(
      sourceFixtureId: (json['sourceFixtureId'] ?? '').toString(),
      homeTeam: (json['homeTeam'] ?? 'Home Team').toString(),
      awayTeam: (json['awayTeam'] ?? 'Away Team').toString(),
      homeLogo: (json['homeLogo'] ?? '').toString(),
      awayLogo: (json['awayLogo'] ?? '').toString(),
      matchTime: parsedTime,
      competitionName: (json['competitionName'] ?? 'Football Competition')
          .toString(),
      competitionCode: (json['competitionCode'] ?? '').toString(),
      matchDateKey: (json['matchDateKey'] ?? '').toString(),
      status: (json['status'] ?? '').toString().toUpperCase(),
      competitionPriority: priority,
    );
  }
}

int _priorityForCompetition(String code) {
  const priorities = <String, int>{
    'PL': 1,
    'PD': 2,
    'SA': 3,
    'BL1': 4,
    'FL1': 5,
  };

  return priorities[code] ?? 1000;
}

bool _isArabic(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar';
}

String _competitionTitle(String name, String code, bool arabic) {
  if (!arabic) return name;

  const translations = <String, String>{
    'PL': 'الدوري الإنجليزي الممتاز',
    'PD': 'الدوري الإسباني',
    'SA': 'الدوري الإيطالي',
    'BL1': 'الدوري الألماني',
    'FL1': 'الدوري الفرنسي',
  };

  return translations[code] ?? name;
}

String _teamTitle(String name, bool arabic) {
  if (!arabic) return name;

  // ترجمة أسماء معروفة فقط؛ غير الموجود يبقى بالإنجليزية حتى لا تظهر ترجمة حرفية خاطئة.
  const translations = <String, String>{
    'Manchester United FC': 'مانشستر يونايتد',
    'Manchester United': 'مانشستر يونايتد',
    'Liverpool FC': 'ليفربول',
    'Liverpool': 'ليفربول',
    'Real Madrid CF': 'ريال مدريد',
    'Real Madrid': 'ريال مدريد',
    'FC Barcelona': 'برشلونة',
    'Barcelona': 'برشلونة',
    'Manchester City FC': 'مانشستر سيتي',
    'Manchester City': 'مانشستر سيتي',
    'Chelsea FC': 'تشيلسي',
    'Chelsea': 'تشيلسي',
    'Arsenal FC': 'أرسنال',
    'Arsenal': 'أرسنال',
    'Tottenham Hotspur FC': 'توتنهام هوتسبير',
    'Tottenham Hotspur': 'توتنهام هوتسبير',
    'Bayern Munich': 'بايرن ميونخ',
    'FC Bayern München': 'بايرن ميونخ',
    'Borussia Dortmund': 'بوروسيا دورتموند',
    'Paris Saint-Germain FC': 'باريس سان جيرمان',
    'Paris Saint-Germain': 'باريس سان جيرمان',
    'Juventus FC': 'يوفنتوس',
    'Juventus': 'يوفنتوس',
    'AC Milan': 'ميلان',
    'Inter Milan': 'إنتر ميلان',
    'Inter': 'إنتر ميلان',
  };

  return translations[name] ?? name;
}

String _formatMatchTime(DateTime time, bool arabic) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12
      ? (arabic ? 'ص' : 'AM')
      : (arabic ? 'م' : 'PM');

  return '$hour:$minute $suffix';
}

String _matchStateText(MatchModel match, bool arabic) {
  switch (match.status) {
    case 'IN_PLAY':
    case 'PAUSED':
    case 'LIVE':
      return arabic ? 'بث مباشر' : 'LIVE';
    case 'FINISHED':
      return arabic ? 'انتهت' : 'Finished';
    case 'POSTPONED':
      return arabic ? 'مؤجلة' : 'Postponed';
    case 'CANCELLED':
      return arabic ? 'ملغاة' : 'Cancelled';
    default:
      return _formatMatchTime(match.matchTime, arabic);
  }
}

bool _isLive(MatchModel match) {
  return match.status == 'IN_PLAY' ||
      match.status == 'PAUSED' ||
      match.status == 'LIVE';
}

// ==========================================
// 3. الشاشة الرئيسية
// ==========================================
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> with RouteAware {
  ModalRoute<dynamic>? _subscribedRoute;
  Timer? _systemUiTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enableHomeImmersiveMode();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route != null) {
        appRouteObserver.subscribe(this, route);
      }
    }
  }

  // خارج مشغل الفيديو: اخفِ الأشرطة، وأعد إخفاءها بعد خمس ثوانٍ من إظهارها.
  void _enableHomeImmersiveMode() {
    SystemChrome.setSystemUIChangeCallback((visible) async {
      if (!mounted) return;
      _systemUiTimer?.cancel();
      if (visible) {
        _systemUiTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
          }
        });
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  // المشغل يضبط واجهته بنفسه؛ نعيد وضع التطبيق العادي بعد إغلاقه فقط.
  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enableHomeImmersiveMode();
    });
  }

  @override
  void dispose() {
    _systemUiTimer?.cancel();
    appRouteObserver.unsubscribe(this);
    SystemChrome.setSystemUIChangeCallback(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            appName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF1B263B),
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                text: _isArabic(context) ? 'المباريات' : 'Matches',
                icon: const Icon(Icons.sports_soccer),
              ),
              Tab(
                text: _isArabic(context) ? 'القنوات الناقلة' : 'Channels',
                icon: const Icon(Icons.tv),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          physics: PageScrollPhysics(),
          children: [
            TodayMatchesTab(),
            BroadcastChannelsTab(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. تبويب المباريات
// ==========================================
class TodayMatchesTab extends StatefulWidget {
  const TodayMatchesTab({super.key});

  @override
  State<TodayMatchesTab> createState() => _TodayMatchesTabState();
}

class _TodayMatchesTabState extends State<TodayMatchesTab>
    with WidgetsBindingObserver {
  // القيم الممكنة فقط: -1 أمس، 0 اليوم، 1 غد.
  int _selectedDayOffset = 0;
  late String _todayKey;
  Timer? _dayRefreshTimer;
  final Set<String> _favoriteCompetitions = <String>{};

  DateTime get _selectedDate {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day + _selectedDayOffset,
    );
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _todayKey = _dateKey(DateTime.now());
    _scheduleDayRefresh();
    _loadFavorites();
  }

  void _scheduleDayRefresh() {
    _dayRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _dayRefreshTimer = Timer(delay, _refreshForSystemDate);
  }

  void _refreshForSystemDate() {
    if (!mounted) return;
    final currentTodayKey = _dateKey(DateTime.now());
    if (currentTodayKey != _todayKey) {
      setState(() {
        _todayKey = currentTodayKey;
      });
    }
    _scheduleDayRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshForSystemDate();
    }
  }

  @override
  void dispose() {
    _dayRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList('favorite_competitions') ?? [];

    if (!mounted) return;

    setState(() {
      _favoriteCompetitions
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _toggleFavorite(String code, String name) async {
    final key = code.isEmpty ? name : code;
    final arabic = _isArabic(context);

    // لا نفعّل المفضلة قبل الحصول على إذن الإشعارات.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            arabic
                ? 'يجب السماح بالإشعارات لتفعيل مفضلة الدوري'
                : 'Allow notifications to favorite this league',
          ),
        ),
      );
      return;
    }

    final topic = 'competition_${key}_${arabic ? 'ar' : 'en'}';
    final willFavorite = !_favoriteCompetitions.contains(key);

    if (willFavorite) {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }

    final preferences = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      if (willFavorite) {
        _favoriteCompetitions.add(key);
      } else {
        _favoriteCompetitions.remove(key);
      }
    });

    await preferences.setStringList(
      'favorite_competitions',
      _favoriteCompetitions.toList(),
    );
  }

  void _changeDate(int direction) {
    setState(() {
      // ترتيب الواجهة: أمس (-1)، اليوم (0)، غد (1)، ثم نلتف إلى البداية.
      var index = _selectedDayOffset + 1 + direction;
      index %= 3;
      if (index < 0) index += 3;
      _selectedDayOffset = index - 1;
    });
  }

  String _dayLabel(bool arabic) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (selected == today) return arabic ? 'اليوم' : 'Today';
    if (selected == today.subtract(const Duration(days: 1))) {
      return arabic ? 'أمس' : 'Yesterday';
    }
    if (selected == today.add(const Duration(days: 1))) {
      return arabic ? 'غدًا' : 'Tomorrow';
    }

    return '${selected.day.toString().padLeft(2, '0')}/'
        '${selected.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() >= 250) {
          _swipeBetweenMainTabs(context, velocity);
        }
      },
      child: NetworkGuard(
        builder: (context, reload) => _buildContent(context, reload),
      ),
    );
  }

  Widget _buildContent(BuildContext context, VoidCallback reload) {
    final arabic = _isArabic(context);

    return Column(
      children: [
        _buildDateNavigation(context, arabic),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_dateKey(_selectedDate)),
            // نقرأ السجلات القديمة والجديدة ثم نصفيها محليًا.
            // هذا يمنع اختفاء البيانات إذا كانت بعض السجلات القديمة لا تحتوي
            // على competitionCode أو competitionPriority.
            stream: FirebaseFirestore.instance
                .collection('matches')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              }

              if (snapshot.hasError) {
                return StatusMessageView(
                  icon: Icons.error_outline,
                  message: arabic
                      ? kLoadErrorMessage
                      : 'Loading error, please try again',
                  onReload: reload,
                );
              }

              final documents = snapshot.data?.docs ?? [];
              final groupedMatches = <String, List<MatchModel>>{};

              final selectedKey = _dateKey(_selectedDate);
              for (final document in documents) {
                final data = Map<String, dynamic>.from(
                  document.data() as Map<String, dynamic>,
                );
                final match = MatchModel.fromFirestore(data);
                final storedDate = (data['matchDateKey'] ?? '').toString();
                final derivedDate = _dateKey(match.matchTime);
                final actualDate = storedDate.isNotEmpty
                    ? storedDate
                    : derivedDate;

                if (actualDate != selectedKey) {
                  continue;
                }

                groupedMatches
                    .putIfAbsent(match.competitionName, () => [])
                    .add(match);
              }

              if (groupedMatches.isEmpty) {
                return Center(
                  child: Text(
                    arabic
                        ? 'لا توجد مباريات في هذا اليوم'
                        : 'No matches on this day',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              final groups = groupedMatches.entries.toList()
                ..sort((a, b) {
                  final aPriority = a.value.isEmpty
                      ? 1000
                      : a.value.first.competitionPriority;
                  final bPriority = b.value.isEmpty
                      ? 1000
                      : b.value.first.competitionPriority;
                  return aPriority.compareTo(bPriority);
                });

              for (final group in groups) {
                group.value.sort(
                      (a, b) => a.matchTime.compareTo(b.matchTime),
                );
              }

              return RefreshIndicator(
                color: Colors.amber,
                onRefresh: () async {
                  setState(() {});
                  await Future<void>.delayed(
                    const Duration(milliseconds: 400),
                  );
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    for (final group in groups)
                      _buildCompetitionSection(
                        context,
                        group.key,
                        group.value,
                        arabic,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateNavigation(BuildContext context, bool arabic) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172A46), Color(0xFF1B263B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: arabic ? 'اليوم السابق' : 'Previous day',
            icon: const Icon(Icons.chevron_left, color: Color(0xFF00E5FF)),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.live_tv,
                  color: Color(0xFFFF4D6D),
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  _dayLabel(arabic),
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: arabic ? 'اليوم التالي' : 'Next day',
            icon: const Icon(Icons.chevron_right, color: Color(0xFF00E5FF)),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitionSection(
      BuildContext context,
      String competitionName,
      List<MatchModel> matches,
      bool arabic,
      ) {
    final code = matches.isEmpty ? '' : matches.first.competitionCode;
    final favoriteKey = code.isEmpty ? competitionName : code;
    final isFavorite = _favoriteCompetitions.contains(favoriteKey);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 8, 10, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: arabic
                      ? 'تفعيل إشعارات هذا الدوري لاحقًا'
                      : 'Enable notifications for this league later',
                  onPressed: () => _toggleFavorite(
                    favoriteKey,
                    competitionName,
                  ),
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.white60,
                  ),
                ),
                Expanded(
                  child: Text(
                    _competitionTitle(competitionName, code, arabic),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          for (var i = 0; i < matches.length; i++)
            _buildMatchRow(
              context,
              matches[i],
              arabic,
              isLast: i == matches.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildMatchRow(
      BuildContext context,
      MatchModel match,
      bool arabic, {
        required bool isLast,
      }) {
    final live = _isLive(match);
    final stateText = _matchStateText(match, arabic);
    final stateColor = live
        ? Colors.redAccent
        : match.status == 'FINISHED'
        ? Colors.white54
        : Colors.amber;

    Widget teamLine(String name, String logo) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _teamTitle(name, arabic),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _logo(logo),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Column(
              children: [
                if (live)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.live_tv,
                        color: Colors.redAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          stateText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: stateColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    stateText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                teamLine(match.homeTeam, match.homeLogo),
                const SizedBox(height: 6),
                teamLine(match.awayTeam, match.awayLogo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(String url) {
    if (url.isEmpty) {
      return const Icon(
        Icons.sports_soccer,
        color: Colors.white54,
        size: 26,
      );
    }

    return Image.network(
      url,
      width: 26,
      height: 26,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return const Icon(
          Icons.sports_soccer,
          color: Colors.white54,
          size: 26,
        );
      },
    );
  }
}

void _swipeBetweenMainTabs(BuildContext context, double velocity) {
  final controller = DefaultTabController.of(context);
  if (velocity < 0 && controller.index < controller.length - 1) {
    controller.animateTo(controller.index + 1);
  } else if (velocity > 0 && controller.index > 0) {
    controller.animateTo(controller.index - 1);
  }
}

// ==========================================
// 6. تبويب القنوات الناقلة
// ==========================================
class BroadcastChannelsTab extends StatelessWidget {
  const BroadcastChannelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() >= 250) {
          _swipeBetweenMainTabs(context, velocity);
        }
      },
      child: NetworkGuard(
        builder: (context, reload) => _buildContent(context, reload),
      ),
    );
  }

  Widget _buildContent(BuildContext context, VoidCallback reload) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('channels')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.amber,
            ),
          );
        }

        if (snapshot.hasError) {
          return StatusMessageView(
            icon: Icons.error_outline,
            message: kLoadErrorMessage,
            onReload: reload,
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد قنوات متاحة',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          );
        }

        final documents = snapshot.data!.docs;
        final firstDocument = documents.first;
        final data = firstDocument.data() as Map<String, dynamic>;

        final providerName = data['providerName'] ?? 'مزود غير معروف';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelsPage(
                      providerId: firstDocument.id,
                      providerName: providerName,
                      isForSplit: false,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sports_soccer,
                      color: Color(0xFF00E5FF),
                      size: 42,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        providerName,
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF00E5FF),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 7. صفحة القنوات
// ==========================================
class ChannelsPage extends StatelessWidget {
  final String providerId;
  final String providerName;
  final bool isForSplit;

  const ChannelsPage({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.isForSplit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(
          'قنوات $providerName',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1B263B),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: NetworkGuard(
        builder: (context, reload) => _buildList(context, reload),
      ),
    );
  }

  Widget _buildList(BuildContext context, VoidCallback reload) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('channels')
          .doc(providerId)
          .collection('channel_list')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.amber,
            ),
          );
        }

        if (snapshot.hasError) {
          return StatusMessageView(
            icon: Icons.error_outline,
            message: kLoadErrorMessage,
            onReload: reload,
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد قنوات في هذا المزود',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          );
        }

        final channels = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final data = channels[index].data() as Map<String, dynamic>;

            final channelName = data['name'] ?? 'قناة غير معروفة';

            final qualities = data['qualities'] is Map
                ? Map<String, dynamic>.from(
              data['qualities'],
            )
                : <String, dynamic>{};

            final firstUrl =
            qualities.isNotEmpty ? qualities.values.first.toString() : '';

            return Material(
              color: const Color(0xFF1B263B),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (firstUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'هذه القناة لا تحتوي على روابط',
                        ),
                      ),
                    );
                    return;
                  }

                  if (isForSplit) {
                    Navigator.pop(
                      context,
                      {
                        'name': channelName,
                        'url': firstUrl,
                        'qualities': qualities,
                      },
                    );
                  } else {
                    Navigator.popUntil(
                      context,
                          (route) => route.isFirst,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerPage(
                          channelName: channelName,
                          streamUrl: firstUrl,
                          qualities: qualities,
                          providerId: providerId,
                          providerName: providerName,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF3CAC).withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                        const Color(0xFFFF3CAC).withValues(alpha: 0.16),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xFFFF3CAC),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          channelName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 8. حالة المشغل
// ==========================================
class _PlayerState {
  VideoPlayerController? controller;

  bool isLoading = true;
  bool isPlaying = false;
  bool isMuted = false;

  String? errorMessage;
  String currentQuality = '';
  String currentUrl = '';

  List<String> qualityList = [];
  Map<String, dynamic> qualities = {};

  void dispose() {
    final oldController = controller;
    controller = null;
    oldController?.dispose();
  }
}

// ==========================================
// 9. صفحة تشغيل الفيديو
// ==========================================
class VideoPlayerPage extends StatefulWidget {
  final String channelName;
  final String streamUrl;
  final Map<String, dynamic> qualities;
  final String? providerId;
  final String? providerName;

  const VideoPlayerPage({
    super.key,
    required this.channelName,
    required this.streamUrl,
    required this.qualities,
    this.providerId,
    this.providerName,
  });

  @override
  State<VideoPlayerPage> createState() {
    return _VideoPlayerPageState();
  }
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
  late final _PlayerState _player1;
  _PlayerState? _player2;

  String _splitMode = 'none';

  double _firstFlex = 50.0;
  double _secondFlex = 50.0;

  bool _isImmersive = false;
  bool _isLandscape = true;

  _PlayerState? _activePlayer;

  bool _controlsVisible = true;
  Timer? _controlsTimer;

  // إخفاء أشرطة النظام (الإشعارات وأزرار الرجوع) بعد ظهورها بالسحب
  Timer? _systemUiTimer;

  // هل الجهاز لوحي؟ (أصغر ضلع للشاشة 600 وحدة أو أكثر)
  bool _isLargeScreen = false;

  // سحب الفاصل بين الشاشتين
  final GlobalKey _splitKey = GlobalKey();
  double _dragGrabOffset = 0.0;
  static const double _dividerSize = 6.0;
  static const double _dividerTouchSize = 36.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIChangeCallback(_onSystemUiChange);

    // نقيس الشاشة الفعلية للجهاز (وليس نافذة التطبيق) قبل تغيير أي اتجاه
    final display =
        WidgetsBinding.instance.platformDispatcher.views.first.display;
    _isLargeScreen =
        display.size.shortestSide / display.devicePixelRatio >= 600;

    _player1 = _PlayerState();
    _activePlayer = _player1;

    _player1.qualities = Map<String, dynamic>.from(widget.qualities);

    _player1.qualityList = _getQualityList(_player1.qualities);

    _player1.currentQuality = _getInitialQuality(_player1.qualities);

    _initializePlayer(
      _player1,
      widget.streamUrl,
      _player1.qualities,
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _enableImmersiveMode();
    _showControlsAndRestartTimer();
  }

  String _getInitialQuality(
      Map<String, dynamic> qualities,
      ) {
    final keys = qualities.keys.toList();

    if (keys.isEmpty) {
      return '';
    }

    keys.sort((a, b) {
      final aValue = int.tryParse(
        a.replaceAll('p', ''),
      ) ??
          0;

      final bValue = int.tryParse(
        b.replaceAll('p', ''),
      ) ??
          0;

      return aValue.compareTo(bValue);
    });

    return keys.last;
  }

  List<String> _getQualityList(
      Map<String, dynamic> qualities,
      ) {
    final keys = qualities.keys.toList();

    keys.sort((a, b) {
      final aValue = int.tryParse(
        a.replaceAll('p', ''),
      ) ??
          0;

      final bValue = int.tryParse(
        b.replaceAll('p', ''),
      ) ??
          0;

      return aValue.compareTo(bValue);
    });

    return keys;
  }

  Future<void> _initializePlayer(
      _PlayerState player,
      String url,
      Map<String, dynamic> qualities,
      ) async {
    try {
      final oldController = player.controller;

      player.controller = null;
      player.isLoading = true;
      player.isPlaying = false;
      player.errorMessage = null;

      await oldController?.dispose();

      if (mounted) {
        setState(() {});
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );

      player.controller = controller;
      player.currentUrl = url;

      await controller.initialize();

      final isSecondPlayer = player == _player2;

      final shouldMute = player.isMuted || isSecondPlayer;

      await controller.setVolume(
        shouldMute ? 0.0 : 1.0,
      );

      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // إذا انقطع البث أثناء التشغيل تظهر رسالة الخطأ مع زر إعادة التحميل
      controller.addListener(() {
        if (!mounted ||
            player.controller != controller ||
            player.errorMessage != null ||
            !controller.value.hasError) {
          return;
        }

        _showPlayerError(player);
      });

      setState(() {
        player.isLoading = false;
        player.isPlaying = true;
        player.isMuted = shouldMute;
        player.errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showPlayerError(player);
    }
  }

  // يعرض رسالة مناسبة: لا يوجد إنترنت، أو خطأ في التحميل
  Future<void> _showPlayerError(_PlayerState player) async {
    final online = await hasInternet();

    if (!mounted) {
      return;
    }

    setState(() {
      player.isLoading = false;
      player.isPlaying = false;
      player.errorMessage = online ? kLoadErrorMessage : kNoInternetMessage;
    });
  }

  // إعادة تحميل القناة الحالية للمشغل المحدد
  void _reloadPlayer(_PlayerState player) {
    if (player.currentUrl.isEmpty) {
      return;
    }

    _initializePlayer(
      player,
      player.currentUrl,
      player.qualities,
    );
  }

  Future<void> _togglePlayPause(
      _PlayerState player,
      ) async {
    final controller = player.controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (player.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      player.isPlaying = !player.isPlaying;
    });

    _showControlsAndRestartTimer();
  }

  Future<void> _toggleMute(
      _PlayerState player,
      ) async {
    final controller = player.controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final muted = !player.isMuted;

    await controller.setVolume(
      muted ? 0.0 : 1.0,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      player.isMuted = muted;
    });

    _showControlsAndRestartTimer();
  }

  void _seekTo(
      _PlayerState player,
      double value,
      ) {
    final controller = player.controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;

    final position = Duration(
      milliseconds: (value * duration.inMilliseconds).round(),
    );

    controller.seekTo(position);

    _showControlsAndRestartTimer();
  }

  void _changeQuality(
      _PlayerState player,
      String quality,
      ) {
    if (quality == player.currentQuality) {
      return;
    }

    final url = player.qualities[quality] ?? widget.streamUrl;

    _initializePlayer(
      player,
      url.toString(),
      player.qualities,
    ).then((_) {
      if (player.isMuted) {
        player.controller?.setVolume(0.0);
      }
    });

    player.currentQuality = quality;

    setState(() {});
  }

  void _showControlsAndRestartTimer() {
    if (!mounted) {
      return;
    }

    setState(() {
      _controlsVisible = true;
    });

    _controlsTimer?.cancel();

    _controlsTimer = Timer(
      const Duration(seconds: 3),
          () {
        if (!mounted) {
          return;
        }

        setState(() {
          _controlsVisible = false;
        });
      },
    );
  }

  void _selectPlayer(
      _PlayerState player,
      ) {
    // الضغط على نفس الشاشة وخياراتها ظاهرة: تختفي الخيارات
    if (_controlsVisible && _activePlayer == player) {
      _controlsTimer?.cancel();

      setState(() {
        _controlsVisible = false;
      });

      return;
    }

    // الضغط وخيارات الشاشة مخفية (أو ظاهرة لشاشة أخرى): تظهر خيارات هذه الشاشة
    setState(() {
      _activePlayer = player;
      _controlsVisible = true;
    });

    _controlsTimer?.cancel();

    _controlsTimer = Timer(
      const Duration(seconds: 3),
          () {
        if (!mounted) {
          return;
        }

        setState(() {
          _controlsVisible = false;
        });
      },
    );
  }

  void _enableImmersiveMode() {
    // immersiveSticky: عند سحب شريط الإشعارات أو أزرار الرجوع تظهر مؤقتاً
    // ثم تختفي تلقائياً
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    if (mounted) {
      setState(() {
        _isImmersive = true;
      });
    }
  }

  void _disableImmersiveMode() {
    _systemUiTimer?.cancel();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    if (mounted) {
      setState(() {
        _isImmersive = false;
      });
    }
  }

  // يُستدعى عند ظهور أو اختفاء أشرطة النظام
  Future<void> _onSystemUiChange(bool systemOverlaysAreVisible) async {
    if (!mounted || !_isImmersive) {
      return;
    }

    _systemUiTimer?.cancel();

    if (systemOverlaysAreVisible) {
      // إذا بقيت الأشرطة ظاهرة نعيد إخفاءها بعد ثلاث ثوانٍ
      _systemUiTimer = Timer(
        const Duration(seconds: 3),
            () {
          if (!mounted || !_isImmersive) {
            return;
          }

          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
          );
        },
      );
    }
  }

  // عند العودة للتطبيق (مثلاً بعد إغلاق لوحة الإشعارات) نعيد وضع ملء الشاشة
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isImmersive) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    }
  }

  void _toggleImmersive() {
    if (_isImmersive) {
      _disableImmersiveMode();
    } else {
      _enableImmersiveMode();
    }

    _showControlsAndRestartTimer();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    _showControlsAndRestartTimer();
  }

  void _setSplitMode(
      String mode,
      ) {
    if (!_controlsVisible) {
      _showControlsAndRestartTimer();
      return;
    }

    setState(() {
      if (_splitMode == mode) {
        _splitMode = 'none';

        _player2?.dispose();
        _player2 = null;

        _activePlayer = _player1;

        _firstFlex = 50.0;
        _secondFlex = 50.0;
      } else {
        _player2 ??= _PlayerState()
          ..isLoading = false
          ..isMuted = true;

        _splitMode = mode;

        _firstFlex = 50.0;
        _secondFlex = 50.0;
      }
    });

    _showControlsAndRestartTimer();
  }

  void _resetSplit() {
    setState(() {
      _firstFlex = 50.0;
      _secondFlex = 50.0;
    });

    _showControlsAndRestartTimer();
  }

  void _showProviderList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1B2A),
            appBar: AppBar(
              title: const Text(
                'اختر المزود',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF1B263B),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: NetworkGuard(
              builder: (context, reload) => StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('channels')
                    .orderBy('order')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.amber,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return StatusMessageView(
                      icon: Icons.error_outline,
                      message: kLoadErrorMessage,
                      onReload: reload,
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد قنوات متاحة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  final providers = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: providers.length,
                    itemBuilder: (context, index) {
                      final providerData =
                      providers[index].data() as Map<String, dynamic>;

                      final providerName =
                          providerData['providerName'] ?? 'مزود غير معروف';

                      final providerId = providers[index].id;

                      return Material(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(context);

                            _showChannelsListForSplit(
                              providerId,
                              providerName.toString(),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(
                              bottom: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.tv,
                                  color: Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    providerName.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChannelsListForSplit(
      String providerId,
      String providerName,
      ) {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ChannelsPage(
            providerId: providerId,
            providerName: providerName,
            isForSplit: true,
          );
        },
      ),
    ).then((result) {
      if (result != null &&
          result.containsKey('url') &&
          result['url'] != null &&
          _player2 != null) {
        final url = result['url'];

        final qualities = result['qualities'] is Map
            ? Map<String, dynamic>.from(
          result['qualities'],
        )
            : <String, dynamic>{};

        _player2!.qualities = Map<String, dynamic>.from(qualities);

        _player2!.currentQuality = _getInitialQuality(qualities);

        _player2!.qualityList = _getQualityList(qualities);

        _player2!.isLoading = true;

        setState(() {});

        _initializePlayer(
          _player2!,
          url.toString(),
          qualities,
        ).then((_) {
          if (_player2?.controller != null) {
            _player2!.controller!.setVolume(0.0);
            _player2!.isMuted = true;
          }

          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }

  void _openChannelListForSecond() {
    if (widget.providerId != null && widget.providerName != null) {
      Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) {
            return ChannelsPage(
              providerId: widget.providerId!,
              providerName: widget.providerName!,
              isForSplit: true,
            );
          },
        ),
      ).then((result) {
        if (result != null &&
            result.containsKey('url') &&
            result['url'] != null &&
            _player2 != null) {
          final url = result['url'];

          final qualities = result['qualities'] is Map
              ? Map<String, dynamic>.from(
            result['qualities'],
          )
              : <String, dynamic>{};

          _player2!.qualities = Map<String, dynamic>.from(qualities);

          _player2!.currentQuality = _getInitialQuality(qualities);

          _player2!.qualityList = _getQualityList(qualities);

          _player2!.isLoading = true;

          setState(() {});

          _initializePlayer(
            _player2!,
            url.toString(),
            qualities,
          ).then((_) {
            if (_player2?.controller != null) {
              _player2!.controller!.setVolume(0.0);
              _player2!.isMuted = true;
            }

            if (mounted) {
              setState(() {});
            }
          });
        }
      });
    } else {
      _showProviderList();
    }
  }

  Widget _buildPlayerWidget(
      _PlayerState player,
      String channelName,
      bool isMain,
      ) {
    final controller = player.controller;

    if (!isMain && _splitMode != 'none' && controller == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_controlsVisible) {
            _selectPlayer(player);
            return;
          }

          _activePlayer = player;
          _showProviderList();
        },
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _selectPlayer(player);
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: player.isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.amber,
                ),
              )
                  : player.errorMessage != null
                  ? StatusMessageView(
                icon: player.errorMessage == kNoInternetMessage
                    ? Icons.wifi_off
                    : Icons.error_outline,
                message: player.errorMessage!,
                onReload: () {
                  _reloadPlayer(player);
                },
              )
                  : controller != null && controller.value.isInitialized
                  ? Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
                  : const SizedBox.shrink(),
            ),

            // زر الرجوع يظهر ويختفي مع بقية الخيارات
            if (!isMain && _splitMode != 'none' && _controlsVisible)
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: Material(
                    color: Colors.black.withValues(
                      alpha: 0.65,
                    ),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        _activePlayer = player;
                        _openChannelListForSecond();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (!isMain && _splitMode != 'none' && player.isMuted)
              const Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  Icons.volume_off,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // الفاصل بين الشاشتين (الشكل فقط، والسحب من منطقة اللمس الأكبر فوقه)
  Widget _buildDivider() {
    return Container(
      width: _splitMode == 'horizontal' ? _dividerSize : double.infinity,
      height: _splitMode == 'vertical' ? _dividerSize : double.infinity,
      color: Colors.white.withValues(
        alpha: 0.3,
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.2,
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.2,
              ),
            ),
          ),
          child: Icon(
            _splitMode == 'horizontal'
                ? Icons.drag_handle
                : Icons.drag_indicator,
            color: Colors.white.withValues(
              alpha: 0.5,
            ),
            size: 16,
          ),
        ),
      ),
    );
  }

  RenderBox? _splitBox() {
    final box = _splitKey.currentContext?.findRenderObject();

    if (box is RenderBox && box.hasSize) {
      return box;
    }

    return null;
  }

  // طول المساحة التي تحتوي الشاشتين على محور السحب
  double _splitTotal(RenderBox box) {
    return _splitMode == 'horizontal' ? box.size.width : box.size.height;
  }

  // موضع الإصبع على محور السحب، بدءاً من بداية الشاشة الأولى
  double _fingerPosition(RenderBox box, Offset globalPosition) {
    final local = box.globalToLocal(globalPosition);

    if (_splitMode == 'horizontal') {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return rtl ? box.size.width - local.dx : local.dx;
    }

    return local.dy;
  }

  // مركز الفاصل الحالي على محور السحب
  double _dividerCenter(double total) {
    return (total - _dividerSize) * _firstFlex / 100.0 + _dividerSize / 2;
  }

  void _onDividerDragStart(DragStartDetails details) {
    final box = _splitBox();

    if (box == null) {
      return;
    }

    final position = _fingerPosition(box, details.globalPosition);

    // نحفظ المسافة بين الإصبع ومركز الفاصل حتى لا يقفز الفاصل عند اللمس
    _dragGrabOffset = position - _dividerCenter(_splitTotal(box));
  }

  // الفاصل يتبع الإصبع مباشرة: الشاشة التي يتجه نحوها الإصبع تصغر والأخرى تكبر
  void _onDividerDragUpdate(DragUpdateDetails details) {
    final box = _splitBox();

    if (box == null) {
      return;
    }

    final total = _splitTotal(box);

    if (total <= _dividerSize) {
      return;
    }

    final center = _fingerPosition(box, details.globalPosition) - _dragGrabOffset;

    final fraction = (center - _dividerSize / 2) / (total - _dividerSize) * 100.0;

    setState(() {
      _firstFlex = fraction.clamp(25.0, 75.0).toDouble();
      _secondFlex = 100.0 - _firstFlex;
    });
  }

  // الشاشتان مع الفاصل، ومنطقة سحب أوسع تعمل دائماً حتى لو كانت الخيارات مخفية
  Widget _buildSplitLayout() {
    final horizontal = _splitMode == 'horizontal';

    final List<Widget> players = [
      Expanded(
        flex: (_firstFlex * 100).round(),
        child: _buildPlayerWidget(
          _player1,
          widget.channelName,
          true,
        ),
      ),
      _buildDivider(),
      Expanded(
        flex: (_secondFlex * 100).round(),
        child: _buildPlayerWidget(
          _player2!,
          '',
          false,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = horizontal ? constraints.maxWidth : constraints.maxHeight;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final start = _dividerCenter(total) - _dividerTouchSize / 2;

        final touchArea = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onDividerDragStart,
          onPanUpdate: _onDividerDragUpdate,
          child: const SizedBox.expand(),
        );

        return Stack(
          key: _splitKey,
          children: [
            Positioned.fill(
              child: horizontal
                  ? Row(children: players)
                  : Column(children: players),
            ),
            if (horizontal)
              Positioned(
                left: rtl ? total - start - _dividerTouchSize : start,
                width: _dividerTouchSize,
                top: 0,
                bottom: 0,
                child: touchArea,
              )
            else
              Positioned(
                top: start,
                height: _dividerTouchSize,
                left: 0,
                right: 0,
                child: touchArea,
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _systemUiTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setSystemUIChangeCallback(null);

    _player1.dispose();
    _player2?.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // الأجهزة اللوحية: نترك الاتجاه للنظام ليبقى التطبيق بكامل الشاشة.
    // (تثبيته على الوضع الطولي يجعله يظهر بحجم الجوال في منتصف الشاشة)
    SystemChrome.setPreferredOrientations(
      _isLargeScreen
          ? <DeviceOrientation>[]
          : <DeviceOrientation>[DeviceOrientation.portraitUp],
    );

    super.dispose();
  }

  Widget _buildMainControls(
      bool isSplit,
      ) {
    final player = _activePlayer ?? _player1;
    final controller = player.controller;

    final initialized = controller != null && controller.value.isInitialized;

    final durationMs =
    initialized ? controller.value.duration.inMilliseconds : 0;

    final positionMs =
    initialized ? controller.value.position.inMilliseconds : 0;

    final maxValue = durationMs > 0 ? durationMs.toDouble() : 1.0;

    final currentValue = positionMs
        .clamp(
      0,
      durationMs > 0 ? durationMs : 1,
    )
        .toDouble();

    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(
          milliseconds: 250,
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(
                    alpha: 0.9,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: initialized
                      ? () {
                    _togglePlayPause(player);
                  }
                      : null,
                ),
                IconButton(
                  icon: Icon(
                    player.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: initialized
                      ? () {
                    _toggleMute(player);
                  }
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: currentValue,
                    max: maxValue,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.white30,
                    onChanged: initialized && durationMs > 0
                        ? (value) {
                      _seekTo(player, value);
                    }
                        : null,
                  ),
                ),
                if (player.qualityList.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: player.qualityList.contains(
                        player.currentQuality,
                      )
                          ? player.currentQuality
                          : player.qualityList.first,
                      dropdownColor: const Color(0xFF1B263B),
                      icon: const Icon(
                        Icons.high_quality,
                        color: Colors.amber,
                      ),
                      items: player.qualityList.map(
                            (quality) {
                          return DropdownMenuItem<String>(
                            value: quality,
                            child: Text(
                              quality,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (quality) {
                        if (quality != null) {
                          _changeQuality(
                            player,
                            quality,
                          );
                        }
                      },
                    ),
                  ),
                if (isSplit)
                  IconButton(
                    icon: Icon(
                      (_firstFlex - 50.0).abs() < 0.1
                          ? Icons.aspect_ratio
                          : Icons.restore,
                      color: Colors.white,
                    ),
                    tooltip: (_firstFlex - 50.0).abs() < 0.1
                        ? 'الحجم الافتراضي'
                        : 'إعادة الحجم الافتراضي',
                    onPressed: _resetSplit,
                  ),
                IconButton(
                  icon: Icon(
                    _splitMode == 'horizontal'
                        ? Icons.merge_type
                        : Icons.view_week,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _setSplitMode('horizontal');
                  },
                ),
                IconButton(
                  icon: Icon(
                    _splitMode == 'vertical'
                        ? Icons.merge_type
                        : Icons.view_day,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _setSplitMode('vertical');
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isImmersive ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: _toggleImmersive,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.screen_rotation,
                    color: Colors.white,
                  ),
                  onPressed: _toggleOrientation,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSplit = _splitMode != 'none';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: isSplit
                ? _buildSplitLayout()
                : _buildPlayerWidget(
              _player1,
              widget.channelName,
              true,
            ),
          ),
          if (_controlsVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.channelName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMainControls(isSplit),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 10. شاشة BeIN Sports Channels
// ==========================================
class BeinSportsChannelsPage extends StatelessWidget {
  const BeinSportsChannelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BeIN Sports'),
        backgroundColor: const Color(0xFF1B263B),
      ),
      body: const Center(
        child: Text(
          'تم نقل هذه الصفحة إلى ChannelsPage',
        ),
      ),
    );
  }
}

// ==========================================
// 11. أدوات الاتصال بالإنترنت ورسائل الأخطاء
// ==========================================
const String kNoInternetMessage =
    'لا يوجد اتصال بالإنترنت، يرجى الاتصال بالإنترنت أولاً';

const String kLoadErrorMessage = 'خطأ في التحميل، يرجى إعادة المحاولة';

/// يتحقق من وجود إنترنت فعلي (واي فاي أو بيانات الهاتف أو أي طريقة اتصال)
Future<bool> hasInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com').timeout(
      const Duration(seconds: 3),
    );

    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// رسالة في منتصف الشاشة مع زر اختياري لإعادة التحميل
class StatusMessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onReload;

  const StatusMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            if (onReload != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onReload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة التحميل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// يعرض محتواه فقط عند وجود إنترنت، وإلا تظهر رسالة عدم الاتصال.
/// يعيد الفحص كل 5 ثوانٍ، وعند عودة الإنترنت يعود المحتوى تلقائياً.
/// الدالة reload تعيد بناء المحتوى من جديد (إعادة تحميل الصفحة).
class NetworkGuard extends StatefulWidget {
  final Widget Function(BuildContext context, VoidCallback reload) builder;

  const NetworkGuard({
    super.key,
    required this.builder,
  });

  @override
  State<NetworkGuard> createState() => _NetworkGuardState();
}

class _NetworkGuardState extends State<NetworkGuard> {
  bool? _online; // null = جاري الفحص
  int _attempt = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _check();

    _timer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _check(),
    );
  }

  Future<void> _check() async {
    final online = await hasInternet();

    if (!mounted || _online == online) {
      return;
    }

    setState(() {
      _online = online;
    });
  }

  void _reload() {
    setState(() {
      _attempt++;
    });

    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.amber,
        ),
      );
    }

    if (_online == false) {
      return const StatusMessageView(
        icon: Icons.wifi_off,
        message: kNoInternetMessage,
      );
    }

    return KeyedSubtree(
      key: ValueKey(_attempt),
      child: widget.builder(context, _reload),
    );
  }
}
