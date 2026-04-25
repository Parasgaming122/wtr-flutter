import React, { useRef, useEffect, useState, useCallback } from 'react';
import {
  StyleSheet, View, Text, TouchableOpacity,
  ScrollView, Platform, BackHandler,
} from 'react-native';
import { WebView } from 'react-native-webview';
import * as Speech from 'expo-speech';
import { Audio } from 'expo-av';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';

const HOME = 'https://wtr-lab.com/en';

const toNativeRate = (r) => {
  if (Platform.OS === 'ios') {
    return Math.min(Math.max(0.5 + (r - 1) * (0.5 / 3), 0.1), 1.0);
  }
  return Math.min(Math.max(r, 0.1), 4.0);
};

const buildBridgeJS = (voices) => {
  const voiceArr = voices.length > 0
    ? voices.map(v => ({
        voiceURI: v.identifier, name: v.name,
        lang: v.language, localService: true, default: false,
      }))
    : [{ voiceURI: 'rn.default', name: 'Default', lang: 'en-US', localService: true, default: true }];

  const firstEn = voiceArr.findIndex(v => v.lang.startsWith('en'));
  if (firstEn >= 0) voiceArr[firstEn].default = true;
  else if (voiceArr.length > 0) voiceArr[0].default = true;

  return `
(function () {
  if (window.__rnBridge) return;
  window.__rnBridge = true;

  var _uid = 0;
  var _cur = null;
  var VOICES = ${JSON.stringify(voiceArr)};

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
      window.ReactNativeWebView.postMessage(JSON.stringify({
        type: 'TTS_SPEAK', id: utt._id,
        text: utt.text, lang: utt.lang || 'en-US',
        rate: utt.rate || 1, pitch: utt.pitch || 1, volume: utt.volume || 1,
        voiceURI: utt.voice ? utt.voice.voiceURI : null,
      }));
      if (utt.onstart) {
        try { utt.onstart({ type: 'start', utterance: utt }); } catch (e) {}
      }
    },

    cancel: function () {
      var u = _cur; _cur = null;
      synth.speaking = false; synth.paused = false;
      window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'TTS_CANCEL' }));
      // ── Web Speech API spec: cancel() MUST fire onend on the stopped utterance.
      // The site waits for this before auto-starting the next chapter.
      // This is safe because _cur is cleared above, so the new speak()
      // that follows won't interfere with this callback.
      if (u && u.onend) setTimeout(function () { u.onend({ type: 'end' }); }, 0);
    },

    pause: function () {
      if (!synth.speaking || synth.paused) return;
      synth.paused = true;
      window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'TTS_PAUSE' }));
      if (_cur && _cur.onpause) _cur.onpause({ type: 'pause' });
    },

    resume: function () {
      if (!synth.paused) return;
      synth.paused = false; synth.speaking = true;
      window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'TTS_RESUME' }));
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
`;
};

let _tabSeq = Date.now();
const mkTab = (url = HOME, title = 'wtr-lab') => ({ id: ++_tabSeq, url, title });

const STORAGE_KEYS = {
  TABS      : 'wtr_tabs',
  ACTIVE_ID : 'wtr_active_id',
  HISTORY   : 'wtr_history',
};

