import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
// import 'package:admob_flutter/admob_flutter.dart';
import 'package:collection/collection.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/Admob/admob.dart';
import 'package:fiberchat/modules/callhistory/screens/callhistory.dart';
import 'package:fiberchat/modules/chat/screens/downloadMedia.dart';
import 'package:fiberchat/modules/chat/screens/message.dart';
import 'package:fiberchat/modules/contacts/screens/ContactsSelect.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/modules/photo_view/screens/photo_view.dart';
import 'package:fiberchat/modules/profile/screens/profile_view.dart';
import 'package:fiberchat/integrations/provider/seen_provider.dart';
import 'package:fiberchat/integrations/provider/seen_state.dart';
import 'package:fiberchat/integrations/screens/callscreens/pickup/pickup_layout.dart';
import 'package:fiberchat/integrations/utils/call_utilities.dart';
import 'package:fiberchat/integrations/utils/permissions.dart';
import 'package:fiberchat/utils/services/chat_controller.dart';
import 'package:fiberchat/utils/services/crc.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/save.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:fiberchat/utils/widgets/Audiorecord/Audiorecord.dart';
import 'package:fiberchat/utils/widgets/DocumentPicker.dart/documentPicker.dart';
import 'package:fiberchat/utils/widgets/GiphyPicker/giphy_picker.dart';
import 'package:fiberchat/utils/widgets/ImagePicker/image_picker.dart';
import 'package:fiberchat/utils/widgets/VideoPicker/VideoPicker.dart';
import 'package:fiberchat/utils/widgets/VideoPicker/VideoPreview.dart';
import 'package:fiberchat/widgets/bubble.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fiberchat/utils/widgets/E2EE/e2ee.dart' as e2ee;

import 'package:scoped_model/scoped_model.dart';
import 'package:flutter/services.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:simple_url_preview/simple_url_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

hidekeyboard(BuildContext context) {
  FocusScope.of(context).requestFocus(FocusNode());
}

class ChatScreen extends StatefulWidget {
  final String peerNo, currentUserNo;
  final DataModel model;
  final int unread;
  ChatScreen(
      {Key key,
      @required this.currentUserNo,
      @required this.peerNo,
      @required this.model,
      @required this.unread});

  @override
  State createState() =>
      new _ChatScreenState(currentUserNo: currentUserNo, peerNo: peerNo);
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  GlobalKey<ScaffoldState> _scaffold = new GlobalKey<ScaffoldState>();
  String peerAvatar, peerNo, currentUserNo, privateKey, sharedSecret;
  bool locked, hidden;
  Map<String, dynamic> peer, currentUser;
  int chatStatus, unread;
  GlobalKey<State> _keyLoader =
      new GlobalKey<State>(debugLabel: 'qqqeqeqsseaadqeqe');
  _ChatScreenState({@required this.peerNo, @required this.currentUserNo});

  String chatId;
  SharedPreferences prefs;

  bool typing = false;
  File thumbnailFile;
  File imageFile;
  bool isLoading;
  String imageUrl;
  SeenState seenState;
  List<Message> messages = new List<Message>();
  List<Map<String, dynamic>> _savedMessageDocs =
      new List<Map<String, dynamic>>();

  int uploadTimestamp;

