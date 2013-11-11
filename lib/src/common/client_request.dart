// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_common;


class ClientRequest {
  final dynamic args;
  final String type;

  /**
   * Creates a [ClientRequest] with specified [type] and [args]
   * [name] is the name of the requested server function
   * [args] is a map of arguments for the specified server function
   */
  ClientRequest(this.type, this.args);

  /**
   * Create a [ClientRequest] from JSON map {'name' : something, 'args' somethingElse}
   */
  factory ClientRequest.fromJson(Map data) => new ClientRequest(data['type'], data['args']);

  /**
   * Converts this [ClientRequest] to JSON serializable map.
   */
  Map toJson() => {'type': type, 'args': args};
}
