import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result.dart';
import 'package:flutter_sdal/core/network/api_result_parser.dart';
import 'package:flutter_sdal/features/albums/data/albums_repository.dart';

import '../../test_support/fake_api_client.dart';

void main() {
  group('AlbumsRepository contracts', () {
    test('fetchLatest forwards limit/offset and preserves hasMore', () async {
      final apiClient = _RecordingAlbumsApiClient(
        getRawData: const {
          'items': [
            {
              'id': 91,
              'katid': 3,
              'dosyaadi': 'photo.jpg',
              'tarih': '2026-01-01T12:00:00.000Z',
              'kategori': 'Mezunlar',
            },
          ],
          'hasMore': true,
        },
      );
      final repository = AlbumsRepository(apiClient);

      final page = await repository.fetchLatest(limit: 24, offset: 48);

      expect(apiClient.lastMethod, 'GET');
      expect(apiClient.lastPath, '/api/album/latest');
      expect(apiClient.lastQuery, {'limit': 24, 'offset': 48});
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
    });

    test(
      'fetchCategoryDetail forwards page/pageSize and exposes hasMore',
      () async {
        final apiClient = _RecordingAlbumsApiClient(
          getRawData: const {
            'category': {'id': 7, 'kategori': 'Arşiv', 'aciklama': 'Açıklama'},
            'photos': [
              {
                'id': 201,
                'dosyaadi': 'a.jpg',
                'baslik': 'Fotoğraf A',
                'tarih': '2026-02-01T10:00:00.000Z',
              },
            ],
            'page': 2,
            'pages': 4,
            'total': 80,
            'pageSize': 20,
          },
        );
        final repository = AlbumsRepository(apiClient);

        final detail = await repository.fetchCategoryDetail(
          7,
          page: 2,
          pageSize: 20,
        );

        expect(apiClient.lastMethod, 'GET');
        expect(apiClient.lastPath, '/api/albums/7');
        expect(apiClient.lastQuery, {'page': 2, 'pageSize': 20});
        expect(detail.page, 2);
        expect(detail.pages, 4);
        expect(detail.hasMore, isTrue);
        expect(detail.photos, hasLength(1));
      },
    );
  });
}

class _RecordingAlbumsApiClient extends FakeApiClient {
  _RecordingAlbumsApiClient({this.getRawData = const <String, Object?>{}});

  final dynamic getRawData;

  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query == null ? null : Map<String, dynamic>.from(query);
    return ApiResult<T>(
      ok: true,
      statusCode: 200,
      message: '',
      code: '',
      data: decoder == null ? null : decoder(getRawData),
      rawData: getRawData,
    );
  }
}