  StreamSubscription seenSubscription, msgSubscription, deleteUptoSubscription;

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController realtime = new ScrollController();
  final ScrollController saved = new ScrollController();
  DataModel _cachedModel;
  //TODO ADMOB CODE
  // AdmobReward rewardAd;
  // AdmobInterstitial interstitialAd;
  @override
  void initState() {
    super.initState();
    Fiberchat.internetLookUp();
    _cachedModel = widget.model;
    updateLocalUserData(_cachedModel);

    seenState = new SeenState(false);
    WidgetsBinding.instance.addObserver(this);
    chatId = '';
    unread = widget.unread;
    isLoading = false;
    imageUrl = '';
    loadSavedMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 10), () {
        readLocal(this.context);
      });
    });
    //TODO ADMOB CODE
    // if (IsVideoAdShow == true) {
    //   rewardAd = AdmobReward(
    //     adUnitId: getRewardBasedVideoAdUnitId(),
    //     listener: (AdmobAdEvent event, Map<String, dynamic> args) {
    //       if (event == AdmobAdEvent.closed) rewardAd.load();
    //       // handleEvent(event, args, 'Reward');
    //     },
    //   );
    //   rewardAd.load();
    //   Future.delayed(const Duration(milliseconds: 4500), () {
    //     rewardAd.show();
    //   });
    // }

    // interstitialAd.load();
  }

  updateLocalUserData(model) {
    peer = model.userData[peerNo];
    currentUser = _cachedModel.currentUser;
    if (currentUser != null && peer != null) {
      hidden =
          currentUser[HIDDEN] != null && currentUser[HIDDEN].contains(peerNo);
      locked =
          currentUser[LOCKED] != null && currentUser[LOCKED].contains(peerNo);
      chatStatus = peer[CHAT_STATUS];
      peerAvatar = peer[PHOTO_URL];
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    setLastSeen();
    msgSubscription?.cancel();
    seenSubscription?.cancel();
    deleteUptoSubscription?.cancel();
  }

  loadvideoAd() {
    return Container();
    //TODO ADMOB CODE
    // return AdmobReward(
    //     adUnitId: getRewardBasedVideoAdUnitId(), nonPersonalizedAds: true);
  }

  void setLastSeen() async {
    if (chatStatus != ChatStatus.blocked.index) {
      if (chatId != null) {
        await FirebaseFirestore.instance.collection(MESSAGES).doc(chatId).set(
            {'$currentUserNo': DateTime.now().millisecondsSinceEpoch},
            SetOptions(merge: true));
      }
    }
  }

  dynamic encryptWithCRC(String input) {
    try {
      String encrypted = cryptor.encrypt(input, iv: iv).base64;
      int crc = CRC32.compute(input);
      return '$encrypted$CRC_SEPARATOR$crc';
    } catch (e) {
      Fiberchat.toast('Waiting for your peer to join the chat.');
      return false;
    }
  }

  String decryptWithCRC(String input) {
    try {
      if (input.contains(CRC_SEPARATOR)) {
        int idx = input.lastIndexOf(CRC_SEPARATOR);
        String msgPart = input.substring(0, idx);
        String crcPart = input.substring(idx + 1);
        int crc = int.tryParse(crcPart);
        if (crc != null) {
          msgPart =
              cryptor.decrypt(encrypt.Encrypted.fromBase64(msgPart), iv: iv);
          if (CRC32.compute(msgPart) == crc) return msgPart;
        }
      }
    } on FormatException {
      Fiberchat.toast('Messages can\'t load');
      return '';
    }
    Fiberchat.toast('Messages  can\'t load  !');
    return '';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      setIsActive();
    else
      setLastSeen();
  }

  void setIsActive() async {
    await FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .set({'$currentUserNo': true}, SetOptions(merge: true));
  }

  dynamic lastSeen;

  FlutterSecureStorage storage = new FlutterSecureStorage();
  encrypt.Encrypter cryptor;
  final iv = encrypt.IV.fromLength(8);

  readLocal(
    BuildContext context,
  ) async {
    prefs = await SharedPreferences.getInstance();
    try {
      privateKey = await storage.read(key: PRIVATE_KEY);
      sharedSecret = (await e2ee.X25519().calculateSharedSecret(
              e2ee.Key.fromBase64(privateKey, false),
              e2ee.Key.fromBase64(peer[PUBLIC_KEY], true)))
          .toBase64();
      final key = encrypt.Key.fromBase64(sharedSecret);
      cryptor = new encrypt.Encrypter(encrypt.Salsa20(key));
    } catch (e) {
      sharedSecret = null;
    }
    try {
      seenState.value = prefs.getInt(getLastSeenKey());
    } catch (e) {
      seenState.value = false;
    }
    chatId = Fiberchat.getChatId(currentUserNo, peerNo);
    textEditingController.addListener(() {
      if (textEditingController.text.isNotEmpty && typing == false) {
        lastSeen = peerNo;
        FirebaseFirestore.instance
            .collection(USERS)
            .doc(currentUserNo)
            .set({LAST_SEEN: peerNo}, SetOptions(merge: true));
        typing = true;
      }
      if (textEditingController.text.isEmpty && typing == true) {
        lastSeen = true;
        FirebaseFirestore.instance
            .collection(USERS)
            .doc(currentUserNo)
            .set({LAST_SEEN: true}, SetOptions(merge: true));
        typing = false;
      }
    });
    setIsActive();
    deleteUptoSubscription = FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .snapshots()
        .listen((doc) {
      if (doc != null && mounted) {
        deleteMessagesUpto(doc.data()[DELETE_UPTO]);
      }
    });
    seenSubscription = FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .snapshots()
        .listen((doc) {
      if (doc != null && mounted) {
        seenState.value = doc[peerNo] ?? false;
        if (seenState.value is int) {
          prefs.setInt(getLastSeenKey(), seenState.value);
        }
      }
    });
    loadMessagesAndListen(context);
  }

  String getLastSeenKey() {
    return "$peerNo-$LAST_SEEN";
  }

  int thumnailtimestamp;
  getImage(File image) {
    if (image != null) {
      setState(() {
        imageFile = image;
      });
    }
    return uploadFile(false);
  }

  getThumbnail(String url) async {
    if (url != null) {
      String path = await VideoThumbnail.thumbnailFile(
          video: url,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.PNG,
          // maxHeight: 150,
          // maxWidth:300,
          // timeMs: r.timeMs,
          quality: 30);
      setState(() {
        thumbnailFile = File(path);
      });
    }
    return uploadFile(true);
  }

//  await VideoThumbnail.thumbnailFile(
//               video: videoGeneratedurl,
//               thumbnailPath: (await getTemporaryDirectory()).path,
//               imageFormat: ImageFormat.PNG,
//               // maxHeight: 150,
//               // maxWidth:300,
//               // timeMs: r.timeMs,
//               quality: 30)
  getWallpaper(File image) {
    if (image != null) {
      _cachedModel.setWallpaper(peerNo, image);
    }
    return Future.value(false);
  }

  getImageFileName(id, timestamp) {
    return "$id-$timestamp";
  }

  FlutterVideoInfo videoInfo = FlutterVideoInfo();
  VideoData info;
  String videometadata;
  Future uploadFile(bool isthumbnail) async {
    uploadTimestamp = DateTime.now().millisecondsSinceEpoch;
    String fileName = getImageFileName(
        currentUserNo,
        isthumbnail == false
            ? '$uploadTimestamp'
            : '${thumnailtimestamp}Thumbnail');
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageTaskSnapshot uploading = await reference
        .putFile(isthumbnail == true ? thumbnailFile : imageFile)
        .onComplete;
    if (isthumbnail == false) {
      setState(() {
        thumnailtimestamp = uploadTimestamp;
      });
    }
    if (isthumbnail == true) {
      info = await videoInfo.getVideoInfo(thumbnailFile.path);
      setState(() {
        videometadata = jsonEncode({
          "width": info.width,
          "height": info.height,
          "orientation": info.orientation,
          "duration": info.duration,
          "filesize": info.filesize,
          "author": info.author,
          "date": info.date,
          "framerate": info.framerate,
          "location": info.location,
          "path": info.path,
          "title": info.title,
          "mimetype": info.mimetype,
        }).toString();
      });
    }

    return uploading.ref.getDownloadURL();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }
    Fiberchat.toast('Detecting Location...');
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  void onSendMessage(BuildContext context, String content, MessageType type,
      int timestamp) async {
    if (content.trim() != '') {
      content = content.trim();
      if (chatStatus == null)
        ChatController.request(currentUserNo, peerNo, chatId);
      textEditingController.clear();
      final encrypted = encryptWithCRC(content);
      if (encrypted is String) {
        Future messaging = FirebaseFirestore.instance
            .collection(MESSAGES)
            .doc(chatId)
            .collection(chatId)
            .doc('$timestamp')
            .set({
          FROM: currentUserNo,
          TO: peerNo,
          TIMESTAMP: timestamp,
          CONTENT: encrypted,
          TYPE: type.index,
        }, SetOptions(merge: true));
        _cachedModel.addMessage(peerNo, timestamp, messaging);
        var tempDoc = {
          TIMESTAMP: timestamp,
          TO: peerNo,
          TYPE: type.index,
          CONTENT: content,
          FROM: currentUserNo,
        };
        setState(() {
          messages = List.from(messages)
            ..add(Message(
              buildTempMessage(context, type, content, timestamp, messaging),
              onTap: type == MessageType.image
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewWrapper(
                          tag: timestamp.toString(),
                          imageProvider: CachedNetworkImageProvider(content),
                        ),
                      ))
                  : null,
              onDismiss: null,
              onDoubleTap: () {
                save(tempDoc);
              },
              onLongPress: () {
                contextMenu(context, tempDoc);
              },
              from: currentUserNo,
              timestamp: timestamp,
            ));
        });

        unawaited(realtime.animateTo(0.0,
            duration: Duration(milliseconds: 300), curve: Curves.easeOut));
      } else {
        Fiberchat.toast('Nothing to send');
      }
    }
  }

  delete(int ts) {
    setState(() {
      messages.removeWhere((msg) => msg.timestamp == ts);
      messages = List.from(messages);
    });
  }

  contextMenu(BuildContext context, Map<String, dynamic> doc,
      {bool saved = false}) {
    List<Widget> tiles = List<Widget>();
    if (saved == false) {
      tiles.add(ListTile(
          dense: true,
          leading: Icon(Icons.save_alt),
          title: Text(
            'Save',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            save(doc);
            Navigator.pop(context);
          }));
    }
    if (doc[FROM] == currentUserNo && saved == false) {
      tiles.add(ListTile(
          dense: true,
          leading: Icon(Icons.delete),
          title: Text(
            'Delete',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            if (doc[TYPE] == MessageType.image.index) {
              FirebaseStorage.instance
                  .ref()
                  .child(getImageFileName(doc[FROM], doc[TIMESTAMP]))
                  .delete();
            } else if (doc[TYPE] == MessageType.doc.index) {
              FirebaseStorage.instance
                  .ref()
                  .child(getImageFileName(doc[FROM], doc[TIMESTAMP]))
                  .delete();
            } else if (doc[TYPE] == MessageType.audio.index) {
              FirebaseStorage.instance
                  .ref()
                  .child(getImageFileName(doc[FROM], doc[TIMESTAMP]))
                  .delete();
            } else if (doc[TYPE] == MessageType.video.index) {
              StorageReference reference1 = FirebaseStorage.instance
                  .ref()
                  .child(getImageFileName(doc[FROM], doc[TIMESTAMP]));
              StorageReference reference2 = FirebaseStorage.instance
                  .ref()
                  .child(getImageFileName(
                      doc[FROM], '${doc[TIMESTAMP]}Thumbnail'));

              await reference1.delete();
              await reference2.delete();
            }

            delete(doc[TIMESTAMP]);
            FirebaseFirestore.instance
                .collection(MESSAGES)
                .doc(chatId)
                .collection(chatId)
                .doc('${doc[TIMESTAMP]}')
                .delete();
            Navigator.pop(context);
            Fiberchat.toast('Deleted!');
          }));
    }
    if (saved == true) {
      tiles.add(ListTile(
          dense: true,
          leading: Icon(Icons.delete),
          title: Text(
            'Delete',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            Save.deleteMessage(peerNo, doc);
            _savedMessageDocs
                .removeWhere((msg) => msg[TIMESTAMP] == doc[TIMESTAMP]);
            setState(() {
              _savedMessageDocs = List.from(_savedMessageDocs);
            });
            Navigator.pop(context);
            Fiberchat.toast('Deleted!');
          }));
    }
    if (doc[TYPE] == MessageType.text.index) {
      tiles.add(ListTile(
          dense: true,
          leading: Icon(Icons.content_copy),
          title: Text(
            'Copy',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            Clipboard.setData(ClipboardData(text: doc[CONTENT]));
            Navigator.pop(context);
            Fiberchat.toast('Copied!');
          }));
    }
    showDialog(
        context: context,
        builder: (context) {
          return Theme(
              data: FiberchatTheme, child: SimpleDialog(children: tiles));
        });
  }

  deleteUpto(int upto) {
    FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .collection(chatId)
        .where(TIMESTAMP, isLessThanOrEqualTo: upto)
        .get()
        .then((query) {
      query.docs.forEach((msg) async {
        if (msg[TYPE] == MessageType.image.index) {
          FirebaseStorage.instance
              .ref()
              .child(getImageFileName(msg[FROM], msg[TIMESTAMP]))
              .delete();
        } else if (msg[TYPE] == MessageType.doc.index) {
          FirebaseStorage.instance
              .ref()
              .child(getImageFileName(msg[FROM], msg[TIMESTAMP]))
              .delete();
        } else if (msg[TYPE] == MessageType.audio.index) {
          FirebaseStorage.instance
              .ref()
              .child(getImageFileName(msg[FROM], msg[TIMESTAMP]))
              .delete();
        } else if (msg[TYPE] == MessageType.video.index) {
          StorageReference reference1 = FirebaseStorage.instance
              .ref()
              .child(getImageFileName(msg[FROM], msg[TIMESTAMP]));
          StorageReference reference2 = FirebaseStorage.instance
              .ref()
              .child(getImageFileName(msg[FROM], '${msg[TIMESTAMP]}Thumbnail'));

          await reference1.delete();
          await reference2.delete();
        }
        msg.reference.delete();
      });
    });

    FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .set({DELETE_UPTO: upto}, SetOptions(merge: true));
    deleteMessagesUpto(upto);
    empty = true;
  }

  deleteMessagesUpto(int upto) {
    if (upto != null) {
      int before = messages.length;
      setState(() {
        messages = List.from(messages.where((msg) => msg.timestamp > upto));
        if (messages.length < before) Fiberchat.toast('Conversation Ended!');
      });
    }
  }

  save(Map<String, dynamic> doc) async {
    Fiberchat.toast('Saved');
    if (!_savedMessageDocs.any((_doc) => _doc[TIMESTAMP] == doc[TIMESTAMP])) {
      String content;
      if (doc[TYPE] == MessageType.image.index) {
        content = doc[CONTENT].toString().startsWith('http')
            ? await Save.getBase64FromImage(imageUrl: doc[CONTENT] as String)
            : doc[CONTENT]; // if not a url, it is a base64 from saved messages
      } else {
        // If text
        content = doc[CONTENT];
      }
      doc[CONTENT] = content;
      Save.saveMessage(peerNo, doc);
      _savedMessageDocs.add(doc);
      setState(() {
        _savedMessageDocs = List.from(_savedMessageDocs);
      });
    }
  }

  Widget selectablelinkify(String text) {
    // text: "Made by https://cretezy.com",
    // style: TextStyle(color: Colors.yellow),
    // linkStyle: TextStyle(color: Colors.red),
    return SelectableLinkify(
      onOpen: (link) async {
        if (await canLaunch(link.url)) {
          await launch(link.url);
        } else {
          throw 'Could not launch $link';
        }
      },
      text: text ?? "",
      style: TextStyle(color: Colors.black, fontSize: 16),
    );
  }

  Widget getTextMessage(bool isMe, Map<String, dynamic> doc, bool saved) {
    return selectablelinkify(
      doc[CONTENT],
      // style: TextStyle(
      //     color: isMe ? fiberchatBlack : Colors.black, fontSize: 16.0),
    );
  }

  Widget getTempTextMessage(String message) {
    return selectablelinkify(
      message,
      // style: TextStyle(
      //     color: isMe ? fiberchatBlack : Colors.black, fontSize: 16.0),
    );
  }

  Widget getLocationMessage(String message, {bool saved = false}) {
    return SimpleUrlPreview(
      descriptionLines: 1,
      titleLines: 1,
      url: '$message',
      textColor: Colors.black54,
      bgColor: Colors.white,
      isClosable: false,
      previewHeight: 150,
    );
  }

  Widget getAudiomessage(BuildContext context, String message,
      {bool saved = false}) {
    return SizedBox(
      width: 220,
      height: 116,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.all(4),
            isThreeLine: false,
            leading: Container(
              decoration: BoxDecoration(
                color: Colors.yellow[800],
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.audiotrack,
                size: 25,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Recording_' + message.split('-BREAK-')[1],
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
          ),
          Divider(
            height: 3,
          ),
          FlatButton(
              onPressed: () async {
                await downloadFile(
                  context: _scaffold.currentContext,
                  fileName: 'Recording_' + message.split('-BREAK-')[1],
                  isonlyview: false,
                  keyloader: _keyLoader,
                  uri: message.split('-BREAK-')[0],
                );
              },
              child: Text('DOWNLOAD',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.blue[400])))
        ],
      ),
    );
  }

  Widget getDocmessage(BuildContext context, String message,
      {bool saved = false}) {
    return SizedBox(
      width: 220,
      height: 116,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.all(4),
            isThreeLine: false,
            leading: Container(
              decoration: BoxDecoration(
                color: Colors.cyan[700],
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.attach_file_rounded,
                size: 25,
                color: Colors.white,
              ),
            ),
            title: Text(
              message.split('-BREAK-')[1],
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
          ),
          Divider(
            height: 3,
          ),
          FlatButton(
              onPressed: () async {
                await downloadFile(
                  context: _scaffold.currentContext,
                  fileName: message.split('-BREAK-')[1],
                  isonlyview: false,
                  keyloader: _keyLoader,
                  uri: message.split('-BREAK-')[0],
                );
              },
              child: Text('DOWNLOAD',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.blue[400])))
        ],
      ),
    );
  }

  Widget getVideoMessage(BuildContext context, String message,
      {bool saved = false}) {
    Map<dynamic, dynamic> meta =
        jsonDecode((message.split('-BREAK-')[2]).toString());
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => new PreviewVideo(
                      id: null,
                      videourl: message.split('-BREAK-')[0],
                      aspectratio: meta["width"] / meta["height"],
                    )));
      },
      child: Container(
        color: Colors.blueGrey,
        height: 197,
        width: 197,
        child: Stack(
          children: [
            CachedNetworkImage(
              placeholder: (context, url) => Container(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(fiberchatBlue),
                ),
                width: 197,
                height: 197,
                padding: EdgeInsets.all(80.0),
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.all(
                    Radius.circular(0.0),
                  ),
                ),
              ),
              errorWidget: (context, str, error) => Material(
                child: Image.asset(
                  'assets/img_not_available.jpeg',
                  width: 197,
                  height: 197,
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(0.0),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              imageUrl: message.split('-BREAK-')[1],
              width: 197,
              height: 197,
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(0.4),
              height: 197,
              width: 197,
            ),
            Center(
              child: Icon(Icons.play_circle_fill_outlined,
                  color: Colors.white70, size: 65),
            ),
          ],
        ),
      ),
    );
  }

  Widget getContactMessage(BuildContext context, String message,
      {bool saved = false}) {
    return SizedBox(
      width: 250,
      height: 130,
      child: Column(
        children: [
          ListTile(
            isThreeLine: false,
            leading: customCircleAvatar(url: null),
            title: Text(
              message.split('-BREAK-')[0],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue[400]),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                message.split('-BREAK-')[1],
                style: TextStyle(
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
            ),
          ),
          Divider(
            height: 7,
          ),
          FlatButton(
              onPressed: () {
                // Fiberchat.toast('Please wait... Loading !');
                FirebaseFirestore.instance
                    .collection(USERS)
                    .doc(message.split('-BREAK-')[1])
                    .get()
                    .then((user) {
                  if (user.exists) {
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
                  } else {
                    Fiberchat.toast('User has not joined $Appname yet.');
                  }
                });
              },
              child: Text('MESSAGE',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.blue[400])))
        ],
      ),
    );
  }

  Widget getImageMessage(Map<String, dynamic> doc, {bool saved = false}) {
    return Container(
      child: saved
          ? Material(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                      image: Save.getImageFromBase64(doc[CONTENT]).image,
                      fit: BoxFit.cover),
                ),
                width: 200.0,
                height: 200.0,
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(8.0),
              ),
              clipBehavior: Clip.hardEdge,
            )
          : CachedNetworkImage(
              placeholder: (context, url) => Container(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(fiberchatBlue),
                ),
                width: 200.0,
                height: 200.0,
                padding: EdgeInsets.all(80.0),
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.all(
                    Radius.circular(8.0),
                  ),
                ),
              ),
              errorWidget: (context, str, error) => Material(
                child: Image.asset(
                  'assets/img_not_available.jpeg',
                  width: 200.0,
                  height: 200.0,
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(8.0),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              imageUrl: doc[CONTENT],
              width: 200.0,
              height: 200.0,
              fit: BoxFit.cover,
            ),
    );
  }

  Widget getTempImageMessage({String url}) {
    return imageFile != null
        ? Container(
            child: Image.file(
              imageFile,
              width: 200.0,
              height: 200.0,
              fit: BoxFit.cover,
            ),
          )
        : getImageMessage({CONTENT: url});
  }

  Widget buildMessage(BuildContext context, Map<String, dynamic> doc,
      {bool saved = false, List<Message> savedMsgs}) {
    final bool isMe = doc[FROM] == currentUserNo;
    bool isContinuing;
    if (savedMsgs == null)
      isContinuing =
          messages.isNotEmpty ? messages.last.from == doc[FROM] : false;
    else {
      isContinuing =
          savedMsgs.isNotEmpty ? savedMsgs.last.from == doc[FROM] : false;
    }
    return SeenProvider(
        timestamp: doc[TIMESTAMP].toString(),
        data: seenState,
        child: Bubble(
            messagetype: doc[TYPE] == MessageType.text.index
                ? MessageType.text
                : doc[TYPE] == MessageType.contact.index
                    ? MessageType.contact
                    : doc[TYPE] == MessageType.location.index
                        ? MessageType.location
                        : doc[TYPE] == MessageType.image.index
                            ? MessageType.image
                            : doc[TYPE] == MessageType.video.index
                                ? MessageType.video
                                : doc[TYPE] == MessageType.doc.index
                                    ? MessageType.doc
                                    : MessageType.text,
            child: doc[TYPE] == MessageType.text.index
                ? getTextMessage(isMe, doc, saved)
                : doc[TYPE] == MessageType.location.index
                    ? getLocationMessage(doc[CONTENT], saved: false)
                    : doc[TYPE] == MessageType.doc.index
                        ? getDocmessage(context, doc[CONTENT], saved: false)
                        : doc[TYPE] == MessageType.audio.index
                            ? getAudiomessage(context, doc[CONTENT],
                                saved: false)
                            : doc[TYPE] == MessageType.video.index
                                ? getVideoMessage(context, doc[CONTENT],
                                    saved: false)
                                : doc[TYPE] == MessageType.contact.index
                                    ? getContactMessage(context, doc[CONTENT],
                                        saved: false)
                                    : getImageMessage(
                                        doc,
                                        saved: saved,
                                      ),
            isMe: isMe,
            timestamp: doc[TIMESTAMP],
            delivered: _cachedModel.getMessageStatus(peerNo, doc[TIMESTAMP]),
            isContinuing: isContinuing));
  }

  Widget buildTempMessage(
      BuildContext context, MessageType type, content, timestamp, delivered) {
    final bool isMe = true;
    return SeenProvider(
        timestamp: timestamp.toString(),
        data: seenState,
        child: Bubble(
          messagetype: type,
          child: type == MessageType.text
              ? getTempTextMessage(content)
              : type == MessageType.location
                  ? getLocationMessage(content, saved: false)
                  : type == MessageType.doc
                      ? getDocmessage(context, content, saved: false)
                      : type == MessageType.audio
                          ? getAudiomessage(context, content, saved: false)
                          : type == MessageType.video
                              ? getVideoMessage(context, content, saved: false)
                              : type == MessageType.contact
                                  ? getContactMessage(context, content,
                                      saved: false)
                                  : getTempImageMessage(url: content),
          isMe: isMe,
          timestamp: timestamp,
          delivered: delivered,
          isContinuing:
              messages.isNotEmpty && messages.last.from == currentUserNo,
        ));
  }

  Widget buildLoading() {
    return Positioned(
      child: isLoading
          ? Container(
              child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(fiberchatBlue)),
              ),
              color: fiberchatBlack.withOpacity(0.8),
            )
          : Container(),
    );
  }

  shareMedia(BuildContext context) {
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        builder: (BuildContext context) {
          // return your layout
          return Container(
            padding: EdgeInsets.all(12),
            height: 250,
            child: Column(children: [
              SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(
                    child: Column(
                      children: [
                        RawMaterialButton(
                          disabledElevation: 0,
                          onPressed: () {
                            hidekeyboard(context);
                            Navigator.of(context).pop();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => HybridDocumentPicker(
                                          title: 'Pick a Document',
                                          callback: getImage,
                                        ))).then((url) async {
                              if (url != null) {
                                Fiberchat.toast(
                                    'Sending Document... Please wait for few seconds !');

                                onSendMessage(
                                    this.context,
                                    url +
                                        '-BREAK-' +
                                        basename(imageFile.path).toString(),
                                    MessageType.doc,
                                    uploadTimestamp);
                                Fiberchat.toast('Document Sent !');
                              } else {
                                Fiberchat.toast('Document not Sent!');
                              }
                            });
                          },
                          elevation: .5,
                          fillColor: Colors.indigo,
                          child: Icon(
                            Icons.file_copy,
                            size: 25.0,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(15.0),
                          shape: CircleBorder(),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Document',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Column(
                      children: [
                        RawMaterialButton(
                          disabledElevation: 0,
                          onPressed: () {
                            hidekeyboard(context);
                            Navigator.of(context).pop();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => HybridVideoPicker(
                                          title: 'Pick a Video',
                                          callback: getImage,
                                        ))).then((url) async {
                              if (url != null) {
                                Fiberchat.toast(
                                    'Sending Video... Please wait for few seconds !');
                                String thumbnailurl = await getThumbnail(url);
                                onSendMessage(
                                    context,
                                    url +
                                        '-BREAK-' +
                                        thumbnailurl +
                                        '-BREAK-' +
                                        videometadata,
                                    MessageType.video,
                                    thumnailtimestamp);
                                Fiberchat.toast('Video Sent !');
                              } else {
                                Fiberchat.toast('Video not Sent!');
                              }
                            });
                          },
                          elevation: .5,
                          fillColor: Colors.pink[600],
                          child: Icon(
                            Icons.video_collection_sharp,
                            size: 25.0,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(15.0),
                          shape: CircleBorder(),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Video',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Column(
                      children: [
                        RawMaterialButton(
                          disabledElevation: 0,
                          onPressed: () {
                            hidekeyboard(context);
                            Navigator.of(context).pop();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => HybridImagePicker(
                                          title: 'Pick an image',
                                          callback: getImage,
                                        ))).then((url) {
                              if (url != null) {
                                onSendMessage(context, url, MessageType.image,
                                    uploadTimestamp);
                              } else {
                                Fiberchat.toast('Image Not Sent');
                              }
                            });
                          },
                          elevation: .5,
                          fillColor: Colors.purple,
                          child: Icon(
                            Icons.image_rounded,
                            size: 25.0,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(15.0),
                          shape: CircleBorder(),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Image',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14),
                        )
                      ],
                    ),
                  )
                ],
              ),
              SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(
                    child: Column(
                      children: [
                        RawMaterialButton(
                          disabledElevation: 0,
                          onPressed: () {
                            hidekeyboard(context);

                            Navigator.of(context).pop();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AudioRecord(
                                          title: 'Record Audio',
                                          callback: getImage,
                                        ))).then((url) {
                              if (url != null) {
                                onSendMessage(
                                    context,
                                    url +
                                        '-BREAK-' +
                                        uploadTimestamp.toString(),
                                    MessageType.audio,
                                    uploadTimestamp);
                              } else {
                                Fiberchat.toast('Recording Not Sent!');
                              }
                            });
                          },
                          elevation: .5,
                          fillColor: Colors.yellow[900],
                          child: Icon(
                            Icons.mic_rounded,
                            size: 25.0,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(15.0),
                          shape: CircleBorder(),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Audio',
                          style: TextStyle(color: Colors.grey[700]),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Column(
                      children: [
                        RawMaterialButton(
                          disabledElevation: 0,
                          onPressed: () async {
                            hidekeyboard(context);
                            Navigator.of(context).pop();
                            await _determinePosition().then(
                              (location) async {
                                Fiberchat.toast('Location Sent Successfuly !');

                                print(location.latitude.toString());
                                print(location.longitude.toString());
                                var locationstring =
                                    'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
                                onSendMessage(
                                    context,
                                    locationstring,
                                    MessageType.location,
                                    DateTime.now().millisecondsSinceEpoch);
                                setState(() {});
                              },
                            );
                          },
                          elevation: .5,
                          fillColor: Colors.cyan[700],
                          child: Icon(
                            Icons.location_on,
                            size: 25.0,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(15.0),
                          shape: CircleBorder(),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Location',
                          style: TextStyle(color: Colors.grey[700]),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Column(
                      children: [
                        RawMaterialButton(
                          disabledElevation: 0,
                          onPressed: () async {
                            hidekeyboard(context);
                            Navigator.of(context).pop();
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ContactsSelect(
                                        currentUserNo: widget.currentUserNo,
                                        model: widget.model,
                                        biometricEnabled: false,
                                        prefs: prefs,
                                        onSelect: (name, phone) {
                                          onSendMessage(
                                              context,
                                              '$name-BREAK-$phone',
                                              MessageType.contact,
                                              DateTime.now()
                                                  .millisecondsSinceEpoch);
                                        })));
                          },
                          elevation: .5,
                          fillColor: Colors.blue[800],
                          child: Icon(
                            Icons.person,
                            size: 25.0,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(15.0),
                          shape: CircleBorder(),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Contact',
                          style: TextStyle(color: Colors.grey[700]),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ]),
          );
        });
  }

  Widget buildInput(
    BuildContext context,
  ) {
    if (chatStatus == ChatStatus.requested.index) {
      return AlertDialog(
        backgroundColor: Colors.white,
        elevation: 10.0,
        title: Text(
          'Accept ${peer[NICKNAME]}\'s invitation?',
          style: TextStyle(color: fiberchatBlack),
        ),
        actions: <Widget>[
          FlatButton(
              child: Text('Reject'),
              onPressed: () {
                ChatController.block(currentUserNo, peerNo);
                setState(() {
                  chatStatus = ChatStatus.blocked.index;
                });
              }),
          FlatButton(
              child: Text('Accept'),
              onPressed: () {
                ChatController.accept(currentUserNo, peerNo);
                setState(() {
                  chatStatus = ChatStatus.accepted.index;
                });
              })
        ],
      );
    }
    return Container(
      margin: EdgeInsets.only(bottom: Platform.isIOS == true ? 20 : 0),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: 10,
              ),
              decoration: BoxDecoration(
                  color: fiberchatWhite,
                  // border: Border.all(
                  //   color: Colors.red[500],
                  // ),
                  borderRadius: BorderRadius.all(Radius.circular(30))),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        IconButton(
                            color: fiberchatWhite,
                            padding: EdgeInsets.all(0.0),
                            icon: Icon(
                              Icons.gif,
                              size: 40,
                              color: fiberchatGrey,
                            ),
                            onPressed: () async {
                              final gif = await GiphyPicker.pickGif(
                                  context: context, apiKey: GiphyAPIKey);
                              onSendMessage(
                                  context,
                                  gif.images.original.url,
                                  MessageType.image,
                                  DateTime.now().millisecondsSinceEpoch);
                            }),
                        IconButton(
                          icon: new Icon(
                            Icons.attachment_outlined,
                            color: fiberchatGrey,
                          ),
                          padding: EdgeInsets.all(0.0),
                          onPressed: chatStatus == ChatStatus.blocked.index
                              ? () {
                                  Fiberchat.toast(
                                      'Unblock chat to Share Media');
                                }
                              : () {
                                  hidekeyboard(context);
                                  shareMedia(context);
                                },
                          color: fiberchatWhite,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: TextField(
                      maxLines: null,
                      style: TextStyle(fontSize: 18.0, color: fiberchatBlack),
                      controller: textEditingController,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          // width: 0.0 produces a thin "hairline" border
                          borderRadius: BorderRadius.circular(1),
                          borderSide:
                              BorderSide(color: Colors.transparent, width: 1.5),
                        ),
                        hoverColor: Colors.transparent,
                        focusedBorder: OutlineInputBorder(
                          // width: 0.0 produces a thin "hairline" border
                          borderRadius: BorderRadius.circular(1),
                          borderSide:
                              BorderSide(color: Colors.transparent, width: 1.5),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(1),
                            borderSide: BorderSide(color: Colors.transparent)),
                        contentPadding: EdgeInsets.fromLTRB(7, 4, 7, 4),
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Button send message
          Container(
            height: 47,
            width: 47,
            // alignment: Alignment.center,
            margin: EdgeInsets.only(left: 6, right: 10),
            decoration: BoxDecoration(
                color: fiberchatgreen,
                // border: Border.all(
                //   color: Colors.red[500],
                // ),
                borderRadius: BorderRadius.all(Radius.circular(30))),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: IconButton(
                icon: new Icon(
                  Icons.send,
                  color: fiberchatWhite.withOpacity(0.9),
                ),
                onPressed: chatStatus == ChatStatus.blocked.index
                    ? null
                    : () => onSendMessage(
                        context,
                        textEditingController.text,
                        MessageType.text,
                        DateTime.now().millisecondsSinceEpoch),
                color: fiberchatWhite,
              ),
            ),
          ),
        ],
      ),
      width: double.infinity,
      height: 60.0,
      decoration: new BoxDecoration(
        // border: new Border(top: new BorderSide(color: Colors.grey, width: 0.5)),
        color: Colors.transparent,
      ),
    );
  }

  bool empty = true;

  loadMessagesAndListen(
    BuildContext context,
  ) async {
    await FirebaseFirestore.instance
        .collection(MESSAGES)
        .doc(chatId)
        .collection(chatId)
        .orderBy(TIMESTAMP)
        .get()
        .then((docs) {
      if (docs.docs.isNotEmpty) empty = false;
      docs.docs.forEach((doc) {
        Map<String, dynamic> _doc = Map.from(doc.data());
        int ts = _doc[TIMESTAMP];
        _doc[CONTENT] = decryptWithCRC(_doc[CONTENT]);
        messages.add(Message(buildMessage(context, _doc),
            onDismiss: _doc[FROM] == peerNo ? () => deleteUpto(ts) : null,
            onTap: _doc[TYPE] == MessageType.image.index
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoViewWrapper(
                        message: _doc[CONTENT],
                        tag: ts.toString(),
                        imageProvider:
                            CachedNetworkImageProvider(_doc[CONTENT]),
                      ),
                    ))
                : null, onDoubleTap: () {
          save(_doc);
        }, onLongPress: () {
          contextMenu(context, _doc);
        }, from: _doc[FROM], timestamp: ts));
      });
      if (mounted) {
        setState(() {
          messages = List.from(messages);
        });
      }
      msgSubscription = FirebaseFirestore.instance
          .collection(MESSAGES)
          .doc(chatId)
          .collection(chatId)
          .where(FROM, isEqualTo: peerNo)
          .snapshots()
          .listen((query) {
        if (empty == true || query.docs.length != query.docChanges.length) {
          query.docChanges.where((doc) {
            return doc.oldIndex <= doc.newIndex;
          }).forEach((change) {
            Map<String, dynamic> _doc = Map.from(change.doc.data());
            int ts = _doc[TIMESTAMP];
            _doc[CONTENT] = decryptWithCRC(_doc[CONTENT]);
            messages.add(Message(buildMessage(context, _doc),
                onLongPress: () {
                  contextMenu(context, _doc);
                },
                onTap: _doc[TYPE] == MessageType.image.index
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhotoViewWrapper(
                            tag: ts.toString(),
                            imageProvider:
                                CachedNetworkImageProvider(_doc[CONTENT]),
                          ),
                        ))
                    : null,
                onDoubleTap: () {
                  save(_doc);
                },
                from: _doc[FROM],
                timestamp: ts,
                onDismiss: () => deleteUpto(ts)));
          });
          if (mounted) {
            setState(() {
              messages = List.from(messages);
            });
          }
        }
      });
    });
  }

  void loadSavedMessages() {
    if (_savedMessageDocs.isEmpty) {
      Save.getSavedMessages(peerNo).then((_msgDocs) {
        if (_msgDocs != null) {
          setState(() {
            _savedMessageDocs = _msgDocs;
          });
        }
      });
    }
  }

  List<Widget> sortAndGroupSavedMessages(
      BuildContext context, List<Map<String, dynamic>> _msgs) {
    _msgs.sort((a, b) => a[TIMESTAMP] - b[TIMESTAMP]);
    List<Message> _savedMessages = new List<Message>();
    List<Widget> _groupedSavedMessages = new List<Widget>();
    _msgs.forEach((msg) {
      _savedMessages.add(Message(
          buildMessage(context, msg, saved: true, savedMsgs: _savedMessages),
          saved: true,
          from: msg[FROM],
          onDoubleTap: () {}, onLongPress: () {
        contextMenu(context, msg, saved: true);
      },
          onDismiss: null,
          onTap: msg[TYPE] == MessageType.image.index
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhotoViewWrapper(
                      tag: "saved_" + msg[TIMESTAMP].toString(),
                      imageProvider: msg[CONTENT].toString().startsWith(
                              'http') // See if it is an online or saved
                          ? CachedNetworkImageProvider(msg[CONTENT])
                          : Save.getImageFromBase64(msg[CONTENT]).image,
                    ),
                  ))
              : null,
          timestamp: msg[TIMESTAMP]));
    });

    _groupedSavedMessages
        .add(Center(child: Chip(label: Text('Saved Conversations'))));

    groupBy<Message, String>(_savedMessages, (msg) {
      return getWhen(DateTime.fromMillisecondsSinceEpoch(msg.timestamp));
    }).forEach((when, _actualMessages) {
      _groupedSavedMessages.add(Center(
          child: Chip(
        label: Text(
          when,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      )));
      _actualMessages.forEach((msg) {
        _groupedSavedMessages.add(msg.child);
      });
    });
    return _groupedSavedMessages;
  }

