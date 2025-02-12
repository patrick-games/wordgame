import 'package:flutter/material.dart';
import 'package:my_app/models/game_state.dart';
import 'package:my_app/widgets/tappable_word_input.dart';
import 'package:my_app/widgets/app_drawer.dart';

class GameDisplay extends StatefulWidget {
  final Stream<GameState> gameState;
  final Function(String) onSubmitWord;
  final VoidCallback onResetGame;

  const GameDisplay({
    Key? key,
    required this.gameState,
    required this.onSubmitWord,
    required this.onResetGame,
  }) : super(key: key);

  @override
  _GameDisplayState createState() => _GameDisplayState();
}

class _GameDisplayState extends State<GameDisplay> {
  final TextEditingController _wordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<TappableWordInputState> _tappableInputKey =
      GlobalKey<TappableWordInputState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleWordSubmit(String word) {
    widget.onSubmitWord(word).then((_) {
      _wordController.clear();
      _focusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word found: $word'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      String message;
      if (error.toString().contains('already found this round')) {
        message = 'This word has already been found this round';
      } else if (error.toString().contains('found in a previous round')) {
        message = 'This word was found in a previous round';
      } else if (error.toString().contains('cannot be made')) {
        message = 'Word cannot be made with current letters';
      } else {
        message = 'Invalid word';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );

      _wordController.clear();
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameState>(
      stream: widget.gameState,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Big Dict Energy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final state = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Big Dict Energy',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          drawer: const AppDrawer(),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Global progress at top
                Text(
                    '${state.totalWordsFound} / ${state.dictionarySize} words (${state.completionPercentage.toStringAsFixed(4)}%)'),
                const SizedBox(height: 20),

                // Timer
                Text(
                  'Time: ${state.timeRemaining}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: state.timeRemaining <= 5 ? Colors.red : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),

                // Letters display with hexagonal shape
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: state.currentLetters.map((letter) {
                        bool isVowel = 'AEIOU'.contains(letter);
                        return GestureDetector(
                          onTap: () {
                            if (constraints.maxWidth < 600) {
                              _tappableInputKey.currentState?.addLetter(letter);
                            }
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isVowel ? Colors.amber : Colors.lightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Word input
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Use tappable input for screens narrower than 600px
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          const SizedBox(height: 20),
                          TappableWordInput(
                            letters: state.currentLetters,
                            onSubmitWord: _handleWordSubmit,
                            key: _tappableInputKey,
                          ),
                        ],
                      );
                    } else {
                      // Original text field for wider screens
                      return Column(
                        children: [
                          const SizedBox(height: 20),
                          TextField(
                            controller: _wordController,
                            focusNode: _focusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Enter word',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: _handleWordSubmit,
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Words found counters
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Use smaller font for mobile
                    double fontSize = constraints.maxWidth < 600 ? 18 : 24;

                    return Column(
                      children: [
                        Text(
                          'Found this round: ${state.wordsFoundThisMinute}',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Total words found: ${state.sessionWordsFound}',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // List of found words (only from current round)
                Expanded(
                  child: ListView(
                    children: state.completedWords
                        .map((wordEntry) => ListTile(
                              title: Text(wordEntry.word),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _wordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
