import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';
import '../../explore/data/explore_repository.dart';
import '../../groups/data/groups_repository.dart';

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class AlbumPhotoMedia {
  const AlbumPhotoMedia({
    required this.fileName,
    required this.displayFileName,
    required this.displayUrl,
    required this.thumbnailUrl,
    required this.lightboxUrl,
    required this.sourceFileName,
    required this.editMetadata,
    required this.aspectRatio,
    required this.isEdited,
  });

  final String fileName;
  final String displayFileName;
  final String displayUrl;
  final String thumbnailUrl;
  final String lightboxUrl;
  final String sourceFileName;
  final JsonMap editMetadata;
  final double aspectRatio;
  final bool isEdited;

  factory AlbumPhotoMedia.empty(String fileName) {
    final clean = fileName.trim();
    return AlbumPhotoMedia(
      fileName: clean,
      displayFileName: clean,
      displayUrl: '',
      thumbnailUrl: '',
      lightboxUrl: '',
      sourceFileName: '',
      editMetadata: const <String, dynamic>{},
      aspectRatio: 4 / 3,
      isEdited: false,
    );
  }

  factory AlbumPhotoMedia.fromMap(JsonMap map, {String fallbackFileName = ''}) {
    final fileName = coalesceText([
      map['fileName'],
      map['displayFileName'],
      fallbackFileName,
    ], fallback: '');
    return AlbumPhotoMedia(
      fileName: fileName,
      displayFileName: coalesceText([
        map['displayFileName'],
        map['fileName'],
        fallbackFileName,
      ], fallback: fileName),
      displayUrl: coalesceText([map['displayUrl']], fallback: ''),
      thumbnailUrl: coalesceText([map['thumbnailUrl']], fallback: ''),
      lightboxUrl: coalesceText([map['lightboxUrl']], fallback: ''),
      sourceFileName: coalesceText([
        map['sourceFileName'],
        map['editSourceFileName'],
      ], fallback: ''),
      editMetadata: asJsonMap(map['editMetadata']),
      aspectRatio: _asDouble(map['aspectRatio']) ?? 4 / 3,
      isEdited: asBool(map['isEdited']) ?? false,
    );
  }
}

class AlbumCategoryItem {
  const AlbumCategoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.count,
    required this.previews,
    this.previewMedia = const <AlbumPhotoMedia>[],
    required this.visibilityScope,
    required this.cohortYear,
    required this.albumType,
    required this.ownerUserId,
    required this.isSystemAlbum,
    this.coverMode = 'latest',
    this.coverFileName = '',
    required this.canUpload,
    required this.canEdit,
  });

  final int id;
  final String title;
  final String description;
  final int count;
  final List<String> previews;
  final List<AlbumPhotoMedia> previewMedia;
  final String visibilityScope;
  final String cohortYear;
  final String albumType;
  final int? ownerUserId;
  final bool isSystemAlbum;
  final String coverMode;
  final String coverFileName;
  final bool canUpload;
  final bool canEdit;

  bool get isProfileAlbum => albumType == 'profile';
  bool get isCohortAlbum =>
      albumType == 'cohort' || visibilityScope == 'cohort';

  factory AlbumCategoryItem.fromMap(JsonMap map) {
    return AlbumCategoryItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['kategori'], map['title']], fallback: 'Albüm'),
      description: coalesceText([
        map['aciklama'],
        map['description'],
      ], fallback: ''),
      count:
          asInt(
            map['count'] ?? map['photoCount'] ?? map['total'] ?? map['cnt'],
          ) ??
          0,
      previews: (map['previews'] is List)
          ? (map['previews'] as List)
                .map((item) => coalesceText([item], fallback: ''))
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      previewMedia: asJsonMapList(
        map['previewMedia'],
      ).map(AlbumPhotoMedia.fromMap).toList(growable: false),
      visibilityScope: coalesceText([
        map['visibilityScope'],
        map['visibility_scope'],
      ], fallback: 'public'),
      cohortYear: coalesceText([
        map['cohortYear'],
        map['cohort_year'],
      ], fallback: ''),
      albumType: coalesceText([
        map['albumType'],
        map['album_type'],
      ], fallback: 'general'),
      ownerUserId: asInt(map['ownerUserId'] ?? map['owner_user_id']),
      isSystemAlbum:
          asBool(map['isSystemAlbum'] ?? map['is_system_album']) ?? false,
      coverMode: coalesceText([
        map['coverMode'],
        map['cover_mode'],
      ], fallback: 'latest'),
      coverFileName: coalesceText([
        map['coverFileName'],
        map['cover_file_name'],
      ], fallback: ''),
      canUpload: asBool(map['canUpload']) ?? false,
      canEdit: asBool(map['canEdit']) ?? false,
    );
  }
}

