// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Server side
 */
library clean_ajax.server;

import "dart:core";
import "dart:async";
import "dart:convert";
import 'dart:io';
import 'package:http_server/http_server.dart';

import 'package:clean_ajax/common.dart';
export 'package:clean_ajax/common.dart' show ClientRequest, PackedRequest;
import 'package:clean_backend/clean_backend.dart' show HttpRequestHandler;

typedef Future ClientRequestHandler(ClientRequest request);

typedef Future<HttpBody> HttpBodyExtractor(HttpRequest request);

/**
 * Exception thrown when a MultiRequestHandler can pass one of multiple
 * request to any handler
 */
class UnknownHandlerException implements Exception {
  /**
   * A message describing the format error.
   */
  final String message;

  /**
   * Creates a new FormatException with an optional error [message].
   */
  const UnknownHandlerException([this.message = ""]);

  String toString() => "UnknownHandlerException: $message";
}

class MultiRequestHandler implements HttpRequestHandler {

  final Map<String, ClientRequestHandler> _registeredExecutors = new Map();
  ClientRequestHandler _defaultExecutor = null;
  final HttpBodyExtractor httpBodyExtractor;

  MultiRequestHandler.config(this.httpBodyExtractor);

  factory MultiRequestHandler() => new MultiRequestHandler.config(HttpBodyHandler.processRequest);

  void handleHttpRequest(HttpRequest httpRequest) {
    httpBodyExtractor(httpRequest).then((HttpBody body) {
      var packedRequests = packedRequestsFromJson(JSON.decode(body.body));

      _splitAndProcessRequests(packedRequests).then((response) {
        httpRequest.response
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.OK
          ..write(JSON.encode(response))
          ..close();
      }).catchError((e){
        httpRequest.response
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.BAD_REQUEST
          ..close();
      },test: (e) => e is UnknownHandlerException);
    });
  }

  /**
   * Run asynchroniusly requests in order as they are presented in [requests]
   * and return list of processed results from each request.
   */
  Future<List> _splitAndProcessRequests(List<PackedRequest> requests) {
    final List responses = new List();

    //handlePackedRequest will be function for processing one request
    var handlePackedRequest = (PackedRequest request) => _handleClientRequest(request.clientRequest);

    //now you need to call on each element of requests function processingFunc
    //this calls are asynchronous but must run in seqencial order
    //results from calls are collected inside response
    //if you encounter error durig execution of any fuction run you end
    //execution all of next functions and complete returned future with error
    return Future.forEach(
             requests,
             (PackedRequest request) => handlePackedRequest(request)
                 .then((response){
                   //print("RESPONSE: ${response}");
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
       return new Future.error(new UnknownHandlerException(request.type));
     }
   }

   /**
    * Register default [RequestExecutor] for incomming [ClientRequest]
    * Default executor is called only if executor for [ClientRequest.type] is
    * not registerd.
    * Multiple registration cause exception.
    */
   void registerDefaultExecutor(ClientRequestHandler requestExecutor)
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
   void registerExecutor(String name, ClientRequestHandler requestExecutor){
     if(_registeredExecutors.containsKey(name)){
       throw new Exception("AlreadyRegistered");
     } else {
       _registeredExecutors[name] = requestExecutor;
     }
   }
}
