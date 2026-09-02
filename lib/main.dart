import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'features/access/access_models.dart';
import 'features/access/access_repository.dart';
import 'features/auth/auth_service.dart';
import 'features/business/business_profile.dart';
import 'features/business/business_profile_service.dart';
import 'features/stalls/stall.dart';
import 'features/stalls/stall_service.dart';
import 'features/staff/staff_models.dart';
import 'features/staff/staff_service.dart';
import 'features/menu/menu_models.dart';
import 'features/menu/menu_service.dart';
import 'features/tables/dining_table.dart';
import 'features/tables/table_service.dart';
import 'features/qr/qr_service.dart';
import 'features/qr/qr_token.dart';
import 'features/kitchen/kitchen_order.dart';
import 'features/kitchen/kitchen_service.dart';
import 'features/payments/razorpay_checkout.dart';

part 'core/router/app_router.dart';
part 'core/widgets/shared_widgets.dart';
part 'features/access/business_selector.dart';
part 'features/auth/auth_pages.dart';
part 'features/business/business_pages.dart';
part 'features/business/business_profile_page.dart';
part 'features/staff/staff_pages.dart';
part 'features/staff/staff_management_page.dart';
part 'features/stalls/dashboard_page.dart';
part 'features/stalls/stall_management_page.dart';
part 'features/menu/menu_management_page.dart';
part 'features/tables/table_management_page.dart';
part 'features/qr/qr_management_page.dart';
part 'features/kitchen/kitchen_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initializationError;
  if (AppConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
        // Supabase Flutter owns the one-time web callback exchange and the
        // existing mobile deep-link handling. The router only reacts to the
        // resulting auth state.
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: true,
        ),
      );
    } catch (_) {
      initializationError =
          'We could not connect to ServeFlow. Please try again later.';
    }
  } else {
    initializationError = 'Supabase configuration is missing. Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.';
  }
  runApp(ServeFlowApp(initializationError: initializationError));
}
