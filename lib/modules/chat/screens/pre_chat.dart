import 'dart:core';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/chat/screens/chat.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreChat extends StatefulWidget {
  final String name, phone, currentUserNo;
  final DataModel model;
  const PreChat(
      {@required this.name,
      @required this.phone,
      @required this.currentUserNo,
      @required this.model});

  @override
  _PreChatState createState() => _PreChatState();
}

class _PreChatState extends State<PreChat> {
  bool isLoading, isUser = false;

  @override
  initState() {
    super.initState();
    getUser();
    isLoading = true;
  }

  getUser() {
    FirebaseFirestore.instance
        .collection(USERS)
        .doc(widget.phone)
        .get()
        .then((user) {
      setState(() {
        isLoading = false;
        isUser = user.exists;
        if (isUser) {
          var peer = user;
          widget.model.addUser(user);
          Navigator.pushReplacement(
              context,
              new MaterialPageRoute(
                  builder: (context) => new ChatScreen(
                      unread: 0,
                      currentUserNo: widget.currentUserNo,
                      model: widget.model,
                      peerNo: peer[PHONE])));
        }
      });
    });
  }

  Widget buildLoading() {
    return Positioned(
      child: isLoading
          ? Container(
              child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(fiberchatBlue)),
              ),
              color: fiberchatBlack.withOpacity(0.8),
            )
          : Container(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Fiberchat.getNTPWrappedWidget(Scaffold(
      appBar:
          AppBar(backgroundColor: fiberchatDeepGreen, title: Text(widget.name)),
      body: Stack(children: <Widget>[
        Container(
            child: Center(
          child: !isUser
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Text(widget.name + " is not in SwitchApp!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: fiberchatBlack,
                            fontWeight: FontWeight.w500,
                            fontSize: 20.0)),
                  ),
                  SizedBox(
                    height: 20.0,
                  ),
                  RaisedButton(
                    elevation: 0.5,
                    color: fiberchatBlue,
                    textColor: fiberchatWhite,
                    child: Text(
                      'Invite ${widget.name}',
                      style: TextStyle(color: fiberchatWhite),
                    ),
                    onPressed: () {
                      Fiberchat.invite();
                    },
                  )
                ])
              : Container(),
        )),
        // Loading
        buildLoading()
      ]),
      backgroundColor: fiberchatWhite,
    ));
  }
}
