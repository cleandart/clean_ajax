// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Server side
 */
library clean_server;

import "dart:core";
import "dart:async";
import "dart:convert";
import 'dart:io';
import 'package:http_server/http_server.dart';

import 'package:clean_ajax/common.dart';
export 'package:clean_ajax/common.dart' show ClientRequest, PackedRequest;

typedef Future RequestExecutor(ClientRequest request);
typedef Future<HttpBody> HttpBodyExtractor(HttpRequest request);

class RequestHandler {

  final Map<String, RequestExecutor> _registeredExecutors = new Map();
  RequestExecutor _defaultExecutor = null;
  final HttpBodyExtractor httpBodyExtractor;

  RequestHandler.config(this.httpBodyExtractor);

  factory RequestHandler() => new RequestHandler.config(HttpBodyHandler.processRequest);

  void serveHttpRequest(HttpRequest httpRequest) {
    httpBodyExtractor(httpRequest).then((HttpBody body) {
      var packedRequests = createPackedRequestsfromJson(JSON.decode(body.body));

      _splitAndProcessRequests(packedRequests).then((response) {
        httpRequest.response
          ..headers.add("Access-Control-Allow-Origin", "*") // I do not know why this is needed
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.OK
          ..write(JSON.encode(response))
          ..close();
      }).catchError((e){
        print('Found unknown request:$e');
        httpRequest.response
          ..headers.add("Access-Control-Allow-Origin", "*") // I do not know why this is needed
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.BAD_REQUEST
          ..close();
      });
    });
  }

  void _serveBody(HttpBody body,HttpResponse httpResponse)
  {

  }

  /**
   * Run asynchroniusly requests in order as they are presented in [requests]
   * and return list of processed results from each request.
   */
  Future<List> _splitAndProcessRequests(List<PackedRequest> requests) {
    final List responses = new List();

    //handlePackedRequest will be function for processing one request
    var _handlePackedRequest = (PackedRequest request) => _handleClientRequest(request.clientRequest);

    //now you need to call on each element of requests function processingFunc
    //this calls are asynchronous but must run in seqencial order
    //results from calls are collected inside response
    //if you encounter error durig execution of any fuction run you end
    //execution all of next functions and complete returned future with error
    return Future.forEach(
             requests,
             (PackedRequest request) => _handlePackedRequest(request)
                 .then((response){
                   print("RESPONSE: ${response}");
                   responses.add({'id': request.id, 'response': response});
                 })
           ).then((_)=>new Future.value(responses));
  }

  /**
   * Try to find which executor should handle [ClientRequest].
   * If for [ClientRequest.type] is not not registered any executor than will
   * try to run default executor if presented. In other cases throws exception.
   */
   Future _handleClientRequest(ClientRequest request){
     if(_registeredExecutors.containsKey(request.type)){
       return _registeredExecutors[request.type](request);
     } else if(_defaultExecutor != null) {
       return _defaultExecutor(request);
     } else {
       return new Future.error("${request.type}");
     }
   }

   /**
    * Register default [RequestExecutor] for incomming [ClientRequest]
    * Default executor is called only if executor for [ClientRequest.type] is
    * not registerd.
    * Multiple registration cause exception.
    */
   void registerDefaultExecutor(RequestExecutor requestExecutor)
   {
     if (_defaultExecutor == null) {
       _defaultExecutor = requestExecutor;
     } else {
       throw new Exception("AlreadyRegistered");
     }
   }

   /**
    * Register [RequestExecutor] for incomming [ClientRequest] with
    * [ClientRequest.type] setted to [name].
    * Multiple registration for same [name] cause exception.
    */
   void registerExecutor(String name, RequestExecutor requestExecutor){
     if(_registeredExecutors.containsKey(name)){
       throw new Exception("AlreadyRegistered");
     } else {
       _registeredExecutors[name] = requestExecutor;
     }
   }
}

