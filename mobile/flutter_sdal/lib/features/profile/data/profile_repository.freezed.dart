// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProfileData _$ProfileDataFromJson(Map<String, dynamic> json) {
  return _ProfileData.fromJson(json);
}

/// @nodoc
mixin _$ProfileData {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get username => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get lastName => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get email => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get graduationYear => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get city => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get profession => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get website => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get university => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get signature => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get photo => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get company => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get title => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get expertise => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get linkedinUrl => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get universityDepartment => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get mentorOptIn => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get mentorTopics => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get kvkkConsent => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get directoryConsent => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get emailHidden => throw _privateConstructorUsedError;

  /// Serializes this ProfileData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProfileData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileDataCopyWith<ProfileData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileDataCopyWith<$Res> {
  factory $ProfileDataCopyWith(
    ProfileData value,
    $Res Function(ProfileData) then,
  ) = _$ProfileDataCopyWithImpl<$Res, ProfileData>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String username,
    @JsonKey(fromJson: readRequiredText) String firstName,
    @JsonKey(fromJson: readRequiredText) String lastName,
    @JsonKey(fromJson: readRequiredText) String email,
    @JsonKey(fromJson: readRequiredText) String graduationYear,
    @JsonKey(fromJson: readRequiredText) String city,
    @JsonKey(fromJson: readRequiredText) String profession,
    @JsonKey(fromJson: readRequiredText) String website,
    @JsonKey(fromJson: readRequiredText) String university,
    @JsonKey(fromJson: readRequiredText) String signature,
    @JsonKey(fromJson: readRequiredText) String photo,
    @JsonKey(fromJson: readRequiredText) String company,
    @JsonKey(fromJson: readRequiredText) String title,
    @JsonKey(fromJson: readRequiredText) String expertise,
    @JsonKey(fromJson: readRequiredText) String linkedinUrl,
    @JsonKey(fromJson: readRequiredText) String universityDepartment,
    @JsonKey(fromJson: readRequiredBool) bool mentorOptIn,
    @JsonKey(fromJson: readRequiredText) String mentorTopics,
    @JsonKey(fromJson: readRequiredBool) bool kvkkConsent,
    @JsonKey(fromJson: readRequiredBool) bool directoryConsent,
    @JsonKey(fromJson: readRequiredBool) bool emailHidden,
  });
}

