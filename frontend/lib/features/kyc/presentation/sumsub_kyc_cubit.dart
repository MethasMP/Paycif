import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_service.dart';

sealed class SumsubKycState {}

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
      if (isClosed) return;
      final token = res['token'];
      if (token != null) {
        emit(SumsubReady(token));
      } else {
        emit(SumsubFailed('Invalid token response'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(SumsubFailed(e.toString()));
    }
  }

  Future<void> onSumsubCompleted() async {
    emit(SumsubLoading());
    
    // Poll for status update in DB (Backend updates tier via webhook)
    int attempts = 0;
    while (attempts < 30) {
      if (isClosed) return;
      final tier = await ApiService.getUserTier();
      if (isClosed) return;
      if (tier == 'tier2') {
        emit(SumsubCompleted());
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
    }
    
    if (isClosed) return;
    emit(SumsubFailed('Verification processing timed out. Please check again later.'));
  }
}