class AlbumPhotoCard {
  const AlbumPhotoCard({
    required this.id,
    required this.categoryId,
    required this.fileName,
    required this.title,
    required this.date,
    required this.categoryTitle,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.allowComments,
    required this.media,
    this.groupKey = '',
    this.groupCount = 1,
    this.groupIndex = 0,
  });

  final int id;
  final int categoryId;
  final String fileName;
  final String title;
  final String date;
  final String categoryTitle;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool allowComments;
  final AlbumPhotoMedia media;
  final String groupKey;
  final int groupCount;
  final int groupIndex;

  factory AlbumPhotoCard.fromMap(JsonMap map) {
    final fileName = coalesceText([
      map['dosyaadi'],
      map['file_name'],
    ], fallback: '');
    return AlbumPhotoCard(
      id: asInt(map['id']) ?? 0,
      categoryId: asInt(map['katid'] ?? map['categoryId']) ?? 0,
      fileName: fileName,
      title: coalesceText([map['baslik'], map['title']], fallback: 'Fotoğraf'),
      date: coalesceText([map['tarih'], map['created_at']], fallback: ''),
      categoryTitle: coalesceText([
        map['kategori'],
        map['category_title'],
      ], fallback: ''),
      viewCount: asInt(map['viewCount'] ?? map['hit']) ?? 0,
      likeCount: asInt(map['likeCount']) ?? 0,
      commentCount: asInt(map['commentCount']) ?? 0,
      liked: asBool(map['liked']) ?? false,
      allowComments: asBool(map['allowComments']) ?? true,
      media: AlbumPhotoMedia.fromMap(
        asJsonMap(map['media']),
        fallbackFileName: fileName,
      ),
      groupKey: coalesceText([
        map['groupKey'],
        map['album_group_key'],
      ], fallback: ''),
      groupCount: asInt(map['groupCount']) ?? 1,
      groupIndex: asInt(map['groupIndex']) ?? 0,
    );
  }
}

class AlbumPhotoGroupItem {
  const AlbumPhotoGroupItem({
    required this.id,
    required this.fileName,
    required this.title,
    required this.groupIndex,
    required this.media,
    this.editMetadata = const <String, dynamic>{},
    this.editSourceFileName = '',
  });

  final int id;
  final String fileName;
  final String title;
  final int groupIndex;
  final AlbumPhotoMedia media;
  final JsonMap editMetadata;
  final String editSourceFileName;

  factory AlbumPhotoGroupItem.fromMap(JsonMap map) {
    final fileName = coalesceText([
      map['fileName'],
      map['dosyaadi'],
    ], fallback: '');
    final media = AlbumPhotoMedia.fromMap(
      asJsonMap(map['media']),
      fallbackFileName: fileName,
    );
    return AlbumPhotoGroupItem(
      id: asInt(map['id']) ?? 0,
      fileName: fileName,
      title: coalesceText([map['title'], map['baslik']], fallback: 'Fotoğraf'),
      groupIndex: asInt(map['groupIndex']) ?? 0,
      media: media,
      editMetadata: asJsonMap(map['editMetadata']).isNotEmpty
          ? asJsonMap(map['editMetadata'])
          : media.editMetadata,
      editSourceFileName: coalesceText([
        map['editSourceFileName'],
        media.sourceFileName,
      ], fallback: ''),
    );
  }
}

