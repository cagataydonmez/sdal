import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class AlbumCategoryItem {
  const AlbumCategoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.count,
    required this.previews,
  });

  final int id;
  final String title;
  final String description;
  final int count;
  final List<String> previews;

  factory AlbumCategoryItem.fromMap(JsonMap map) {
    return AlbumCategoryItem(
      id: asInt(map['id']) ?? 0,
      title: coalesceText([map['kategori']], fallback: 'Albüm'),
      description: coalesceText([map['aciklama']], fallback: ''),
      count: asInt(map['count']) ?? 0,
      previews: (map['previews'] is List)
          ? (map['previews'] as List)
                .map((item) => coalesceText([item], fallback: ''))
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

class AlbumLatestPhoto {
  const AlbumLatestPhoto({
    required this.id,
    required this.categoryId,
    required this.fileName,
    required this.date,
    required this.categoryTitle,
  });

  final int id;
  final int categoryId;
  final String fileName;
  final String date;
  final String categoryTitle;

  factory AlbumLatestPhoto.fromMap(JsonMap map) {
    return AlbumLatestPhoto(
      id: asInt(map['id']) ?? 0,
      categoryId: asInt(map['katid']) ?? 0,
      fileName: coalesceText([map['dosyaadi']], fallback: ''),
      date: coalesceText([map['tarih']], fallback: ''),
      categoryTitle: coalesceText([map['kategori']], fallback: ''),
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
  });

  final int id;
  final String title;
  final String description;
  final List<AlbumPhotoSummary> photos;
  final int page;
  final int pages;

  bool get hasMore => page < pages;
}

class AlbumPhotoSummary {
  const AlbumPhotoSummary({
    required this.id,
    required this.fileName,
    required this.title,
    required this.date,
  });

  final int id;
  final String fileName;
  final String title;
  final String date;

  factory AlbumPhotoSummary.fromMap(JsonMap map) {
    return AlbumPhotoSummary(
      id: asInt(map['id']) ?? 0,
      fileName: coalesceText([map['dosyaadi']], fallback: ''),
      title: coalesceText([map['baslik']], fallback: 'Fotoğraf'),
      date: coalesceText([map['tarih']], fallback: ''),
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
    required this.categoryTitle,
  });

  final int id;
  final int categoryId;
  final String fileName;
  final String title;
  final String description;
  final String date;
  final String categoryTitle;
}

class AlbumComment {
  const AlbumComment({
    required this.id,
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.comment,
    required this.date,
    required this.verified,
    required this.photo,
  });

  final int id;
  final int userId;
  final String handle;
  final String displayName;
  final String comment;
  final String date;
  final bool verified;
  final String photo;

  factory AlbumComment.fromMap(JsonMap map) {
    return AlbumComment(
      id: asInt(map['id']) ?? 0,
      userId: asInt(map['user_id']) ?? 0,
      handle: coalesceText([map['kadi'], map['uyeadi']], fallback: ''),
      displayName: coalesceText([
        '${asString(map['isim']) ?? ''} ${asString(map['soyisim']) ?? ''}'
            .trim(),
        map['kadi'],
        map['uyeadi'],
      ], fallback: 'SDAL Üyesi'),
      comment: coalesceText([map['yorum']], fallback: ''),
      date: coalesceText([map['tarih']], fallback: ''),
      verified: asBool(map['verified']) ?? false,
      photo: coalesceText([map['resim']], fallback: ''),
    );
  }
}

class AlbumsPageData {
  const AlbumsPageData({required this.items, required this.hasMore});

  final List<AlbumLatestPhoto> items;
  final bool hasMore;
}

class AlbumsRepository {
  const AlbumsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AlbumCategoryItem>> fetchCategories() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/albums',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(AlbumCategoryItem.fromMap).toList(growable: false);
  }

  Future<AlbumsPageData> fetchLatest({int limit = 24, int offset = 0}) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/album/latest',
      query: {'limit': limit, 'offset': offset},
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    return AlbumsPageData(
      items: asJsonMapList(
        payload['items'],
      ).map(AlbumLatestPhoto.fromMap).toList(growable: false),
      hasMore: asBool(payload['hasMore']) ?? false,
    );
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
    final payload = asJsonMap(result.rawData);
    final category = asJsonMap(payload['category']);
    return AlbumCategoryDetail(
      id: asInt(category['id']) ?? categoryId,
      title: coalesceText([category['kategori']], fallback: 'Albüm'),
      description: coalesceText([category['aciklama']], fallback: ''),
      photos: asJsonMapList(
        payload['photos'],
      ).map(AlbumPhotoSummary.fromMap).toList(growable: false),
      page: asInt(payload['page']) ?? 1,
      pages: asInt(payload['pages']) ?? 1,
    );
  }

  Future<AlbumPhotoDetail> fetchPhotoDetail(int photoId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/photos/$photoId',
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    final row = asJsonMap(payload['row']);
    final category = asJsonMap(payload['category']);
    return AlbumPhotoDetail(
      id: asInt(row['id']) ?? photoId,
      categoryId: asInt(row['katid']) ?? 0,
      fileName: coalesceText([row['dosyaadi']], fallback: ''),
      title: coalesceText([row['baslik']], fallback: 'Fotoğraf'),
      description: coalesceText([row['aciklama']], fallback: ''),
      date: coalesceText([row['tarih']], fallback: ''),
      categoryTitle: coalesceText([category['kategori']], fallback: ''),
    );
  }

  Future<List<AlbumComment>> fetchComments(int photoId) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/photos/$photoId/comments',
      decoder: asJsonMap,
    );
    final payload = asJsonMap(result.rawData);
    final items = payload['comments'] ?? payload['items'];
    return asJsonMapList(
      items,
    ).map(AlbumComment.fromMap).toList(growable: false);
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

  Future<List<AlbumCategoryItem>> fetchUploadCategories() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/album/categories/active',
      decoder: asJsonMap,
    );
    return asJsonMapList(asJsonMap(result.rawData)['categories'])
        .map(
          (map) => AlbumCategoryItem(
            id: asInt(map['id']) ?? 0,
            title: coalesceText([map['kategori']], fallback: 'Kategori'),
            description: '',
            count: 0,
            previews: const <String>[],
          ),
        )
        .toList(growable: false);
  }

  Future<ApiResult<dynamic>> uploadPhoto({
    required int categoryId,
    required String title,
    required String description,
    required File file,
  }) {
    return _apiClient.multipart<dynamic>(
      '/api/album/upload',
      fields: {'kat': categoryId, 'baslik': title, 'aciklama': description},
      files: {'file': file},
    );
  }
}

final albumsRepositoryProvider = Provider<AlbumsRepository>(
  (ref) => AlbumsRepository(ref.watch(apiClientProvider)),
);
