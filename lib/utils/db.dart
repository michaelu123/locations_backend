import 'package:intl/intl.dart';
import 'package:locations/parser/parser.dart';
import 'package:locations/providers/base_config.dart';
import 'package:locations/utils/utils.dart';

class Coord {
  double lat;
  double lon;
  int quality;
  bool hasImage;
}

class LocationsDB {
  static String dbName;
  static String tableBase;
  static String baseName;
  static bool hasZusatz;
  static int bcVers;

  static double lat, lon;
  static int stellen;
  static String latRound, lonRound;
  static Map<String, List<String>> colNames = {};
  static List<Statement> statements;
  static Map<String, Map<String, List<Map<String, Object>>>> locData;
  static DateFormat dateFormatterDB = DateFormat('yyyy.MM.dd HH:mm:ss');
  static int nrInc = 1;

  static Future<void> setBaseDB(BaseConfig baseConfig) async {
    if (dbName == baseConfig.getDbName()) return;
    baseName = baseConfig.getName();
    dbName = baseConfig.getDbName();
    tableBase = baseConfig.getDbTableBaseName();
    var felder = baseConfig.getDbDatenFelder();
    colNames["daten"] = felder.map((feld) => feld["name"] as String).toList();
    felder = baseConfig.getDbZusatzFelder();
    colNames["zusatz"] = felder.map((feld) => feld["name"] as String).toList();
    hasZusatz = felder.length > 0;
    felder = baseConfig.getDbImagesFelder();
    colNames["images"] = felder.map((feld) => feld["name"] as String).toList();
    lat = lon = null;
    statements = parseProgram(baseConfig.getProgram());
    locData = {"daten": {}, "zusatz": {}, "images": {}};
  }

  static String keyFor(String latRound, String lonRound) {
    return latRound + ":" + lonRound;
  }

  static String keyOf(String table, Map<String, Object> data) {
    return keyFor(data["lat_round"].toString(), data["lon_round"].toString());
  }

  static Future<int> insert(String table, Map<String, Object> data) async {
    String key = keyOf(table, data);
    data["new_or_modified"] = null;
    List<Map<String, Object>> entries = locData[table][key];
    if (entries == null) {
      entries = [data];
      locData[table][key] = entries;
    } else {
      entries.add(data);
    }
    return 1;
  }

  static List<Map<String, Object>> getAllData(String table) {
    // https://stackoverflow.com/questions/15413248/how-to-flatten-a-list
    return locData[table].values.expand((l) => l).toList();
  }

  static Future<Map> dataForSameLoc() async {
    return dataFor(lat, lon, stellen);
  }

  static Map<String, dynamic> makeWritableMap(Map m) {
    return m;
  }

  static List makeWritableList(List l) {
    return l;
  }

  static List<Map<String, Object>> getLocData(table, latRound, lonRound) {
    return locData[table][keyFor(latRound, lonRound)] ?? [];
  }

  static Future<Map> dataFor(double alat, double alon, int astellen) async {
    lat = alat;
    lon = alon;
    stellen = astellen;
    latRound = roundDS(alat, stellen);
    lonRound = roundDS(alon, stellen);
    final resD = getLocData("daten", latRound, lonRound);
    final resZ = hasZusatz ? getLocData("zusatz", latRound, lonRound) : [];
    final resI = getLocData("images", latRound, lonRound);
    return {
      "daten": makeWritableList(resD),
      "zusatz": makeWritableList(resZ),
      "images": makeWritableList(resI),
    };
  }

  static List<Map<String, Object>> getLocDataNew(String table) {
    List<Map<String, Object>> res = [];
    for (List l in locData[table].values) {
      for (Map m in l) {
        if (m["new_or_modified"] != null) {
          res.add(m);
        }
      }
    }
    return res;
  }

  static Future<Map> getNewData() async {
    final resD = getLocDataNew("daten");
    final resZ = hasZusatz ? getLocDataNew("zusatz") : [];
    final resI = getLocDataNew("images");
    return {
      // res is readOnly
      "daten": makeWritableList(resD),
      "zusatz": makeWritableList(resZ),
      "images": makeWritableList(resI),
    };
  }

  static Future<Map> updateRowDB(
      String table, String region, String name, Object val, String userName,
      {int nr}) async {
    final now = dateFormatterDB.format(DateTime.now());
    List l = getLocData(table, latRound, lonRound);
    if (table != "zusatz" || nr != null) {
      if (table == "zusatz") {
        l.removeWhere((li) => li["nr"] != nr);
      }
      for (final li in l) {
        li[name] = val;
        li["new_or_modified"] = 1;
      }
      if (l.length != 0) {
        return {"modified": now};
      }
    }
    Map<String, Object> data = {
      "region": region,
      "lat": lat,
      "lon": lon,
      "lat_round": latRound,
      "lon_round": lonRound,
      "creator": userName,
      "created": now,
      "modified": now,
      "new_or_modified": 1,
      name: val,
    }; //);
    if (table == "zusatz") {
      data["nr"] = nrInc++;
    }
    insert(table, data);
    // res = the created rowid
    final res = 0; // ??
    return {"nr": res, "created": now};
  }

