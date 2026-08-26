import 'package:supabase_flutter/supabase_flutter.dart';

import 'kitchen_order.dart';

class KitchenService {
  const KitchenService(this._client);
  final SupabaseClient _client;

  static const _orderGraph = '''
    id,business_id,stall_id,dining_table_id,scope,status,table_number,stall_name,
    currency,total_amount,created_at,updated_at,
    order_items(id,menu_item_id,item_name,unit_price,options_total,quantity,
      line_total,created_at,order_item_options(id,menu_option_id,option_group_id,
        group_name,option_name,price_delta))
  ''';

  Future<List<KitchenOrder>> loadActiveOrders({
    required String businessId,
    required String? stallId,
  }) async {
    var query = _client
        .from('orders')
        .select(_orderGraph)
        .eq('business_id', businessId)
        .inFilter('status', const ['received', 'preparing', 'ready']);
    if (stallId != null) query = query.eq('stall_id', stallId);
    final rows = await query.order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows)
        .map(KitchenOrder.fromJson)
        .toList();
  }

  Future<void> updateStatus(String orderId, String status) => _client.rpc(
    'update_order_status',
    params: {'p_order_id': orderId, 'p_new_status': status},
  );

  /// `orders` is an invalidation signal. Re-fetch the nested graph on every
  /// event rather than trying to merge incomplete Realtime row payloads.
  RealtimeChannel subscribe({
    required String businessId,
    required void Function() onChange,
  }) => _client
      .channel('kitchen-orders-$businessId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_id',
          value: businessId,
        ),
        callback: (_) => onChange(),
      )
      .subscribe();

  Future<void> unsubscribe(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
