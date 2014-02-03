// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Browser implementation of [Connection].
 */
library clean_ajax.client_browser;

import 'client.dart';
export 'client.dart';
import 'http_request.dart';

/**
 * Create new [Connection] based on ajax polling.
 *
 * Expects [MultiRequestHandler] listening server side on the [url].
 * Polling interval can be configured by [delayBetweenRequests].
 */
Connection createHttpConnection(url, Duration delayBetweenRequests, [int timeout = null]) =>
  new Connection.config(
      new HttpTransport(sendHttpRequest, url, delayBetweenRequests, timeout)
  );
