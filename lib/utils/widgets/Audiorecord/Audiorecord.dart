import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/integrations/utils/permissions.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

///
typedef _Fn = void Function();

/// Example app.
class AudioRecord extends StatefulWidget {
  AudioRecord({
    Key key,
    @required this.title,
    @required this.callback,
  }) : super(key: key);

  final String title;
  final Function callback;

  @override
  _AudioRecordState createState() => _AudioRecordState();
}

class _AudioRecordState extends State<AudioRecord> {
  FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  bool _mplaybackReady = false;
  final String _mPath = 'Recording${DateTime.now().millisecondsSinceEpoch}.aac';

  @override
  void initState() {
    _mPlayer.openAudioSession().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });

    openTheRecorder().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _mPlayer.closeAudioSession();
    _mPlayer = null;

    _mRecorder.closeAudioSession();
    _mRecorder = null;
    super.dispose();
  }

  bool issinit = true;
  Future<void> openTheRecorder() async {
    if (!kIsWeb) {
      var status = await Permissions.getMicrophonePermission();

      if (status != PermissionStatus.granted) {
        Fiberchat.showRationale(
            'Permission to access Microphone is required to Start.');
        Navigator.push(context,
            new MaterialPageRoute(builder: (context) => OpenSettings()));
      } else {
        await _mRecorder.openAudioSession();
        _mRecorderIsInited = true;
      }
    }
  }

  // ----------------------  Here is the code for recording and playback -------
  Timer timerr;
  void record() async {
    _mRecorder
        .startRecorder(
      toFile: _mPath,
      //codec: kIsWeb ? Codec.opusWebM : Codec.aacADTS,
    )
        .then((value) {
      setState(() {
        status = 'recording';
        issinit = false;
      });
    });
  }

  File recordedfile;
  void stopRecorder() async {
    await _mRecorder.stopRecorder().then((value) async {
      setState(() {
        _mplaybackReady = true;
        status = 'recorded';
      });
      setState(() {
        recordedfile = File(value);
      });
    });
  }

  void play() async {
    assert(_mPlayerIsInited &&
        _mplaybackReady &&
        _mRecorder.isStopped &&
        _mPlayer.isStopped);
    _mPlayer
        .startPlayer(
            fromURI: _mPath,
            //codec: kIsWeb ? Codec.opusWebM : Codec.aacADTS,
            whenFinished: () {
              setState(() {});
            })
        .then((value) {
      setState(() {
        // status = 'play';
      });
    });
  }

  void stopPlayer() {
    _mPlayer.stopPlayer().then((value) {
      setState(() {
        setState(() {
          // status = 'notplay';
        });
      });
    });
  }

// ----------------------------- UI --------------------------------------------

  _Fn getRecorderFn() {
    if (!_mRecorderIsInited || !_mPlayer.isStopped) {
      return null;
    }
    return _mRecorder.isStopped ? record : stopRecorder;
  }

  _Fn getPlaybackFn() {
    if (!_mPlayerIsInited || !_mplaybackReady || !_mRecorder.isStopped) {
      return null;
    }
    return _mPlayer.isStopped ? play : stopPlayer;
  }

  String status = 'notrecording';

  Future<bool> onWillPopNEw() {
    return Future.value(issinit == true
        ? true
        : status == 'recorded'
            ? _mPlayer.isPlaying
                ? false
                : true
            : false);
  }

  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    Widget makeBody() {
      return Center(
        child: isLoading == true
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(fiberchatLightGreen))
            : Column(
                children: [
                  SizedBox(
                    height: 30,
                  ),
                  Container(
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.all(13),
                    // height: 160,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Column(children: [
                      Text(
                        _mRecorder.isRecording
                            ? 'Recording....'
                            : 'Recorder is stopped',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      RawMaterialButton(
                        onPressed: getRecorderFn(),
                        elevation: 2.0,
                        fillColor:
                            _mRecorder.isRecording ? Colors.red : Colors.white,
                        child: Icon(
                          _mRecorder.isRecording
                              ? Icons.stop
                              : Icons.mic_rounded,
                          size: 75.0,
                          color: _mRecorder.isRecording
                              ? Colors.white
                              : Colors.red,
                        ),
                        padding: EdgeInsets.all(15.0),
                        shape: CircleBorder(),
                      ),
                    ]),
                  ),
                  Container(
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.all(13),
                    // height: 160,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Column(children: [
                      Text(
                        _mPlayer.isPlaying ? 'Playing Recorded' : '',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      RawMaterialButton(
                        onPressed: getPlaybackFn(),
                        elevation: 2.0,
                        fillColor:
                            _mPlayer.isPlaying ? Colors.blue : Colors.white,
                        child: Icon(
                          _mPlayer.isPlaying ? Icons.stop : Icons.play_arrow,
                          size: 75.0,
                          color:
                              _mPlayer.isPlaying ? Colors.white : Colors.blue,
                        ),
                        padding: EdgeInsets.all(15.0),
                        shape: CircleBorder(),
                      ),
                    ]),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  status == 'recorded'
                      ? _mPlayer.isPlaying
                          ? SizedBox()
                          : RaisedButton(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                  side: BorderSide(color: fiberchatLightGreen)),
                              elevation: 0.2,
                              color: fiberchatLightGreen,
                              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                });
                                Fiberchat.toast(
                                    'Sending Recording... Please wait !');
                                widget
                                    .callback(recordedfile)
                                    .then((recordedUrl) {
                                  Navigator.pop(context, recordedUrl);
                                });
                              },
                              child: Text(
                                'Send Recording',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ))
                      : SizedBox()
                ],
              ),
      );
    }

    return WillPopScope(
        onWillPop: onWillPopNEw,
        child: Scaffold(
          backgroundColor: fiberchatDeepGreen,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: fiberchatDeepGreen,
            title: Text(widget.title ?? 'Audio Recorder'),
          ),
          body: makeBody(),
        ));
  }
}
