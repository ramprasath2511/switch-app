import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:flutter/widgets.dart';

class UserProvider with ChangeNotifier {
  UserModel _user;

  UserModel get getUser => _user;

  getUserDetails(String phone) async {
    DocumentSnapshot documentSnapshot =
        await FirebaseFirestore.instance.collection(USERS).doc(phone).get();

    _user = UserModel.fromMap(documentSnapshot.data());
    notifyListeners();
  }
}

class UserModel {
  String uid;
  String name;
  String phone;
  String username;
  String status;
  int state;
  String profilePhoto;

  UserModel({
    this.uid,
    this.name,
    this.phone,
    this.username,
    this.status,
    this.state,
    this.profilePhoto,
  });

  Map toMap(UserModel user) {
    var data = Map<String, dynamic>();
    data['id'] = user.uid;
    data['nickname'] = user.name;
    data['phone'] = user.phone;
    // data["status"] = user.status;
    // data["state"] = user.state;
    data["photoUrl"] = user.profilePhoto;
    return data;
  }

  // Named constructor
  UserModel.fromMap(Map<String, dynamic> mapData) {
    this.uid = mapData['id'];
    this.name = mapData['nickname'];
    this.phone = mapData['phone'];
    // this.username = mapData['username'];
    // this.status = mapData['status'];
    // this.state = mapData['state'];
    this.profilePhoto = mapData['photoUrl'];
  }
}

// class AuthMethods {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   Future<User> getCurrentUser() async {
//     User currentUser;
//     currentUser = _auth.currentUser;
//     print('CURRENCT USER IS: ${currentUser.uid}');
//     return currentUser;
//   }

//   Future<UserModel> getUserDetails() async {
//     User currentUser = await getCurrentUser();

//     DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
//         .collection(USERS)
//         .doc(currentUser.uid)
//         .get();

//     return UserModel.fromMap(documentSnapshot.data());
//   }
// }
