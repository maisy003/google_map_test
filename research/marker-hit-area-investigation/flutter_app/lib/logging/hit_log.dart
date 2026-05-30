import 'dart:convert';
import 'dart:developer' as developer;

/// 計測ログを単一行 JSON で logcat に出力する。タグは "HITLOG"。
/// 受信側スクリプトは `adb logcat -s flutter:I` または `adb logcat | grep HITLOG`
/// で拾う。
class HitLog {
  static const _prefix = 'HITLOG';

  static void emit(Map<String, dynamic> event) {
    final line = '$_prefix ${jsonEncode(event)}';
    developer.log(line, name: 'flutter');
    // dart:developer log の name=flutter は logcat の flutter タグに出る。
    // 念のため print も併用すると遅延なく拾える。
    // ignore: avoid_print
    print(line);
  }

  static void indexStart({required String app}) =>
      emit({'event': 'index_start', 'app': app, 'ts': DateTime.now().toIso8601String()});

  static void index({
    required String id,
    required String shape,
    required String ratio,
    required String anchor,
    required int bitmapPxW,
    required int bitmapPxH,
    required double logicalPtW,
    required double logicalPtH,
    required int anchorScreenX,
    required int anchorScreenY,
  }) =>
      emit({
        'event': 'index',
        'id': id,
        'shape': shape,
        'ratio': ratio,
        'anchor': anchor,
        'bitmap_px_w': bitmapPxW,
        'bitmap_px_h': bitmapPxH,
        'logical_pt_w': logicalPtW,
        'logical_pt_h': logicalPtH,
        'anchor_screen_x': anchorScreenX,
        'anchor_screen_y': anchorScreenY,
      });

  static void indexDone() =>
      emit({'event': 'index_done', 'ts': DateTime.now().toIso8601String()});

  static void markerTap(String id) =>
      emit({'event': 'tap', 'id': id, 'ts': DateTime.now().toIso8601String()});
}
