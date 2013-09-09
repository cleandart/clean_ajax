// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class Request {
  final Map<String, dynamic> _args;
  final String _name;
  
  get args => this._args;
  get name => this._name;
  
  int id;
  
  /**
   * Creates a [Request] with specified [name] and [args]
   * [name] is the name of the requested server function
   * [args] is a map of arguments for the specified server function 
   */
  Request(this._name, this._args);
  
  /**
   * Creates a [Request] from JSON encoded request
   */
  factory Request.fromJSON(json) {
    var parsed = parse(json);
    return new Request(parsed['name'], parsed['args']);
  }
  
  /**
   * Converts this [Request] to JSON string.
   */
  String toJSON() {    
    return stringify({'id': id, 'name': name, 'args': args});
  }  
}
