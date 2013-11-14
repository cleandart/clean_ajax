// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clean_backend/clean_backend.dart';
import 'package:static_file_handler/static_file_handler.dart';
import 'package:clean_ajax/server.dart';
import 'dart:async';

Future simpleClientRequestHandler(ClientRequest request) =>
    new Future.value(request.args);

void main() {
  Backend backend;
  StaticFileHandler fileHandler = new StaticFileHandler.serveFolder('.');
  MultiRequestHandler requestHandler = new MultiRequestHandler();
  requestHandler.registerDefaultHandler(simpleClientRequestHandler);
  backend = new Backend(fileHandler, requestHandler)..listen();
}
