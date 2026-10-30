import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoicePhase {
  /// Asking for the mic and the recognizer.
  starting,
  listening,

  /// Stopped with something heard.
  done,

  /// No recognizer, or the mic / speech permission was refused.
  unavailable,

  /// Stopped without hearing anything usable.
  nothingHeard,
}

class VoiceState {
  const VoiceState({
    this.phase = VoicePhase.starting,
    this.transcript = '',
    this.level = 0,
  });

  final VoicePhase phase;
  final String transcript;

  /// Mic loudness 0…1, for the listening animation.
  final double level;

  VoiceState copyWith({VoicePhase? phase, String? transcript, double? level}) =>
      VoiceState(
        phase: phase ?? this.phase,
        transcript: transcript ?? this.transcript,
        level: level ?? this.level,
      );
}

/// One voice entry: listens through the phone's own speech recognizer
/// (Google on Android, Apple on iOS) in Indian English, which copes with
/// Hinglish, and stops after a short pause. Lives while the voice sheet is
/// open (autoDispose), which also stops the mic.
final voiceEntryProvider =
    NotifierProvider.autoDispose<VoiceEntryController, VoiceState>(
      VoiceEntryController.new,
    );

class VoiceEntryController extends Notifier<VoiceState> {
  /// One recognizer for the app: initializing again re-asks permissions.
  static final SpeechToText _speech = SpeechToText();
  static bool _ready = false;

  /// The open sheet's controller. The recognizer's status and error
  /// callbacks are set once, at initialize, so they go through this.
  static VoiceEntryController? _active;

  static const _listenFor = Duration(seconds: 20);

  /// Ends the session if the recognizer never reports it done (seen on
  /// iOS: "Listening…" stayed up after the time limit).
  Timer? _deadline;

  /// When this session started, and whether it had to set the recognizer
  /// up (the permission prompts) first: that first session can end at
  /// once with nothing heard, so it's retried once.
  DateTime? _startedAt;
  bool _retryOnQuickEnd = false;

  @override
  VoiceState build() {
    _active = this;
    ref.onDispose(() {
      _deadline?.cancel();
      if (identical(_active, this)) _active = null;
      if (_speech.isListening) _speech.cancel();
    });
    return const VoiceState();
  }

  Future<void> start() async {
    state = const VoiceState();
    _retryOnQuickEnd = !_ready;
    if (!_ready) {
      try {
        _ready = await _speech.initialize(
          onError: (e) => _active?._onError(e),
          onStatus: (s) => _active?._onStatus(s),
        );
      } catch (_) {
        _ready = false;
      }
    }
    if (!_ready) {
      state = state.copyWith(phase: VoicePhase.unavailable);
      return;
    }
    final locale = await _locale();
    _startedAt = DateTime.now();
    _deadline?.cancel();
    _deadline = Timer(_listenFor + const Duration(seconds: 3), () {
      if (state.phase == VoicePhase.listening) stop();
    });
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: (l) => state = state.copyWith(
        // Android reports about -2…10 dB, iOS 0…1 or so; squash to 0…1.
        level: ((l + 2) / 12).clamp(0.0, 1.0),
      ),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: _listenFor,
        pauseFor: const Duration(seconds: 3),
        localeId: locale,
      ),
    );
    state = state.copyWith(phase: VoicePhase.listening);
  }

  /// Done talking: keep what was heard.
  Future<void> stop() async {
    await _speech.stop();
    _finish();
  }

  /// Indian English when the phone has it, else the phone's language.
  Future<String?> _locale() async {
    try {
      final locales = await _speech.locales();
      for (final id in ['en_IN', 'en-IN']) {
        if (locales.any((l) => l.localeId == id)) return id;
      }
    } catch (_) {}
    return null;
  }

  void _onResult(SpeechRecognitionResult r) {
    state = state.copyWith(transcript: r.recognizedWords);
    if (r.finalResult) _finish();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _finish();
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (e.permanent) _finish();
  }

  void _finish() {
    if (state.phase != VoicePhase.listening) return;
    _deadline?.cancel();
    final quick =
        _startedAt != null &&
        DateTime.now().difference(_startedAt!) < const Duration(seconds: 3);
    if (_retryOnQuickEnd && quick && state.transcript.trim().isEmpty) {
      _retryOnQuickEnd = false;
      start();
      return;
    }
    state = state.copyWith(
      phase: state.transcript.trim().isEmpty
          ? VoicePhase.nothingHeard
          : VoicePhase.done,
      level: 0,
    );
  }
}
