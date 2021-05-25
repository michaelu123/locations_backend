import 'dart:convert';
import 'dart:io';
import 'package:locations/providers/markers.dart';
import 'package:locations/providers/settings.dart';
import 'package:locations/screens/karte.dart';
import 'package:locations/screens/splash_screen.dart';
import 'package:locations/utils/db.dart';
import 'package:locations/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:locations/parser/parser.dart';
import 'package:locations/providers/base_config.dart';
import 'package:locations/providers/storage.dart';
import 'package:provider/provider.dart';

class MarkerCodeScreen extends StatefulWidget {
  static String routeName = "/markercode";

  @override
  _MarkerCodeScreenState createState() => _MarkerCodeScreenState();
}

class _MarkerCodeScreenState extends State<MarkerCodeScreen> {
  static String progName;
  static List<String> progNames;
  static Map<String, String> progs = {};
  static Map<String, String> descs = {};

  BaseConfig baseConfigNL;
  Storage strgClntNL;
  Settings settingsNL;
  Markers markersNL;
  String tableBase;
  List<Statement> statements;
  Future mcFuture;
  String extPath;
  String markerCodePath;
  final String chooseProg = "Marker-Code wählen";
  String copyProg = "";
  String errorMessage;
  final nameCtrlr = TextEditingController();
  final codeCtrlr = TextEditingController();
  final descCtrlr = TextEditingController();
  final errorCtrlr = TextEditingController();

  @override
  void initState() {
    super.initState();
    baseConfigNL = Provider.of<BaseConfig>(context, listen: false);
    strgClntNL = Provider.of<Storage>(context, listen: false);
    settingsNL = Provider.of<Settings>(context, listen: false);
    markersNL = Provider.of<Markers>(context, listen: false);

    tableBase = baseConfigNL.getDbTableBaseName();

    progNames = ["Standard", "Neu", "_div_"] + baseConfigNL.getProgNames();
    final name = settingsNL.getConfigValueS("progName", defVal: "Standard");
    copyProg = "";
    if (progName == null) progName = "Standard";
    extPath = getExtPath();
    markerCodePath = path.join(extPath, "markerCode", tableBase);
    mcFuture = setProgram(name);
  }

  Future<void> setProgram(String name) async {
    if (name == "Standard") {
      nameCtrlr.text = "Standard";
      codeCtrlr.text = baseConfigNL.getProgram();
      descCtrlr.text = "Standard-Code, definiert in der config-Datei";
      copyProg = "";
      if (name == progName) return;
    } else if (name == "Neu") {
      nameCtrlr.text = "";
      codeCtrlr.text = "";
      descCtrlr.text = "";
      setState(() => progName = name);
      return;
    } else {
      if (progs[name] == null) {
        File f = File(path.join(markerCodePath, name + ".json"));
        if (!await f.exists()) {
          screenMessage(context, "Datei $f nicht gefunden");
          return;
        }
        final content = await f.readAsString();
        final Map codeJS = json.decode(content);
        progs[name] = codeJS["code"];
        descs[name] = codeJS["desc"];
      }
      nameCtrlr.text = name;
      codeCtrlr.text = progs[name];
      descCtrlr.text = descs[name];
      copyProg = "";
    }
    errorMessage = null;
    if (name == progName || name == "Neu") return;
    settingsNL.setConfigValue("progName", name);
    if (codeCtrlr.text != "") {
      statements = parseProgram(codeCtrlr.text);
      if (statements == null || statements.isEmpty) {
        setState(() {
          errorMessage = getErrorMessage();
        });
        print("ERR $errorMessage");
        errorCtrlr.text = errorMessage;
        return;
      }
      LocationsDB.setProgram(statements);
      // await LocationsDB.setBaseDB(baseConfigNL);
      await markersNL.readMarkersAgain();
    }

    setState(() => progName = name);
  }

  Future<void> speichern() async {
    statements = parseProgram(codeCtrlr.text);
    if (statements == null || statements.isEmpty) {
      setState(() {
        errorMessage = getErrorMessage();
      });
      print("ERR $errorMessage");
      errorCtrlr.text = errorMessage;
      return;
    }
    if (nameCtrlr.text == "" || descCtrlr.text == "") {
      screenMessage(context, 'Bitte alle Felder ausfüllen');
      return;
    }
    errorMessage = null;
    progName = nameCtrlr.text;
    progNames.add(progName);
    progs[progName] = codeCtrlr.text;
    descs[progName] = descCtrlr.text;
    String codeJS =
        json.encode({"code": codeCtrlr.text, "desc": descCtrlr.text});
    await strgClntNL.postMarkerCode(tableBase, progName, codeJS);
    File f = File(path.join(markerCodePath, progName + ".json"));
    f.writeAsString(codeJS, flush: true);

    baseConfigNL.setProgNames(progNames.sublist(3));
    LocationsDB.setProgram(statements);
    settingsNL.setConfigValue("progName", progName);

    Navigator.of(context).pushNamed(KartenScreen.routeName);
  }

