import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/hidden_chat_manager.dart';

class HiddenLockDialog extends StatefulWidget {
  const HiddenLockDialog({super.key});

  @override
  State<HiddenLockDialog> createState() => _HiddenLockDialogState();
}

class _HiddenLockDialogState extends State<HiddenLockDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMsg;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<HiddenChatManager>();
    final isSettingPin = !mgr.hasPin;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          Text(isSettingPin ? 'Set Hidden Chat PIN' : 'Unlock Hidden Chats'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSettingPin
                ? 'Create a PIN or password to protect your hidden chats.'
                : 'Enter your PIN to reveal protected conversations.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'PIN / Password',
              errorText: _errorMsg,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (_) => _handleSubmit(mgr, isSettingPin),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _handleSubmit(mgr, isSettingPin),
          child: Text(isSettingPin ? 'Set PIN' : 'Unlock'),
        ),
      ],
    );
  }

  void _handleSubmit(HiddenChatManager mgr, bool isSettingPin) {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMsg = 'PIN cannot be empty');
      return;
    }

    if (isSettingPin) {
      mgr.setPin(pin);
      Navigator.pop(context, true);
    } else {
      if (mgr.verifyPin(pin)) {
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMsg = 'Incorrect PIN');
      }
    }
  }
}
