// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class Server {
  /**
   * The factory to create Http Requests.
   * Factory must implement [HttpRequestFactory] class and provide function
   * createRequest();
   */
  HttpRequestFactory _factory;
  
  /**
   * The URL where to perform requests.
   */
  String _url;
  
  /**
   * Queue of unprepared [Request]s.
   */
  Queue<Request> _requestQueue;
  
  /**
   * Indicates whether a [HttpRequest] is currently on the way.
   */
  bool _isRunning = false;
  
  /**
   * Indicates whether another [HttpRequest] is currently scheduled. 
   */
  bool _scheduled = false;
  
  /**
   * Future for the current running [HttpRequest]
   */
  Future _runningRequest;
  
  /**
   * Creates a new [Server] with default [HttpRequestFactory]
   */
  Server() {
    this._requestQueue = new Queue<Request>();
    this._factory = new HttpRequestFactory();    
  }
  
  /**
   * Creates a new [Server] with specified [HttpRequestFactory]
   */
  Server.withFactory(this._factory) {
    this._requestQueue = new Queue<Request>();
  }
  
  /**
   * Maps sent [Request] names to requests.
   */
  Map<String, Request> _requestMap;
  
  /**
   * Begins performing HttpRequest. Stores the Future for this request 
   * completion as [_runningRequest] and sets [_isRunning] as true for the time 
   * this request is running.   
   */
  void performHttpRequest() {    
    this._isRunning = true;
    this._requestMap = new Map<String, Request>();
    Completer runCompleted = new Completer();
    this._runningRequest = runCompleted.future;
    List<Request> queue = this._requestQueue.toList();
    this._requestQueue.clear();
    Queue<Future> contentqueue = new Queue<Future>();
    Completer<Response> responseCompleter = new Completer<Response>();    
    
    for (Request request in queue) {
        contentqueue.add(request.requestContent());
    }
    
    Future.wait(contentqueue).then( (list) {
      Map<String, String> request_map = new Map<String, String>();
      for (Request request in queue) {
        String name = request.name;
        RequestContent content = request.content;
        request_map[name] = content.json;
        this._requestMap[name] = request;
      }
      
      var xhr = this._factory.createRequest();
      xhr.open('POST', this._url, async: true);
      xhr.onLoad.listen((event) {
        if (xhr.status == 200) {
          // the request completed successfully
          List list = parse(xhr.responseText);
          for (Map responseMap in list) {
            String name = responseMap['name'];
            String jsonResponse = responseMap['response'];
            Response response = new Response(jsonResponse);
            if (this._requestMap.containsKey(name)) {
              this._requestMap[name].completeRequest(response);            
              this._requestMap.remove(name);
            }
          }
          this._requestMap.forEach((name, request) {
            request.completeRequest(null);
          });
        } else {
          // the request resulted in an error, we raise an exception
          throw new Exception("Request completed with errors");
        }        

        this._isRunning = false;
        runCompleted.complete();        
      });
      
      // the request data is sent JSON encoded
      xhr.send(stringify(request_map));
    });
  }
  
  /**
   * Creates a new [Request] and puts it in queue.
   * Returns Future object that completes when the request is about to be sent 
   */
  Future<Request> prepareRequest() {
    Completer<Request> completer = new Completer<Request>();
    Request request = new Request(completer);
    this._requestQueue.add(request);
    
    if (!this._isRunning) {
      this.performHttpRequest();
    } else if (!this._scheduled) {
      this._runningRequest.then((event) => this.performHttpRequest());      
      this._scheduled = true;
    }
    
    return completer.future;
  }
}
