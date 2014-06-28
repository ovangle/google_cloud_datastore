library test_logging;

import 'package:logging/logging.dart';

bool loggingStarted = false;

void initLogging() {
  if (!loggingStarted) {
    Logger.root.onRecord.listen(print);
    loggingStarted = true;
  }
}