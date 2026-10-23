import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

/// اسم التطبيق حسب لغة هاتف المستخدم
String get appName =>
    WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar'
        ? 'أوف سايد'
        : 'Offside';

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
  final String homeTeam;
  final String awayTeam;
  final String homeLogo;
  final String awayLogo;
  final DateTime matchTime;
  final String competitionName;
  final String matchDateKey;

  MatchModel({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogo,
    required this.awayLogo,
    required this.matchTime,
    required this.competitionName,
    required this.matchDateKey,
  });

  factory MatchModel.fromFirestore(
      Map<String, dynamic> json,
      ) {
    final rawTime = json['matchTime'];

    DateTime parsedTime;

    if (rawTime is Timestamp) {
      parsedTime = rawTime.toDate().toLocal();
    } else if (rawTime is String) {
      parsedTime = DateTime.parse(rawTime).toLocal();
    } else {
      parsedTime = DateTime.now();
    }

    return MatchModel(
      homeTeam: json['homeTeam'] ?? 'Home Team',
      awayTeam: json['awayTeam'] ?? 'Away Team',
      homeLogo: json['homeLogo'] ?? '',
      awayLogo: json['awayLogo'] ?? '',
      matchTime: parsedTime,
      competitionName: json['competitionName'] ?? 'Football Competition',
      matchDateKey: json['matchDateKey'] ?? '',
    );
  }
}

// ==========================================
// 3. الشاشة الرئيسية
// ==========================================
class MainHomeScreen extends StatelessWidget {
  const MainHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            appName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF1B263B),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                text: 'مباريات اليوم',
                icon: Icon(Icons.sports_soccer),
              ),
              Tab(
                text: 'القنوات الناقلة',
                icon: Icon(Icons.tv),
              ),
            ],
          ),
        ),
        body: const TabBarView(
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
class TodayMatchesTab extends StatelessWidget {
  const TodayMatchesTab({super.key});

  String _todayKey() {
    final now = DateTime.now();

    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return '${now.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where(
        'matchDateKey',
        isEqualTo: _todayKey(),
      )
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
          return Center(
            child: Text(
              'Firestore error: ${snapshot.error}',
              style: const TextStyle(
                color: Colors.redAccent,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final groupedMatches = <String, List<MatchModel>>{};

        for (final document in documents) {
          final data = document.data() as Map<String, dynamic>;

          final match = MatchModel.fromFirestore(data);

          groupedMatches
              .putIfAbsent(
            match.competitionName,
                () => [],
          )
              .add(match);
        }

        if (groupedMatches.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد مباريات اليوم',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: groupedMatches.entries.map(
                (entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(
                      top: 8,
                      bottom: 10,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF415A77),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                        (match) => MatchCard(match: match),
                  ),
                ],
              );
            },
          ).toList(),
        );
      },
    );
  }
}

// ==========================================
// 5. بطاقة المباراة
// ==========================================
class MatchCard extends StatefulWidget {
  final MatchModel match;