class AlbumTaggedMember {
  const AlbumTaggedMember({
    required this.id,
    required this.handle,
    required this.firstName,
    required this.lastName,
    required this.photo,
  });

  final int id;
  final String handle;
  final String firstName;
  final String lastName;
  final String photo;

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (handle.isNotEmpty) return '@$handle';
    return 'SDAL Üyesi';
  }

  factory AlbumTaggedMember.fromMap(JsonMap map) {
    return AlbumTaggedMember(
      id: asInt(map['id']) ?? 0,
      handle: coalesceText([map['kadi']], fallback: ''),
      firstName: coalesceText([map['isim']], fallback: ''),
      lastName: coalesceText([map['soyisim']], fallback: ''),
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
    );
  }
}

class AlbumComment {
  const AlbumComment({
    required this.id,
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.comment,
    required this.date,
    required this.updatedAt,
    required this.verified,
    required this.photo,
    required this.canEdit,
    required this.canDelete,
  });

  final int id;
  final int userId;
  final String handle;
  final String displayName;
  final String comment;
  final String date;
  final String updatedAt;
  final bool verified;
  final String photo;
  final bool canEdit;
  final bool canDelete;

  bool get isEdited => updatedAt.trim().isNotEmpty && updatedAt != date;

  factory AlbumComment.fromMap(JsonMap map) {
    final handle = coalesceText([map['kadi'], map['uyeadi']], fallback: '');
    final firstName = coalesceText([map['isim']], fallback: '');
    final lastName = coalesceText([map['soyisim']], fallback: '');
    final fullName = '$firstName $lastName'.trim();
    return AlbumComment(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      handle: handle,
      displayName: coalesceText([fullName, handle], fallback: 'SDAL Üyesi'),
      comment: coalesceText([map['yorum'], map['comment']], fallback: ''),
      date: coalesceText([map['tarih'], map['created_at']], fallback: ''),
      updatedAt: coalesceText([
        map['updatedAt'],
        map['updated_at'],
      ], fallback: ''),
      verified: asBool(map['verified']) ?? false,
      photo: coalesceText([map['resim'], map['photo']], fallback: ''),
      canEdit: asBool(map['canEdit']) ?? false,
      canDelete: asBool(map['canDelete']) ?? false,
    );
  }
}

class AlbumLikeUser {
  const AlbumLikeUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    this.graduationYear,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String avatarUrl;
  final int? graduationYear;

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    return username.isNotEmpty ? username : 'SDAL Üyesi';
  }

  factory AlbumLikeUser.fromMap(JsonMap map) {
    return AlbumLikeUser(
      id: asInt(map['id']) ?? 0,
      username: coalesceText([map['username'], map['kadi']], fallback: ''),
      firstName: coalesceText([map['firstName'], map['isim']], fallback: ''),
      lastName: coalesceText([map['lastName'], map['soyisim']], fallback: ''),
      avatarUrl: coalesceText([
        map['avatarUrl'],
        map['resim'],
        map['photo'],
      ], fallback: ''),
      graduationYear: asInt(map['graduationYear']),
    );
  }
}

class AlbumPhotoDetail {
  const AlbumPhotoDetail({
    required this.id,
    required this.categoryId,
    required this.fileName,
    required this.title,
    required this.description,
    required this.date,
    required this.updatedAt,
    required this.categoryTitle,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.allowComments,
    required this.uploadedByUserId,
    required this.canEditPhoto,
    required this.canToggleComments,
    required this.canBulkDeleteComments,
    required this.taggedUsers,
    required this.editMetadata,
    required this.editSourceFileName,
    required this.media,
    this.groupKey = '',
    this.groupCount = 1,
    this.groupIndex = 0,
    this.groupPhotos = const <AlbumPhotoGroupItem>[],
  });

  final int id;
  final int categoryId;
  final String fileName;
  final String title;
  final String description;
  final String date;
  final String updatedAt;
  final String categoryTitle;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool allowComments;
  final int? uploadedByUserId;
  final bool canEditPhoto;
  final bool canToggleComments;
  final bool canBulkDeleteComments;
  final List<AlbumTaggedMember> taggedUsers;
  final JsonMap editMetadata;
  final String editSourceFileName;
  final AlbumPhotoMedia media;
  final String groupKey;
  final int groupCount;
  final int groupIndex;
  final List<AlbumPhotoGroupItem> groupPhotos;

