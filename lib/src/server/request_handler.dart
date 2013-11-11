// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

typedef Future RequestExecutor(request);

class RequestHandler {

  final Map<String, RequestExecutor> _registeredExecutors = new Map();

  bool get isEmpty => _registeredExecutors.isEmpty;


  void serveHttpRequest(HttpRequest httpRequest) {
    HttpBodyHandler.processRequest(httpRequest).then((HttpBody body) {
      var json = JSON.decode(body.body);
      var packedRequests = decodeFromJson(json);

      _splitAndProcessRequests(packedRequests).then((response) {
        httpRequest.response
          ..headers.add("Access-Control-Allow-Origin", "*") // I do not know why this is needed
          ..headers.contentType = ContentType.parse("application/json")
          ..write(JSON.encode(response))
          ..close();
      }).catchError((e){
        print('Error: $e');
        httpRequest.response
          ..headers.add("Access-Control-Allow-Origin", "*") // I do not know why this is needed
          ..headers.contentType = ContentType.parse("application/json")
          ..statusCode = HttpStatus.BAD_REQUEST
          ..close();
      });
    });
  }

  Future<List> _splitAndProcessRequests(List<PackedRequest> requests) {
    Completer c = new Completer();

    final List responses = new List();

    //processingFunc will be function for processing one request
    var processingFunc = (PackedRequest request) => _handleClientRequest(request.clientRequest.type, request.clientRequest);

    //now you need to call on each element of requests function processingFunc
    //this calls are asynchronous but must run in seqencial order
    //results from calls are collected inside response
    //if you encounter error durig execution of any fuction run you end
    // execution all of next functions and complete returned future with error
    Future.forEach(
      requests,
      (request) => processingFunc(request)
          .then((response){
            print(response);
            responses.add({'id': request["id"], 'response': response});
            print("RESPONSE: ${response}");
          }))
    .then(
      (_)=>c.complete(responses))
    .catchError(
      (e)=> c.completeError(e));

    return c.future;
  }


 Future _handleClientRequest(String name, request){
   if(_registeredExecutors.containsKey(name)){
     return _registeredExecutors[name](request);
   }
   if(_registeredExecutors.containsKey('')){
     return _registeredExecutors[''](request);
   }
   return new Future.error("Unknow request");
 }

 bool registerExecutor(String name, RequestExecutor requestExecutor){
   if(_registeredExecutors.containsKey(name)){
     return false;
   }
   _registeredExecutors[name] = requestExecutor;
   return true;
 }

 bool unregisterExecutor(String name){
   if(!_registeredExecutors.containsKey(name)){
     return false;
   }
   _registeredExecutors.remove(name);
   return true;
 }
}
