import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import '../models/meme_editor_models.dart';
import '../services/meme_editor_service.dart';

class CloudSyncService {
  final String _baseUrl = 'https://api.lolzone.com';
  final String _deviceId;
  final MemeEditorService _memeEditorService;
  final SharedPreferences _prefs;
  final List<String> _pendingSyncs = [];
  bool _isHandlingConflict = false;

  CloudSyncService(this._memeEditorService) async {
    _prefs = await SharedPreferences.getInstance();
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.androidId;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor;
    } else {
      _deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Load pending syncs
    final pendingSyncs = _prefs.getStringList('pending_syncs') ?? [];
    _pendingSyncs.addAll(pendingSyncs);
  }

  Future<void> syncMemeToCloud(MemeEditorState meme) async {
    try {
      // Check for conflicts
      final response = await http.get(
        Uri.parse('$_baseUrl/api/memes/$deviceId/conflicts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
      );

      if (response.statusCode == 200) {
        final conflicts = jsonDecode(response.body);
        if (conflicts.isNotEmpty) {
          final conflict = Conflict.fromJson(conflicts.first);
          _pendingSyncs.add(meme.id);
          await _prefs.setStringList('pending_syncs', _pendingSyncs);
          throw Exception('Conflict detected');
        }
      }

      // Proceed with sync
      final syncResponse = await http.post(
        Uri.parse('$_baseUrl/api/memes/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
        body: jsonEncode({
          'deviceId': _deviceId,
          'meme': meme.toJson(),
        }),
      );

      if (syncResponse.statusCode != 200) {
        throw Exception('Failed to sync meme: ${syncResponse.body}');
      }

      // Remove from pending syncs
      _pendingSyncs.remove(meme.id);
      await _prefs.setStringList('pending_syncs', _pendingSyncs);
    } catch (e) {
      debugPrint('Failed to sync meme to cloud: $e');
      if (e.toString().contains('Conflict detected')) {
        // Add to pending syncs if conflict
        _pendingSyncs.add(meme.id);
        await _prefs.setStringList('pendingSyncs', _pendingSyncs);
      }
      throw e;
    }
  }

  Future<MemeEditorState> mergeVersions(
    MemeEditorState localVersion,
    MemeEditorState cloudVersion,
  ) async {
    // Merge image if both have one
    final image = localVersion.image ?? cloudVersion.image;

    // Merge text overlays - keep both but avoid duplicates
    final textOverlays = {
      ...localVersion.textOverlays.asMap().entries.map((e) => e.value),
      ...cloudVersion.textOverlays.asMap().entries.map((e) => e.value),
    }.toList();

    // Remove duplicates based on text content
    final uniqueTextOverlays = textOverlays.toSet().toList();

    // Merge effects - prefer local version if both have effects
    final effects = localVersion.effects ?? cloudVersion.effects;

    return MemeEditorState(
      id: localVersion.id,
      image: image,
      textOverlays: uniqueTextOverlays,
      effects: effects,
      createdAt: localVersion.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> resolveConflict(
    String conflictId,
    ConflictResolution resolution,
    MemeEditorState? mergedMeme,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/memes/conflicts/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
        body: jsonEncode({
          'conflictId': conflictId,
          'resolution': resolution.toString(),
          'mergedMeme': mergedMeme?.toJson(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to resolve conflict: ${response.body}');
      }

      // Remove from pending syncs
      _pendingSyncs.remove(conflictId);
      await _prefs.setStringList('pendingSyncs', _pendingSyncs);
    } catch (e) {
      debugPrint('Failed to resolve conflict: $e');
      throw e;
    }
  }

  Future<List<MemeEditorState>> getSyncedMemes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/memes/sync?deviceId=$_deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch synced memes: ${response.body}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => MemeEditorState.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Failed to fetch synced memes: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/preferences?deviceId=$_deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch preferences: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Failed to fetch preferences: $e');
      throw e;
    }
  }

  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/preferences'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
        body: jsonEncode({
          'deviceId': _deviceId,
          'preferences': preferences,
        }),
      );
    } catch (e) {
      debugPrint('Failed to save preferences: $e');
      throw e;
    }
  }

  Future<void> deleteSyncedMeme(String memeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/memes/sync/$memeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete synced meme: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to delete synced meme: $e');
      throw e;
    }
  }

  Future<void> syncWithCloud() async {
    try {
      // Get pending syncs first
      final pendingSyncs = _pendingSyncs;
      if (pendingSyncs.isNotEmpty) {
        // Handle conflicts
        final conflictsResponse = await http.get(
          Uri.parse('$_baseUrl/api/memes/conflicts'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
          },
        );

        if (conflictsResponse.statusCode == 200) {
          final conflicts = jsonDecode(conflictsResponse.body);
          for (final conflict in conflicts) {
            await _handleConflict(conflict);
          }
        }
      }

      // Get memes from cloud
      final cloudMemes = await getSyncedMemes();
      
      // Get local memes
      final localMemes = _prefs.getStringList('local_memes') ?? [];
      
      // Compare and sync
      for (final cloudMeme in cloudMemes) {
        if (!localMemes.contains(cloudMeme.id)) {
          // Save new meme locally
          await _prefs.setStringList(
            'local_memes',
            [...localMemes, cloudMeme.id]
          );
          
          // Save meme state
          await _prefs.setString(
            'meme_${cloudMeme.id}',
            jsonEncode(cloudMeme.toJson())
          );
        }
      }
      
      // Clean up deleted memes
      for (final localMemeId in localMemes) {
        if (!cloudMemes.any((m) => m.id == localMemeId)) {
          await _prefs.remove('meme_$localMemeId');
          localMemes.remove(localMemeId);
        }
      }
      
      await _prefs.setStringList('local_memes', localMemes);
    } catch (e) {
      debugPrint('Failed to sync with cloud: $e');
      throw e;
    }
  }

  Future<void> _handleConflict(Map<String, dynamic> conflict) async {
    if (_isHandlingConflict) return;

    _isHandlingConflict = true;
    try {
      final localMeme = await _prefs.getString('meme_${conflict['meme_id']}');
      final cloudMeme = await http.get(
        Uri.parse('$_baseUrl/api/memes/${conflict['meme_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
        },
      );

      if (cloudMeme.statusCode == 200) {
        final resolution = await _showConflictResolutionDialog(
          localMeme: MemeEditorState.fromJson(jsonDecode(localMeme!)),
          cloudMeme: MemeEditorState.fromJson(jsonDecode(cloudMeme.body)),
        );

        // Resolve conflict based on user choice
        await http.post(
          Uri.parse('$_baseUrl/api/memes/conflicts/${conflict['id']}/resolve'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _memeEditorService.getToken()}',
          },
          body: jsonEncode({
            'resolution_type': resolution,
          }),
        );
      }
    } catch (e) {
      debugPrint('Failed to handle conflict: $e');
    } finally {
      _isHandlingConflict = false;
    }
  }

  Future<String> _showConflictResolutionDialog({
    required MemeEditorState localMeme,
    required MemeEditorState cloudMeme,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A conflict was detected for this meme. Please choose which version to keep:',
            ),
            const SizedBox(height: 16),
            Text(
              'Local Version (Last Modified: ${localMeme.updatedAt})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Cloud Version (Last Modified: ${cloudMeme.updatedAt})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'local'),
            child: const Text('Keep Local Version'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cloud'),
            child: const Text('Keep Cloud Version'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'merge'),
            child: const Text('Merge Versions'),
          ),
        ],
      ),
    ) ?? 'local';
  }
}
