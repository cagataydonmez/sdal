// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedAuthor {

@JsonKey(fromJson: readOptionalInt) int? get id;@JsonKey(fromJson: readRequiredText) String get isim;@JsonKey(fromJson: readRequiredText) String get kadi;@JsonKey(fromJson: readRequiredText) String get resim;
/// Create a copy of FeedAuthor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedAuthorCopyWith<FeedAuthor> get copyWith => _$FeedAuthorCopyWithImpl<FeedAuthor>(this as FeedAuthor, _$identity);

  /// Serializes this FeedAuthor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedAuthor&&(identical(other.id, id) || other.id == id)&&(identical(other.isim, isim) || other.isim == isim)&&(identical(other.kadi, kadi) || other.kadi == kadi)&&(identical(other.resim, resim) || other.resim == resim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,isim,kadi,resim);

@override
String toString() {
  return 'FeedAuthor(id: $id, isim: $isim, kadi: $kadi, resim: $resim)';
}


}

/// @nodoc
abstract mixin class $FeedAuthorCopyWith<$Res>  {
  factory $FeedAuthorCopyWith(FeedAuthor value, $Res Function(FeedAuthor) _then) = _$FeedAuthorCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readOptionalInt) int? id,@JsonKey(fromJson: readRequiredText) String isim,@JsonKey(fromJson: readRequiredText) String kadi,@JsonKey(fromJson: readRequiredText) String resim
});




}
/// @nodoc
class _$FeedAuthorCopyWithImpl<$Res>
    implements $FeedAuthorCopyWith<$Res> {
  _$FeedAuthorCopyWithImpl(this._self, this._then);

  final FeedAuthor _self;
  final $Res Function(FeedAuthor) _then;

/// Create a copy of FeedAuthor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? isim = null,Object? kadi = null,Object? resim = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,isim: null == isim ? _self.isim : isim // ignore: cast_nullable_to_non_nullable
as String,kadi: null == kadi ? _self.kadi : kadi // ignore: cast_nullable_to_non_nullable
as String,resim: null == resim ? _self.resim : resim // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedAuthor].
extension FeedAuthorPatterns on FeedAuthor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedAuthor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedAuthor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedAuthor value)  $default,){
final _that = this;
switch (_that) {
case _FeedAuthor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedAuthor value)?  $default,){
final _that = this;
switch (_that) {
case _FeedAuthor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readOptionalInt)  int? id, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String kadi, @JsonKey(fromJson: readRequiredText)  String resim)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedAuthor() when $default != null:
return $default(_that.id,_that.isim,_that.kadi,_that.resim);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readOptionalInt)  int? id, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String kadi, @JsonKey(fromJson: readRequiredText)  String resim)  $default,) {final _that = this;
switch (_that) {
case _FeedAuthor():
return $default(_that.id,_that.isim,_that.kadi,_that.resim);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readOptionalInt)  int? id, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String kadi, @JsonKey(fromJson: readRequiredText)  String resim)?  $default,) {final _that = this;
switch (_that) {
case _FeedAuthor() when $default != null:
return $default(_that.id,_that.isim,_that.kadi,_that.resim);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedAuthor implements FeedAuthor {
  const _FeedAuthor({@JsonKey(fromJson: readOptionalInt) this.id, @JsonKey(fromJson: readRequiredText) required this.isim, @JsonKey(fromJson: readRequiredText) required this.kadi, @JsonKey(fromJson: readRequiredText) required this.resim});
  factory _FeedAuthor.fromJson(Map<String, dynamic> json) => _$FeedAuthorFromJson(json);

@override@JsonKey(fromJson: readOptionalInt) final  int? id;
@override@JsonKey(fromJson: readRequiredText) final  String isim;
@override@JsonKey(fromJson: readRequiredText) final  String kadi;
@override@JsonKey(fromJson: readRequiredText) final  String resim;

/// Create a copy of FeedAuthor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedAuthorCopyWith<_FeedAuthor> get copyWith => __$FeedAuthorCopyWithImpl<_FeedAuthor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedAuthorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedAuthor&&(identical(other.id, id) || other.id == id)&&(identical(other.isim, isim) || other.isim == isim)&&(identical(other.kadi, kadi) || other.kadi == kadi)&&(identical(other.resim, resim) || other.resim == resim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,isim,kadi,resim);

@override
String toString() {
  return 'FeedAuthor(id: $id, isim: $isim, kadi: $kadi, resim: $resim)';
}


}

/// @nodoc
abstract mixin class _$FeedAuthorCopyWith<$Res> implements $FeedAuthorCopyWith<$Res> {
  factory _$FeedAuthorCopyWith(_FeedAuthor value, $Res Function(_FeedAuthor) _then) = __$FeedAuthorCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readOptionalInt) int? id,@JsonKey(fromJson: readRequiredText) String isim,@JsonKey(fromJson: readRequiredText) String kadi,@JsonKey(fromJson: readRequiredText) String resim
});




}
/// @nodoc
class __$FeedAuthorCopyWithImpl<$Res>
    implements _$FeedAuthorCopyWith<$Res> {
  __$FeedAuthorCopyWithImpl(this._self, this._then);

  final _FeedAuthor _self;
  final $Res Function(_FeedAuthor) _then;

/// Create a copy of FeedAuthor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? isim = null,Object? kadi = null,Object? resim = null,}) {
  return _then(_FeedAuthor(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,isim: null == isim ? _self.isim : isim // ignore: cast_nullable_to_non_nullable
as String,kadi: null == kadi ? _self.kadi : kadi // ignore: cast_nullable_to_non_nullable
as String,resim: null == resim ? _self.resim : resim // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$FeedVariants {

@JsonKey(fromJson: readRequiredText) String get feedUrl;@JsonKey(fromJson: readOptionalText) String? get thumbUrl;@JsonKey(fromJson: readOptionalText) String? get fullUrl;
/// Create a copy of FeedVariants
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedVariantsCopyWith<FeedVariants> get copyWith => _$FeedVariantsCopyWithImpl<FeedVariants>(this as FeedVariants, _$identity);

  /// Serializes this FeedVariants to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedVariants&&(identical(other.feedUrl, feedUrl) || other.feedUrl == feedUrl)&&(identical(other.thumbUrl, thumbUrl) || other.thumbUrl == thumbUrl)&&(identical(other.fullUrl, fullUrl) || other.fullUrl == fullUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,feedUrl,thumbUrl,fullUrl);

@override
String toString() {
  return 'FeedVariants(feedUrl: $feedUrl, thumbUrl: $thumbUrl, fullUrl: $fullUrl)';
}


}

/// @nodoc
abstract mixin class $FeedVariantsCopyWith<$Res>  {
  factory $FeedVariantsCopyWith(FeedVariants value, $Res Function(FeedVariants) _then) = _$FeedVariantsCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String feedUrl,@JsonKey(fromJson: readOptionalText) String? thumbUrl,@JsonKey(fromJson: readOptionalText) String? fullUrl
});




}
/// @nodoc
class _$FeedVariantsCopyWithImpl<$Res>
    implements $FeedVariantsCopyWith<$Res> {
  _$FeedVariantsCopyWithImpl(this._self, this._then);

  final FeedVariants _self;
  final $Res Function(FeedVariants) _then;

/// Create a copy of FeedVariants
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? feedUrl = null,Object? thumbUrl = freezed,Object? fullUrl = freezed,}) {
  return _then(_self.copyWith(
feedUrl: null == feedUrl ? _self.feedUrl : feedUrl // ignore: cast_nullable_to_non_nullable
as String,thumbUrl: freezed == thumbUrl ? _self.thumbUrl : thumbUrl // ignore: cast_nullable_to_non_nullable
as String?,fullUrl: freezed == fullUrl ? _self.fullUrl : fullUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedVariants].
extension FeedVariantsPatterns on FeedVariants {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedVariants value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedVariants() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedVariants value)  $default,){
final _that = this;
switch (_that) {
case _FeedVariants():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedVariants value)?  $default,){
final _that = this;
switch (_that) {
case _FeedVariants() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String feedUrl, @JsonKey(fromJson: readOptionalText)  String? thumbUrl, @JsonKey(fromJson: readOptionalText)  String? fullUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedVariants() when $default != null:
return $default(_that.feedUrl,_that.thumbUrl,_that.fullUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String feedUrl, @JsonKey(fromJson: readOptionalText)  String? thumbUrl, @JsonKey(fromJson: readOptionalText)  String? fullUrl)  $default,) {final _that = this;
switch (_that) {
case _FeedVariants():
return $default(_that.feedUrl,_that.thumbUrl,_that.fullUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredText)  String feedUrl, @JsonKey(fromJson: readOptionalText)  String? thumbUrl, @JsonKey(fromJson: readOptionalText)  String? fullUrl)?  $default,) {final _that = this;
switch (_that) {
case _FeedVariants() when $default != null:
return $default(_that.feedUrl,_that.thumbUrl,_that.fullUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedVariants implements FeedVariants {
  const _FeedVariants({@JsonKey(fromJson: readRequiredText) required this.feedUrl, @JsonKey(fromJson: readOptionalText) this.thumbUrl, @JsonKey(fromJson: readOptionalText) this.fullUrl});
  factory _FeedVariants.fromJson(Map<String, dynamic> json) => _$FeedVariantsFromJson(json);

@override@JsonKey(fromJson: readRequiredText) final  String feedUrl;
@override@JsonKey(fromJson: readOptionalText) final  String? thumbUrl;
@override@JsonKey(fromJson: readOptionalText) final  String? fullUrl;

/// Create a copy of FeedVariants
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedVariantsCopyWith<_FeedVariants> get copyWith => __$FeedVariantsCopyWithImpl<_FeedVariants>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedVariantsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedVariants&&(identical(other.feedUrl, feedUrl) || other.feedUrl == feedUrl)&&(identical(other.thumbUrl, thumbUrl) || other.thumbUrl == thumbUrl)&&(identical(other.fullUrl, fullUrl) || other.fullUrl == fullUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,feedUrl,thumbUrl,fullUrl);

@override
String toString() {
  return 'FeedVariants(feedUrl: $feedUrl, thumbUrl: $thumbUrl, fullUrl: $fullUrl)';
}


}

/// @nodoc
abstract mixin class _$FeedVariantsCopyWith<$Res> implements $FeedVariantsCopyWith<$Res> {
  factory _$FeedVariantsCopyWith(_FeedVariants value, $Res Function(_FeedVariants) _then) = __$FeedVariantsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String feedUrl,@JsonKey(fromJson: readOptionalText) String? thumbUrl,@JsonKey(fromJson: readOptionalText) String? fullUrl
});




}
/// @nodoc
class __$FeedVariantsCopyWithImpl<$Res>
    implements _$FeedVariantsCopyWith<$Res> {
  __$FeedVariantsCopyWithImpl(this._self, this._then);

  final _FeedVariants _self;
  final $Res Function(_FeedVariants) _then;

/// Create a copy of FeedVariants
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? feedUrl = null,Object? thumbUrl = freezed,Object? fullUrl = freezed,}) {
  return _then(_FeedVariants(
feedUrl: null == feedUrl ? _self.feedUrl : feedUrl // ignore: cast_nullable_to_non_nullable
as String,thumbUrl: freezed == thumbUrl ? _self.thumbUrl : thumbUrl // ignore: cast_nullable_to_non_nullable
as String?,fullUrl: freezed == fullUrl ? _self.fullUrl : fullUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$FeedItem {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredText) String get content;@JsonKey(fromJson: readRequiredText) String get createdAt; FeedAuthor get author;@JsonKey(fromJson: readRequiredText) String get image; FeedVariants? get variants;@JsonKey(fromJson: readRequiredInt) int get likeCount;@JsonKey(fromJson: readRequiredInt) int get commentCount;@JsonKey(fromJson: readRequiredBool) bool get liked;@JsonKey(fromJson: readOptionalText) String? get updatedAt;@JsonKey(fromJson: readOptionalText) String? get postType;@JsonKey(fromJson: readOptionalInt) int? get entityId;
/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedItemCopyWith<FeedItem> get copyWith => _$FeedItemCopyWithImpl<FeedItem>(this as FeedItem, _$identity);

  /// Serializes this FeedItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.author, author) || other.author == author)&&(identical(other.image, image) || other.image == image)&&(identical(other.variants, variants) || other.variants == variants)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.liked, liked) || other.liked == liked)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.postType, postType) || other.postType == postType)&&(identical(other.entityId, entityId) || other.entityId == entityId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,content,createdAt,author,image,variants,likeCount,commentCount,liked,updatedAt,postType,entityId);

@override
String toString() {
  return 'FeedItem(id: $id, content: $content, createdAt: $createdAt, author: $author, image: $image, variants: $variants, likeCount: $likeCount, commentCount: $commentCount, liked: $liked, updatedAt: $updatedAt, postType: $postType, entityId: $entityId)';
}


}

/// @nodoc
abstract mixin class $FeedItemCopyWith<$Res>  {
  factory $FeedItemCopyWith(FeedItem value, $Res Function(FeedItem) _then) = _$FeedItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String content,@JsonKey(fromJson: readRequiredText) String createdAt, FeedAuthor author,@JsonKey(fromJson: readRequiredText) String image, FeedVariants? variants,@JsonKey(fromJson: readRequiredInt) int likeCount,@JsonKey(fromJson: readRequiredInt) int commentCount,@JsonKey(fromJson: readRequiredBool) bool liked,@JsonKey(fromJson: readOptionalText) String? updatedAt,@JsonKey(fromJson: readOptionalText) String? postType,@JsonKey(fromJson: readOptionalInt) int? entityId
});


$FeedAuthorCopyWith<$Res> get author;$FeedVariantsCopyWith<$Res>? get variants;

}
/// @nodoc
class _$FeedItemCopyWithImpl<$Res>
    implements $FeedItemCopyWith<$Res> {
  _$FeedItemCopyWithImpl(this._self, this._then);

  final FeedItem _self;
  final $Res Function(FeedItem) _then;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? content = null,Object? createdAt = null,Object? author = null,Object? image = null,Object? variants = freezed,Object? likeCount = null,Object? commentCount = null,Object? liked = null,Object? updatedAt = freezed,Object? postType = freezed,Object? entityId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as FeedAuthor,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,variants: freezed == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as FeedVariants?,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,liked: null == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,postType: freezed == postType ? _self.postType : postType // ignore: cast_nullable_to_non_nullable
as String?,entityId: freezed == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedAuthorCopyWith<$Res> get author {
  
  return $FeedAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedVariantsCopyWith<$Res>? get variants {
    if (_self.variants == null) {
    return null;
  }

  return $FeedVariantsCopyWith<$Res>(_self.variants!, (value) {
    return _then(_self.copyWith(variants: value));
  });
}
}


/// Adds pattern-matching-related methods to [FeedItem].
extension FeedItemPatterns on FeedItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedItem value)  $default,){
final _that = this;
switch (_that) {
case _FeedItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedItem value)?  $default,){
final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String content, @JsonKey(fromJson: readRequiredText)  String createdAt,  FeedAuthor author, @JsonKey(fromJson: readRequiredText)  String image,  FeedVariants? variants, @JsonKey(fromJson: readRequiredInt)  int likeCount, @JsonKey(fromJson: readRequiredInt)  int commentCount, @JsonKey(fromJson: readRequiredBool)  bool liked, @JsonKey(fromJson: readOptionalText)  String? updatedAt, @JsonKey(fromJson: readOptionalText)  String? postType, @JsonKey(fromJson: readOptionalInt)  int? entityId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
return $default(_that.id,_that.content,_that.createdAt,_that.author,_that.image,_that.variants,_that.likeCount,_that.commentCount,_that.liked,_that.updatedAt,_that.postType,_that.entityId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String content, @JsonKey(fromJson: readRequiredText)  String createdAt,  FeedAuthor author, @JsonKey(fromJson: readRequiredText)  String image,  FeedVariants? variants, @JsonKey(fromJson: readRequiredInt)  int likeCount, @JsonKey(fromJson: readRequiredInt)  int commentCount, @JsonKey(fromJson: readRequiredBool)  bool liked, @JsonKey(fromJson: readOptionalText)  String? updatedAt, @JsonKey(fromJson: readOptionalText)  String? postType, @JsonKey(fromJson: readOptionalInt)  int? entityId)  $default,) {final _that = this;
switch (_that) {
case _FeedItem():
return $default(_that.id,_that.content,_that.createdAt,_that.author,_that.image,_that.variants,_that.likeCount,_that.commentCount,_that.liked,_that.updatedAt,_that.postType,_that.entityId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String content, @JsonKey(fromJson: readRequiredText)  String createdAt,  FeedAuthor author, @JsonKey(fromJson: readRequiredText)  String image,  FeedVariants? variants, @JsonKey(fromJson: readRequiredInt)  int likeCount, @JsonKey(fromJson: readRequiredInt)  int commentCount, @JsonKey(fromJson: readRequiredBool)  bool liked, @JsonKey(fromJson: readOptionalText)  String? updatedAt, @JsonKey(fromJson: readOptionalText)  String? postType, @JsonKey(fromJson: readOptionalInt)  int? entityId)?  $default,) {final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
return $default(_that.id,_that.content,_that.createdAt,_that.author,_that.image,_that.variants,_that.likeCount,_that.commentCount,_that.liked,_that.updatedAt,_that.postType,_that.entityId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedItem extends FeedItem {
  const _FeedItem({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredText) required this.content, @JsonKey(fromJson: readRequiredText) required this.createdAt, required this.author, @JsonKey(fromJson: readRequiredText) required this.image, this.variants, @JsonKey(fromJson: readRequiredInt) required this.likeCount, @JsonKey(fromJson: readRequiredInt) required this.commentCount, @JsonKey(fromJson: readRequiredBool) required this.liked, @JsonKey(fromJson: readOptionalText) this.updatedAt, @JsonKey(fromJson: readOptionalText) this.postType, @JsonKey(fromJson: readOptionalInt) this.entityId}): super._();
  factory _FeedItem.fromJson(Map<String, dynamic> json) => _$FeedItemFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredText) final  String content;
@override@JsonKey(fromJson: readRequiredText) final  String createdAt;
@override final  FeedAuthor author;
@override@JsonKey(fromJson: readRequiredText) final  String image;
@override final  FeedVariants? variants;
@override@JsonKey(fromJson: readRequiredInt) final  int likeCount;
@override@JsonKey(fromJson: readRequiredInt) final  int commentCount;
@override@JsonKey(fromJson: readRequiredBool) final  bool liked;
@override@JsonKey(fromJson: readOptionalText) final  String? updatedAt;
@override@JsonKey(fromJson: readOptionalText) final  String? postType;
@override@JsonKey(fromJson: readOptionalInt) final  int? entityId;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedItemCopyWith<_FeedItem> get copyWith => __$FeedItemCopyWithImpl<_FeedItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.author, author) || other.author == author)&&(identical(other.image, image) || other.image == image)&&(identical(other.variants, variants) || other.variants == variants)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.liked, liked) || other.liked == liked)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.postType, postType) || other.postType == postType)&&(identical(other.entityId, entityId) || other.entityId == entityId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,content,createdAt,author,image,variants,likeCount,commentCount,liked,updatedAt,postType,entityId);

