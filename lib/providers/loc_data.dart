import 'package:flutter/foundation.dart';
import 'package:locations/utils/db.dart';
import 'package:locations/providers/markers.dart';

class LocData with ChangeNotifier {
  // data read from / written to DB
  List locDaten = [];
  int datenIndex = 0;
  List locImages = [];
  int imagesIndex = 0;
  List locZusatz = [];
  bool isZusatz = false;
  int zusatzIndex = 0;
  List<List<bool>> checkBoxValuesList;
  List<bool> checkBoxAllSet;
  List<bool> checkBoxValues;
  List<String> checkBoxIndex2Name;
  Map<String, int> checkBoxName2Index;

  void dataFor(String table, Map data) {
    isZusatz = table == "zusatz";
    locDaten = data["daten"]; // newest is last
    locZusatz = data["zusatz"];
    locImages = data["images"];
    datenIndex = 0;
    zusatzIndex = 0;
    imagesIndex = 0;
    notifyListeners();
  }

  void fillCheckboxValues(List felder) {
    int ld = locDaten.length;
    int lf = felder.length;
    checkBoxValuesList = List.filled(ld, null);
    checkBoxAllSet = List.filled(ld, false);
    checkBoxName2Index = Map<String, int>();
    checkBoxIndex2Name = List.filled(lf, "");
    for (int i = 0; i < ld; i++) {
      List<bool> lb = List.filled(lf, false);
      checkBoxValuesList[i] = lb;
    }
    checkBoxValues = checkBoxValuesList[datenIndex];
    for (int i = 0; i < lf; i++) {
      checkBoxIndex2Name[i] = felder[i]["name"];
      checkBoxName2Index[felder[i]["name"]] = i;
    }
    for (int i = ld - 1; i >= 0; i--) {
      for (int j = 0; j < lf; j++) {
        bool set = false;
        for (int k = i + 1; k < ld; k++) {
          if (checkBoxValuesList[k][j]) set = true;
        }
        if (!set && locDaten[i][checkBoxIndex2Name[j]] != null)
          checkBoxValuesList[i][j] = true;
      }
    }
    setCBox("created", checkBoxName2Index["created"], true);
  }

  void clearLocData() {
    locDaten = [];
    locZusatz = [];
    locImages = [];
    isZusatz = false;
  }

  Future<void> setFeld(Markers markers, String region, String name, String type,
      Object val, String userName) async {
    Map res;
    if (isZusatz) {
      // print("setZusatz $name $type $val $zusatzIndex");
      final v = locZusatz[zusatzIndex][name];
      if (v != val) {
        int nr = locZusatz[zusatzIndex]["nr"];
        locZusatz[zusatzIndex][name] = val;
        res = await LocationsDB.updateRowDB(
            "zusatz", region, name, val, userName, 0,
            nr: nr);
        nr = res["nr"];
        //print(
        //    "LocZusatz index=$zusatzIndex nr=$nr $name changed from $v to $val");
        if (nr != null) locZusatz[zusatzIndex]["nr"] = nr;
        final created = res["created"];
        if (created != null) {
          locZusatz[zusatzIndex]["created"] = created;
          locZusatz[zusatzIndex]["modified"] = created;
        }
        final modified = res["modified"];
        if (modified != null) {
          locZusatz[zusatzIndex]["modified"] = modified;
        }
        notifyListeners();
      }
    } else {
      // print("setDaten $name $type $val");
      final v = locDaten[datenIndex][name];
      if (v != val) {
        locDaten[datenIndex][name] = val;
        res = await LocationsDB.updateRowDB(
            "daten", region, name, val, userName, datenIndex);
        // print("LocDatum $name changed from $v to $val");
        final created = res["created"];
        if (created != null) {
          locDaten[datenIndex]["created"] = created;
          locDaten[datenIndex]["modified"] = created;
        }
        final modified = res["modified"];
        if (modified != null) {
          locDaten[datenIndex]["modified"] = modified;
        }
        notifyListeners();
      }
    }

    final coord = Coord();
    coord.lat = LocationsDB.lat;
    coord.lon = LocationsDB.lon;
    coord.quality =
        LocationsDB.qualityOfLoc(locDaten[datenIndex], locZusatz, 1);
    coord.hasImage = locImages.length > 0;
    markers.current(coord);
    // no notify
  }

  String getFeldText(String name, String type) {
    dynamic t;
    if (isZusatz) {
      if (locZusatz.length == 0) return "";
      if (zusatzIndex >= locZusatz.length) zusatzIndex = 0;
      t = locZusatz[zusatzIndex][name];
    } else {
      if (datenIndex >= locDaten.length) datenIndex = 0;
      t = locDaten[datenIndex][name];
    }
    if (t == null) return "";
    if (type == "bool") return t == 1 ? "ja" : "nein";
    return t.toString();
  }

  void decIndexZusatz() {
    if (zusatzIndex > 0) {
      zusatzIndex--;
      notifyListeners();
    }
  }

  void incIndexZusatz() {
    if (zusatzIndex < locZusatz.length - 1) {
      zusatzIndex++;
      notifyListeners();
    }
  }

  void addDaten() {
    locDaten.add(Map<String, Object>());
    datenIndex = 0;
    notifyListeners();
  }

