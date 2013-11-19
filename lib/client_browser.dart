// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Client(Browser) side
 */
library clean_ajax.client;

import "dart:html";
import 'package:clean_ajax/client.dart' as Client;
export 'package:clean_ajax/client.dart' show ClientRequest, HttpRequestFactory;


class HttpConnection extends Client.HttpConnection
{
  /**
   * Creates a new [Connection] with default [HttpRequestFactory]
   */
  HttpConnection(url, Duration delayBetweenRequests) : super.config(HttpRequest.request, url, delayBetweenRequests) ;
}