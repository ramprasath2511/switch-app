import 'dart:core';
import 'dart:async';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/core/auth/screens/authentication.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatController {
  static request(currentUserNo, peerNo, chatid) async {
    FirebaseFirestore.instance
        .collection(USERS)
        .doc(currentUserNo)
        .collection(CHATS_WITH)
        .doc(CHATS_WITH)
        .set({'$peerNo': ChatStatus.waiting.index}, SetOptions(merge: true));
    FirebaseFirestore.instance
        .collection(USERS)
        .doc(peerNo)
        .collection(CHATS_WITH)
        .doc(CHATS_WITH)
        .set({'$currentUserNo': ChatStatus.requested.index},
            SetOptions(merge: true));
    var doc =
        await FirebaseFirestore.instance.collection(USERS).doc('$peerNo').get();
    FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatid)
        .set({'$peerNo': doc[LAST_SEEN]}, SetOptions(merge: true));
  }

  static accept(currentUserNo, peerNo) {
    FirebaseFirestore.instance
        .collection(USERS)
        .doc(currentUserNo)
        .collection(CHATS_WITH)
        .doc(CHATS_WITH)
        .set({'$peerNo': ChatStatus.accepted.index}, SetOptions(merge: true));
  }

  static block(currentUserNo, peerNo) {
    FirebaseFirestore.instance
        .collection(USERS)
        .doc(currentUserNo)
        .collection(CHATS_WITH)
        .doc(CHATS_WITH)
        .set({'$peerNo': ChatStatus.blocked.index}, SetOptions(merge: true));
    FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(Fiberchat.getChatId(currentUserNo, peerNo))
        .set({'$currentUserNo': DateTime.now().millisecondsSinceEpoch},
            SetOptions(merge: true));
    Fiberchat.toast('Blocked.');
  }

  static Future<ChatStatus> getStatus(currentUserNo, peerNo) async {
    var doc = await FirebaseFirestore.instance
        .collection(USERS)
        .doc(currentUserNo)
        .collection(CHATS_WITH)
        .doc(CHATS_WITH)
        .get();
    return ChatStatus.values[doc[peerNo]];
  }

  static hideChat(currentUserNo, peerNo) {
    FirebaseFirestore.instance.collection(USERS).doc(currentUserNo).set({
      HIDDEN: FieldValue.arrayUnion([peerNo])
    }, SetOptions(merge: true));
    Fiberchat.toast('Chat hidden.');
  }

  static unhideChat(currentUserNo, peerNo) {
    FirebaseFirestore.instance.collection(USERS).doc(currentUserNo).set({
      HIDDEN: FieldValue.arrayRemove([peerNo])
    }, SetOptions(merge: true));
    Fiberchat.toast('Chat is visible.');
  }

  static lockChat(currentUserNo, peerNo) {
    FirebaseFirestore.instance.collection(USERS).doc(currentUserNo).set({
      LOCKED: FieldValue.arrayUnion([peerNo])
    }, SetOptions(merge: true));
    Fiberchat.toast('Chat locked.');
  }

  static unlockChat(currentUserNo, peerNo) {
    FirebaseFirestore.instance.collection(USERS).doc(currentUserNo).set({
      LOCKED: FieldValue.arrayRemove([peerNo])
    }, SetOptions(merge: true));
    Fiberchat.toast('Chat unlocked.');
  }

  static void authenticate(DataModel model, String caption,
      {@required NavigatorState state,
      AuthenticationType type = AuthenticationType.passcode,
      @required SharedPreferences prefs,
      @required Function onSuccess,
      @required bool shouldPop}) {
    Map<String, dynamic> user = model.currentUser;
    if (user != null && model != null) {
      state.push(MaterialPageRoute<bool>(
          builder: (context) => Authenticate(
              shouldPop: shouldPop,
              caption: caption,
              type: type,
              model: model,
              state: state,
              answer: user[ANSWER],
              passcode: user[PASSCODE],
              question: user[QUESTION],
              phoneNo: user[PHONE],
              prefs: prefs,
              onSuccess: onSuccess)));
    }
  }
}
