import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Supabase configuration and connection management
class SupabaseConfig {
  static const String supabaseUrl = 'https://rvfrqptzupzupkiojbcy.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2ZnJxcHR6dXB6dXBraW9qYmN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5OTU2NTksImV4cCI6MjA3OTU3MTY1OX0.pJGFlbSwQyMaqohqW9S0oyopdn-cdF1S0NVh3Gw_-p4';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
      debug: kDebugMode,
    );
    debugPrint('✅ Supabase initialized: $supabaseUrl');
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
}

/// Result wrapper for database operations
class SupabaseResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  SupabaseResult.success(this.data)
      : error = null,
        isSuccess = true;

  SupabaseResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

/// Generic database service for CRUD operations with comprehensive error handling
class SupabaseService {
  /// Select multiple records from a table
  /// Returns SupabaseResult with proper error handling
  static Future<SupabaseResult<List<Map<String, dynamic>>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    debugPrint('📥 Supabase SELECT from "$table"');
    debugPrint('   Filters: $filters');
    debugPrint('   OrderBy: $orderBy');

    try {
      // Build query - use dynamic type for query chaining
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          debugPrint('   Applying filter: ${entry.key} = ${entry.value}');
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Execute query and cast response
      final response = await query as List<dynamic>;
      
      // Convert to List<Map<String, dynamic>>
      final List<Map<String, dynamic>> data = response
          .map((item) => item as Map<String, dynamic>)
          .toList();

      debugPrint('✅ Query successful: ${data.length} records returned');
      debugPrint('   Sample: ${data.isEmpty ? "[]" : data.first}');

      return SupabaseResult.success(data);
    } on PostgrestException catch (e) {
      // RLS or database-level error
      final errorMsg = _parsePostgrestError(e, table);
      debugPrint('❌ PostgrestException: $errorMsg');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Details: ${e.details}');
      debugPrint('   Hint: ${e.hint}');
      return SupabaseResult.failure(errorMsg);
    } catch (e, stackTrace) {
      // Generic error
      final errorMsg = 'Failed to select from $table: ${e.toString()}';
      debugPrint('❌ Unexpected error: $errorMsg');
      debugPrint('   Stack: ${stackTrace.toString()}');
      return SupabaseResult.failure(errorMsg);
    }
  }

  /// Select a single record from a table
  static Future<SupabaseResult<Map<String, dynamic>?>> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    debugPrint('📥 Supabase SELECT SINGLE from "$table"');
    debugPrint('   Filters: $filters');

    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      final response = await query.maybeSingle() as Map<String, dynamic>?;

      debugPrint('✅ Single query successful: ${response != null ? "Found" : "Not found"}');

      return SupabaseResult.success(response);
    } on PostgrestException catch (e) {
      final errorMsg = _parsePostgrestError(e, table);
      debugPrint('❌ PostgrestException: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    } catch (e) {
      final errorMsg = 'Failed to select single from $table: ${e.toString()}';
      debugPrint('❌ Unexpected error: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    }
  }

  /// Insert a record into a table
  static Future<SupabaseResult<List<Map<String, dynamic>>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    debugPrint('📤 Supabase INSERT into "$table"');
    debugPrint('   Data: $data');

    try {
      final response = await SupabaseConfig.client
          .from(table)
          .insert(data)
          .select() as List<dynamic>;

      final List<Map<String, dynamic>> result = response
          .map((item) => item as Map<String, dynamic>)
          .toList();

      debugPrint('✅ Insert successful: ${result.length} records created');

      return SupabaseResult.success(result);
    } on PostgrestException catch (e) {
      final errorMsg = _parsePostgrestError(e, table);
      debugPrint('❌ PostgrestException: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    } catch (e) {
      final errorMsg = 'Failed to insert into $table: ${e.toString()}';
      debugPrint('❌ Unexpected error: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    }
  }

  /// Insert multiple records into a table
  static Future<SupabaseResult<List<Map<String, dynamic>>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    debugPrint('📤 Supabase INSERT MULTIPLE into "$table"');
    debugPrint('   Count: ${data.length}');

    try {
      final response = await SupabaseConfig.client
          .from(table)
          .insert(data)
          .select() as List<dynamic>;

      final List<Map<String, dynamic>> result = response
          .map((item) => item as Map<String, dynamic>)
          .toList();

      debugPrint('✅ Insert multiple successful: ${result.length} records created');

      return SupabaseResult.success(result);
    } on PostgrestException catch (e) {
      final errorMsg = _parsePostgrestError(e, table);
      debugPrint('❌ PostgrestException: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    } catch (e) {
      final errorMsg = 'Failed to insert multiple into $table: ${e.toString()}';
      debugPrint('❌ Unexpected error: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    }
  }

  /// Update records in a table
  static Future<SupabaseResult<List<Map<String, dynamic>>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    debugPrint('🔄 Supabase UPDATE "$table"');
    debugPrint('   Filters: $filters');
    debugPrint('   Data: $data');

    try {
      dynamic query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      final response = await query.select() as List<dynamic>;

      final List<Map<String, dynamic>> result = response
          .map((item) => item as Map<String, dynamic>)
          .toList();

      debugPrint('✅ Update successful: ${result.length} records updated');

      return SupabaseResult.success(result);
    } on PostgrestException catch (e) {
      final errorMsg = _parsePostgrestError(e, table);
      debugPrint('❌ PostgrestException: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    } catch (e) {
      final errorMsg = 'Failed to update $table: ${e.toString()}';
      debugPrint('❌ Unexpected error: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    }
  }

  /// Delete records from a table
  static Future<SupabaseResult<void>> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    debugPrint('🗑️ Supabase DELETE from "$table"');
    debugPrint('   Filters: $filters');

    try {
      dynamic query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;

      debugPrint('✅ Delete successful');

      return SupabaseResult.success(null);
    } on PostgrestException catch (e) {
      final errorMsg = _parsePostgrestError(e, table);
      debugPrint('❌ PostgrestException: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    } catch (e) {
      final errorMsg = 'Failed to delete from $table: ${e.toString()}';
      debugPrint('❌ Unexpected error: $errorMsg');
      return SupabaseResult.failure(errorMsg);
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Parse PostgrestException and provide user-friendly error messages
  static String _parsePostgrestError(PostgrestException error, String table) {
    final code = error.code;
    final message = error.message;

    // RLS policy violation
    if (code == '42501' || message.contains('row-level security') || message.contains('policy')) {
      return 'RLS blocked request: Check policies for "$table" table. Ensure anon role has SELECT permission.';
    }

    // Table doesn't exist
    if (code == '42P01' || message.contains('does not exist')) {
      return 'Table "$table" does not exist. Please run migrations first.';
    }

    // Foreign key violation
    if (code == '23503') {
      return 'Foreign key violation: Referenced record does not exist.';
    }

    // Unique constraint violation
    if (code == '23505') {
      return 'Duplicate record: A record with this value already exists.';
    }

    // Not null violation
    if (code == '23502') {
      return 'Required field missing: ${error.details}';
    }

    // Generic error
    return 'Database error on "$table": $message (Code: $code)';
  }
}
