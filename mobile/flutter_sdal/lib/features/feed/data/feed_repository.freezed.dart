// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FeedAuthor _$FeedAuthorFromJson(Map<String, dynamic> json) {
  return _FeedAuthor.fromJson(json);
}

/// @nodoc
mixin _$FeedAuthor {
  @JsonKey(fromJson: readOptionalInt)
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get isim => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get kadi => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get resim => throw _privateConstructorUsedError;

  /// Serializes this FeedAuthor to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedAuthor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedAuthorCopyWith<FeedAuthor> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedAuthorCopyWith<$Res> {
  factory $FeedAuthorCopyWith(
    FeedAuthor value,
    $Res Function(FeedAuthor) then,
  ) = _$FeedAuthorCopyWithImpl<$Res, FeedAuthor>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readOptionalInt) int? id,
    @JsonKey(fromJson: readRequiredText) String isim,
    @JsonKey(fromJson: readRequiredText) String kadi,
    @JsonKey(fromJson: readRequiredText) String resim,
  });
}

/// @nodoc
class _$FeedAuthorCopyWithImpl<$Res, $Val extends FeedAuthor>
    implements $FeedAuthorCopyWith<$Res> {
  _$FeedAuthorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedAuthor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? isim = null,
    Object? kadi = null,
    Object? resim = null,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int?,
            isim: null == isim
                ? _value.isim
                : isim // ignore: cast_nullable_to_non_nullable
                      as String,
            kadi: null == kadi
                ? _value.kadi
                : kadi // ignore: cast_nullable_to_non_nullable
                      as String,
            resim: null == resim
                ? _value.resim
                : resim // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeedAuthorImplCopyWith<$Res>
    implements $FeedAuthorCopyWith<$Res> {
  factory _$$FeedAuthorImplCopyWith(
    _$FeedAuthorImpl value,
    $Res Function(_$FeedAuthorImpl) then,
  ) = __$$FeedAuthorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readOptionalInt) int? id,
    @JsonKey(fromJson: readRequiredText) String isim,
    @JsonKey(fromJson: readRequiredText) String kadi,
    @JsonKey(fromJson: readRequiredText) String resim,
  });
}

/// @nodoc
class __$$FeedAuthorImplCopyWithImpl<$Res>
    extends _$FeedAuthorCopyWithImpl<$Res, _$FeedAuthorImpl>
    implements _$$FeedAuthorImplCopyWith<$Res> {
  __$$FeedAuthorImplCopyWithImpl(
    _$FeedAuthorImpl _value,
    $Res Function(_$FeedAuthorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeedAuthor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? isim = null,
    Object? kadi = null,
    Object? resim = null,
  }) {
    return _then(
      _$FeedAuthorImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int?,
        isim: null == isim
            ? _value.isim
            : isim // ignore: cast_nullable_to_non_nullable
                  as String,
        kadi: null == kadi
            ? _value.kadi
            : kadi // ignore: cast_nullable_to_non_nullable
                  as String,
        resim: null == resim
            ? _value.resim
            : resim // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedAuthorImpl implements _FeedAuthor {
  const _$FeedAuthorImpl({
    @JsonKey(fromJson: readOptionalInt) this.id,
    @JsonKey(fromJson: readRequiredText) required this.isim,
    @JsonKey(fromJson: readRequiredText) required this.kadi,
    @JsonKey(fromJson: readRequiredText) required this.resim,
  });

  factory _$FeedAuthorImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedAuthorImplFromJson(json);

  @override
  @JsonKey(fromJson: readOptionalInt)
  final int? id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String isim;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String kadi;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String resim;

  @override
  String toString() {
    return 'FeedAuthor(id: $id, isim: $isim, kadi: $kadi, resim: $resim)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedAuthorImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.isim, isim) || other.isim == isim) &&
            (identical(other.kadi, kadi) || other.kadi == kadi) &&
            (identical(other.resim, resim) || other.resim == resim));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, isim, kadi, resim);

  /// Create a copy of FeedAuthor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedAuthorImplCopyWith<_$FeedAuthorImpl> get copyWith =>
      __$$FeedAuthorImplCopyWithImpl<_$FeedAuthorImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedAuthorImplToJson(this);
  }
}

abstract class _FeedAuthor implements FeedAuthor {
  const factory _FeedAuthor({
    @JsonKey(fromJson: readOptionalInt) final int? id,
    @JsonKey(fromJson: readRequiredText) required final String isim,
    @JsonKey(fromJson: readRequiredText) required final String kadi,
    @JsonKey(fromJson: readRequiredText) required final String resim,
  }) = _$FeedAuthorImpl;

