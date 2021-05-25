import 'package:flutter/material.dart';
import 'package:locations/providers/markers.dart';
import 'package:locations/providers/storage.dart';
// import 'package:locations/providers/markers.dart';
import 'package:locations/utils/db.dart';
// import 'package:locations/providers/photos.dart';
import 'package:locations/providers/settings.dart';
import 'package:locations/screens/zusatz.dart';
import 'package:locations/screens/bilder.dart';
import 'package:locations/screens/karte.dart';
import 'package:locations/utils/utils.dart';
import 'package:provider/provider.dart';

import 'package:locations/providers/base_config.dart';
import 'package:locations/providers/loc_data.dart';
import 'package:locations/utils/felder.dart';

class DatenScreen extends StatefulWidget {
  static String routeName = "/daten";
  @override
  _DatenScreenState createState() => _DatenScreenState();
}

class _DatenScreenState extends State<DatenScreen> with Felder {
  List prevDaten;
  BaseConfig baseConfigNL;
  Markers markersNL;
  LocData locDataNL;
  Storage strgClntNL;
  Settings settingsNL;
  String tableBase;
  String userName;

  @override
  void initState() {
    super.initState();
    baseConfigNL = Provider.of<BaseConfig>(context, listen: false);
    markersNL = Provider.of<Markers>(context, listen: false);
    locDataNL = Provider.of<LocData>(context, listen: false);
    strgClntNL = Provider.of<Storage>(context, listen: false);
    settingsNL = Provider.of<Settings>(context, listen: false);
    tableBase = baseConfigNL.getDbTableBaseName();
    userName = settingsNL.getConfigValueS("username");
    initFelder(context, false);
  }

  void cboxChanged(int index, bool b) {
    List felder = baseConfigNL.getDatenFelder();
    String name = felder[index]["name"];
    setState(() => locDataNL.setCBox(name, index, b));
  }

  void allBoxesChanged(bool b) {
    setState(() => locDataNL.setAllBoxes(b));
  }

  @override
  void dispose() {
    super.dispose();
    deleteFelder();
  }

  void nochMal() async {
    LocationsDB.storeDaten(prevDaten);
    prevDaten = null;
    final map = await LocationsDB.dataFor(
        LocationsDB.lat, LocationsDB.lon, baseConfigNL.stellen());
    locDataNL.dataFor(tableBase, "daten", map);
    locDataNL.fillCheckboxValues(baseConfigNL.getDatenFelder());
  }

  void offiziell() async {
    Map<String, Object> val = locDataNL.getDaten();
    val["creator"] = "STAMM";
    await strgClntNL.official(tableBase, val);
    val.remove("_united");
    prevDaten = null;
    setState(() {});
    locDataNL.notifyListeners();
  }

  Future<void> deleteLoc(Markers markers) async {
    if (!await areYouSure(context,
        'Wollen Sie wirklich ALLE Daten und Bilder dieses Ortes löschen?'))
      return;
    LocationsDB.deleteLoc(
      LocationsDB.latRound,
      LocationsDB.lonRound,
    );
    await strgClntNL.deleteLoc(
        tableBase, LocationsDB.latRound, LocationsDB.lonRound);
    int imgCnt = locDataNL.getImagesCount();
    for (int i = 0; i < imgCnt; i++) {
      String imgPath = locDataNL.getImgPath(i);
      await strgClntNL.deleteImage(tableBase, imgPath);
    }
    markers.deleteLoc(LocationsDB.latRound, LocationsDB.lonRound);
    locDataNL.clearLocData();
    setState(() {});
    Navigator.of(context)
        .pushNamedAndRemoveUntil(KartenScreen.routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final baseConfig = Provider.of<BaseConfig>(context, listen: true);
    final felder = baseConfig.getDatenFelder();
    final locData = Provider.of<LocData>(context, listen: true);

    return WillPopScope(
      onWillPop: () async {
        return prevDaten == null;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(baseConfig.getName() + "/Daten"), actions: [
          if (userName == "admin")
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => deleteLoc(markersNL),
            ),
        ]),
        body: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (prevDaten == null)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          KartenScreen.routeName, (_) => false);
                    },
                    child: const Text(
                      'Karte',
                    ),
                  ),
                if (prevDaten == null && baseConfig.hasZusatz())
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    onPressed: () async {
                      final map = await LocationsDB.dataForSameLoc();
                      locDataNL.dataFor(tableBase, "zusatz", map);
                      await Navigator.of(context)
                          .pushNamed(ZusatzScreen.routeName);
                      // without the next statement, after pressing back button
                      // from zusatz the datenscreen shows wrong data
                      locDataNL.setIsZusatz(false);
                    },
                    child: const Text(
                      'Zusatzdaten',
                    ),
                  ),
                if (prevDaten == null)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamed(ImagesScreen.routeName);
                    },
                    child: const Text(
                      'Bilder',
                    ),
                  ),
                if (userName == "admin" && locData.moreThanOne())
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.lightGreen[200],
                    ),
                    onPressed: () => prevDaten = locData.vereinigen(),
                    child: const Text(
                      'Vereinigen',
                    ),
                  ),
                if (userName == "admin" && prevDaten != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.lightGreen[200],
                    ),
                    onPressed: nochMal,
                    child: const Text(
                      'Nochmal',
                    ),
                  ),
                if (!locData.moreThanOne() &&
                    userName == "admin" &&
                    (prevDaten != null || locData.creator() != "STAMM"))
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.lightGreen[200],
                    ),
                    onPressed: offiziell,
                    child: const Text(
                      'Offiziell',
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.arrow_back),
                  onPressed:
                      locData.canDecDaten() ? locData.decIndexDaten : null,
                ),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.add),
                  onPressed: locData.isEmptyDaten() ? locData.addDaten : null,
                ),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.arrow_forward),
                  onPressed:
                      locData.canIncDaten() ? locData.incIndexDaten : null,
                ),
              ],
            ),
            if (locData.moreThanOne())
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 60,
                    child: Checkbox(
                        value: locData.getAllBoxesSetValue(),
                        onChanged: (b) => allBoxesChanged(b)),
                  ),
                  Expanded(child: Text("Alle Checkboxen setzen/löschen"))
                ],
              ),
            if (locData.isEmptyDaten())
              const Center(
                child: const Text(
                  "Noch keine Daten eingetragen",
                  style: const TextStyle(
                    backgroundColor: Colors.white,
                    color: Colors.black,
                    fontSize: 20,
                  ),
                ),
              ),
            if (!locData.isEmptyDaten())
              Expanded(
                child: settingsNL
                        .getConfigValueS("username", defVal: "")
                        .isEmpty
                    ? const Center(
                        child: Text(
                          "Bitte erst einen Benutzer/Spitznamen eingeben",
                          style: TextStyle(
                            backgroundColor: Colors.white,
                            color: Colors.black,
                            fontSize: 20,
                          ),
                        ),
                      )
                    : Consumer<LocData>(
                        builder: (ctx, locDaten, _) {
                          setFelder(locDaten, baseConfig, false);
                          return ListView.builder(
                            itemCount: felder.length,
                            itemBuilder: (ctx, index) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (locData.moreThanOne())
                                    SizedBox(
                                      width: 60,
                                      child: Checkbox(
                                          value: locData.getCboxValue(index),
                                          onChanged: (b) =>
                                              cboxChanged(index, b)),
                                    ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: textFields[index],
                                    ),
                                  )
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