/// @nodoc
class _$ProfileDataCopyWithImpl<$Res, $Val extends ProfileData>
    implements $ProfileDataCopyWith<$Res> {
  _$ProfileDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfileData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? email = null,
    Object? graduationYear = null,
    Object? city = null,
    Object? profession = null,
    Object? website = null,
    Object? university = null,
    Object? signature = null,
    Object? photo = null,
    Object? company = null,
    Object? title = null,
    Object? expertise = null,
    Object? linkedinUrl = null,
    Object? universityDepartment = null,
    Object? mentorOptIn = null,
    Object? mentorTopics = null,
    Object? kvkkConsent = null,
    Object? directoryConsent = null,
    Object? emailHidden = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            firstName: null == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                      as String,
            lastName: null == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            graduationYear: null == graduationYear
                ? _value.graduationYear
                : graduationYear // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            profession: null == profession
                ? _value.profession
                : profession // ignore: cast_nullable_to_non_nullable
                      as String,
            website: null == website
                ? _value.website
                : website // ignore: cast_nullable_to_non_nullable
                      as String,
            university: null == university
                ? _value.university
                : university // ignore: cast_nullable_to_non_nullable
                      as String,
            signature: null == signature
                ? _value.signature
                : signature // ignore: cast_nullable_to_non_nullable
                      as String,
            photo: null == photo
                ? _value.photo
                : photo // ignore: cast_nullable_to_non_nullable
                      as String,
            company: null == company
                ? _value.company
                : company // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            expertise: null == expertise
                ? _value.expertise
                : expertise // ignore: cast_nullable_to_non_nullable
                      as String,
            linkedinUrl: null == linkedinUrl
                ? _value.linkedinUrl
                : linkedinUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            universityDepartment: null == universityDepartment
                ? _value.universityDepartment
                : universityDepartment // ignore: cast_nullable_to_non_nullable
                      as String,
            mentorOptIn: null == mentorOptIn
                ? _value.mentorOptIn
                : mentorOptIn // ignore: cast_nullable_to_non_nullable
                      as bool,
            mentorTopics: null == mentorTopics
                ? _value.mentorTopics
                : mentorTopics // ignore: cast_nullable_to_non_nullable
                      as String,
            kvkkConsent: null == kvkkConsent
                ? _value.kvkkConsent
                : kvkkConsent // ignore: cast_nullable_to_non_nullable
                      as bool,
            directoryConsent: null == directoryConsent
                ? _value.directoryConsent
                : directoryConsent // ignore: cast_nullable_to_non_nullable
                      as bool,
            emailHidden: null == emailHidden
                ? _value.emailHidden
                : emailHidden // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileDataImplCopyWith<$Res>
    implements $ProfileDataCopyWith<$Res> {
  factory _$$ProfileDataImplCopyWith(
    _$ProfileDataImpl value,
    $Res Function(_$ProfileDataImpl) then,
  ) = __$$ProfileDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String username,
    @JsonKey(fromJson: readRequiredText) String firstName,
    @JsonKey(fromJson: readRequiredText) String lastName,
    @JsonKey(fromJson: readRequiredText) String email,
    @JsonKey(fromJson: readRequiredText) String graduationYear,
    @JsonKey(fromJson: readRequiredText) String city,
    @JsonKey(fromJson: readRequiredText) String profession,
    @JsonKey(fromJson: readRequiredText) String website,
    @JsonKey(fromJson: readRequiredText) String university,
    @JsonKey(fromJson: readRequiredText) String signature,
    @JsonKey(fromJson: readRequiredText) String photo,
    @JsonKey(fromJson: readRequiredText) String company,
    @JsonKey(fromJson: readRequiredText) String title,
    @JsonKey(fromJson: readRequiredText) String expertise,
    @JsonKey(fromJson: readRequiredText) String linkedinUrl,
    @JsonKey(fromJson: readRequiredText) String universityDepartment,
    @JsonKey(fromJson: readRequiredBool) bool mentorOptIn,
    @JsonKey(fromJson: readRequiredText) String mentorTopics,
    @JsonKey(fromJson: readRequiredBool) bool kvkkConsent,
    @JsonKey(fromJson: readRequiredBool) bool directoryConsent,
    @JsonKey(fromJson: readRequiredBool) bool emailHidden,
  });
}

