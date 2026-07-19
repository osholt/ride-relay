import 'package:flutter/material.dart';

import '../../controllers/rider_profile_controller.dart';

/// Editor for in-case-of-emergency details. Deliberately device-local only -
/// stored solely in [RiderProfileController]'s SharedPreferences, never
/// threaded into RideSession/RideEvent, so it can never reach the relay, the
/// event journal, or another rider's device.
class EmergencyInfoSheet extends StatefulWidget {
  const EmergencyInfoSheet({super.key, required this.riderProfile});

  final RiderProfileController riderProfile;

  static Future<void> show(
    BuildContext context,
    RiderProfileController riderProfile,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => EmergencyInfoSheet(riderProfile: riderProfile),
  );

  @override
  State<EmergencyInfoSheet> createState() => _EmergencyInfoSheetState();
}

class _EmergencyInfoSheetState extends State<EmergencyInfoSheet> {
  late final _nameController = TextEditingController(
    text: widget.riderProfile.emergencyContactName,
  );
  late final _phoneController = TextEditingController(
    text: widget.riderProfile.emergencyContactPhone,
  );
  late final _notesController = TextEditingController(
    text: widget.riderProfile.medicalNotes,
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      22,
      4,
      22,
      28 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Emergency info',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Kept only on this device - never shared with other riders or sent '
          'over the network. Visible to anyone with this phone unlocked.',
          style: TextStyle(color: Color(0xFF98A3B1)),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('emergency-contact-name'),
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Emergency contact name',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('emergency-contact-phone'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Emergency contact phone',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('emergency-medical-notes'),
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Medical notes (optional)',
            hintText: 'Allergies, conditions, blood type, ...',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('emergency-info-save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.riderProfile.saveEmergencyInfo(
      emergencyContactName: _nameController.text.trim(),
      emergencyContactPhone: _phoneController.text.trim(),
      medicalNotes: _notesController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
