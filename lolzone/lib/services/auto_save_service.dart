import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meme_editor_models.dart';

class AutoSaveService {
  static const String _autoSaveKey = 'meme_editor_auto_save';
  static const Duration _saveInterval = Duration(minutes: 1);
  static const int _maxHistory = 5;

  final SharedPreferences _prefs;
  Timer? _saveTimer;
  List<MemeEditorState> _history = [];
  int _currentHistoryIndex = -1;

  AutoSaveService(this._prefs);

  void startAutoSave() {
    _saveTimer = Timer.periodic(_saveInterval, (_) => _saveCurrentState());
  }

  void stopAutoSave() {
    _saveTimer?.cancel();
  }

  Future<void> _saveCurrentState() async {
    try {
      if (_currentHistoryIndex == -1) return;

      // Remove older saves if we reach max history
      if (_history.length > _maxHistory) {
        _history.removeAt(0);
      }

      // Save current state
      final currentState = _history[_currentHistoryIndex];
      final encodedState = jsonEncode(currentState.toJson());
      
      await _prefs.setString(_autoSaveKey, encodedState);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Auto-saved your meme progress'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                _undo();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to auto-save: $e');
    }
  }

  Future<MemeEditorState?> loadAutoSave() async {
    try {
      final savedState = _prefs.getString(_autoSaveKey);
      if (savedState != null) {
        final decodedState = jsonDecode(savedState);
        return MemeEditorState.fromJson(decodedState);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to load auto-save: $e');
      return null;
    }
  }

  void addHistory(MemeEditorState state) {
    // Clear future history
    if (_currentHistoryIndex < _history.length - 1) {
      _history.removeRange(_currentHistoryIndex + 1, _history.length);
    }

    // Add new state
    _history.add(state);
    _currentHistoryIndex = _history.length - 1;

    // Save immediately
    _saveCurrentState();
  }

  void _undo() {
    if (_currentHistoryIndex > 0) {
      _currentHistoryIndex--;
      final previousState = _history[_currentHistoryIndex];
      // TODO: Notify the editor to update state
    }
  }

  void _redo() {
    if (_currentHistoryIndex < _history.length - 1) {
      _currentHistoryIndex++;
      final nextState = _history[_currentHistoryIndex];
      // TODO: Notify the editor to update state
    }
  }

  void clearAutoSave() {
    _history.clear();
    _currentHistoryIndex = -1;
    _prefs.remove(_autoSaveKey);
  }
}
