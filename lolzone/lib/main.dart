import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOLZone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
        fontFamily: 'ComicSans',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'ComicSans'),
          displayMedium: TextStyle(fontFamily: 'ComicSans'),
          displaySmall: TextStyle(fontFamily: 'ComicSans'),
          headlineLarge: TextStyle(fontFamily: 'ComicSans'),
          headlineMedium: TextStyle(fontFamily: 'ComicSans'),
          headlineSmall: TextStyle(fontFamily: 'ComicSans'),
          titleLarge: TextStyle(fontFamily: 'ComicSans'),
          titleMedium: TextStyle(fontFamily: 'ComicSans'),
          titleSmall: TextStyle(fontFamily: 'ComicSans'),
          bodyLarge: TextStyle(fontFamily: 'ComicSans'),
          bodyMedium: TextStyle(fontFamily: 'ComicSans'),
          bodySmall: TextStyle(fontFamily: 'ComicSans'),
          labelLarge: TextStyle(fontFamily: 'ComicSans'),
          labelMedium: TextStyle(fontFamily: 'ComicSans'),
          labelSmall: TextStyle(fontFamily: 'ComicSans'),
        ),
      ),
      home: const HomeScreen(),
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
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // TODO: Implement Google Sign In
                // This is just a placeholder
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
