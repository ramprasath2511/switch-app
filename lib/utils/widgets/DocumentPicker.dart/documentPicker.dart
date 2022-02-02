import 'dart:io';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class HybridDocumentPicker extends StatefulWidget {
  HybridDocumentPicker(
      {Key key,
      @required this.title,
      @required this.callback,
      this.profile = false})
      : super(key: key);

  final String title;
  final Function callback;
  final bool profile;

  @override
  _HybridDocumentPickerState createState() => new _HybridDocumentPickerState();
}

class _HybridDocumentPickerState extends State<HybridDocumentPicker> {
  File _docFile;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void captureFile() async {
    try {
      // ignore: deprecated_member_use
      var file = await FilePicker.getFile(
        type: FileType.ANY,
      );
      setState(() {
        _docFile = file;
      });
    } catch (e) {}
  }

  Widget _buildDoc() {
    if (_docFile != null) {
      return new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.file_copy_rounded, size: 100, color: Colors.yellow[800]),
          SizedBox(
            height: 30,
          ),
          Text(basename(_docFile.path).toString(),
              style: new TextStyle(fontSize: 18.0, color: fiberchatWhite)),
        ],
      );
    } else {
      return new Text('Take a File to start',
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
  //     sourcePath: _docFile.path,
  //     // ratioX: x,
  //     // ratioY: y,
  //     // circleShape: widget.profile,
  //     // toolbarColor: Colors.white
  //   );
  //   setState(() {
  //     if (croppedFile != null) _docFile = croppedFile;
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
            actions: _docFile != null
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
                          widget.callback(_docFile).then((imageUrl) {
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
            new Expanded(child: new Center(child: _buildDoc())),
            _buildButtons(context)
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

  Widget _buildButtons(BuildContext context) {
    return new ConstrainedBox(
        constraints: BoxConstraints.expand(height: 60.0),
        child: new Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildActionButton(new Key('retake'), Icons.add, () {
                Fiberchat.checkAndRequestPermission(PermissionGroup.storage)
                    .then((res) {
                  if (res) {
                    captureFile();
                  } else {
                    Fiberchat.showRationale(
                        'Permission to access storage needed to select files.');
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
