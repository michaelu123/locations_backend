import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:locations/screens/locaccount.dart';
import 'package:path/path.dart' as path;
import 'package:cryptography/cryptography.dart';

class LocationsClient {
  //"http://raspberrylan.1qgrvqjevtodmryr.myfritz.net:80/";
  String serverUrl;
  String extPath;
  bool hasZusatz;
  String id;

  Future<void> init(String serverUrl, String extPath, bool hasZusatz) async {
    this.serverUrl = serverUrl;
    this.extPath = extPath;
    this.hasZusatz = hasZusatz;

    // https: //cryptography.io/en/latest/hazmat/primitives/asymmetric/x25519/
    final algorithm = X25519();

    // Alice chooses her key pair
    final aliceKeyPair = await algorithm.newKeyPair();

    // // Alice knows Bob's public key
    // final bobKeyPair = await algorithm.newKeyPair();
    // final bobPublicKey = await bobKeyPair.extractPublicKey();

    // final bobPublicKeyBytes = bobPublicKey.bytes;
    // final bobPublicKey2 =
    //     SimplePublicKey(bobPublicKeyBytes, type: KeyPairType.x25519);

    final alicePubKey = await aliceKeyPair.extractPublicKey();
    final aliceB64 = base64.encode(alicePubKey.bytes);
    Map res = await kex("ich", aliceB64);
    final bobPublicKey2 =
        SimplePublicKey(base64.decode(res["pubkey"]), type: KeyPairType.x25519);

    // Alice calculates the shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      //remotePublicKey: bobPublicKey,
      remotePublicKey: bobPublicKey2,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    final sharedSecretB64 = base64.encode(sharedSecretBytes);
    print('Shared secret: $sharedSecretB64');

    final message = utf8.encode("dies ist ein test");
    final cryptAlg = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final encMsg = await cryptAlg.encrypt(message,
        secretKey: SecretKey(sharedSecretBytes));
    final ctxt = encMsg.cipherText;
    final iv = encMsg.nonce;

    // final mac = encMsg.mac; // = Mac.empty
    final secBox = SecretBox(ctxt, nonce: iv, mac: Mac.empty);
    final decMsg1 =
        await cryptAlg.decrypt(encMsg, secretKey: SecretKey(sharedSecretBytes));
    final decMsg2 =
        await cryptAlg.decrypt(secBox, secretKey: SecretKey(sharedSecretBytes));
    print("msg1 ${utf8.decode(decMsg1)}");
    print("msg2 ${utf8.decode(decMsg2)}");

    res = await test("ich", base64.encode(ctxt), base64.encode(iv));
    print("resp $res");
    print("msg3 ${res['res']}");
  }

  Future<dynamic> _req2(String method, String req,
      {Map<String, String> headers, String body}) async {
    http.Response resp;

    if (method == "GET") {
      resp = await http.get(Uri.parse(serverUrl + req), headers: headers);
    } else if (method == "DELETE") {
      resp = await http.delete(Uri.parse(serverUrl + req), headers: headers);
    } else {
      resp = await http.post(Uri.parse(serverUrl + req),
          headers: headers, body: body);
    }
    if (resp.statusCode >= 400) {
      String errBody = resp.body;
      print("req2 code ${resp.statusCode} ${resp.reasonPhrase} $errBody");
      try {
        Map m = json.decode(errBody);
        errBody = m.values.first;
      } catch (_) {}
      throw HttpException(errBody);
    }
    dynamic res = json.decode(resp.body);
    checkExpiration(resp.headers["x-auth"]);
    return res;
  }

  // why the retry?
  Future<dynamic> reqWithRetry(String method, String req,
      {Map<String, String> headers, dynamic body}) async {
    dynamic res;
    if (headers == null) {
      headers = Map<String, String>();
    }
    headers["x-auth"] = LocAuth.instance.token();
    try {
      res = await _req2(
        method,
        req,
        headers: headers,
        body: body,
      );
    } catch (ex) {
      throw (ex);
      // print("http exc $ex");
      // res = await _req2(
      //   method,
      //   req,
      //   headers: headers,
      //   body: body,
      // );
    }
    return res;
  }

