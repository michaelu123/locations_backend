import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
// ignore: implementation_imports
import 'package:geoflutterfire/src/Util.dart';
// ignore: implementation_imports
import 'package:geoflutterfire/src/models/DistanceDocSnapshot.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class FirebaseClient {
  static DateFormat dateFormatterDB = DateFormat('yyyy.MM.dd HH:mm:ss');
  Map felder;
  Map types;
  String extPath;
  final geo = Geoflutterfire();

  void init(
    String extPath,
  ) {
    this.extPath = extPath;
  }

  void initFelder(
    List datenFelder,
    List zusatzFelder,
    List imagesFelder,
  ) {
    felder = {
      "daten": datenFelder,
      "zusatz": zusatzFelder,
      "images": imagesFelder,
    };
    types = {
      "daten": {},
      "zusatz": {},
      "images": {},
    };
    for (String tableName in felder.keys) {
      Map tmap = types[tableName];
      List lst = felder[tableName];
      for (Map m in lst) {
        tmap[m["name"]] = m["type"];
      }
    }
  }

  dynamic convertFb2DB(String type, dynamic val) {
    if (val == null) return null;
    if (type == "bool") return (val as bool) ? 1 : 0;
    return val;
  }

  dynamic convertDb2Fb(String type, dynamic val) {
    if (val == null) return null;
    if (type == "bool") return val != 0;
    return val;
  }

  Future<Map> getValuesWithin(String tableBase, String region, double minlat,
      double maxlat, double minlon, double maxlon) async {
    final geo = Geoflutterfire();
    final res = {};
    for (String tableName in ["daten", "zusatz", "images"]) {
      String table = "${tableBase}_$tableName";
      List dbFelder = felder[tableName];
      int len = dbFelder.length - 1; // without new_or_modified

      GeoFirePoint center =
          GeoFirePoint((minlat + maxlat) / 2, (minlon + maxlon) / 2);
      double radius = center.distance(lat: maxlat, lng: maxlon);
      final precision = Util.setPrecision(radius);
      final centerHash = center.hash.substring(0, precision);
      final area = GeoFirePoint.neighborsOf(hash: centerHash)..add(centerHash);

      final rows1 = await getRegionPy(table, area);
      final rows2 = [];
      for (final row1 in rows1) {
        final GeoPoint geoPoint = row1['geopoint'];
        if (geoPoint.latitude >= minlat &&
            geoPoint.latitude <= maxlat &&
            geoPoint.longitude >= minlon &&
            geoPoint.longitude <= maxlon) {
          rows2.add(row1);
        }
      }

      final rows = [];
      for (final data in rows2) {
        if (region != "" && data["region"] != region) continue;
        final row = List<dynamic>.filled(len, null, growable: true);
        dynamic val;
        int index = 0;
        for (Map feld in dbFelder) {
          String name = feld["name"];
          switch (name) {
            case "created":
              val = dateFormatterDB
                  .format((data["created"] as Timestamp).toDate());
              break;
            case "modified":
              val = dateFormatterDB
                  .format((data["modified"] as Timestamp).toDate());
              break;
            case "lat":
              val = (data["latlng"]["geopoint"] as GeoPoint).latitude;
              break;
            case "lon":
              val = (data["latlng"]["geopoint"] as GeoPoint).longitude;
              break;
            case "nr":
              val = data["nr"]; // ??
              break;
            case "new_or_modified":
              continue;
            default:
              val = convertFb2DB(feld["type"], data[name]);
          }
          row[index++] = val;
        }
        rows.add(row);
      }
      res[tableName] = rows;
    }
    return res;
  }

  Future<Map> postImage(String tableBase, String imgName) async {
    String imgPath = path.join(extPath, tableBase, "images", imgName);
    File f = File(imgPath);
    final res = await postImagePy(f, "${tableBase}_images", imgName);
    return {"url": res["url"]};
  }

  // thumbnail suppport requires Firebase Extension "Resize Images"
  Future<List> getImage(
      String tableBase, String imgName, int maxdim, bool thumbnail) async {
    String imgPath = path.join(extPath, tableBase, "images", imgName);
    File f = File(imgPath);
    if (await f.exists()) return [f, false];
    if (thumbnail) {
      imgPath = path.join(extPath, tableBase, "images", "tn_" + imgName);
      f = File(imgPath);
      if (await f.exists()) return [f, false];
      imgName = imgName.replaceFirst(".jpg", "_200x200.jpg");
    }

    Uint8List res = await getImagePy(
        thumbnail ? "${tableBase}_images/thumbnails" : "${tableBase}_images",
        imgName);
    if (res == null) return null;
    await f.writeAsBytes(res, flush: true);
    return [f, !thumbnail];
  }

  String docidFor(Map val, String tableName) {
    String id;
    switch (tableName) {
      case "daten":
        id = '${val["lat_round"]}_${val["lon_round"]}_${val["creator"]}';
        break;
      case "zusatz":
        String uniq = (val["created"] as Timestamp).seconds.toRadixString(36);
        id = '${val["lat_round"]}_${val["lon_round"]}_${val["creator"]}_$uniq';
        break;
      case "images":
        id = '${val["creator"]}_${val["image_path"]}';
        break;
    }
    return id;
  }

  Future<void> post(String tableBase, Map values) async {
    // values is a Map {table: [{colname:colvalue},...]}
    for (final tableName in values.keys) {
      String table = "${tableBase}_$tableName";

      List rows = values[tableName];
      if (rows.length == 0) continue;
      double lat;
      GeoFirePoint latlng;
      for (Map map in rows) {
        for (String name in map.keys) {
          switch (name) {
            case "created":
            case "modified":
              // "2000.01.01 01:00:00" -> 20000101 01:00:00
              String val = map[name].replaceAll(".", "");
              final dt = DateTime.parse(val);
              final msec = dt.millisecondsSinceEpoch;
              final ts = Timestamp((msec / 1000).round(), 0);
              map[name] = ts;
              break;
            case "lat":
              double val = map[name];
              lat = val;
              break;
            case "lon":
              double val = map[name];
              latlng = geo.point(latitude: lat, longitude: val);
              break;
            default:
              dynamic val = map[name];
              String type = types[tableName][name];
              map[name] = convertDb2Fb(type, val);
          }
        }
        map["latlng"] = latlng.data;
        map.remove("new_or_modified");
        map.remove("nr");
        map.remove("lat");
        map.remove("lon");
      }

      for (Map val in rows) {
        String id = docidFor(val, tableName);
        postPy(table, id, val);
      }
    }
  }

  void postRows(String tableBase, Map values) {
    // values is a Map {table: [[colvalue,...],...]]
    for (final tableName in values.keys) {
      String table = "${tableBase}_$tableName";
      List dbFelder = felder[tableName];
      double lat;
      List rowsIn = values[tableName];
      List rowsOut = [];
      if (rowsIn.length == 0) continue;
      for (List row in rowsIn) {
        Map<String, dynamic> map = {};
        int index = 0;
        for (Map feld in dbFelder) {
          String name = feld["name"];
          String type = feld["type"];
          switch (name) {
            case "created":
            case "modified":
              // "2000.01.01 01:00:00" -> 20000101 01:00:00
              String val = row[index].replaceAll(".", "");
              final dt = DateTime.parse(val);
              final msec = dt.millisecondsSinceEpoch;
              final ts = Timestamp((msec / 1000).round(), 0);
              map[name] = ts;
              break;
            case "lat":
              double val = row[index];
              lat = val;
              break;
            case "lon":
              double val = row[index];
              GeoFirePoint latlng = geo.point(latitude: lat, longitude: val);
              map["latlng"] = latlng.data;
              break;
            case "nr":
            case "new_or_modified":
              break;
            default:
              dynamic val = row[index];
              map[name] = convertDb2Fb(type, val);
          }
          index++;
        }
        rowsOut.add(map);
      }

      for (Map val in rowsOut) {
        String id = docidFor(val, tableName);
        postPy(table, id, val);
      }
    }
  }

  Future<void> sayHello(String tableBase) async {
    throw UnimplementedError();
  }

  Future<List> getConfigs() async {
  //   final lr = await FirebaseStorage.instance.ref().child("configs").listAll();
  //   return lr.items.map((l) => l.name).toList();
    throw UnimplementedError();
  }

  Future<Map> getConfig(String config) async {
    // Uint8List resBytes = await FirebaseStorage.instance
    //     .ref()
    //     .child("configs")
    //     .child(config)
    //     .getData();
    // final Map map = json.decode(Utf8Decoder().convert(resBytes));
    // return map;
    throw UnimplementedError();
  }
 
  Future<void> official(String tableBase, Map<String, Object> daten) async {
    throw UnimplementedError();
  }

  Future<void> deleteLoc(
      String tableBase, String latRound, String lonRound) async {
    throw UnimplementedError();
  }

  Future<void> deleteImage(String tableBase, String imgPath) async {
    throw UnimplementedError();
  }

  Future<List> getMarkerCodeNames(String tableBase) async {
    return [];
  }

  Future<Map> getMarkerCode(String tableBase, String name) async {
    throw UnimplementedError();
  }

  Future<void> postMarkerCode(
      String tableBase, String name, String codeJS) async {
    throw UnimplementedError();
  }

  Future<void> deleteMarkerCode(String tableBase, String name) async {
    throw UnimplementedError();
  }

  void logoff() {
    //throw UnimplementedError();
  }

  getRegionPy(String table, List<String> area) {}

  postImagePy(File f, String s, String imgName) {}

  getImagePy(String s, String imgName) {}
}

void postPy(tableName, String id, Map val) {}