  factory AlbumPhotoDetail.fromPayload(JsonMap payload) {
    final row = asJsonMap(payload['row']);
    final category = asJsonMap(payload['category']);
    final permissions = asJsonMap(payload['permissions']);
    final fileName = coalesceText([row['dosyaadi']], fallback: '');
    final media = AlbumPhotoMedia.fromMap(
      asJsonMap(row['media']),
      fallbackFileName: fileName,
    );
    return AlbumPhotoDetail(
      id: asInt(row['id']) ?? 0,
      categoryId: asInt(row['katid']) ?? 0,
      fileName: fileName,
      title: coalesceText([row['baslik']], fallback: 'Fotoğraf'),
      description: coalesceText([row['aciklama']], fallback: ''),
      date: coalesceText([row['tarih']], fallback: ''),
      updatedAt: coalesceText([row['updatedAt']], fallback: ''),
      categoryTitle: coalesceText([
        category['kategori'],
        category['title'],
      ], fallback: ''),
      viewCount: asInt(row['hit']) ?? 0,
      likeCount: asInt(row['likeCount']) ?? 0,
      commentCount: asInt(row['commentCount']) ?? 0,
      liked: asBool(row['liked']) ?? false,
      allowComments: asBool(row['allowComments']) ?? true,
      uploadedByUserId: asInt(row['ekleyenid']),
      canEditPhoto: asBool(permissions['canEditPhoto']) ?? false,
      canToggleComments: asBool(permissions['canToggleComments']) ?? false,
      canBulkDeleteComments:
          asBool(permissions['canBulkDeleteComments']) ?? false,
      taggedUsers: asJsonMapList(
        payload['taggedUsers'],
      ).map(AlbumTaggedMember.fromMap).toList(growable: false),
      editMetadata: asJsonMap(payload['editMetadata']).isNotEmpty
          ? asJsonMap(payload['editMetadata'])
          : media.editMetadata,
      editSourceFileName: coalesceText([
        payload['editSourceFileName'],
        media.sourceFileName,
      ], fallback: ''),
      media: media,
      groupKey: coalesceText([
        row['groupKey'],
        row['album_group_key'],
      ], fallback: ''),
      groupCount: asInt(row['groupCount']) ?? 1,
      groupIndex: asInt(row['groupIndex']) ?? 0,
      groupPhotos: asJsonMapList(
        payload['groupPhotos'],
      ).map(AlbumPhotoGroupItem.fromMap).toList(growable: false),
    );
  }
}

class AlbumCategoryDetail {
  const AlbumCategoryDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.photos,
    required this.page,
    required this.pages,
    required this.total,
    required this.visibilityScope,
    required this.cohortYear,
    required this.albumType,
    this.coverMode = 'latest',
    this.coverFileName = '',
    this.allowedMembers = const <MemberSummary>[],
    this.allowedGroups = const <GroupListItem>[],
    required this.canUpload,
    required this.canEdit,
  });

  final int id;
  final String title;
  final String description;
  final List<AlbumPhotoCard> photos;
  final int page;
  final int pages;
  final int total;
  final String visibilityScope;
  final String cohortYear;
  final String albumType;
  final String coverMode;
  final String coverFileName;
  final List<MemberSummary> allowedMembers;
  final List<GroupListItem> allowedGroups;
  final bool canUpload;
  final bool canEdit;

  bool get hasMore => page < pages;

  factory AlbumCategoryDetail.fromPayload(JsonMap payload) {
    final category = asJsonMap(payload['category']);
    return AlbumCategoryDetail(
      id: asInt(category['id']) ?? 0,
      title: coalesceText([
        category['kategori'],
        category['title'],
      ], fallback: 'Albüm'),
      description: coalesceText([
        category['aciklama'],
        category['description'],
      ], fallback: ''),
      photos: asJsonMapList(
        payload['photos'],
      ).map(AlbumPhotoCard.fromMap).toList(growable: false),
      page: asInt(payload['page']) ?? 1,
      pages: asInt(payload['pages']) ?? 1,
      total: asInt(payload['total']) ?? 0,
      visibilityScope: coalesceText([
        category['visibilityScope'],
        category['visibility_scope'],
      ], fallback: 'public'),
      cohortYear: coalesceText([
        category['cohortYear'],
        category['cohort_year'],
      ], fallback: ''),
      albumType: coalesceText([
        category['albumType'],
        category['album_type'],
      ], fallback: 'general'),
      coverMode: coalesceText([
        category['coverMode'],
        category['cover_mode'],
      ], fallback: 'latest'),
      coverFileName: coalesceText([
        category['coverFileName'],
        category['cover_file_name'],
      ], fallback: ''),
      allowedMembers: asJsonMapList(
        payload['allowedMembers'],
      ).map(MemberSummary.fromMap).toList(growable: false),
      allowedGroups: asJsonMapList(
        payload['allowedGroups'],
      ).map(GroupListItem.fromMap).toList(growable: false),
      canUpload: asBool(category['canUpload']) ?? false,
      canEdit: asBool(category['canEdit']) ?? false,
    );
  }
}

