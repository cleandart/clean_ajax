// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 */
library clean_client;

import "dart:core";
import "dart:async";
import "dart:collection";
import "dart:html";
import "dart:convert";

import 'package:clean_ajax/clean_common.dart';
export 'package:clean_ajax/clean_common.dart' show ClientRequest;

part 'src/client/server.dart';
