import 'package:fiberchat/modules/chat/screens/downloadMedia.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/save.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoViewWrapper extends StatelessWidget {
  PhotoViewWrapper(
      {this.imageProvider,
      this.message,
      this.loadingChild,
      this.backgroundDecoration,
      this.minScale,
      this.maxScale,
      @required this.tag});

  final String tag;
  final String message;

  final ImageProvider imageProvider;
  final Widget loadingChild;
  final Decoration backgroundDecoration;
  final dynamic minScale;
  final dynamic maxScale;

  final GlobalKey<ScaffoldState> _scaffoldd = new GlobalKey<ScaffoldState>();
  final GlobalKey<State> _keyLoaderr =
      new GlobalKey<State>(debugLabel: 'qqqesqeqsseaadqeqe');
  @override
  Widget build(BuildContext context) {
    return Fiberchat.getNTPWrappedWidget(Scaffold(
        key: _scaffoldd,
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            Fiberchat.checkAndRequestPermission(PermissionGroup.storage)
                .then((res) async {
              if (res) {
                Save.saveToDisk(imageProvider, tag);
                await downloadFile(
                  context: _scaffoldd.currentContext,
                  fileName: '${DateTime.now().millisecondsSinceEpoch}.png',
                  isonlyview: false,
                  keyloader: _keyLoaderr,
                  uri: message,
                );
                Fiberchat.toast('Saved!');
              } else {
                Fiberchat.showRationale(
                    'Permission to access storage needed to save photos to your phone.');
                Navigator.push(
                    context,
                    new MaterialPageRoute(
                        builder: (context) => OpenSettings()));
              }
            });
          },
          child: Icon(Icons.file_download),
        ),
        body: Container(
            constraints: BoxConstraints.expand(
              height: MediaQuery.of(context).size.height,
            ),
            child: PhotoView(
              imageProvider: imageProvider,
              loadingChild: loadingChild,
              backgroundDecoration: backgroundDecoration,
              minScale: minScale,
              maxScale: maxScale,
              heroTag: tag,
            ))));
  }
}
