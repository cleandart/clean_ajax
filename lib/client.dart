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
import 'dart:math';
import "package:logging/logging.dart";

import 'common.dart';

export 'common.dart' show ClientRequest;

final logger = new Logger('clean_ajax');

/**
 * Exception thrown when the server does not respond to request or responds
 * with HTTP error code.
 */
class FailedRequestException implements Exception {
  const FailedRequestException();
  String toString() => "FailedRequestException";
}

class CancelError implements Exception {
  const CancelError();
  String toString() => "CancelError";
}

class ConnectionError extends Error {
  var event;
  ConnectionError(this.event);
}

class ResponseError extends Error {
  var event;
  ResponseError(this.event);
}

typedef ClientRequest CreateRequest();

/**
 * Representation of connection to server.
 */
class Connection {

  /**
   * Flag which marks whether there are problems with connection or no.
   * If this is false, automatic checker starts sending requests and when
   * a response arrives, then it is set back to true.
   */
  bool _connected = true;

  bool get isConnected => _connected;

  StreamController _onDisconnectedController = new StreamController.broadcast();
  StreamController _onConnectedController = new StreamController.broadcast();

  Stream get onDisconnected => _onDisconnectedController.stream;
  Stream get onConnected => _onConnectedController.stream;

  void _disconnect() {
    _connected = false;
    _onDisconnectedController.add(null);
  }

  void _reconnect() {
    _connected = true;
    _onConnectedController.add(null);
  }

  String _authenticatedUserId;

  String get authenticatedUserId => _authenticatedUserId;

  final StreamController<String> _onAuthenticatedUserIdChangeController =
      new StreamController.broadcast();

  Stream<String> get onAuthenticatedUserIdChange => _onAuthenticatedUserIdChangeController.stream;

  final Transport _transport;

  /**
   * Dependency injection constructor of [Connection].
   *
   * In majority of cases, you want to use either [createHttpConnection] or
   * [createLoopBackConnection] factories from [clean_ajax.client_browser] and
   * [clean_ajax.client_backend] libraries.
   */
  Connection.config(this._transport) {
    this._transport.setHandlers(_prepareRequest, _handleResponse, _handleError, _disconnect, _reconnect);
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
      }).catchError((e) {
        request['controller'].addError(e);
      });
    }
    while (!_requestQueue.isEmpty) {
      var map = _requestQueue.removeFirst();
      var clientRequest = map['createRequest'](); // create the request
      if (clientRequest == null) {
        map['completer'].completeError(new CancelError());
      } else {
        request_list.add(new PackedRequest(requestCount, clientRequest));
        _responseMap[requestCount++] = map['completer'];
      }
    }
    return request_list;
  }