//-- GROUP BY DATE ---
  List<Widget> getGroupedMessages() {
    List<Widget> _groupedMessages = new List<Widget>();
    int count = 0;
    groupBy<Message, String>(messages, (msg) {
      return getWhen(DateTime.fromMillisecondsSinceEpoch(msg.timestamp));
    }).forEach((when, _actualMessages) {
      _groupedMessages.add(Center(
          child: Chip(
        backgroundColor: Colors.blue[50],
        label: Text(
          when,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      )));
      _actualMessages.forEach((msg) {
        count++;
        if (unread != 0 && (messages.length - count) == unread - 1) {
          _groupedMessages.add(Center(
              child: Chip(
            backgroundColor: Colors.blueGrey[50],
            label: Text('$unread unread messages'),
          )));
          unread = 0; // reset
        }
        _groupedMessages.add(msg.child);
      });
    });
    return _groupedMessages.reversed.toList();
  }

  Widget buildSavedMessages(
    BuildContext context,
  ) {
    return Flexible(
        child: ListView(
      padding: EdgeInsets.all(10.0),
      children: _savedMessageDocs.isEmpty
          ? [
              Padding(
                  padding: EdgeInsets.only(top: 200.0),
                  child: Text('No saved messages.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey, fontSize: 18)))
            ]
          : sortAndGroupSavedMessages(context, _savedMessageDocs),
      controller: saved,
    ));
  }

  Widget buildMessages(
    BuildContext context,
  ) {
    if (chatStatus == ChatStatus.blocked.index) {
      return AlertDialog(
        backgroundColor: Colors.white,
        elevation: 10.0,
        title: Text(
          'Unblock ${peer[NICKNAME]}?',
          style: TextStyle(color: fiberchatBlack),
        ),
        actions: <Widget>[
          FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              }),
          FlatButton(
              child: Text('Unblock'),
              onPressed: () {
                ChatController.accept(currentUserNo, peerNo);
                setState(() {
                  chatStatus = ChatStatus.accepted.index;
                });
              })
        ],
      );
    }
    return Flexible(
        child: chatId == '' || messages.isEmpty || sharedSecret == null
            ? ListView(
                children: <Widget>[
                  Padding(
                      padding: EdgeInsets.only(top: 200.0),
                      child: sharedSecret == null
                          ? Center(
                              child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      fiberchatLightGreen)),
                            )
                          : Text('Say Hi!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: fiberchatWhite, fontSize: 18))),
                ],
                controller: realtime,
              )
            : ListView(
                padding: EdgeInsets.all(10.0),
                children: getGroupedMessages(),
                controller: realtime,
                reverse: true,
              ));
  }

  getWhen(date) {
    DateTime now = DateTime.now();
    String when;
    if (date.day == now.day)
      when = 'Today';
    else if (date.day == now.subtract(Duration(days: 1)).day)
      when = 'Yesterday';
    else
      when = DateFormat.MMMd().format(date);
    return when;
  }

  getPeerStatus(val) {
    if (val is bool && val == true) {
      return 'online';
    } else if (val is int) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(val);
      String at = DateFormat.jm().format(date), when = getWhen(date);
      return 'last seen $when at $at';
    } else if (val is String) {
      if (val == currentUserNo) return 'typing…';
      return 'online';
    }
    return 'loading…';
  }

  bool isBlocked() {
    return chatStatus == ChatStatus.blocked.index ?? true;
  }

  call(BuildContext context, bool isvideocall) async {
    prefs = await SharedPreferences.getInstance();
    var mynickname = prefs.getString(NICKNAME) ?? '';

    var myphotoUrl = prefs.getString(PHOTO_URL) ?? '';

    CallUtils.dial(
        currentuseruid: widget.currentUserNo,
        fromDp: myphotoUrl,
        toDp: peer["photoUrl"],
        fromUID: widget.currentUserNo,
        fromFullname: mynickname,
        toUID: widget.peerNo,
        toFullname: peer["nickname"],
        context: context,
        isvideocall: isvideocall);
  }

  @override
  Widget build(BuildContext context) {
    return PickupLayout(
      scaffold: Fiberchat.getNTPWrappedWidget(WillPopScope(
          onWillPop: () async {
            setLastSeen();
            if (lastSeen == peerNo)
              await FirebaseFirestore.instance
                  .collection(USERS)
                  .doc(currentUserNo)
                  .set({LAST_SEEN: true}, SetOptions(merge: true));
            return Future.value(true);
          },
          child: ScopedModel<DataModel>(
              model: _cachedModel,
              child: ScopedModelDescendant<DataModel>(
                  builder: (context, child, _model) {
                _cachedModel = _model;
                updateLocalUserData(_model);
                return peer != null
                    ? Scaffold(
                        key: _scaffold,
                        backgroundColor: fiberchatGrey,
                        appBar: AppBar(
                          titleSpacing: -10,
                          backgroundColor: fiberchatDeepGreen,
                          title: InkWell(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                      opaque: false,
                                      pageBuilder: (context, a1, a2) =>
                                          ProfileView(peer)));
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 5, 0, 5),
                                  child: Fiberchat.avatar(peer),
                                ),
                                SizedBox(
                                  width: 7,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Fiberchat.getNickname(peer),
                                      style: TextStyle(
                                          color: fiberchatWhite,
                                          fontSize: 17.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(
                                      height: 6,
                                    ),
                                    chatId.isNotEmpty
                                        ? Text(
                                            getPeerStatus(peer[LAST_SEEN]),
                                            style: TextStyle(
                                                color: fiberchatWhite,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400),
                                          )
                                        : Text(
                                            'loading…',
                                            style: TextStyle(
                                                color: fiberchatWhite,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            SizedBox(
                              width: 35,
                              child: IconButton(
                                  icon: Icon(
                                    Icons.video_call,
                                  ),
                                  onPressed: () async {
                                    await Permissions
                                            .cameraAndMicrophonePermissionsGranted()
                                        .then((isgranted) {
                                      if (isgranted == true) {
                                        call(context, true);
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
                                  }),
                            ),
                            SizedBox(
                              width: 55,
                              child: IconButton(
                                  icon: Icon(
                                    Icons.phone,
                                  ),
                                  onPressed: () async {
                                    await Permissions
                                            .cameraAndMicrophonePermissionsGranted()
                                        .then((isgranted) {
                                      if (isgranted == true) {
                                        call(context, false);
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
                                  }),
                            ),
                            SizedBox(
                              width: 25,
                              child: PopupMenuButton(
                                padding: EdgeInsets.all(0),
                                icon: Padding(
                                  padding: const EdgeInsets.only(right: 0),
                                  child: Icon(Icons.more_vert_outlined,
                                      color: fiberchatWhite),
                                ),
                                color: fiberchatWhite,
                                onSelected: (val) {
                                  switch (val) {
                                    case 'hide':
                                      ChatController.hideChat(
                                          currentUserNo, peerNo);
                                      break;
                                    case 'unhide':
                                      ChatController.unhideChat(
                                          currentUserNo, peerNo);
                                      break;
                                    case 'lock':
                                      ChatController.lockChat(
                                          currentUserNo, peerNo);
                                      break;
                                    case 'unlock':
                                      ChatController.unlockChat(
                                          currentUserNo, peerNo);
                                      break;
                                    case 'block':
                                      ChatController.block(
                                          currentUserNo, peerNo);
                                      break;
                                    case 'unblock':
                                      ChatController.accept(
                                          currentUserNo, peerNo);
                                      Fiberchat.toast('Unblocked.');
                                      break;
                                    case 'tutorial':
                                      Fiberchat.toast(
                                          'Drag your friend\'s message from left to right to end conversations up until that message.');
                                      Future.delayed(Duration(seconds: 2))
                                          .then((_) {
                                        Fiberchat.toast(
                                            'Swipe left on the screen to view saved messages.');
                                      });
                                      break;
                                    case 'remove_wallpaper':
                                      _cachedModel.removeWallpaper(peerNo);
                                      Fiberchat.toast('Wallpaper removed.');
                                      break;
                                    case 'set_wallpaper':
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  HybridImagePicker(
                                                    title: 'Pick an image',
                                                    callback: getWallpaper,
                                                  )));
                                      break;
                                  }
                                },
                                itemBuilder: (context) =>
                                    <PopupMenuItem<String>>[
                                  PopupMenuItem<String>(
                                    value: hidden ? 'unhide' : 'hide',
                                    child: Text(
                                      '${hidden ? 'Unhide' : 'Hide'} Chat',
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: locked ? 'unlock' : 'lock',
                                    child: Text(
                                        '${locked ? 'Unlock' : 'Lock'} Chat'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: isBlocked() ? 'unblock' : 'block',
                                    child: Text(
                                        '${isBlocked() ? 'Unblock' : 'Block'} Chat'),
                                  ),
                                  PopupMenuItem<String>(
                                      value: 'set_wallpaper',
                                      child: Text('Set Wallpaper')),
                                  peer[WALLPAPER] != null
                                      ? PopupMenuItem<String>(
                                          value: 'remove_wallpaper',
                                          child: Text('Remove Wallpaper'))
                                      : null,
                                  PopupMenuItem<String>(
                                    child: Text('Show Tutorial'),
                                    value: 'tutorial',
                                  )
                                ].where((o) => o != null).toList(),
                              ),
                            ),
                          ],
                        ),
                        body: Stack(
                          children: <Widget>[
                            new Container(
                              decoration: new BoxDecoration(
                                image: new DecorationImage(
                                    image: peer[WALLPAPER] == null
                                        ? AssetImage(
                                            "assets/images/background.png")
                                        : Image.file(File(peer[WALLPAPER]))
                                            .image,
                                    fit: BoxFit.cover),
                              ),
                            ),
                            PageView(
                              children: <Widget>[
                                Column(
                                  children: [
                                    // List of messages
                                    buildMessages(context),
                                    // Input content
                                    isBlocked()
                                        ? Container()
                                        : buildInput(context),
                                  ],
                                ),
                                Column(
                                  children: [
                                    // List of saved messages
                                    buildSavedMessages(context)
                                  ],
                                ),
                              ],
                            ),

                            // Loading
                            buildLoading()
                          ],
                        ))
                    : Container();
              })))),
    );
  }
}
