
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

const String homeUrl = 'https://wtr-lab.com/en';

// region: Models
class Tab {
  final int id;
  String url;
  String title;
  WebViewController? controller;

  Tab({required this.id, this.url = homeUrl, this.title = 'wtr-lab', this.controller});

  factory Tab.fromMap(Map<String, dynamic> map) {
    return Tab(
      id: map['id'],
      url: map['url'],
      title: map['title'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
    };
  }
}

class HistoryItem {
  final String url;
  final String title;
  final int timestamp;

  HistoryItem({required this.url, required this.title, required this.timestamp});

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      url: map['url'],
      title: map['title'],
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'timestamp': timestamp,
    };
  }
}
// endregion

// region: State Management (AppState)
class AppState with ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final AudioPlayer silentPlayer = AudioPlayer();

  List<Tab> _tabs = [];
  int? _activeTabId;
  List<HistoryItem> _history = [];
  bool _isReady = false;

  List<Tab> get tabs => _tabs;
  int? get activeTabId => _activeTabId;
  Tab? get activeTab =>
      _activeTabId == null ? null : _tabs.firstWhere((t) => t.id == _activeTabId);
  List<HistoryItem> get history => _history;
  bool get isReady => _isReady;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    await _loadState();
    _initTts();
    _initSilentAudio();
    _isReady = true;
    notifyListeners();
  }

  void _initTts() {
    tts.setCompletionHandler(() {
      activeTab?.controller?.runJavaScript('window.__ttsDidEnd();');
    });
    tts.setErrorHandler((msg) {
      activeTab?.controller?.runJavaScript('window.__ttsDidError("$msg");');
    });
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
    if (_tabs.length == 1) {
      addTab(); // Add a new tab before closing the last one
      _tabs.removeAt(0); // Remove the original last tab
    } else {
      final index = _tabs.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tabs.removeAt(index);
        if (_activeTabId == id) {
          _activeTabId = _tabs.isNotEmpty ? _tabs.last.id : null;
        }
      }
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
        _tabs = tabMaps.map((map) => Tab.fromMap(map)).toList();
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
// endregion

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const WtrLabReaderApp(),
    ),
  );
}

class WtrLabReaderApp extends StatelessWidget {
  const WtrLabReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WTR Lab Reader',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF111118),
        scaffoldBackgroundColor: const Color(0xFF111118),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (!appState.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TabBarWidget(),
            Expanded(
              child: WebViewStack(),
            ),
          ],
        ),
      ),
    );
  }
}

