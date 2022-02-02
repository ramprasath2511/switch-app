import 'dart:io';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class HybridImagePicker extends StatefulWidget {
  HybridImagePicker(
      {Key key,
      @required this.title,
      @required this.callback,
      this.profile = false})
      : super(key: key);

  final String title;
  final Function callback;
  final bool profile;

  @override
  _HybridImagePickerState createState() => new _HybridImagePickerState();
}

class _HybridImagePickerState extends State<HybridImagePicker> {
  File _imageFile;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void captureImage(ImageSource captureMode) async {
    try {
      // ignore: deprecated_member_use
      var imageFile = await ImagePicker.pickImage(source: captureMode);
      setState(() {
        _imageFile = imageFile;
      });
    } catch (e) {}
  }

  Widget _buildImage() {
    if (_imageFile != null) {
      return new Image.file(_imageFile);
    } else {
      return new Text('Take an image to start',
          style: new TextStyle(fontSize: 18.0, color: fiberchatWhite));
    }
  }

  // Future<Null> _cropImage() async {
  //   double x, y;
  //   if (widget.profile) {
  //     x = 1.0;
  //     y = 1.0;
  //   }
  //   File croppedFile = await ImageCropper.cropImage(
  //     sourcePath: _imageFile.path,
  //     // ratioX: x,
  //     // ratioY: y,
  //     // circleShape: widget.profile,
  //     // toolbarColor: Colors.white
  //   );
  //   setState(() {
  //     if (croppedFile != null) _imageFile = croppedFile;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Fiberchat.getNTPWrappedWidget(WillPopScope(
      child: Scaffold(
        backgroundColor: fiberchatBlack,
        appBar: new AppBar(
            title: new Text(widget.title),
            backgroundColor: fiberchatBlack,
            actions: _imageFile != null
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
                          setState(() {
                            isLoading = true;
                          });
                          widget.callback(_imageFile).then((imageUrl) {
                            Navigator.pop(context, imageUrl);
                          });
                        }),
                    SizedBox(
                      width: 8.0,
                    )
                  ]
                : []),
        body: Stack(children: [
          new Column(children: [
            new Expanded(child: new Center(child: _buildImage())),
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
      ),
      onWillPop: () => Future.value(!isLoading),
    ));
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
                    captureImage(ImageSource.gallery);
                  } else {
                    Fiberchat.showRationale(
                        'Permission to access gallery needed to select photos.');
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
                    captureImage(ImageSource.camera);
                  } else {
                    Fiberchat.showRationale(
                        'Permission to access camera needed to take photos.');
                    Navigator.pushReplacement(
                        context,
                        new MaterialPageRoute(
                            builder: (context) => OpenSettings()));
                  }
                });
              }),
            ]));
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
