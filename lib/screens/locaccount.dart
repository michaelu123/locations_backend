import 'dart:async';

import 'package:flutter/material.dart';
import 'package:locations/providers/settings.dart';
import 'package:locations/widgets/app_config.dart';
import 'package:locations/widgets/auth_form.dart';
import 'package:provider/provider.dart';

class LocAuth {
  static LocAuth _instance;
  static StreamController _controller;

  static LocAuth get instance {
    if (_instance == null) _instance = LocAuth();
    return _instance;
  }

  Future<UserCredential> signInWithEmailAndPassword(
      {String email, String password}) async {
    return null;
  }

  Future<UserCredential> createUserWithEmailAndPassword(
      {String email, String password, String username}) async {
    return null;
  }

  Stream authStateChanges() {
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
    return true;
  }
}

class UserCredential {
  String username;
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
        authResult = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        String username = authResult.username;
        settingsNL.setConfigValue("username", username);
      } else {
        try {
          authResult = await auth.createUserWithEmailAndPassword(
              email: email, password: password, username: username);
        } catch (err) {
          if (err.message == null || !err.message.contains("already in use")) {
            throw (err);
          }
          authResult = await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        settingsNL.setConfigValue("username", username);
      }
    } catch (err) {
      var message = "An error occurred, please check your credentials!";
      try {
        message = err.message;
      } catch (_) {}
      print("plaex $err $message");
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
