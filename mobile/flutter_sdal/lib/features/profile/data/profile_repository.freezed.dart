// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileData {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredText) String get username;@JsonKey(fromJson: readRequiredText) String get firstName;@JsonKey(fromJson: readRequiredText) String get lastName;@JsonKey(fromJson: readRequiredText) String get email;@JsonKey(fromJson: readRequiredText) String get graduationYear;@JsonKey(fromJson: readRequiredText) String get city;@JsonKey(fromJson: readRequiredText) String get profession;@JsonKey(fromJson: readRequiredText) String get website;@JsonKey(fromJson: readRequiredText) String get university;@JsonKey(fromJson: readRequiredText) String get signature;@JsonKey(fromJson: readRequiredText) String get photo;@JsonKey(fromJson: readRequiredText) String get company;@JsonKey(fromJson: readRequiredText) String get title;@JsonKey(fromJson: readRequiredText) String get expertise;@JsonKey(fromJson: readRequiredText) String get linkedinUrl;@JsonKey(fromJson: readRequiredText) String get universityDepartment;@JsonKey(fromJson: readRequiredText) String get teacherSubject;@JsonKey(fromJson: readRequiredText) String get teacherSubjectOther;@JsonKey(fromJson: readOptionalInt) int? get teacherStartedYear;@JsonKey(fromJson: readOptionalInt) int? get teacherEndedYear;@JsonKey(fromJson: readRequiredBool) bool get teacherCurrentlyWorking;@JsonKey(fromJson: readRequiredBool) bool get mentorOptIn;@JsonKey(fromJson: readRequiredText) String get mentorTopics;@JsonKey(fromJson: readRequiredBool) bool get kvkkConsent;@JsonKey(fromJson: readRequiredBool) bool get directoryConsent;@JsonKey(fromJson: readRequiredBool) bool get emailHidden;
/// Create a copy of ProfileData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileDataCopyWith<ProfileData> get copyWith => _$ProfileDataCopyWithImpl<ProfileData>(this as ProfileData, _$identity);

  /// Serializes this ProfileData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileData&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.graduationYear, graduationYear) || other.graduationYear == graduationYear)&&(identical(other.city, city) || other.city == city)&&(identical(other.profession, profession) || other.profession == profession)&&(identical(other.website, website) || other.website == website)&&(identical(other.university, university) || other.university == university)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.company, company) || other.company == company)&&(identical(other.title, title) || other.title == title)&&(identical(other.expertise, expertise) || other.expertise == expertise)&&(identical(other.linkedinUrl, linkedinUrl) || other.linkedinUrl == linkedinUrl)&&(identical(other.universityDepartment, universityDepartment) || other.universityDepartment == universityDepartment)&&(identical(other.teacherSubject, teacherSubject) || other.teacherSubject == teacherSubject)&&(identical(other.teacherSubjectOther, teacherSubjectOther) || other.teacherSubjectOther == teacherSubjectOther)&&(identical(other.teacherStartedYear, teacherStartedYear) || other.teacherStartedYear == teacherStartedYear)&&(identical(other.teacherEndedYear, teacherEndedYear) || other.teacherEndedYear == teacherEndedYear)&&(identical(other.teacherCurrentlyWorking, teacherCurrentlyWorking) || other.teacherCurrentlyWorking == teacherCurrentlyWorking)&&(identical(other.mentorOptIn, mentorOptIn) || other.mentorOptIn == mentorOptIn)&&(identical(other.mentorTopics, mentorTopics) || other.mentorTopics == mentorTopics)&&(identical(other.kvkkConsent, kvkkConsent) || other.kvkkConsent == kvkkConsent)&&(identical(other.directoryConsent, directoryConsent) || other.directoryConsent == directoryConsent)&&(identical(other.emailHidden, emailHidden) || other.emailHidden == emailHidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,username,firstName,lastName,email,graduationYear,city,profession,website,university,signature,photo,company,title,expertise,linkedinUrl,universityDepartment,teacherSubject,teacherSubjectOther,teacherStartedYear,teacherEndedYear,teacherCurrentlyWorking,mentorOptIn,mentorTopics,kvkkConsent,directoryConsent,emailHidden]);

