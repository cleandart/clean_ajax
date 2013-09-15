// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class Request {
  final Map<String, dynamic> args;
  final String name;  
  
  /**
   * Creates a [Request] with specified [name] and [args]
   * [name] is the name of the requested server function
   * [args] is a map of arguments for the specified server function 
   */
  Request(this.name, this.args);  
  
  /**
   * Converts this [Request] to JSON serializable map.
   */
  Map toJson() {    
    return {'name': name, 'args': args};
  }  
}
