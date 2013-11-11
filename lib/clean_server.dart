// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A library for server-client communication and interaction
 */
library clean_server;

import "dart:core";
import "dart:async";
import "dart:convert";
import 'dart:io';
import 'package:http_server/http_server.dart';

import 'package:clean_ajax/clean_common.dart';
export 'package:clean_ajax/clean_common.dart' show ClientRequest;

part 'src/server/request_handler.dart';
