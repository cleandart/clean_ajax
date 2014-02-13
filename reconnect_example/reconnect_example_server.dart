// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clean_backend/clean_backend.dart';
import 'package:clean_ajax/server.dart';
import 'dart:async';
import 'package:clean_ajax/client.dart';
import 'package:clean_ajax/client_backend.dart';
import 'package:clean_ajax/common.dart';
import 'package:crypto/crypto.dart';
import 'package:clean_router/common.dart';


// Don't run example_client.dart nor index.html instead run example_server.dart
// (working directory should be set to the directory containing this script) and navigate
// dartium to the address 0.0.0.0:8080/index.html

var requestCount = 0;

Future simpleServerRequestHandler(ServerRequest request) {
  print("Simple request received");
  if ((requestCount++ / 3).toInt() % 2 == 0)
    return new Future.value(request.args);
  else return new Future.delayed(new Duration(milliseconds: 500), () => request.args);
}

void main() {

  MultiRequestHandler requestHandler = new MultiRequestHandler();
  requestHandler.registerDefaultHandler(simpleServerRequestHandler);

  Connection connection = createLoopBackConnection(requestHandler);

  Backend.bind([], new SHA256()).then((backend) {
    backend.addDefaultHttpHeader('Access-Control-Allow-Origin','*');
    backend.addRoute('resources', new Route('/resources/'));
    backend.addRoute('static', new Route('/*'));
    backend.addView('resources', requestHandler.handleHttpRequest);
    backend.addStaticView('static', './');
  });
}
