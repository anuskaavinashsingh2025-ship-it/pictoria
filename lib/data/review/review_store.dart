import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_record.dart';

/// Saves and loads review decisions and the deletion queue.
abstract class ReviewStore {
  Future<ReviewSnapshot> load();
  Future<void> save(ReviewSnapshot snapshot);
}

/// Keeps everything in memory only (used by tests and as a safe fallback).
class MemoryReviewStore implements ReviewStore {
  MemoryReviewStore([this._snapshot = ReviewSnapshot.empty]);

  ReviewSnapshot _snapshot;
  int saveCount = 0;

  ReviewSnapshot get snapshot => _snapshot;

  @override
  Future<ReviewSnapshot> load() async => _snapshot;

  @override
  Future<void> save(ReviewSnapshot snapshot) async {
    saveCount++;
    _snapshot = snapshot;
  }
}

/// Persists to the platform key-value store (NSUserDefaults on iOS,
/// SharedPreferences on Android) as one small JSON document.
class SharedPreferencesReviewStore implements ReviewStore {
  SharedPreferencesReviewStore([this._preferences]);

  static const storageKey = 'pictora.review.v1';
  static const _version = 1;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<ReviewSnapshot> load() async {
    try {
      final raw = (await _prefs).getString(storageKey);
      if (raw == null) return ReviewSnapshot.empty;
      return decodeSnapshot(raw);
    } catch (error) {
      // A corrupt or unreadable file shouldn't stop the app from starting.
      debugPrint('Could not read review data: $error');
      return ReviewSnapshot.empty;
    }
  }

  @override
  Future<void> save(ReviewSnapshot snapshot) async {
    await (await _prefs).setString(storageKey, encodeSnapshot(snapshot));
  }

  static String encodeSnapshot(ReviewSnapshot snapshot) => jsonEncode({
    'version': _version,
    'records': [for (final record in snapshot.records.values) record.toJson()],
    'pendingDeletion': snapshot.pendingDeletionIds.toList(),
  });

  static ReviewSnapshot decodeSnapshot(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map || json['version'] != _version) {
      return ReviewSnapshot.empty;
    }
    final records = <String, ReviewRecord>{};
    for (final entry in (json['records'] as List? ?? const [])) {
      final record = ReviewRecord.tryFromJson(entry);
      if (record != null) records[record.id] = record;
    }
    return ReviewSnapshot(
      records: records,
      pendingDeletionIds: {
        for (final id in (json['pendingDeletion'] as List? ?? const []))
          if (id is String) id,
      },
    );
  }
}
