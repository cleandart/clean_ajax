// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:clean_ajax/server.dart';
import 'package:unittest/mock.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http_server/http_server.dart';



class NullObject {
  noSuchMethod(invocation) {
    return new NullObject();
  }
}

class MockHttpRequest extends Mock implements HttpRequest
{
  MockHttpResponse response = new MockHttpResponse();
  MockHttpBody body;
  MockHttpRequest(String request)
  {
    body = new MockHttpBody(request);
  }
  noSuchMethod(invocation) => new NullObject();
}

class MockHttpBody extends Mock implements HttpBody
{
  String type = 'type';
  dynamic body;
  MockHttpBody(this.body);
}

class MockHttpResponse extends Mock implements HttpResponse
{
  final Completer _completer = new Completer();
  Future isFinished;
  dynamic result;
  int statusCode;
  get headers => new NullObject();

  MockHttpResponse()
  {
    isFinished = _completer.future;
  }

  close() => _completer.complete(this);

  write(text) => result = text;

  noSuchMethod(invocation) {
    return new NullObject();
  }
}

Future<MockHttpBody> mockHttpBodyExctractor(MockHttpRequest request) =>
    new Future.value(request.body);

void main() {

  group('RequestHandler', () {
    MultiRequestHandler requestHandler;
    MockHttpBody body;

    setUp(() {
      requestHandler = new MultiRequestHandler.config(mockHttpBodyExctractor);
    });


    test('Empty request handler (T01).', () {
      //given
      var request = new MockHttpRequest(JSON.encode([new PackedRequest(47, new ClientRequest('test1',15))]));

      //when
      requestHandler.handleHttpRequest(request);

      //then
      request.response.isFinished.then(expectAsync1((MockHttpResponse response) => expect(response.statusCode,HttpStatus.BAD_REQUEST)));
    });

    test('Register and run one executor (TO2).', () {
        //given
        Future mockExecutor(request) => new Future.value('dummyResponse');
        requestHandler.registerExecutor('dummyType', mockExecutor);
        var request = new MockHttpRequest(JSON.encode([new PackedRequest(47, new ClientRequest('dummyType',15))]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        request.response.isFinished.then(expectAsync1(
          (MockHttpResponse response) {
            expect(response.statusCode,HttpStatus.OK);
            expect(response.result,equals(JSON.encode([{'id':47, 'response': 'dummyResponse'}])));
          }
        ));
    });

    test('Register and run default executor (TO3).', () {
        //given
        Future mockExecutor(request) => new Future.value('dummyResponse');
        requestHandler.registerDefaultExecutor(mockExecutor);
        var request = new MockHttpRequest(JSON.encode([new PackedRequest(47, new ClientRequest('dummyType',15))]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        request.response.isFinished.then(expectAsync1(
          (MockHttpResponse response) {
            expect(response.statusCode,HttpStatus.OK);
            expect(response.result,equals(JSON.encode([{'id':47, 'response': 'dummyResponse'}])));
          }
        ));
    });

    test('Test reciving of multiple PackedRequests (TO4).', () {
        //given
        Future mockExecutor1(request) => new Future.delayed(new Duration(seconds: 2),()=>'dummyResponse1');
        Future mockExecutor2(request) => new Future.value('dummyResponse2');
        requestHandler.registerExecutor('dummyType1',mockExecutor1);
        requestHandler.registerDefaultExecutor(mockExecutor2);

        var request = new MockHttpRequest(
            JSON.encode([new PackedRequest(1, new ClientRequest('dummyType1',10)),
                         new PackedRequest(2, new ClientRequest('dummyType2',12))
                        ]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        request.response.isFinished.then(expectAsync1(
          (MockHttpResponse response) {
            expect(response.statusCode,HttpStatus.OK);
            expect(response.result,equals(JSON.encode(
                [{'id':1, 'response': 'dummyResponse1'},
                 {'id':2, 'response': 'dummyResponse2'}
                ]
            )));
          }
        ));
    });
  });

 }
