library clean_ajax.http_client;

import 'dart:async';
import 'dart:html';
import 'client.dart';

/**
 * Custom variant of the HttpRequest.request() method which handles timeouts
 * and divides Connection errors with Erroneous responses (HTTP errors)
 */
Future<HttpRequest> sendHttpRequest(String url,
    {String method, bool withCredentials, String responseType,
  String mimeType, Map<String, String> requestHeaders, sendData,
  void onProgress(ProgressEvent e), int timeout, Function requestFactory}) {
  var completer = new Completer<HttpRequest>();

  var xhr = new HttpRequest();
  if (null != requestFactory) xhr = requestFactory();
  if (method == null) {
    method = 'GET';
  }
  xhr.open(method, url, async: true);

  if (withCredentials != null) {
    xhr.withCredentials = withCredentials;
  }

  if (responseType != null) {
    xhr.responseType = responseType;
  }

  if (mimeType != null) {
    xhr.overrideMimeType(mimeType);
  }

  if (requestHeaders != null) {
    requestHeaders.forEach((header, value) {
      xhr.setRequestHeader(header, value);
    });
  }

  if (onProgress != null) {
    xhr.onProgress.listen(onProgress);
  }

  if (timeout != null) {
    xhr.timeout = timeout;
    xhr.onTimeout.listen((e) {
      return completer.completeError(new ConnectionError(e));
    });
  }

  xhr.onLoad.listen((e) {
    // Note: file:// URIs have status of 0.
    if ((xhr.status >= 200 && xhr.status < 300) ||
        xhr.status == 0 || xhr.status == 304) {
      completer.complete(xhr);
    } else {
      completer.completeError(new ResponseError(e));
    }
  });

  xhr.onError.listen((e) => completer.completeError(new ConnectionError(e)));

  if (sendData != null) {
    xhr.send(sendData);
  } else {
    xhr.send();
  }

  return completer.future;
}