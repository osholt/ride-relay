import 'package:flutter/material.dart';

import '../../controllers/rider_profile_controller.dart';

/// Editor for in-case-of-emergency details. Stored in
/// [RiderProfileController]'s SharedPreferences and kept off ordinary ride
/// events by default. It only leaves the device via an explicit share action
/// or the opt-in "share with the leader by default" setting below, both
/// driven from RideController - never as a side effect of anything else.
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
  late bool _shareWithLeaderByDefault =
      widget.riderProfile.shareIceWithLeaderByDefault;
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
          'Kept on this device by default - not sent over the network unless '
          'you explicitly share it or trigger an emergency alert with '
          'sharing switched on below. Visible to anyone with this phone '
          'unlocked.',
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
        const SizedBox(height: 4),
        CheckboxListTile(
          key: const Key('emergency-info-share-with-leader-default'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _shareWithLeaderByDefault,
          onChanged: (value) =>
              setState(() => _shareWithLeaderByDefault = value ?? false),
          title: const Text('Share automatically with the ride leader'),
          subtitle: const Text(
            'If you send an emergency-stop alert, this info goes straight '
            'to whoever is currently the leader - useful if you can\'t take '
            'a further step yourself. You can also share it with the whole '
            'group at any time from the ride menu.',
          ),
        ),
        const SizedBox(height: 16),
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
      shareWithLeaderByDefault: _shareWithLeaderByDefault,
    );
    if (mounted) Navigator.of(context).pop();
  }
}