  static Future<void> updateImagesDB(
      String imagePath, String name, Object val) async {
    assert(false);
  }

  static int qualityOfLoc(Map daten, List zusatz) {
    int r = evalProgram(statements, daten, zusatz);
    if (r == null || r < 0 || r > 2) r = 0;
    return r;
  }

  static Future<List<Coord>> readCoords() async {
    Map<String, Map<String, dynamic>> daten = {};
    Map<String, List> zusatz = {};
    Map<String, Coord> map = {};
    final resD = getAllData("daten");
    for (final res in resD) {
      final coord = Coord();
      coord.lat = res["lat"];
      coord.lon = res["lon"];
      coord.hasImage = false;
      final key = '${res["lat_round"]}:${res["lon_round"]}';
      map[key] = coord;
      daten[key] = res;
    }
    if (hasZusatz) {
      final resZ = getAllData("zusatz");
      for (final res in resZ) {
        final key = '${res["lat_round"]}:${res["lon_round"]}';
        List l = zusatz[key];
        if (l == null) {
          l = [];
          zusatz[key] = l;
        }
        l.add(res);
        var coord = map[key];
        if (coord == null) {
          coord = Coord();
          coord.lat = res["lat"];
          coord.lon = res["lon"];
          coord.hasImage = false;
          map[key] = coord;
        }
      }
    }
    final resI = getAllData("images");
    for (final res in resI) {
      final key = '${res["lat_round"]}:${res["lon_round"]}';
      var coord = map[key];
      if (coord == null) {
        coord = Coord();
        coord.lat = res["lat"];
        coord.lon = res["lon"];
        map[key] = coord;
      }
      coord.hasImage = true;
    }

    map.forEach((key, coord) {
      final m = daten[key] != null ? makeWritableMap(daten[key]) : {};
      final z = zusatz[key];
      List l;
      if (z != null) {
        l = makeWritableList(z);
      } else {
        l = [];
      }
      coord.quality = qualityOfLoc(m, l);
    });
    return map.values.toList();
  }

  static void deleteAllLoc(double lat, double lon) {
    locData = {"daten": {}, "zusatz": {}, "images": {}};
  }

  static void delLocDataOld(String table) {
    for (List l in locData[table].values) {
      l.removeWhere((m) => m["new_or_modified"] == null);
    }
  }

  static Future<void> deleteOldData() async {
    delLocDataOld("daten");
    delLocDataOld("zusatz");
    delLocDataOld("images");
  }

  static void deleteZusatz(int nr) {
    List l = getLocData("zusatz", latRound, lonRound);
    l.removeWhere((m) => m["nr"] == nr);
  }

  static Future<void> deleteImage(String imgPath) async {
    for (String k in locData["images"].keys) {
      List l = locData["images"][k];
      l.removeWhere((m) => m["image_path"] == imgPath);
    }
  }

  static Future<void> fillWithDBValues(Map values) async {
    Map newData = await getNewData(); // save new data
    for (String table in values.keys) {
      bool isZusatz = table == "zusatz";

      List rows = values[table];
      if (rows == null) continue;
      // sort for modification date: newer records overwrite older ones
      switch (table) {
        case "daten":
          rows.sort((r1, r2) => (r1[2] as String).compareTo(r2[2] as String));
          break;
        case "zusatz":
          rows.sort((r1, r2) => (r1[3] as String).compareTo(r2[3] as String));
          break;
      }
      final cnames = colNames[table];
      int l = cnames.length - 1; // no new_or_modified in newData
      for (final row in rows) {
        assert(row.length == l);
        Map<String, Object> data = {};
        for (int i = 0; i < l; i++) {
          data[cnames[i]] = row[i];
        }
        insert(table, data);
      }
      // restore new data
      rows = newData[table];
      for (final map in rows) {
        if (isZusatz) map['nr'] = nrInc++;
        insert(table, map);
      }
    }
  }

  static Future<Set> getNewImagePaths() async {
    final set = Set();
    final resI = getAllData("images");
    for (final data in resI) {
      if (data["new_or_modified"] != null) {
        set.add(data["image_path"]);
      }
    }
    return set;
  }

  static Future<void> clearNewOrModified() async {
    for (final table in ["daten", if (hasZusatz) "zusatz", "images"]) {
      final resT = getAllData(table);
      for (final data in resT) {
        data["new_or_modified"] = null;
      }
    }
  }
}