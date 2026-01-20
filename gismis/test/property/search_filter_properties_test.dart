import 'package:glados/glados.dart';

import 'package:gismis/shared/models/anime.dart';
import 'package:gismis/features/home/data/anime_repository.dart';

/// Feature: anime-tracker-app, Property 2: Search Filter Correctness
/// Validates: Requirements 1.3
///
/// For any search query string and list of Anime objects, the filtered results
/// SHALL only contain anime where the title or any alias contains the query
/// string (case-insensitive).

void main() {
  group('Property 2: Search Filter Correctness', () {
    // Helper to create an anime with given title and aliases
    Anime createAnime({
      required String id,
      required String title,
      List<String> aliases = const [],
    }) {
      return Anime(
        id: id,
        title: title,
        titleAlias: aliases,
        coverUrl: 'https://example.com/cover.jpg',
        status: AnimeStatus.ongoing,
        updatedAt: DateTime(2024),
      );
    }

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any query, filtered results only contain anime with matching title or alias',
      (query) {
        // Create a diverse list of anime
        final animes = [
          createAnime(
            id: '1',
            title: 'Attack on Titan',
            aliases: ['Shingeki no Kyojin', 'AOT'],
          ),
          createAnime(id: '2', title: 'One Piece', aliases: ['OP', 'Wan Pisu']),
          createAnime(
            id: '3',
            title: 'Naruto Shippuden',
            aliases: ['Naruto Part 2'],
          ),
          createAnime(
            id: '4',
            title: 'My Hero Academia',
            aliases: ['Boku no Hero Academia', 'MHA'],
          ),
          createAnime(
            id: '5',
            title: 'Demon Slayer',
            aliases: ['Kimetsu no Yaiba'],
          ),
        ];

        final results = filterAnimeByQuery(animes, query);
        final lowerQuery = query.toLowerCase();

        // Property: Every result must have the query in title or alias
        for (final anime in results) {
          final titleMatches = anime.title.toLowerCase().contains(lowerQuery);
          final aliasMatches = anime.titleAlias.any(
            (alias) => alias.toLowerCase().contains(lowerQuery),
          );

          expect(
            titleMatches || aliasMatches,
            isTrue,
            reason:
                'Anime "${anime.title}" should not be in results for query "$query"',
          );
        }
      },
    );

    Glados<String>(
      any.nonEmptyLetterOrDigits,
    ).test('For any query, no matching anime is excluded from results', (
      query,
    ) {
      final animes = [
        createAnime(id: '1', title: 'Sword Art Online', aliases: ['SAO']),
        createAnime(
          id: '2',
          title: 'Fullmetal Alchemist',
          aliases: ['FMA', 'Hagane no Renkinjutsushi'],
        ),
        createAnime(id: '3', title: 'Death Note', aliases: ['DN']),
      ];

      final results = filterAnimeByQuery(animes, query);
      final lowerQuery = query.toLowerCase();

      // Property: Every anime that should match IS in results
      for (final anime in animes) {
        final titleMatches = anime.title.toLowerCase().contains(lowerQuery);
        final aliasMatches = anime.titleAlias.any(
          (alias) => alias.toLowerCase().contains(lowerQuery),
        );

        if (titleMatches || aliasMatches) {
          expect(
            results.any((r) => r.id == anime.id),
            isTrue,
            reason:
                'Anime "${anime.title}" should be in results for query "$query"',
          );
        }
      }
    });

    test('Empty query returns all anime unchanged', () {
      final animes = [
        createAnime(id: '1', title: 'Anime A'),
        createAnime(id: '2', title: 'Anime B'),
        createAnime(id: '3', title: 'Anime C'),
      ];

      final results = filterAnimeByQuery(animes, '');
      expect(results.length, equals(animes.length));
      expect(results, equals(animes));
    });

    test('Whitespace-only query returns all anime unchanged', () {
      final animes = [
        createAnime(id: '1', title: 'Anime A'),
        createAnime(id: '2', title: 'Anime B'),
      ];

      final results = filterAnimeByQuery(animes, '   ');
      expect(results.length, equals(animes.length));
    });

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'Search is case-insensitive for title',
      (title) {
        final anime = createAnime(id: '1', title: title);
        final animes = [anime];

        // Search with lowercase
        final lowerResults = filterAnimeByQuery(animes, title.toLowerCase());
        // Search with uppercase
        final upperResults = filterAnimeByQuery(animes, title.toUpperCase());

        expect(lowerResults.length, equals(upperResults.length));
        if (lowerResults.isNotEmpty) {
          expect(lowerResults.first.id, equals(upperResults.first.id));
        }
      },
    );

    Glados<String>(
      any.nonEmptyLetterOrDigits,
    ).test('Search is case-insensitive for aliases', (alias) {
      final anime = createAnime(id: '1', title: 'Some Title', aliases: [alias]);
      final animes = [anime];

      // Search with lowercase
      final lowerResults = filterAnimeByQuery(animes, alias.toLowerCase());
      // Search with uppercase
      final upperResults = filterAnimeByQuery(animes, alias.toUpperCase());

      expect(lowerResults.length, equals(upperResults.length));
    });

    test('Partial match in title returns anime', () {
      final animes = [createAnime(id: '1', title: 'Attack on Titan')];

      expect(filterAnimeByQuery(animes, 'Attack').length, equals(1));
      expect(filterAnimeByQuery(animes, 'Titan').length, equals(1));
      expect(filterAnimeByQuery(animes, 'on').length, equals(1));
      expect(filterAnimeByQuery(animes, 'tack').length, equals(1));
    });

    test('Partial match in alias returns anime', () {
      final animes = [
        createAnime(
          id: '1',
          title: 'Attack on Titan',
          aliases: ['Shingeki no Kyojin'],
        ),
      ];

      expect(filterAnimeByQuery(animes, 'Shingeki').length, equals(1));
      expect(filterAnimeByQuery(animes, 'Kyojin').length, equals(1));
      expect(filterAnimeByQuery(animes, 'geki').length, equals(1));
    });

    test('Non-matching query returns empty list', () {
      final animes = [
        createAnime(id: '1', title: 'Attack on Titan'),
        createAnime(id: '2', title: 'One Piece'),
      ];

      final results = filterAnimeByQuery(animes, 'xyz123nonexistent');
      expect(results, isEmpty);
    });

    test('Filter preserves order of matching anime', () {
      final animes = [
        createAnime(id: '1', title: 'Anime Alpha'),
        createAnime(id: '2', title: 'Beta Show'),
        createAnime(id: '3', title: 'Anime Gamma'),
      ];

      final results = filterAnimeByQuery(animes, 'Anime');

      expect(results.length, equals(2));
      expect(results[0].id, equals('1'));
      expect(results[1].id, equals('3'));
    });
  });
}
