import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';

abstract class SumsubKycState {}

class SumsubInitial extends SumsubKycState {}
class SumsubLoading extends SumsubKycState {}
class SumsubReady extends SumsubKycState {
  final String token;
  SumsubReady(this.token);
}
class SumsubCompleted extends SumsubKycState {}
class SumsubFailed extends SumsubKycState {
  final String reason;
  SumsubFailed(this.reason);
}

class SumsubKycCubit extends Cubit<SumsubKycState> {
  SumsubKycCubit() : super(SumsubInitial());

  Future<void> initKyc() async {
    emit(SumsubLoading());
    try {
      final res = await ApiService.getSumsubToken();
      final token = res['token'];
      if (token != null) {
        emit(SumsubReady(token));
      } else {
        emit(SumsubFailed('Invalid token response'));
      }
    } catch (e) {
      emit(SumsubFailed(e.toString()));
    }
  }

  Future<void> onSumsubCompleted() async {
    emit(SumsubLoading());
    
    // Poll for status update in DB (Backend updates tier via webhook)
    int attempts = 0;
    while (attempts < 30) {
      final tier = await ApiService.getUserTier();
      if (tier == 'tier2') {
        emit(SumsubCompleted());
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
    }
    
    emit(SumsubFailed('Verification processing timed out. Please check again later.'));
  }
}
