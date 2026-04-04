import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/json_utils.dart';

class RequestCategory {
  const RequestCategory({
    required this.categoryKey,
    required this.label,
    required this.description,
  });

  final String categoryKey;
  final String label;
  final String description;

  factory RequestCategory.fromMap(JsonMap map) {
    return RequestCategory(
      categoryKey: coalesceText([map['category_key'], map['categoryKey']]),
      label: coalesceText([map['label']], fallback: 'Talep'),
      description: coalesceText([map['description']], fallback: ''),
    );
  }
}

class RequestAttachment {
  const RequestAttachment({
    required this.name,
    required this.mime,
    required this.size,
    required this.url,
  });

  final String name;
  final String mime;
  final int size;
  final String url;

  factory RequestAttachment.fromMap(JsonMap map) {
    return RequestAttachment(
      name: coalesceText([map['name']], fallback: 'Ek'),
      mime: coalesceText([map['mime']], fallback: ''),
      size: asInt(map['size']) ?? 0,
      url: coalesceText([map['url']], fallback: ''),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'name': name,
    'mime': mime,
    'size': size,
    'url': url,
  };
}

class MemberRequestItem {
  const MemberRequestItem({
    required this.id,
    required this.categoryKey,
    required this.categoryLabel,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.reviewedAt,
    required this.resolutionNote,
  });

  final int id;
  final String categoryKey;
  final String categoryLabel;
  final JsonMap payload;
  final String status;
  final String createdAt;
  final String reviewedAt;
  final String resolutionNote;

  factory MemberRequestItem.fromMap(JsonMap map) {
    return MemberRequestItem(
      id: asInt(map['id']) ?? 0,
      categoryKey: coalesceText([map['category_key']], fallback: ''),
      categoryLabel: coalesceText([
        map['category_label'],
        map['category_key'],
      ], fallback: 'Talep'),
      payload: _decodePayload(map['payload_json']),
      status: coalesceText([map['status']], fallback: 'pending'),
      createdAt: coalesceText([map['created_at']], fallback: ''),
      reviewedAt: coalesceText([map['reviewed_at']], fallback: ''),
      resolutionNote: coalesceText([map['resolution_note']], fallback: ''),
    );
  }
}

class RequestsRepository {
  const RequestsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RequestCategory>> fetchCategories() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/request-categories',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(RequestCategory.fromMap).toList(growable: false);
  }

  Future<List<MemberRequestItem>> fetchMyRequests() async {
    final result = await _apiClient.get<JsonMap>(
      '/api/new/requests/my',
      decoder: asJsonMap,
    );
    return asJsonMapList(
      asJsonMap(result.rawData)['items'],
    ).map(MemberRequestItem.fromMap).toList(growable: false);
  }

  Future<ApiResult<RequestAttachment>> uploadAttachment(File file) async {
    final result = await _apiClient.multipart<JsonMap>(
      '/api/new/requests/upload',
      files: {'file': file},
      decoder: asJsonMap,
    );
    final attachmentMap = asJsonMap(asJsonMap(result.rawData)['attachment']);
    final attachment = attachmentMap.isEmpty
        ? null
        : RequestAttachment.fromMap(attachmentMap);
    return ApiResult<RequestAttachment>(
      ok: result.ok && attachment != null,
      statusCode: result.statusCode,
      message: result.message,
      code: result.code,
      data: attachment,
      rawData: result.rawData,
    );
  }

  Future<ApiResult<dynamic>> createRequest({
    required String categoryKey,
    required JsonMap payload,
  }) {
    return _apiClient.post<dynamic>(
      '/api/new/requests',
      body: {'category_key': categoryKey, 'payload': payload},
    );
  }
}

JsonMap _decodePayload(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const <String, dynamic>{};
    try {
      return asJsonMap(jsonDecode(trimmed));
    } catch (_) {
      return <String, dynamic>{'note': trimmed};
    }
  }
  return asJsonMap(value);
}

final requestsRepositoryProvider = Provider<RequestsRepository>(
  (ref) => RequestsRepository(ref.watch(apiClientProvider)),
);

final requestCategoriesProvider =
    FutureProvider.autoDispose<List<RequestCategory>>(
      (ref) => ref.watch(requestsRepositoryProvider).fetchCategories(),
    );

final myRequestsProvider = FutureProvider.autoDispose<List<MemberRequestItem>>(
  (ref) => ref.watch(requestsRepositoryProvider).fetchMyRequests(),
);
