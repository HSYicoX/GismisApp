import 'package:gismis/features/schedule/data/schedule_repository.dart';
import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 6: Progress Increment Invariant
/// Validates: Requirements 2.4
///
/// For any UserAnimeFollow with progressEpisode = N, after incrementing
/// progress, the progressEpisode SHALL equal N+1, and N+1 SHALL NOT
/// exceed latestEpisode.

void main() {
  group('Property 6: Progress Increment Invariant', () {
    Glados2<int, int>(any.intInRange(0, 100), any.intInRange(1, 100)).test(
      'Incrementing progress produces N+1 when below latest episode',
      (currentProgress, latestEpisode) {
        // Ensure currentProgress is valid (less than latestEpisode)
        final validProgress = currentProgress > latestEpisode
            ? latestEpisode - 1
            : currentProgress;

        if (validProgress < latestEpisode) {
          final newProgress = incrementProgress(validProgress, latestEpisode);

          // Property: New progress equals current + 1
          expect(newProgress, equals(validProgress + 1));
        }
      },
    );

    Glados<int>(any.intInRange(1, 100)).test(
      'Progress never exceeds latest episode',
      (latestEpisode) {
        // Test at the boundary
        final atMax = incrementProgress(latestEpisode, latestEpisode);
        expect(
          atMax <= latestEpisode,
          isTrue,
          reason: 'Progress $atMax should not exceed latest $latestEpisode',
        );

        // Test above the boundary (edge case)
        final aboveMax = incrementProgress(latestEpisode + 5, latestEpisode);
        expect(
          aboveMax <= latestEpisode,
          isTrue,
          reason: 'Progress should be capped at latest episode',
        );
      },
    );

    Glados2<int, int>(any.intInRange(0, 50), any.intInRange(1, 50)).test(
      'Incremented progress is always greater than or equal to current',
      (currentProgress, latestEpisode) {
        final newProgress = incrementProgress(currentProgress, latestEpisode);

        // Property: Progress never decreases
        expect(
          newProgress >= currentProgress || newProgress == latestEpisode,
          isTrue,
          reason: 'Progress should not decrease',
        );
      },
    );

    test('Progress at 0 increments to 1', () {
      final newProgress = incrementProgress(0, 12);
      expect(newProgress, equals(1));
    });

    test('Progress at latest episode stays at latest episode', () {
      const latestEpisode = 12;
      final newProgress = incrementProgress(latestEpisode, latestEpisode);
      expect(newProgress, equals(latestEpisode));
    });

    test('Progress one below latest increments to latest', () {
      const latestEpisode = 12;
      final newProgress = incrementProgress(latestEpisode - 1, latestEpisode);
      expect(newProgress, equals(latestEpisode));
    });

    Glados<int>(any.intInRange(1, 100)).test(
      'Multiple increments eventually reach latest episode',
      (latestEpisode) {
        var progress = 0;

        // Increment until we reach latest
        for (var i = 0; i < latestEpisode + 10; i++) {
          progress = incrementProgress(progress, latestEpisode);

          // Property: Never exceeds latest
          expect(progress <= latestEpisode, isTrue);

          if (progress == latestEpisode) break;
        }

        // Property: Eventually reaches latest
        expect(progress, equals(latestEpisode));
      },
    );

    Glados<int>(any.intInRange(1, 50)).test(
      'Increment is idempotent at max progress',
      (latestEpisode) {
        // Start at max
        final first = incrementProgress(latestEpisode, latestEpisode);
        final second = incrementProgress(first, latestEpisode);

        // Property: Incrementing at max produces same result
        expect(first, equals(second));
        expect(first, equals(latestEpisode));
      },
    );

    test('Progress with latest episode of 1 caps at 1', () {
      expect(incrementProgress(0, 1), equals(1));
      expect(incrementProgress(1, 1), equals(1));
      expect(incrementProgress(5, 1), equals(1));
    });

    Glados2<int, int>(any.intInRange(0, 100), any.intInRange(1, 100)).test(
      'Result is always within valid range [0, latestEpisode]',
      (currentProgress, latestEpisode) {
        final newProgress = incrementProgress(currentProgress, latestEpisode);

        // Property: Result is in valid range
        expect(newProgress >= 0, isTrue);
        expect(newProgress <= latestEpisode, isTrue);
      },
    );
  });
}
