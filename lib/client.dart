// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for efficient server-client communication that guarantees order of
 * requests and responses.
 *
 * ## Examples
 *
 * Following example demonstrate simple usage of connection in browser. It is
 * guaranteed that the first request finishes before the second.
 *
 *      import "package:clean_ajax/client_browser.dart";
 *
 *      var connection = createHttpConnection("http://www.example.com/api/",
 *                                            new Duration(milliseconds: 100));
 *
 *      connection.send(() => new ClientRequest("user/get", {"name": "John"}))
 *      .then((user) {
 *        showUserInfo(user);
 *      });
 *
 *      connection.send(() => new ClientRequest("user/get", {"name": "Peter"}))
 *      .then((user) {
 *        showUserInfo(user);
 *      });
 *
 * It can be handy to send some requests periodically, for example to check the
 * state of the email inbox.
 *
 *      import "package:clean_ajax/client_browser.dart";
 *
 *      var connection = createHttpConnection("http://www.example.com/api/",
 *                                            new Duration(milliseconds: 100));
 *
 *      connection.sendPeriodically(() => new ClientRequest("inbox/get", {}))
 *      .listen((inbox) {
 *        updateInbox(inbox);
 *      });
 *
 * Periodical requests are canceled simply by canceling the subscription to
 * results.
 *
 *      import "package:clean_ajax/client_browser.dart";
 *
 *      var connection = createHttpConnection("http://www.example.com/api/",
 *                                            new Duration(milliseconds: 100));
 *
 *      var subscription = connection.sendPeriodically(
 *          () => new ClientRequest("inbox/get", {})
 *      ).listen((inbox) {
 *        updateInbox(inbox);
 *      });
 *
 *      // Stop sending requests when the inbox is closed by the user.
 *      onInboxClose(() => subscription.cancel());
 *
 * Reusal of code on server is encouraged by [LoopBackTransport] layer, that
 * works on the server.
 *
 *      import "package:clean_ajax/client_backend.dart";
 *
 *      var connection = createLoopBackConnection(requestHandler);
 *
 *      connection.send(() => new ClientRequest("user/get", {"name": "John"}))
 *      .then((user) {
 *        showUserInfo(user);
 *      });
 *
 *      connection.send(() => new ClientRequest("user/get", {"name": "Peter"}))
 *      .then((user) {
 *        showUserInfo(user);
 *      });
 *
 * However, [sendPeriodically] is not supported by [LoopBackTransport], it is
 * not error to call it on the server, however it gets send only first time and
 * later times when normal [send] is triggered.
 *
 */
library clean_ajax.client;

import "dart:core";
import "dart:async";
import "dart:collection";
import "dart:convert";

import 'common.dart';
export 'common.dart' show ClientRequest;

typedef ClientRequest CreateRequest();

/**
 * Representation of connection to server.
 */
class Connection {

  final Transport _transport;

  /**
   * Dependency injection constructor of [Connection].
   *
   * In majority of cases, you want to use either [createHttpConnection] or
   * [createLoopBackConnection] factories from [clean_ajax.client_browser] and
   * [clean_ajax.client_backend] libraries.
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

  final Set<Map> _periodicRequests = new Set<Map>();

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
    for (var request in _periodicRequests) {
      send(request['createRequest']).then((value) {
        request['controller'].add(value);
      });
    }
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
   * Schedule the send of [ClientRequest] created by factory function
   * [createRequest].
   *
   * Request will be created immediately before the send, that makes it possible
   * to send always mostly actual requests.
   *
   * Returned [Future] completes with the value of response.
   */
  Future send(CreateRequest createRequest) {
    var completer = new Completer();
    _requestQueue.add({'createRequest': createRequest, 'completer': completer});
    _transport.markDirty();
    return completer.future;
  }

  /**
   * Schedule the [ClientRequest]s to be sent periodically and return the
   * [Stream] of responses.
   *
   * Every time the transport layer notifies [Connection] about being ready to
   * send next request, [createRequest] is executed and resulting
   * [ClientRequest] is send.
   *
   * Similarly to [send], this method will notify the transport layer there is
   * request to be sent. This notification happens only as direct consequence
   * of calling [sendPeriodically], it won't happen multiple times for single
   * [createRequest] factory.
   *
   * The returned [Stream] can have only single listener, and periodical
   * requests are canceled when the subscription to results [Stream] is
   * canceled.
   */
  Stream sendPeriodically(CreateRequest createRequest) {
    var periodicRequest = {'createRequest': createRequest};
    var streamController = new StreamController(
        onCancel: () => _periodicRequests.remove(periodicRequest));
    periodicRequest['controller'] = streamController;
    _periodicRequests.add(periodicRequest);
    _transport.markDirty();
    return streamController.stream;
  }
}

/**
 * Interface implemented by various transport mechanisms used by [Connection]
 * like [HttpTransport] and [LoopBackTransport].
 */
abstract class Transport {
  dynamic _prepareRequest;
  dynamic _handleResponse;

  setHandlers(prepareRequest, handleResponse) {
    _prepareRequest = prepareRequest;
    _handleResponse = handleResponse;
  }

  void markDirty();
}

/**
 * Transport mechanism using ajax polling used by [createHttpConnection].
 */
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
  markDirty() {}

  /**
   * Marks timer as disposed, which prevents him from future sending of http
   * requests.
   */
  dispose() {
    if(_timer != null) _timer.cancel();
  }

  bool _shouldSendHttpRequest() => !_isRunning;

  void _openRequest() {
    _isRunning = true;
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
    var data = _prepareRequest();
    if (data.isEmpty) return;

    _openRequest();
    _sendHttpRequest(
        _url,
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: JSON.encode(data)
    ).then((xhr) {
        _handleResponse(JSON.decode(xhr.responseText));
        _closeRequest();
    });
  }
}
/**
 * Transport mechanism used on server, that directly uses [RequestHandler],
 * used by [createLoopBackConnection].
 */
class LoopBackTransport extends Transport {
  /**
   * RequestFactory is a function like LoopBackRequest.request() that returns
   * [Future<LoopBackRequest>].
   */
  final _sendLoopBackRequest;

  /**
   * Id of the user currently authenticated.
   */
  final _authenticatedUserId;

  /**
   * Indicates whether a [LoopBackRequest] is currently on the way.
   */
  bool _isRunning = false;

  bool _isDirty;

  LoopBackTransport(this._sendLoopBackRequest, [this._authenticatedUserId = null]);

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

    _sendLoopBackRequest(_prepareRequest(), _authenticatedUserId)
      .then((response) {
        _handleResponse(response);
        _closeRequest();
      });
  }
}
