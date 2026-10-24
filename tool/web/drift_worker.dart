// The web worker drift runs the database in — compiled into
// `web/drift_worker.js` by `tool/build_web_db_assets.sh`, from the drift
// version pubspec.lock pins, so the two can never disagree.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