  Future<Uint8List> _reqGetBytes(String req,
      {Map<String, String> headers}) async {
    http.Response resp =
        await http.get(Uri.parse(serverUrl + req), headers: headers);
    if (resp.statusCode >= 400) {
      String errBody = resp.body;
      print(
          "reqGetBytes code ${resp.statusCode} ${resp.reasonPhrase} $errBody");
      try {
        Map m = json.decode(errBody);
        errBody = m.values.first;
      } catch (ex) {}
      throw HttpException(errBody);
    }
    checkExpiration(resp.headers["x-auth"]);
    return resp.bodyBytes;
  }

  // why the retry?
  Future<Uint8List> reqGetBytesWithRetry(String req,
      {Map<String, String> headers}) async {
    Uint8List res;
    if (headers == null) {
      headers = Map();
    }
    headers["x-auth"] = LocAuth.instance.token();
    try {
      res = await _reqGetBytes(req, headers: headers);
    } catch (e) {
      throw (e);
      // print("http exc $e");
      // res = await _reqGetBytes(req, headers: headers);
    }
    return res;
  }

  Future<Map> _reqPostBytes(String req, Uint8List body,
      {Map<String, String> headers}) async {
    http.Response resp = await http.post(Uri.parse(serverUrl + req),
        headers: headers, body: body);
    if (resp.statusCode >= 400) {
      String errBody = resp.body;
      print(
          "reqPostBytes code ${resp.statusCode} ${resp.reasonPhrase} $errBody");
      try {
        Map m = json.decode(errBody);
        errBody = m.values.first;
      } catch (ex) {}
      throw HttpException(errBody);
    }
    checkExpiration(resp.headers["x-auth"]);
    Map res = json.decode(resp.body);
    return res;
  }

  // why the retry?
  Future<Map> reqPostBytesWithRetry(String req, Uint8List body,
      {Map<String, String> headers}) async {
    if (headers == null) {
      headers = {};
    }
    headers["x-auth"] = LocAuth.instance.token();
    Map res;
    try {
      res = await _reqPostBytes(req, body, headers: headers);
    } catch (e) {
      throw (e);
      // print("http exc $e");
      // res = await _reqPostBytes(req, body, headers: headers);
    }
    return res;
  }

  Future<void> sayHello(String tableBase) async {
    String table = tableBase + "_daten";
    String req = "/tables";
    List res = await reqWithRetry("GET", req);
    for (String l in res) {
      if (l == table) return;
    }
    throw "Keine Tabelle $table auf dem LocationsServer gefunden";
  }

  Future<Map> post(String tableBase, Map values) async {
    // values is a Map {table: [{colname:colvalue},...]}
    Map res;
    Map<String, String> headers = {
      "Content-type": "application/json",
    };
    for (final table in values.keys) {
      String req = "/add/${tableBase}_$table";
      List vals = values[table];
      int vl = vals.length;
      if (vl == 0) continue;
      int start = 0;
      while (start < vl) {
        int end = min(start + 100, vl);
        List sub = vals.sublist(start, end);
        start = end;
        String body = json.encode(sub);
        res = await reqWithRetry("POST", req, body: body, headers: headers);
        print("res $res");
      }
      if (table == "zusatz" && res != null && vals.length == 1) {
        vals[0]["nr"] = res["rowid"];
      }
    }
    return res;
  }

  Future<Map> getValuesWithin(String tableBase, String region, double minlat,
      double maxlat, double minlon, double maxlon) async {
    final res = {};
    for (String table in ["daten", if (hasZusatz) "zusatz", "images"]) {
      String req =
          "/region/${tableBase}_$table?minlat=$minlat&maxlat=$maxlat&minlon=$minlon&maxlon=$maxlon&region=$region";
      List res2 = await reqWithRetry("GET", req);
      res[table] = res2;
    }
    return res;
  }

