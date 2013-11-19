// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Client(Browser) side
 */
library clean_ajax.client;

import "dart:html";
import 'package:clean_ajax/client.dart';
export 'package:clean_ajax/client.dart';

Connection createHttpConnection(url, Duration delayBetweenRequests) =>
  new Connection.config(
      new HttpTransport(HttpRequest.request, url, delayBetweenRequests)
  );