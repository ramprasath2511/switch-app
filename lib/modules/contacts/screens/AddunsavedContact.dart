import 'dart:core';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/core/auth/screens/login.dart';
import 'package:fiberchat/modules/chat/screens/chat.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddunsavedNumber extends StatefulWidget {
  final String currentUserNo;
  final DataModel model;
  const AddunsavedNumber({@required this.currentUserNo, @required this.model});

  @override
  _AddunsavedNumberState createState() => _AddunsavedNumberState();
}

class _AddunsavedNumberState extends State<AddunsavedNumber> {
  bool isLoading, isUser = true;
  bool istyping = true;
  @override
  initState() {
    super.initState();
    // getUser();
    // isLoading = true;
  }

  getUser() {
    FirebaseFirestore.instance
        .collection(USERS)
        .doc(phoneCode + _phoneNo.text.trim())
        .get()
        .then((user) {
      setState(() {
        isLoading = false;
        istyping = false;
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

  final _phoneNo = TextEditingController();

  String phoneCode = DEFAULT_COUNTTRYCODE_NUMBER;
  Widget buildLoading() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(17, 52, 17, 8),
          child: Container(
            margin: EdgeInsets.only(top: 0),

            // padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
            // height: 63,
            height: 63,
            // width: w / 1.18,
            child: Form(
              // key: _enterNumberFormKey,
              child: MobileInputWithOutline(
                buttonhintTextColor: fiberchatGrey,
                borderColor: fiberchatGrey.withOpacity(0.2),
                controller: _phoneNo,
                initialCountryCode: DEFAULT_COUNTTRYCODE_ISO,
                onSaved: (phone) {
                  setState(() {
                    phoneCode = phone.countryCode;
                    istyping = true;
                  });
                  print(phoneCode);
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(13, 22, 13, 8),
          child: isLoading == true
              ? Center(
                  child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(fiberchatLightGreen)),
                )
              : MySimpleButton(
                  buttoncolor: fiberchatLightGreen.withOpacity(0.99),
                  buttontext: 'SEARCH USER',
                  onpressed: () {
                    RegExp e164 = new RegExp(r'^\+[1-9]\d{1,14}$');

                    String _phone = _phoneNo.text.toString().trim();
                    if ((_phone.isNotEmpty &&
                            e164.hasMatch(phoneCode + _phone)) &&
                        widget.currentUserNo != phoneCode + _phone) {
                      setState(() {
                        isLoading = true;
                      });
                      print(widget.currentUserNo);
                      print(phoneCode + _phone);
                      getUser();
                    } else {
                      Fiberchat.toast(widget.currentUserNo != phoneCode + _phone
                          ? 'Please enter a valid number.'
                          : 'Sorry! this is yours number.');
                    }
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Fiberchat.getNTPWrappedWidget(Scaffold(
      appBar: AppBar(
          backgroundColor: fiberchatDeepGreen,
          title: Text(
            'Chat without Saving Number',
            style: TextStyle(fontSize: 15),
          )),
      body: Stack(children: <Widget>[
        Container(
            child: Center(
          child: !isUser
              ? istyping == true
                  ? SizedBox()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          SizedBox(
                            height: 140,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Text(
                                phoneCode +
                                    _phoneNo.text.trim() +
                                    "  SwitchApp!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: fiberchatBlack,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20.0)),
                          ),
                          SizedBox(
                            height: 10.0,
                          ),
                          RaisedButton(
                            elevation: 0.5,
                            color: fiberchatBlue,
                            textColor: fiberchatWhite,
                            child: Text(
                              'Invite User',
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
