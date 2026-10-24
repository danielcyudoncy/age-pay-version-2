import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';

class InfractionPreset {
  final PenaltyInfractionType type;
  final String title;
  final String description;
  final double defaultAmount;
  final IconData icon;
  final Color color;

  const InfractionPreset({
    required this.type,
    required this.title,
    required this.description,
    required this.defaultAmount,
    required this.icon,
    required this.color,
  });

  static const List<InfractionPreset> presets = [
    InfractionPreset(
      type: PenaltyInfractionType.lateComing,
      title: 'Late Coming',
      description: 'Arriving past the scheduled meeting commencement time.',
      defaultAmount: 1000.0,
      icon: Icons.timer_outlined,
      color: Colors.amber,
    ),
    InfractionPreset(
      type: PenaltyInfractionType.unexcusedAbsence,
      title: 'Unexcused Absence',
      description: 'Failing to attend an official meeting without prior written excuse.',
      defaultAmount: 2000.0,
      icon: Icons.person_off_outlined,
      color: Colors.red,
    ),
    InfractionPreset(
      type: PenaltyInfractionType.noiseOrDisturbance,
      title: 'Phone / Disturbance',
      description: 'Phone ringing or side-talking during official meeting proceedings.',
      defaultAmount: 500.0,
      icon: Icons.notifications_active_outlined,
      color: Colors.orange,
    ),
    InfractionPreset(
      type: PenaltyInfractionType.improperAttire,
      title: 'Improper Attire',
      description: 'Failing to wear the mandatory uniform or prescribed dress code.',
      defaultAmount: 1000.0,
      icon: Icons.checkroom_outlined,
      color: Colors.purple,
    ),
    InfractionPreset(
      type: PenaltyInfractionType.custom,
      title: 'Custom Sanction',
      description: 'Other disciplinary infraction defined in organizational bylaws.',
      defaultAmount: 1000.0,
      icon: Icons.gavel_outlined,
      color: Colors.blueGrey,
    ),
  ];

  static InfractionPreset forType(PenaltyInfractionType type) {
    return presets.firstWhere(
      (p) => p.type == type,
      orElse: () => presets.last,
    );
  }
}
