// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:unittest/html_config.dart';
import 'package:clean_server/clean_server.dart';
import 'dart:async';

class MockHttpRequestFactory extends Mock implements HttpRequestFactory {
  
  dynamic createRequest() {
    return new MockHttpRequest();
  }
}

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
}

class MockDelayedHttpRequestFactory extends Mock implements HttpRequestFactory {
  dynamic createRequest() {
    return new MockDelayedHttpRequest();
  }
}

class MockDelayedHttpRequest  {
  static var _responseText;

  StreamController _loadStream;
  Stream onLoad;

  MockDelayedHttpRequest() {
    _loadStream = new StreamController.broadcast();
    onLoad = _loadStream.stream;
  }

  static stubResponseTextWith(v) => _responseText = v;
  get responseText => _responseText;
  get status => 200;

  open(_a, _b, {async, user, password}) {}
  
  send(request) {
    Timer timer = new Timer(new Duration(seconds: 1), () {
      _loadStream.add(this);
    });
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
    MockDelayedHttpRequestFactory delayedFactory;
    setUp(() {
      delayedFactory = new MockDelayedHttpRequestFactory();
      server = new Server.withFactory(new MockHttpRequestFactory());
      delayedserver = new Server.withFactory(delayedFactory);      
    });
    
    test('Single Request receives a response', () {
      MockHttpRequest.stubResponseTextWith('[{"name": "name", "response": "response"}]');      
      
      server.prepareRequest().then( (request) {
        return request.send('name', new RequestContent(""));
      }).then( expectAsync1( (response) {
        expect(response.json, equals('response'));
      }));
    });
    
    test('Multiple Requests with same name can receive different response', () {
      MockHttpRequest.stubResponseTextWith('[{"name": "name", "response": "response2"}]');
      
      server.prepareRequest().then( (request) {
        return request.send('name', new RequestContent(""));
      }).then( expectAsync1((response) {
          expect(response.json, equals('response2'));
      }));
    });
    
    test('Multiple Requests can be sent in one shot (see sent/arrived order in log in DartEditor)', () {      
      MockDelayedHttpRequest.stubResponseTextWith('[{"name": "name1", "response": "response1"}, {"name": "name2", "response": "response2"}, {"name": "name3", "response": "response3"}]');
      delayedserver.prepareRequest().then( (request) {
        print("Request 1 sent");
        return request.send('name1', new RequestContent(""));
      }).then( expectAsync1((response) {
          print("Response 1 arrived");
          expect(response.json, equals('response1'));
      }));            
      
      delayedserver.prepareRequest().then( (request) {
        print("Request 2 sent");
        return request.send('name2', new RequestContent(""));        
      }).then( expectAsync1((response) {
          print("Response 2 arrived");
          expect(response.json, equals('response2'));
      }));
      
      delayedserver.prepareRequest().then( (request) {
        print("Request 3 sent");
        return request.send('name3', new RequestContent(""));
      }).then( expectAsync1((response) {
          print("Response 3 arrived");
          print(delayedFactory.log);
          expect(response.json, equals('response3'));
      }));
      
    });
    
  });
}
