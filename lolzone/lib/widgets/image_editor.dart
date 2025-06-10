import 'package:flutter/material.dart';
import 'package:image_filter/image_filter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ImageEditor extends StatefulWidget {
  final String imageUrl;
  final Function(String) onImageUpdated;

  const ImageEditor({
    super.key,
    required this.imageUrl,
    required this.onImageUpdated,
  });

  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  double _rotation = 0;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  bool _isFlipped = false;
  bool _isLoading = true;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      if (widget.imageUrl.startsWith('http')) {
        final response = await http.get(Uri.parse(widget.imageUrl));
        final bytes = response.bodyBytes;
        _image = await decodeImageFromList(bytes);
      } else {
        final file = File(widget.imageUrl);
        final bytes = await file.readAsBytes();
        _image = await decodeImageFromList(bytes);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  Future<void> _applyEffects() async {
    if (_image == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/edited_image.png';

      final filter = ImageFilter(
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        rotation: _rotation,
        flipHorizontal: _isFlipped,
      );

      await filter.apply(
        source: widget.imageUrl,
        destination: tempPath,
      );

      if (mounted) {
        widget.onImageUpdated(tempPath);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply effects: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: _applyEffects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateZ(_rotation)
                            ..scale(_isFlipped ? -1 : 1),
                          child: _image != null
                              ? Image.memory(
                                  _image!.bytes!,
                                  fit: BoxFit.contain,
                                )
                              : const CircularProgressIndicator(),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildEffectSlider(
                        'Brightness',
                        _brightness,
                        (value) => setState(() => _brightness = value),
                        min: -1,
                        max: 1,
                      ),
                      _buildEffectSlider(
                        'Contrast',
                        _contrast,
                        (value) => setState(() => _contrast = value),
                        min: -1,
                        max: 1,
                      ),
                      _buildEffectSlider(
                        'Saturation',
                        _saturation,
                        (value) => setState(() => _saturation = value),
                        min: -1,
                        max: 1,
                      ),
                      IconButton(
                        icon: Icon(
                          _isFlipped ? Icons.flip_back : Icons.flip_front,
                        ),
                        onPressed: () => setState(() => _isFlipped = !_isFlipped),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEffectSlider(
    String label,
    double value,
    Function(double) onChanged, {
    double min = 0,
    double max = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