/// @nodoc
class __$$ProfileDataImplCopyWithImpl<$Res>
    extends _$ProfileDataCopyWithImpl<$Res, _$ProfileDataImpl>
    implements _$$ProfileDataImplCopyWith<$Res> {
  __$$ProfileDataImplCopyWithImpl(
    _$ProfileDataImpl _value,
    $Res Function(_$ProfileDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfileData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? email = null,
    Object? graduationYear = null,
    Object? city = null,
    Object? profession = null,
    Object? website = null,
    Object? university = null,
    Object? signature = null,
    Object? photo = null,
    Object? company = null,
    Object? title = null,
    Object? expertise = null,
    Object? linkedinUrl = null,
    Object? universityDepartment = null,
    Object? mentorOptIn = null,
    Object? mentorTopics = null,
    Object? kvkkConsent = null,
    Object? directoryConsent = null,
    Object? emailHidden = null,
  }) {
    return _then(
      _$ProfileDataImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        firstName: null == firstName
            ? _value.firstName
            : firstName // ignore: cast_nullable_to_non_nullable
                  as String,
        lastName: null == lastName
            ? _value.lastName
            : lastName // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        graduationYear: null == graduationYear
            ? _value.graduationYear
            : graduationYear // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        profession: null == profession
            ? _value.profession
            : profession // ignore: cast_nullable_to_non_nullable
                  as String,
        website: null == website
            ? _value.website
            : website // ignore: cast_nullable_to_non_nullable
                  as String,
        university: null == university
            ? _value.university
            : university // ignore: cast_nullable_to_non_nullable
                  as String,
        signature: null == signature
            ? _value.signature
            : signature // ignore: cast_nullable_to_non_nullable
                  as String,
        photo: null == photo
            ? _value.photo
            : photo // ignore: cast_nullable_to_non_nullable
                  as String,
        company: null == company
            ? _value.company
            : company // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        expertise: null == expertise
            ? _value.expertise
            : expertise // ignore: cast_nullable_to_non_nullable
                  as String,
        linkedinUrl: null == linkedinUrl
            ? _value.linkedinUrl
            : linkedinUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        universityDepartment: null == universityDepartment
            ? _value.universityDepartment
            : universityDepartment // ignore: cast_nullable_to_non_nullable
                  as String,
        mentorOptIn: null == mentorOptIn
            ? _value.mentorOptIn
            : mentorOptIn // ignore: cast_nullable_to_non_nullable
                  as bool,
        mentorTopics: null == mentorTopics
            ? _value.mentorTopics
            : mentorTopics // ignore: cast_nullable_to_non_nullable
                  as String,
        kvkkConsent: null == kvkkConsent
            ? _value.kvkkConsent
            : kvkkConsent // ignore: cast_nullable_to_non_nullable
                  as bool,
        directoryConsent: null == directoryConsent
            ? _value.directoryConsent
            : directoryConsent // ignore: cast_nullable_to_non_nullable
                  as bool,
        emailHidden: null == emailHidden
            ? _value.emailHidden
            : emailHidden // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProfileDataImpl extends _ProfileData {
  const _$ProfileDataImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredText) required this.username,
    @JsonKey(fromJson: readRequiredText) required this.firstName,
    @JsonKey(fromJson: readRequiredText) required this.lastName,
    @JsonKey(fromJson: readRequiredText) required this.email,
    @JsonKey(fromJson: readRequiredText) required this.graduationYear,
    @JsonKey(fromJson: readRequiredText) required this.city,
    @JsonKey(fromJson: readRequiredText) required this.profession,
    @JsonKey(fromJson: readRequiredText) required this.website,
    @JsonKey(fromJson: readRequiredText) required this.university,
    @JsonKey(fromJson: readRequiredText) required this.signature,
    @JsonKey(fromJson: readRequiredText) required this.photo,
    @JsonKey(fromJson: readRequiredText) required this.company,
    @JsonKey(fromJson: readRequiredText) required this.title,
    @JsonKey(fromJson: readRequiredText) required this.expertise,
    @JsonKey(fromJson: readRequiredText) required this.linkedinUrl,
    @JsonKey(fromJson: readRequiredText) required this.universityDepartment,
    @JsonKey(fromJson: readRequiredBool) required this.mentorOptIn,
    @JsonKey(fromJson: readRequiredText) required this.mentorTopics,
    @JsonKey(fromJson: readRequiredBool) required this.kvkkConsent,
    @JsonKey(fromJson: readRequiredBool) required this.directoryConsent,
    @JsonKey(fromJson: readRequiredBool) required this.emailHidden,
  }) : super._();

  factory _$ProfileDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileDataImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String username;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String firstName;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String lastName;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String email;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String graduationYear;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String city;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String profession;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String website;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String university;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String signature;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String photo;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String company;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String title;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String expertise;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String linkedinUrl;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String universityDepartment;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool mentorOptIn;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String mentorTopics;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool kvkkConsent;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool directoryConsent;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool emailHidden;

  @override
  String toString() {
    return 'ProfileData(id: $id, username: $username, firstName: $firstName, lastName: $lastName, email: $email, graduationYear: $graduationYear, city: $city, profession: $profession, website: $website, university: $university, signature: $signature, photo: $photo, company: $company, title: $title, expertise: $expertise, linkedinUrl: $linkedinUrl, universityDepartment: $universityDepartment, mentorOptIn: $mentorOptIn, mentorTopics: $mentorTopics, kvkkConsent: $kvkkConsent, directoryConsent: $directoryConsent, emailHidden: $emailHidden)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileDataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.graduationYear, graduationYear) ||
                other.graduationYear == graduationYear) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.profession, profession) ||
                other.profession == profession) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.university, university) ||
                other.university == university) &&
            (identical(other.signature, signature) ||
                other.signature == signature) &&
            (identical(other.photo, photo) || other.photo == photo) &&
            (identical(other.company, company) || other.company == company) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.expertise, expertise) ||
                other.expertise == expertise) &&
            (identical(other.linkedinUrl, linkedinUrl) ||
                other.linkedinUrl == linkedinUrl) &&
            (identical(other.universityDepartment, universityDepartment) ||
                other.universityDepartment == universityDepartment) &&
            (identical(other.mentorOptIn, mentorOptIn) ||
                other.mentorOptIn == mentorOptIn) &&
            (identical(other.mentorTopics, mentorTopics) ||
                other.mentorTopics == mentorTopics) &&
            (identical(other.kvkkConsent, kvkkConsent) ||
                other.kvkkConsent == kvkkConsent) &&
            (identical(other.directoryConsent, directoryConsent) ||
                other.directoryConsent == directoryConsent) &&
            (identical(other.emailHidden, emailHidden) ||
                other.emailHidden == emailHidden));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    username,
    firstName,
    lastName,
    email,
    graduationYear,
    city,
    profession,
    website,
    university,
    signature,
    photo,
    company,
    title,
    expertise,
    linkedinUrl,
    universityDepartment,
    mentorOptIn,
    mentorTopics,
    kvkkConsent,
    directoryConsent,
    emailHidden,
  ]);

  /// Create a copy of ProfileData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileDataImplCopyWith<_$ProfileDataImpl> get copyWith =>
      __$$ProfileDataImplCopyWithImpl<_$ProfileDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileDataImplToJson(this);
  }
}

