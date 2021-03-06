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


class TransportMock extends Mock implements Transport {
  Function prepareRequest;
  Function handleResponse;
  Function handleError;
  Function handleDisconnect;
  Function handleReconnect;

  setHandlers(prepareRequest, handleResponse, handleError, [handleDisconnect = null, handleReconnect = null]) {
    this.prepareRequest = prepareRequest;
    this.handleResponse = handleResponse;
    this.handleError = handleError;
    this.handleDisconnect = handleDisconnect == null ? (){} : handleDisconnect;
    this.handleReconnect = handleReconnect == null ? (){} : handleReconnect;
  }
}

class CRMock extends Mock implements ClientRequest {}

void main() {
  group('Connection', () {


    test('handleResponse set autheticated userId.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var request = new CRMock();
      var response = "response";
      var future = connection.send(() => request);
      var packedRequests = transport.prepareRequest();
      var packedResponses = [{'id': packedRequests[0].id, 'response': response}];

      // when
      transport.handleResponse({'authenticatedUserId': 'someAuthenticatedUserId', 'responses': packedResponses});

      // then
      expect(connection.authenticatedUserId, equals('someAuthenticatedUserId'));
    });

    test('handleResponse adds to stream on AuthenticatedUserIdChange.', () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var request = new CRMock();
      var response = "response";
      var future = connection.send(() => request);
      var packedRequests = transport.prepareRequest();
      var packedResponses = [{'id': packedRequests[0].id, 'response': response}];

      var listenOnFirstAuthenticatedUserIdChange = connection.onAuthenticatedUserIdChange.first;

      // when
      transport.handleResponse({'authenticatedUserId': 'someAuthenticatedUserId', 'responses': packedResponses});

     //then
      expect(listenOnFirstAuthenticatedUserIdChange, completion('someAuthenticatedUserId'));

    });

    test("handleResponse with same authenticatedUserId don't adds to stream onAuthenticatedUserIdChange.", () {
      // given
      var transport = new TransportMock();
      var connection = new Connection.config(transport);
      var request = new CRMock();
      var response = "response";
      var future = connection.send(() => request);
      var packedRequests = transport.prepareRequest();
      var packedResponses = [{'id': packedRequests[0].id, 'response': response}];

      Future handle() {
        transport.handleResponse({'authenticatedUserId': 'someAuthenticatedUserId', 'responses': packedResponses});
        return new Future.delayed(new Duration(seconds:0));
      }

      // then
      Future ll = handle().then((_) {connection.onAuthenticatedUserIdChange.listen((protectAsync1((_)
          {expect(true, isFalse, reason: 'Should not be reached');})));});

      // when
      return Future.wait([ll.then((_) {transport.handleResponse({'authenticatedUserId': 'someAuthenticatedUserId', 'responses': packedResponses});})]);

    });

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
      transport.handleResponse({'authenticatedUserId': '', 'responses': packedResponses});

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
        transport.handleResponse({'authenticatedUserId': '', 'responses': packedResponses});
      }).then((_) {
        var packedRequests2 = transport.prepareRequest();
        var packedResponses = [];
        packedResponses.add({'id': packedRequests2[0].id, 'response': 'response'});
        transport.handleResponse({'authenticatedUserId': '', 'responses': packedResponses});
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
        return new Future.value(() =>
          expect(clientRequests, unorderedEquals([request1, request3])));
      });

    });

    test('complete send with error.', () {
      // given
      var transport = new TransportMock();
      var error = new FailedRequestException();
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
      var error = new FailedRequestException();
      var connection = new Connection.config(transport);
      var request = connection.sendPeriodically(() => new CRMock());
      transport.prepareRequest();

      // when
      transport.handleError(error);

      // then

      var subscription = request.listen(null);
      subscription.onError(expectAsync((e) {
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
          expectAsync((receivedResponse) {
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
        transport.dispose();
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
          new Duration(milliseconds: 1000));

      // when
      transport.setHandlers(() => packedRequests, null,
          expectAsync((e) {
            // then
            expect(e, new isInstanceOf<FailedRequestException>("FailedRequestException"));
            transport.dispose();
          })
      );

    });
    group('Reconnect', () {
      test('Disconnect triggered at Transport level.', () {
        // given
        var sendHttpRequest = new Mock()
        ..when(callsTo('call')).alwaysCall(
            (url) => new Future.error(new ConnectionError(new Mock()))
        );

        var packedRequests = [{"packedId": 1}, {"packedId": 2}];
        var transport = new HttpTransport(sendHttpRequest, "url",
            new Duration(milliseconds: 1000));

        // when
        transport.setHandlers(() => packedRequests, null,
            expectAsync((e) {
              // then
              expect(e, new isInstanceOf<ConnectionError>());
              transport.dispose();
            })
        );
      });
      test('Disconnect propagated.', () {
        //given
        var sendHttpRequest = new Mock()
        ..when(callsTo('call')).alwaysCall(
            (url) => new Future.error(new ConnectionError(new Mock()))
        );

        var packedRequests = [{"packedId": 1}, {"packedId": 2}];
        var transport = new HttpTransport(sendHttpRequest, "url",
            new Duration(milliseconds: 100));
        var sentCount = 0;
        Function getRequests = () {
          if (sentCount == 0) return packedRequests;
          else return [];
        };

        // when
        transport.setHandlers(() => packedRequests, null,
            expectAsync((e) {
              // then
              expect(e, new isInstanceOf<ConnectionError>());
            }), expectAsync(() {transport.dispose();})
        );
      });
      test('Reconnect propagated.', () {
        //given
        var sendHttpRequest = new Mock()
        ..when(callsTo('call')).alwaysCall(
            (url) => new Future.error(new ConnectionError(new Mock()))
        );

        var packedRequests = [{"packedId": 1}, {"packedId": 2}];
        var transport = new HttpTransport(sendHttpRequest, "url",
            new Duration(milliseconds: 10));
        var sentCount = 0;
        Function getRequests = () {
          if (sentCount++ == 0) return packedRequests;
          else return [];
        };

        // when
        transport.setHandlers(getRequests, null,
            expectAsync((e) {
              // then
              expect(e, new isInstanceOf<ConnectionError>());
              sendHttpRequest.resetBehavior();
              sendHttpRequest.when(callsTo('call')).alwaysCall(
                (url) => new Future.value(null)
              );
            }), expectAsync(() {}), expectAsync(() {transport.dispose();})
        );
      });
    });
  });

  group('LoopBackTransport', () {
    test('send packedRequests encoded in JSON.', () {
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
          expectAsync((receivedResponse) {
            expect(receivedResponse, equals({'responses':response, 'authenticatedUserId': authenticatedUserId}));
          }

      ), null);

      // when
      transport.markDirty();

      // then
      return new Future.delayed(new Duration(milliseconds: 20), () => sendLoopBackRequest.getLogs(
          callsTo('call', JSON.encode(packedRequests), authenticatedUserId))
            .verify(happenedOnce));
    });

    test('handle error.', () {
      // given
      var sendLoopBackRequest = new Mock()
          ..when(callsTo('call')).alwaysCall((url)=>new Future.error(new Mock()));

      var packedRequests = [{"packedId": 1}, {"packedId": 2}];

      var transport = new LoopBackTransport(
          (String requests, authenticatedUserId) => sendLoopBackRequest(requests)
      );

      // when
      transport.setHandlers(() => packedRequests, null,
          expectAsync((e) {
            // then
            expect(e, new isInstanceOf<FailedRequestException>("FailedRequestException"));
          })
      );

      // when
      transport.markDirty();

    });

    // TODO
    test('requests are sent in the next event-loop', (){

    });

    // TODO
    test('ClientRequest are JSON serialized / deserialized', (){

    });

  });

  group('LoopBackTransportStub', () {
    test('After calling fail, first request runs with error and next requests are not executed.', () {
      // given
      int requests = 0;
      var response = new Mock();
      var authenticatedUserId = new Mock();

      var packedRequests = new Mock();
      var sendLoopBackRequest = new Mock()
          ..when(callsTo('call')).alwaysReturn(new Future.value(response));

      var transport = new LoopBackTransportStub(
          sendLoopBackRequest,
          authenticatedUserId
      );

      transport.setHandlers(
          () { requests++; return packedRequests; },
          (response) => expect(false, isTrue),
          expectAsync((e) => expect(e, new isInstanceOf<ConnectionError>())));

      transport.fail(1.0, new Duration(hours: 1));

      // when
      transport.markDirty();

      // then
      return new Future.delayed(new Duration(milliseconds: 50)).then((_){
        expect(requests, equals(1));
        sendLoopBackRequest.getLogs(
            callsTo('call', JSON.encode(packedRequests), authenticatedUserId))
              .verify(neverHappened);
      });
    });

    test('when calling fail repeatedly, everything works fine', (){
      // given
      var response = new Mock();
      var packedRequests = [new Mock(), new Mock()];
      var responseCount = 0;
      var numResponseCount = 0;
      var sumResponseCount = 0;
      var authenticatedUserId = new Mock();
      bool _connect = true;
      var sendLoopBackRequest = new Mock()
          ..when(callsTo('call'))
          .alwaysReturn(new Future.delayed(new Duration(), () => response));

      var transport = new LoopBackTransportStub(
          sendLoopBackRequest,
          authenticatedUserId
      );
      transport.setHandlers(
          () {  expect(_connect, isTrue);
                transport.markDirty();
                return packedRequests;
          },
          (response) {
            responseCount++;
          },
          (error) {},
          (){
            _connect = false;
            sumResponseCount+=responseCount;
            numResponseCount++;

          },
          (){_connect = true;}
      );

      num millis = 50;

      Timer timer = new Timer.periodic(new Duration(milliseconds: millis*4), (_){
        responseCount = 0;
        transport.fail(0.1, new Duration(milliseconds: millis*2));

        new Future.delayed(new Duration(milliseconds: millis*1), () {
          expect(_connect, isFalse);
        });
        new Future.delayed(new Duration(milliseconds: millis*3), () {
          expect(_connect, isTrue);
        });
      });

      transport.markDirty();

      return new Future.delayed(new Duration(seconds: 5))
      .then((_){
        expect(sumResponseCount/numResponseCount, inInclusiveRange(5, 15));
        timer.cancel();
        transport.setHandlers((){}, (_){}, (_){});
      });

    });
  });

  /**
   * TODO: experimenting with sending requests immediately as they occur;
   * fix this test, if the feature looks promissing
   */
  skip_test('Requests are sent strictly periodicaly in HttpTransport.', () {
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
        expectAsync((receivedResponse) {
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
        transport.dispose();
      });
    });
    // then

  });

}
