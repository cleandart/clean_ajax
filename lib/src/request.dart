// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class Request {
  /**
   * Completer that is completed when the request is about to be sent
   */
  Completer<Request> _requestCompleter;
  /**
   * Completer that is completed when the request receives response
   */
  Completer<Response> _responseCompleter;
  /**
   * Completer that is completed when the request is filled with dat
   */
  Completer _doneCompleter;

  RequestContent _content;  
  String _name;
  
  RequestContent get content => this._content;
  String get name => this._name;
  Future get done => this._doneCompleter.future;
  
  /**
   * Creates a [Request] with specified [Completer]. 
   * Completer is triggered when the request is about to be sent.
   */
  Request(this._requestCompleter) {
    this._doneCompleter = new Completer();    
  }  
  
  /**
   * Completes the preparation stage for this [Request]
   * First .then() is now called and the request name and contents are awaited.
   * 
   * Returns Future for when this [Request] data has been filled by client.
   */
  Future requestContent() {
    this._requestCompleter.complete(this);
    return this.done;
  }
  
  /**
   * Fills the request with name and content and returns the Future [Response].
   */
  Future<Response> send(String name, RequestContent content) {
    this._responseCompleter = new Completer<Response>();
    this._name = name;
    this._content = content;
    this._doneCompleter.complete();
    return this._responseCompleter.future;
  }
  
  /**
   * Completes the request with selected response.
   */
  void completeRequest(Response response) => 
      this._responseCompleter.complete(response);
}
