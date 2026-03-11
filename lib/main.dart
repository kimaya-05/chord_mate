import 'package:flutter/material.dart';
import 'dsp_test_page.dart';
import 'ui/practice_session_page.dart';
import 'ui/note_detection_screen.dart';
import 'models/octave_exercise.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const MyHomePage(title: 'ChordMate Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.mic),
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const DspTestPage())
                ),
                label: const Text('DSP Engine Test'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.music_note),
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const PracticeSessionPage(mode: ExerciseMode.fullRange))
                ),
                label: const Text('Start Octave Practice'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.hearing),
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const NoteDetectionScreen())
                ),
                label: const Text('Note Detection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
