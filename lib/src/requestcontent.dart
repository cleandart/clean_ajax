// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_server;

class RequestContent {
  String json;
  
  /**
   * Creates RequestContent from JSON encoded string 
   */
  RequestContent(this.json); 
  
}
