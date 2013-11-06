// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

typedef HttpRequestFactory(String url, {String method, bool withCredentials,
  String responseType, String mimeType, Map<String, String> requestHeaders,
  sendData, void onProgress(e)});

typedef Request CreateRequest();

class Server {
  /**
   * RequestFactory is a function like HttpRequest.request() that returns
   * [Future<HttpRequest>].
   */
  final HttpRequestFactory _factory;

  /**
   * The URL where to perform requests.
   */
  final String _url;

  /**
   * Queue of unprepared [Request]s.
   * The map entry should contain these keys and values:
   *   'request': [Request] object
   *   'completer': [Completer] object which returns response for the request
   */
  final Queue<Map> _requestQueue = new Queue<Map>();

  /**
   * Indicates whether a [HttpRequest] is currently on the way.
   */
  bool _isRunning = false;

  /**
   * Creates a new [Server] with default [HttpRequestFactory]
   */
  factory Server(url) {
    return new Server.config(HttpRequest.request, url);
  }

  /**
   * Creates a new [Server] with specified [HttpRequestFactory]
   */
  Server.config(this._factory, this._url);

  /**
   * Maps [Request] names to their future responses.
   */
  final Map<int, Completer> _responseMap = new Map<int, Completer>();

  /**
   * Counts sent requests. Serves as unique ID for new requests.
   */
  int requestCount = 0;

  /**
   * Begins performing HttpRequest. Is not launched if another request is
   * already running or the request Queue is empty. Sets [_isRunning] as true
   * for the time this request is running and hooks up another request
   * after this one.
   */
  void performHttpRequest() {
    if (this._isRunning || this._requestQueue.isEmpty) {
      return;
    }
    this._isRunning = true;

    var request_list = new List();
    while (!this._requestQueue.isEmpty) {
      var map = this._requestQueue.removeFirst();
      var request = map['request'](); // create the request
      request_list.add({'id': requestCount, 'request': request});
      this._responseMap[requestCount++] = map['completer'];
    }

    this._factory(this._url, method: 'POST',
      sendData: JSON.encode(request_list)).then((xhr) {
        var list = JSON.decode(xhr.responseText);
        for (var responseMap in list) {
          var id = responseMap['id'];
          var response = responseMap['response'];
          if (this._responseMap.containsKey(id)) {
            this._responseMap[id].complete(response);
            this._responseMap.remove(id);
          }
        }
        this._responseMap.forEach((id, request) {
          throw new Exception("Request $id was not answered!");
        });
        this._isRunning = false;
        this.performHttpRequest();
      });
  }

  /**
   * Puts the Unprepared Request to queue.
   * Returns Future object that completes when the request receives response.
   */
  Future sendRequest(CreateRequest request) {
    var completer = new Completer();
    this._requestQueue.add({'request': request, 'completer': completer});
    this.performHttpRequest();
    return completer.future;
  }
}