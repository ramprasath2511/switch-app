import 'dart:async';
import 'dart:core';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/core/auth/screens/login.dart';
import 'package:fiberchat/core/settings/screens/settings.dart';
import 'package:fiberchat/main.dart';
import 'package:fiberchat/modules/AllChats/screens/RecentsChats.dart';
import 'package:fiberchat/modules/AllChats/screens/SearchChat.dart';
import 'package:fiberchat/modules/callhistory/screens/callhistory.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/integrations/provider/user_provider.dart';
import 'package:fiberchat/integrations/screens/callscreens/cached_image.dart';
import 'package:fiberchat/integrations/screens/callscreens/pickup/pickup_layout.dart';
import 'package:fiberchat/utils/services/chat_controller.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:launch_review/launch_review.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:package_info/package_info.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class Homepage extends StatefulWidget {
  Homepage(
      {@required this.currentUserNo, @required this.isSecuritySetupDone, key})
      : super(key: key);
  final String currentUserNo;
  final bool isSecuritySetupDone;
  @override
  State createState() => new HomepageState(currentUserNo: this.currentUserNo);
}

class HomepageState extends State<Homepage>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin {
  HomepageState({Key key, this.currentUserNo}) {
    _filter.addListener(() {
      _userQuery.add(_filter.text.isEmpty ? '' : _filter.text);
    });
  }
  TabController controller;
  @override
  bool get wantKeepAlive => true;

  FirebaseMessaging notifications = new FirebaseMessaging();

