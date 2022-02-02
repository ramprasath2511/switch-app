import 'dart:async';
import 'dart:core';
// import 'package:admob_flutter/admob_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/Admob/admob.dart';
import 'package:fiberchat/modules/AllChats/class/messagedata.dart';
import 'package:fiberchat/modules/callhistory/screens/callhistory.dart';
import 'package:fiberchat/modules/chat/screens/chat.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/integrations/provider/user_provider.dart';
import 'package:fiberchat/utils/services/alias.dart';
import 'package:fiberchat/utils/services/chat_controller.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scoped_model/scoped_model.dart';

class SearchChats extends StatefulWidget {
  SearchChats(
      {@required this.currentUserNo,
      @required this.isSecuritySetupDone,
      @required this.prefs,
      key})
      : super(key: key);
  final String currentUserNo;
  final SharedPreferences prefs;
  final bool isSecuritySetupDone;
  @override
  State createState() =>
      new SearchChatsState(currentUserNo: this.currentUserNo);
}

class SearchChatsState extends State<SearchChats> {
  SearchChatsState({Key key, this.currentUserNo}) {
    _filter.addListener(() {
      _userQuery.add(_filter.text.isEmpty ? '' : _filter.text);
    });
  }
  GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
  final TextEditingController _filter = new TextEditingController();
  bool isAuthenticating = false;

  List<StreamSubscription> unreadSubscriptions = List<StreamSubscription>();

  List<StreamController> controllers = new List<StreamController>();
  //TODO ADMOB CODE
  // AdmobBannerSize bannerSize;
  // AdmobInterstitial interstitialAd;
  // AdmobReward rewardAd;
  @override
  void initState() {
    super.initState();

    Fiberchat.internetLookUp();
//TODO ADMOB CODE
    // if (IsBannerAdShow == true) {
    //   bannerSize = AdmobBannerSize.BANNER;

    //   rewardAd = AdmobReward(
    //     adUnitId: getRewardBasedVideoAdUnitId(),
    //     listener: (AdmobAdEvent event, Map<String, dynamic> args) {
    //       if (event == AdmobAdEvent.closed) rewardAd.load();
    //       // handleEvent(event, args, 'Reward');
    //     },
    //   );

    //   // interstitialAd.load();
    //   rewardAd.load();
    // }
  }

  //   void handleEvent(
  //     AdmobAdEvent event, Map<String, dynamic> args, String adType) {
  //   switch (event) {
  //     case AdmobAdEvent.loaded:
  //       showSnackBar('New Admob $adType Ad loaded!');
  //       break;
  //     case AdmobAdEvent.opened:
  //       showSnackBar('Admob $adType Ad opened!');
  //       break;
  //     case AdmobAdEvent.closed:
  //       showSnackBar('Admob $adType Ad closed!');
  //       break;
  //     case AdmobAdEvent.failedToLoad:
  //       showSnackBar('Admob $adType failed to load. :(');
  //       break;
  //     case AdmobAdEvent.rewarded:
  //       showDialog(
  //         context: scaffoldState.currentContext,
  //         builder: (BuildContext context) {
  //           return WillPopScope(
  //             child: AlertDialog(
  //               content: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: <Widget>[
  //                   Text('Reward callback fired. Thanks Andrew!'),
  //                   Text('Type: ${args['type']}'),
  //                   Text('Amount: ${args['amount']}'),
  //                 ],
  //               ),
  //             ),
  //             onWillPop: () async {
  //               scaffoldState.currentState.hideCurrentSnackBar();
  //               return true;
  //             },
  //           );
  //         },
  //       );
  //       break;
  //     default:
  //   }
  // }

