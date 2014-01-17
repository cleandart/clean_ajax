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

  Future<Mock> send(String url, {String method, bool withCredentials,
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
  Function handleError;

  setHandlers(prepareRequest, handleResponse, handleError) {
    this.prepareRequest = prepareRequest;
    this.handleResponse = handleResponse;
    this.handleError = handleError;
  }
}

class CRMock extends Mock implements ClientRequest {}

void main() {
  group('Connection', () {

    test('notify transport on send.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);

      // when
      connection.send(null);

      // then
      transport.getLogs(callsTo('markDirty')).verify(happenedOnce);
    });

    test('notify transport on sendPeriodically.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);

      // when
      connection.sendPeriodically(null);

      // then
      transport.getLogs(callsTo('markDirty')).verify(happenedOnce);

    });

    test('after adding only null requests is packedRequests empty.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      List requests = [null, null];

      // when
      for (var request in requests) {
        connection.send(() => request).catchError(
            expectAsync1((e) => expect(e, new isInstanceOf<CancelError>())));
      }

      // then
      List packedRequests = transport.prepareRequest();
      expect(packedRequests.isEmpty, isTrue);

    });

    test('adds only not null requests.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var requests = [null, new CRMock()];

      // when
      for (var request in requests) {
        if(request == null) connection.send(() => request)
          .catchError(expectAsync1((e) => expect(e, new isInstanceOf<CancelError>())));
        else connection.send(() => request);
      }

      // then
      List packedRequests = transport.prepareRequest();

      expect(packedRequests.length, equals(1));
      expect(packedRequests.first.clientRequest, equals(requests[1]));

    });

    test('send requests in order.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var requests = [new CRMock(), new CRMock(), new CRMock()];

      // when
      for (var request in requests) {
        connection.send(() => request);
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
        futures.add(connection.send(() => request));
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

    test('send periodically.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var request = new CRMock();

      // when
      connection.sendPeriodically(() => request);
      var packedRequests1 = transport.prepareRequest();
      var packedRequests2 = transport.prepareRequest();

      // then
      expect(packedRequests1[0].clientRequest, equals(request));
      expect(packedRequests2[0].clientRequest, equals(request));

    });

    test('receive responses from stream periodically.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var request = new CRMock();
      var responseStream = connection.sendPeriodically(() => request);

      // when
      new Future.sync(() {
        var packedRequests1 = transport.prepareRequest();
        var packedResponses = [];
        packedResponses.add({'id': packedRequests1[0].id, 'response': 'response'});
        transport.handleResponse(packedResponses);
      }).then((_) {
        var packedRequests2 = transport.prepareRequest();
        var packedResponses = [];
        packedResponses.add({'id': packedRequests2[0].id, 'response': 'response'});
        transport.handleResponse(packedResponses);
      });

      // then
      return responseStream.take(2).toList().then((value) {
        expect(value, equals(['response', 'response']));
      });

    });

    test('stop listening to correct response stream.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var request1 = new CRMock();
      var request2 = new CRMock();
      var request3 = new CRMock();
      var responseStream1 = connection.sendPeriodically(() => request1);
      var responseStream2 = connection.sendPeriodically(() => request2);
      var responseStream3 = connection.sendPeriodically(() => request3);


      // when
      return new Future.value(responseStream2.listen((value) {}).cancel()).then((_) {
        var packedRequests = transport.prepareRequest();
        var clientRequests = packedRequests.map((request) => request.clientRequest);

        // then
        expect(clientRequests, unorderedEquals([request1, request3]));
      });

    });

    test('complete send with error.', () {
      // given
      var transport = new TransportMock();
      var error = new Mock();
      var connection = new Connection.config(transport);
      var request1 = connection.send(() => new CRMock());
      var request2 = connection.send(() => new CRMock());
      transport.prepareRequest();

      // when
      transport.handleError(error);

      // then
      expect(request1, throwsA(new isInstanceOf<FailedRequestException>("FailedRequestException")));
      expect(request2, throwsA(new isInstanceOf<FailedRequestException>("FailedRequestException")));
    });

    test('complete sendPeriodically with error.', () {
      // given
      var transport = new TransportMock();
      var error = new Mock();
      var connection = new Connection.config(transport);
      var request = connection.sendPeriodically(() => new CRMock());
      transport.prepareRequest();

      // when
      transport.handleError(error);

      // then

      var subscription = request.listen(null);
      subscription.onError(expectAsync1((e) {
        expect(e, new isInstanceOf<FailedRequestException>("FailedRequestException"));
        subscription.cancel();
      }));

    });

  });


  group('HttpTransport', () {

    test('send packedRequests as JSON.', () {
      // given
      var response = [{"id": 1}, {"id": 2}];
      var httpResponse = new Mock()
          ..when(callsTo('get responseText')).alwaysReturn(JSON.encode(response));

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];

      var getPackedRequests = new Mock();
      getPackedRequests.when(callsTo('call'))
        ..thenReturn(packedRequests)
        ..alwaysReturn([]);

      var sendHttpRequest = new Mock()
          ..when(callsTo('call')).alwaysReturn(new Future.value(httpResponse));

      var transport = new HttpTransport(
          (url, {method, requestHeaders, sendData}) =>
              sendHttpRequest(url, method, requestHeaders, sendData),
          "url",
          new Duration(milliseconds: 1)
      );

      transport.setHandlers(getPackedRequests,

          // then
          expectAsync1((receivedResponse) {
            expect(receivedResponse, equals(response));
            transport.dispose();
          }

      ), null);

      // when
      transport.markDirty();

      // then
      return new Future.delayed(new Duration(milliseconds: 10), () {
        sendHttpRequest.getLogs(
            callsTo('call', 'url', 'POST', {'Content-Type': 'application/json'},
                    JSON.encode(packedRequests))).verify(happenedOnce);
      });
    });

    test('do not send empty requests.', () {
      // given
      var sendHttpRequest = new Mock();
      var transport = new HttpTransport(sendHttpRequest, "url",
          new Duration(milliseconds: 1));

      // when
      transport.setHandlers(() => [], null, null);

      // then
      return new Future.delayed(new Duration(milliseconds: 10), () {
        expect(sendHttpRequest.verifyZeroInteractions(), isTrue);
      });


    });

    test('handle error.', () {
      // given
      var sendHttpRequest = new Mock()
          ..when(callsTo('call')).alwaysCall(
              (url) => new Future.error(new Mock())
          );

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];
      var transport = new HttpTransport(sendHttpRequest, "url",
          new Duration(milliseconds: 1));

      // when
      transport.setHandlers(() => packedRequests, null,
          expectAsync1((e) {
            // then
            expect(e, new isInstanceOf<FailedRequestException>("FailedRequestException"));
          })
      );

    });
  });

  group('LoopBackTransport', () {
    test('send packedRequests.', () {
      // given
      var response = [{"id": 1}, {"id": 2}];
      var authenticatedUserId = new Mock();

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];
      var sendLoopBackRequest = new Mock()
          ..when(callsTo('call')).alwaysReturn(new Future.value(response));

      var transport = new LoopBackTransport(
          sendLoopBackRequest,
          authenticatedUserId
      );

      transport.setHandlers(() => packedRequests,

          // then
          expectAsync1((receivedResponse) {
            expect(receivedResponse, equals(response));
          }

      ), null);

      // when
      transport.markDirty();

      // then
      sendLoopBackRequest.getLogs(
          callsTo('call', packedRequests, authenticatedUserId))
            .verify(happenedOnce);
    });

    test('handle error.', () {
      // given
      var sendLoopBackRequest = new Mock()
          ..when(callsTo('call')).alwaysCall((url)=>new Future.error(new Mock()));

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];

      var transport = new LoopBackTransport(
          (List<PackedRequest> requests, authenticatedUserId) => sendLoopBackRequest(requests)
      );

      // when
      transport.setHandlers(() => packedRequests, null,
          expectAsync1((e) {
            // then
            expect(e, new isInstanceOf<FailedRequestException>("FailedRequestException"));
          })
      );

      // when
      transport.markDirty();

    });
  });

  test('Requests are sent strictly periodicaly in HttpTransport.', () {
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
            new Duration(milliseconds: 100)
    );

    transport.setHandlers(() => packedRequests,

        // then
        expectAsync1((receivedResponse) {
          expect(receivedResponse, equals(response));
        },
        count: 1, max: 1
    ), null);

    // when
    transport.markDirty();
    return new Future.delayed(new Duration(milliseconds: 10), () {
      transport.markDirty();
      return new Future.delayed(new Duration(milliseconds:100), () {
        sendHttpRequest.getLogs(
            callsTo('call', 'url', 'POST', {'Content-Type': 'application/json'},
                    JSON.encode(packedRequests))).verify(happenedOnce);
      });
    });
    // then

  });

}