  factory _FeedAuthor.fromJson(Map<String, dynamic> json) =
      _$FeedAuthorImpl.fromJson;

  @override
  @JsonKey(fromJson: readOptionalInt)
  int? get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get isim;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get kadi;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get resim;

  /// Create a copy of FeedAuthor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedAuthorImplCopyWith<_$FeedAuthorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeedVariants _$FeedVariantsFromJson(Map<String, dynamic> json) {
  return _FeedVariants.fromJson(json);
}

/// @nodoc
mixin _$FeedVariants {
  @JsonKey(fromJson: readRequiredText)
  String get feedUrl => throw _privateConstructorUsedError;

  /// Serializes this FeedVariants to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedVariants
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedVariantsCopyWith<FeedVariants> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedVariantsCopyWith<$Res> {
  factory $FeedVariantsCopyWith(
    FeedVariants value,
    $Res Function(FeedVariants) then,
  ) = _$FeedVariantsCopyWithImpl<$Res, FeedVariants>;
  @useResult
  $Res call({@JsonKey(fromJson: readRequiredText) String feedUrl});
}

/// @nodoc
class _$FeedVariantsCopyWithImpl<$Res, $Val extends FeedVariants>
    implements $FeedVariantsCopyWith<$Res> {
  _$FeedVariantsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedVariants
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? feedUrl = null}) {
    return _then(
      _value.copyWith(
            feedUrl: null == feedUrl
                ? _value.feedUrl
                : feedUrl // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeedVariantsImplCopyWith<$Res>
    implements $FeedVariantsCopyWith<$Res> {
  factory _$$FeedVariantsImplCopyWith(
    _$FeedVariantsImpl value,
    $Res Function(_$FeedVariantsImpl) then,
  ) = __$$FeedVariantsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(fromJson: readRequiredText) String feedUrl});
}

/// @nodoc
class __$$FeedVariantsImplCopyWithImpl<$Res>
    extends _$FeedVariantsCopyWithImpl<$Res, _$FeedVariantsImpl>
    implements _$$FeedVariantsImplCopyWith<$Res> {
  __$$FeedVariantsImplCopyWithImpl(
    _$FeedVariantsImpl _value,
    $Res Function(_$FeedVariantsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeedVariants
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? feedUrl = null}) {
    return _then(
      _$FeedVariantsImpl(
        feedUrl: null == feedUrl
            ? _value.feedUrl
            : feedUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedVariantsImpl implements _FeedVariants {
  const _$FeedVariantsImpl({
    @JsonKey(fromJson: readRequiredText) required this.feedUrl,
  });

  factory _$FeedVariantsImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedVariantsImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredText)
  final String feedUrl;

  @override
  String toString() {
    return 'FeedVariants(feedUrl: $feedUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedVariantsImpl &&
            (identical(other.feedUrl, feedUrl) || other.feedUrl == feedUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, feedUrl);

  /// Create a copy of FeedVariants
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedVariantsImplCopyWith<_$FeedVariantsImpl> get copyWith =>
      __$$FeedVariantsImplCopyWithImpl<_$FeedVariantsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedVariantsImplToJson(this);
  }
}

abstract class _FeedVariants implements FeedVariants {
  const factory _FeedVariants({
    @JsonKey(fromJson: readRequiredText) required final String feedUrl,
  }) = _$FeedVariantsImpl;

  factory _FeedVariants.fromJson(Map<String, dynamic> json) =
      _$FeedVariantsImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredText)
  String get feedUrl;

  /// Create a copy of FeedVariants
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedVariantsImplCopyWith<_$FeedVariantsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeedItem _$FeedItemFromJson(Map<String, dynamic> json) {
  return _FeedItem.fromJson(json);
}

/// @nodoc
mixin _$FeedItem {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get content => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get createdAt => throw _privateConstructorUsedError;
  FeedAuthor get author => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get image => throw _privateConstructorUsedError;
  FeedVariants? get variants => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get likeCount => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get commentCount => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get liked => throw _privateConstructorUsedError;

  /// Serializes this FeedItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedItemCopyWith<FeedItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedItemCopyWith<$Res> {
  factory $FeedItemCopyWith(FeedItem value, $Res Function(FeedItem) then) =
      _$FeedItemCopyWithImpl<$Res, FeedItem>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String content,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    FeedAuthor author,
    @JsonKey(fromJson: readRequiredText) String image,
    FeedVariants? variants,
    @JsonKey(fromJson: readRequiredInt) int likeCount,
    @JsonKey(fromJson: readRequiredInt) int commentCount,
    @JsonKey(fromJson: readRequiredBool) bool liked,
  });

  $FeedAuthorCopyWith<$Res> get author;
  $FeedVariantsCopyWith<$Res>? get variants;
}

/// @nodoc
class _$FeedItemCopyWithImpl<$Res, $Val extends FeedItem>
    implements $FeedItemCopyWith<$Res> {
  _$FeedItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? content = null,
    Object? createdAt = null,
    Object? author = null,
    Object? image = null,
    Object? variants = freezed,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? liked = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            author: null == author
                ? _value.author
                : author // ignore: cast_nullable_to_non_nullable
                      as FeedAuthor,
            image: null == image
                ? _value.image
                : image // ignore: cast_nullable_to_non_nullable
                      as String,
            variants: freezed == variants
                ? _value.variants
                : variants // ignore: cast_nullable_to_non_nullable
                      as FeedVariants?,
            likeCount: null == likeCount
                ? _value.likeCount
                : likeCount // ignore: cast_nullable_to_non_nullable
                      as int,
            commentCount: null == commentCount
                ? _value.commentCount
                : commentCount // ignore: cast_nullable_to_non_nullable
                      as int,
            liked: null == liked
                ? _value.liked
                : liked // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeedAuthorCopyWith<$Res> get author {
    return $FeedAuthorCopyWith<$Res>(_value.author, (value) {
      return _then(_value.copyWith(author: value) as $Val);
    });
  }

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeedVariantsCopyWith<$Res>? get variants {
    if (_value.variants == null) {
      return null;
    }

    return $FeedVariantsCopyWith<$Res>(_value.variants!, (value) {
      return _then(_value.copyWith(variants: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FeedItemImplCopyWith<$Res>
    implements $FeedItemCopyWith<$Res> {
  factory _$$FeedItemImplCopyWith(
    _$FeedItemImpl value,
    $Res Function(_$FeedItemImpl) then,
  ) = __$$FeedItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String content,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    FeedAuthor author,
    @JsonKey(fromJson: readRequiredText) String image,
    FeedVariants? variants,
    @JsonKey(fromJson: readRequiredInt) int likeCount,
    @JsonKey(fromJson: readRequiredInt) int commentCount,
    @JsonKey(fromJson: readRequiredBool) bool liked,
  });

  @override
  $FeedAuthorCopyWith<$Res> get author;
  @override
  $FeedVariantsCopyWith<$Res>? get variants;
}

/// @nodoc
class __$$FeedItemImplCopyWithImpl<$Res>
    extends _$FeedItemCopyWithImpl<$Res, _$FeedItemImpl>
    implements _$$FeedItemImplCopyWith<$Res> {
  __$$FeedItemImplCopyWithImpl(
    _$FeedItemImpl _value,
    $Res Function(_$FeedItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? content = null,
    Object? createdAt = null,
    Object? author = null,
    Object? image = null,
    Object? variants = freezed,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? liked = null,
  }) {
    return _then(
      _$FeedItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _value.author
            : author // ignore: cast_nullable_to_non_nullable
                  as FeedAuthor,
        image: null == image
            ? _value.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String,
        variants: freezed == variants
            ? _value.variants
            : variants // ignore: cast_nullable_to_non_nullable
                  as FeedVariants?,
        likeCount: null == likeCount
            ? _value.likeCount
            : likeCount // ignore: cast_nullable_to_non_nullable
                  as int,
        commentCount: null == commentCount
            ? _value.commentCount
            : commentCount // ignore: cast_nullable_to_non_nullable
                  as int,
        liked: null == liked
            ? _value.liked
            : liked // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedItemImpl extends _FeedItem {
  const _$FeedItemImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredText) required this.content,
    @JsonKey(fromJson: readRequiredText) required this.createdAt,
    required this.author,
    @JsonKey(fromJson: readRequiredText) required this.image,
    this.variants,
    @JsonKey(fromJson: readRequiredInt) required this.likeCount,
    @JsonKey(fromJson: readRequiredInt) required this.commentCount,
    @JsonKey(fromJson: readRequiredBool) required this.liked,
  }) : super._();

  factory _$FeedItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedItemImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String content;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String createdAt;
  @override
  final FeedAuthor author;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String image;
  @override
  final FeedVariants? variants;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int likeCount;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int commentCount;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool liked;

  @override
  String toString() {
    return 'FeedItem(id: $id, content: $content, createdAt: $createdAt, author: $author, image: $image, variants: $variants, likeCount: $likeCount, commentCount: $commentCount, liked: $liked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.variants, variants) ||
                other.variants == variants) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.commentCount, commentCount) ||
                other.commentCount == commentCount) &&
            (identical(other.liked, liked) || other.liked == liked));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    content,
    createdAt,
    author,
    image,
    variants,
    likeCount,
    commentCount,
    liked,
  );

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedItemImplCopyWith<_$FeedItemImpl> get copyWith =>
      __$$FeedItemImplCopyWithImpl<_$FeedItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedItemImplToJson(this);
  }
}

