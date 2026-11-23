import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/repositories/stage_repository.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ApiClient> makeClient(Handler handler) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'd'});
    final store = SecureStore();
    await store.load();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = FakeAdapter(handler);
    return ApiClient(store, dio: dio);
  }

  group('Attendance conflict batches & bulk resolution client tests', () {
    test('attendanceConflictBatches requests /attendance/sync-conflicts/batches and parses response', () async {
      late RequestOptions capturedReq;
      final api = await makeClient((req) {
        capturedReq = req;
        if (req.path == '/attendance/sync-conflicts/batches') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': [
                {
                  'batch_id': 'batch-uuid-1234',
                  'program_id': 1,
                  'program_title': 'Weekly Rehearsal',
                  'occurrence_date': '2026-10-29',
                  'submitted_by': 5,
                  'submitted_by_name': 'Taker Dawit',
                  'total_conflicts': 10,
                  'open_count': 10,
                  'accepted_count': 0,
                  'rejected_count': 0,
                  'primary_code': 'SIGNATURE_REQUIRED',
                  'status': 'open',
                }
              ],
              'meta': {'page': 1, 'limit': 20, 'total': 1, 'pages': 1},
              'errors': [],
            }
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });
      final repo = StageRepository(api);

      final result = await repo.attendanceConflictBatches(status: 'open');

      expect(result.items.length, 1);
      final batch = result.items.first;
      expect(batch['batch_id'], 'batch-uuid-1234');
      expect(batch['total_conflicts'], 10);
      expect(batch['open_count'], 10);
      expect(batch['status'], 'open');
      expect(batch['primary_code'], 'SIGNATURE_REQUIRED');
      expect(capturedReq.queryParameters['status'], 'open');
    });

    test('attendanceConflicts accepts batchId and passes it as query parameter', () async {
      late RequestOptions capturedReq;
      final api = await makeClient((req) {
        capturedReq = req;
        if (req.path == '/attendance/sync-conflicts') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': [
                {
                  'id': 101,
                  'batch_id': 'batch-uuid-1234',
                  'code': 'SIGNATURE_REQUIRED',
                  'status': 'open',
                  'user_id': 10,
                  'full_name': 'Member Abebe',
                }
              ],
              'meta': {'page': 1, 'limit': 20, 'total': 1, 'pages': 1},
              'errors': [],
            }
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });
      final repo = StageRepository(api);

      final result = await repo.attendanceConflicts(status: 'open', batchId: 'batch-uuid-1234');

      expect(result.items.length, 1);
      expect(result.items.first['id'], 101);
      expect(capturedReq.queryParameters['batch_id'], 'batch-uuid-1234');
    });

    test('bulkResolveAttendanceConflicts calls POST /attendance/sync-conflicts/bulk-resolve', () async {
      late RequestOptions capturedReq;
      final api = await makeClient((req) {
        capturedReq = req;
        if (req.path == '/attendance/sync-conflicts/bulk-resolve' && req.method == 'POST') {
          final b = body(req);
          return (
            status: 200,
            body: ok({
              'success': true,
              'decision': b['decision'],
              'total': 5,
              'resolved': 5,
              'accepted': b['decision'] == 'accept' ? 5 : 0,
              'rejected': b['decision'] == 'reject' ? 5 : 0,
              'skipped': 0,
              'batch_id': b['batch_id'],
              'resolved_ids': [101, 102, 103, 104, 105],
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });
      final repo = StageRepository(api);

      final res = await repo.bulkResolveAttendanceConflicts(
        batchId: 'batch-uuid-1234',
        decision: 'accept',
        note: 'Approved by HR batch review',
      );

      expect(res['success'], true);
      expect(res['decision'], 'accept');
      expect(res['resolved'], 5);
      expect(res['batch_id'], 'batch-uuid-1234');

      final sentBody = body(capturedReq);
      expect(sentBody['batch_id'], 'batch-uuid-1234');
      expect(sentBody['decision'], 'accept');
      expect(sentBody['note'], 'Approved by HR batch review');
    });
  });
}