export default function App() {
  const [bridgeJS, setBridgeJS] = useState(null);
  const [tabs, setTabs]         = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [history, setHistory]   = useState([]);
  const [showHist, setShowHist] = useState(false);
  const [ready, setReady]       = useState(false);

  const wvRefs     = useRef({});
  const speakGen   = useRef(0);
  const pausedText = useRef(null);
  const pausedOpts = useRef(null);
  const speakTabId = useRef(null);
  const voicesRef  = useRef([]);
  const silentLoop = useRef(null);

  // ── Load Saved State ───────────────────────────────────────────────────────
  useEffect(() => {
    (async () => {
      try {
        const [sTabs, sActive, sHist] = await Promise.all([
          AsyncStorage.getItem(STORAGE_KEYS.TABS),
          AsyncStorage.getItem(STORAGE_KEYS.ACTIVE_ID),
          AsyncStorage.getItem(STORAGE_KEYS.HISTORY),
        ]);

        if (sTabs) {
          const parsed = JSON.parse(sTabs);
          if (parsed.length > 0) {
            setTabs(parsed);
            if (sActive) setActiveId(parseInt(sActive, 10));
            else setActiveId(parsed[0].id);
          } else {
            const t = mkTab();
            setTabs([t]);
            setActiveId(t.id);
          }
        } else {
          const t = mkTab();
          setTabs([t]);
          setActiveId(t.id);
        }

        if (sHist) setHistory(JSON.parse(sHist));
      } catch (e) { console.warn('load state:', e); }
      setReady(true);
    })();
  }, []);

  // ── Save State Changes ─────────────────────────────────────────────────────
  useEffect(() => {
    if (!ready) return;
    AsyncStorage.setItem(STORAGE_KEYS.TABS, JSON.stringify(tabs));
  }, [tabs, ready]);

  useEffect(() => {
    if (!ready || activeId === null) return;
    AsyncStorage.setItem(STORAGE_KEYS.ACTIVE_ID, String(activeId));
  }, [activeId, ready]);

  useEffect(() => {
    if (!ready) return;
    AsyncStorage.setItem(STORAGE_KEYS.HISTORY, JSON.stringify(history));
  }, [history, ready]);

  useEffect(() => {
    (async () => {
      try {
        await Audio.setAudioModeAsync({
          allowsRecordingIOS        : false,
          playsInSilentModeIOS      : true,
          staysActiveInBackground   : true,
          interruptionModeIOS       : Audio.INTERRUPTION_MODE_IOS_DO_NOT_MIX,
          shouldDuckAndroid         : true,
          interruptionModeAndroid   : Audio.INTERRUPTION_MODE_ANDROID_DO_NOT_MIX,
          playThroughEarpieceAndroid: false,
        });
      } catch (e) { console.warn('audio mode:', e); }

      let voices = [];
      try {
        voices = await Speech.getAvailableVoicesAsync();
        voicesRef.current = voices;
      } catch {}
      setBridgeJS(buildBridgeJS(voices));

      // ── Silent Loop to keep WebView JS and background process alive ───────
      try {
        console.log('[SilentLoop] Starting...');
        const { sound } = await Audio.Sound.createAsync(
          { uri: 'https://cdn.jsdelivr.net/gh/anars/blank-audio/10-seconds-of-silence.mp3' }, // updated URL
          { shouldPlay: true, isLooping: true, volume: 0.01 } // slightly higher volume for robustness
        );
        silentLoop.current = sound;
        console.log('[SilentLoop] Active.');
      } catch (e) { 
        console.warn('[SilentLoop] Failed to start:', e); 
      }
    })();

    return () => {
      Speech.stop();
      if (silentLoop.current) silentLoop.current.unloadAsync();
    };
  }, []);

  useEffect(() => {
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      wvRefs.current[activeId]?.goBack();
      return true;
    });
    return () => sub.remove();
  }, [activeId]);

  const addTab = () => {
    const t = mkTab();
    setTabs(p => [...p, t]);
    setActiveId(t.id);
  };

  const closeTab = useCallback((id) => {
    if (speakTabId.current === id) {
      speakGen.current++;
      Speech.stop();
      speakTabId.current = null;
    }
    delete wvRefs.current[id];

    setTabs(prev => {
      if (prev.length === 1) {
        const t = mkTab();
        setActiveId(t.id);
        return [t];
      }
      const next = prev.filter(t => t.id !== id);
      setActiveId(cur => cur === id ? next[next.length - 1].id : cur);
      return next;
    });
  }, []);

  const updateTitle = useCallback((id, title) => {
    if (!title) return;
    setTabs(p => p.map(t => t.id === id ? { ...t, title } : t));
  }, []);

  const addToHistory = useCallback((url, title) => {
    if (!url || url === 'about:blank' || url === HOME) return;
    setHistory(prev => {
      const filtered = prev.filter(h => h.url !== url);
      return [{ url, title, ts: Date.now() }, ...filtered].slice(0, 100);
    });
  }, []);

  const updateTabUrl = useCallback((id, url) => {
    setTabs(p => p.map(t => t.id === id ? { ...t, url } : t));
  }, []);

  const makeOnMessage = (tabId) => async ({ nativeEvent }) => {
    let data;
    try { data = JSON.parse(nativeEvent.data); } catch { return; }

    const inject = (js) => wvRefs.current[tabId]?.injectJavaScript(js);

    switch (data.type) {

      case 'TTS_SPEAK': {
        speakTabId.current = tabId;

        // REMOVED Speech.stop() - This reduces the sub-1s lag by letting 
        // the native layer handle the transition immediately without a stop/clear call.
        const gen = ++speakGen.current;

        let voiceId;
        if (data.voiceURI) {
          voiceId = voicesRef.current.find(v => v.identifier === data.voiceURI)?.identifier;
        }

        const opts = {
          language : data.lang  || 'en-US',
          rate     : toNativeRate(data.rate  ?? 1),
          pitch    : Math.min(Math.max(data.pitch  ?? 1, 0.5), 2.0),
          volume   : data.volume ?? 1,
          ...(voiceId ? { voice: voiceId } : {}),
          onDone: () => {
            // Only notify site if this is still the active utterance.
            // Prevents old chapter's onDone firing into the new chapter.
            if (speakGen.current === gen) inject('window.__ttsDidEnd();');
          },
          // ── onStopped stays SILENT ──────────────────────────────────────────
          // expo-speech fires onStopped when Speech.stop() is called (e.g. on
          // skip). If we called __ttsDidEnd here, the site would think TTS ended
          // naturally and re-trigger the next segment → infinite skip loop.
          onStopped: () => {},
          onError: (e) => {
            if (speakGen.current === gen) {
              inject(`window.__ttsDidError(${JSON.stringify(e?.message ?? String(e))}); true;`);
            }
          },
        };

        pausedText.current = data.text;
        pausedOpts.current = opts;
        Speech.speak(data.text, opts);
        break;
      }

      case 'TTS_CANCEL': {
        speakGen.current++;
        Speech.stop(); // no await — see TTS_SPEAK note above
        pausedText.current = null;
        pausedOpts.current = null;
        break;
      }

      case 'TTS_PAUSE': {
        speakGen.current++;
        Speech.stop();
        break;
      }

      case 'TTS_RESUME': {
        if (!pausedText.current) break;
        const gen = ++speakGen.current;
        Speech.speak(pausedText.current, {
          ...pausedOpts.current,
          onDone   : () => { if (speakGen.current === gen) inject('window.__ttsDidEnd(); true;'); },
          onStopped: () => {},
        });
        break;
      }
    }
  };

  // ── Title update only — no bridge re-injection on nav change.
  // wtr-lab is a Next.js SPA: client-side navigation does NOT reset window,
  // so the bridge installed by injectedJavaScriptBeforeContentLoaded persists.
  // Re-injecting would reset _cur and synth state mid-session, breaking auto-start.
  const makeOnNavChange = (tabId) => (state) => {
    updateTitle(tabId, state.title);
    updateTabUrl(tabId, state.url);
    if (!state.loading) addToHistory(state.url, state.title);
  };

  if (!bridgeJS || !ready) return <View style={s.root} />;

  return (
    <SafeAreaProvider>
      <SafeAreaView style={s.root} edges={['top', 'left', 'right', 'bottom']}>
        <StatusBar style="light" backgroundColor="#111118" />

        <View style={s.tabBar}>
          <TouchableOpacity style={s.histBtn} onPress={() => setShowHist(true)}>
            <Text style={s.histBtnIcon}>📜</Text>
          </TouchableOpacity>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={s.tabScroll}
            keyboardShouldPersistTaps="handled"
          >
            {tabs.map(tab => {
              const active = tab.id === activeId;
              return (
                <TouchableOpacity
                  key={tab.id}
                  style={[s.tab, active && s.tabActive]}
                  onPress={() => setActiveId(tab.id)}
                  activeOpacity={0.75}
                >
                  <Text style={[s.tabTitle, active && s.tabTitleActive]} numberOfLines={1}>
                    {tab.title}
                  </Text>
                  <TouchableOpacity
                    style={s.closeWrap}
                    onPress={() => closeTab(tab.id)}
                    hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
                    activeOpacity={0.6}
                  >
                    <Text style={[s.closeIcon, active && s.closeIconActive]}>×</Text>
                  </TouchableOpacity>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
          <TouchableOpacity style={s.newTab} onPress={addTab} activeOpacity={0.7}>
            <Text style={s.newTabIcon}>+</Text>
          </TouchableOpacity>
        </View>

        <View style={s.stack}>
          {tabs.map(tab => (
            <View
              key={tab.id}
              style={[StyleSheet.absoluteFillObject, { opacity: tab.id === activeId ? 1 : 0 }]}
              pointerEvents={tab.id === activeId ? 'auto' : 'none'}
            >
              <WebView
                ref={ref => { wvRefs.current[tab.id] = ref; }}
                source={{ uri: HOME }}
                style={StyleSheet.absoluteFillObject}
                injectedJavaScriptBeforeContentLoaded={bridgeJS}
                onMessage={makeOnMessage(tab.id)}
                onNavigationStateChange={makeOnNavChange(tab.id)}
                javaScriptEnabled
                domStorageEnabled
                sharedCookiesEnabled
                thirdPartyCookiesEnabled
                allowsInlineMediaPlayback
                mediaPlaybackRequiresUserAction={false}
                renderToHardwareTextureAndroid
                androidLayerType="hardware"
                applicationNameForUserAgent="Chrome/124.0.0.0 Mobile"
              />
            </View>
          ))}
        </View>

        {showHist && (
          <View style={s.histOverlay}>
            <View style={s.histContent}>
              <View style={s.histHeader}>
                <Text style={s.histTitleText}>History</Text>
                <TouchableOpacity onPress={() => setShowHist(false)}>
                  <Text style={s.histClose}>✕</Text>
                </TouchableOpacity>
              </View>
              <ScrollView style={s.histList}>
                {history.length === 0 ? (
                  <Text style={s.histEmpty}>No history yet.</Text>
                ) : (
                  history.map((h, i) => (
                    <TouchableOpacity
                      key={i}
                      style={s.histItem}
                      onPress={() => {
                        const t = mkTab(h.url, h.title);
                        setTabs(p => [...p, t]);
                        setActiveId(t.id);
                        setShowHist(false);
                      }}
                    >
                      <Text style={s.histItemTitle} numberOfLines={1}>{h.title || h.url}</Text>
                      <Text style={s.histItemUrl} numberOfLines={1}>{h.url}</Text>
                    </TouchableOpacity>
                  ))
                )}
              </ScrollView>
              {history.length > 0 && (
                <TouchableOpacity
                  style={s.clearHist}
                  onPress={() => setHistory([])}
                >
                  <Text style={s.clearHistText}>Clear History</Text>
                </TouchableOpacity>
              )}
            </View>
          </View>
        )}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const TAB_H = 40;
const s = StyleSheet.create({
  root    : { flex: 1, backgroundColor: '#111118' },
  tabBar  : {
    height: TAB_H, flexDirection: 'row', backgroundColor: '#111118',
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#2a2a38',
    alignItems: 'center',
  },
  tabScroll     : { alignItems: 'center', paddingHorizontal: 4, gap: 4 },
  tab           : {
    flexDirection: 'row', alignItems: 'center', paddingHorizontal: 10,
    paddingVertical: 5, borderRadius: 8, maxWidth: 160, minWidth: 80,
    backgroundColor: 'transparent', gap: 6,
  },
  tabActive     : {
    backgroundColor: '#1e1e2e',
    borderWidth: StyleSheet.hairlineWidth, borderColor: '#3a3a52',
  },
  tabTitle      : { flex: 1, fontSize: 12, color: '#666680', fontWeight: '400' },
  tabTitleActive: { color: '#d0d0e8', fontWeight: '500' },
  closeWrap     : { width: 16, height: 16, alignItems: 'center', justifyContent: 'center' },
  closeIcon     : { fontSize: 15, lineHeight: 16, color: '#444460', fontWeight: '400' },
  closeIconActive: { color: '#9090b0' },
  newTab        : {
    width: 36, height: TAB_H, alignItems: 'center', justifyContent: 'center',
    borderLeftWidth: StyleSheet.hairlineWidth, borderLeftColor: '#2a2a38',
  },
  newTabIcon    : { fontSize: 18, color: '#8080a0', lineHeight: 22, fontWeight: '400' },
  stack         : { flex: 1, position: 'relative' },
  histBtn       : { width: 40, height: TAB_H, alignItems: 'center', justifyContent: 'center' },
  histBtnIcon   : { fontSize: 18 },
  histOverlay   : {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.85)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  histContent   : {
    width: '90%',
    height: '80%',
    backgroundColor: '#1a1a24',
    borderRadius: 16,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#333345',
  },
  histHeader    : {
    height: 50,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#333345',
  },
  histTitleText : { color: '#fff', fontSize: 18, fontWeight: '600' },
  histClose     : { color: '#888', fontSize: 20 },
  histList      : { flex: 1, padding: 8 },
  histItem      : {
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#252533',
  },
  histItemTitle : { color: '#d0d0e8', fontSize: 14, fontWeight: '500', marginBottom: 2 },
  histItemUrl   : { color: '#666680', fontSize: 11 },
  histEmpty     : { color: '#666', textAlign: 'center', marginTop: 40 },
  clearHist     : {
    height: 50,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#252533',
  },
  clearHistText : { color: '#ff6b6b', fontWeight: '500' },
});