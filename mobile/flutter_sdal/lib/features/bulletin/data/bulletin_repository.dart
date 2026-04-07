import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class BulletinCategoryOption {
  const BulletinCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

class BulletinAuthor {
  const BulletinAuthor({
    required this.id,
    required this.handle,
    required this.photo,
  });

  final int id;
  final String handle;
  final String photo;

  String get displayName => handle.isNotEmpty ? '@$handle' : 'SDAL Üyesi';

  factory BulletinAuthor.fromMap(JsonMap map) {
    final normalized = normalizeJsonAliases(map, {
      'handle': ['kadi', 'username'],
      'photo': ['resim'],
    });
    return BulletinAuthor(
      id: asInt(normalized['id']) ?? 0,
      handle: coalesceText([normalized['handle']], fallback: ''),
      photo: coalesceText([normalized['photo']], fallback: ''),
    );
  }
}

class BulletinMessage {
  const BulletinMessage({
    required this.id,
    required this.bodyHtml,
    required this.createdAt,
    required this.author,
    required this.isNew,
  });

  final int id;
  final String bodyHtml;
  final DateTime? createdAt;
  final BulletinAuthor author;
  final bool isNew;

  factory BulletinMessage.fromMap(JsonMap map) {
    return BulletinMessage(
      id: asInt(map['id']) ?? 0,
      bodyHtml: coalesceText([map['mesajHtml'], map['mesaj']], fallback: ''),
      createdAt: asDateTime(map['tarih']),
      author: BulletinAuthor.fromMap(asJsonMap(map['user'])),
      isNew: asBool(map['isNew']) ?? false,
    );
  }
}

class BulletinPageData {
  const BulletinPageData({
    required this.categoryId,
    required this.categoryName,
    required this.gradCategory,
    required this.messages,
    required this.page,
    required this.pages,
    required this.canDelete,
  });

  final int categoryId;
  final String categoryName;
  final BulletinCategoryOption? gradCategory;
  final List<BulletinMessage> messages;
  final int page;
  final int pages;
  final bool canDelete;

  bool get hasMore => page < pages;

  factory BulletinPageData.fromMap(JsonMap map) {
    final gradCategoryMap = asJsonMap(map['gradCategory']);
    return BulletinPageData(
      categoryId: asInt(map['categoryId']) ?? 0,
      categoryName: coalesceText([map['categoryName']], fallback: 'Genel'),
      gradCategory: gradCategoryMap.isEmpty
          ? null
          : BulletinCategoryOption(
              id: asInt(gradCategoryMap['id']) ?? 0,
              name: coalesceText([
                gradCategoryMap['kategoriadi'],
                gradCategoryMap['name'],
              ], fallback: ''),
            ),
      messages: asJsonMapList(
        map['messages'],
      ).map(BulletinMessage.fromMap).toList(growable: false),
      page: asInt(map['page']) ?? 1,
      pages: asInt(map['pages']) ?? 1,
      canDelete: asBool(map['canDelete']) ?? false,
    );
  }
}

class BulletinRepository {
  const BulletinRepository(this._apiClient);

  final dynamic _apiClient;

  Future<BulletinPageData> fetchBoard({
    required int categoryId,
    int page = 1,
  }) async {
    final result = await _apiClient.get<JsonMap>(
      '/api/panolar',
      query: {'mkatid': categoryId, 'page': page < 1 ? 1 : page},
      decoder: (raw) => asJsonMap(raw),
    );
    return BulletinPageData.fromMap(asJsonMap(result.rawData));
  }

  Future<ApiResult<dynamic>> createMessage({
    required int categoryId,
    required String message,
  }) {
    return _apiClient.post<dynamic>(
      '/api/panolar',
      body: {'katid': categoryId, 'mesaj': message},
    );
  }

  Future<ApiResult<dynamic>> deleteMessage(int messageId) {
    return _apiClient.delete<dynamic>('/api/panolar/$messageId');
  }
}

final bulletinRepositoryProvider = Provider<BulletinRepository>(
  (ref) => BulletinRepository(ref.watch(apiClientProvider)),
);
