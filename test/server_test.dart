// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:unittest/html_config.dart';
import 'package:clean_server/clean_server.dart';
import "dart:collection";
import 'dart:async';
import 'dart:convert';

class MockHttpRequest {
  static var _responseText;

  StreamController _loadStream;
  Stream onLoad;

  MockHttpRequest() {
    _loadStream = new StreamController.broadcast();
    onLoad = _loadStream.stream;
  }

  static stubResponseTextWith(v) => _responseText = v;
  get responseText => _responseText;
  get status => 200;

  open(_a, _b, {async, user, password}) {}
  send(request) => _loadStream.add(this);

  static request(String url, {String method, bool withCredentials,
      String responseType, String mimeType, Map<String, String> requestHeaders,
      sendData, void onProgress(e)}) {
    var completer = new Completer<MockHttpRequest>();
    var xhr = new MockHttpRequest();
    if (method == null) {
      method = 'GET';
    }
    xhr.open(method, url, async:true);

    xhr.onLoad.listen((e) {
      completer.complete(xhr);
    });

    xhr.send(sendData);

    return completer.future;
  }
}

class MockDelayedHttpRequest extends MockHttpRequest {
  static get stubResponseTextWith => MockHttpRequest.stubResponseTextWith;

  send(request) {
    Timer timer = new Timer(new Duration(seconds: 1), () {
      _loadStream.add(this);
    });
  }

  static request(String url, {String method, bool withCredentials,
    String responseType, String mimeType, Map<String, String> requestHeaders,
    sendData, void onProgress(e)}) {
    var completer = new Completer<MockDelayedHttpRequest>();
    var xhr = new MockDelayedHttpRequest();
    if (method == null) {
      method = 'GET';
    }
    xhr.open(method, url, async:true);

    xhr.onLoad.listen((e) {
      completer.complete(xhr);
    });

    xhr.send(sendData);

    return completer.future;
  }
}

class MockArgumentedHttpRequest extends MockHttpRequest {
  static get stubResponseTextWith => MockHttpRequest.stubResponseTextWith;

  send(request) {
    var response = new List();
    for (var singleRequest in JSON.decode(request)) {
      response.add({'id': singleRequest['id'], 'response': singleRequest['request']['args']['argument']});
    }
    stubResponseTextWith(JSON.encode(response));
    _loadStream.add(this);
  }

  static request(String url, {String method, bool withCredentials,
    String responseType, String mimeType, Map<String, String> requestHeaders,
    sendData, void onProgress(e)}) {
    var completer = new Completer<MockArgumentedHttpRequest>();
    var xhr = new MockArgumentedHttpRequest();
    if (method == null) {
      method = 'GET';
    }
    xhr.open(method, url, async:true);

    xhr.onLoad.listen((e) {
      completer.complete(xhr);
    });

    xhr.send(sendData);

    return completer.future;
  }
}

void main() {
  useHtmlConfiguration();
  test_server();
}

void test_server() {
  group('Server', () {

    Server server;
    Server delayedserver;
    Server parsingserver;
    setUp(() {
      server = new Server.config(MockHttpRequest.request, 'localhost');
      delayedserver = new Server.config(MockDelayedHttpRequest.request, 'localhost');
      parsingserver = new Server.config(MockArgumentedHttpRequest.request, 'localhost');
    });

    test('Single Request receives a response', () {
      MockHttpRequest.stubResponseTextWith('[{"id": 0, "response": "response"}]');

      server.sendRequest( () => new Request('name1', {}))
        .then( expectAsync1( (response) {
          expect(response, equals('response'));
      }));
    });


    test('Multiple Requests with same name can receive different response', () {
      MockHttpRequest.stubResponseTextWith('[{"id": 0, "response": "response2"}, {"id": 1, "response": "response3"}]');

      server.sendRequest( () => new Request('name', {}))
        .then( expectAsync1( (response) {
          expect(response, equals('response2'));
      }));

      server.sendRequest( () => new Request('name', {}))
        .then( expectAsync1( (response) {
          expect(response, equals('response3'));
      }));
    });

    test('Multiple Requests can be sent in one shot (see sent/arrived order in log in DartEditor)', () {
      MockDelayedHttpRequest.stubResponseTextWith('[{"id": 0, "response": "response1"}, {"id": 1, "response": "response2"}, {"id": 2, "response": "response3"}]');

      delayedserver.sendRequest( () {
        print("Request 1 sent");
        return new Request('name1', {});
      }).then( expectAsync1( (response) {
        print("Response 1 arrived");
        expect(response, equals('response1'));
      }));

      delayedserver.sendRequest( () {
        print("Request 2 sent");
        return new Request('name2', {});
      }).then( expectAsync1( (response) {
        print("Response 2 arrived");
        expect(response, equals('response2'));
      }));

      delayedserver.sendRequest( () {
        print("Request 3 sent");
        return new Request('name3', {});
      }).then( expectAsync1( (response) {
        print("Response 3 arrived");
        expect(response, equals('response3'));
      }));

    });

    test('Response is JSON decoded on arrival', () {
      MockHttpRequest.stubResponseTextWith('[{"id": 0, "response": ["response1", "response2"]}]');

      server.sendRequest( () => new Request('name1', {}))
        .then( expectAsync1( (response) {
          expect(response, equals(["response1", "response2"]));
      }));
    });

    test('Arguments are passed to server correctly', () {
      parsingserver.sendRequest( () => new Request('name', {'argument': 'testvalue1'}))
        .then( expectAsync1( (response) {
          expect(response, equals('testvalue1'));
      }));

      parsingserver.sendRequest( () => new Request('name', {'argument': 'testvalue2'}))
        .then( expectAsync1( (response) {
          expect(response, equals('testvalue2'));
      }));
    });

  });
}
