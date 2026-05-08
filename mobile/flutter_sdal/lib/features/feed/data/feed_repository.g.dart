// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FeedAuthor _$FeedAuthorFromJson(Map<String, dynamic> json) => _FeedAuthor(
  id: readOptionalInt(json['id']),
  isim: readRequiredText(json['isim']),
  kadi: readRequiredText(json['kadi']),
  resim: readRequiredText(json['resim']),
);

Map<String, dynamic> _$FeedAuthorToJson(_FeedAuthor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'isim': instance.isim,
      'kadi': instance.kadi,
      'resim': instance.resim,
    };

_FeedVariants _$FeedVariantsFromJson(Map<String, dynamic> json) =>
    _FeedVariants(
      feedUrl: readRequiredText(json['feedUrl']),
      thumbUrl: readOptionalText(json['thumbUrl']),
      fullUrl: readOptionalText(json['fullUrl']),
    );

Map<String, dynamic> _$FeedVariantsToJson(_FeedVariants instance) =>
    <String, dynamic>{
      'feedUrl': instance.feedUrl,
      'thumbUrl': instance.thumbUrl,
      'fullUrl': instance.fullUrl,
    };

_FeedItem _$FeedItemFromJson(Map<String, dynamic> json) => _FeedItem(
  id: readRequiredInt(json['id']),
  content: readRequiredText(json['content']),
  createdAt: readRequiredText(json['createdAt']),
  author: FeedAuthor.fromJson(json['author'] as Map<String, dynamic>),
  image: readRequiredText(json['image']),
  variants: json['variants'] == null
      ? null
      : FeedVariants.fromJson(json['variants'] as Map<String, dynamic>),
  likeCount: readRequiredInt(json['likeCount']),
  commentCount: readRequiredInt(json['commentCount']),
  liked: readRequiredBool(json['liked']),
  updatedAt: readOptionalText(json['updatedAt']),
);

Map<String, dynamic> _$FeedItemToJson(_FeedItem instance) => <String, dynamic>{
  'id': instance.id,
  'content': instance.content,
  'createdAt': instance.createdAt,
  'author': instance.author,
  'image': instance.image,
  'variants': instance.variants,
  'likeCount': instance.likeCount,
  'commentCount': instance.commentCount,
  'liked': instance.liked,
  'updatedAt': instance.updatedAt,
};

_FeedComment _$FeedCommentFromJson(Map<String, dynamic> json) => _FeedComment(
  id: readRequiredInt(json['id']),
  comment: readRequiredText(json['comment']),
  isim: readRequiredText(json['isim']),
  createdAt: readRequiredText(json['createdAt']),
  userId: readOptionalInt(json['userId']),
  kadi: readOptionalText(json['kadi']),
  soyisim: readOptionalText(json['soyisim']),
  resim: readOptionalText(json['resim']),
  verified: readOptionalBool(json['verified']),
  updatedAt: readOptionalText(json['updatedAt']),
);

Map<String, dynamic> _$FeedCommentToJson(_FeedComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'comment': instance.comment,
      'isim': instance.isim,
      'createdAt': instance.createdAt,
      'userId': instance.userId,
      'kadi': instance.kadi,
      'soyisim': instance.soyisim,
      'resim': instance.resim,
      'verified': instance.verified,
      'updatedAt': instance.updatedAt,
    };
