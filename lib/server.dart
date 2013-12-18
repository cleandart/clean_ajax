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
import 'package:clean_backend/clean_backend.dart' show Request;


import 'common.dart';
export 'common.dart' show PackedRequest;

/**
 * Type of handler which can be registered in [MultiRequestHandler] for
 * processing [ServerRequest]
 */
typedef Future ServerRequestHandler(ServerRequest request);

/**
 * Helper type function extracting [HttpBody] from [HttpRequest]
 */
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

/**
 * Exception thrown when a you try register second default handler or
 * handler under same name.
 */
class AlreadyRegisteredHandlerException implements Exception {
  /**
   * A message describing the format error.
   */
  final String message;

  /**
   * Creates a new FormatException with an optional error [message].
   */
  const AlreadyRegisteredHandlerException([this.message = ""]);

  String toString() => "Handler aready registed under name: $message";
}

/**
 * Class which can process multiple [ClientRequest] send in one [HttpRequest].
 * Is responsible for unpacking [HttpRequest] and calling aproriate handler which
 * has been registered inside it.
 */
class MultiRequestHandler {

  /**
   * List of handlers for [ClientRequest]. Index is matching with
   * [ClientRequest.type]
   */
  final Map<String, ServerRequestHandler> _registeredExecutors = new Map();
  /**
   * Default handler form [ClientRequest]
   */
  ServerRequestHandler _defaultExecutor = null;



  /**
   * Process [HttpRequest] extract from it [HttpBody]
   * then extract [PackedRequest]s process them and generate proper
   * [HttpResponse]
   */
  void handleHttpRequest(Request request) {
    if (request.type != 'json') {
      throw new Exception('Request type is ${request.type}, '
                          'json was expected!');
    }
    List<PackedRequest> packedRequests =
//        packedRequestsFromJson(JSON.decode(request.body));
        packedRequestsFromJson(request.body);
    // decorate individual clientRequests with authenticatedUserId property

    _splitAndProcessRequests(packedRequests, request.authenticatedUserId)
      .then((response) {
        request.response
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.OK
          ..write(JSON.encode(response))
          ..close();
      }).catchError((e){
        request.response
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.BAD_REQUEST
          ..close();
      },test: (e) => e is UnknownHandlerException);
  }

  Future<List> handleLoopBackRequest(List<PackedRequest> requests,
                                     authenticatedUserId) {
    return _splitAndProcessRequests(requests, authenticatedUserId);
  }

  /**
   * Run asynchroniusly [PackedRequest]s in order as they are presented in [requests]
   * and return list of processed results from each request.
   */
  Future<List> _splitAndProcessRequests(List<PackedRequest> requests,
                                        authenticatedUserId) {
    
    final List responses = new List();
    //now you need to call on each element of requests function _handleClientRequest
    //this calls are asynchronous but must run in sequencial order
    //results from calls are collected inside response
    //if you encounter error during execution of any fuction run you end
    //execution of all next functions and complete future result with error
    return Future.forEach(
             requests,
             (PackedRequest request) {
               // Create new server request from packed request and add
               // authenticatedUserId to it
                 ServerRequest serverRequest = new ServerRequest(request.clientRequest.type,
                                                                 request.clientRequest.args,
                                                                 authenticatedUserId);
                 
                 _handleClientRequest(serverRequest).then(
                     (response) {
                       responses.add({'id': request.id, 'response': response});
                 });
             }
           ).then((_)=>new Future.value(responses));
  }

  /**
   * Try to find which handler should execute [ClientRequest].
   * If for [ClientRequest.type] is not not registered any executor than will
   * try to run default executor if presented. In other cases throws
   * exception [UnknownHandlerException].
   */
   Future _handleClientRequest(ServerRequest request){
     if(_registeredExecutors.containsKey(request.type)){
       return _registeredExecutors[request.type](request);
     } else if(_defaultExecutor != null) {
       return _defaultExecutor(request);
     } else {
       return new Future.error(new UnknownHandlerException(request.type));
     }
   }

   /**
    * Register default [ClientRequestHandler] for incomming [ClientRequest]
    * Default executor is called only if executor for [ClientRequest.type] is
    * not registerd.
    * Multiple registration cause exception [AlreadyRegisteredHandlerException].
    */
   void registerDefaultHandler(ServerRequestHandler requestExecutor)
   {
     if (_defaultExecutor == null) {
       _defaultExecutor = requestExecutor;
     } else {
       throw new AlreadyRegisteredHandlerException("");
     }
   }

   /**
    * Register [ClientRequestHandler] for incomming [ClientRequest] with
    * [ClientRequest.type] setted to [name]. Multiple registration for
    * same [name] cause exception [AlreadyRegisteredHandlerException].
    */
   void registerHandler(String name, ServerRequestHandler requestExecutor){
     if(_registeredExecutors.containsKey(name)){
       throw new AlreadyRegisteredHandlerException(name);
     } else {
       _registeredExecutors[name] = requestExecutor;
     }
   }
}

class ServerRequest {
  final dynamic args;
  final String type;
  String authenticatedUserId;

  /**
   * Creates a [ServerRequest] with specified [type] and [args]
   * [type] is the name of the requested server function
   * [args] is a map of arguments for the specified server function
   */
  ServerRequest(this.type, this.args, this.authenticatedUserId);

  /**
   * Create a [ServerRequest] from JSON map {'name' : something, 'args': somethingElse}
   */
//  factory ServerRequest.fromJson(Map data) => new ServerRequest(data['type'], data['args']);

  /**
   * Converts this [ServerRequest] to JSON serializable map.
   */
  Map toJson() => {'type': type, 'args': args, 'authenticatedUserId': authenticatedUserId};
}