abstract class _FeedItem extends FeedItem {
  const factory _FeedItem({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredText) required final String content,
    @JsonKey(fromJson: readRequiredText) required final String createdAt,
    required final FeedAuthor author,
    @JsonKey(fromJson: readRequiredText) required final String image,
    final FeedVariants? variants,
    @JsonKey(fromJson: readRequiredInt) required final int likeCount,
    @JsonKey(fromJson: readRequiredInt) required final int commentCount,
    @JsonKey(fromJson: readRequiredBool) required final bool liked,
  }) = _$FeedItemImpl;
  const _FeedItem._() : super._();

  factory _FeedItem.fromJson(Map<String, dynamic> json) =
      _$FeedItemImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get content;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get createdAt;
  @override
  FeedAuthor get author;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get image;
  @override
  FeedVariants? get variants;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get likeCount;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get commentCount;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get liked;

  /// Create a copy of FeedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedItemImplCopyWith<_$FeedItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeedComment _$FeedCommentFromJson(Map<String, dynamic> json) {
  return _FeedComment.fromJson(json);
}

/// @nodoc
mixin _$FeedComment {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get comment => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get isim => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalInt)
  int? get userId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalText)
  String? get kadi => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalText)
  String? get soyisim => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalText)
  String? get resim => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalBool)
  bool? get verified => throw _privateConstructorUsedError;

  /// Serializes this FeedComment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeedComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedCommentCopyWith<FeedComment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedCommentCopyWith<$Res> {
  factory $FeedCommentCopyWith(
    FeedComment value,
    $Res Function(FeedComment) then,
  ) = _$FeedCommentCopyWithImpl<$Res, FeedComment>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String comment,
    @JsonKey(fromJson: readRequiredText) String isim,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    @JsonKey(fromJson: readOptionalInt) int? userId,
    @JsonKey(fromJson: readOptionalText) String? kadi,
    @JsonKey(fromJson: readOptionalText) String? soyisim,
    @JsonKey(fromJson: readOptionalText) String? resim,
    @JsonKey(fromJson: readOptionalBool) bool? verified,
  });
}