// region: UI Widgets
class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Container(
      height: 40,
      color: const Color(0xFF111118),
      child: Row(
        children: [
          // History Button
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => _showHistory(context),
          ),
          // Tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: appState.tabs.length,
              itemBuilder: (context, index) {
                final tab = appState.tabs[index];
                final bool isActive = appState.activeTabId == tab.id;
                return GestureDetector(
                  onTap: () => appState.setActiveTab(tab.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1e1e2e) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? const Color(0xFF3a3a52) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          tab.title,
                          style: TextStyle(
                            color: isActive ? const Color(0xFFd0d0e8) : const Color(0xFF666680),
                            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => appState.closeTab(tab.id),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: isActive ? const Color(0xFF9090b0) : const Color(0xFF444460),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // New Tab Button
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: appState.addTab,
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final appState = context.read<AppState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a24),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('History', style: TextStyle(color: Colors.white)),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: () {
                appState.clearHistory();
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: appState.history.isEmpty
              ? const Text('No history yet.', style: TextStyle(color: Colors.white70))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: appState.history.length,
                  itemBuilder: (context, index) {
                    final item = appState.history[index];
                    return ListTile(
                      title: Text(item.title, style: const TextStyle(color: Color(0xFFd0d0e8))), 
                      subtitle: Text(item.url, style: const TextStyle(color: Color(0xFF666680)), overflow: TextOverflow.ellipsis),
                      onTap: () {
                        appState.addTab();
                        appState.updateTab(appState.activeTabId!, url: item.url);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class WebViewStack extends StatefulWidget {
  const WebViewStack({super.key});

  @override
  State<WebViewStack> createState() => _WebViewStackState();
}

class _WebViewStackState extends State<WebViewStack> {

  String get bridgeJS => """
    (function () {
      if (window.__rnBridge) return;
      window.__rnBridge = true;

      var _uid = 0;
      var _cur = null;
      var VOICES = [ { voiceURI: 'rn.default', name: 'Default', lang: 'en-US', localService: true, default: true }];

      function SpeechSynthesisUtterance(text) {
        this.text = text || '';
        this.lang = 'en-US'; this.rate = 1; this.pitch = 1; this.volume = 1;
        this.voice = null;
        this.onstart = null; this.onend = null; this.onerror = null;
        this.onpause = null; this.onresume = null;
        this._id = ++_uid;
      }
      window.SpeechSynthesisUtterance = SpeechSynthesisUtterance;

      var synth = {
        speaking: false, paused: false, pending: false, onvoiceschanged: null,

        speak: function (utt) {
          _cur = utt;
          synth.speaking = true; synth.paused = false;
          TTSChannel.postMessage(JSON.stringify({
            type: 'TTS_SPEAK', id: utt._id,
            text: utt.text, lang: utt.lang || 'en-US',
            rate: utt.rate || 1, pitch: utt.pitch || 1, volume: utt.volume || 1,
          }));
          if (utt.onstart) {
            try { utt.onstart({ type: 'start', utterance: utt }); } catch (e) {}
          }
        },

        cancel: function () {
          var u = _cur; _cur = null;
          synth.speaking = false; synth.paused = false;
          TTSChannel.postMessage(JSON.stringify({ type: 'TTS_CANCEL' }));
          if (u && u.onend) setTimeout(function () { u.onend({ type: 'end' }); }, 0);
        },

        pause: function () {
          if (!synth.speaking || synth.paused) return;
          synth.paused = true;
          TTSChannel.postMessage(JSON.stringify({ type: 'TTS_PAUSE' }));
          if (_cur && _cur.onpause) _cur.onpause({ type: 'pause' });
        },

        resume: function () {
          if (!synth.paused) return;
          synth.paused = false; synth.speaking = true;
          TTSChannel.postMessage(JSON.stringify({ type: 'TTS_RESUME' }));
          if (_cur && _cur.onresume) _cur.onresume({ type: 'resume' });
        },

        getVoices: function () { return VOICES; },
        addEventListener: function (evt, fn) {
          if (evt === 'voiceschanged') setTimeout(fn, 120);
        },
        removeEventListener: function () {},
      };

      window.speechSynthesis = synth;

      setTimeout(function () {
        if (typeof synth.onvoiceschanged === 'function') synth.onvoiceschanged();
        try { window.dispatchEvent(new Event('voiceschanged')); } catch (e) {}
      }, 100);

      window.__ttsDidEnd = function () {
        synth.speaking = false; synth.paused = false;
        var u = _cur; _cur = null;
        if (u && u.onend) {
          try { u.onend({ type: 'end' }); } catch (e) {}
        }
      };

      window.__ttsDidError = function (msg) {
        synth.speaking = false;
        var u = _cur; _cur = null;
        if (u && u.onerror) u.onerror({ type: 'error', error: msg });
      };

      true;
    })();
  """;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Stack(
      children: appState.tabs.map((tab) {
        return Offstage(
          offstage: appState.activeTabId != tab.id,
          child: WebViewWidget(controller: _getControllerForTab(tab)),
        );
      }).toList(),
    );
  }

  WebViewController _getControllerForTab(Tab tab) {
    if (tab.controller != null) {
      return tab.controller!;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('TTSChannel', onMessageReceived: (message) {
        _handleTTSMessage(message.message);
      });

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          if (!mounted) return;
          context.read<AppState>().updateTab(tab.id, url: url);
          _getTabTitle(tab.id, controller);
          controller.runJavaScript(bridgeJS);
        },
        onNavigationRequest: (NavigationRequest request) {
          return NavigationDecision.navigate;
        },
      ),
    );

    controller.loadRequest(Uri.parse(tab.url));

    // Schedule a microtask to update the tab with the controller after the current build phase.
    Future.microtask(() {
        if (mounted) {
            context.read<AppState>().updateTab(tab.id, controller: controller);
        }
    });
    
    return controller;
  }


  void _getTabTitle(int tabId, WebViewController controller) async {
    final title = await controller.getTitle();
    if (title != null && title.isNotEmpty) {
      if (!mounted) return;
      context.read<AppState>().updateTab(tabId, title: title);
    }
  }

  void _handleTTSMessage(String message) {
    final appState = context.read<AppState>();
    final data = jsonDecode(message);

    switch (data['type']) {
      case 'TTS_SPEAK':
        appState.tts.setLanguage(data['lang'] ?? 'en-US');
        appState.tts.setPitch(data['pitch']?.toDouble() ?? 1.0);
        appState.tts.setSpeechRate(data['rate']?.toDouble() ?? 1.0);
        appState.tts.speak(data['text']);
        break;
      case 'TTS_CANCEL':
        appState.tts.stop();
        break;
      case 'TTS_PAUSE':
        appState.tts.pause();
        break;
      case 'TTS_RESUME':
        // flutter_tts does not have a resume, so we just speak again
        // This is not ideal, but it's the best we can do with the library
        appState.tts.speak(data['text']);
        break;
    }
  }
}

// endregion