class AlbumsDashboardData {
  const AlbumsDashboardData({
    required this.categories,
    required this.latest,
    required this.popular,
    required this.mine,
    required this.canCreateAlbum,
    required this.canManageCategories,
  });

  final List<AlbumCategoryItem> categories;
  final List<AlbumPhotoCard> latest;
  final List<AlbumPhotoCard> popular;
  final List<AlbumCategoryItem> mine;
  final bool canCreateAlbum;
  final bool canManageCategories;

  factory AlbumsDashboardData.fromPayload(JsonMap payload) {
    final permissions = asJsonMap(payload['permissions']);
    return AlbumsDashboardData(
      categories: asJsonMapList(
        payload['categories'] ?? payload['items'],
      ).map(AlbumCategoryItem.fromMap).toList(growable: false),
      latest: asJsonMapList(
        payload['latest'],
      ).map(AlbumPhotoCard.fromMap).toList(growable: false),
      popular: asJsonMapList(
        payload['popular'],
      ).map(AlbumPhotoCard.fromMap).toList(growable: false),
      mine: asJsonMapList(
        payload['mine'],
      ).map(AlbumCategoryItem.fromMap).toList(growable: false),
      canCreateAlbum: asBool(permissions['canCreateAlbum']) ?? false,
      canManageCategories: asBool(permissions['canManageCategories']) ?? false,
    );
  }
}

