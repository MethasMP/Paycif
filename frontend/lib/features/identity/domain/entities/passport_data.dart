import 'package:equatable/equatable.dart';

/// 🌍 Passport Identity Entity
/// 
/// Represents the high-integrity data extracted from a physical passport's 
/// NFC chip and MRZ zone.
class PassportData extends Equatable {
  final String firstName;
  final String lastName;
  final String documentNumber;
  final String dateOfBirth;
  final String dateOfExpiry;
  final String nationality;
  final String gender;
  final String? portraitImageBase64; // High-res image from Chip
  final bool isChipVerified; // True if Passive Authentication (PA) succeeded

  const PassportData({
    required this.firstName,
    required this.lastName,
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.nationality,
    required this.gender,
    this.portraitImageBase64,
    this.isChipVerified = false,
  });

  @override
  List<Object?> get props => [
        documentNumber,
        firstName,
        lastName,
        dateOfBirth,
        dateOfExpiry,
        nationality,
        gender,
        isChipVerified,
      ];
}