@override
String toString() {
  return 'FeedItem(id: $id, content: $content, createdAt: $createdAt, author: $author, image: $image, variants: $variants, likeCount: $likeCount, commentCount: $commentCount, liked: $liked, updatedAt: $updatedAt, postType: $postType, entityId: $entityId)';
}


}

/// @nodoc
abstract mixin class _$FeedItemCopyWith<$Res> implements $FeedItemCopyWith<$Res> {
  factory _$FeedItemCopyWith(_FeedItem value, $Res Function(_FeedItem) _then) = __$FeedItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String content,@JsonKey(fromJson: readRequiredText) String createdAt, FeedAuthor author,@JsonKey(fromJson: readRequiredText) String image, FeedVariants? variants,@JsonKey(fromJson: readRequiredInt) int likeCount,@JsonKey(fromJson: readRequiredInt) int commentCount,@JsonKey(fromJson: readRequiredBool) bool liked,@JsonKey(fromJson: readOptionalText) String? updatedAt,@JsonKey(fromJson: readOptionalText) String? postType,@JsonKey(fromJson: readOptionalInt) int? entityId
});


@override $FeedAuthorCopyWith<$Res> get author;@override $FeedVariantsCopyWith<$Res>? get variants;

}
/// @nodoc
class __$FeedItemCopyWithImpl<$Res>
    implements _$FeedItemCopyWith<$Res> {
  __$FeedItemCopyWithImpl(this._self, this._then);

  final _FeedItem _self;
  final $Res Function(_FeedItem) _then;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? content = null,Object? createdAt = null,Object? author = null,Object? image = null,Object? variants = freezed,Object? likeCount = null,Object? commentCount = null,Object? liked = null,Object? updatedAt = freezed,Object? postType = freezed,Object? entityId = freezed,}) {
  return _then(_FeedItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as FeedAuthor,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,variants: freezed == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as FeedVariants?,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,liked: null == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,postType: freezed == postType ? _self.postType : postType // ignore: cast_nullable_to_non_nullable
as String?,entityId: freezed == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedAuthorCopyWith<$Res> get author {
  
  return $FeedAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedVariantsCopyWith<$Res>? get variants {
    if (_self.variants == null) {
    return null;
  }

  return $FeedVariantsCopyWith<$Res>(_self.variants!, (value) {
    return _then(_self.copyWith(variants: value));
  });
}
}


/// @nodoc
mixin _$FeedComment {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredText) String get comment;@JsonKey(fromJson: readRequiredText) String get isim;@JsonKey(fromJson: readRequiredText) String get createdAt;@JsonKey(fromJson: readOptionalInt) int? get userId;@JsonKey(fromJson: readOptionalText) String? get kadi;@JsonKey(fromJson: readOptionalText) String? get soyisim;@JsonKey(fromJson: readOptionalText) String? get resim;@JsonKey(fromJson: readOptionalBool) bool? get verified;@JsonKey(fromJson: readOptionalText) String? get updatedAt;
/// Create a copy of FeedComment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedCommentCopyWith<FeedComment> get copyWith => _$FeedCommentCopyWithImpl<FeedComment>(this as FeedComment, _$identity);

  /// Serializes this FeedComment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedComment&&(identical(other.id, id) || other.id == id)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.isim, isim) || other.isim == isim)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.kadi, kadi) || other.kadi == kadi)&&(identical(other.soyisim, soyisim) || other.soyisim == soyisim)&&(identical(other.resim, resim) || other.resim == resim)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,comment,isim,createdAt,userId,kadi,soyisim,resim,verified,updatedAt);

@override
String toString() {
  return 'FeedComment(id: $id, comment: $comment, isim: $isim, createdAt: $createdAt, userId: $userId, kadi: $kadi, soyisim: $soyisim, resim: $resim, verified: $verified, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $FeedCommentCopyWith<$Res>  {
  factory $FeedCommentCopyWith(FeedComment value, $Res Function(FeedComment) _then) = _$FeedCommentCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String comment,@JsonKey(fromJson: readRequiredText) String isim,@JsonKey(fromJson: readRequiredText) String createdAt,@JsonKey(fromJson: readOptionalInt) int? userId,@JsonKey(fromJson: readOptionalText) String? kadi,@JsonKey(fromJson: readOptionalText) String? soyisim,@JsonKey(fromJson: readOptionalText) String? resim,@JsonKey(fromJson: readOptionalBool) bool? verified,@JsonKey(fromJson: readOptionalText) String? updatedAt
});




}
/// @nodoc
class _$FeedCommentCopyWithImpl<$Res>
    implements $FeedCommentCopyWith<$Res> {
  _$FeedCommentCopyWithImpl(this._self, this._then);

  final FeedComment _self;
  final $Res Function(FeedComment) _then;

/// Create a copy of FeedComment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? comment = null,Object? isim = null,Object? createdAt = null,Object? userId = freezed,Object? kadi = freezed,Object? soyisim = freezed,Object? resim = freezed,Object? verified = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,comment: null == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String,isim: null == isim ? _self.isim : isim // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,kadi: freezed == kadi ? _self.kadi : kadi // ignore: cast_nullable_to_non_nullable
as String?,soyisim: freezed == soyisim ? _self.soyisim : soyisim // ignore: cast_nullable_to_non_nullable
as String?,resim: freezed == resim ? _self.resim : resim // ignore: cast_nullable_to_non_nullable
as String?,verified: freezed == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedComment].
extension FeedCommentPatterns on FeedComment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedComment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedComment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedComment value)  $default,){
final _that = this;
switch (_that) {
case _FeedComment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedComment value)?  $default,){
final _that = this;
switch (_that) {
case _FeedComment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String comment, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readOptionalInt)  int? userId, @JsonKey(fromJson: readOptionalText)  String? kadi, @JsonKey(fromJson: readOptionalText)  String? soyisim, @JsonKey(fromJson: readOptionalText)  String? resim, @JsonKey(fromJson: readOptionalBool)  bool? verified, @JsonKey(fromJson: readOptionalText)  String? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedComment() when $default != null:
return $default(_that.id,_that.comment,_that.isim,_that.createdAt,_that.userId,_that.kadi,_that.soyisim,_that.resim,_that.verified,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String comment, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readOptionalInt)  int? userId, @JsonKey(fromJson: readOptionalText)  String? kadi, @JsonKey(fromJson: readOptionalText)  String? soyisim, @JsonKey(fromJson: readOptionalText)  String? resim, @JsonKey(fromJson: readOptionalBool)  bool? verified, @JsonKey(fromJson: readOptionalText)  String? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _FeedComment():
return $default(_that.id,_that.comment,_that.isim,_that.createdAt,_that.userId,_that.kadi,_that.soyisim,_that.resim,_that.verified,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String comment, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readOptionalInt)  int? userId, @JsonKey(fromJson: readOptionalText)  String? kadi, @JsonKey(fromJson: readOptionalText)  String? soyisim, @JsonKey(fromJson: readOptionalText)  String? resim, @JsonKey(fromJson: readOptionalBool)  bool? verified, @JsonKey(fromJson: readOptionalText)  String? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _FeedComment() when $default != null:
return $default(_that.id,_that.comment,_that.isim,_that.createdAt,_that.userId,_that.kadi,_that.soyisim,_that.resim,_that.verified,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedComment extends FeedComment {
  const _FeedComment({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredText) required this.comment, @JsonKey(fromJson: readRequiredText) required this.isim, @JsonKey(fromJson: readRequiredText) required this.createdAt, @JsonKey(fromJson: readOptionalInt) this.userId, @JsonKey(fromJson: readOptionalText) this.kadi, @JsonKey(fromJson: readOptionalText) this.soyisim, @JsonKey(fromJson: readOptionalText) this.resim, @JsonKey(fromJson: readOptionalBool) this.verified, @JsonKey(fromJson: readOptionalText) this.updatedAt}): super._();
  factory _FeedComment.fromJson(Map<String, dynamic> json) => _$FeedCommentFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredText) final  String comment;
@override@JsonKey(fromJson: readRequiredText) final  String isim;
@override@JsonKey(fromJson: readRequiredText) final  String createdAt;
@override@JsonKey(fromJson: readOptionalInt) final  int? userId;
@override@JsonKey(fromJson: readOptionalText) final  String? kadi;
@override@JsonKey(fromJson: readOptionalText) final  String? soyisim;
@override@JsonKey(fromJson: readOptionalText) final  String? resim;
@override@JsonKey(fromJson: readOptionalBool) final  bool? verified;
@override@JsonKey(fromJson: readOptionalText) final  String? updatedAt;

/// Create a copy of FeedComment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedCommentCopyWith<_FeedComment> get copyWith => __$FeedCommentCopyWithImpl<_FeedComment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedCommentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedComment&&(identical(other.id, id) || other.id == id)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.isim, isim) || other.isim == isim)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.kadi, kadi) || other.kadi == kadi)&&(identical(other.soyisim, soyisim) || other.soyisim == soyisim)&&(identical(other.resim, resim) || other.resim == resim)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,comment,isim,createdAt,userId,kadi,soyisim,resim,verified,updatedAt);

@override
String toString() {
  return 'FeedComment(id: $id, comment: $comment, isim: $isim, createdAt: $createdAt, userId: $userId, kadi: $kadi, soyisim: $soyisim, resim: $resim, verified: $verified, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$FeedCommentCopyWith<$Res> implements $FeedCommentCopyWith<$Res> {
  factory _$FeedCommentCopyWith(_FeedComment value, $Res Function(_FeedComment) _then) = __$FeedCommentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String comment,@JsonKey(fromJson: readRequiredText) String isim,@JsonKey(fromJson: readRequiredText) String createdAt,@JsonKey(fromJson: readOptionalInt) int? userId,@JsonKey(fromJson: readOptionalText) String? kadi,@JsonKey(fromJson: readOptionalText) String? soyisim,@JsonKey(fromJson: readOptionalText) String? resim,@JsonKey(fromJson: readOptionalBool) bool? verified,@JsonKey(fromJson: readOptionalText) String? updatedAt
});




}
/// @nodoc
class __$FeedCommentCopyWithImpl<$Res>
    implements _$FeedCommentCopyWith<$Res> {
  __$FeedCommentCopyWithImpl(this._self, this._then);

  final _FeedComment _self;
  final $Res Function(_FeedComment) _then;

/// Create a copy of FeedComment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? comment = null,Object? isim = null,Object? createdAt = null,Object? userId = freezed,Object? kadi = freezed,Object? soyisim = freezed,Object? resim = freezed,Object? verified = freezed,Object? updatedAt = freezed,}) {
  return _then(_FeedComment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,comment: null == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String,isim: null == isim ? _self.isim : isim // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,kadi: freezed == kadi ? _self.kadi : kadi // ignore: cast_nullable_to_non_nullable
as String?,soyisim: freezed == soyisim ? _self.soyisim : soyisim // ignore: cast_nullable_to_non_nullable
as String?,resim: freezed == resim ? _self.resim : resim // ignore: cast_nullable_to_non_nullable
as String?,verified: freezed == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
