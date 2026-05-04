
import 'dart:convert';
import 'package:flutter/material.dart' hide Tab;
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:myapp/models/tab_model.dart';
import 'package:myapp/state/app_state.dart';

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
  """ ;

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
        onPageFinished: (String url) async {
          if (!mounted) return;
          final title = await controller.getTitle();
          if (!mounted) return;
          context.read<AppState>().updateTab(tab.id, url: url, title: title ?? '');
          context.read<AppState>().addToHistory(url, title ?? '');
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

  void _handleTTSMessage(String message) {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final data = jsonDecode(message);

    switch (data['type']) {
      case 'TTS_SPEAK':
        appState.speak(
          data['text'],
          lang: data['lang'],
          pitch: data['pitch']?.toDouble(),
          rate: (data['rate']?.toDouble() ?? 1.0) * 0.5, // The * 5.0 was making it too fast
        );
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
        appState.speak(data['text']);
        break;
    }
  }
}