  void showSnackBar(String content) {
    scaffoldState.currentState.showSnackBar(
      SnackBar(
        content: Text(content),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  getuid(BuildContext context) {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    userProvider.getUserDetails(currentUserNo);
  }

  void cancelUnreadSubscriptions() {
    unreadSubscriptions.forEach((subscription) {
      subscription?.cancel();
    });
  }

  DataModel _cachedModel;
  bool showHidden = false, biometricEnabled = false;

  String currentUserNo;

  bool isLoading = false;

  Widget buildItem(BuildContext context, Map<String, dynamic> user) {
    if (user[PHONE] as String == currentUserNo) {
      return Container(width: 0, height: 0);
    } else {
      return StreamBuilder(
        stream: getUnread(user).asBroadcastStream(),
        builder: (context, AsyncSnapshot<MessageData> unreadData) {
          int unread =
              unreadData.hasData && unreadData.data.snapshot.docs.isNotEmpty
                  ? unreadData.data.snapshot.docs
                      .where((t) => t[TIMESTAMP] > unreadData.data.lastSeen)
                      .length
                  : 0;
          return Theme(
              data: ThemeData(
                  splashColor: fiberchatBlue,
                  highlightColor: Colors.transparent),
              child: Column(
                children: [
                  ListTile(
                      onLongPress: () {
                        // ChatController.authenticate(_cachedModel,
                        //     'Authentication needed to unlock the chat.',
                        //     state: state,
                        //     shouldPop: true,
                        //     type: Fiberchat.getAuthenticationType(
                        //         biometricEnabled, _cachedModel),
                        //     prefs: prefs, onSuccess: () async {
                        //   await Future.delayed(Duration(seconds: 0));
                        //   unawaited(showDialog(
                        //       context: context,
                        //       builder: (context) {
                        //         return AliasForm(user, _cachedModel);
                        //       }));
                        // });

                        unawaited(showDialog(
                            context: context,
                            builder: (context) {
                              return AliasForm(user, _cachedModel);
                            }));
                      },
                      leading:
                          customCircleAvatar(url: user['photoUrl'], radius: 22),
                      title: Text(
                        Fiberchat.getNickname(user),
                        style: TextStyle(color: fiberchatBlack, fontSize: 16),
                      ),
                      onTap: () {
                        if (_cachedModel.currentUser[LOCKED] != null &&
                            _cachedModel.currentUser[LOCKED]
                                .contains(user[PHONE])) {
                          NavigatorState state = Navigator.of(context);
                          ChatController.authenticate(_cachedModel,
                              'Authentication needed to unlock the chat.',
                              state: state,
                              shouldPop: false,
                              type: Fiberchat.getAuthenticationType(
                                  biometricEnabled, _cachedModel),
                              prefs: widget.prefs, onSuccess: () {
                            state.pushReplacement(new MaterialPageRoute(
                                builder: (context) => new ChatScreen(
                                    unread: unread,
                                    model: _cachedModel,
                                    currentUserNo: currentUserNo,
                                    peerNo: user[PHONE] as String)));
                          });
                        } else {
                          Navigator.push(
                              context,
                              new MaterialPageRoute(
                                  builder: (context) => new ChatScreen(
                                      unread: unread,
                                      model: _cachedModel,
                                      currentUserNo: currentUserNo,
                                      peerNo: user[PHONE] as String)));
                        }
                      },
                      trailing: unread != 0
                          ? Container(
                              child: Text(unread.toString(),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              padding: const EdgeInsets.all(7.0),
                              decoration: new BoxDecoration(
                                shape: BoxShape.circle,
                                color: user[LAST_SEEN] == true
                                    ? fiberchatLightGreen
                                    : Colors.blue[300],
                              ),
                            )
                          : Container(
                              child: Container(width: 0, height: 0),
                              padding: const EdgeInsets.all(7.0),
                              decoration: new BoxDecoration(
                                shape: BoxShape.circle,
                                color: user[LAST_SEEN] == true
                                    ? fiberchatLightGreen
                                    : Colors.grey,
                              ),
                            )),
                  Divider(),
                ],
              ));
        },
      );
    }
  }

  Stream<MessageData> getUnread(Map<String, dynamic> user) {
    String chatId = Fiberchat.getChatId(currentUserNo, user[PHONE]);
    var controller = StreamController<MessageData>.broadcast();
    unreadSubscriptions.add(FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .snapshots()
        .listen((doc) {
      if (doc[currentUserNo] != null && doc[currentUserNo] is int) {
        unreadSubscriptions.add(FirebaseFirestore.instance
            .collection(MESSAGES)
            .doc(chatId)
            .collection(chatId)
            .snapshots()
            .listen((snapshot) {
          controller.add(
              MessageData(snapshot: snapshot, lastSeen: doc[currentUserNo]));
        }));
      }
    }));
    controllers.add(controller);
    return controller.stream;
  }

  _isHidden(phoneNo) {
    Map<String, dynamic> _currentUser = _cachedModel.currentUser;
    return _currentUser[HIDDEN] != null &&
        _currentUser[HIDDEN].contains(phoneNo);
  }

  StreamController<String> _userQuery =
      new StreamController<String>.broadcast();

  List<Map<String, dynamic>> _users = List<Map<String, dynamic>>();

  _chats(Map<String, Map<String, dynamic>> _userData,
      Map<String, dynamic> currentUser) {
    _users = Map.from(_userData)
        .values
        .where((_user) => _user.keys.contains(CHAT_STATUS))
        .toList()
        .cast<Map<String, dynamic>>();
    Map<String, int> _lastSpokenAt = _cachedModel.lastSpokenAt;
    List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>();

    _users.sort((a, b) {
      int aTimestamp = _lastSpokenAt[a[PHONE]] ?? 0;
      int bTimestamp = _lastSpokenAt[b[PHONE]] ?? 0;
      return bTimestamp - aTimestamp;
    });

    if (!showHidden) {
      _users.removeWhere((_user) => _isHidden(_user[PHONE]));
    }

    return Stack(
      children: <Widget>[
        RefreshIndicator(
            onRefresh: () {
              isAuthenticating = false;
              setState(() {
                showHidden = true;
              });
              return Future.value(false);
            },
            child: Container(
                child: _users.isNotEmpty
                    ? StreamBuilder(
                        stream: _userQuery.stream.asBroadcastStream(),
                        builder: (context, snapshot) {
                          if (_filter.text.isNotEmpty ||
                              snapshot.hasData && snapshot.data.isNotEmpty) {
                            filtered = this._users.where((user) {
                              return user[NICKNAME]
                                  .toLowerCase()
                                  .trim()
                                  .contains(new RegExp(r'' +
                                      _filter.text.toLowerCase().trim() +
                                      ''));
                            }).toList();
                            if (filtered.isNotEmpty)
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.all(0.0),
                                itemBuilder: (context, index) => buildItem(
                                    context, filtered.elementAt(index)),
                                itemCount: filtered.length,
                              );
                            else
                              return ListView(shrinkWrap: true, children: [
                                Padding(
                                    padding: EdgeInsets.only(
                                        top:
                                            MediaQuery.of(context).size.height /
                                                3.5),
                                    child: Center(
                                      child: Text('No search results.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: fiberchatGrey,
                                          )),
                                    ))
                              ]);
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(0, 10, 0, 30),
                            itemBuilder: (context, index) =>
                                buildItem(context, _users.elementAt(index)),
                            itemCount: _users.length,
                          );
                        })
                    : ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(0),
                        children: [
                            Padding(
                                padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).size.height /
                                        3.5),
                                child: Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(30.0),
                                      child: Text(
                                          'Start a chat with your friend !',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            height: 1.59,
                                            color: fiberchatGrey,
                                          ))),
                                )),
                            //TODO ADMOB CODE
                            // IsBannerAdShow == true
                            //     ? Container(
                            //         margin:
                            //             EdgeInsets.only(bottom: 30.0, top: 30),
                            //         child: AdmobBanner(
                            //           adUnitId: getBannerAdUnitId(),
                            //           adSize: AdmobBannerSize.MEDIUM_RECTANGLE,
                            //           listener: (AdmobAdEvent event,
                            //               Map<String, dynamic> args) {
                            //             // handleEvent(event, args, 'Banner');
                            //           },
                            //           onBannerCreated:
                            //               (AdmobBannerController controller) {
                            //             // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
                            //             // Normally you don't need to worry about disposing this yourself, it's handled.
                            //             // If you need direct access to dispose, this is your guy!
                            //             // controller.dispose();
                            //           },
                            //         ),
                            //       )
                            //     : SizedBox(height: 0),
                          ]))),
      ],
    );
  }

  DataModel getModel() {
    _cachedModel ??= DataModel(currentUserNo);
    return _cachedModel;
  }

  @override
  Widget build(BuildContext context) {
    return Fiberchat.getNTPWrappedWidget(ScopedModel<DataModel>(
      model: getModel(),
      child:
          ScopedModelDescendant<DataModel>(builder: (context, child, _model) {
        _cachedModel = _model;
        return Scaffold(
            key: scaffoldState,
            backgroundColor: fiberchatWhite,
            body: ListView(
                padding: EdgeInsets.all(5),
                shrinkWrap: true,
                children: [
                  Container(
                    height: 77,
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _filter,
                      decoration: new InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: fiberchatLightGreen, width: 2.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: fiberchatGrey, width: 1.5),
                        ),
                        hintText: 'Search Recent chats',
                      ),
                    ),
                  ),
                  //TODO ADMOB CODE
                  // IsBannerAdShow == true
                  //     ? Container(
                  //         margin: EdgeInsets.only(bottom: 20.0, top: 10),
                  //         child: AdmobBanner(
                  //           adUnitId: getBannerAdUnitId(),
                  //           adSize: bannerSize,
                  //           listener: (AdmobAdEvent event,
                  //               Map<String, dynamic> args) {
                  //             // handleEvent(event, args, 'Banner');
                  //           },
                  //           onBannerCreated:
                  //               (AdmobBannerController controller) {
                  //             // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
                  //             // Normally you don't need to worry about disposing this yourself, it's handled.
                  //             // If you need direct access to dispose, this is your guy!
                  //             // controller.dispose();
                  //           },
                  //         ),
                  //       )
                  //     : SizedBox(height: 0),
                  // TextField(
                  //   autofocus: false,
                  //   style: TextStyle(color: fiberchatWhite),
                  //   controller: _filter,
                  //   decoration: new InputDecoration(
                  //       focusedBorder: InputBorder.none,
                  //       prefixIcon: Icon(
                  //         Icons.search,
                  //         color: fiberchatWhite.withOpacity(0.5),
                  //       ),
                  //       hintText: 'Search Recent chats',
                  //       hintStyle: TextStyle(
                  //         color: fiberchatWhite.withOpacity(0.4),
                  //       )),
                  // ),

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Recent chats',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(),
                  SizedBox(
                    height: 10,
                  ),
                  _chats(_model.userData, _model.currentUser),
                  //TODO ADMOB CODE
                  // IsBannerAdShow == true
                  //     ? Container(
                  //         margin: EdgeInsets.only(bottom: 10.0, top: 0),
                  //         child: AdmobBanner(
                  //           adUnitId: getBannerAdUnitId(),
                  //           adSize: AdmobBannerSize.MEDIUM_RECTANGLE,
                  //           listener: (AdmobAdEvent event,
                  //               Map<String, dynamic> args) {
                  //             // handleEvent(event, args, 'Banner');
                  //           },
                  //           onBannerCreated:
                  //               (AdmobBannerController controller) {
                  //             // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
                  //             // Normally you don't need to worry about disposing this yourself, it's handled.
                  //             // If you need direct access to dispose, this is your guy!
                  //             // controller.dispose();
                  //           },
                  //         ),
                  //       )
                  //     : SizedBox(height: 0),
                ]));
      }),
    ));
  }

  @override
  void dispose() {
    //TODO ADMOB CODE
    // if (IsBannerAdShow == true) {
    //   interstitialAd.dispose();
    //   rewardAd.dispose();
    // }

    super.dispose();
  }
}
