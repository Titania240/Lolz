import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/meme_feed.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      _token = token;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please log in to continue',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement login
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOLZone'),
        backgroundColor: Colors.pink,
        actions: [
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: () async {
              // Récupérer l'ID utilisateur depuis le token
              final userId = await _getUserFromToken();
              
              if (userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaymentScreen(userId: userId)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez vous connecter d\'abord')),
                );
              }
            },
          ),
        ],
      ),
      body: MemeFeed(token: _token!),
    );
  }

  Future<String?> _getUserFromToken() async {
    if (_token == null) return null;
    
    try {
      // Décoder le token JWT
      final parts = _token!.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      
      final Map<String, dynamic> json = jsonDecode(decoded);
      return json['sub']; // ID utilisateur
    } catch (e) {
      print('Erreur lors de la décodage du token: $e');
      return null;
    }
  }
            },
          ),
        ],
      ),
      body: MemeFeed(token: _token!),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.pink,
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
