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
   * Time interval between response to a request is received and next request
   * is sent.
   */
  Duration _delayBetweenRequests;

  /**
   * _isDirty is true iff there is some request to be sent.
   */
  bool _isDirty;

  /**
   * If set to true, this instance stops sending http requests.
   */
  bool _disposed = false;
  
  Timer _timer;
  
  HttpTransport(this._sendHttpRequest, this._url, this._delayBetweenRequests);
  
  
  setHandlers(prepareRequest, handleResponse) {
    super.setHandlers(prepareRequest, handleResponse);
    _timer = new Timer.periodic(this._delayBetweenRequests, (_) => _performRequest());
  }
  
  /**
   * Notifies [HttpTransport] instance that there are some requests to be sent
   * and attempts to send them immediately. If a HttpRequest is already running,
   * the new requests will be sent in next "iteration" (after response is
   * received + time interval _delayBetweenRequests passes).
   */
  markDirty() {
    _isDirty = true;
  }

  /**
   * Marks timer as disposed, which prevents him from future sending of http
   * requests.
   */
  dispose() {
    _disposed = true;
    if(_timer != null) {
      _timer.cancel();
    }
  }

  bool _shouldSendHttpRequest() {
    return !_isRunning && _isDirty && !_disposed;
  }

  void _openRequest() {
    _isRunning = true;
    _isDirty = false;
  }

  void _closeRequest() {
    _isRunning = false;
  }

  /**
   * Begins performing HttpRequest. Is not launched if another request is
   * already running ([_isRunning] is true) or the request Queue is empty,
   * ([_isDirty] is false). Sets [_isRunning] as true for the time this request
   * is running and hooks up another request after this one with a delay of
   * [_delayBetweenRequests].
   */
  void _performRequest() {
    if (!_shouldSendHttpRequest()) {
      return;
    }
    _openRequest();
    _sendHttpRequest(
        _url,
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
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
     * Begins performing LoopBackRequest. Is not launched if another request is
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
