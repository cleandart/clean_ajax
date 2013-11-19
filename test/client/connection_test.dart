// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library connection_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
//import 'package:unittest/html_config.dart';
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

void main() {
  group('Server', () {

    HttpConnection connection;
    MockRemoteHttpServer remoteServer;

    setUp(() {
      remoteServer = new MockRemoteHttpServer();
      connection = new HttpConnection.config(remoteServer.sendRequest, 'localhost', new Duration(milliseconds:100));
    });

    test('Single Request receives a response', () {
      // given
      remoteServer.setResponse('dummyType', 'dummyArgs','dummyResponse');

      // when
      var response = connection.sendRequest( () => new ClientRequest('dummyType', 'dummyArgs'));

      //then
      expect(response, completion(equals('dummyResponse')));
    });

    test('Arguments are passed to server correctly', () {
      // given
      remoteServer.delay = new Duration(seconds: 1);
      remoteServer.setResponse('dummyType', 'dummyArgs1', 'testvalue3');
      remoteServer.setResponse('dummyType', 'dummyArgs2', 'testvalue4');

      // when
      var res1 = connection.sendRequest( () => new ClientRequest('dummyType', 'dummyArgs1'));
      var res2 = connection.sendRequest( () => new ClientRequest('dummyType', 'dummyArgs2'));

      // then
      expect(res1,completion(equals('testvalue3')));
      expect(res2,completion(equals('testvalue4')));
    });

    test('Response is JSON decoded on arrival', () {
      // given
      remoteServer.setResponse('dummyType', 'dummyArgs', ['response1', 'response2']);

      // when
      var res = connection.sendRequest( () => new ClientRequest('dummyType', 'dummyArgs'));

      // then
      expect(res,completion(equals(['response1', 'response2'])));
    });


    test('Multiple Requests with same name can receive different response', () {
      // given
      remoteServer.setResponse('dummyType', 'dummyArgs1', 'response2');
      remoteServer.setResponse('dummyType', 'dummyArgs2', 'response3');

      // when
      var res1 = connection.sendRequest( () => new ClientRequest('dummyType', 'dummyArgs1'));
      var res2 = connection.sendRequest( () => new ClientRequest('dummyType', 'dummyArgs2'));

      // then
      expect(res1, completion(equals('response2')));
      expect(res2, completion(equals('response3')));
    });

    test('Multiple Requests can be sent in one request.', () {
      // given
      remoteServer.delay = new Duration(seconds: 1);
      remoteServer.setResponse('dummyType', 'dummyArgs1', 'response1');
      remoteServer.setResponse('dummyType', 'dummyArgs2', 'response2');
      remoteServer.setResponse('dummyType', 'dummyArgs3', 'response3');

      List logOfActions = new List();
      logAction(id) {
        print("Action $id");
        logOfActions.add(id);
      }

      // when
      var res1 = connection.sendRequest( () {
        logAction('req1');
        return new ClientRequest('dummyType', 'dummyArgs1');
      });
      var res2 = connection.sendRequest( () {
        logAction('req2');
        return new ClientRequest('dummyType', 'dummyArgs2');
      });
      var res3 = connection.sendRequest( () {
        logAction('req3');
        return new ClientRequest('dummyType', 'dummyArgs3');
      });

      // then
      var procesedRes1 = res1.then((_) => logAction('res1'));
      var procesedRes2 = res2.then((_) => logAction('res2'));
      var procesedRes3 = res3.then((_) => logAction('res3'));

      expect(res1,completion(equals('response1')));
      expect(res2,completion(equals('response2')));
      expect(res3,completion(equals('response3')));

      var finishedActions = Future.wait([procesedRes1,procesedRes2,procesedRes3])
          .then((_) => logOfActions);
      expect(finishedActions,completion(equals(['req1', 'res1','req2', 'req3', 'res2', 'res3'])));
    });

  });
}
