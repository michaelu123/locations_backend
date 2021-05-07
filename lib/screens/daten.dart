import 'package:flutter/material.dart';
// import 'package:locations/providers/markers.dart';
import 'package:locations/utils/db.dart';
// import 'package:locations/providers/photos.dart';
import 'package:locations/providers/settings.dart';
import 'package:locations/screens/zusatz.dart';
import 'package:locations/screens/bilder.dart';
import 'package:locations/screens/karte.dart';
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

  @override
  void initState() {
    super.initState();
    final baseConfigNL = Provider.of<BaseConfig>(context, listen: false);
    initFelder(context, baseConfigNL, false);
  }

  void cboxChanged(int index, bool b) {
    final baseConfigNL = Provider.of<BaseConfig>(context, listen: false);
    final locDataNL = Provider.of<LocData>(context, listen: false);
    List felder = baseConfigNL.getDatenFelder();
    String name = felder[index]["name"];
    setState(() => locDataNL.setCBox(name, index, b));
  }

  void allBoxesChanged(bool b) {
    final locDataNL = Provider.of<LocData>(context, listen: false);
    setState(() => locDataNL.setAllBoxes(b));
  }

  @override
  void dispose() {
    super.dispose();
    deleteFelder();
  }

  void nochMal() async {
    final locDataNL = Provider.of<LocData>(context, listen: false);
    final baseConfigNL = Provider.of<BaseConfig>(context, listen: false);
    LocationsDB.storeDaten(prevDaten);
    prevDaten = null;
    final map = await LocationsDB.dataFor(
        LocationsDB.lat, LocationsDB.lon, baseConfigNL.stellen());
    locDataNL.dataFor("daten", map);
    locDataNL.fillCheckboxValues(baseConfigNL.getDatenFelder());
  }

  @override
  Widget build(BuildContext context) {
    final baseConfig = Provider.of<BaseConfig>(context);
    final settingsNL = Provider.of<Settings>(context, listen: false);
    final felder = baseConfig.getDatenFelder();
    final locData = Provider.of<LocData>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(baseConfig.getName() + "/Daten"),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              if (baseConfig.hasZusatz())
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber,
                  ),
                  onPressed: () async {
                    final locDataNL =
                        Provider.of<LocData>(context, listen: false);
                    final map = await LocationsDB.dataForSameLoc();
                    locDataNL.dataFor("zusatz", map);
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
              if (locData.moreThanOne())
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.lightGreen[200],
                  ),
                  onPressed: () => prevDaten = locData.vereinigen(),
                  child: const Text(
                    'Vereinigen',
                  ),
                ),
              if (prevDaten != null)
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.lightGreen[200],
                  ),
                  onPressed: nochMal,
                  child: const Text(
                    'Nochmal',
                  ),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.lightGreen[200],
                ),
                onPressed: () {},
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
                onPressed: locData.canDecDaten() ? locData.decIndexDaten : null,
              ),
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.add),
                onPressed: locData.isEmpty() ? locData.addDaten : null,
              ),
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.arrow_forward),
                onPressed: locData.canIncDaten() ? locData.incIndexDaten : null,
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
          if (locData.isEmpty())
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
          if (!locData.isEmpty())
            Expanded(
              child: settingsNL.getConfigValueS("username", defVal: "").isEmpty
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                ))
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
