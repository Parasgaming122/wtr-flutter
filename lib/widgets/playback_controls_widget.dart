
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/state/app_state.dart';

class PlaybackControlsWidget extends StatelessWidget {
  const PlaybackControlsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tts = appState.tts;

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              final text = await appState.activeTab?.controller
                  ?.runJavaScriptReturningResult('document.body.innerText');
              if (text != null) {
                tts.speak(text.toString());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () => tts.pause(),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () => tts.stop(),
          ),
        ],
      ),
    );
  }
}