class AlbumsRepository {
  const AlbumsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AlbumsDashboardData> fetchDashboard() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/albums',
      decoder: asJsonMap,
    );
    return AlbumsDashboardData.fromPayload(asJsonMap(result.rawData));
  }

  Future<List<AlbumCategoryItem>> fetchUploadCategories() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/album/categories/active',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['categories'],
    ).map(AlbumCategoryItem.fromMap).toList(growable: false);
  }

  Future<AlbumCategoryDetail> fetchCategoryDetail(
    int categoryId, {
    int page = 1,
    int pageSize = 24,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/albums/$categoryId',
      query: {'page': page, 'pageSize': pageSize},
      decoder: asJsonMap,
    );
    return AlbumCategoryDetail.fromPayload(asJsonMap(result.rawData));
  }

  Future<AlbumPhotoDetail> fetchPhotoDetail(int photoId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/photos/$photoId',
      decoder: asJsonMap,
    );
    return AlbumPhotoDetail.fromPayload(asJsonMap(result.rawData));
  }

  Future<(List<AlbumComment> comments, bool hidden)> fetchComments(
    int photoId,
  ) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/photos/$photoId/comments',
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return (
      asJsonMapList(
        payload['comments'],
      ).map(AlbumComment.fromMap).toList(growable: false),
      asBool(payload['hidden']) ?? false,
    );
  }

  Future<ApiResult<dynamic>> addComment({
    required int photoId,
    required String comment,
  }) {
    return _apiClient.post<dynamic>(
      '/api/photos/$photoId/comments',
      body: {'yorum': comment},
    );
  }

  Future<ApiResult<dynamic>> editComment({
    required int photoId,
    required int commentId,
    required String comment,
  }) {
    return _apiClient.patch<dynamic>(
      '/api/photos/$photoId/comments/$commentId',
      body: {'yorum': comment},
    );
  }

  Future<ApiResult<dynamic>> deleteComment({
    required int photoId,
    required int commentId,
  }) {
    return _apiClient.delete<dynamic>(
      '/api/photos/$photoId/comments/$commentId',
    );
  }

  Future<ApiResult<dynamic>> deleteAllComments(int photoId) {
    return _apiClient.delete<dynamic>('/api/photos/$photoId/comments');
  }

  Future<ApiResult<dynamic>> toggleLike(int photoId) {
    return _apiClient.post<dynamic>('/api/photos/$photoId/like');
  }

  Future<List<AlbumLikeUser>> fetchLikes(int photoId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/photos/$photoId/likes',
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return asJsonMapList(
      payload['items'],
    ).map(AlbumLikeUser.fromMap).toList(growable: false);
  }

  Future<ApiResult<dynamic>> replacePhotoFile({
    required int photoId,
    required File file,
    File? sourceFile,
    JsonMap editMetadata = const <String, dynamic>{},
    int? albumGroupIndex,
  }) {
    final files = <String, File>{'file': file};
    if (sourceFile != null) {
      files['sourceFile'] = sourceFile;
    }
    return _apiClient.multipart<dynamic>(
      '/api/photos/$photoId/file',
      method: 'PUT',
      fields: {
        if (editMetadata.isNotEmpty) 'editMetadata': editMetadata,
        'albumGroupIndex': ?albumGroupIndex,
      },
      files: files,
    );
  }

  Future<ApiResult<dynamic>> deletePhoto(int photoId) {
    return _apiClient.delete<dynamic>('/api/photos/$photoId');
  }

  Future<ApiResult<dynamic>> uploadPhoto({
    required int categoryId,
    required String title,
    required String description,
    required File file,
    File? sourceFile,
    required bool allowComments,
    List<int> taggedUserIds = const <int>[],
    JsonMap editMetadata = const <String, dynamic>{},
    String albumGroupKey = '',
    int albumGroupIndex = 0,
  }) {
    final files = <String, File>{'file': file};
    if (sourceFile != null) {
      files['sourceFile'] = sourceFile;
    }
    return _apiClient.multipart<dynamic>(
      '/api/album/upload',
      fields: {
        'kat': categoryId.toString(),
        'categoryId': categoryId.toString(),
        'albumId': categoryId.toString(),
        'baslik': title,
        'aciklama': description,
        'yorumlaraIzin': allowComments ? '1' : '0',
        'taggedUserIds': taggedUserIds.join(','),
        if (albumGroupKey.trim().isNotEmpty)
          'albumGroupKey': albumGroupKey.trim(),
        if (albumGroupKey.trim().isNotEmpty)
          'albumGroupIndex': albumGroupIndex.toString(),
        if (editMetadata.isNotEmpty) 'editMetadata': editMetadata,
      },
      files: files,
    );
  }

  Future<ApiResult<dynamic>> uploadPhotosBatch({
    required int categoryId,
    required String description,
    required bool allowComments,
    required List<File> files,
    List<File> sourceFiles = const <File>[],
    required List<String> titles,
    List<int> taggedUserIds = const <int>[],
    List<JsonMap> metadataList = const <JsonMap>[],
  }) {
    return _apiClient.multipart<dynamic>(
      '/api/album/upload-batch',
      fields: {
        'kat': categoryId.toString(),
        'categoryId': categoryId.toString(),
        'albumId': categoryId.toString(),
        'aciklama': description,
        'yorumlaraIzin': allowComments ? '1' : '0',
        'taggedUserIds': taggedUserIds.join(','),
        'titles': titles,
        'metadataList': metadataList,
      },
      files: const <String, File>{},
      extraFiles: {
        'files': files,
        if (sourceFiles.isNotEmpty) 'sourceFiles': sourceFiles,
      },
    );
  }

  Future<ApiResult<dynamic>> updatePhoto({
    required int photoId,
    required String title,
    required String description,
    required bool allowComments,
    List<int> taggedUserIds = const <int>[],
    JsonMap editMetadata = const <String, dynamic>{},
  }) {
    return _apiClient.patch<dynamic>(
      '/api/photos/$photoId',
      body: {
        'baslik': title,
        'aciklama': description,
        'yorumlaraIzin': allowComments,
        'taggedUserIds': taggedUserIds,
        if (editMetadata.isNotEmpty) 'editMetadata': editMetadata,
      },
    );
  }

  Future<ApiResult<dynamic>> createAlbum({
    required String title,
    required String description,
    required String visibilityScope,
    bool isProfileAlbum = false,
    String cohortYear = '',
    List<int> allowedUserIds = const <int>[],
    List<int> allowedGroupIds = const <int>[],
  }) {
    return _apiClient.post<dynamic>(
      '/api/albums',
      body: {
        'title': title,
        'description': description,
        'visibilityScope': visibilityScope,
        'isProfileAlbum': isProfileAlbum,
        if (cohortYear.trim().isNotEmpty) 'cohortYear': cohortYear.trim(),
        if (allowedUserIds.isNotEmpty) 'allowedUserIds': allowedUserIds,
        if (allowedGroupIds.isNotEmpty) 'allowedGroupIds': allowedGroupIds,
      },
    );
  }

  Future<ApiResult<dynamic>> updateAlbum({
    required int categoryId,
    required String title,
    required String description,
    required String visibilityScope,
    String cohortYear = '',
    String coverMode = 'latest',
    int? coverPhotoId,
    List<int> allowedUserIds = const <int>[],
    List<int> allowedGroupIds = const <int>[],
  }) {
    return _apiClient.put<dynamic>(
      '/api/albums/$categoryId',
      body: {
        'title': title,
        'description': description,
        'visibilityScope': visibilityScope,
        'cohortYear': cohortYear.trim(),
        'coverMode': coverMode,
        if (coverPhotoId != null && coverPhotoId > 0)
          'coverPhotoId': coverPhotoId,
        'allowedUserIds': allowedUserIds,
        'allowedGroupIds': allowedGroupIds,
      },
    );
  }

  Future<ApiResult<dynamic>> deleteAlbum(int categoryId) {
    return _apiClient.delete<dynamic>('/api/albums/$categoryId');
  }
}