  SharedPreferences prefs;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      setIsActive();
    else
      setLastSeen();
  }

  void setIsActive() async {
    if (currentUserNo != null)
      await FirebaseFirestore.instance
          .collection(USERS)
          .doc(currentUserNo)
          .set({LAST_SEEN: true}, SetOptions(merge: true));
  }

  void setLastSeen() async {
    if (currentUserNo != null)
      await FirebaseFirestore.instance.collection(USERS).doc(currentUserNo).set(
          {LAST_SEEN: DateTime.now().millisecondsSinceEpoch},
          SetOptions(merge: true));
  }

  final TextEditingController _filter = new TextEditingController();
  bool isAuthenticating = false;

  StreamSubscription spokenSubscription;
  List<StreamSubscription> unreadSubscriptions = List<StreamSubscription>();

  List<StreamController> controllers = new List<StreamController>();

  @override
  void initState() {
    super.initState();

    controller = TabController(length: 3, vsync: this);
    controller.index = 1;
    listenToNotification();
    Fiberchat.internetLookUp();
    WidgetsBinding.instance.addObserver(this);
    LocalAuthentication().canCheckBiometrics.then((res) {
      if (res) biometricEnabled = true;
    });
    getModel();
    getSignedInUserOrRedirect();
  }

  getuid(BuildContext context) {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    userProvider.getUserDetails(currentUserNo);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    controllers.forEach((controller) {
      controller.close();
    });
    _filter.dispose();
    spokenSubscription?.cancel();
    _userQuery.close();
    cancelUnreadSubscriptions();
    setLastSeen();
  }

  void cancelUnreadSubscriptions() {
    unreadSubscriptions.forEach((subscription) {
      subscription?.cancel();
    });
  }

  void listenToNotification() {
    notifications.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        if (message['notification']['title'] != 'You have new messsage(s)') {
          if (message != null) {
            showOverlayNotification((context) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: SafeArea(
                  child: ListTile(
                    leading: SizedBox.fromSize(
                        size: const Size(40, 40),
                        child: ClipOval(
                            child: CachedImage(message['data']['dp'] ?? ''))),
                    title: Text(message['notification']['title']),
                    subtitle: Text(message['notification']['body']),
                    trailing: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          OverlaySupportEntry.of(context).dismiss();
                        }),
                  ),
                ),
              );
            }, duration: Duration(milliseconds: 4000));
          }
        }
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: ${message["data"]}");
        SchedulerBinding.instance.addPostFrameCallback((_) {});
      },
    );
  }

  DataModel _cachedModel;
  bool showHidden = false, biometricEnabled = false;

  DataModel getModel() {
    _cachedModel ??= DataModel(currentUserNo);
    return _cachedModel;
  }

  getSignedInUserOrRedirect() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {});
    await FirebaseFirestore.instance
        .collection('version')
        .doc('userapp')
        .get()
        .then((doc) async {
      if (doc.exists) {
        final PackageInfo info = await PackageInfo.fromPlatform();
        double currentAppVersionInPhone =
            double.parse(info.version.trim().replaceAll(".", ""));
        double currentNewAppVersionInServer =
            double.parse(doc['version'].trim().replaceAll(".", ""));

        if (currentAppVersionInPhone < currentNewAppVersionInServer) {
          showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              String title = "App Update Available";
              String message =
                  "There is a newer version of app available. You must update app to continue using it.";
              String btnLabel = "UPDATE NOW";
              // String btnLabelCancel = "Later";
              return
                  // Platform.isIOS
                  //     ? new CupertinoAlertDialog(
                  //         title: Text(title),
                  //         content: Text(message),
                  //         actions: <Widget>[
                  //           FlatButton(
                  //             child: Text(btnLabel),
                  //             onPressed: () => launch(doc['url']),
                  //           ),
                  //           // FlatButton(
                  //           //   child: Text(btnLabelCancel),
                  //           //   onPressed: () => Navigator.pop(context),
                  //           // ),
                  //         ],
                  //       )
                  //     :
                  new WillPopScope(
                      onWillPop: () async => false,
                      child: AlertDialog(
                        title: Text(
                          title,
                          style: TextStyle(color: fiberchatDeepGreen),
                        ),
                        content: Text(message),
                        actions: <Widget>[
                          FlatButton(
                            child: Text(
                              btnLabel,
                              style: TextStyle(color: fiberchatLightGreen),
                            ),
                            onPressed: () => launch(doc['url']),
                          ),
                          // FlatButton(
                          //   child: Text(btnLabelCancel),
                          //   onPressed: () => Navigator.pop(context),
                          // ),
                        ],
                      ));
            },
          );
        } else {
          prefs = await SharedPreferences.getInstance();
          if (currentUserNo == null ||
              currentUserNo.isEmpty ||
              widget.isSecuritySetupDone == false ||
              widget.isSecuritySetupDone == null)
            unawaited(Navigator.pushReplacement(
                context,
                new MaterialPageRoute(
                    builder: (context) => new LoginScreen(
                          title: 'Sign in to SwitchApp',
                          issecutitysetupdone: widget.isSecuritySetupDone,
                        ))));
          else {
            getuid(context);
            setIsActive();
            String fcmToken = await notifications.getToken();
            if (prefs.getBool(IS_TOKEN_GENERATED) != true) {
              await FirebaseFirestore.instance
                  .collection(USERS)
                  .doc(currentUserNo)
                  .set({
                NOTIFICATION_TOKENS: FieldValue.arrayUnion([fcmToken])
              }, SetOptions(merge: true));
              unawaited(prefs.setBool(IS_TOKEN_GENERATED, true));
            }
          }
        }
      } else {
        await FirebaseFirestore.instance
            .collection('version')
            .doc('userapp')
            .set({'version': '1.0.0', 'url': 'https://www.google.com/'},
                SetOptions(merge: true));
        Fiberchat.toast('Server Setup Done ! Please restart the app');
      }
    }).catchError((err) {
      print('FETCHING ERROR: $err');
      Fiberchat.toast('Loading Failed ! Please restart the app');
    });
  }

  String currentUserNo;

  bool isLoading = false;

  StreamController<String> _userQuery =
      new StreamController<String>.broadcast();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PickupLayout(
        scaffold: Fiberchat.getNTPWrappedWidget(WillPopScope(
            onWillPop: () {
              if (!isAuthenticating) setLastSeen();
              return Future.value(true);
            },
            child: Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                    backgroundColor: fiberchatDeepGreen,
                    title: Text(
                      Appname,
                      style: TextStyle(
                        fontSize: 21.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    actions: <Widget>[
                      // IconButton(icon: Icon(Icons.search), onPressed: () {}),
                      PopupMenuButton(
                        padding: EdgeInsets.all(0),
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 1),
                          child: Icon(Icons.more_vert_outlined,
                              color: fiberchatWhite),
                        ),
                        color: fiberchatWhite,
                        onSelected: (val) async {
                          switch (val) {
                            case 'rate':
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return Theme(
                                      data: FiberchatTheme,
                                      child: SimpleDialog(children: <Widget>[
                                        ListTile(
                                            contentPadding:
                                                EdgeInsets.only(top: 20),
                                            subtitle: Padding(
                                                padding:
                                                    EdgeInsets.only(top: 10.0)),
                                            title: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    size: 40,
                                                    color: fiberchatGrey,
                                                  ),
                                                  Icon(
                                                    Icons.star,
                                                    size: 40,
                                                    color: fiberchatGrey,
                                                  ),
                                                  Icon(
                                                    Icons.star,
                                                    size: 40,
                                                    color: fiberchatGrey,
                                                  ),
                                                  Icon(
                                                    Icons.star,
                                                    size: 40,
                                                    color: fiberchatGrey,
                                                  ),
                                                  Icon(
                                                    Icons.star,
                                                    size: 40,
                                                    color: fiberchatGrey,
                                                  ),
                                                ]),
                                            onTap: () {
                                              LaunchReview.launch();
                                              Navigator.pop(context);
                                            }),
                                        Divider(),
                                        Padding(
                                            child: Text(
                                              'Loved the app ? Rate the app on Playstore.',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: fiberchatBlack),
                                              textAlign: TextAlign.center,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10)),
                                        Center(
                                            child: RaisedButton(
                                                elevation: 0,
                                                color: fiberchatgreen,
                                                child: Text(
                                                  'Rate App',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                onPressed: () {
                                                  LaunchReview.launch();
                                                  Navigator.pop(context);
                                                }))
                                      ]),
                                    );
                                  });
                              break;
                            case 'about':
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return Theme(
                                        child: SimpleDialog(
                                          contentPadding: EdgeInsets.all(20),
                                          children: <Widget>[
                                            ListTile(
                                                title: Text(
                                                    'Swipe down the screen to view hidden chats.'),
                                                subtitle: Text(
                                                    'Swipe down again to hide them')),
                                            SizedBox(
                                              height: 10,
                                            ),
                                            ListTile(
                                                title: Text(
                                                    'Long press on the chat to set alias.'))
                                          ],
                                        ),
                                        data: FiberchatTheme);
                                  });
                              break;
                            case 'privacy':
                              launch(PRIVACY_POLICY_URL);
                              break;
                            case 'tnc':
                              launch(TERMS_CONDITION_URL);
                              break;
                            case 'share':
                              Fiberchat.invite();

                              break;
                            case 'feedback':
                              launch('mailto:$FeedbackEmail');
                              break;
                            case 'logout':
                              final FirebaseAuth firebaseAuth =
                                  FirebaseAuth.instance;

                              await firebaseAuth.signOut();
                              await prefs.setString(PHONE, null);

                              // Navigator.pop(context);

                              FlutterSecureStorage storage =
                                  new FlutterSecureStorage();
                              // ignore: await_only_futures
                              await storage.delete;
                              Navigator.of(context).pushAndRemoveUntil(
                                // the new route
                                MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      FiberchatWrapper(),
                                ),

                                // this function should return true when we're done removing routes
                                // but because we want to remove all other screens, we make it
                                // always return false
                                (Route route) => false,
                              );
                              // main();
                              break;
                            case 'settings':
                              ChatController.authenticate(_cachedModel,
                                  'Authentication needed to unlock the Settings',
                                  state: Navigator.of(context),
                                  shouldPop: false,
                                  type: Fiberchat.getAuthenticationType(
                                      biometricEnabled, _cachedModel),
                                  prefs: prefs, onSuccess: () {
                                Navigator.pushReplacement(
                                    context,
                                    new MaterialPageRoute(
                                        builder: (context) => SettingsScreen(
                                              biometricEnabled:
                                                  biometricEnabled,
                                              type: Fiberchat
                                                  .getAuthenticationType(
                                                      biometricEnabled,
                                                      _cachedModel),
                                            )));
                              });
                              // Navigator.push(
                              //     context,
                              //     new MaterialPageRoute(
                              //         builder: (context) => SettingsScreen(
                              //               biometricEnabled: biometricEnabled,
                              //               type:
                              //                   Fiberchat.getAuthenticationType(
                              //                       biometricEnabled,
                              //                       _cachedModel),
                              //             )));

                              break;
                          }
                        },
                        itemBuilder: (context) => <PopupMenuItem<String>>[
                          PopupMenuItem<String>(
                              value: 'settings', child: Text('Profile')),
                          PopupMenuItem<String>(
                            value: 'rate',
                            child: Text(
                              'Rate app',
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'share',
                            child: Text('Share app'),
                          ),
                          PopupMenuItem<String>(
                            value: 'feedback',
                            child: Text('Feedback'),
                          ),
                          PopupMenuItem<String>(
                            value: 'about',
                            child: Text('Tutorials'),
                          ),
                          PopupMenuItem<String>(
                            value: 'tnc',
                            child: Text('Terms & Conditions'),
                          ),
                          PopupMenuItem<String>(
                            value: 'privacy',
                            child: Text('Privacy Policy'),
                          ),
                          PopupMenuItem<String>(
                              value: 'logout', child: Text('Logout')),
                        ].where((o) => o != null).toList(),
                      ),
                    ],
                    bottom: TabBar(
                      indicatorWeight: 3,
                      indicatorColor: Colors.white,
                      controller: controller,
                      tabs: <Widget>[
                        Tab(
                          icon: Icon(
                            Icons.search,
                            size: 22,
                          ),
                        ),
                        Tab(
                          child: Text(
                            "CHATS",
                            style: TextStyle(
                                fontSize: 14.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Tab(
                          child: Text(
                            "CALLS",
                            style: TextStyle(
                                fontSize: 14.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    )),
                body: TabBarView(
                  controller: controller,
                  children: <Widget>[
                    SearchChats(
                        prefs: prefs,
                        currentUserNo: widget.currentUserNo,
                        isSecuritySetupDone: widget.isSecuritySetupDone),
                    RecentChats(
                        prefs: prefs,
                        currentUserNo: widget.currentUserNo,
                        isSecuritySetupDone: widget.isSecuritySetupDone),
                    CallHistory(
                      userphone: widget.currentUserNo,
                    ),
                  ],
                )))));
  }
}
