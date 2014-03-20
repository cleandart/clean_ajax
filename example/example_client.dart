import 'dart:async';
import 'dart:html';
import "package:clean_ajax/client_browser.dart";
import 'package:clean_ajax/common.dart';

// Don't run example_client.dart nor index.html instead run example_server.dart and go
// in dartium to address 0.0.0.0:8080

void main() {
  Connection connection = createHttpConnection("http://0.0.0.0:8080/resources/", new Duration(milliseconds: 200));

  querySelector('#send').onClick.listen((_) {
    InputElement request = querySelector("#request");
    ParagraphElement responseElem = querySelector("#response");

    connection.send(()=>new ClientRequest('json', request.value)).then(
        (response) {
          responseElem.text = request.value;
        }
    );
  });

}
