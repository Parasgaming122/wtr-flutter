
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/state/app_state.dart';
import 'package:myapp/state/theme_provider.dart';

class TabBarWidget extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const TabBarWidget({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final themeProvider = context.watch<ThemeProvider>();
    final tabs = appState.tabs;
    final activeTabId = appState.activeTabId;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          if (onMenuPressed != null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: onMenuPressed,
              tooltip: 'History',
            ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = tab.id == activeTabId;
                return GestureDetector(
                  onTap: () => appState.setActiveTab(tab.id),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                      border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tab.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                            ),
                          ),
                        ),
                        if (tabs.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => appState.closeTab(tab.id),
                            splashRadius: 16,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => appState.addTab(),
            tooltip: 'New Tab',
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
    );
  }
}