  Future<void> loeschen() async {
    bool sure =
        await areYouSure(context, "Wollen Sie wirklich $progName löschen?");
    if (!sure) return;
    progNames.remove(progName);
    progs.remove(progName);
    descs.remove(progName);
    nameCtrlr.text = "";
    codeCtrlr.text = "";
    descCtrlr.text = "";
    await strgClntNL.deleteMarkerCode(tableBase, progName);
    File f = File(path.join(markerCodePath, progName + ".json"));
    f.delete();
  }

  @override
  Widget build(BuildContext context) {
    final baseConfig = Provider.of<BaseConfig>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(baseConfig.getName() + "/Marker-Code"),
      ),
      body: FutureBuilder(
          future: mcFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return SplashScreen();
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  "error ${snap.error}",
                  style: const TextStyle(
                    backgroundColor: Colors.white,
                    color: Colors.black,
                    fontSize: 20,
                  ),
                ),
              );
            }
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (progName != "Neu" &&
                        progName != "Standard" &&
                        progName != chooseProg)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                        onPressed: loeschen,
                        child: const Text(
                          'Löschen',
                        ),
                      ),
                    PopupMenuButton(
                      child: Container(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(
                            "Wählen",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        decoration: new BoxDecoration(
                            borderRadius:
                                BorderRadius.all(new Radius.circular(3.0)),
                            color: Colors.amber),
                      ),
                      itemBuilder: (_) {
                        return List.generate(
                          progNames.length,
                          (index) => progNames[index] == "_div_"
                              ? PopupMenuDivider(
                                  height: 10,
                                )
                              : PopupMenuItem(
                                  child: Text(progNames[index]),
                                  value: progNames[index],
                                ),
                        );
                      },
                      onSelected: (dynamic selectedValue) {
                        print("selected $selectedValue");
                        setProgram(selectedValue);
                      },
                    ),
                    if (progName == "Neu")
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                        onPressed: () {
                          speichern();
                        },
                        child: const Text(
                          'Speichern',
                        ),
                      ),
                    if (progName != "Neu" && progName != chooseProg)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                        onPressed: () {
                          copyProg = codeCtrlr.text;
                        },
                        child: const Text(
                          'Kopieren',
                        ),
                      ),
                    if (progName == "Neu" && copyProg != "")
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                        onPressed: () {
                          codeCtrlr.text = copyProg;
                        },
                        child: const Text(
                          'Einfügen',
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: TextField(
                    enabled: progName == "Neu",
                    controller: nameCtrlr,
                    decoration: InputDecoration(
                      labelText: "Marker-Code Name",
                      helperText: 'Bitte Namen wählen',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    enabled: progName == "Neu",
                    controller: codeCtrlr,
                    decoration: InputDecoration(
                      labelText: "Marker-Code",
                      helperText: progName == "Neu"
                          ? 'Bitte Marker-Code eingeben'
                          : "Marker-Code",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                      ),
                    ),
                    keyboardType: TextInputType.multiline,
                    minLines: 1, //Normal textInputField will be displayed
                    maxLines: 10, // when user presses enter it will adapt to it
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    enabled: progName == "Neu",
                    controller: descCtrlr,
                    decoration: InputDecoration(
                      labelText: "Marker-Code Beschreibung",
                      helperText: progName == "Neu"
                          ? 'Bitte Kurzbeschreibung eingeben'
                          : "Beschreibung",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                      ),
                    ),
                    keyboardType: TextInputType.multiline,
                    minLines: 1, //Normal textInputField will be displayed
                    maxLines: 10, // when user presses enter it will adapt to it
                  ),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: TextField(
                      controller: errorCtrlr,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: "Syntax Fehler",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        ),
                      ),
                      keyboardType: TextInputType.multiline,
                      minLines: 1, //Normal textInputField will be displayed
                      maxLines:
                          10, // when user presses enter it will adapt to it
                    ),
                  ),
              ],
            );
          }),
    );
  }
}
