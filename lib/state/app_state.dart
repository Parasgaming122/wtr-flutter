
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/history_model.dart';
import 'package:myapp/models/tab_model.dart';
import 'package:myapp/core/utils/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AppState with ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final AudioPlayer silentPlayer = AudioPlayer();

  List<Tab> _tabs = [];
  int? _activeTabId;
  List<HistoryItem> _history = [];
  bool _isReady = false;
  final bool silentAudioEnabled;

  // TTS Configuration State
  String? _currentTtsLang;
  double _currentTtsPitch = 1.0;
  double _currentTtsRate = 0.5;

  List<Tab> get tabs => _tabs;
  int? get activeTabId => _activeTabId;
  Tab? get activeTab {
    if (_activeTabId == null) return null;
    try {
      return _tabs.firstWhere((t) => t.id == _activeTabId);
    } catch (e) {
      return null;
    }
  }
  List<HistoryItem> get history => _history;
  bool get isReady => _isReady;

  AppState({this.silentAudioEnabled = false}) {
    _init();
  }

  Future<void> _init() async {
    await _loadState();
    _initTts();
    if (silentAudioEnabled) {
      _initSilentAudio();
    }
    _isReady = true;
    notifyListeners();
  }

  void _initTts() {
    tts.setCompletionHandler(() {
      if (silentAudioEnabled) silentPlayer.play();
      activeTab?.controller?.runJavaScript('window.__ttsDidEnd();');
    });
    tts.setErrorHandler((msg) {
      if (silentAudioEnabled) silentPlayer.play();
      activeTab?.controller?.runJavaScript('window.__ttsDidError("$msg");');
    });
  }

  Future<void> speak(String text, {String? lang, double? pitch, double? rate}) async {
    lang ??= 'en-US';
    pitch ??= 1.0;
    rate ??= 0.5;

    if (silentAudioEnabled) await silentPlayer.pause();

    try {
      if (_currentTtsLang != lang) {
        await tts.setLanguage(lang);
        _currentTtsLang = lang;
      }
      if (_currentTtsPitch != pitch) {
        await tts.setPitch(pitch);
        _currentTtsPitch = pitch;
      }
      if (_currentTtsRate != rate) {
        await tts.setSpeechRate(rate);
        _currentTtsRate = rate;
      }
      await tts.speak(text);
    } catch (e, s) {
      developer.log("TTS Error", name: 'wtr_lab_reader.tts', error: e, stackTrace: s);
      if (silentAudioEnabled) await silentPlayer.play();
      rethrow;
    }
  }

  Future<void> _initSilentAudio() async {
    try {
      // Short, silent MP3 from https://github.com/anars/blank-audio
      await silentPlayer.setUrl('https://cdn.jsdelivr.net/gh/anars/blank-audio/10-seconds-of-silence.mp3');
      await silentPlayer.setLoopMode(LoopMode.one);
      await silentPlayer.setVolume(0.01);
      await silentPlayer.play();
      developer.log('[SilentAudio] Playback initiated.', name: 'wtr_lab_reader.audio');
    } catch (e, s) {
      developer.log('[SilentAudio] Failed to start silent audio loop', name: 'wtr_lab_reader.audio', error: e, stackTrace: s);
    }
  }

  // region: Tab Management
  void addTab() {
    final newTab = Tab(id: DateTime.now().millisecondsSinceEpoch);
    _tabs.add(newTab);
    _activeTabId = newTab.id;
    _saveState();
    notifyListeners();
  }

  void closeTab(int id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tabs.removeAt(index);
      if (_activeTabId == id) {
        if (_tabs.isNotEmpty) {
          _activeTabId = _tabs.length > index ? _tabs[index].id : _tabs.last.id;
        } else {
          addTab(); // Ensure there is always at least one tab
        }
      }
    }
    if (_tabs.isEmpty) {
      addTab();
    }
    _saveState();
    notifyListeners();
  }

  void setActiveTab(int id) {
    if (_activeTabId != id) {
      _activeTabId = id;
      notifyListeners();
    }
  }

  void updateTab(int id, {String? url, String? title, WebViewController? controller}) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (url != null) _tabs[index].url = url;
      if (title != null) _tabs[index].title = title;
      if (controller != null) _tabs[index].controller = controller;
      _saveState();
      notifyListeners();
    }
  }
  // endregion

  // region: History Management
  void addToHistory(String url, String title) {
    if (url.isEmpty || url == homeUrl || url == 'about:blank') return;
    _history.removeWhere((h) => h.url == url);
    _history.insert(0, HistoryItem(url: url, title: title, timestamp: DateTime.now().millisecondsSinceEpoch));
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    _saveState();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _saveState();
    notifyListeners();
  }
  // endregion

  // region: Persistence
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('tabs', jsonEncode(_tabs.map((t) => t.toMap()).toList()));
    prefs.setInt('active_tab_id', _activeTabId ?? 0);
    prefs.setString('history', jsonEncode(_history.map((h) => h.toMap()).toList()));
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (prefs.containsKey('tabs')) {
        final List<dynamic> tabMaps = jsonDecode(prefs.getString('tabs')!);
        _tabs = tabMaps.map((map) {
          final tab = Tab.fromMap(map);
          if (tab.url == 'about:blank') {
            tab.url = homeUrl;
          }
          return tab;
        }).toList();
      }
      if (prefs.containsKey('active_tab_id')) {
        _activeTabId = prefs.getInt('active_tab_id');
      }
      if (prefs.containsKey('history')) {
        final List<dynamic> historyMaps = jsonDecode(prefs.getString('history')!);
        _history = historyMaps.map((map) => HistoryItem.fromMap(map)).toList();
      }
    } catch (e, s) {
      developer.log("Error loading state", name: 'wtr_lab_reader.persistence', error: e, stackTrace: s);
    }

    if (_tabs.isEmpty) {
      addTab();
    } else if (_activeTabId == null || !_tabs.any((t) => t.id == _activeTabId)) {
      _activeTabId = _tabs.first.id;
    }
    notifyListeners();
  }
  // endregion
}