  bool canDecDaten() {
    return datenIndex > 0;
  }

  void decIndexDaten() {
    if (datenIndex > 0) {
      datenIndex--;
      checkBoxValues = checkBoxValuesList[datenIndex];
      notifyListeners();
    }
  }

  bool canIncDaten() {
    return datenIndex < (locDaten.length - 1);
  }

  void incIndexDaten() {
    if (datenIndex < locDaten.length - 1) {
      datenIndex++;
      checkBoxValues = checkBoxValuesList[datenIndex];
      notifyListeners();
    }
  }

  bool isEmpty() {
    return (isZusatz ? locZusatz.length : locDaten.length) == 0;
  }

  void addZusatz() {
    locZusatz.add(Map<String, Object>());
    zusatzIndex = locZusatz.length - 1;
    notifyListeners();
  }

  bool canDecZusatz() {
    return zusatzIndex > 0;
  }

  bool canIncZusatz() {
    return zusatzIndex < (locZusatz.length - 1);
  }

  int deleteZusatz() {
    int nr = locZusatz[zusatzIndex]["nr"];
    locZusatz.removeAt(zusatzIndex);
    if (zusatzIndex >= locZusatz.length) zusatzIndex = locZusatz.length - 1;
    notifyListeners();
    return nr;
  }

  int getImagesCount() {
    return locImages.length;
  }

  void setImagesIndex(int x) {
    imagesIndex = x;
  }

  String getImgUrl(int index) {
    return locImages[index]["image_url"];
  }

  String getImgPath(int index) {
    return locImages[index]["image_path"];
  }

  String getImgCreated(int index) {
    return locImages[index]["created"];
  }

  String getImgBemerkung(int index) {
    return locImages[index]["bemerkung"];
  }

  void setImgBemerkung(String text, int index) {
    locImages[index]["bemerkung"] = text;
    String imgPath = getImgPath(index);
    LocationsDB.updateImagesDB(imgPath, "bemerkung", text);
  }

  bool isEmptyImages() {
    return (locImages.length) == 0;
  }

  int addImage(Map map, Markers markers) {
    locImages.add(map);
    imagesIndex = locImages.length - 1;
    notifyListeners();

    final coord = Coord();
    coord.lat = LocationsDB.lat;
    coord.lon = LocationsDB.lon;
    coord.quality =
        LocationsDB.qualityOfLoc(locDaten[datenIndex], locZusatz, 1);
    coord.hasImage = locImages.length > 0;
    markers.current(coord);

    return imagesIndex;
  }

  String deleteImage(Markers markers) {
    String imgPath = locImages[imagesIndex]["image_path"];
    locImages.removeAt(imagesIndex);
    if (imagesIndex >= locImages.length) imagesIndex = locImages.length - 1;
    notifyListeners();

    final coord = Coord();
    coord.lat = LocationsDB.lat;
    coord.lon = LocationsDB.lon;
    coord.quality =
        LocationsDB.qualityOfLoc(locDaten[datenIndex], locZusatz, 1);
    coord.hasImage = locImages.length > 0;
    markers.current(coord);

    return imgPath;
  }

  String getImagePath() {
    if (locImages.length == 0) return null;
    final imagePath = locImages[imagesIndex]["image_path"];
    return imagePath;
  }

  String getImageUrl() {
    if (locImages.length == 0) return null;
    final imageUrl = locImages[imagesIndex]["image_url"];
    return imageUrl;
  }

  void setIsZusatz(bool b) {
    if (isZusatz == b) return;
    isZusatz = b;
    notifyListeners();
  }

  void setCBox(String name, int index, bool b) {
    print("setCBox $name $index $datenIndex $b");
    if (b) {
      for (int i = 0; i < locDaten.length; i++)
        checkBoxValuesList[i][index] = false;
    }
    checkBoxValues[index] = b;
  }

  bool getCboxValue(int index) {
    return checkBoxValues[index];
  }

  void setAllBoxes(bool b) {
    if (b) {
      for (int i = 0; i < locDaten.length; i++) {
        List<bool> lb = checkBoxValuesList[i];
        int l = lb.length;
        for (int j = 0; j < l; j++) lb[j] = false;
        checkBoxAllSet[i] = false;
      }
    }
    int l = checkBoxValues.length;
    for (int j = 0; j < l; j++) checkBoxValues[j] = b;
    checkBoxAllSet[datenIndex] = b;
  }

  bool getAllBoxesSetValue() {
    return checkBoxAllSet[datenIndex];
  }

  bool moreThanOne() {
    return locDaten.length > 1;
  }

  List vereinigen() {
    int ld = locDaten.length;
    int lf = checkBoxValues.length;
    Map<String, Object> res = {...locDaten[ld - 1]};
    for (int i = ld - 2; i >= 0; i--) {
      for (int j = 0; j < lf; j++) {
        if (checkBoxValuesList[i][j]) {
          String name = checkBoxIndex2Name[j];
          res[name] = locDaten[i][name];
        }
      }
    }
    res["new_or_modified"] = 1;
    locDaten = [res];
    List prev = LocationsDB.storeDaten(locDaten);
    datenIndex = 0;
    setAllBoxes(false);
    notifyListeners();
    return prev;
  }
}
