import 'dart:io';

// import 'package:admob_flutter/admob_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/Admob/admob.dart';
import 'package:fiberchat/modules/callhistory/widgets/InfiniteListView.dart';
import 'package:fiberchat/integrations/provider/call_history_provider.dart';
import 'package:fiberchat/integrations/utils/call_utilities.dart';
import 'package:fiberchat/integrations/utils/permissions.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallHistory extends StatefulWidget {
  final String userphone;
  CallHistory({@required this.userphone});
  @override
  _CallHistoryState createState() => _CallHistoryState();
}

class _CallHistoryState extends State<CallHistory> {
  SharedPreferences prefs;
  call(BuildContext context, bool isvideocall, var peer) async {
    prefs = await SharedPreferences.getInstance();
    var mynickname = prefs.getString(NICKNAME) ?? '';

    var myphotoUrl = prefs.getString(PHOTO_URL) ?? '';

    CallUtils.dial(
        currentuseruid: widget.userphone,
        fromDp: myphotoUrl,
        toDp: peer["photoUrl"],
        fromUID: widget.userphone,
        fromFullname: mynickname,
        toUID: peer['phone'],
        toFullname: peer["nickname"],
        context: context,
        isvideocall: isvideocall);
  }
//TODO ADMOB CODE
  // AdmobInterstitial interstitialAd;
  GlobalKey<ScaffoldState> _scaffold = new GlobalKey<ScaffoldState>();
  @override
  void initState() {
    super.initState();
    //TODO ADMOB CODE
    // if (IsInterstitialAdShow == true) {
    //   interstitialAd = AdmobInterstitial(
    //     adUnitId: getInterstitialAdUnitId(),
    //     listener: (AdmobAdEvent event, Map<String, dynamic> args) {
    //       if (event == AdmobAdEvent.closed) interstitialAd.load();
    //       // handleEvent(event, args, 'Interstitial');
    //     },
    //   );
    //   interstitialAd.load();
    //   Future.delayed(const Duration(milliseconds: 2000), () {
    //     interstitialAd.show();
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirestoreDataProviderCALLHISTORY>(
      builder: (context, firestoreDataProvider, _) => Scaffold(
        //TODO ADMOB CODE
        // bottomSheet: IsBannerAdShow == true
        //     ? Container(
        //         height: 60,
        //         margin: EdgeInsets.only(
        //             bottom: Platform.isIOS == true ? 25.0 : 5, top: 0),
        //         child: Center(
        //           child: AdmobBanner(
        //             adUnitId: getBannerAdUnitId(),
        //             adSize: AdmobBannerSize.BANNER,
        //             listener: (AdmobAdEvent event, Map<String, dynamic> args) {
        //               // handleEvent(event, args, 'Banner');
        //             },
        //             onBannerCreated: (AdmobBannerController controller) {
        //               // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
        //               // Normally you don't need to worry about disposing this yourself, it's handled.
        //               // If you need direct access to dispose, this is your guy!
        //               // controller.dispose();
        //             },
        //           ),
        //         ),
        //       )
        //     : SizedBox(
        //         height: 0,
        //       ),
        key: _scaffold,
        floatingActionButton: firestoreDataProvider.recievedDocs.length == 0
            ? SizedBox()
            : Padding(
                padding: const EdgeInsets.only(
                    bottom: IsBannerAdShow == true ? 60 : 0),
                child: FloatingActionButton(
                    backgroundColor: fiberchatWhite,
                    child: Icon(
                      Icons.delete,
                      size: 30.0,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: new Text("Clear Call log"),
                              content: new Text(
                                  "Do you want to delete all call logs?"),
                              actions: [
                                FlatButton(
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                        color: fiberchatgreen, fontSize: 18),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                FlatButton(
                                  child: Text(
                                    "Delete",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 18),
                                  ),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    Fiberchat.toast(
                                        'Deleting Logs... Please Wait !');
                                    FirebaseFirestore.instance
                                        .collection(USERS)
                                        .doc(widget.userphone)
                                        .collection(CALL_HISTORY_COLLECTION)
                                        .get()
                                        .then((snapshot) {
                                      for (DocumentSnapshot doc
                                          in snapshot.docs) {
                                        doc.reference.delete();
                                      }
                                    }).then((value) {
                                      firestoreDataProvider.clearall();
                                      Fiberchat.toast('All Logs Deleted!');
                                    });
                                  },
                                )
                              ],
                            );
                          });
                    }),
              ),
        body: InfiniteListView(
          firestoreDataProviderCALLHISTORY: firestoreDataProvider,
          datatype: 'CALLHISTORY',
          refdata: FirebaseFirestore.instance
              .collection(USERS)
              .doc(widget.userphone)
              .collection(CALL_HISTORY_COLLECTION)
              .orderBy('TIME', descending: true)
              .limit(14),
          list: ListView.builder(
              padding: EdgeInsets.only(bottom: 150),
              physics: ScrollPhysics(),
              shrinkWrap: true,
              itemCount: firestoreDataProvider.recievedDocs.length,
              itemBuilder: (BuildContext context, int i) {
                var dc = firestoreDataProvider.recievedDocs[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      // padding: EdgeInsets.fromLTRB(0, 0, 0, 5),
                      margin: EdgeInsets.fromLTRB(0, 0, 0, 17),
                      height: 40,
                      child: FutureBuilder(
                          future: FirebaseFirestore.instance
                              .collection(USERS)
                              .doc(dc['PEER'])
                              .get(),
                          builder: (BuildContext context, snapshot) {
                            if (snapshot.hasData) {
                              var user = snapshot.data.data();
                              return SizedBox(
                                height: 40,
                                child: ListTile(
                                  isThreeLine: false,
                                  leading: Stack(
                                    children: [
                                      customCircleAvatar(url: user['photoUrl']),
                                      dc['STARTED'] == null ||
                                              dc['ENDED'] == null
                                          ? SizedBox(
                                              height: 0,
                                              width: 0,
                                            )
                                          : Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: EdgeInsets.fromLTRB(
                                                    6, 2, 6, 2),
                                                decoration: BoxDecoration(
                                                    color: fiberchatLightGreen,
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                20))),
                                                child: Text(
                                                  dc['ENDED']
                                                              .toDate()
                                                              .difference(
                                                                  dc['STARTED']
                                                                      .toDate())
                                                              .inMinutes <
                                                          1
                                                      ? dc['ENDED']
                                                              .toDate()
                                                              .difference(
                                                                  dc['STARTED']
                                                                      .toDate())
                                                              .inSeconds
                                                              .toString() +
                                                          's'
                                                      : dc['ENDED']
                                                              .toDate()
                                                              .difference(
                                                                  dc['STARTED']
                                                                      .toDate())
                                                              .inMinutes
                                                              .toString() +
                                                          'm',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10),
                                                ),
                                              ))
                                    ],
                                  ),
                                  title: Text(
                                    user['nickname'],
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        height: 1.4,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          dc['TYPE'] == 'INCOMING'
                                              ? (dc['STARTED'] == null
                                                  ? Icons.call_missed
                                                  : Icons.call_received)
                                              : (dc['STARTED'] == null
                                                  ? Icons.call_made_rounded
                                                  : Icons.call_made_rounded),
                                          size: 15,
                                          color: dc['TYPE'] == 'INCOMING'
                                              ? (dc['STARTED'] == null
                                                  ? Colors.redAccent
                                                  : fiberchatLightGreen)
                                              : (dc['STARTED'] == null
                                                  ? Colors.redAccent
                                                  : fiberchatLightGreen),
                                        ),
                                        SizedBox(
                                          width: 7,
                                        ),
                                        Text(Jiffy(DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        dc["TIME"]))
                                                .MMMMd
                                                .toString() +
                                            ', ' +
                                            Jiffy(DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        dc["TIME"]))
                                                .Hm
                                                .toString()),
                                        // Text(time)
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                      icon: Icon(
                                          dc['ISVIDEOCALL'] == true
                                              ? Icons.video_call
                                              : Icons.call,
                                          color: fiberchatgreen,
                                          size: 24),
                                      onPressed: () async {
                                        if (dc['ISVIDEOCALL'] == true) {
                                          //---Make a video call
                                          await Permissions
                                                  .cameraAndMicrophonePermissionsGranted()
                                              .then((isgranted) {
                                            if (isgranted == true) {
                                              call(context, true, user);
                                            } else {
                                              Fiberchat.showRationale(
                                                  'Permission to access Microphone & camera is required to Start.');
                                              Navigator.push(
                                                  context,
                                                  new MaterialPageRoute(
                                                      builder: (context) =>
                                                          OpenSettings()));
                                            }
                                          }).catchError((onError) {
                                            Fiberchat.showRationale(
                                                'Permission to access Microphone & camera is required to Start.');
                                            Navigator.push(
                                                context,
                                                new MaterialPageRoute(
                                                    builder: (context) =>
                                                        OpenSettings()));
                                          });
                                        } else if (dc['ISVIDEOCALL'] == false) {
                                          //---Make a audio call
                                          await Permissions
                                                  .cameraAndMicrophonePermissionsGranted()
                                              .then((isgranted) {
                                            if (isgranted == true) {
                                              call(context, false, user);
                                            } else {
                                              Fiberchat.showRationale(
                                                  'Permission to access Microphone & camera is required to Start.');
                                              Navigator.push(
                                                  context,
                                                  new MaterialPageRoute(
                                                      builder: (context) =>
                                                          OpenSettings()));
                                            }
                                          }).catchError((onError) {
                                            Fiberchat.showRationale(
                                                'Permission to access Microphone & camera is required to Start.');
                                            Navigator.push(
                                                context,
                                                new MaterialPageRoute(
                                                    builder: (context) =>
                                                        OpenSettings()));
                                          });
                                        }
                                      }),
                                ),
                              );
                            } else if (!snapshot.hasData) {
                              return Container();
                            } else {
                              return Container();
                            }
                          }),
                    ),
                    Divider(),
                  ],
                );
              }),
        ),
      ),
    );
  }
}

//  'TYPE': 'OUTGOING',
//         'ISVIDEOCALL': widget.call.isvideocall,
//         'PEER': widget.call.receiverId,
//         'TIME': widget.call.timeepoch,
//         'DP': widget.call.receiverPic,
//         'ISMUTED': false,
//         'TARGET': widget.call.receiverId,
//         'ISJOINEDEVER': true,
//         'STATUS': 'calling',
//         'STARTED': null,
//         'ENDED': null,

Widget customCircleAvatar({String url, double radius}) {
  if (url == null || url == '') {
    return CircleAvatar(
      backgroundColor: Color(0xffE6E6E6),
      radius: radius ?? 30,
      child: Icon(
        Icons.person,
        color: Color(0xffCCCCCC),
      ),
    );
  } else {
    return CircleAvatar(
      backgroundColor: Color(0xffE6E6E6),
      radius: radius ?? 30,
      backgroundImage: NetworkImage('$url'),
    );
  }
}
