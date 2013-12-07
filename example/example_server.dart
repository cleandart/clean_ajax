// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clean_backend/clean_backend.dart';
import 'package:clean_ajax/server.dart';
import 'dart:async';
import 'package:clean_ajax/client.dart';
import 'package:clean_ajax/client_backend.dart';
import 'package:crypto/crypto.dart';


// Don't run example_client.dart nor index.html instead run example_server.dart and go
// in dartium to address 0.0.0.0:8080

Future simpleClientRequestHandler(ClientRequest request) =>
    new Future.value(request.args);

void main() {

  MultiRequestHandler requestHandler = new MultiRequestHandler();
  requestHandler.registerDefaultHandler(simpleClientRequestHandler);

  Connection connection = createLoopBackConnection(requestHandler);

  for (int i=0; i<10; i++) {
    connection.sendRequest(()=>new ClientRequest('dummyType','request$i')).then(
        (response) => print(response)
    );
  }


  Backend.bind([], new SHA256()).then((backend) {
    backend.addDefaultHttpHeader('Access-Control-Allow-Origin','*');
    backend.addView(r'/resources', requestHandler.handleHttpRequest);
    backend.addStaticView(new RegExp(r'/.*'), '.');
  });
}
