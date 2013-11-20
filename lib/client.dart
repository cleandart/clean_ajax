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
import "dart:convert";

import 'package:clean_ajax/common.dart';
export 'package:clean_ajax/common.dart' show ClientRequest;

typedef ClientRequest CreateRequest();

/**
 * Abstract representation of connection to server.
 */
class Connection {

  final Transport _transport;

  /**
   * Creates a new [Connection].
   */
  Connection.config(this._transport) {
    this._transport.setHandlers(_prepareRequest, _handleResponse);
  }

  /**
   * Queue of unprepared [ClientRequest]s.
   * The map entry should contain these keys and values:
   *   'createRequest': [CreateRequest] object
   *   'completer': [Completer] object which returns response for the request
   */
  final Queue<Map> _requestQueue = new Queue<Map>();

  /**
   * Maps [Request] names to their future responses.
   */
  final Map<int, Completer> _responseMap = new Map<int, Completer>();

  /**
   * Counts sent requests. Serves as unique ID for new requests.
   */
  int requestCount = 0;

  List<PackedRequest> _prepareRequest() {
    var request_list = [];
    while (!_requestQueue.isEmpty) {
      var map = _requestQueue.removeFirst();
      var clientRequest = map['createRequest'](); // create the request
      request_list.add(new PackedRequest(requestCount, clientRequest));
      _responseMap[requestCount++] = map['completer'];
    }
    return request_list;
  }

  void _handleResponse(List responses) {
    for (var responseMap in responses) {
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
  }

  /**
   * Puts the Unprepared Request to queue.
   * Returns Future object that completes when the request receives response.
   */
  Future sendRequest(CreateRequest createRequest) {
    var completer = new Completer();
    _requestQueue.add({'createRequest': createRequest, 'completer': completer});
    _transport.markDirty();
    return completer.future;
  }
}

abstract class Transport {
  dynamic _prepareRequest;
  dynamic _handleResponse;

  setHandlers(prepareRequest, handleResponse) {
    _prepareRequest = prepareRequest;
    _handleResponse = handleResponse;
  }

  void markDirty();
}

class HttpTransport extends Transport {
  /**
   * RequestFactory is a function like HttpRequest.request() that returns
   * [Future<HttpRequest>].
   */
  final _sendHttpRequest;

  /**
   * The URL where to perform requests.
   */
  final String _url;

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

  bool _isDirty;

  HttpTransport(this._sendHttpRequest, this._url, this._delayBetweenRequests);

  markDirty() {
    _isDirty = true;
    performRequest();
  }

  bool _shouldSendHttpRequest() {
    return !_isRunning &&
        _isDirty &&
        new DateTime.now().difference(_lastResponseTime) >= _delayBetweenRequests;
  }

  void _openRequest() {
    _isRunning = true;
    _isDirty = false;
  }

  void _closeRequest() {
    _isRunning = false;
    _lastResponseTime = new DateTime.now();
    new Timer(_delayBetweenRequests, performRequest);
  }

  /**
   * Begins performing HttpRequest. Is not launched if another request is
   * already running or the request Queue is empty. Sets [_isRunning] as true
   * for the time this request is running and hooks up another request
   * after this one.
   */
  void performRequest() {
    if (!_shouldSendHttpRequest()) {
      return;
    }

    _openRequest();

    _sendHttpRequest(
        _url,
        method: 'POST',
        sendData: JSON.encode(_prepareRequest())
    ).then((xhr) {
        _handleResponse(JSON.decode(xhr.responseText));
        _closeRequest();
    });
  }
}

  class LoopBackTransport extends Transport {
    /**
     * RequestFactory is a function like LoopBackRequest.request() that returns
     * [Future<LoopBackRequest>].
     */
    final _sendLoopBackRequest;

    /**
     * Indicates whether a [LoopBackRequest] is currently on the way.
     */
    bool _isRunning = false;



    bool _isDirty;

    LoopBackTransport(this._sendLoopBackRequest);

    markDirty() {
      _isDirty = true;
      performRequest();
    }

    bool _shouldSendLoopBackRequest() {
      return !_isRunning &&
          _isDirty;
    }

    void _openRequest() {
      _isRunning = true;
      _isDirty = false;
    }

    void _closeRequest() {
      _isRunning = false;
      performRequest();
    }

    /**
     * Begins performing HttpRequest. Is not launched if another request is
     * already running or the request Queue is empty. Sets [_isRunning] as true
     * for the time this request is running and hooks up another request
     * after this one.
     */
    void performRequest() {
      if (!_shouldSendLoopBackRequest()) {
        return;
      }

      _openRequest();

      _sendLoopBackRequest(
        _prepareRequest()
      ).then((response) {
        _handleResponse(response);
        _closeRequest();
    });
  }
}