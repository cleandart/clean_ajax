// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test_all;

import "common/packed_request_test.dart" as packed_request_test;
import "common/client_request_test.dart" as client_request_test;
import "server/request_handler_test.dart" as request_handler_test;
import "client/connection_test.dart" as connection_handler_test;

void main() {
  packed_request_test.main();
  client_request_test.main();
  request_handler_test.main();
  connection_handler_test.main();
}