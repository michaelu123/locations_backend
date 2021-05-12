import 'package:intl/intl.dart';
import 'package:locations/parser/parser.dart';
import 'package:locations/providers/base_config.dart';
import 'package:locations/utils/utils.dart';

class Coord {
  double lat;
  double lon;
  int quality;
  bool hasImage;
  int count;
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
  static Map<String, Map<String, List<Map<String, Object>>>> locDataDB;
  static DateFormat dateFormatterDB = DateFormat('yyyy.MM.dd HH:mm:ss');
  static int nrInc = 0;

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
    // statements = parseProgram("if _count > 1 then return 2 end; return -1");

    locDataDB = {"daten": {}, "zusatz": {}, "images": {}};
  }

  static String keyFor(String latRound, String lonRound) {
    return latRound + ":" + lonRound;
  }

  static String keyOf(Map<String, Object> data) {
    return keyFor(data["lat_round"].toString(), data["lon_round"].toString());
  }

  static Future<int> insert(String table, Map<String, Object> data) async {
    String key = keyOf(data);
    List<Map<String, Object>> entries = locDataDB[table][key];
    if (entries == null) {
      entries = [data];
      locDataDB[table][key] = entries;
    } else {
      switch (table) {
        case "daten": // server has primary key (creator, lat, lon)
          final creator = data["creator"];
          entries.removeWhere((row) => row["creator"] == creator);
          break;
        case "zusatz":
          final nr = data["nr"];
          entries.removeWhere((row) => row["nr"] == nr);
          break;
      }
      entries.add(data);
    }
    return entries.length - 1;
  }

  static List<Map<String, Object>> getAllData(String table) {
    // https://stackoverflow.com/questions/15413248/how-to-flatten-a-list
    return locDataDB[table].values.expand((l) => l).toList();
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
    return locDataDB[table][keyFor(latRound, lonRound)] ?? [];
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
    for (List l in locDataDB[table].values) {
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

  static Future<Map> updateRowDB(String table, String region, String name,
      Object val, String userName, int index,
      {int nr}) async {
    final now = dateFormatterDB.format(DateTime.now());
    List l = getLocData(table, latRound, lonRound);
    Map<String, Object> m = l[index];
    // m[name]=value already done by LocData.setFeld
    m["new_or_modified"] = 1;
    if (m["lat"] == null) {
      m["region"] = region;
      m["lat"] = lat;
      m["lon"] = lon;
      m["lat_round"] = latRound;
      m["lon_round"] = lonRound;
      m["creator"] = userName;
      m[name] = val;
      if (table == "zusatz") {
        m["nr"] = nrInc++;
      }
      return {"created": now};
    }
    return {"modified": now};
  }

  static Future<void> updateImagesDB(
      String imagePath, String name, Object val) async {
    assert(false);
  }

  static int qualityOfLoc(Map daten, List zusatz, int count) {
    daten["_count"] = count;
    int r = evalProgram(statements, daten, zusatz);
    if (r == null)
      r = 0;
    else if (r > 2)
      r = 2;
    else if (r < 0) r = -1;
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
      final key = keyOf(res);
      final prev = map[key];
      coord.count = prev != null ? prev.count + 1 : 1;
      // here, newer records replace older ones
      map[key] = coord;
      daten[key] = res;
    }
    if (hasZusatz) {
      final resZ = getAllData("zusatz");
      for (final res in resZ) {
        final key = keyOf(res);
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
          coord.count = 0;
          map[key] = coord;
        }
      }
    }
    final resI = getAllData("images");
    for (final res in resI) {
      final key = keyOf(res);
      var coord = map[key];
      if (coord == null) {
        coord = Coord();
        coord.lat = res["lat"];
        coord.lon = res["lon"];
        coord.count = 0;
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
      coord.quality = qualityOfLoc(m, l, coord.count);
      // coord.quality = coord.count > 2 ? 2 : coord.count;
    });
    return map.values.toList();
  }

  static void delLocDataLatLon(String table, String latRound, String lonRound) {
    final key = keyFor(latRound, lonRound);
    locDataDB[table].remove(key);
  }

  static void deleteLoc(String latRound, String lonRound) {
    delLocDataLatLon("daten", latRound, lonRound);
    if (hasZusatz) {
      delLocDataLatLon("zusatz", latRound, lonRound);
    }
    delLocDataLatLon("images", latRound, lonRound);
  }

  static void delLocDataOld(String table) {
    for (List l in locDataDB[table].values) {
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
    for (String k in locDataDB["images"].keys) {
      List l = locDataDB["images"][k];
      l.removeWhere((m) => m["image_path"] == imgPath);
    }
  }

  static Future<void> fillWithDBValues(Map values) async {
    Map newData = await getNewData(); // save new data
    for (String table in values.keys) {
      bool isZusatz = table == "zusatz";

      List rows = values[table];
      if (rows == null) continue;
      final cnames = colNames[table];
      int l = cnames.length - 1; // no new_or_modified in newData
      for (final row in rows) {
        assert(row.length == l);
        Map<String, Object> data = {};
        for (int i = 0; i < l; i++) {
          data[cnames[i]] = row[i];
        }
        data["new_or_modified"] = null;
        if (isZusatz) {
          int nr = data["nr"];
          if (nr >= nrInc) nrInc = nr + 1;
        }
        insert(table, data);
      }
      Map<String, List<Map<String, Object>>> entries = locDataDB[table];
      for (List<Map<String, Object>> locs in entries.values) {
        // sort for modification date: newer records come after older ones
        if (table == "images") {
          locs.sort((r1, r2) =>
              (r1["created"] as String).compareTo(r2["created"] as String));
        } else {
          locs.sort((r1, r2) =>
              (r1["modified"] as String).compareTo(r2["modified"] as String));
        }
      }
      // restore new data
      rows = newData[table];
      for (final map in rows) {
        // if (isZusatz) map['nr'] = nrInc++;
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

  static List<Map<String, Object>> storeDaten(List locDaten) {
    String k = keyFor(latRound, lonRound);
    List<Map<String, Object>> prev = locDataDB["daten"][k];
    locDataDB["daten"][k] = locDaten.cast<Map<String, Object>>();
    return prev;
  }
}
