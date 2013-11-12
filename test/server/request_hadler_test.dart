// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:clean_backend/clean_backend.dart';
import 'package:unittest/mock.dart';
import 'dart:async';


void main() {

  group('RequestHandler', () {
    RequestHandler requestHandler;
    setUp(() {
      requestHandler = new RequestHandler();
      
    });
    
    
    test('empty request handler (T01).', () {

      // whenthen
      expect(()=> requestHandler.handleRequest('uknownRequest', {}), throws);
      
      // then
//      future.then( expectAsync1( (response) {
//        print("Response 1 arrived");
//        expect(response, equals('response1'));
//      }));
    });
    
    test('register executor (TO2).', () {
        
        //given 
        Future executor(request) => new Future.value({});
          
        // when
          var added = requestHandler.registerExecutor("dummy", executor);
          
        //then
          expect(added, isTrue);
          expect(requestHandler.isEmpty, isFalse);
    });
    
    test('unregister executor (TO3).', () {
      
      //given 
      Future executor(request) => new Future.value({});
      requestHandler.registerExecutor("dummy", executor);
      
      // when
      var removed = requestHandler.unregisterExecutor("dummy");
      
      //then
      expect(removed, isTrue);
      expect(requestHandler.isEmpty, isTrue);
    });
    
    test('handle registered handler (TO4).', () {
      
      //given 
      Future executor(request) => new Future.value({});
      requestHandler.registerExecutor("dummy", executor);
      
      // when
      var future = requestHandler.handleRequest("dummy", {"name": "dummy"});
      
      //then
      future.then( expectAsync1( (response) {
        expect(response, equals({}));
      }));
    });
    
    test('handle unknown request with default handler (TO5).', () {
      
      //given 
      Future executor(request) => new Future.value({});
      requestHandler.registerExecutor("", executor);
      
      // when
      var future = requestHandler.handleRequest("uknownRequest", {"name": "dummy"});
      
      //then
      future.then( expectAsync1( (response) {
        expect(response, equals({}));
      }));
    });
    
    test('handle unknown request without default handler (TO6).', () {
      
      //given 
      Future executor(request) => new Future.value({});
      requestHandler.registerExecutor("dummy", executor);
      
      // whenthen
      expect(()=> requestHandler.handleRequest('uknownRequest', {}), throws);
    });
    
    test('register second executor with same name (TO7).', () {
      
      //given 
      Future executor(request) => new Future.value({});
      Future executor2(request) => new Future.value({"response": "different to executor"}); 
      
      //when
      requestHandler.registerExecutor("dummy", executor);
      var added = requestHandler.registerExecutor("dummy", executor2);
      var future = requestHandler.handleRequest("dummy", {"name": "dummy"});
      
      // then
      expect(added, isFalse);
      future.then( expectAsync1( (response) {
        expect(response, equals({}));
      }));
    });
    
    
  });
  
  
 }
