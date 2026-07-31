import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arteria/features/user%20data/user_bloc.dart';
import 'package:arteria/features/user%20data/user_state.dart';

extension BPThemeContext on BuildContext {
  Color get bpStatusColor {
    final state = watch<UserBloc>().state;
    if (state is! UserLoaded) return Colors.green;
    
    final sys = state.latestReading?['systolic'] as int? ?? 0;
    final dia = state.latestReading?['diastolic'] as int? ?? 0;
    final age = state.latestReading?['age'] as int?;
    final isElderly = age != null && age >= 65;

    if (sys == 0) return Colors.green;

    if (sys >= 180 || dia >= 120) return const Color(0xFF9B2226); // Critical
    if (sys >= 140 || dia >= 90) return const Color(0xFFAE2012); // Stage 2
    
    if (sys == 120 && dia == 80) {
      return isElderly ? const Color(0xFFCA6702) : Colors.green; // Elevated for elderly, Normal for young
    }

    if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) return const Color(0xFFE85D04); // Stage 1
    
    if (sys >= 121 && sys <= 129 && dia < 80) return const Color(0xFFCA6702); // Elevated (sys 121-129; 120 is Normal)

    return Colors.green; // Normal
  }
}
