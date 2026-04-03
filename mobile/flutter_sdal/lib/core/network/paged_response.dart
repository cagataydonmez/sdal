import 'json_utils.dart';

class PagedResponse<T> {
  const PagedResponse({
    required this.items,
    required this.hasMore,
    this.limit,
    this.offset,
    this.page,
    this.pages,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final int? limit;
  final int? offset;
  final int? page;
  final int? pages;
  final String? nextCursor;

  factory PagedResponse.fromDynamic(
    dynamic raw,
    T Function(JsonMap map) decoder,
  ) {
    final map = asJsonMap(raw);
    final rawItems = map['items'] ?? map['rows'] ?? const <dynamic>[];
    return PagedResponse<T>(
      items: asJsonMapList(rawItems).map(decoder).toList(growable: false),
      hasMore: asBool(map['hasMore']) ?? false,
      limit: asInt(map['limit']),
      offset: asInt(map['offset']),
      page: asInt(map['page']),
      pages: asInt(map['pages']),
      nextCursor: asString(map['next_cursor']) ?? asString(map['nextCursor']),
    );
  }
}
