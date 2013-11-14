// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Client side
 */
library clean_ajax.client;

import "dart:core";
import "dart:async";
import "dart:collection";
import "dart:html";
import "dart:convert";

import 'package:clean_ajax/common.dart';
export 'package:clean_ajax/common.dart' show ClientRequest;

typedef HttpRequestFactory(String url, {String method, bool withCredentials,
  String responseType, String mimeType, Map<String, String> requestHeaders,
  sendData, void onProgress(e)});

typedef ClientRequest CreateRequest();

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
   * Queue of unprepared [ClientRequest]s.
   * The map entry should contain these keys and values:
   *   'createRequest': [CreateRequest] object
   *   'completer': [Completer] object which returns response for the request
   */
  final Queue<Map> _requestQueue = new Queue<Map>();

  /**
   * Indicates whether a [HttpRequest] is currently on the way.
   */
  bool _isRunning = false;

  /**
   * Indicate time when last response come
   */
  DateTime _lastResponseTime = new DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /**
   * Duration of pause between two http requests.
   */
  Duration _delayBetweenRequests;

  /**
   * Creates a new [Server] with default [HttpRequestFactory]
   */
  factory Server(url, Duration delayBetweenRequests) {
    return new Server.config(HttpRequest.request, url, delayBetweenRequests);
  }

  /**
   * Creates a new [Server] with specified [HttpRequestFactory]
   */
  Server.config(this._factory, this._url, this._delayBetweenRequests);

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
    if (_isRunning || _requestQueue.isEmpty ||
        new DateTime.now().difference(_lastResponseTime) < _delayBetweenRequests) {
      return;
    }

    _isRunning = true;
    var request_list = new List();
    while (!_requestQueue.isEmpty) {
      var map = _requestQueue.removeFirst();
      var clientRequest = map['createRequest'](); // create the request
      request_list.add(new PackedRequest(requestCount, clientRequest));
      _responseMap[requestCount++] = map['completer'];
    }

    _factory(_url, method: 'POST',
      sendData: JSON.encode(request_list)).then((xhr) {
        var list = JSON.decode(xhr.responseText);
        for (var responseMap in list) {
          var id = responseMap['id'];
          var response = responseMap['response'];
          if (_responseMap.containsKey(id)) {
            _responseMap[id].complete(response);
            _responseMap.remove(id);
          }
        }
        _responseMap.forEach((id, request) {
          throw new Exception("Request $id was not answered!");
        });
        _isRunning = false;
        _lastResponseTime = new DateTime.now();
        new Timer(_delayBetweenRequests, performHttpRequest);
    });
  }

  /**
   * Puts the Unprepared Request to queue.
   * Returns Future object that completes when the request receives response.
   */
  Future sendRequest(CreateRequest createRequest) {
    var completer = new Completer();
    _requestQueue.add({'createRequest': createRequest, 'completer': completer});
    performHttpRequest();
    return completer.future;
  }
}
