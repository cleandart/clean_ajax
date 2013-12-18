// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 * Common parts for client and server parts
 */
library clean_ajax.common;

import "dart:core";
import 'client.dart' show ClientRequest;

class PackedRequest {
  final int id;
  final ClientRequest clientRequest;

  /**
   * Encapsulate [ClientRequest] with unique id to enable sending of multiple
   * [ClientRequest] in one list
   */
  PackedRequest(this.id,this.clientRequest);

  /**
   * Converts [PackedRequest] to JSON serializable map.
   */
  Map toJson() => {'id': id, 'clientRequest': clientRequest.toJson()};

  /**
   * Create a [ClientRequest] from JSON map {'name' : something, 'args': somethingElse}
   */
  factory PackedRequest.fromJson(Map data) =>
      new PackedRequest(data['id'], new ClientRequest.fromJson(data['clientRequest']));
}

/**
 *  Decode [List] of Json  maps back into [List] of [PackedRequest]
 */
List<PackedRequest> packedRequestsFromJson(List<Map> json) {
  return json.map((one) => new PackedRequest.fromJson(one)).toList();
}