  const MatchCard({
    super.key,
    required this.match,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    _updateRemaining();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final difference = widget.match.matchTime.difference(
      DateTime.now(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _remaining = difference.isNegative ? Duration.zero : difference;
    });
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _countdownText() {
    if (_remaining == Duration.zero) {
      return 'LIVE';
    }

    final days = _remaining.inDays;

    final hours = _twoDigits(
      _remaining.inHours.remainder(24),
    );

    final minutes = _twoDigits(
      _remaining.inMinutes.remainder(60),
    );

    final seconds = _twoDigits(
      _remaining.inSeconds.remainder(60),
    );

    if (days > 0) {
      return '$days يوم $hours:$minutes:$seconds';
    }

    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _team(
      String name,
      String logo,
      ) {
    return Expanded(
      child: Column(
        children: [
          logo.isEmpty
              ? const Icon(
            Icons.sports_soccer,
            size: 52,
            color: Colors.white70,
          )
              : Image.network(
            logo,
            height: 52,
            width: 52,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.sports_soccer,
                size: 52,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B263B),
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              '${widget.match.matchTime.hour.toString().padLeft(2, '0')}:${widget.match.matchTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _team(
                  widget.match.homeTeam,
                  widget.match.homeLogo,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _team(
                  widget.match.awayTeam,
                  widget.match.awayLogo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _remaining == Duration.zero
                    ? Colors.redAccent.withValues(
                  alpha: 0.18,
                )
                    : Colors.amber.withValues(
                  alpha: 0.14,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _countdownText(),
                style: TextStyle(
                  color: _remaining == Duration.zero
                      ? Colors.redAccent
                      : Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. تبويب القنوات الناقلة
// ==========================================
class BroadcastChannelsTab extends StatelessWidget {
  const BroadcastChannelsTab({super.key});

  @override
  Widget build(BuildContext context) {
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
          return Center(
            child: Text(
              'خطأ: ${snapshot.error}',
              style: const TextStyle(
                color: Colors.redAccent,
              ),
            ),
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
      body: StreamBuilder<QuerySnapshot>(
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
            return Center(
              child: Text(
                'خطأ: ${snapshot.error}',
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
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
      ),
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

class _VideoPlayerPageState extends State<VideoPlayerPage> {
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

  @override
  void initState() {
    super.initState();

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

      setState(() {
        player.isLoading = false;
        player.isPlaying = true;
        player.isMuted = shouldMute;
        player.errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        player.isLoading = false;
        player.isPlaying = false;
        player.errorMessage = 'فشل في تحميل البث:\n$error';
      });
    }
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
    if (!_controlsVisible || _activePlayer != player) {
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

      return;
    }

    _showControlsAndRestartTimer();
  }

  void _enableImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersive,
      overlays: [],
    );

    if (mounted) {
      setState(() {
        _isImmersive = true;
      });
    }
  }

  void _disableImmersiveMode() {
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
            body: StreamBuilder<QuerySnapshot>(
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
                  return Center(
                    child: Text(
                      'خطأ: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
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
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    player.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
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

  // الفاصل المتحرك بين القناتين
  Widget _buildDivider() {
    return GestureDetector(
      onPanUpdate: (details) {
        final delta = _splitMode == 'horizontal'
            ? details.delta.dx
            : details.delta.dy;

        final availableSize = _splitMode == 'horizontal'
            ? MediaQuery.of(context).size.width
            : MediaQuery.of(context).size.height;

        if (availableSize <= 0 || delta.abs() < 0.1) {
          return;
        }

        final direction = _activePlayer == _player2 ? -1.0 : 1.0;

        final change = direction * delta / availableSize * 100.0;

        setState(() {
          final newFirst = (_firstFlex + change).clamp(25.0, 75.0).toDouble();

          _firstFlex = newFirst;
          _secondFlex = 100.0 - newFirst;
        });
      },
      child: Container(
        width: _splitMode == 'horizontal' ? 6 : double.infinity,
        height: _splitMode == 'vertical' ? 6 : double.infinity,
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
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();

    _player1.dispose();
    _player2?.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

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
                ? _splitMode == 'horizontal'
                ? Row(
              children: [
                Expanded(
                  flex: _firstFlex.round(),
                  child: _buildPlayerWidget(
                    _player1,
                    widget.channelName,
                    true,
                  ),
                ),
                _buildDivider(),
                Expanded(
                  flex: _secondFlex.round(),
                  child: _buildPlayerWidget(
                    _player2!,
                    '',
                    false,
                  ),
                ),
              ],
            )
                : Column(
              children: [
                Expanded(
                  flex: _firstFlex.round(),
                  child: _buildPlayerWidget(
                    _player1,
                    widget.channelName,
                    true,
                  ),
                ),
                _buildDivider(),
                Expanded(
                  flex: _secondFlex.round(),
                  child: _buildPlayerWidget(
                    _player2!,
                    '',
                    false,
                  ),
                ),
              ],
            )
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