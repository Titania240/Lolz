import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:color_picker/color_picker.dart';
import '../models/meme_editor_models.dart';
import '../services/meme_editor_service.dart';
import '../services/cloud_sync_service.dart';
import 'premium_gallery.dart';
import 'image_editor.dart';

class MemeEditor extends StatefulWidget {
  const MemeEditor({super.key});

  @override
  State<MemeEditor> createState() => _MemeEditorState();
}

class _MemeEditorState extends State<MemeEditor> {
  final MemeEditorService _memeEditorService = MemeEditorService();
  final AutoSaveService _autoSaveService;
  final CloudSyncService _cloudSyncService;
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _textControllers = <TextEditingController>[];
  MemeEditorState _state = MemeEditorState();
  bool _isSyncing = false;
  Map<String, dynamic> _userPreferences = {
    'theme': 'light',
    'fontSize': 16,
    'fontColor': '#000000',
    'autoSave': true,
    'autoSync': true,
    'lastSync': null
  };

  _MemeEditorState() {
    _autoSaveService = AutoSaveService(SharedPreferences.getInstance().sync());
    _cloudSyncService = CloudSyncService(_memeEditorService);
    _autoSaveService.startAutoSave();
    _loadAutoSave();
    _startSyncTimer();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _cloudSyncService.getUserPreferences();
      setState(() {
        _userPreferences = prefs;
      });
    } catch (e) {
      debugPrint('Failed to load preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _cloudSyncService.saveUserPreferences(_userPreferences);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  }

  @override
  void dispose() {
    _autoSaveService.stopAutoSave();
    _autoSaveService.clearAutoSave();
    _stopSyncTimer();
    super.dispose();
  }

  void _startSyncTimer() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _syncWithCloud();
    });
  }

  void _stopSyncTimer() {
    // Nothing to do here as Timer handles its own cleanup
  }

  Future<void> _syncWithCloud() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await _cloudSyncService.syncWithCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Memes synchronized with cloud'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to sync with cloud: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _loadAutoSave() async {
    try {
      // Check for conflicts first
      final conflicts = await _cloudSyncService.getUnresolvedConflicts();
      if (conflicts.isNotEmpty) {
        // Show conflict resolution dialog
        await _showConflictResolutionDialog(conflicts.first);
      }

      // Try to load from cloud first
      final cloudMemes = await _cloudSyncService.getSyncedMemes();
      if (cloudMemes.isNotEmpty) {
        setState(() {
          _state = cloudMemes.first;
          _descriptionController.text = _state.description;
          _textControllers.clear();
          _textControllers.addAll(
            List.generate(_state.texts.length, (_) => TextEditingController()),
          );
        });
        return;
      }

      // Fallback to local storage
      final savedState = await _autoSaveService.loadAutoSave();
      if (savedState != null) {
        setState(() {
          _state = savedState;
          _descriptionController.text = savedState.description;
          _textControllers.clear();
          _textControllers.addAll(
            List.generate(savedState.texts.length, (_) => TextEditingController()),
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to load auto-save: $e');
    }
  }

  Future<void> _showConflictResolutionDialog(Map<String, dynamic> conflict) async {
    final localVersion = MemeEditorState.fromJson(conflict['localVersion']);
    final cloudVersion = MemeEditorState.fromJson(conflict['cloudVersion']);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conflict Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Local version: ${localVersion.createdAt}'),
            const SizedBox(height: 8),
            Text('Cloud version: ${cloudVersion.createdAt}'),
            const SizedBox(height: 16),
            const Text('Choose how to resolve this conflict:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Choose local version
              await _cloudSyncService.resolveConflict(
                conflict['id'],
                ConflictResolution.localWins,
                null,
              );
              Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local version kept'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Keep Local'),
          ),
          TextButton(
            onPressed: () async {
              // Choose cloud version
              await _cloudSyncService.resolveConflict(
                conflict['id'],
                ConflictResolution.cloudWins,
                null,
              );
              Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cloud version kept'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Keep Cloud'),
          ),
          TextButton(
            onPressed: () async {
              // Merge versions
              final mergedMeme = await _cloudSyncService.mergeVersions(
                localVersion,
                cloudVersion,
              );
              await _cloudSyncService.resolveConflict(
                conflict['id'],
                ConflictResolution.merged,
                mergedMeme,
              );
              Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Versions merged successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Merge Versions'),
          ),
        ],
      ),
    );

    if (resolution != null) {
      await _cloudSyncService.resolveConflict(conflict['id'], resolution);
      if (resolution == 'cloud') {
        // Load cloud version
        final cloudVersion = MemeEditorState.fromJson(conflict['cloud_version']);
        setState(() {
          _state = cloudVersion;
          _descriptionController.text = cloudVersion.description;
          _textControllers.clear();
          _textControllers.addAll(
            List.generate(cloudVersion.texts.length, (_) => TextEditingController()),
          );
        });
      } else if (resolution == 'merge') {
        // TODO: Implement merge logic
      }
    }
  }

  @override
  void dispose() {
    _autoSaveService.stopAutoSave();
    _autoSaveService.clearAutoSave();
    super.dispose();
  }

  Future<void> _loadAutoSave() async {
    try {
      final savedState = await _autoSaveService.loadAutoSave();
      if (savedState != null) {
        setState(() {
          _state = savedState;
          _descriptionController.text = savedState.description;
          _textControllers.clear();
          _textControllers.addAll(
            List.generate(savedState.texts.length, (_) => TextEditingController()),
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to load auto-save: $e');
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    
    // Show image source dialog
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Premium Gallery'),
              onTap: () {
                Navigator.pop(context);
                _showPremiumGallery();
              },
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1080,
          maxHeight: 1920,
          imageQuality: 80,
        );

        if (image != null) {
          // Show image editor
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageEditor(
                imageUrl: image.path,
                onImageUpdated: (editedPath) {
                  setState(() {
                    _state = _state.copyWith(
                      imageUrl: editedPath,
                    );
                  });
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to select image: $e')),
          );
        }
      }
    }
  }

  Future<void> _showPremiumGallery() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PremiumGallery(
            onImageSelected: (imageUrl) {
              setState(() {
                _state = _state.copyWith(
                  imageUrl: imageUrl,
                  isPremium: true,
                );
              });
            },
            userLolcoins: 100, // TODO: Get actual user LOLCoins
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open gallery: $e')),
        );
      }
    }
  }

  void _addTextOverlay() {
    setState(() {
      final newText = MemeText(text: '');
      _state = _state.copyWith(
        texts: [..._state.texts, newText],
      );
      _autoSaveService.addHistory(_state);
      _cloudSyncService.syncMemeToCloud(_state);
    });
  }

  void _removeTextOverlay(int index) {
    setState(() {
      _textControllers.removeAt(index);
      _state = _state.copyWith(
        texts: _state.texts.where((text, i) => i != index).toList(),
      );
      _autoSaveService.addHistory(_state);
    });
  }

  Future<void> _createMeme() async {
    if (_formKey.currentState!.validate()) {
      try {
        final texts = List<MemeText>.generate(
          _textControllers.length,
          (i) => MemeText(
            text: _textControllers[i].text,
            position: TextPosition.top,
          ),
        );

        final result = await _memeEditorService.createMeme(
          imageId: _state.imageId!,
          description: _descriptionController.text,
          texts: texts,
          hashtags: _state.hashtags,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Meme created successfully!')),
          );
          // TODO: Navigate to meme details
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create meme: $e')),
          );
        }
      }
    }
  }

  void _showTextOptionsDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Undo'),
              onTap: () {
                _autoSaveService._undo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.redo),
              title: const Text('Redo'),
              onTap: () {
                _autoSaveService._redo();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('Change Font Size'),
              onTap: () {
                _showFontSizeDialog(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill),
              title: const Text('Change Color'),
              onTap: () {
                _showColorPicker(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                color: _state.texts[index].color,
                onColorChanged: (color) {
                  setState(() {
                    _state = _state.copyWith(
                      texts: _state.texts.map((t) {
                        if (t == _state.texts[index]) {
                          return t.copyWith(color: color);
                        }
                        return t;
                      }).toList(),
                    );
                    _autoSaveService.addHistory(_state);
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: Slider(
          value: _state.texts[index].size,
          min: 10,
          max: 50,
          divisions: 8,
          label: '${_state.texts[index].size.round()}',
          onChanged: (value) {
            setState(() {
              _state = _state.copyWith(
                texts: _state.texts.map((t) {
                  if (t == _state.texts[index]) {
                    return t.copyWith(size: value);
                  }
                  return t;
                }).toList(),
              );
              _autoSaveService.addHistory(_state);
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meme Editor'),
        actions: [
          IconButton(
            icon: Icon(
              _isSyncing ? Icons.sync_problem : Icons.sync,
              color: _isSyncing ? Colors.red : Colors.white,
            ),
            onPressed: _isSyncing ? null : _syncWithCloud,
            tooltip: 'Sync with Cloud',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) async {
              switch (value) {
                case 'preferences':
                  await _showPreferencesDialog();
                  break;
                case 'history':
                  await _showHistoryDialog();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'preferences',
                child: Text('Preferences'),
              ),
              const PopupMenuItem<String>(
                value: 'history',
                child: Text('Version History'),
              ),
            ],
          ),
        ],
      ),
      body:
      appBar: AppBar(
        title: const Text('Create Meme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _createMeme,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Image selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Image'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _selectImage,
                            child: const Text('Upload Image'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: Open gallery
                            },
                            child: const Text('Gallery'),
                          ),
                        ],
                      ),
                      if (_state.imageUrl != null)
                        Stack(
                          children: [
                            // Image preview
                            _state.imageUrl!.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: _state.imageUrl!,
                                    height: 300,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_state.imageUrl!),
                                    height: 300,
                                    fit: BoxFit.cover,
                                  ),

                            // Text overlays
                            ..._state.texts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final text = entry.value;
                              return Positioned(
                                left: text.x,
                                top: text.y,
                                child: Draggable<DraggableDetails>(
                                  data: DraggableDetails(
                                    index: index,
                                    text: text,
                                  ),
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      text.text,
                                      style: TextStyle(
                                        color: text.color,
                                        fontSize: text.size,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        _state = _state.copyWith(
                                          texts: _state.texts.map((t) {
                                            if (t == text) {
                                              return t.copyWith(
                                                x: t.x + details.delta.dx,
                                                y: t.y + details.delta.dy,
                                              );
                                            }
                                            return t;
                                          }).toList(),
                                        );
                                      });
                                    },
                                    child: Text(
                                      text.text,
                                      style: TextStyle(
                                        color: text.color,
                                        fontSize: text.size,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // Text overlays
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Text Overlays'),
                      const SizedBox(height: 8),
                      ..._textControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                        return Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: 'Text ${index + 1}',
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _removeTextOverlay(index),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_color_text),
                                    onPressed: () {
                                      _showTextOptionsDialog(index);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      ElevatedButton(
                        onPressed: _addTextOverlay,
                        child: const Text('Add Text Overlay'),
                      ),
                    ],
                  ),
                ),
              ),

              // Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Describe your meme',
                          hintText: 'Enter a description...',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          if (value.length > 500) {
                            return 'Description must be less than 500 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Hashtags
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hashtags'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _state.hashtags.map((hashtag) {
                          return Chip(
                            label: Text(hashtag),
                            onDeleted: () {
                              setState(() {
                                _state = _state.copyWith(
                                  hashtags: _state.hashtags
                                      .where((h) => h != hashtag)
                                      .toList(),
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Add hashtag',
                          hintText: '#funny #memes #lolzone',
                        ),
                        onFieldSubmitted: (value) {
                          if (value.isNotEmpty && !value.startsWith('#')) {
                            value = '#$value';
                          }
                          setState(() {
                            _state = _state.copyWith(
                              hashtags: [..._state.hashtags, value],
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