@override
String toString() {
  return 'ProfileData(id: $id, username: $username, firstName: $firstName, lastName: $lastName, email: $email, graduationYear: $graduationYear, city: $city, profession: $profession, website: $website, university: $university, signature: $signature, photo: $photo, company: $company, title: $title, expertise: $expertise, linkedinUrl: $linkedinUrl, universityDepartment: $universityDepartment, teacherSubject: $teacherSubject, teacherSubjectOther: $teacherSubjectOther, teacherStartedYear: $teacherStartedYear, teacherEndedYear: $teacherEndedYear, teacherCurrentlyWorking: $teacherCurrentlyWorking, mentorOptIn: $mentorOptIn, mentorTopics: $mentorTopics, kvkkConsent: $kvkkConsent, directoryConsent: $directoryConsent, emailHidden: $emailHidden)';
}


}

/// @nodoc
abstract mixin class $ProfileDataCopyWith<$Res>  {
  factory $ProfileDataCopyWith(ProfileData value, $Res Function(ProfileData) _then) = _$ProfileDataCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String username,@JsonKey(fromJson: readRequiredText) String firstName,@JsonKey(fromJson: readRequiredText) String lastName,@JsonKey(fromJson: readRequiredText) String email,@JsonKey(fromJson: readRequiredText) String graduationYear,@JsonKey(fromJson: readRequiredText) String city,@JsonKey(fromJson: readRequiredText) String profession,@JsonKey(fromJson: readRequiredText) String website,@JsonKey(fromJson: readRequiredText) String university,@JsonKey(fromJson: readRequiredText) String signature,@JsonKey(fromJson: readRequiredText) String photo,@JsonKey(fromJson: readRequiredText) String company,@JsonKey(fromJson: readRequiredText) String title,@JsonKey(fromJson: readRequiredText) String expertise,@JsonKey(fromJson: readRequiredText) String linkedinUrl,@JsonKey(fromJson: readRequiredText) String universityDepartment,@JsonKey(fromJson: readRequiredText) String teacherSubject,@JsonKey(fromJson: readRequiredText) String teacherSubjectOther,@JsonKey(fromJson: readOptionalInt) int? teacherStartedYear,@JsonKey(fromJson: readOptionalInt) int? teacherEndedYear,@JsonKey(fromJson: readRequiredBool) bool teacherCurrentlyWorking,@JsonKey(fromJson: readRequiredBool) bool mentorOptIn,@JsonKey(fromJson: readRequiredText) String mentorTopics,@JsonKey(fromJson: readRequiredBool) bool kvkkConsent,@JsonKey(fromJson: readRequiredBool) bool directoryConsent,@JsonKey(fromJson: readRequiredBool) bool emailHidden
});




}
/// @nodoc
class _$ProfileDataCopyWithImpl<$Res>
    implements $ProfileDataCopyWith<$Res> {
  _$ProfileDataCopyWithImpl(this._self, this._then);

  final ProfileData _self;
  final $Res Function(ProfileData) _then;

/// Create a copy of ProfileData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? graduationYear = null,Object? city = null,Object? profession = null,Object? website = null,Object? university = null,Object? signature = null,Object? photo = null,Object? company = null,Object? title = null,Object? expertise = null,Object? linkedinUrl = null,Object? universityDepartment = null,Object? teacherSubject = null,Object? teacherSubjectOther = null,Object? teacherStartedYear = freezed,Object? teacherEndedYear = freezed,Object? teacherCurrentlyWorking = null,Object? mentorOptIn = null,Object? mentorTopics = null,Object? kvkkConsent = null,Object? directoryConsent = null,Object? emailHidden = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,graduationYear: null == graduationYear ? _self.graduationYear : graduationYear // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,profession: null == profession ? _self.profession : profession // ignore: cast_nullable_to_non_nullable
as String,website: null == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String,university: null == university ? _self.university : university // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,expertise: null == expertise ? _self.expertise : expertise // ignore: cast_nullable_to_non_nullable
as String,linkedinUrl: null == linkedinUrl ? _self.linkedinUrl : linkedinUrl // ignore: cast_nullable_to_non_nullable
as String,universityDepartment: null == universityDepartment ? _self.universityDepartment : universityDepartment // ignore: cast_nullable_to_non_nullable
as String,teacherSubject: null == teacherSubject ? _self.teacherSubject : teacherSubject // ignore: cast_nullable_to_non_nullable
as String,teacherSubjectOther: null == teacherSubjectOther ? _self.teacherSubjectOther : teacherSubjectOther // ignore: cast_nullable_to_non_nullable
as String,teacherStartedYear: freezed == teacherStartedYear ? _self.teacherStartedYear : teacherStartedYear // ignore: cast_nullable_to_non_nullable
as int?,teacherEndedYear: freezed == teacherEndedYear ? _self.teacherEndedYear : teacherEndedYear // ignore: cast_nullable_to_non_nullable
as int?,teacherCurrentlyWorking: null == teacherCurrentlyWorking ? _self.teacherCurrentlyWorking : teacherCurrentlyWorking // ignore: cast_nullable_to_non_nullable
as bool,mentorOptIn: null == mentorOptIn ? _self.mentorOptIn : mentorOptIn // ignore: cast_nullable_to_non_nullable
as bool,mentorTopics: null == mentorTopics ? _self.mentorTopics : mentorTopics // ignore: cast_nullable_to_non_nullable
as String,kvkkConsent: null == kvkkConsent ? _self.kvkkConsent : kvkkConsent // ignore: cast_nullable_to_non_nullable
as bool,directoryConsent: null == directoryConsent ? _self.directoryConsent : directoryConsent // ignore: cast_nullable_to_non_nullable
as bool,emailHidden: null == emailHidden ? _self.emailHidden : emailHidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileData].
extension ProfileDataPatterns on ProfileData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileData value)  $default,){
final _that = this;
switch (_that) {
case _ProfileData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileData value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String username, @JsonKey(fromJson: readRequiredText)  String firstName, @JsonKey(fromJson: readRequiredText)  String lastName, @JsonKey(fromJson: readRequiredText)  String email, @JsonKey(fromJson: readRequiredText)  String graduationYear, @JsonKey(fromJson: readRequiredText)  String city, @JsonKey(fromJson: readRequiredText)  String profession, @JsonKey(fromJson: readRequiredText)  String website, @JsonKey(fromJson: readRequiredText)  String university, @JsonKey(fromJson: readRequiredText)  String signature, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredText)  String company, @JsonKey(fromJson: readRequiredText)  String title, @JsonKey(fromJson: readRequiredText)  String expertise, @JsonKey(fromJson: readRequiredText)  String linkedinUrl, @JsonKey(fromJson: readRequiredText)  String universityDepartment, @JsonKey(fromJson: readRequiredText)  String teacherSubject, @JsonKey(fromJson: readRequiredText)  String teacherSubjectOther, @JsonKey(fromJson: readOptionalInt)  int? teacherStartedYear, @JsonKey(fromJson: readOptionalInt)  int? teacherEndedYear, @JsonKey(fromJson: readRequiredBool)  bool teacherCurrentlyWorking, @JsonKey(fromJson: readRequiredBool)  bool mentorOptIn, @JsonKey(fromJson: readRequiredText)  String mentorTopics, @JsonKey(fromJson: readRequiredBool)  bool kvkkConsent, @JsonKey(fromJson: readRequiredBool)  bool directoryConsent, @JsonKey(fromJson: readRequiredBool)  bool emailHidden)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileData() when $default != null:
return $default(_that.id,_that.username,_that.firstName,_that.lastName,_that.email,_that.graduationYear,_that.city,_that.profession,_that.website,_that.university,_that.signature,_that.photo,_that.company,_that.title,_that.expertise,_that.linkedinUrl,_that.universityDepartment,_that.teacherSubject,_that.teacherSubjectOther,_that.teacherStartedYear,_that.teacherEndedYear,_that.teacherCurrentlyWorking,_that.mentorOptIn,_that.mentorTopics,_that.kvkkConsent,_that.directoryConsent,_that.emailHidden);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String username, @JsonKey(fromJson: readRequiredText)  String firstName, @JsonKey(fromJson: readRequiredText)  String lastName, @JsonKey(fromJson: readRequiredText)  String email, @JsonKey(fromJson: readRequiredText)  String graduationYear, @JsonKey(fromJson: readRequiredText)  String city, @JsonKey(fromJson: readRequiredText)  String profession, @JsonKey(fromJson: readRequiredText)  String website, @JsonKey(fromJson: readRequiredText)  String university, @JsonKey(fromJson: readRequiredText)  String signature, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredText)  String company, @JsonKey(fromJson: readRequiredText)  String title, @JsonKey(fromJson: readRequiredText)  String expertise, @JsonKey(fromJson: readRequiredText)  String linkedinUrl, @JsonKey(fromJson: readRequiredText)  String universityDepartment, @JsonKey(fromJson: readRequiredText)  String teacherSubject, @JsonKey(fromJson: readRequiredText)  String teacherSubjectOther, @JsonKey(fromJson: readOptionalInt)  int? teacherStartedYear, @JsonKey(fromJson: readOptionalInt)  int? teacherEndedYear, @JsonKey(fromJson: readRequiredBool)  bool teacherCurrentlyWorking, @JsonKey(fromJson: readRequiredBool)  bool mentorOptIn, @JsonKey(fromJson: readRequiredText)  String mentorTopics, @JsonKey(fromJson: readRequiredBool)  bool kvkkConsent, @JsonKey(fromJson: readRequiredBool)  bool directoryConsent, @JsonKey(fromJson: readRequiredBool)  bool emailHidden)  $default,) {final _that = this;
switch (_that) {
case _ProfileData():
return $default(_that.id,_that.username,_that.firstName,_that.lastName,_that.email,_that.graduationYear,_that.city,_that.profession,_that.website,_that.university,_that.signature,_that.photo,_that.company,_that.title,_that.expertise,_that.linkedinUrl,_that.universityDepartment,_that.teacherSubject,_that.teacherSubjectOther,_that.teacherStartedYear,_that.teacherEndedYear,_that.teacherCurrentlyWorking,_that.mentorOptIn,_that.mentorTopics,_that.kvkkConsent,_that.directoryConsent,_that.emailHidden);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String username, @JsonKey(fromJson: readRequiredText)  String firstName, @JsonKey(fromJson: readRequiredText)  String lastName, @JsonKey(fromJson: readRequiredText)  String email, @JsonKey(fromJson: readRequiredText)  String graduationYear, @JsonKey(fromJson: readRequiredText)  String city, @JsonKey(fromJson: readRequiredText)  String profession, @JsonKey(fromJson: readRequiredText)  String website, @JsonKey(fromJson: readRequiredText)  String university, @JsonKey(fromJson: readRequiredText)  String signature, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredText)  String company, @JsonKey(fromJson: readRequiredText)  String title, @JsonKey(fromJson: readRequiredText)  String expertise, @JsonKey(fromJson: readRequiredText)  String linkedinUrl, @JsonKey(fromJson: readRequiredText)  String universityDepartment, @JsonKey(fromJson: readRequiredText)  String teacherSubject, @JsonKey(fromJson: readRequiredText)  String teacherSubjectOther, @JsonKey(fromJson: readOptionalInt)  int? teacherStartedYear, @JsonKey(fromJson: readOptionalInt)  int? teacherEndedYear, @JsonKey(fromJson: readRequiredBool)  bool teacherCurrentlyWorking, @JsonKey(fromJson: readRequiredBool)  bool mentorOptIn, @JsonKey(fromJson: readRequiredText)  String mentorTopics, @JsonKey(fromJson: readRequiredBool)  bool kvkkConsent, @JsonKey(fromJson: readRequiredBool)  bool directoryConsent, @JsonKey(fromJson: readRequiredBool)  bool emailHidden)?  $default,) {final _that = this;
switch (_that) {
case _ProfileData() when $default != null:
return $default(_that.id,_that.username,_that.firstName,_that.lastName,_that.email,_that.graduationYear,_that.city,_that.profession,_that.website,_that.university,_that.signature,_that.photo,_that.company,_that.title,_that.expertise,_that.linkedinUrl,_that.universityDepartment,_that.teacherSubject,_that.teacherSubjectOther,_that.teacherStartedYear,_that.teacherEndedYear,_that.teacherCurrentlyWorking,_that.mentorOptIn,_that.mentorTopics,_that.kvkkConsent,_that.directoryConsent,_that.emailHidden);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileData extends ProfileData {
  const _ProfileData({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredText) required this.username, @JsonKey(fromJson: readRequiredText) required this.firstName, @JsonKey(fromJson: readRequiredText) required this.lastName, @JsonKey(fromJson: readRequiredText) required this.email, @JsonKey(fromJson: readRequiredText) required this.graduationYear, @JsonKey(fromJson: readRequiredText) required this.city, @JsonKey(fromJson: readRequiredText) required this.profession, @JsonKey(fromJson: readRequiredText) required this.website, @JsonKey(fromJson: readRequiredText) required this.university, @JsonKey(fromJson: readRequiredText) required this.signature, @JsonKey(fromJson: readRequiredText) required this.photo, @JsonKey(fromJson: readRequiredText) required this.company, @JsonKey(fromJson: readRequiredText) required this.title, @JsonKey(fromJson: readRequiredText) required this.expertise, @JsonKey(fromJson: readRequiredText) required this.linkedinUrl, @JsonKey(fromJson: readRequiredText) required this.universityDepartment, @JsonKey(fromJson: readRequiredText) required this.teacherSubject, @JsonKey(fromJson: readRequiredText) required this.teacherSubjectOther, @JsonKey(fromJson: readOptionalInt) this.teacherStartedYear, @JsonKey(fromJson: readOptionalInt) this.teacherEndedYear, @JsonKey(fromJson: readRequiredBool) required this.teacherCurrentlyWorking, @JsonKey(fromJson: readRequiredBool) required this.mentorOptIn, @JsonKey(fromJson: readRequiredText) required this.mentorTopics, @JsonKey(fromJson: readRequiredBool) required this.kvkkConsent, @JsonKey(fromJson: readRequiredBool) required this.directoryConsent, @JsonKey(fromJson: readRequiredBool) required this.emailHidden}): super._();
  factory _ProfileData.fromJson(Map<String, dynamic> json) => _$ProfileDataFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredText) final  String username;
@override@JsonKey(fromJson: readRequiredText) final  String firstName;
@override@JsonKey(fromJson: readRequiredText) final  String lastName;
@override@JsonKey(fromJson: readRequiredText) final  String email;
@override@JsonKey(fromJson: readRequiredText) final  String graduationYear;
@override@JsonKey(fromJson: readRequiredText) final  String city;
@override@JsonKey(fromJson: readRequiredText) final  String profession;
@override@JsonKey(fromJson: readRequiredText) final  String website;
@override@JsonKey(fromJson: readRequiredText) final  String university;
@override@JsonKey(fromJson: readRequiredText) final  String signature;
@override@JsonKey(fromJson: readRequiredText) final  String photo;
@override@JsonKey(fromJson: readRequiredText) final  String company;
@override@JsonKey(fromJson: readRequiredText) final  String title;
@override@JsonKey(fromJson: readRequiredText) final  String expertise;
@override@JsonKey(fromJson: readRequiredText) final  String linkedinUrl;
@override@JsonKey(fromJson: readRequiredText) final  String universityDepartment;
@override@JsonKey(fromJson: readRequiredText) final  String teacherSubject;
@override@JsonKey(fromJson: readRequiredText) final  String teacherSubjectOther;
@override@JsonKey(fromJson: readOptionalInt) final  int? teacherStartedYear;
@override@JsonKey(fromJson: readOptionalInt) final  int? teacherEndedYear;
@override@JsonKey(fromJson: readRequiredBool) final  bool teacherCurrentlyWorking;
@override@JsonKey(fromJson: readRequiredBool) final  bool mentorOptIn;
@override@JsonKey(fromJson: readRequiredText) final  String mentorTopics;
@override@JsonKey(fromJson: readRequiredBool) final  bool kvkkConsent;
@override@JsonKey(fromJson: readRequiredBool) final  bool directoryConsent;
@override@JsonKey(fromJson: readRequiredBool) final  bool emailHidden;

/// Create a copy of ProfileData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileDataCopyWith<_ProfileData> get copyWith => __$ProfileDataCopyWithImpl<_ProfileData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileData&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.graduationYear, graduationYear) || other.graduationYear == graduationYear)&&(identical(other.city, city) || other.city == city)&&(identical(other.profession, profession) || other.profession == profession)&&(identical(other.website, website) || other.website == website)&&(identical(other.university, university) || other.university == university)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.company, company) || other.company == company)&&(identical(other.title, title) || other.title == title)&&(identical(other.expertise, expertise) || other.expertise == expertise)&&(identical(other.linkedinUrl, linkedinUrl) || other.linkedinUrl == linkedinUrl)&&(identical(other.universityDepartment, universityDepartment) || other.universityDepartment == universityDepartment)&&(identical(other.teacherSubject, teacherSubject) || other.teacherSubject == teacherSubject)&&(identical(other.teacherSubjectOther, teacherSubjectOther) || other.teacherSubjectOther == teacherSubjectOther)&&(identical(other.teacherStartedYear, teacherStartedYear) || other.teacherStartedYear == teacherStartedYear)&&(identical(other.teacherEndedYear, teacherEndedYear) || other.teacherEndedYear == teacherEndedYear)&&(identical(other.teacherCurrentlyWorking, teacherCurrentlyWorking) || other.teacherCurrentlyWorking == teacherCurrentlyWorking)&&(identical(other.mentorOptIn, mentorOptIn) || other.mentorOptIn == mentorOptIn)&&(identical(other.mentorTopics, mentorTopics) || other.mentorTopics == mentorTopics)&&(identical(other.kvkkConsent, kvkkConsent) || other.kvkkConsent == kvkkConsent)&&(identical(other.directoryConsent, directoryConsent) || other.directoryConsent == directoryConsent)&&(identical(other.emailHidden, emailHidden) || other.emailHidden == emailHidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,username,firstName,lastName,email,graduationYear,city,profession,website,university,signature,photo,company,title,expertise,linkedinUrl,universityDepartment,teacherSubject,teacherSubjectOther,teacherStartedYear,teacherEndedYear,teacherCurrentlyWorking,mentorOptIn,mentorTopics,kvkkConsent,directoryConsent,emailHidden]);

@override
String toString() {
  return 'ProfileData(id: $id, username: $username, firstName: $firstName, lastName: $lastName, email: $email, graduationYear: $graduationYear, city: $city, profession: $profession, website: $website, university: $university, signature: $signature, photo: $photo, company: $company, title: $title, expertise: $expertise, linkedinUrl: $linkedinUrl, universityDepartment: $universityDepartment, teacherSubject: $teacherSubject, teacherSubjectOther: $teacherSubjectOther, teacherStartedYear: $teacherStartedYear, teacherEndedYear: $teacherEndedYear, teacherCurrentlyWorking: $teacherCurrentlyWorking, mentorOptIn: $mentorOptIn, mentorTopics: $mentorTopics, kvkkConsent: $kvkkConsent, directoryConsent: $directoryConsent, emailHidden: $emailHidden)';
}


}

