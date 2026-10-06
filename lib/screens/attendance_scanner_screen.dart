import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/attendance_storage.dart';
import '../services/class_schedule.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';
import 'attendance_report_screen.dart';
import 'class_days_screen.dart';

/// The attendance screen: the phone camera reads a student's QR code, the
/// student is checked in for today, and the list underneath shows everyone who
/// is already present.
///
/// Where the camera is not available (a computer) or a student forgot their
/// code, the student number can be typed instead: the keyboard button in the
/// header does the same check-in.
class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() =>
      _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final AttendanceStorage _storage = AttendanceStorage();

  /// Plays the short confirmation beep when a check-in is recorded.
  final AudioPlayer _beep = AudioPlayer();

  /// Plays the error sound when a student who is already clocked in today is
  /// scanned again. A separate player, so the two sounds never cut each other
  /// off.
  final AudioPlayer _error = AudioPlayer();

  List<AttendanceEntry> _today = const [];
  CheckInResult? _last;

  /// Whether the owner marked today as training cancelled. Today then has no
  /// present list and nobody can be checked in.
  bool _cancelledToday = false;

  /// True while a check-in is being written, so a camera that reports the same
  /// code many times a second cannot start a second one on top of it.
  bool _busy = false;

  /// The last code the camera reported and when, so holding a code in front of
  /// the lens does not flash the same answer over and over.
  String? _lastRaw;
  DateTime? _lastRawAt;
  static const Duration _sameCodePause = Duration(seconds: 3);

  /// The camera plugin works on phones; on a computer the typed number is the
  /// way to check in.
  static bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _prepareSounds();
    _loadToday();
  }

  @override
  void dispose() {
    _beep.dispose();
    _error.dispose();
    super.dispose();
  }

  /// Sets both players up: the low-latency mode so a sound follows the scan at
  /// once, and full player volume. (1.0 is the most the player can do; to make
  /// a sound louder than that, the audio file itself has to be louder.)
  Future<void> _prepareSounds() async {
    for (final player in [_beep, _error]) {
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setVolume(1.0);
      } catch (_) {
        // Sound is a nicety: a device without audio must not stop attendance.
      }
    }
  }

  /// The confirmation beep for a newly recorded check-in. Any audio problem
  /// (no sound device, a missing file) is ignored on purpose.
  Future<void> _playBeep() async {
    try {
      await _beep.stop();
      await _beep.play(AssetSource('sound/beep.mp3'), volume: 1.0);
    } catch (_) {}
  }

  /// The error sound for a student who is already clocked in today.
  Future<void> _playError() async {
    try {
      await _error.stop();
      await _error.play(AssetSource('sound/error.mp3'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> _loadToday() async {
    try {
      final entries = await _storage.loadDay(DateTime.now());
      final cancelled = ClassSchedule.isCancelled(
        await ClassSchedule().loadCancelled(),
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _today = entries;
        _cancelledToday = cancelled;
      });
    } catch (_) {
      // The list is a convenience: a read problem must not stop check-in.
    }
  }

  /// Runs one check-in and shows its answer. Only one runs at a time.
  Future<void> _run(Future<CheckInResult> Function() checkIn) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await checkIn();
      if (!mounted) return;
      if (result.status == CheckInStatus.recorded) {
        HapticFeedback.mediumImpact();
        _playBeep();
      } else if (result.status == CheckInStatus.alreadyPresent) {
        _playError();
      }
      setState(() {
        _last = result;
        if (result.status == CheckInStatus.trainingCancelled) {
          _cancelledToday = true;
        }
      });
      if (result.status == CheckInStatus.recorded) await _loadToday();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not record attendance. Please try again.'),
          ),
        );
    } finally {
      _busy = false;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    final now = DateTime.now();
    final lastAt = _lastRawAt;
    final repeated =
        raw == _lastRaw &&
        lastAt != null &&
        now.difference(lastAt) < _sameCodePause;
    if (repeated) return;
    final scanned = raw;
    _lastRaw = scanned;
    _lastRawAt = now;
    _run(() => _storage.checkInScanned(scanned));
  }

  Future<void> _openClassDays() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ClassDaysScreen()),
    );
    // A day may have been cancelled or restored there.
    if (mounted) await _loadToday();
  }

  Future<void> _openReport() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AttendanceReportScreen()),
    );
    // The report can cancel or restore today's training.
    if (mounted) await _loadToday();
  }

  Future<void> _enterNumber() async {
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => const _StudentNumberDialog(),
    );
    if (entered == null || entered.trim().isEmpty || !mounted) return;
    await _run(() => _storage.checkInByStudentNo(entered));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          if (_cameraSupported)
            Expanded(flex: 5, child: _cameraArea())
          else
            _noCameraCard(),
          Expanded(flex: 4, child: _todayList()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    return Container(
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _dayLabel(now),
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Attendance report',
                icon: const Icon(Icons.event_note_outlined, color: Colors.white),
                onPressed: _openReport,
              ),
              IconButton(
                tooltip: 'Class days',
                icon: const Icon(Icons.calendar_view_week, color: Colors.white),
                onPressed: _openClassDays,
              ),
              IconButton(
                tooltip: 'Enter student number',
                icon: const Icon(Icons.keyboard_outlined, color: Colors.white),
                onPressed: _enterNumber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraArea() {
    final last = _last;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraProblem(error: error),
          ),
        ),
        // A frame to aim the code into. Purely visual: the whole picture is
        // scanned, not only the inside of the frame.
        IgnorePointer(
          child: Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white70, width: 3),
              ),
            ),
          ),
        ),
        if (last != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _ResultBanner(outcome: _describe(last)),
          ),
      ],
    );
  }

  Widget _noCameraCard() {
    final last = _last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 32,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Camera scanning works on Android and iOS phones. Here you '
                  'can record attendance by typing the student number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _enterNumber,
                  child: const Text('Enter student number'),
                ),
              ],
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 12),
            _ResultBanner(outcome: _describe(last)),
          ],
        ],
      ),
    );
  }

  Widget _todayList() {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              _cancelledToday
                  ? 'Present today (-)'
                  : 'Present today (${_today.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
          ),
          Expanded(
            child: _today.isEmpty
                ? Center(
                    child: Text(
                      _cancelledToday
                          ? 'Training is cancelled today. No one is counted '
                                'present or absent.'
                          : 'No one has clocked in yet today.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _today.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = _today[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            StudentAvatar(
                              student: entry.student,
                              size: 40,
                              borderRadius: 10,
                              initialsFontSize: 14,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(entry.checkedInAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
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
  }

  _Outcome _describe(CheckInResult result) {
    final name = result.student?.name ?? '';
    final at = result.checkedInAt == null
        ? ''
        : _formatTime(result.checkedInAt!);
    return switch (result.status) {
      CheckInStatus.recorded => _Outcome(
        color: const Color(0xFF15803D),
        icon: Icons.check_circle,
        title: name,
        detail: 'Clocked In at $at',
      ),
      CheckInStatus.alreadyPresent => _Outcome(
        color: const Color(0xFFB45309),
        icon: Icons.info,
        title: name,
        detail: 'Already clocked in today at $at',
      ),
      CheckInStatus.inTrash => _Outcome(
        color: AppColors.red,
        icon: Icons.block,
        title: name,
        detail: 'This student is in the Trash. Restore them first.',
      ),
      CheckInStatus.trainingCancelled => const _Outcome(
        color: AppColors.cancelled,
        foreground: AppColors.onCancelled,
        icon: Icons.event_busy,
        title: 'Training cancelled today',
        detail:
            'No one is counted present or absent. Remove the cancellation in '
            'Class days to check students in.',
      ),
      CheckInStatus.unknown => const _Outcome(
        color: AppColors.red,
        icon: Icons.help_outline,
        title: 'Not recognised',
        detail: 'No student in this registry matches that code or number.',
      ),
    };
  }
}

/// What the banner shows for one check-in.
class _Outcome {
  const _Outcome({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
    this.foreground = Colors.white,
  });

  final Color color;

  /// Colour of the icon and the text drawn on [color].
  final Color foreground;
  final IconData icon;
  final String title;
  final String detail;
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.outcome});

  final _Outcome outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: outcome.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(outcome.icon, color: outcome.foreground, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcome.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: outcome.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  outcome.detail,
                  style: TextStyle(color: outcome.foreground, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the camera when it cannot start: most often the camera
/// permission was refused.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: AppColors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(
            denied
                ? 'Camera permission is off. Allow the camera for this app in '
                      'the phone settings, then come back. You can still type a '
                      'student number with the keyboard button above.'
                : 'The camera could not start. You can still type a student '
                      'number with the keyboard button above.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Asks for a student number. It owns its text controller, so the controller is
/// disposed only after the dialog has finished closing.
class _StudentNumberDialog extends StatefulWidget {
  const _StudentNumberDialog();

  @override
  State<_StudentNumberDialog> createState() => _StudentNumberDialogState();
}

class _StudentNumberDialogState extends State<_StudentNumberDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter student number'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'e.g. 12 or TKD-0012'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Check in'),
        ),
      ],
    );
  }
}

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dayLabel(DateTime day) =>
    '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
