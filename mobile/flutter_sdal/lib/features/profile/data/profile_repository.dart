import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class ProfileData {
  const ProfileData({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.graduationYear,
    required this.city,
    required this.profession,
    required this.website,
    required this.university,
    required this.signature,
    required this.photo,
    required this.company,
    required this.title,
    required this.expertise,
    required this.linkedinUrl,
    required this.universityDepartment,
    required this.mentorOptIn,
    required this.mentorTopics,
    required this.kvkkConsent,
    required this.directoryConsent,
    required this.emailHidden,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String graduationYear;
  final String city;
  final String profession;
  final String website;
  final String university;
  final String signature;
  final String photo;
  final String company;
  final String title;
  final String expertise;
  final String linkedinUrl;
  final String universityDepartment;
  final bool mentorOptIn;
  final String mentorTopics;
  final bool kvkkConsent;
  final bool directoryConsent;
  final bool emailHidden;

  factory ProfileData.fromMap(JsonMap map) {
    return ProfileData(
      id: asInt(map['id']) ?? 0,
      username: coalesceText([map['kadi']], fallback: ''),
      firstName: coalesceText([map['isim']], fallback: ''),
      lastName: coalesceText([map['soyisim']], fallback: ''),
      email: coalesceText([map['email']], fallback: ''),
      graduationYear: coalesceText([map['mezuniyetyili']], fallback: ''),
      city: coalesceText([map['sehir']], fallback: ''),
      profession: coalesceText([map['meslek']], fallback: ''),
      website: coalesceText([map['websitesi']], fallback: ''),
      university: coalesceText([map['universite']], fallback: ''),
      signature: coalesceText([map['imza']], fallback: ''),
      photo: coalesceText([map['resim']], fallback: ''),
      company: coalesceText([map['sirket']], fallback: ''),
      title: coalesceText([map['unvan']], fallback: ''),
      expertise: coalesceText([map['uzmanlik']], fallback: ''),
      linkedinUrl: coalesceText([map['linkedin_url']], fallback: ''),
      universityDepartment: coalesceText([
        map['universite_bolum'],
      ], fallback: ''),
      mentorOptIn: asBool(map['mentor_opt_in']) ?? false,
      mentorTopics: coalesceText([map['mentor_konulari']], fallback: ''),
      kvkkConsent: asBool(map['kvkk_consent']) ?? false,
      directoryConsent: asBool(map['directory_consent']) ?? false,
      emailHidden: asBool(map['mailkapali']) ?? false,
    );
  }

  Map<String, dynamic> toUpdateBody() {
    return {
      'isim': firstName,
      'soyisim': lastName,
      'mezuniyetyili': graduationYear,
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

  ProfileData copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? graduationYear,
    String? city,
    String? profession,
    String? website,
    String? university,
    String? signature,
    String? photo,
    String? company,
    String? title,
    String? expertise,
    String? linkedinUrl,
    String? universityDepartment,
    bool? mentorOptIn,
    String? mentorTopics,
    bool? kvkkConsent,
    bool? directoryConsent,
    bool? emailHidden,
  }) {
    return ProfileData(
      id: id,
      username: username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      graduationYear: graduationYear ?? this.graduationYear,
      city: city ?? this.city,
      profession: profession ?? this.profession,
      website: website ?? this.website,
      university: university ?? this.university,
      signature: signature ?? this.signature,
      photo: photo ?? this.photo,
      company: company ?? this.company,
      title: title ?? this.title,
      expertise: expertise ?? this.expertise,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      universityDepartment: universityDepartment ?? this.universityDepartment,
      mentorOptIn: mentorOptIn ?? this.mentorOptIn,
      mentorTopics: mentorTopics ?? this.mentorTopics,
      kvkkConsent: kvkkConsent ?? this.kvkkConsent,
      directoryConsent: directoryConsent ?? this.directoryConsent,
      emailHidden: emailHidden ?? this.emailHidden,
    );
  }
}

class VerificationUploadResult {
  const VerificationUploadResult({
    required this.proofPath,
    required this.proofImageRecordId,
  });

  final String proofPath;
  final String proofImageRecordId;

  factory VerificationUploadResult.fromMap(JsonMap map) {
    return VerificationUploadResult(
      proofPath: coalesceText([map['proof_path']], fallback: ''),
      proofImageRecordId: coalesceText([
        map['proof_image_record_id'],
      ], fallback: ''),
    );
  }
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

  Future<ApiResult<dynamic>> requestEmailChange(String email) {
    return _apiClient.post<dynamic>(
      '/api/profile/email-change/request',
      body: {'email': email},
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
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/verified/request',
      body: {
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
