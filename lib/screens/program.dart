import 'package:flutter/material.dart';
import 'package:locations/parser/parser.dart';
import 'package:locations/providers/base_config.dart';
import 'package:provider/provider.dart';

class ProgramSelector extends StatefulWidget {
  static String routeName = "/photo";

  @override
  _ProgramSelectorState createState() => _ProgramSelectorState();
}

class _ProgramSelectorState extends State<ProgramSelector> {
  BaseConfig baseConfigNL;
  List<Statement> statements;
  List keys = ["Standard", "Neu", "_div_", "red", "yellow", "green"];
  Map<String, String> progs = {};
  Map<String, String> descs = {};

  final String chooseProg = "Programm wählen";
  String progName;
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
    progName = chooseProg;
    progs["red"] = "return 0";
    progs["yellow"] = "return 1";
    progs["green"] = "return 2";
    descs["red"] = "red";
    descs["yellow"] = "yellow";
    descs["green"] = "green";
  }

  Future<void> setProgram(String name) async {
    if (name == "Standard") {
      nameCtrlr.text = "Standard";
      codeCtrlr.text = baseConfigNL.getProgram();
      descCtrlr.text = "Standard-Code, definiert in der config-Datei";
      statements = parseProgram(codeCtrlr.text);
      copyProg = "";
    } else if (name == "Neu") {
      nameCtrlr.text = "";
      codeCtrlr.text = "";
      descCtrlr.text = "";
    } else {
      nameCtrlr.text = name;
      codeCtrlr.text = progs[name];
      descCtrlr.text = descs[name];
      statements = parseProgram(codeCtrlr.text);
      copyProg = "";
    }
    errorMessage = null;
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
      message('Bitte alle Felder ausfüllen');
      return;
    }
    errorMessage = null;
    progName = nameCtrlr.text;
    keys.add(progName);
    progs[progName] = codeCtrlr.text;
    descs[progName] = descCtrlr.text;
    setState(() {});
  }

  Future<void> loeschen() async {
    keys.remove(progName);
    progs.remove(progName);
    descs.remove(progName);
    nameCtrlr.text = "";
    codeCtrlr.text = "";
    descCtrlr.text = "";
  }

  Future<void> message(String msg) {
    return showDialog(
      context: context,
      builder: (context) => new AlertDialog(
        title: const Text('Fehler'),
        content: Text(msg),
        actions: <Widget>[
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseConfig = Provider.of<BaseConfig>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(baseConfig.getName() + "/Programme"),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Padding(
              //   padding: const EdgeInsets.all(10),
              //   child: Text("Programm: ",
              //       style: TextStyle(backgroundColor: Colors.amber)),
              // ),
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
                      borderRadius: BorderRadius.all(new Radius.circular(3.0)),
                      color: Colors.amber),
                ),
                itemBuilder: (_) {
                  return List.generate(
                    keys.length,
                    (index) => keys[index] == "_div_"
                        ? PopupMenuDivider(
                            height: 10,
                          )
                        : PopupMenuItem(
                            child: Text(keys[index]),
                            value: keys[index] as String,
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
                labelText: "Programmname",
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
                labelText: "Programm Code",
                helperText: progName == "Neu"
                    ? 'Bitte Programm eingeben'
                    : "Programmtext",
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
                labelText: "Programm Beschreibung",
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
                maxLines: 10, // when user presses enter it will adapt to it
              ),
            ),
        ],
      ),
    );
  }
}
