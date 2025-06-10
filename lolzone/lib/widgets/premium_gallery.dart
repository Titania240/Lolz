import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meme_editor_models.dart';
import '../services/meme_editor_service.dart';

class PremiumGallery extends StatefulWidget {
  final Function(String) onImageSelected;
  final int userLolcoins;

  const PremiumGallery({
    super.key,
    required this.onImageSelected,
    required this.userLolcoins,
  });

  @override
  State<PremiumGallery> createState() => _PremiumGalleryState();
}

class _PremiumGalleryState extends State<PremiumGallery> {
  final MemeEditorService _memeEditorService = MemeEditorService();
  List<ImageModel> _images = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    try {
      final images = await _memeEditorService.getGalleryImages(
        category: _selectedCategory != 'all' 
          ? ImageCategory.values.firstWhere(
              (e) => e.toString() == 'ImageCategory.$_selectedCategory')
          : null,
        type: ImageType.premium,
      );
      setState(() {
        _images = images;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load images: $e')),
        );
      }
    }
  }

  void _selectImage(String imageId) async {
    try {
      final image = _images.firstWhere((img) => img.id == imageId);
      if (image.priceLolcoins > widget.userLolcoins) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Not enough LOLCoins! Need ${image.priceLolcoins - widget.userLolcoins} more.',
              ),
            ),
          );
        }
        return;
      }

      final purchasedImage = await _memeEditorService.purchasePremiumImage(imageId);
      if (mounted) {
        widget.onImageSelected(purchasedImage.url);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to purchase image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Gallery'),
        actions: [
          DropdownButton<String>(
            value: _selectedCategory,
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All Categories'),
              ),
              ...ImageCategory.values.map((category) => DropdownMenuItem(
                value: category.toString().split('.').last,
                child: Text(category.toString().split('.').last),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
                _isLoading = true;
              });
              _fetchImages();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final image = _images[index];
                return GestureDetector(
                  onTap: () => _selectImage(image.id),
                  child: Card(
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: image.url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.error),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                image.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/lolcoin.svg',
                                    width: 16,
                                    height: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${image.priceLolcoins} LOLCoins',
                                    style: TextStyle(
                                      color: image.priceLolcoins > widget.userLolcoins
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
