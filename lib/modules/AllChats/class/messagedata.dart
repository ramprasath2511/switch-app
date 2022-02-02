import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MessageData {
  int lastSeen;
  QuerySnapshot snapshot;
  MessageData({@required this.snapshot, @required this.lastSeen});
}