abstract class _ProfileData extends ProfileData {
  const factory _ProfileData({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredText) required final String username,
    @JsonKey(fromJson: readRequiredText) required final String firstName,
    @JsonKey(fromJson: readRequiredText) required final String lastName,
    @JsonKey(fromJson: readRequiredText) required final String email,
    @JsonKey(fromJson: readRequiredText) required final String graduationYear,
    @JsonKey(fromJson: readRequiredText) required final String city,
    @JsonKey(fromJson: readRequiredText) required final String profession,
    @JsonKey(fromJson: readRequiredText) required final String website,
    @JsonKey(fromJson: readRequiredText) required final String university,
    @JsonKey(fromJson: readRequiredText) required final String signature,
    @JsonKey(fromJson: readRequiredText) required final String photo,
    @JsonKey(fromJson: readRequiredText) required final String company,
    @JsonKey(fromJson: readRequiredText) required final String title,
    @JsonKey(fromJson: readRequiredText) required final String expertise,
    @JsonKey(fromJson: readRequiredText) required final String linkedinUrl,
    @JsonKey(fromJson: readRequiredText)
    required final String universityDepartment,
    @JsonKey(fromJson: readRequiredBool) required final bool mentorOptIn,
    @JsonKey(fromJson: readRequiredText) required final String mentorTopics,
    @JsonKey(fromJson: readRequiredBool) required final bool kvkkConsent,
    @JsonKey(fromJson: readRequiredBool) required final bool directoryConsent,
    @JsonKey(fromJson: readRequiredBool) required final bool emailHidden,
  }) = _$ProfileDataImpl;
  const _ProfileData._() : super._();

  factory _ProfileData.fromJson(Map<String, dynamic> json) =
      _$ProfileDataImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get username;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get firstName;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get lastName;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get email;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get graduationYear;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get city;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get profession;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get website;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get university;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get signature;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get photo;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get company;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get title;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get expertise;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get linkedinUrl;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get universityDepartment;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get mentorOptIn;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get mentorTopics;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get kvkkConsent;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get directoryConsent;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get emailHidden;

  /// Create a copy of ProfileData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileDataImplCopyWith<_$ProfileDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VerificationUploadResult _$VerificationUploadResultFromJson(
  Map<String, dynamic> json,
) {
  return _VerificationUploadResult.fromJson(json);
}

