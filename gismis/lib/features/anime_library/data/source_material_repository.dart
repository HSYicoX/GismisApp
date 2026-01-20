/// Source Material Repository for Supabase PostgREST queries.
///
/// This repository handles public read operations for source material
/// (novels, manga, etc.) using PostgREST direct queries with RLS public access.
library;

import '../../../core/supabase/paginated_result.dart';
import '../../../core/supabase/supabase_client.dart';
import 'models/models.dart';

/// Repository for source material data operations via Supabase.
///
/// Access mode: PostgREST direct connection (public read-only, RLS allows)
///
/// Features:
/// - Source material queries by anime
/// - Chapter list queries with pagination
/// - Nested queries (source material with chapters)
class SourceMaterialRepository {
  SourceMaterialRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Fetches the source material for a specific anime.
  ///
  /// Parameters:
  /// - [animeId]: The anime UUID
  ///
  /// Returns the source material or null if not found.
  Future<SourceMaterial?> getSourceMaterial(String animeId) async {
    final result = await _client.query<SourceMaterial>(
      table: 'source_materials',
      fromJson: SourceMaterial.fromJson,
      filters: {'anime_id': 'eq.$animeId'},
      limit: 1,
      countTotal: false,
    );

    return result.items.isNotEmpty ? result.items.first : null;
  }

  /// Fetches the source material by ID with full details.
  ///
  /// Parameters:
  /// - [id]: The source material UUID
  ///
  /// Returns the source material or throws if not found.
  Future<SourceMaterial> getSourceMaterialById(String id) async {
    return _client.querySingle<SourceMaterial>(
      table: 'source_materials',
      fromJson: SourceMaterial.fromJson,
      filters: {'id': 'eq.$id'},
    );
  }

  /// Fetches paginated chapters for a source material.
  ///
  /// Parameters:
  /// - [sourceMaterialId]: The source material UUID
  /// - [page]: Page number (1-indexed)
  /// - [pageSize]: Number of items per page (default: 50)
  ///
  /// Returns a [PaginatedResult] containing chapters and pagination metadata.
  Future<PaginatedResult<Chapter>> getChapters({
    required String sourceMaterialId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final offset = (page - 1) * pageSize;

    return _client.query<Chapter>(
      table: 'chapters',
      fromJson: Chapter.fromJson,
      filters: {'source_material_id': 'eq.$sourceMaterialId'},
      order: 'chapter_number.asc',
      limit: pageSize,
      offset: offset,
    );
  }

  /// Fetches all chapters for a source material (no pagination).
  ///
  /// Use with caution for source materials with many chapters.
  ///
  /// Parameters:
  /// - [sourceMaterialId]: The source material UUID
  ///
  /// Returns a list of all chapters ordered by chapter number.
  Future<List<Chapter>> getAllChapters(String sourceMaterialId) async {
    final result = await _client.query<Chapter>(
      table: 'chapters',
      fromJson: Chapter.fromJson,
      filters: {'source_material_id': 'eq.$sourceMaterialId'},
      order: 'chapter_number.asc',
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches source material with nested chapters.
  ///
  /// This uses PostgREST's nested query feature to fetch source material
  /// along with its chapters in a single request.
  ///
  /// Parameters:
  /// - [animeId]: The anime UUID
  /// - [chapterLimit]: Maximum number of chapters to include (default: 20)
  ///
  /// Returns the source material with chapters populated or null if not found.
  Future<SourceMaterial?> getSourceMaterialWithChapters(
    String animeId, {
    int chapterLimit = 20,
  }) async {
    final result = await _client.query<SourceMaterial>(
      table: 'source_materials',
      fromJson: SourceMaterial.fromJson,
      select:
          '*,chapters(*)&chapters.order=chapter_number.desc&chapters.limit=$chapterLimit',
      filters: {'anime_id': 'eq.$animeId'},
      limit: 1,
      countTotal: false,
    );

    return result.items.isNotEmpty ? result.items.first : null;
  }

  /// Fetches the latest chapters across all source materials.
  ///
  /// Returns chapters that have been recently published.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of chapters to return (default: 20)
  ///
  /// Returns a list of recent chapters.
  Future<List<Chapter>> getLatestChapters({int limit = 20}) async {
    final result = await _client.query<Chapter>(
      table: 'chapters',
      fromJson: Chapter.fromJson,
      filters: {'publish_date': 'not.is.null'},
      order: 'publish_date.desc',
      limit: limit,
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches a single chapter by ID.
  ///
  /// Parameters:
  /// - [id]: The chapter UUID
  ///
  /// Returns the chapter or throws if not found.
  Future<Chapter> getChapterById(String id) async {
    return _client.querySingle<Chapter>(
      table: 'chapters',
      fromJson: Chapter.fromJson,
      filters: {'id': 'eq.$id'},
    );
  }

  /// Fetches source materials by type.
  ///
  /// Parameters:
  /// - [type]: The source material type (novel, manga, game, original)
  /// - [limit]: Maximum number of results (default: 20)
  ///
  /// Returns a list of source materials of the specified type.
  Future<List<SourceMaterial>> getSourceMaterialsByType(
    SourceMaterialType type, {
    int limit = 20,
  }) async {
    final result = await _client.query<SourceMaterial>(
      table: 'source_materials',
      fromJson: SourceMaterial.fromJson,
      filters: {'type': 'eq.${type.value}'},
      order: 'last_updated.desc.nullslast',
      limit: limit,
      countTotal: false,
    );

    return result.items;
  }
}