  Future<Map> postImage(String tableBase, String imgName) async {
    String req = "/addimage/$tableBase/$imgName";
    final headers = {"Content-type": "image/jpeg"};

    final imgPath = path.join(extPath, tableBase, "images", imgName);
    File f = File(imgPath);
    final body = await f.readAsBytes();
    Map res = await reqPostBytesWithRetry(req, body, headers: headers);
    return res;
  }

  Future<List> getImage(
      String tableBase, String imgName, int maxdim, bool thumbnail) async {
    String imgPath = path.join(extPath, tableBase, "images", imgName);
    File f = File(imgPath);
    if (await f.exists()) return [f, false];
    if (thumbnail) {
      imgPath = path.join(extPath, tableBase, "images", "tn_" + imgName);
      f = File(imgPath);
      if (await f.exists()) return [f, false];
    }
    final req = "/getimage/$tableBase/$imgName?maxdim=$maxdim";
    Uint8List res = await reqGetBytesWithRetry(req);
    if (res == null) return null;
    await f.writeAsBytes(res, flush: true);
    return [f, !thumbnail];
  }

  Future<List> getConfigs() async {
    final req = "/configs";
    List res = await reqWithRetry("GET", req);
    return res;
  }

  Future<Map> getConfig(String name) async {
    final req = "/config/$name";
    Map res = await reqWithRetry("GET", req);
    return res;
  }

  Future<void> official(String tableBase, Map<String, Object> val) async {
    // values is a Map {colname:colvalue}, i.e. one DB row
    Map<String, String> headers = {"Content-type": "application/json"};
    String req = "/official/${tableBase}_daten";
    String body = json.encode(val);
    await reqWithRetry("POST", req, body: body, headers: headers);
  }

  Future<void> deleteLoc(
      String tableBase, String latRound, String lonRound) async {
    final req =
        "/deleteloc/$tableBase?lat=$latRound&lon=$lonRound&haszusatz=$hasZusatz";
    Map _ = await reqWithRetry("DELETE", req);
  }

  Future<void> deleteImage(String tableBase, String imgPath) async {
    final req = "/deleteimage/$tableBase/$imgPath";
    Map _ = await reqWithRetry("DELETE", req);
  }

  Future<List> getMarkerCodeNames(String tableBase) async {
    final req = "/markercodes/$tableBase";
    List res = await reqWithRetry("GET", req);
    return res;
  }

  Future<Map> getMarkerCode(String tableBase, String name) async {
    final req = "/markercode/$tableBase/$name";
    Map res = await reqWithRetry("GET", req);
    return res;
  }

  Future<void> postMarkerCode(
      String tableBase, String name, String codeJS) async {
    String req = "/addmarkercode/$tableBase/$name";
    Map<String, String> headers = {"Content-type": "text/plain"};
    Map res = await reqWithRetry("POST", req, body: codeJS, headers: headers);
    return res;
  }

  Future<void> deleteMarkerCode(String tableBase, String name) async {
    final req = "/deletemarkercode/$tableBase/$name";
    Map _ = await reqWithRetry("DELETE", req);
  }

  Future<Map> kex(String id, String alicePubKey) async {
    Map<String, String> headers = {"Content-type": "application/json"};
    String req = "/kex";
    String body = json.encode({"id": id, "pubkey": alicePubKey});
    Map m = await reqWithRetry("POST", req, body: body, headers: headers);
    return m;
  }

  Future<Map> test(String id, String encData, String iv) async {
    Map<String, String> headers = {"Content-type": "application/json"};
    String req = "/test";
    String body = json.encode({"id": id, "enc": encData, "iv": iv});
    Map m = await reqWithRetry("POST", req, body: body, headers: headers);
    return m;
  }

  Future<Map> postAuth(String loginOrSignon, String cred) async {
    Map<String, String> headers = {
      "Content-type": "application/json",
    };
    String req = "/auth/" + loginOrSignon;
    Map m = await reqWithRetry("POST", req, body: cred, headers: headers);
    id = m["id"];
    return m;
  }

  void checkExpiration(String xauth) {
    print("checkExp $xauth");
  }
}
