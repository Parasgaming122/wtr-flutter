
# WTR Lab Reader Blueprint

## Overview

A web-based text-to-speech (TTS) reader with a rich feature set designed for an optimal reading experience. The application allows users to listen to web content, manage multiple tabs, and access a history of visited pages.

## Style, Design, and Features

### Initial Version

*   **Core Functionality:** Web page rendering and text-to-speech conversion.
*   **User Interface:** A simple, intuitive interface with a tab bar for managing multiple web pages and playback controls for the TTS functionality.
*   **State Management:** The `provider` package is used for state management, ensuring a clear separation of concerns and a scalable architecture.
*   **Asynchronous Operations:** The application handles asynchronous operations, such as loading web pages and interacting with the TTS engine, in a robust and efficient manner.

### Current Version

*   **Playback Controls:** The application now features a dedicated widget for controlling TTS playback, including play, pause, and stop functionality.
*   **History Panel:** A side panel has been added to display a history of visited pages. Users can easily access this panel to revisit previous content.
*   **History Search:** The history panel now includes a search bar, allowing users to filter their browsing history.
*   **UI Enhancements:** The tab bar has been updated to include a button for accessing the history panel, and the overall layout has been refined for a more polished user experience.
*   **Theming:** The application now supports both light and dark themes, with a toggle switch in the tab bar to switch between them. The theme is based on Material Design 3 and uses the `google_fonts` package for custom fonts.
*   **Testability:** The application has been refactored to improve testability, including the ability to disable silent audio during tests and mock the `WebViewStack` widget.
*   **Performance:** The text-to-speech functionality has been optimized to prevent unnecessary reconfiguration of the TTS engine, resulting in a smoother and more responsive user experience.

## Plan

1.  **Implement Playback Controls:** Create a new widget for controlling TTS playback, including play, pause, and stop functionality.
2.  **Add History Panel:** Implement a side panel to display a history of visited pages.
3.  **Update UI:** Integrate the new widgets into the main screen and refine the overall layout.
4.  **Improve Testability:** Refactor the application to improve testability, including the ability to disable silent audio during tests and mock the `WebViewStack` widget.
5.  **Add Theming:** Implement light and dark themes with a user-facing toggle.
6.  **Add History Search:** Add a search bar to the history panel to allow users to search their browsing history.
7.  **Bug Fixes:** Fixed errors related to theme, history search, unused imports, and broken tests.
8.  **Performance Optimization:** Optimized the text-to-speech functionality to prevent unnecessary reconfiguration of the TTS engine.
