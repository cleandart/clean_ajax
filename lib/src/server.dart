// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

typedef HttpRequestFactory(String url, {String method, bool withCredentials,
  String responseType, String mimeType, Map<String, String> requestHeaders, 
  sendData, void onProgress(e)});

typedef Request UnpreparedRequest();

class Server {
  /** 
   * RequestFactory is a function like HttpRequest.request() that returns 
   * [Future<HttpRequest>].
   */
  final HttpRequestFactory _factory;  
  
  /**
   * The URL where to perform requests.
   */
  String _url;
  
  /**
   * Queue of unprepared [Request]s.
   */
  final Queue<Map> _requestQueue = new Queue<Map>();
  
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
   * Maps [Request] names to their future responses.
   */
  final Map<String, Completer<Response>> _responseMap = 
      new Map<String, Completer<Response>>();
  
  /**
   * Begins performing HttpRequest. Stores the Future for this request 
   * completion as [_runningRequest] and sets [_isRunning] as true for the time 
   * this request is running.   
   */
  void performHttpRequest() {
    this._isRunning = true;
    this._responseMap.clear();
    var runCompleted = new Completer();
    this._runningRequest = runCompleted.future;
    var queue = this._requestQueue.toList();
    this._requestQueue.clear();   
    
    var request_map = new Map<String, String>();    
    for (Map map in queue) {
      var request = map['request']();
      var completer = map['completer'];
      var name = request.name;
      var content = request.content;
      request_map[name] = content.json;
      this._responseMap[name] = completer;
    }    
      
    this._factory(this._url, method: 'POST', 
      sendData: stringify(request_map)).then((xhr) {
        if (xhr.status == 200) {
          var list = parse(xhr.responseText);
          for (Map responseMap in list) {              
            var name = responseMap['name'];
            var jsonResponse = responseMap['response'];              
            var response = new Response(jsonResponse);              
            if (this._responseMap.containsKey(name)) {
              this._responseMap[name].complete(response);                
              this._responseMap.remove(name);
            } 
          }
          this._responseMap.forEach((name, request) {
            throw new Exception("Request <"+name+"> was not answered!");
          });
        } else {
          throw new Exception("Request completed with errors");
        }
        this._isRunning = false;
        runCompleted.complete();
      });  
  }  
  
  /**
   * Puts the UnpreparedRequest to queue.
   * Returns Future object that completes when the request receives response.
   */
  Future<Response> sendRequest(UnpreparedRequest request) {
    var completer = new Completer<Response>();
    var map = new Map();
    map['request'] = request;
    map['completer'] = completer;
    this._requestQueue.add(map);
    
    if (!this._isRunning) {
      this.performHttpRequest();
    } else if (this._requestQueue.length == 1) {
      this._runningRequest.then((event) => this.performHttpRequest()); 
    }
    return completer.future;
  }
}