// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:clean_ajax/common.dart';

class MockObject extends Mock implements Object {}

void main() {

  group('Encoding and decoding of PackedRequest', () {

    setUp(() {
    });

    test('Test encoding and decoding PackedRequest with ClientRequest (T01).', () {
      //given
      var pr = new PackedRequest(1, new ClientRequest('type1', new MockObject()));

      //when
      var prDecoded = new PackedRequest.fromJson(pr.toJson());

      //then
      expect(prDecoded.id, equals(pr.id));
      expect(prDecoded.clientRequest.type, equals(pr.clientRequest.type));
      expect(prDecoded.clientRequest.args, equals(pr.clientRequest.args));
    });

    test('Test encoding and decoding list of PackedRequest (T02).', () {
      //given
      var pr1 = new PackedRequest(1, new ClientRequest('type1', new MockObject()));
      var pr2 = new PackedRequest(1, new ClientRequest('type2', new MockObject()));
      var list = [pr1, pr2];

      //when
      var listDecoded = packedRequestsFromJson(list.map((one)=>one.toJson()).toList());

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
