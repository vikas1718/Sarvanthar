import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_models.dart';

class MenuService {
  const MenuService(this.c);
  final SupabaseClient c;
  Future<List<MenuCategory>> categories(String b, String? s) async {
    var q = c
        .from('menu_categories')
        .select('id,name,sort_order')
        .eq('business_id', b)
        .isFilter('archived_at', null);
    q = s == null ? q.isFilter('stall_id', null) : q.eq('stall_id', s);
    return List<Map<String, dynamic>>.from(await q.order('sort_order'))
        .map(MenuCategory.fromJson)
        .toList();
  }

  Future<List<MenuItem>> items(String b, String? s) async {
    var q = c
        .from('menu_items')
        .select('id,category_id,name,description,price,image_path,is_available')
        .eq('business_id', b)
        .isFilter('archived_at', null);
    q = s == null ? q.isFilter('stall_id', null) : q.eq('stall_id', s);
    return List<Map<String, dynamic>>.from(await q.order('sort_order'))
        .map(MenuItem.fromJson)
        .toList();
  }

  Future<void> createCategory(String b, String? s, String n) => c.rpc(
    'create_menu_category',
    params: {
      'p_business_id': b,
      'p_stall_id': s,
      'p_name': n,
      'p_sort_order': 0,
    },
  );
  Future<void> editCategory(MenuCategory x, String n, int order) => c.rpc(
    'update_menu_category',
    params: {'p_category_id': x.id, 'p_name': n, 'p_sort_order': order},
  );
  Future<void> archiveCategory(String id) =>
      c.rpc('archive_menu_category', params: {'p_category_id': id});
  Future<void> saveItem({
    MenuItem? item,
    required String b,
    required String? s,
    required String category,
    required String name,
    required String description,
    required double price,
    String? image,
  }) => item == null
      ? c.rpc(
          'create_menu_item',
          params: {
            'p_business_id': b,
            'p_stall_id': s,
            'p_category_id': category,
            'p_name': name,
            'p_description': description,
            'p_price': price,
            'p_image_path': image,
            'p_sort_order': 0,
          },
        )
      : c.rpc(
          'update_menu_item',
          params: {
            'p_item_id': item.id,
            'p_category_id': category,
            'p_name': name,
            'p_description': description,
            'p_price': price,
            'p_image_path': image,
            'p_sort_order': 0,
          },
        );
  Future<void> archiveItem(String id) =>
      c.rpc('archive_menu_item', params: {'p_item_id': id});
  Future<void> availability(String id, bool v) => c.rpc(
    'set_menu_item_availability',
    params: {'p_item_id': id, 'p_is_available': v},
  );
  Future<String> upload(
    String b,
    String? s,
    String ext,
    Uint8List bytes,
  ) async {
    final path =
        '$b/${s ?? 'business'}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await c.storage
        .from('menu-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    return path;
  }

  Future<List<MenuOptionGroup>> groups(String item) async =>
      List<Map<String, dynamic>>.from(
        await c
            .from('menu_option_groups')
            .select('id,name,type')
            .eq('menu_item_id', item)
            .isFilter('archived_at', null),
      ).map(MenuOptionGroup.fromJson).toList();
  Future<void> createGroup(String item, String name, String type) => c.rpc(
    'create_menu_option_group',
    params: {
      'p_item_id': item,
      'p_name': name,
      'p_type': type,
      'p_min_select': type == 'variant' ? 1 : 0,
      'p_max_select': type == 'variant' ? 1 : 10,
      'p_sort_order': 0,
    },
  );
  Future<void> archiveGroup(String id) =>
      c.rpc('archive_menu_option_group', params: {'p_group_id': id});
  Future<void> createOption(String group, String name, double delta) => c.rpc(
    'create_menu_option',
    params: {
      'p_group_id': group,
      'p_name': name,
      'p_price_delta': delta,
      'p_sort_order': 0,
    },
  );
}
