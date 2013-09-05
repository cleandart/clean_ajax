// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class Request {
  final RequestContent _content;  
  final String _name;
  
  RequestContent get content => this._content;
  String get name => this._name;  
  
  /**
   * Creates a [Request] with specified [name] and [content]
   * Completer is triggered when the request is about to be sent.
   */
  Request(this._name, this._content);
}