/// @nodoc
class _$FeedCommentCopyWithImpl<$Res, $Val extends FeedComment>
    implements $FeedCommentCopyWith<$Res> {
  _$FeedCommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? comment = null,
    Object? isim = null,
    Object? createdAt = null,
    Object? userId = freezed,
    Object? kadi = freezed,
    Object? soyisim = freezed,
    Object? resim = freezed,
    Object? verified = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            comment: null == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String,
            isim: null == isim
                ? _value.isim
                : isim // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: freezed == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as int?,
            kadi: freezed == kadi
                ? _value.kadi
                : kadi // ignore: cast_nullable_to_non_nullable
                      as String?,
            soyisim: freezed == soyisim
                ? _value.soyisim
                : soyisim // ignore: cast_nullable_to_non_nullable
                      as String?,
            resim: freezed == resim
                ? _value.resim
                : resim // ignore: cast_nullable_to_non_nullable
                      as String?,
            verified: freezed == verified
                ? _value.verified
                : verified // ignore: cast_nullable_to_non_nullable
                      as bool?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeedCommentImplCopyWith<$Res>
    implements $FeedCommentCopyWith<$Res> {
  factory _$$FeedCommentImplCopyWith(
    _$FeedCommentImpl value,
    $Res Function(_$FeedCommentImpl) then,
  ) = __$$FeedCommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String comment,
    @JsonKey(fromJson: readRequiredText) String isim,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    @JsonKey(fromJson: readOptionalInt) int? userId,
    @JsonKey(fromJson: readOptionalText) String? kadi,
    @JsonKey(fromJson: readOptionalText) String? soyisim,
    @JsonKey(fromJson: readOptionalText) String? resim,
    @JsonKey(fromJson: readOptionalBool) bool? verified,
  });
}

