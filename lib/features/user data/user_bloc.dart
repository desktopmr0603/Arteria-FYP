import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserLoading()) {
    on<LoadUserData>(_onLoadUserData);
    on<SaveBPReading>(_onSaveBPReading);
  }

  Future<void> _onLoadUserData(
    LoadUserData event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(UserError('No user logged in'));
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final firstName = userDoc.data()?['firstName'] ?? 'User';

      // ✅ Fetch latest BP from sub-collection
      final readingsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic>? latestReading;

      if (readingsQuery.docs.isNotEmpty) {
        final r = readingsQuery.docs.first.data();
        final date = r['date'];

        latestReading = {
          'systolic': r['systolic'],
          'diastolic': r['diastolic'],
          'date': date is Timestamp ? date.toDate() : date,
        };
      }

      final bool isFirstTime = latestReading == null;

      emit(
        UserLoaded(
          firstName: firstName,
          latestReading: latestReading,
          isFirstTimeUser: isFirstTime,
        ),
      );
    } catch (e) {
      emit(UserError('Failed to load user data.'));
    }
  }

  Future<void> _onSaveBPReading(
    SaveBPReading event,
    Emitter<UserState> emit,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(UserError('No user logged in'));
        return;
      }

      // store inside the user's bp readings database
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .add({
            'systolic': event.systolic,
            'diastolic': event.diastolic,
            'date': FieldValue.serverTimestamp(),
          });

      // Reload data after saving
      add(LoadUserData());
    } catch (e) {
      emit(UserError('Failed to save reading: $e'));
    }
  }
}
