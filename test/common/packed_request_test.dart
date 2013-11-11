// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:clean_ajax/clean_common.dart';


void main() {

  group('Encoding and decoding of PackedRequest', () {

    setUp(() {
    });

    test('Test encoding and decoding PackedRequest with ClientRequest with int (T01).', () {
      //given
      var pr = new PackedRequest(1, new ClientRequest('type1', 2));

      //when
      var prDecoded = new PackedRequest.fromJson(pr.toJson());

      //then
      expect(prDecoded.id, equals(pr.id));
      expect(prDecoded.clientRequest.type, equals(pr.clientRequest.type));
      expect(prDecoded.clientRequest.args, equals(pr.clientRequest.args));
    });

    test('Test encoding and decoding PackedRequest with ClientRequest with list (T02).', () {
      //given
      var pr = new PackedRequest(1, new ClientRequest('type1', ['a', 1, 'b', 2]));

      //when
      var prDecoded = new PackedRequest.fromJson(pr.toJson());

      //then
      expect(prDecoded.id, equals(pr.id));
      expect(prDecoded.clientRequest.type, equals(pr.clientRequest.type));
      expect(prDecoded.clientRequest.args, equals(pr.clientRequest.args));
    });

    test('Test encoding and decoding PackedRequest with ClientRequest with map (T03).', () {
      //given
      var pr = new PackedRequest(1, new ClientRequest('type1', {'a': 1,'b': 2}));

      //when
      var prDecoded = new PackedRequest.fromJson(pr.toJson());

      //then
      expect(prDecoded.id, equals(pr.id));
      expect(prDecoded.clientRequest.type, equals(pr.clientRequest.type));
      expect(prDecoded.clientRequest.args, equals(pr.clientRequest.args));
    });

    test('Test encoding and decoding list of PackedRequest (T04).', () {
      //given
      var pr1 = new PackedRequest(1, new ClientRequest('type1', {'a': 1,'b': 2}));
      var pr2 = new PackedRequest(1, new ClientRequest('type2', 10));
      var pr3 = new PackedRequest(1, new ClientRequest('type3', ['c', 3, 'd']));
      var list = [pr1, pr2, pr3];

      //when
      var listDecoded = decodeFromJson(encodeToJson(list));

      //then
      expect(listDecoded.length, equals(list.length));
      for(int i = 0; i < list.length; i++) {
        expect(listDecoded[i].id, equals(list[i].id));
        expect(listDecoded[i].clientRequest.type, equals(list[i].clientRequest.type));
        expect(listDecoded[i].clientRequest.args, equals(list[i].clientRequest.args));
      }
    });

  });
 }