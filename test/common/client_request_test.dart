// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library client_request_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:clean_ajax/common.dart';


class MockObject extends Mock implements Object {}

void main() {

  group('Encoding and decoding of ClientRequest', () {

    test('Test encoding and decoding ClientRequest(T01).', () {
      //given
      var cr = new ClientRequest('type1', new MockObject());
      //when
      var crDecoded = new ClientRequest.fromJson(cr.toJson());
      //then
      expect(crDecoded.type, equals(cr.type));
      expect(crDecoded.args, equals(cr.args));
    });

  });
 }
