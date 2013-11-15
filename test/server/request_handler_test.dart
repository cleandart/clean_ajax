// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library request_handler_test.dart;

import 'package:unittest/unittest.dart';
import 'package:clean_ajax/server.dart';
import 'package:unittest/mock.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http_server/http_server.dart';

class MockHttpBody extends Mock implements HttpBody {}

class MockHttpRequest extends Mock implements HttpRequest {
  Mock httpBody = new MockHttpBody();
  Mock httpResponse = new Mock();
  Mock httpHeaders = new Mock();
  MockHttpRequest(String body) {
    httpBody.when(callsTo('get body')).alwaysReturn(body);
    when(callsTo('get response')).alwaysReturn(httpResponse);
    httpResponse.when(callsTo('get headers')).alwaysReturn(httpHeaders);
  }
}

Future mockHttpBodyExctractor(MockHttpRequest request) =>
    new Future.value(request.httpBody);

void main() {

  group('MultiRequestHandler', () {
    MultiRequestHandler requestHandler;

    setUp(() {
      requestHandler = new MultiRequestHandler.config(mockHttpBodyExctractor);
    });

    verifyCorrectRequestMetaData(request, expectedHttpStatusCode) {
      var contentType = request.response.headers
          .getLogs(callsTo('set contentType')).last.args.first;
      var statusCode = request.response
          .getLogs(callsTo('set statusCode')).last.args.first;

      expect(contentType.toString(), equals(ContentType.parse("application/json").toString()));
      expect(statusCode, expectedHttpStatusCode);
    }

    verifyCorrectRequestContent(request, String expectedContent)
    {
       var content = request.response.getLogs(callsTo('write')).last.args.first;
       expect(content,equals(expectedContent));
    }

    test('No ClientRequestHandler registered (T01).', () {
      //given
      var request = new MockHttpRequest(JSON.encode([new PackedRequest(47, new ClientRequest('test1',15))]));
      //when
      requestHandler.handleHttpRequest(request);

      //then
      var closeCalled = expectAsync0(() {
        verifyCorrectRequestMetaData(request, HttpStatus.BAD_REQUEST);
      });
      request.response.when(callsTo('close')).alwaysCall(closeCalled);
    });

    test('One ClientRequestHandler execution (TO2).', () {
        //given
        Future mockExecutor(request) => new Future.value('dummyResponse');
        requestHandler.registerHandler('dummyType', mockExecutor);
        var request = new MockHttpRequest(JSON.encode([new PackedRequest(47, new ClientRequest('dummyType',15))]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        var closeCalled = expectAsync0(() {
          verifyCorrectRequestMetaData(request, HttpStatus.OK);
          verifyCorrectRequestContent(request,'[{"id":47,"response":"dummyResponse"}]');
        });
        request.response.when(callsTo('close')).alwaysCall(closeCalled);
    });

    test('Default ClientRequestHandler execution (TO3).', () {
        //given
        Future mockExecutor(request) => new Future.value('dummyResponse');
        requestHandler.registerDefaultHandler(mockExecutor);
        var request = new MockHttpRequest(JSON.encode([new PackedRequest(47, new ClientRequest('dummyType',15))]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        var closeCalled = expectAsync0(() {
          verifyCorrectRequestMetaData(request, HttpStatus.OK);
          verifyCorrectRequestContent(request,'[{"id":47,"response":"dummyResponse"}]');
        });
        request.response.when(callsTo('close')).alwaysCall(closeCalled);
    });

    test('ClientRequestHandler execution with more packed requests in order (TO4).', () {
        //given
        List<String> orderOfExecution = new List<String>();

        Future mockExecutor(ClientRequest request) {
          orderOfExecution.add(request.args.toString());
          return new Future.value(request.type);
        }
        requestHandler.registerDefaultHandler(mockExecutor);

        var request = new MockHttpRequest(
            JSON.encode([new PackedRequest(1, new ClientRequest('dummyType1','firstRequest')),
                         new PackedRequest(2, new ClientRequest('dummyType2','secondRequest'))
                        ]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        var closeCalled = expectAsync0(() {
          verifyCorrectRequestMetaData(request, HttpStatus.OK);
          verifyCorrectRequestContent(request,'[{"id":1,"response":"dummyType1"},{"id":2,"response":"dummyType2"}]');
          expect(orderOfExecution,equals(['firstRequest','secondRequest']));
        });
        request.response.when(callsTo('close')).alwaysCall(closeCalled);
    });

    test('Specific and default ClientRequestHandler execution (TO5).', () {
        //given
        Future mockExecutorSpecific(request) => new Future.delayed(new Duration(seconds: 2),()=>'specificResponse');
        Future mockExecutorDefault(request) => new Future.value('defaultResponse');
        requestHandler.registerHandler('specificType',mockExecutorSpecific);
        requestHandler.registerDefaultHandler(mockExecutorDefault);

        var request = new MockHttpRequest(
            JSON.encode([new PackedRequest(1, new ClientRequest('specificType',10)),
                         new PackedRequest(2, new ClientRequest('dummyType',12))
                        ]));

        //when
        requestHandler.handleHttpRequest(request);

        //then
        var closeCalled = expectAsync0(() {
          verifyCorrectRequestMetaData(request, HttpStatus.OK);
          verifyCorrectRequestContent(request,'[{"id":1,"response":"specificResponse"},{"id":2,"response":"defaultResponse"}]');
        });
        request.response.when(callsTo('close')).alwaysCall(closeCalled);
    });
  });

 }