/// @nodoc
class __$$FeedCommentImplCopyWithImpl<$Res>
    extends _$FeedCommentCopyWithImpl<$Res, _$FeedCommentImpl>
    implements _$$FeedCommentImplCopyWith<$Res> {
  __$$FeedCommentImplCopyWithImpl(
    _$FeedCommentImpl _value,
    $Res Function(_$FeedCommentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeedComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? comment = null,
    Object? isim = null,
    Object? createdAt = null,
    Object? userId = freezed,
    Object? kadi = freezed,
    Object? soyisim = freezed,
    Object? resim = freezed,
    Object? verified = freezed,
  }) {
    return _then(
      _$FeedCommentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        comment: null == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String,
        isim: null == isim
            ? _value.isim
            : isim // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: freezed == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as int?,
        kadi: freezed == kadi
            ? _value.kadi
            : kadi // ignore: cast_nullable_to_non_nullable
                  as String?,
        soyisim: freezed == soyisim
            ? _value.soyisim
            : soyisim // ignore: cast_nullable_to_non_nullable
                  as String?,
        resim: freezed == resim
            ? _value.resim
            : resim // ignore: cast_nullable_to_non_nullable
                  as String?,
        verified: freezed == verified
            ? _value.verified
            : verified // ignore: cast_nullable_to_non_nullable
                  as bool?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedCommentImpl extends _FeedComment {
  const _$FeedCommentImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredText) required this.comment,
    @JsonKey(fromJson: readRequiredText) required this.isim,
    @JsonKey(fromJson: readRequiredText) required this.createdAt,
    @JsonKey(fromJson: readOptionalInt) this.userId,
    @JsonKey(fromJson: readOptionalText) this.kadi,
    @JsonKey(fromJson: readOptionalText) this.soyisim,
    @JsonKey(fromJson: readOptionalText) this.resim,
    @JsonKey(fromJson: readOptionalBool) this.verified,
  }) : super._();

  factory _$FeedCommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedCommentImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String comment;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String isim;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String createdAt;
  @override
  @JsonKey(fromJson: readOptionalInt)
  final int? userId;
  @override
  @JsonKey(fromJson: readOptionalText)
  final String? kadi;
  @override
  @JsonKey(fromJson: readOptionalText)
  final String? soyisim;
  @override
  @JsonKey(fromJson: readOptionalText)
  final String? resim;
  @override
  @JsonKey(fromJson: readOptionalBool)
  final bool? verified;

  @override
  String toString() {
    return 'FeedComment(id: $id, comment: $comment, isim: $isim, createdAt: $createdAt, userId: $userId, kadi: $kadi, soyisim: $soyisim, resim: $resim, verified: $verified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedCommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.isim, isim) || other.isim == isim) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.kadi, kadi) || other.kadi == kadi) &&
            (identical(other.soyisim, soyisim) || other.soyisim == soyisim) &&
            (identical(other.resim, resim) || other.resim == resim) &&
            (identical(other.verified, verified) ||
                other.verified == verified));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    comment,
    isim,
    createdAt,
    userId,
    kadi,
    soyisim,
    resim,
    verified,
  );

  /// Create a copy of FeedComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedCommentImplCopyWith<_$FeedCommentImpl> get copyWith =>
      __$$FeedCommentImplCopyWithImpl<_$FeedCommentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedCommentImplToJson(this);
  }
}

abstract class _FeedComment extends FeedComment {
  const factory _FeedComment({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredText) required final String comment,
    @JsonKey(fromJson: readRequiredText) required final String isim,
    @JsonKey(fromJson: readRequiredText) required final String createdAt,
    @JsonKey(fromJson: readOptionalInt) final int? userId,
    @JsonKey(fromJson: readOptionalText) final String? kadi,
    @JsonKey(fromJson: readOptionalText) final String? soyisim,
    @JsonKey(fromJson: readOptionalText) final String? resim,
    @JsonKey(fromJson: readOptionalBool) final bool? verified,
  }) = _$FeedCommentImpl;
  const _FeedComment._() : super._();

  factory _FeedComment.fromJson(Map<String, dynamic> json) =
      _$FeedCommentImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get comment;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get isim;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get createdAt;
  @override
  @JsonKey(fromJson: readOptionalInt)
  int? get userId;
  @override
  @JsonKey(fromJson: readOptionalText)
  String? get kadi;
  @override
  @JsonKey(fromJson: readOptionalText)
  String? get soyisim;
  @override
  @JsonKey(fromJson: readOptionalText)
  String? get resim;
  @override
  @JsonKey(fromJson: readOptionalBool)
  bool? get verified;

  /// Create a copy of FeedComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedCommentImplCopyWith<_$FeedCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
