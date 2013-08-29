// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class Response {
  String json;
  
  /**
   * Creates Response object from JSON encoded string
   */
  Response(this.json);  
}
