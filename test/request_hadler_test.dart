// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';
import 'package:clean_ajax/clean_common.dart';
import 'dart:async';


void main() {

  group('RequestHandler', () {
    setUp(() {
    });

    test('Test encoding and decoding (TXX).', () {
      var cr1= new ClientRequest('name1',{'a':[1,2,3], 'b':[4,5,6], 'c':[7,8,9]});
      var cr2= new ClientRequest('name1',{'d':[4,2,3], 'e':[2,5,6], 'f':[3,8,9]});
      var cr3= new ClientRequest('name1',{'g':[8,2,3], 'h':[9,{'b':'c'},6], 'i':[9,8,9]});
      var pr1 = new PackedRequest(1, cr1);
      var pr2 = new PackedRequest(2, cr2);
      var pr3 = new PackedRequest(3, cr3);
      var data = [pr1,pr2,pr3];

      var str = encodeListOfPackedRequest(data);
      var decodedData = decodeListOfPackedRequest(str);

      print(data);
      print(decodedData);
      expect(decodedData, equals(data));
    });
  });


 }
