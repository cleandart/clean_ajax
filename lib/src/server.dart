// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

typedef HttpRequestFactory(String url, {String method, bool withCredentials,
  String responseType, String mimeType, Map<String, String> requestHeaders, 
  sendData, void onProgress(e)});

class Server {
  /** 
   * RequestFactory is a function like HttpRequest.request() that returns 
   * Future<HttpRequest>.
   */
  final HttpRequestFactory _factory;
  
  /**
   * The URL where to perform requests.
   */
  String _url;
  
  /**
   * Queue of unprepared [Request]s.
   */
  final Queue<Request> _requestQueue = new Queue<Request>();
  
  /**
   * Indicates whether a [HttpRequest] is currently on the way.
   */
  bool _isRunning = false;  
  
  /**
   * Future for the current running [HttpRequest]
   */
  Future _runningRequest;
  
  /**
   * Creates a new [Server] with default [HttpRequestFactory]
   */
  factory Server() {
    return new Server.withFactory(HttpRequest.request);        
  }
  
  /**
   * Creates a new [Server] with specified [HttpRequestFactory]
   */
  Server.withFactory(this._factory);
  
  /**
   * Maps sent [Request] names to requests.
   */
  Map<String, Request> _requestMap = new Map<String, Request>();
  
  /**
   * Begins performing HttpRequest. Stores the Future for this request 
   * completion as [_runningRequest] and sets [_isRunning] as true for the time 
   * this request is running.   
   */
  void performHttpRequest() {
    this._isRunning = true;
    this._requestMap.clear();
    var runCompleted = new Completer();
    this._runningRequest = runCompleted.future;
    var queue = this._requestQueue.toList();
    this._requestQueue.clear();
    var contentqueue = new Queue<Future>();
    Completer<Response> responseCompleter = new Completer<Response>();    
    
    for (Request request in queue) {
        contentqueue.add(request.requestContent());
    }
    
    Future.wait(contentqueue).then( (list) {
      var request_map = new Map<String, String>();
      for (Request request in queue) {
        var name = request.name;
        var content = request.content;
        request_map[name] = content.json;
        this._requestMap[name] = request;
      }
      
      this._factory(this._url, method: 'POST', 
        sendData: stringify(request_map)).then((xhr) {
          if (xhr.status == 200) {
            var list = parse(xhr.responseText);            
            for (Map responseMap in list) {              
              var name = responseMap['name'];
              var jsonResponse = responseMap['response'];              
              var response = new Response(jsonResponse);              
              if (this._requestMap.containsKey(name)) {
                this._requestMap[name].completeRequest(response);                
                this._requestMap.remove(name);
              } 
            }
            this._requestMap.forEach((name, request) {
              throw new Exception("Request <"+name+"> was not answered!");
            });
          } else {
            throw new Exception("Request completed with errors");
          }
          this._isRunning = false;
          runCompleted.complete();
        });      
    });
  }
  
  /**
   * Creates a new [Request] and puts it in queue.
   * Returns Future object that completes when the request is about to be sent 
   */
  Future<Request> prepareRequest() {
    var completer = new Completer<Request>();
    var request = new Request(completer);
    this._requestQueue.add(request);
    
    if (!this._isRunning) {
      this.performHttpRequest();
    } else if (this._requestQueue.length == 1) {
      this._runningRequest.then((event) => this.performHttpRequest());
    }
    
    return completer.future;
  }
}
