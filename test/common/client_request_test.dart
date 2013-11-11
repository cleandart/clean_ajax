// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:clean_ajax/clean_common.dart';


void main() {

  group('Encoding and decoding of ClientRequest', () {

    setUp(() {
    });

    test('Test encoding and decoding ClientRequest with int (T01).', () {
      //given
      var cr = new ClientRequest('type1', 2);

      //when
      var crDecoded = new ClientRequest.fromJson(cr.toJson());

      //then
      expect(crDecoded.type, equals(cr.type));
      expect(crDecoded.args, equals(cr.args));
    });

    test('Test encoding and decoding ClientRequest with list (T02).', () {
      //given
      var cr = new ClientRequest('type1', {'a': 1,'b': 2});

      //when
      var crDecoded = new ClientRequest.fromJson(cr.toJson());

      //then
      expect(crDecoded.type, equals(cr.type));
      expect(crDecoded.args, equals(cr.args));
    });

    test('Test encoding and decoding ClientRequest with map (T03).', () {
      //given
      var cr = new ClientRequest('type1', {'a': 1,'b': 2});

      //when
      var crDecoded = new ClientRequest.fromJson(cr.toJson());

      //then
      expect(crDecoded.type, equals(cr.type));
      expect(crDecoded.args, equals(cr.args));
    });

  });
 }
