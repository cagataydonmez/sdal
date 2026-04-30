import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

part 'profile_repository.freezed.dart';
part 'profile_repository.g.dart';

@freezed
class ProfileData with _$ProfileData {
  const ProfileData._();

  const factory ProfileData({
    @JsonKey(fromJson: readRequiredInt) required int id,
    @JsonKey(fromJson: readRequiredText) required String username,
    @JsonKey(fromJson: readRequiredText) required String firstName,
    @JsonKey(fromJson: readRequiredText) required String lastName,
    @JsonKey(fromJson: readRequiredText) required String email,
    @JsonKey(fromJson: readRequiredText) required String graduationYear,
    @JsonKey(fromJson: readRequiredText) required String city,
    @JsonKey(fromJson: readRequiredText) required String profession,
    @JsonKey(fromJson: readRequiredText) required String website,
    @JsonKey(fromJson: readRequiredText) required String university,
    @JsonKey(fromJson: readRequiredText) required String signature,
    @JsonKey(fromJson: readRequiredText) required String photo,
    @JsonKey(fromJson: readRequiredText) required String company,
    @JsonKey(fromJson: readRequiredText) required String title,
    @JsonKey(fromJson: readRequiredText) required String expertise,
    @JsonKey(fromJson: readRequiredText) required String linkedinUrl,
    @JsonKey(fromJson: readRequiredText) required String universityDepartment,
    @JsonKey(fromJson: readRequiredBool) required bool mentorOptIn,
    @JsonKey(fromJson: readRequiredText) required String mentorTopics,
    @JsonKey(fromJson: readRequiredBool) required bool kvkkConsent,
    @JsonKey(fromJson: readRequiredBool) required bool directoryConsent,
    @JsonKey(fromJson: readRequiredBool) required bool emailHidden,
  }) = _ProfileData;

  factory ProfileData.fromJson(Map<String, dynamic> json) =>
      _$ProfileDataFromJson(
        normalizeJsonAliases(json, {
          'username': ['kadi'],
          'firstName': ['isim'],
          'lastName': ['soyisim'],
          'graduationYear': ['mezuniyetyili'],
          'city': ['sehir'],
          'profession': ['meslek'],
          'website': ['websitesi'],
          'university': ['universite'],
          'signature': ['imza'],
          'photo': ['resim'],
          'company': ['sirket'],
          'title': ['unvan'],
          'expertise': ['uzmanlik'],
          'linkedinUrl': ['linkedin_url'],
          'universityDepartment': ['universite_bolum'],
          'mentorOptIn': ['mentor_opt_in'],
          'mentorTopics': ['mentor_konulari'],
          'kvkkConsent': ['kvkk_consent'],
          'directoryConsent': ['directory_consent'],
          'emailHidden': ['mailkapali'],
        }),
      );

  factory ProfileData.fromMap(JsonMap map) => ProfileData.fromJson(map);

  Map<String, dynamic> toUpdateBody() {
    return {
      'isim': firstName,
      'soyisim': lastName,
      'sehir': city,
      'meslek': profession,
      'websitesi': website,
      'universite': university,
      'imza': signature,
      'sirket': company,
      'unvan': title,
      'uzmanlik': expertise,
      'linkedin_url': linkedinUrl,
      'universite_bolum': universityDepartment,
      'mentor_opt_in': mentorOptIn,
      'mentor_konulari': mentorTopics,
      'kvkk_consent': kvkkConsent,
      'directory_consent': directoryConsent,
      'mailkapali': emailHidden ? '1' : '0',
    };
  }
}

@freezed
class VerificationUploadResult with _$VerificationUploadResult {
  const factory VerificationUploadResult({
    @JsonKey(fromJson: readRequiredText) required String proofPath,
    @JsonKey(fromJson: readRequiredText) required String proofImageRecordId,
  }) = _VerificationUploadResult;

  factory VerificationUploadResult.fromJson(Map<String, dynamic> json) =>
      _$VerificationUploadResultFromJson(
        normalizeJsonAliases(json, {
          'proofPath': ['proof_path'],
          'proofImageRecordId': ['proof_image_record_id'],
        }),
      );

  factory VerificationUploadResult.fromMap(JsonMap map) =>
      VerificationUploadResult.fromJson(map);
}

class ProfileRepository {
  const ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ProfileData?> fetchProfile() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/profile',
      decoder: asJsonMap,
    );
    final user = asJsonMap(asJsonMap(result.rawData)['user']);
    if (user.isEmpty) return null;
    return ProfileData.fromMap(user);
  }

  Future<ApiResult<dynamic>> updateProfile(ProfileData profile) {
    return _apiClient.put<dynamic>(
      '/api/profile',
      body: profile.toUpdateBody(),
    );
  }

  Future<ApiResult<dynamic>> claimGraduationYear({
    required String graduationYear,
    required String password,
    required String passwordRepeat,
    required bool kvkkConsent,
    required bool directoryConsent,
  }) {
    return _apiClient.post<dynamic>(
      '/api/profile/graduation-year/claim',
      body: {
        'mezuniyetyili': graduationYear,
        'sifre': password,
        'sifre2': passwordRepeat,
        'kvkk_consent': kvkkConsent,
        'directory_consent': directoryConsent,
      },
    );
  }

  Future<ApiResult<dynamic>> requestEmailChange(String email) {
    return _apiClient.post<dynamic>(
      '/api/profile/email-change/request',
      body: {'email': email},
    );
  }

  Future<ApiResult<dynamic>> verifyEmailChange(String token) {
    return _apiClient.get<dynamic>(
      '/api/profile/email-change/verify',
      query: {'token': token},
    );
  }

  Future<ApiResult<dynamic>> changePassword({
    required String currentPassword,
    required String nextPassword,
    required String nextPasswordRepeat,
  }) {
    return _apiClient.post<dynamic>(
      '/api/profile/password',
      body: {
        'eskisifre': currentPassword,
        'yenisifre': nextPassword,
        'yenisifretekrar': nextPasswordRepeat,
      },
    );
  }

  Future<ApiResult<dynamic>> uploadPhoto(File file) {
    return _apiClient.multipart<dynamic>(
      '/api/profile/photo',
      files: {'file': file},
    );
  }

  Future<ApiResult<JsonMap>> uploadVerificationProof(File file) {
    return _apiClient.multipart<JsonMap>(
      '/api/new/verified/proof',
      files: {'proof': file},
      decoder: asJsonMap,
    );
  }

  Future<ApiResult<dynamic>> submitVerificationRequest({
    String proofPath = '',
    String proofImageRecordId = '',
    String requestType = 'member_verification',
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/verified/request',
      body: {
        'request_type': requestType,
        if (proofPath.isNotEmpty) 'proof_path': proofPath,
        if (proofImageRecordId.isNotEmpty)
          'proof_image_record_id': proofImageRecordId,
      },
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final profileProvider = FutureProvider.autoDispose<ProfileData?>(
  (ref) => ref.watch(profileRepositoryProvider).fetchProfile(),
);
