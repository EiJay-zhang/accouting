import '../models/item.dart';
import 'api_client.dart';

class ItemApi {
  ItemApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Item>> fetchItems({String? keyword, ItemStatus? status}) async {
    final query = <String, String>{};
    final trimmed = keyword?.trim() ?? '';
    if (trimmed.isNotEmpty) query['q'] = trimmed;
    if (status != null) query['status'] = status.apiValue;
    final rows = await _client.getJsonList(
      '/api/items',
      query: query.isEmpty ? null : query,
    );
    return rows
        .map((row) => Item.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<ItemSummary> fetchSummary() async {
    return ItemSummary.fromJson(await _client.getJson('/api/items/summary'));
  }

  Future<Item> createItem({
    required String name,
    required int categoryId,
    required double amount,
    required DateTime purchaseDate,
    required String purpose,
    required ItemStatus status,
    double? soldAmount,
    DateTime? soldDate,
    DateTime? warrantyUntil,
    String note = '',
  }) async {
    final row = await _client.postJson(
      '/api/items',
      _body(
        name: name,
        categoryId: categoryId,
        amount: amount,
        purchaseDate: purchaseDate,
        purpose: purpose,
        status: status,
        soldAmount: soldAmount,
        soldDate: soldDate,
        warrantyUntil: warrantyUntil,
        note: note,
      ),
    );
    return Item.fromJson(row);
  }

  Future<Item> updateItem({
    required int id,
    required String name,
    required int categoryId,
    required double amount,
    required DateTime purchaseDate,
    required String purpose,
    required ItemStatus status,
    double? soldAmount,
    DateTime? soldDate,
    DateTime? warrantyUntil,
    String note = '',
  }) async {
    final row = await _client.putJson(
      '/api/items/$id',
      _body(
        name: name,
        categoryId: categoryId,
        amount: amount,
        purchaseDate: purchaseDate,
        purpose: purpose,
        status: status,
        soldAmount: soldAmount,
        soldDate: soldDate,
        warrantyUntil: warrantyUntil,
        note: note,
      ),
    );
    return Item.fromJson(row);
  }

  Future<void> deleteItem(int id) {
    return _client.delete('/api/items/$id');
  }

  Map<String, dynamic> _body({
    required String name,
    required int categoryId,
    required double amount,
    required DateTime purchaseDate,
    required String purpose,
    required ItemStatus status,
    required double? soldAmount,
    required DateTime? soldDate,
    required DateTime? warrantyUntil,
    required String note,
  }) {
    return {
      'name': name,
      'category_id': categoryId,
      'amount': amount,
      'purchase_date': _formatDate(purchaseDate),
      'purpose': purpose,
      'status': status.apiValue,
      'sold_amount': soldAmount,
      'sold_date': soldDate == null ? null : _formatDate(soldDate),
      'warranty_until': warrantyUntil == null
          ? null
          : _formatDate(warrantyUntil),
      'note': note,
    };
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
