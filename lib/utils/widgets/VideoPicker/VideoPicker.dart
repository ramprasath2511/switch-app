import 'dart:io';

import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class HybridVideoPicker extends StatefulWidget {
  final String title;
  final Function callback;
  HybridVideoPicker({@required this.callback, @required this.title});
  @override
  _HybridVideoPickerState createState() => _HybridVideoPickerState();
}

class _HybridVideoPickerState extends State<HybridVideoPicker> {
  // File _image;
  // File _cameraImage;
  File _video;
  // File _video;

  ImagePicker picker = ImagePicker();

  VideoPlayerController _videoPlayerController;
  // VideoPlayerController _videoPlayerController;

  // // This funcion will helps you to pick and Image from Gallery
  // _pickImageFromGallery() async {
  //   PickedFile pickedFile =
  //       await picker.getImage(source: ImageSource.gallery, imageQuality: 50);

  //   File image = File(pickedFile.path);

  //   setState(() {
  //     _image = image;
  //   });
  // }

  // // This funcion will helps you to pick and Image from Camera
  // _pickImageFromCamera() async {
  //   PickedFile pickedFile =
  //       await picker.getImage(source: ImageSource.camera, imageQuality: 50);

  //   File image = File(pickedFile.path);

  //   setState(() {
  //     _cameraImage = image;
  //   });
  // }

  // This funcion will helps you to pick a Video File
  _pickVideo() async {
    PickedFile pickedFile = await picker.getVideo(source: ImageSource.gallery);

    _video = File(pickedFile.path);

    _videoPlayerController = VideoPlayerController.file(_video)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      });
  }

  // This funcion will helps you to pick a Video File from Camera
  _pickVideoFromCamera() async {
    PickedFile pickedFile = await picker.getVideo(source: ImageSource.camera);

    _video = File(pickedFile.path);

    _videoPlayerController = VideoPlayerController.file(_video)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      });
  }

  _buildVideo(BuildContext context) {
    if (_video != null)
      return _videoPlayerController.value.initialized
          ? AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController),
            )
          : Container();
  }

  Widget _buildButtons() {
    return new ConstrainedBox(
        constraints: BoxConstraints.expand(height: 60.0),
        child: new Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildActionButton(new Key('retake'), Icons.photo_library, () {
                Fiberchat.checkAndRequestPermission(PermissionGroup.storage)
                    .then((res) {
                  if (res) {
                    _pickVideo();
                  } else {
                    Fiberchat.showRationale(
                        'Permission to access gallery needed to select Video.');
                    Navigator.pushReplacement(
                        context,
                        new MaterialPageRoute(
                            builder: (context) => OpenSettings()));
                  }
                });
              }),
              _buildActionButton(new Key('upload'), Icons.photo_camera, () {
                Fiberchat.checkAndRequestPermission(PermissionGroup.camera)
                    .then((res) {
                  if (res) {
                    _pickVideoFromCamera();
                  } else {
                    Fiberchat.showRationale(
                        'Permission to access camera needed to take Video.');
                    Navigator.pushReplacement(
                        context,
                        new MaterialPageRoute(
                            builder: (context) => OpenSettings()));
                  }
                });
              }),
            ]));
  }

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fiberchatBlack,
      appBar: AppBar(
        backgroundColor: fiberchatBlack,
        title: Text(widget.title ?? "Pick a Video"),
        actions: _video != null
            ? <Widget>[
                // IconButton(
                //     icon: Icon(Icons.edit, color: fiberchatWhite),
                //     disabledColor: Colors.transparent,
                //     onPressed: () {
                //       _cropImage();
                //     }),
                IconButton(
                    icon: Icon(Icons.check, color: fiberchatWhite),
                    onPressed: () {
                      _videoPlayerController.pause();

                      setState(() {
                        isLoading = true;
                      });

                      widget.callback(_video).then((imageUrl) {
                        Navigator.pop(context, imageUrl);
                      });
                    }),
                SizedBox(
                  width: 8.0,
                )
              ]
            : [],
      ),
      body: Stack(children: [
        new Column(children: [
          new Expanded(child: new Center(child: _buildVideo(context))),
          _buildButtons()
        ]),
        Positioned(
          child: isLoading
              ? Container(
                  child: Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(fiberchatBlue)),
                  ),
                  color: fiberchatBlack.withOpacity(0.8),
                )
              : Container(),
        )
      ]),
    );
  }

  Widget _buildActionButton(Key key, IconData icon, Function onPressed) {
    return new Expanded(
      child: new RaisedButton(
          key: key,
          child: Icon(icon, size: 30.0),
          shape: new RoundedRectangleBorder(),
          color: fiberchatDeepGreen,
          textColor: fiberchatWhite,
          onPressed: onPressed),
    );
  }
}
