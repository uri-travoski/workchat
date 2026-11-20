import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiddenChatManager extends ChangeNotifier {
  static const String _prefPinHash = 'hidden_chat_pin_hash';
  static const String _prefHiddenIds = 'hidden_chat_ids';

  bool _isUnlocked = false;
  String? _pinHash;
  final Set<String> _hiddenConvIds = {};

  bool get isUnlocked => _isUnlocked;
  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;
  Set<String> get hiddenConvIds => _hiddenConvIds;

  HiddenChatManager() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _pinHash = prefs.getString(_prefPinHash);
    final ids = prefs.getStringList(_prefHiddenIds) ?? [];
    _hiddenConvIds.addAll(ids);
    notifyListeners();
  }

  bool isHidden(String convId) {
    return _hiddenConvIds.contains(convId);
  }

  Future<bool> setPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    _pinHash = hash;
    _isUnlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPinHash, hash);
    notifyListeners();
    return true;
  }

  bool verifyPin(String pin) {
    if (_pinHash == null) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    if (hash == _pinHash) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lock() {
    _isUnlocked = false;
    notifyListeners();
  }

  Future<void> toggleHidden(String convId) async {
    if (_hiddenConvIds.contains(convId)) {
      _hiddenConvIds.remove(convId);
    } else {
      _hiddenConvIds.add(convId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefHiddenIds, _hiddenConvIds.toList());
    notifyListeners();
  }
}
