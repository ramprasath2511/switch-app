import 'dart:async';

import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/integrations/models/call.dart';
import 'package:fiberchat/integrations/screens/callscreens/cached_image.dart';
import 'package:fiberchat/integrations/utils/call_utilities.dart';
import 'package:flutter/material.dart';

class AudioCall extends StatefulWidget {
  final String channelName;
  final Call call;
  final String currentuseruid;
  final ClientRole role;
  const AudioCall(
      {Key key,
      @required this.call,
      @required this.currentuseruid,
      this.channelName,
      this.role})
      : super(key: key);

  @override
  _AudioCallState createState() => _AudioCallState();
}

class _AudioCallState extends State<AudioCall> {
  final _users = <int>[];
  final _infoStrings = <String>[];
  bool muted = false;
  RtcEngine _engine;

  @override
  void dispose() {
    // clear users
    _users.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    super.dispose();
  }

  Stream<DocumentSnapshot> stream;
  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initialize();
    stream = usersCollection
        .doc(widget.currentuseruid == widget.call.callerId
            ? widget.call.receiverId
            : widget.call.callerId)
        .collection(CALL_HISTORY_COLLECTION)
        .doc(widget.call.timeepoch.toString())
        .snapshots();
  }

  bool isspeaker = false;
  Future<void> initialize() async {
    if (Agora_APP_IDD.isEmpty) {
      setState(() {
        _infoStrings.add(
          'Agora_APP_IDD missing, please provide your Agora_APP_IDD in app_constant.dart',
        );
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }

    await _initAgoraRtcEngine();
    _addAgoraEventHandlers();

    VideoEncoderConfiguration configuration = VideoEncoderConfiguration();
    configuration.dimensions = VideoDimensions(1920, 1080);
    await _engine.setVideoEncoderConfiguration(configuration);
    await _engine.joinChannel(Agora_TOKEN, widget.channelName, null, 0);
  }

  Future<void> _initAgoraRtcEngine() async {
    _engine = await RtcEngine.create(Agora_APP_IDD);
    await _engine.setEnableSpeakerphone(isspeaker);
    await _engine.setChannelProfile(ChannelProfile.LiveBroadcasting);
    await _engine.setClientRole(widget.role);
  }

  bool isalreadyendedcall = false;
  void _addAgoraEventHandlers() {
    _engine.setEventHandler(RtcEngineEventHandler(error: (code) {
      setState(() {
        final info = 'onError: $code';
        _infoStrings.add(info);
      });
    }, joinChannelSuccess: (channel, uid, elapsed) {
      if (widget.call.callerId == widget.currentuseruid) {
        setState(() {
          final info = 'onJoinChannel: $channel, uid: $uid';
          _infoStrings.add(info);
        });
        usersCollection
            .doc(widget.call.callerId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'TYPE': 'OUTGOING',
          'ISVIDEOCALL': widget.call.isvideocall,
          'PEER': widget.call.receiverId,
          'TARGET': widget.call.receiverId,
          'TIME': widget.call.timeepoch,
          'DP': widget.call.receiverPic,
          'ISMUTED': false,
          'ISJOINEDEVER': false,
          'STATUS': 'calling',
          'STARTED': null,
          'ENDED': null,
        }, SetOptions(merge: true));
        usersCollection
            .doc(widget.call.receiverId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'TYPE': 'INCOMING',
          'ISVIDEOCALL': widget.call.isvideocall,
          'PEER': widget.call.callerId,
          'TARGET': widget.call.receiverId,
          'TIME': widget.call.timeepoch,
          'DP': widget.call.callerPic,
          'ISMUTED': false,
          'ISJOINEDEVER': true,
          'STATUS': 'missedcall',
          'STARTED': null,
          'ENDED': null,
        }, SetOptions(merge: true));
      }
    }, leaveChannel: (stats) {
      setState(() {
        _infoStrings.add('onLeaveChannel');
        _users.clear();
      });
      if (isalreadyendedcall == false) {
        usersCollection
            .doc(widget.call.callerId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'STATUS': 'ended',
          'ENDED': DateTime.now(),
        }, SetOptions(merge: true));
        usersCollection
            .doc(widget.call.receiverId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'STATUS': 'ended',
          'ENDED': DateTime.now(),
        }, SetOptions(merge: true));
      }
    }, userJoined: (uid, elapsed) {
      setState(() {
        final info = 'userJoined: $uid';
        _infoStrings.add(info);
        _users.add(uid);
      });
      if (widget.currentuseruid == widget.call.callerId) {
        usersCollection
            .doc(widget.call.callerId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'STARTED': DateTime.now(),
          'STATUS': 'pickedup',
          'ISJOINEDEVER': true,
        }, SetOptions(merge: true));
        usersCollection
            .doc(widget.call.receiverId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'STARTED': DateTime.now(),
          'STATUS': 'pickedup',
        }, SetOptions(merge: true));
      }
    }, userOffline: (uid, elapsed) {
      setState(() {
        final info = 'userOffline: $uid';
        _infoStrings.add(info);
        _users.remove(uid);
      });

      if (isalreadyendedcall == false) {
        usersCollection
            .doc(widget.call.callerId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'STATUS': 'ended',
          'ENDED': DateTime.now(),
        }, SetOptions(merge: true));
        usersCollection
            .doc(widget.call.receiverId)
            .collection(CALL_HISTORY_COLLECTION)
            .doc(widget.call.timeepoch.toString())
            .set({
          'STATUS': 'ended',
          'ENDED': DateTime.now(),
        }, SetOptions(merge: true));
      }
    }, firstRemoteVideoFrame: (uid, width, height, elapsed) {
      setState(() {
        final info = 'firstRemoteVideo: $uid ${width}x $height';
        _infoStrings.add(info);
      });
    }));
  }

  Widget _toolbar(
    bool isshowspeaker,
    String status,
  ) {
    if (widget.role == ClientRole.Audience) return Container();
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 35),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          status == 'ended' || status == 'rejected'
              ? SizedBox(height: 42, width: 42)
              : RawMaterialButton(
                  onPressed: _onToggleMute,
                  child: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: muted ? Colors.white : Colors.blueAccent,
                    size: 22.0,
                  ),
                  shape: CircleBorder(),
                  elevation: 2.0,
                  fillColor: muted ? Colors.blueAccent : Colors.white,
                  padding: const EdgeInsets.all(12.0),
                ),
          RawMaterialButton(
            onPressed: () async {
              setState(() {
                isalreadyendedcall =
                    status == 'ended' || status == 'rejected' ? true : false;
              });

              _onCallEnd(context);
            },
            child: Icon(
              status == 'ended' || status == 'rejected'
                  ? Icons.close
                  : Icons.call,
              color: Colors.white,
              size: 35.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: status == 'ended' || status == 'rejected'
                ? Colors.black
                : Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          isshowspeaker == true
              ? RawMaterialButton(
                  onPressed: _onToggleSpeaker,
                  child: Icon(
                    isspeaker
                        ? Icons.volume_mute_rounded
                        : Icons.volume_off_sharp,
                    color: isspeaker ? Colors.white : Colors.blueAccent,
                    size: 22.0,
                  ),
                  shape: CircleBorder(),
                  elevation: 2.0,
                  fillColor: isspeaker ? Colors.blueAccent : Colors.white,
                  padding: const EdgeInsets.all(12.0),
                )
              : SizedBox(height: 42, width: 42)
        ],
      ),
    );
  }

  audioscreen({BuildContext context, String status, bool ispeermuted}) {
    var w = MediaQuery.of(context).size.width;
    var h = MediaQuery.of(context).size.height;
    return Container(
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            status == 'nonetwork'
                ? 'Connecting...'
                : status == 'ringing' || status == 'missedcall'
                    ? 'Calling...'
                    : status == 'calling'
                        ? 'Calling...'
                        : status == 'pickedup'
                            ? 'On Call'
                            : status == 'ended'
                                ? 'Call Ended !'
                                : status == 'rejected'
                                    ? 'Call Rejected !'
                                    : 'Please wait...',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: status == 'pickedup' ? fiberchatLightGreen : Colors.white,
              fontSize: 25,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              status == 'pickedup' ? 'Call picked up' : 'Voice Call',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color:
                    status == 'pickedup' ? fiberchatLightGreen : Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 65),
          status == 'pickedup'
              ? CachedImage(
                  widget.call.callerPic,
                  isRound: true,
                  height: w > h ? 60 : 140,
                  width: w > h ? 60 : 140,
                  radius: w > h ? 70 : 168,
                )
              : Container(
                  height: w > h ? 60 : 140,
                  width: w > h ? 60 : 140,
                  child: Icon(
                    status == 'ended' || status == 'rejected'
                        ? Icons.call_end_sharp
                        : Icons.call,
                    size: w > h ? 60 : 140,
                    color: Colors.white24,
                  ),
                ),
          SizedBox(height: 45),
          Text(
            widget.call.callerId == widget.currentuseruid
                ? widget.call.receiverName
                : widget.call.receiverName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            widget.call.callerId == widget.currentuseruid
                ? widget.call.receiverId
                : widget.call.callerId,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              fontSize: 19,
            ),
          ),
          SizedBox(
            height: h / 10,
          ),
          status == 'pickedup'
              ? ispeermuted == true
                  ? Text(
                      'Peer device is muted',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                        fontSize: 19,
                      ),
                    )
                  : SizedBox(
                      height: 0,
                    )
              : SizedBox(
                  height: 0,
                )
        ],
      ),
    );
  }

  Widget _panel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: ListView.builder(
            reverse: true,
            itemCount: _infoStrings.length,
            itemBuilder: (BuildContext context, int index) {
              if (_infoStrings.isEmpty) {
                return null;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible(
                    //   child: Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       vertical: 2,
                    //       horizontal: 5,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: Colors.yellowAccent,
                    //       borderRadius: BorderRadius.circular(5),
                    //     ),
                    //     child: Text(
                    //       _infoStrings[index],
                    //       style: TextStyle(color: Colors.blueGrey),
                    //     ),
                    //   ),
                    // )
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onCallEnd(BuildContext context) async {
    await CallUtils.callMethods.endCall(call: widget.call);
    DateTime now = DateTime.now();
    if (isalreadyendedcall == false) {
      await usersCollection
          .doc(widget.call.callerId)
          .collection(CALL_HISTORY_COLLECTION)
          .doc(widget.call.timeepoch.toString())
          .set({'STATUS': 'ended', 'ENDED': now}, SetOptions(merge: true));
      await usersCollection
          .doc(widget.call.receiverId)
          .collection(CALL_HISTORY_COLLECTION)
          .doc(widget.call.timeepoch.toString())
          .set({'STATUS': 'ended', 'ENDED': now}, SetOptions(merge: true));
    }
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
    usersCollection
        .doc(widget.currentuseruid)
        .collection(CALL_HISTORY_COLLECTION)
        .doc(widget.call.timeepoch.toString())
        .set({'ISMUTED': muted}, SetOptions(merge: true));
  }

  void _onToggleSpeaker() {
    setState(() {
      isspeaker = !isspeaker;
    });
    _engine.setEnableSpeakerphone(isspeaker);
  }

  Future<bool> onWillPopNEw(BuildContext context) {
    // _onCallEnd(context);
    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => onWillPopNEw(context),
      child: Scaffold(
          backgroundColor: fiberchatDeepGreen,
          body: StreamBuilder<DocumentSnapshot>(
            stream: stream,
            builder: (BuildContext context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data.data() == null || snapshot.data == null) {
                  return Center(
                    child: Stack(
                      children: <Widget>[
                        // _viewRows(),
                        audioscreen(
                            context: context,
                            status: 'calling',
                            ispeermuted: false),
                        _panel(),
                        _toolbar(false, 'calling'),
                      ],
                    ),
                  );
                } else {
                  return Center(
                    child: Stack(
                      children: <Widget>[
                        // _viewRows(),
                        audioscreen(
                            context: context,
                            status: snapshot.data.data()["STATUS"],
                            ispeermuted: snapshot.data.data()["ISMUTED"]),
                        _panel(),
                        _toolbar(
                            snapshot.data.data()["STATUS"] == 'pickedup'
                                ? true
                                : false,
                            snapshot.data.data()["STATUS"]),
                      ],
                    ),
                  );
                }
              } else if (!snapshot.hasData) {
                return Center(
                  child: Stack(
                    children: <Widget>[
                      // _viewRows(),
                      audioscreen(
                          context: context,
                          status: 'nonetwork',
                          ispeermuted: false),
                      _panel(),
                      _toolbar(false, 'nonetwork'),
                    ],
                  ),
                );
              }
              return Center(
                child: Stack(
                  children: <Widget>[
                    // _viewRows(),
                    audioscreen(
                        context: context,
                        status: 'calling',
                        ispeermuted: false),
                    _panel(),
                    _toolbar(false, 'calling'),
                  ],
                ),
              );
            },
          )),
    );
  }
}
