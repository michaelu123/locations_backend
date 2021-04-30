import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class LocationsClient {
  //"http://raspberrylan.1qgrvqjevtodmryr.myfritz.net:80/";
  String serverUrl;
  String extPath;
  bool hasZusatz;

  void init(String serverUrl, String extPath, bool hasZusatz) {
    this.serverUrl = serverUrl;
    this.extPath = extPath;
    this.hasZusatz = hasZusatz;
  }

  Future<dynamic> _req2(String method, String req,
      {Map<String, String> headers, String body}) async {
    http.Response resp;

    if (method == "GET") {
      resp = await http.get(Uri.parse(serverUrl + req), headers: headers);
    } else {
      resp = await http.post(Uri.parse(serverUrl + req),
          headers: headers, body: body);
    }
    if (resp.statusCode >= 400) {
      // Map errbody = json.decode(resp.body);
      // String msg = errbody['error']['message'] ?? "Unknown error";
      // throw HttpException(msg);
      String errBody = resp.body;
      print("errbody $errBody");
      // throw HttpException(errBody);
      return null;
    }
    dynamic res = json.decode(resp.body);
    return res;
  }

  Future<dynamic> reqWithRetry(String method, String req,
      {Map<String, String> headers, dynamic body}) async {
    dynamic res;
    try {
      res = await _req2(
        method,
        req,
        headers: headers,
        body: body,
      );
    } catch (e) {
      print("http exc $e");
      res = await _req2(
        method,
        req,
        headers: headers,
        body: body,
      );
    }
    return res;
  }

  Future<Uint8List> _reqGetBytes(String req, {Map headers}) async {
    http.Response resp =
        await http.get(Uri.parse(serverUrl + req), headers: headers);
    if (resp.statusCode >= 400) {
      print(
          "reqBytes code ${resp.statusCode} ${resp.reasonPhrase} ${resp.body}");
      return null;
    }
    return resp.bodyBytes;
  }

  Future<Uint8List> reqGetBytesWithRetry(String req, {Map headers}) async {
    Uint8List res;
    try {
      res = await _reqGetBytes(req, headers: headers);
    } catch (e) {
      print("http exc $e");
      res = await _reqGetBytes(req, headers: headers);
    }
    return res;
  }

  Future<Map> _reqPostBytes(String req, Uint8List body, {Map headers}) async {
    http.Response resp = await http.post(Uri.parse(serverUrl + req),
        headers: headers, body: body);
    if (resp.statusCode >= 400) {
      print("_reqPostBytes code ${resp.statusCode} ${resp.reasonPhrase}");
      String errBody = resp.body;
      print("_reqPostBytes errbody $errBody");
      // throw HttpException(errBody);
      return null;
    }
    Map res = json.decode(resp.body);
    return res;
  }

  Future<Map> reqPostBytesWithRetry(String req, Uint8List body,
      {Map headers}) async {
    Map res;
    try {
      res = await _reqPostBytes(req, body, headers: headers);
    } catch (e) {
      print("http exc $e");
      res = await _reqPostBytes(req, body, headers: headers);
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

  Future<void> post(String tableBase, Map values) async {
    // values is a Map {table: [{colname:colvalue},...]}
    Map<String, String> headers = {"Content-type": "application/json"};
    for (final table in values.keys) {
      String req = "/add/${tableBase}_$table";
      List vals = values[table];
      if (vals.length == 0) continue;
      for (Map val in vals) {
        val.remove("new_or_modified");
      }
      if (table == "zusatz") {
        for (Map val in vals) {
          val["nr"] = null;
        }
      }

      int vl = vals.length;
      int start = 0;
      while (start < vl) {
        int end = min(start + 100, vl);
        List sub = vals.sublist(start, end);
        start = end;
        String body = json.encode(sub);
        await reqWithRetry("POST", req, body: body, headers: headers);
      }
    }
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
    String req = "/addimage/${tableBase}_images/$imgName";
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
    final req = "/getimage/${tableBase}_images/$imgName?maxdim=$maxdim";
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
}