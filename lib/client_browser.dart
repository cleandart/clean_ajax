// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Client(Browser) side
 */
library clean_ajax.client_browser;

import "dart:html";
import 'client.dart';
export 'client.dart';

Connection createHttpConnection(url, Duration delayBetweenRequests) =>
  new Connection.config(
      new HttpTransport(HttpRequest.request, url, delayBetweenRequests)
  );
