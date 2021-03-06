import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:locations/parser/val.dart';
import 'package:locations/providers/locations_client.dart';
import 'package:locations/screens/locaccount.dart';

import 'firebasepy.dart';

class Storage extends ChangeNotifier {
  bool useLoc = true;
  LocationsClient locClnt;
  FirebaseClient fbClnt;

  void setClnt(bool useLoc) {
    if (useLoc != this.useLoc) {
      if (this.useLoc) {
        LocAuth.instance.signOut();
      } else {
        fbClnt.logoff();
      }
    }
    this.useLoc = useLoc;
    if (locClnt == null) locClnt = LocationsClient();
    if (fbClnt == null) fbClnt = FirebaseClient();
  }

  void init(
      {String serverUrl,
      String extPath,
      List datenFelder,
      List zusatzFelder,
      List imagesFelder}) async {
    bool hasZusatz = zusatzFelder.length > 0;
    locClnt.init(serverUrl, extPath, hasZusatz);
    fbClnt.init(extPath);
    fbClnt.initFelder(datenFelder, zusatzFelder, imagesFelder);
  }

  void initFelder({List datenFelder, List zusatzFelder, List imagesFelder}) {
    fbClnt.initFelder(datenFelder, zusatzFelder, imagesFelder);
  }

  Future<void> sayHello(String tableBase) async {
    if (useLoc) return locClnt.sayHello(tableBase);
    return fbClnt.sayHello(tableBase);
  }

  Future<Map> postImage(String tableBase, String imgName) async {
    if (useLoc) return locClnt.postImage(tableBase, imgName);
    return fbClnt.postImage(tableBase, imgName);
  }

  Future<void> post(String tableBase, Map values) async {
    for (Map val in (values["daten"] ?? [])) {
      val = val.cast<String, Object>();
      val.removeWhere((k, v) => v is Value);
      val.removeWhere((k, v) => k.startsWith("_"));
      val.remove("new_or_modified");
    }
    if (useLoc) return locClnt.post(tableBase, values);
    return fbClnt.post(tableBase, values);
  }

  Future<Map> getValuesWithin(String tableBase, String region, double minlat,
      double maxlat, double minlon, double maxlon) async {
    if (useLoc)
      return locClnt.getValuesWithin(
          tableBase, region, minlat, maxlat, minlon, maxlon);
    return fbClnt.getValuesWithin(
        tableBase, region, minlat, maxlat, minlon, maxlon);
  }

  Future<File> getImage(
      String tableBase, String imgName, int maxdim, bool thumbnail) async {
    // res[0] = imgFile, res[1] = notify, because thumbnail can be replaced
    // with full res image
    List res;
    if (useLoc) {
      res = await locClnt.getImage(tableBase, imgName, maxdim, thumbnail);
    } else {
      res = await fbClnt.getImage(tableBase, imgName, maxdim, thumbnail);
    }
    if (res == null) return null;
    if (res[1]) {
      notifyListeners(); // changed from thumbnail to full image
    }
    return res[0];
  }

  Future<void> copyLoc2Fb(String tableBase, int maxdim) async {
    Map values =
        await locClnt.getValuesWithin(tableBase, "", -90, 90, -180, 180);
    final imageList = values["images"];
    for (final imageRow in imageList) {
      String imgName = imageRow[6];
      List lcres = await locClnt.getImage(tableBase, imgName, maxdim, false);
      File imgFile = lcres[0];
      if (imgFile == null) continue;
      Map res = await fbClnt.postImage(tableBase, imgName);
      String url = res["url"];
      imageRow[7] = url;
    }
    fbClnt.postRows(tableBase, values);
    print("copyLoc2Fb done");
  }

  Future<List> getConfigs() async {
    if (useLoc) return locClnt.getConfigs();
    return fbClnt.getConfigs();
  }

  Future<Map> getConfig(String config) async {
    if (useLoc) return locClnt.getConfig(config);
    return fbClnt.getConfig(config);
  }

  Future<void> official(String tableBase, Map<String, Object> val) {
    val.removeWhere((k, v) => v is Value);
    val.removeWhere((k, v) => k.startsWith("_"));
    val.remove("new_or_modified");
    if (useLoc) return locClnt.official(tableBase, val);
    return fbClnt.official(tableBase, val);
  }

  Future<void> deleteLoc(String tableBase, String latRound, String lonRound) {
    if (useLoc) return locClnt.deleteLoc(tableBase, latRound, lonRound);
    return fbClnt.deleteLoc(tableBase, latRound, lonRound);
  }

  Future<void> deleteImage(String tableBase, String imgPath) {
    if (useLoc) return locClnt.deleteImage(tableBase, imgPath);
    return fbClnt.deleteImage(tableBase, imgPath);
  }

  Future<List> getMarkerCodeNames(String tableBase) async {
    if (useLoc) return locClnt.getMarkerCodeNames(tableBase);
    return fbClnt.getMarkerCodeNames(tableBase);
  }

  Future<Map> getMarkerCode(String tableBase, String name) async {
    if (useLoc) return locClnt.getMarkerCode(tableBase, name);
    return fbClnt.getMarkerCode(tableBase, name);
  }

  Future<void> postMarkerCode(
      String tableBase, String name, String codeJS) async {
    if (useLoc) return locClnt.postMarkerCode(tableBase, name, codeJS);
    return fbClnt.postMarkerCode(tableBase, name, codeJS);
  }

  Future<void> deleteMarkerCode(String tableBase, String name) async {
    if (useLoc) return locClnt.deleteMarkerCode(tableBase, name);
    return fbClnt.deleteMarkerCode(tableBase, name);
  }
}
