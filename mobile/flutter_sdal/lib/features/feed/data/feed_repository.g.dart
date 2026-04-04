// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeedAuthorImpl _$$FeedAuthorImplFromJson(Map<String, dynamic> json) =>
    _$FeedAuthorImpl(
      isim: readRequiredText(json['isim']),
      kadi: readRequiredText(json['kadi']),
      resim: readRequiredText(json['resim']),
    );

Map<String, dynamic> _$$FeedAuthorImplToJson(_$FeedAuthorImpl instance) =>
    <String, dynamic>{
      'isim': instance.isim,
      'kadi': instance.kadi,
      'resim': instance.resim,
    };

_$FeedVariantsImpl _$$FeedVariantsImplFromJson(Map<String, dynamic> json) =>
    _$FeedVariantsImpl(feedUrl: readRequiredText(json['feedUrl']));

Map<String, dynamic> _$$FeedVariantsImplToJson(_$FeedVariantsImpl instance) =>
    <String, dynamic>{'feedUrl': instance.feedUrl};

_$FeedItemImpl _$$FeedItemImplFromJson(Map<String, dynamic> json) =>
    _$FeedItemImpl(
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
    );

Map<String, dynamic> _$$FeedItemImplToJson(_$FeedItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'createdAt': instance.createdAt,
      'author': instance.author,
      'image': instance.image,
      'variants': instance.variants,
      'likeCount': instance.likeCount,
      'commentCount': instance.commentCount,
      'liked': instance.liked,
    };

_$FeedCommentImpl _$$FeedCommentImplFromJson(Map<String, dynamic> json) =>
    _$FeedCommentImpl(
      id: readRequiredInt(json['id']),
      comment: readRequiredText(json['comment']),
      isim: readRequiredText(json['isim']),
      createdAt: readRequiredText(json['createdAt']),
    );

Map<String, dynamic> _$$FeedCommentImplToJson(_$FeedCommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'comment': instance.comment,
      'isim': instance.isim,
      'createdAt': instance.createdAt,
    };