/// @nodoc
mixin _$VerificationUploadResult {
  @JsonKey(fromJson: readRequiredText)
  String get proofPath => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get proofImageRecordId => throw _privateConstructorUsedError;

  /// Serializes this VerificationUploadResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VerificationUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VerificationUploadResultCopyWith<VerificationUploadResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VerificationUploadResultCopyWith<$Res> {
  factory $VerificationUploadResultCopyWith(
    VerificationUploadResult value,
    $Res Function(VerificationUploadResult) then,
  ) = _$VerificationUploadResultCopyWithImpl<$Res, VerificationUploadResult>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String proofPath,
    @JsonKey(fromJson: readRequiredText) String proofImageRecordId,
  });
}

/// @nodoc
class _$VerificationUploadResultCopyWithImpl<
  $Res,
  $Val extends VerificationUploadResult
>
    implements $VerificationUploadResultCopyWith<$Res> {
  _$VerificationUploadResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VerificationUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? proofPath = null, Object? proofImageRecordId = null}) {
    return _then(
      _value.copyWith(
            proofPath: null == proofPath
                ? _value.proofPath
                : proofPath // ignore: cast_nullable_to_non_nullable
                      as String,
            proofImageRecordId: null == proofImageRecordId
                ? _value.proofImageRecordId
                : proofImageRecordId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VerificationUploadResultImplCopyWith<$Res>
    implements $VerificationUploadResultCopyWith<$Res> {
  factory _$$VerificationUploadResultImplCopyWith(
    _$VerificationUploadResultImpl value,
    $Res Function(_$VerificationUploadResultImpl) then,
  ) = __$$VerificationUploadResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String proofPath,
    @JsonKey(fromJson: readRequiredText) String proofImageRecordId,
  });
}

/// @nodoc
class __$$VerificationUploadResultImplCopyWithImpl<$Res>
    extends
        _$VerificationUploadResultCopyWithImpl<
          $Res,
          _$VerificationUploadResultImpl
        >
    implements _$$VerificationUploadResultImplCopyWith<$Res> {
  __$$VerificationUploadResultImplCopyWithImpl(
    _$VerificationUploadResultImpl _value,
    $Res Function(_$VerificationUploadResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VerificationUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? proofPath = null, Object? proofImageRecordId = null}) {
    return _then(
      _$VerificationUploadResultImpl(
        proofPath: null == proofPath
            ? _value.proofPath
            : proofPath // ignore: cast_nullable_to_non_nullable
                  as String,
        proofImageRecordId: null == proofImageRecordId
            ? _value.proofImageRecordId
            : proofImageRecordId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VerificationUploadResultImpl implements _VerificationUploadResult {
  const _$VerificationUploadResultImpl({
    @JsonKey(fromJson: readRequiredText) required this.proofPath,
    @JsonKey(fromJson: readRequiredText) required this.proofImageRecordId,
  });

  factory _$VerificationUploadResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$VerificationUploadResultImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredText)
  final String proofPath;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String proofImageRecordId;

  @override
  String toString() {
    return 'VerificationUploadResult(proofPath: $proofPath, proofImageRecordId: $proofImageRecordId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VerificationUploadResultImpl &&
            (identical(other.proofPath, proofPath) ||
                other.proofPath == proofPath) &&
            (identical(other.proofImageRecordId, proofImageRecordId) ||
                other.proofImageRecordId == proofImageRecordId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, proofPath, proofImageRecordId);

  /// Create a copy of VerificationUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VerificationUploadResultImplCopyWith<_$VerificationUploadResultImpl>
  get copyWith =>
      __$$VerificationUploadResultImplCopyWithImpl<
        _$VerificationUploadResultImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VerificationUploadResultImplToJson(this);
  }
}

abstract class _VerificationUploadResult implements VerificationUploadResult {
  const factory _VerificationUploadResult({
    @JsonKey(fromJson: readRequiredText) required final String proofPath,
    @JsonKey(fromJson: readRequiredText)
    required final String proofImageRecordId,
  }) = _$VerificationUploadResultImpl;

  factory _VerificationUploadResult.fromJson(Map<String, dynamic> json) =
      _$VerificationUploadResultImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredText)
  String get proofPath;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get proofImageRecordId;

  /// Create a copy of VerificationUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VerificationUploadResultImplCopyWith<_$VerificationUploadResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}
