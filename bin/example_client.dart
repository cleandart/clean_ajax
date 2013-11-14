import 'dart:async';
import 'dart:html';
import "package:clean_ajax/client.dart";

/// Dont run example_client.dart nor index.html instead run example_server.dart and go
/// in dartium to address 0.0.0.0:8080
void main() {
  Server server = new Server("http://0.0.0.0:8080/resources",new Duration(milliseconds: 200));

  querySelector('#send').onClick.listen((_) {
    InputElement request = querySelector("#request");
    ParagraphElement responseElem = querySelector("#response");

    server.sendRequest(()=>new ClientRequest('dummyType',request.value)).then(
        (response) => responseElem.text = response
    );
  });

}
