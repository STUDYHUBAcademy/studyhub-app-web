import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/app_settings_remote_datasource.dart';
import '../../data/repositories/app_settings_repository_impl.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

final appSettingsRemoteDatasourceProvider =
    Provider<AppSettingsRemoteDatasource>((ref) {
      return AppSettingsRemoteDatasource(AppSupabase.client);
    });

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepositoryImpl(
    ref.watch(appSettingsRemoteDatasourceProvider),
  );
});

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchSettings();
});
