
# Blueprint: WTR Lab Reader (Flutter Port)

## 1. Overview

This document outlines the architecture and implementation of the "WTR Lab Reader" application, which was ported from React Native to Flutter. The app functions as a specialized web browser for `wtr-lab.com`, enhanced with background-capable text-to-speech (TTS) functionality, persistent tabs, and browsing history.

## 2. Core Features

- **Tabbed Browsing:** A dynamic UI that allows users to create, switch between, and close multiple web tabs.
- **WebView with JS Bridge:** Each tab contains a `WebView` that loads web content. A JavaScript bridge (`TTSChannel`) facilitates two-way communication between the Flutter host and the web page's JavaScript environment.
- **Native Text-to-Speech (TTS):** The app intercepts speech synthesis commands from the web page and handles them using the native `flutter_tts` engine, allowing for a seamless audio experience.
- **State Persistence:** The application state, including all open tabs, the currently active tab, and the user's browsing history, is automatically saved to local storage (`SharedPreferences`) and restored when the app restarts.
- **Background Audio:** The app can continue playing TTS audio even when minimized or when the screen is off. This is achieved by playing a silent audio track in a loop using `just_audio`, which keeps the app's service alive.
- **History View:** A modal dialog provides a view of the user's browsing history. Users can revisit pages from their history, which open in a new tab.

## 3. Architecture & Implementation

### State Management (Provider)

The application's state is centrally managed by the `AppState` class, which uses the `ChangeNotifier` pattern. This class is provided to the entire widget tree via `ChangeNotifierProvider`.

- **`AppState` Responsibilities:**
  - Managing the list of `Tab` objects (`_tabs`).
  - Tracking the active tab ID (`_activeTabId`).
  - Maintaining the browsing history list (`_history`).
  - Handling all business logic for adding, closing, and updating tabs.
  - Interacting with `SharedPreferences` to save and load the application state.
  - Initializing and managing the `FlutterTts` and `AudioPlayer` instances.

### UI Structure

The UI is built with a clean separation of components:

- **`MainScreen`:** The primary view, which uses a `Column` to house the `TabBarWidget` and the `WebViewStack`.
- **`TabBarWidget`:** A `Row` containing a history button, a horizontally scrolling `ListView` of tabs, and a new-tab button. It reads data directly from `AppState` to render the tabs and their active states.
- **`WebViewStack`:** A `Stack` that contains a `WebViewWidget` for each tab. The `Offstage` widget is used to efficiently show only the active tab's WebView, while keeping the others in the widget tree but not rendering them.

### WebView & JavaScript Bridge

- **`WebViewController`:** Each `Tab` object holds an instance of a `WebViewController`. This controller is configured with `JavaScriptMode.unrestricted`.
- **`TTSChannel`:** A `JavaScriptChannel` named `TTSChannel` is added to each WebView. This channel's `onMessageReceived` callback is the entry point for all messages sent from the web page to the Flutter app.
- **Bridge JavaScript (`bridgeJS`):** A multi-line string containing JavaScript code is injected into the WebView on every `onPageFinished` event. This script:
  - Polyfills `window.speechSynthesis` and `window.SpeechSynthesisUtterance` to mimic the standard Web Speech API.
  - Intercepts calls to `speechSynthesis.speak()`, `pause()`, `resume()`, and `cancel()`.
  - Bundles the TTS command and its parameters into a JSON string and sends it to the Flutter host via `TTSChannel.postMessage()`.
  - Defines global callback functions (`window.__ttsDidEnd`, `window.__ttsDidError`) that the Flutter app can invoke to notify the web page of TTS completion or errors.

### Platform-Specific Configuration

- **Android (`AndroidManifest.xml` & `build.gradle.kts`):
  - Permissions: `INTERNET`, `WAKE_LOCK`, and `FOREGROUND_SERVICE` are declared to allow network access and ensure the app can run in the background.
  - `minSdk` is set to 21 to support a wide range of devices.

- **iOS (`Info.plist`):
  - `UIBackgroundModes`: The `audio` key is added to this array, declaring that the app provides background audio services. This is essential for the silent audio track to keep the app alive.

## 4. Final Application Code (`lib/main.dart`)

The complete, final source code for the application is contained within `lib/main.dart`.
