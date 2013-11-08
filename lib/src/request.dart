// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of clean_ajax_common;


class ClientRequest {
  Map<String, dynamic> args;
  String name;

  /**
   * Creates a [ClientRequest] with specified [name] and [args]
   * [name] is the name of the requested server function
   * [args] is a map of arguments for the specified server function
   */
  ClientRequest(this.name, this.args);

  ClientRequest.fromJsonString(String json)
  {
    Map data = JSON.decode(json);
    name = data['name'];
    args = data['args'];
  }

  ClientRequest.fromJsonMap(Map data)
  {
    name = data['name'];
    args = data['args'];
  }

  /**
   * Converts this [ClientRequest] to JSON serializable map.
   */
  Map toJson() {
    return {'name': name, 'args': args};
  }
}

class PackedRequest {
  int id;
  ClientRequest clientRequest;
  PackedRequest(this.id,this.clientRequest);

  /**
   * Converts this [_PackedRequest] to JSON serializable map.
   */
  Map toJson() {
    return {'id': id, 'clientRequest': clientRequest};
  }

  PackedRequest.fromJsonString(String json)
  {
    Map data = JSON.decode(json);
    id = data['id'];
    clientRequest = new ClientRequest.fromJsonMap(data['clientRequest']);
  }

  PackedRequest.fromJsonMap(Map data)
  {
    id = data['id'];
    clientRequest = new ClientRequest.fromJsonMap(data['clientRequest']);
  }
}

List<PackedRequest> decodeListOfPackedRequest(String json)
{
  List data = JSON.decode(json);
  var x = data.map((one)=> new PackedRequest.fromJsonMap(one));
  var xx = x.toList();
  return xx;
}

String encodeListOfPackedRequest(List<PackedRequest> request_list)
{
  return JSON.encode(request_list);
}