final albumsRepositoryProvider = Provider<AlbumsRepository>(
  (ref) => AlbumsRepository(ref.watch(apiClientProvider)),
);

final albumsDashboardProvider = FutureProvider.autoDispose<AlbumsDashboardData>(
  (ref) => ref.watch(albumsRepositoryProvider).fetchDashboard(),
);

final myAlbumsProvider = FutureProvider.autoDispose<List<AlbumCategoryItem>>((
  ref,
) async {
  final dashboard = await ref.watch(albumsRepositoryProvider).fetchDashboard();
  return dashboard.mine
      .where((item) => item.isProfileAlbum)
      .toList(growable: false);
});

final memberProfileAlbumsProvider = FutureProvider.autoDispose
    .family<List<AlbumCategoryItem>, int>((ref, memberId) async {
      final dashboard = await ref
          .watch(albumsRepositoryProvider)
          .fetchDashboard();
      final seen = <int>{};
      final candidates = <AlbumCategoryItem>[
        ...dashboard.categories,
        ...dashboard.mine,
      ];
      return candidates
          .where((item) {
            if (item.id <= 0 || !seen.add(item.id)) return false;
            return item.isProfileAlbum && item.ownerUserId == memberId;
          })
          .toList(growable: false);
    });

final albumPhotoLikesProvider = FutureProvider.autoDispose
    .family<List<AlbumLikeUser>, int>(
      (ref, photoId) => ref.watch(albumsRepositoryProvider).fetchLikes(photoId),
    );