/// @nodoc
abstract mixin class _$ProfileDataCopyWith<$Res> implements $ProfileDataCopyWith<$Res> {
  factory _$ProfileDataCopyWith(_ProfileData value, $Res Function(_ProfileData) _then) = __$ProfileDataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String username,@JsonKey(fromJson: readRequiredText) String firstName,@JsonKey(fromJson: readRequiredText) String lastName,@JsonKey(fromJson: readRequiredText) String email,@JsonKey(fromJson: readRequiredText) String graduationYear,@JsonKey(fromJson: readRequiredText) String city,@JsonKey(fromJson: readRequiredText) String profession,@JsonKey(fromJson: readRequiredText) String website,@JsonKey(fromJson: readRequiredText) String university,@JsonKey(fromJson: readRequiredText) String signature,@JsonKey(fromJson: readRequiredText) String photo,@JsonKey(fromJson: readRequiredText) String company,@JsonKey(fromJson: readRequiredText) String title,@JsonKey(fromJson: readRequiredText) String expertise,@JsonKey(fromJson: readRequiredText) String linkedinUrl,@JsonKey(fromJson: readRequiredText) String universityDepartment,@JsonKey(fromJson: readRequiredText) String teacherSubject,@JsonKey(fromJson: readRequiredText) String teacherSubjectOther,@JsonKey(fromJson: readOptionalInt) int? teacherStartedYear,@JsonKey(fromJson: readOptionalInt) int? teacherEndedYear,@JsonKey(fromJson: readRequiredBool) bool teacherCurrentlyWorking,@JsonKey(fromJson: readRequiredBool) bool mentorOptIn,@JsonKey(fromJson: readRequiredText) String mentorTopics,@JsonKey(fromJson: readRequiredBool) bool kvkkConsent,@JsonKey(fromJson: readRequiredBool) bool directoryConsent,@JsonKey(fromJson: readRequiredBool) bool emailHidden
});




}
/// @nodoc
class __$ProfileDataCopyWithImpl<$Res>
    implements _$ProfileDataCopyWith<$Res> {
  __$ProfileDataCopyWithImpl(this._self, this._then);

  final _ProfileData _self;
  final $Res Function(_ProfileData) _then;

/// Create a copy of ProfileData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? graduationYear = null,Object? city = null,Object? profession = null,Object? website = null,Object? university = null,Object? signature = null,Object? photo = null,Object? company = null,Object? title = null,Object? expertise = null,Object? linkedinUrl = null,Object? universityDepartment = null,Object? teacherSubject = null,Object? teacherSubjectOther = null,Object? teacherStartedYear = freezed,Object? teacherEndedYear = freezed,Object? teacherCurrentlyWorking = null,Object? mentorOptIn = null,Object? mentorTopics = null,Object? kvkkConsent = null,Object? directoryConsent = null,Object? emailHidden = null,}) {
  return _then(_ProfileData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,graduationYear: null == graduationYear ? _self.graduationYear : graduationYear // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,profession: null == profession ? _self.profession : profession // ignore: cast_nullable_to_non_nullable
as String,website: null == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String,university: null == university ? _self.university : university // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,expertise: null == expertise ? _self.expertise : expertise // ignore: cast_nullable_to_non_nullable
as String,linkedinUrl: null == linkedinUrl ? _self.linkedinUrl : linkedinUrl // ignore: cast_nullable_to_non_nullable
as String,universityDepartment: null == universityDepartment ? _self.universityDepartment : universityDepartment // ignore: cast_nullable_to_non_nullable
as String,teacherSubject: null == teacherSubject ? _self.teacherSubject : teacherSubject // ignore: cast_nullable_to_non_nullable
as String,teacherSubjectOther: null == teacherSubjectOther ? _self.teacherSubjectOther : teacherSubjectOther // ignore: cast_nullable_to_non_nullable
as String,teacherStartedYear: freezed == teacherStartedYear ? _self.teacherStartedYear : teacherStartedYear // ignore: cast_nullable_to_non_nullable
as int?,teacherEndedYear: freezed == teacherEndedYear ? _self.teacherEndedYear : teacherEndedYear // ignore: cast_nullable_to_non_nullable
as int?,teacherCurrentlyWorking: null == teacherCurrentlyWorking ? _self.teacherCurrentlyWorking : teacherCurrentlyWorking // ignore: cast_nullable_to_non_nullable
as bool,mentorOptIn: null == mentorOptIn ? _self.mentorOptIn : mentorOptIn // ignore: cast_nullable_to_non_nullable
as bool,mentorTopics: null == mentorTopics ? _self.mentorTopics : mentorTopics // ignore: cast_nullable_to_non_nullable
as String,kvkkConsent: null == kvkkConsent ? _self.kvkkConsent : kvkkConsent // ignore: cast_nullable_to_non_nullable
as bool,directoryConsent: null == directoryConsent ? _self.directoryConsent : directoryConsent // ignore: cast_nullable_to_non_nullable
as bool,emailHidden: null == emailHidden ? _self.emailHidden : emailHidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$VerificationUploadResult {

@JsonKey(fromJson: readRequiredText) String get proofPath;@JsonKey(fromJson: readRequiredText) String get proofImageRecordId;
/// Create a copy of VerificationUploadResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerificationUploadResultCopyWith<VerificationUploadResult> get copyWith => _$VerificationUploadResultCopyWithImpl<VerificationUploadResult>(this as VerificationUploadResult, _$identity);

  /// Serializes this VerificationUploadResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerificationUploadResult&&(identical(other.proofPath, proofPath) || other.proofPath == proofPath)&&(identical(other.proofImageRecordId, proofImageRecordId) || other.proofImageRecordId == proofImageRecordId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proofPath,proofImageRecordId);

@override
String toString() {
  return 'VerificationUploadResult(proofPath: $proofPath, proofImageRecordId: $proofImageRecordId)';
}


}

/// @nodoc
abstract mixin class $VerificationUploadResultCopyWith<$Res>  {
  factory $VerificationUploadResultCopyWith(VerificationUploadResult value, $Res Function(VerificationUploadResult) _then) = _$VerificationUploadResultCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String proofPath,@JsonKey(fromJson: readRequiredText) String proofImageRecordId
});




}
/// @nodoc
class _$VerificationUploadResultCopyWithImpl<$Res>
    implements $VerificationUploadResultCopyWith<$Res> {
  _$VerificationUploadResultCopyWithImpl(this._self, this._then);

  final VerificationUploadResult _self;
  final $Res Function(VerificationUploadResult) _then;

/// Create a copy of VerificationUploadResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? proofPath = null,Object? proofImageRecordId = null,}) {
  return _then(_self.copyWith(
proofPath: null == proofPath ? _self.proofPath : proofPath // ignore: cast_nullable_to_non_nullable
as String,proofImageRecordId: null == proofImageRecordId ? _self.proofImageRecordId : proofImageRecordId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VerificationUploadResult].
extension VerificationUploadResultPatterns on VerificationUploadResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerificationUploadResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerificationUploadResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerificationUploadResult value)  $default,){
final _that = this;
switch (_that) {
case _VerificationUploadResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerificationUploadResult value)?  $default,){
final _that = this;
switch (_that) {
case _VerificationUploadResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String proofPath, @JsonKey(fromJson: readRequiredText)  String proofImageRecordId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerificationUploadResult() when $default != null:
return $default(_that.proofPath,_that.proofImageRecordId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String proofPath, @JsonKey(fromJson: readRequiredText)  String proofImageRecordId)  $default,) {final _that = this;
switch (_that) {
case _VerificationUploadResult():
return $default(_that.proofPath,_that.proofImageRecordId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredText)  String proofPath, @JsonKey(fromJson: readRequiredText)  String proofImageRecordId)?  $default,) {final _that = this;
switch (_that) {
case _VerificationUploadResult() when $default != null:
return $default(_that.proofPath,_that.proofImageRecordId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerificationUploadResult implements VerificationUploadResult {
  const _VerificationUploadResult({@JsonKey(fromJson: readRequiredText) required this.proofPath, @JsonKey(fromJson: readRequiredText) required this.proofImageRecordId});
  factory _VerificationUploadResult.fromJson(Map<String, dynamic> json) => _$VerificationUploadResultFromJson(json);

@override@JsonKey(fromJson: readRequiredText) final  String proofPath;
@override@JsonKey(fromJson: readRequiredText) final  String proofImageRecordId;

/// Create a copy of VerificationUploadResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerificationUploadResultCopyWith<_VerificationUploadResult> get copyWith => __$VerificationUploadResultCopyWithImpl<_VerificationUploadResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerificationUploadResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerificationUploadResult&&(identical(other.proofPath, proofPath) || other.proofPath == proofPath)&&(identical(other.proofImageRecordId, proofImageRecordId) || other.proofImageRecordId == proofImageRecordId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proofPath,proofImageRecordId);

@override
String toString() {
  return 'VerificationUploadResult(proofPath: $proofPath, proofImageRecordId: $proofImageRecordId)';
}


}

/// @nodoc
abstract mixin class _$VerificationUploadResultCopyWith<$Res> implements $VerificationUploadResultCopyWith<$Res> {
  factory _$VerificationUploadResultCopyWith(_VerificationUploadResult value, $Res Function(_VerificationUploadResult) _then) = __$VerificationUploadResultCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String proofPath,@JsonKey(fromJson: readRequiredText) String proofImageRecordId
});




}
/// @nodoc
class __$VerificationUploadResultCopyWithImpl<$Res>
    implements _$VerificationUploadResultCopyWith<$Res> {
  __$VerificationUploadResultCopyWithImpl(this._self, this._then);

  final _VerificationUploadResult _self;
  final $Res Function(_VerificationUploadResult) _then;

/// Create a copy of VerificationUploadResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? proofPath = null,Object? proofImageRecordId = null,}) {
  return _then(_VerificationUploadResult(
proofPath: null == proofPath ? _self.proofPath : proofPath // ignore: cast_nullable_to_non_nullable
as String,proofImageRecordId: null == proofImageRecordId ? _self.proofImageRecordId : proofImageRecordId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