//  void _handleResponse(List responses) {
  void _handleResponse(Map responsesAndAuthUser) {
    String newAuthUserId = responsesAndAuthUser['authenticatedUserId'];
    if (_authenticatedUserId != newAuthUserId) {
      _onAuthenticatedUserIdChangeController.add(newAuthUserId);
      _authenticatedUserId = newAuthUserId;
    }
    for (var responseMap in responsesAndAuthUser['responses']) {
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

  void _handleError(error) {
    for (var completer in _responseMap.values) {
      completer.completeError(error);
    }
    _responseMap.clear();
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
  dynamic _handleError;
  dynamic _reconnectConnection;
  dynamic _disconnectConnection;

  setHandlers(prepareRequest, handleResponse, handleError, [handleDisconnect = null, handleReconnect = null]) {
    _prepareRequest = prepareRequest;
    _handleResponse = handleResponse;
    _handleError = handleError;
    _disconnectConnection = handleDisconnect == null ? (){} : handleDisconnect;
    _reconnectConnection = handleReconnect == null ? (){} : handleReconnect;
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

  bool _connected = true;

  void _disconnect() {
    _connected = false;
    _disconnectConnection();
  }

  void _reconnect() {
    _connected = true;
    _reconnectConnection();
  }

  HttpTransport(this._sendHttpRequest, this._url, this._delayBetweenRequests, [this._timeout = null]);

  /**
   * Seconds after which request is declared as timed-out. Optional parameter.
   * Use only with HttpRequest factories which support it. (Like the one in http_request.dart)
   */
  int _timeout;
  int get timeout => _timeout;

  setHandlers(prepareRequest, handleResponse, handleError, [handleDisconnect = null, handleReconnect = null]) {
    super.setHandlers(prepareRequest, handleResponse, handleError, handleDisconnect, handleReconnect);
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

  bool _shouldSendHttpRequest() => !_isRunning && _connected;

  void _openRequest() {
    _isRunning = true;
  }

  void _closeRequest() {
    _isRunning = false;
  }

  Future _buildRequest(data) {
    if (null == _timeout) {
      return _sendHttpRequest(
          _url,
          method: 'POST',
          requestHeaders: {'Content-Type': 'application/json'},
          sendData: JSON.encode(data)
      );
    } else {
      return _sendHttpRequest(
          _url,
          method: 'POST',
          requestHeaders: {'Content-Type': 'application/json'},
          sendData: JSON.encode(data),
          timeout: _timeout
      );
    }
  }

  /**
   * Begins performing HttpRequest. Is not launched if another request is
   * already running ([_isRunning] is true) or the request Queue is empty,
   * ([_isDirty] is false). Sets [_isRunning] as true for the time this request
   * is running and hooks up another request after this one with a delay of
   * [_delayBetweenRequests].
   */
  void _performRequest() {
    if (_connected) _sendDataRequest();
    else _sendPingRequest();
  }

  void _sendDataRequest() {
    if (!_shouldSendHttpRequest()) {
      return;
    }
    var data = _prepareRequest();
    if (data.isEmpty) return;

    _openRequest();
    _buildRequest(data).then((xhr) {
        _handleResponse(JSON.decode(xhr.responseText));
        _closeRequest();
    }).catchError((e, s) {
      if (e is ConnectionError) {
        _handleError(e);
        _disconnect();
      } else {
        logger.shout("error", e, s);
        _handleError(new FailedRequestException());
      }
      _closeRequest();
    });
  }

  void _sendPingRequest() {
    _openRequest();
    _buildRequest([new PackedRequest(0, new ClientRequest('ping', 'ping'))]).then((xhr) {
      _reconnect();
      _closeRequest();
    }).catchError((e) {
      if (e is ConnectionError) {
      } else {
        _reconnect();
      }
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

    new Future.delayed(new Duration(), () =>_sendLoopBackRequest(JSON.encode(_prepareRequest()), _authenticatedUserId)
    .then((response) {
      _handleResponse({'responses': response, 'authenticatedUserId': _authenticatedUserId});
      _closeRequest();
    }).catchError((e, s) {
      logger.shout('error: ',e,s);
      _handleError(new FailedRequestException());
      _closeRequest();
    }));

  }
}

class LoopBackTransportStub extends LoopBackTransport {
  num probability;
  Duration duration;
  Random random;
  // on, off, down, up
  String state='on';

  LoopBackTransportStub(sendLoopBackRequest, [authenticatedUserId = null]) :
    super(sendLoopBackRequest, authenticatedUserId) {
    random = new Random(new DateTime.now().millisecondsSinceEpoch);
  }

   /**
    * Requests would fail with [probability] for [duration].
    */
  void fail(num probability, [Duration duration = const Duration()]) {
    if (state != 'on') {
      return;
    }
    state = 'down';
    this.probability = probability;
    this.duration = duration;
  }

  performFailRequest(){
    return new Future.delayed(new Duration(), (){
      _prepareRequest();
      _handleError(new ConnectionError('Error'));
    });
  }

  void performPingRequest(){
    new Future.delayed(new Duration(), (){
      this.markDirty();
    });
  }


  void performRequest() {
     if (state == 'on') super.performRequest();
     else if (state == 'off') {
       performPingRequest();
     }
     else if (state == 'down') {
       if(probability > random.nextDouble()) {
         logger.fine('stub-state transfer -> off');
         state = 'off';
         performFailRequest().then((_) => _disconnectConnection());
         new Timer(duration, () {
           logger.fine('stub-state transfer -> off');
           state = 'up';
         });
       } else {
         super.performRequest();
       }
     }
     else if (state == 'up') {
       if(probability > random.nextDouble()) {
         logger.fine('stub-state transfer -> up');
         state = 'on';
         _reconnectConnection();
         performRequest();
       } else {
         performPingRequest();
       }
     };
  }
}


