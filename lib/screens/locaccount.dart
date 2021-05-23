import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:locations/providers/locations_client.dart';
import 'package:locations/providers/settings.dart';
import 'package:locations/widgets/app_config.dart';
import 'package:locations/widgets/auth_form.dart';
import 'package:provider/provider.dart';

class LocAuth {
  static LocAuth _instance;
  StreamController _controller;
  LocationsClient _locClnt;
  SecretKey sharedSecret;
  AesCbc cryptAlg;
  String id;

  static LocAuth get instance {
    if (_instance == null) _instance = LocAuth();
    return _instance;
  }

  Future<UserCredential> postAuth(String loginOrSignon,
      {String email, String password, String username}) async {
    // https://cryptography.io/en/latest/hazmat/primitives/asymmetric/x25519/
    final algorithm = X25519();
    // my key pair
    final myKeyPair = await algorithm.newKeyPair();
    try {
      await myKeyPair.extractPublicKey();
    } catch (ex) {
      print(ex);
    }
    final myPubKey = await myKeyPair.extractPublicKey();
    final myB64 = base64.encode(myPubKey.bytes);
    id = DateTime.now().millisecondsSinceEpoch.toString();
    Map res = await _locClnt.kex(id, myB64);
    final hisPublicKey =
        SimplePublicKey(base64.decode(res["pubkey"]), type: KeyPairType.x25519);

    // calculate the shared secret.
    sharedSecret = await algorithm.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: hisPublicKey,
    );
    Map cred = {
      "id": id,
      "email": email,
      "password": password,
      "username": username
    };
    String credJS = json.encode(cred);
    final credB = utf8.encode(credJS);
    cryptAlg = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final credEnc = await cryptAlg.encrypt(credB, secretKey: sharedSecret);
    final ctxt = credEnc.cipherText;
    final iv = credEnc.nonce;
    final credMsg = {
      "id": id,
      "ctxt": base64.encode(ctxt),
      "iv": base64.encode(iv)
    };
    final credMsgJS = json.encode(credMsg);
    final map = await _locClnt.postAuth(loginOrSignon, credMsgJS);
    print("map $map");
    final uc = UserCredential(map["id"], map["username"]);
    _controller.add(uc);
    return uc;
  }

  Stream authStateChanges(LocationsClient locClnt) {
    _locClnt = locClnt;
    if (_controller == null) {
      _controller = StreamController(onListen: () {
        if (loggedIn()) {
          _controller.add("OK");
        } else {
          _controller.addError("??");
        }
      });
    }
    return _controller.stream;
  }

  bool loggedIn() {
    return false;
  }

  signOut() {
    if (_controller == null) return;
    print("Signed out");
    _controller.addError("error");
  }
}

class UserCredential {
  final String _id;
  final String _username;
  UserCredential(this._id, this._username);
  String get username {
    return _username;
  }

  String get id {
    return _id;
  }
}

class LocAccountScreen extends StatefulWidget {
  static String routeName = "/locaccount";
  @override
  _LocAccountScreenState createState() => _LocAccountScreenState();
}

class _LocAccountScreenState extends State<LocAccountScreen> {
  final auth = LocAuth.instance;
  bool isLoading = false;
  Settings settingsNL;

  Future<void> submitAuthForm(
    String email,
    String password,
    String username,
    bool isLogin,
    BuildContext ctx,
  ) async {
    UserCredential authResult;
    try {
      setState(() {
        isLoading = true;
      });
      if (isLogin) {
        authResult = await auth.postAuth(
          "login",
          email: email,
          password: password,
        );
        String username = authResult.username;
        settingsNL.setConfigValue("username", username);
      } else {
        authResult = await auth.postAuth("signon",
            email: email, password: password, username: username);
        settingsNL.setConfigValue("username", username);
      }
    } catch (err) {
      var message = "An error occurred, please check your credentials!";
      try {
        message = err.message;
      } catch (_) {}
      print("ex $err $message");
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(ctx).errorColor,
        ),
      );
    } finally {
      if (this.mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    settingsNL = Provider.of<Settings>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text("Login/SignOn"),
      ),
      drawer: AppConfig(),
      backgroundColor: Theme.of(context).primaryColor,
      body: AuthForm(
        submitAuthForm,
        isLoading,
      ),
    );
  }
}
