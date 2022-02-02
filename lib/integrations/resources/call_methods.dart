import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/integrations/models/call.dart';
import 'package:flutter/material.dart';

class CallMethods {
  Stream<DocumentSnapshot> callStream({String phone}) =>
      callCollection.doc(phone).snapshots();

  Future<bool> makeCall(
      {Call call, @required bool isvideocall, @required int timeepoch}) async {
    try {
      call.hasDialled = true;
      Map<String, dynamic> hasDialledMap = call.toMap(call);

      call.hasDialled = false;
      Map<String, dynamic> hasNotDialledMap = call.toMap(call);

      await callCollection.doc(call.callerId).set(hasDialledMap);

      await callCollection.doc(call.receiverId).set(hasNotDialledMap);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> endCall({Call call}) async {
    try {
      await callCollection.doc(call.callerId).delete();
      await callCollection.doc(call.receiverId).delete();
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
