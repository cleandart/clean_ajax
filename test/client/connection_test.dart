// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library connection_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:clean_ajax/common.dart';
import 'package:clean_ajax/client.dart';
import 'dart:async';
import 'dart:convert';

class MockRemoteHttpServer extends Mock
{
  Duration delay = new Duration(seconds:0);

  setResponse(type, args, response) =>
      when(callsTo('_reqToRes',equals(type),equals(args))).alwaysReturn(response);

  _generateResposne(sendData) {
    List decodedList = JSON.decode(sendData);
    return JSON.encode(decodedList.map(
        (request) => {'id': request['id'],
                      'response': _reqToRes(request['clientRequest']['type'],
                                            request['clientRequest']['args']
                     )}
        ).toList());
  }

  Future<Mock> sendRequest(String url, {String method, bool withCredentials,
    String responseType, String mimeType, Map<String, String> requestHeaders,
    sendData, void onProgress(e)})
  {
    var response = _generateResposne(sendData);
    var httpRequest = new Mock();
    httpRequest.when(callsTo('get responseText')).alwaysReturn(response);
    return new  Future.delayed(delay,()=>httpRequest);
  }

}

class TransportMock extends Mock implements Transport {
  Function prepareRequest;
  Function handleResponse;

  setHandlers(prepareRequest, handleResponse) {
    this.prepareRequest = prepareRequest;
    this.handleResponse = handleResponse;
  }
}

class CRMock extends Mock implements ClientRequest {}

void main() {
  group('Connection', () {

    test('notify transport on sendRequest.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);

      // when
      connection.sendRequest(null);

      // then
      transport.getLogs(callsTo('markDirty')).verify(happenedOnce);
    });

    test('send requests in order.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var requests = [new CRMock(), new CRMock(), new CRMock()];

      // when
      for (var request in requests) {
        connection.sendRequest(() => request);
      }

      // then
      var packedRequests = transport.prepareRequest();
      for (var i = 0; i < packedRequests.length; i++) {
        expect(packedRequests[i].clientRequest, equals(requests[i]));
      }
    });

    test('futures are completed with proper response.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var requests = [new CRMock(), new CRMock(), new CRMock()];
      var responses = ["response1", "response2", "response3"];

      var futures = [];
      for (var request in requests) {
        futures.add(connection.sendRequest(() => request));
      }

      var packedRequests = transport.prepareRequest();

      var packedResponses = [];
      for (var i = 0; i < packedRequests.length; i++) {
        packedResponses.add(
            {'id': packedRequests[i].id, 'response': responses[i]});
      }

      // when
      transport.handleResponse(packedResponses);

      // then
      for (var i = 0; i < futures.length; i++) {
        futures[i].then(expectAsync1((response) {
          expect(response, equals(responses[i]));
        }));
      }
    });

  });


  group('HttpTransport', () {
    test('send packedRequests as JSON.', () {
      // given
      var response = [{"id": 1}, {"id": 2}];
      var httpResponse = new Mock()
          ..when(callsTo('get responseText')).alwaysReturn(JSON.encode(response));

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];
      var sendHttpRequest = new Mock()
          ..when(callsTo('call')).alwaysReturn(new Future.value(httpResponse));

      var transport = new HttpTransport(
          (url, {method, requestHeaders, sendData}) =>
              sendHttpRequest(url, method, requestHeaders, sendData),
          "url",
          new Duration()
      );

      transport.setHandlers(() => packedRequests,

          // then
          expectAsync1((receivedResponse) {
            expect(receivedResponse, equals(response));
          }

      ));

      // when
      transport.markDirty();

      // then
      sendHttpRequest.getLogs(
          callsTo('call', 'url', 'POST', {'Content-Type': 'application/json'},
                  JSON.encode(packedRequests))).verify(happenedOnce);
    });
  });

  group('LoopBackTransport', () {
    test('send packedRequests.', () {
      // given
      var response = [{"id": 1}, {"id": 2}];

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];
      var sendLoopBackRequest = new Mock()
          ..when(callsTo('call')).alwaysReturn(new Future.value(response));

      var transport = new LoopBackTransport(
          (List<PackedRequest> requests) => sendLoopBackRequest(requests)
      );

      transport.setHandlers(() => packedRequests,

          // then
          expectAsync1((receivedResponse) {
            expect(receivedResponse, equals(response));
          }

      ));

      // when
      transport.markDirty();

      // then
      sendLoopBackRequest.getLogs(
          callsTo('call', packedRequests))
            .verify(happenedOnce);
    });
  });
}
