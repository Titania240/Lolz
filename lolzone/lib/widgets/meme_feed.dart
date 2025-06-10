import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meme.dart';
import '../services/feed_service.dart';

class MemeFeed extends StatefulWidget {
  final String token;

  const MemeFeed({Key? key, required this.token}) : super(key: key);

  @override
  State<MemeFeed> createState() => _MemeFeedState();
}

class _MemeFeedState extends State<MemeFeed> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;
  final PageController _pageController = PageController();
  final FeedService _feedService = FeedService('');
  List<Meme> _memes = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isProfileVisible = false;
  bool _isLiked = false;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    _feedService = FeedService(widget.token);
    _loadMemes();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 200.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pageController.addListener(() {
      setState(() {
        _currentIndex = _pageController.page?.round() ?? 0;
      });
    });
  }

  Future<void> _loadMemes() async {
    try {
      final memes = await _feedService.getFeed();
      setState(() {
        _memes = memes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load memes: $e')),
      );
    }
  }

  void _showProfile() {
    setState(() {
      _isProfileVisible = true;
    });
    _animationController.forward();
  }

  void _hideProfile() {
    _animationController.reverse().then((_) {
      setState(() {
        _isProfileVisible = false;
      });
    });
  }

  Future<void> _handleDoubleTap() async {
    try {
      setState(() {
        _isLiked = true;
        _likes = _memes[_currentIndex].likes + 1;
      });

      // Show like animation
      final likeAnimation = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

      final scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: likeAnimation, curve: Curves.easeOut),
      );

      final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: likeAnimation, curve: Curves.easeOut),
      );

      final likeWidget = Positioned(
        left: MediaQuery.of(context).size.width / 2 - 20,
        top: MediaQuery.of(context).size.height / 2 - 20,
        child: AnimatedBuilder(
          animation: scale,
          builder: (context, child) {
            return Transform.scale(
              scale: scale.value,
              child: Opacity(
                opacity: opacity.value,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.pink,
                  size: 40,
                ),
              ),
            );
          },
        ),
      );

      Overlay.of(context).insert(OverlayEntry(
        builder: (context) => likeWidget,
      ));

      likeAnimation.forward().then((_) {
        likeAnimation.dispose();
      });

      // Update meme
      await _feedService.likeMeme(_memes[_currentIndex].id);
      setState(() {
        _memes[_currentIndex] = _memes[_currentIndex].copyWith(
          likes: _memes[_currentIndex].likes + 1,
        );
      });
    } catch (e) {
      setState(() {
        _isLiked = false;
        _likes = _memes[_currentIndex].likes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like meme: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main feed
          PageView.builder(
            controller: _pageController,
            itemCount: _memes.length,
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final meme = _memes[index];
              final isCurrent = index == _currentIndex;
              
              return GestureDetector(
                onDoubleTap: _handleDoubleTap,
                onTap: _showProfile,
                child: Stack(
                  children: [
                    // Book page animation
                    AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        final pageOffset = _pageController.page ?? 0;
                        final offset = (pageOffset - index);
                        
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Add perspective
                            ..rotateY(offset * 0.5), // Rotate based on page offset
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Meme image
                                Image.network(
                                  meme.url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                                // Meme details overlay
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.0),
                                          Colors.black.withOpacity(0.7),
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          meme.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundImage: NetworkImage(meme.user.profilePicture ?? ''),
                                              radius: 15,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              meme.user.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          // Profile overlay
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _isProfileVisible ? 0 : -200,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _opacityAnimation.value,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile picture
                    GestureDetector(
                      onTap: () {
                        // Navigate to user's wall
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserWall(userId: _memes[_currentIndex].user.id),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(_memes[_currentIndex].user.profilePicture ?? ''),
                        radius: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // User info
                    Text(
                      _memes[_currentIndex].user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subscribe button
                    ElevatedButton(
                      onPressed: () {
                        // Handle subscription
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Subscribe'),
                    ),
                    const SizedBox(height: 16),
                    // Meme description
                    Text(
                      _memes[_currentIndex].title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Like button
                        GestureDetector(
                          onTap: _handleDoubleTap,
                          child: Column(
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.pink : Colors.white,
                              ),
                              Text(
                                '$_likes',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        // Comment button
                        GestureDetector(
                          onTap: () {
                            // Handle comment
                          },
                          child: Column(
                            children: const [
                              Icon(Icons.chat_bubble_outline, color: Colors.white),
                              Text('Comment', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        // Share button
                        GestureDetector(
                          onTap: () {
                            // Handle share
                          },
                          child: Column(
                            children: const [
                              Icon(Icons.share, color: Colors.white),
                              Text('Share', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class UserWall extends StatelessWidget {
  final String userId;

  const UserWall({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Wall'),
        backgroundColor: Colors.pink,
      ),
      body: const Center(
        child: Text('User wall content will be implemented here'),
      ),
    );
  }
}
