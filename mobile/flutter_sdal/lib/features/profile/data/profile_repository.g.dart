// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileDataImpl _$$ProfileDataImplFromJson(Map<String, dynamic> json) =>
    _$ProfileDataImpl(
      id: readRequiredInt(json['id']),
      username: readRequiredText(json['username']),
      firstName: readRequiredText(json['firstName']),
      lastName: readRequiredText(json['lastName']),
      email: readRequiredText(json['email']),
      graduationYear: readRequiredText(json['graduationYear']),
      city: readRequiredText(json['city']),
      profession: readRequiredText(json['profession']),
      website: readRequiredText(json['website']),
      university: readRequiredText(json['university']),
      signature: readRequiredText(json['signature']),
      photo: readRequiredText(json['photo']),
      company: readRequiredText(json['company']),
      title: readRequiredText(json['title']),
      expertise: readRequiredText(json['expertise']),
      linkedinUrl: readRequiredText(json['linkedinUrl']),
      universityDepartment: readRequiredText(json['universityDepartment']),
      mentorOptIn: readRequiredBool(json['mentorOptIn']),
      mentorTopics: readRequiredText(json['mentorTopics']),
      kvkkConsent: readRequiredBool(json['kvkkConsent']),
      directoryConsent: readRequiredBool(json['directoryConsent']),
      emailHidden: readRequiredBool(json['emailHidden']),
    );

Map<String, dynamic> _$$ProfileDataImplToJson(_$ProfileDataImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'graduationYear': instance.graduationYear,
      'city': instance.city,
      'profession': instance.profession,
      'website': instance.website,
      'university': instance.university,
      'signature': instance.signature,
      'photo': instance.photo,
      'company': instance.company,
      'title': instance.title,
      'expertise': instance.expertise,
      'linkedinUrl': instance.linkedinUrl,
      'universityDepartment': instance.universityDepartment,
      'mentorOptIn': instance.mentorOptIn,
      'mentorTopics': instance.mentorTopics,
      'kvkkConsent': instance.kvkkConsent,
      'directoryConsent': instance.directoryConsent,
      'emailHidden': instance.emailHidden,
    };

_$VerificationUploadResultImpl _$$VerificationUploadResultImplFromJson(
  Map<String, dynamic> json,
) => _$VerificationUploadResultImpl(
  proofPath: readRequiredText(json['proofPath']),
  proofImageRecordId: readRequiredText(json['proofImageRecordId']),
);

Map<String, dynamic> _$$VerificationUploadResultImplToJson(
  _$VerificationUploadResultImpl instance,
) => <String, dynamic>{
  'proofPath': instance.proofPath,
  'proofImageRecordId': instance.proofImageRecordId,
};
