import 'dart:async';
import 'dart:core';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:fiberchat/utils/widgets/PassCode/passcode_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Security extends StatefulWidget {
  final String phoneNo, answer, title;
  final bool setPasscode, shouldPop;

  final Function onSuccess;

  Security(this.phoneNo,
      {this.shouldPop = false,
      this.setPasscode = false,
      this.answer,
      this.title = "Authentication",
      @required this.onSuccess});

  @override
  _SecurityState createState() => _SecurityState();
}

class _SecurityState extends State<Security> {
  final StreamController<bool> _verificationNotifier =
      StreamController<bool>.broadcast();

  final TextEditingController _question = TextEditingController(),
      _answer = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  SharedPreferences prefs;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((_p) {
      prefs = _p;
    });
  }

  String _passCode;

  @override
  Widget build(BuildContext context) {
    return Fiberchat.getNTPWrappedWidget(WillPopScope(
        onWillPop: () {
          // if (!widget.shouldPop) return Future.value(widget.shouldPop);
          // else return widget.onSuccess();
          return Future.value(widget.shouldPop);
        },
        child: Stack(children: [
          Theme(
              child: Scaffold(
                  appBar: AppBar(
                    title: Text(widget.title),
                    elevation: 0.5,
                    backgroundColor: fiberchatDeepGreen,
                  ),
                  body: SingleChildScrollView(
                      child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          widget.setPasscode
                              ? ListTile(
                                  trailing: Icon(Icons.check_circle,
                                      color: _passCode == null
                                          ? fiberchatGrey
                                          : fiberchatLightGreen,
                                      size: 35),
                                  title: RaisedButton(
                                    color: fiberchatgreen,
                                    elevation: 0.5,
                                    child: const Text(
                                      'SET PASSCODE',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: _showLockScreen,
                                  ))
                              : null,
                          widget.setPasscode ? SizedBox(height: 20) : null,
                          ListTile(
                              subtitle: Text(
                                  'The following be used to reset your passcode in case you forget it. Frame a question only you can answer. Be creative and choose an answer that is hard to guess.')),
                          ListTile(
                            leading: Icon(Icons.lock),
                            title: TextFormField(
                              decoration: InputDecoration(
                                  labelText: 'Security Question'),
                              controller: _question,
                              autovalidateMode: AutovalidateMode.always,
                              validator: (v) {
                                return v.trim().isEmpty
                                    ? "Question cannot be empty!"
                                    : null;
                              },
                            ),
                          ),
                          ListTile(
                            leading: Icon(Icons.lock_open),
                            title: TextFormField(
                              autovalidateMode: AutovalidateMode.always,
                              decoration:
                                  InputDecoration(labelText: 'Security Answer'),
                              controller: _answer,
                              validator: (v) {
                                if (v.trim().isEmpty)
                                  return "Answer cannot be empty!";
                                if (Fiberchat.getHashedAnswer(v) ==
                                    widget.answer)
                                  return "Please provide a new answer!";
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 20),
                          ListTile(
                              trailing: RaisedButton(
                            color: fiberchatLightGreen,
                            elevation: 0.5,
                            child: Text(
                              'DONE',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () {
                              if (widget.setPasscode) {
                                if (_passCode == null)
                                  Fiberchat.toast(
                                      'Set the passcode before proceeding.');
                                if (_formKey.currentState.validate() &&
                                    _passCode != null) {
                                  var data = {
                                    QUESTION: _question.text,
                                    ANSWER:
                                        Fiberchat.getHashedAnswer(_answer.text),
                                    PASSCODE:
                                        Fiberchat.getHashedString(_passCode)
                                  };
                                  setState(() {
                                    isLoading = true;
                                  });
                                  prefs.setInt(PASSCODE_TRIES, 0);
                                  prefs.setInt(ANSWER_TRIES, 0);
                                  FirebaseFirestore.instance
                                      .collection(USERS)
                                      .doc(widget.phoneNo)
                                      .update(data)
                                      .then((_) {
                                    Fiberchat.toast('Welcome to SwitchApp!');
                                    widget.onSuccess();
                                  });
                                }
                                prefs.setBool(IS_SECURITY_SETUP_DONE, true);
                              } else {
                                if (_formKey.currentState.validate()) {
                                  var data = {
                                    QUESTION: _question.text,
                                    ANSWER:
                                        Fiberchat.getHashedAnswer(_answer.text),
                                  };
                                  setState(() {
                                    isLoading = true;
                                  });
                                  prefs.setInt(PASSCODE_TRIES, 0);
                                  prefs.setInt(ANSWER_TRIES, 0);
                                  FirebaseFirestore.instance
                                      .collection(USERS)
                                      .doc(widget.phoneNo)
                                      .update(data)
                                      .then((_) {
                                    Fiberchat.toast('Done!');
                                    widget.onSuccess();
                                  });
                                }
                                prefs.setBool(IS_SECURITY_SETUP_DONE, true);
                              }
                            },
                          )),
                        ].where((o) => o != null).toList(),
                      ),
                    ),
                  ))),
              data: FiberchatTheme),
          Positioned(
            child: isLoading
                ? Container(
                    child: Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(fiberchatBlue)),
                    ),
                    color: fiberchatBlack.withOpacity(0.8),
                  )
                : Container(),
          )
        ])));
  }

  _onPasscodeEntered(String enteredPasscode) {
    bool isValid = enteredPasscode.length == 4;
    _verificationNotifier.add(isValid);
    _passCode = null;
    if (isValid)
      setState(() {
        _passCode = enteredPasscode;
      });
  }

  _showLockScreen() {
    Navigator.push(
        context,
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (context, animation, secondaryAnimation) =>
              PasscodeScreen(
            onSubmit: null,
            wait: true,
            authentication: false,
            passwordDigits: 4,
            title: 'Enter the passcode',
            passwordEnteredCallback: _onPasscodeEntered,
            cancelLocalizedText: 'Cancel',
            deleteLocalizedText: 'Delete',
            shouldTriggerVerification: _verificationNotifier.stream,
          ),
        ));
  }
}
