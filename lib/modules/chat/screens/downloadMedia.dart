import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/integrations/provider/DownloadInfoProvider.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

Future<void> downloadFile(
    {BuildContext context,
    uri,
    fileName,
    bool isonlyview,
    GlobalKey keyloader}) async {
  final downloadinfo =
      Provider.of<DownloadInfoprovider>(context, listen: false);
  Fiberchat.checkAndRequestPermission(PermissionGroup.storage)
      .then((res) async {
    if (res) {
      var knockDir =
          // await new Directory('${dir.path}/classroomnest').create(recursive: true);
          await new Directory('/storage/emulated/0/$Appname')
              .create(recursive: true);
      File outputFile = File('${knockDir.path}/$fileName');
      bool fileExists = await outputFile.exists();
      if (fileExists == true) {
        Fiberchat.toast(
          'File already Exists in $Appname folder.',
        );
      } else {
        // Either the permission was already granted before or the user just granted it.

        // setState(() {
        //   downloading = true;
        // });

        String savePath = '${knockDir.path}/$fileName';
        showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return new WillPopScope(
                  onWillPop: () async => false,
                  child: SimpleDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      // side: BorderSide(width: 5, color: Colors.green)),
                      key: keyloader,
                      backgroundColor: Colors.white,
                      children: <Widget>[
                        Consumer<DownloadInfoprovider>(
                            builder: (context, classroomm, _child) => Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      new CircularPercentIndicator(
                                        radius: 55.0,
                                        lineWidth: 4.0,
                                        percent:
                                            downloadinfo.downloadedpercentage /
                                                100,
                                        center: new Text(
                                            "${downloadinfo.downloadedpercentage.floor()}%"),
                                        progressColor: Colors.green[400],
                                      ),
                                      Container(
                                        width: 180,
                                        padding: EdgeInsets.only(left: 7),
                                        child: ListTile(
                                          dense: false,
                                          title: Text(
                                            'Downloading...',
                                            textAlign: TextAlign.left,
                                            style: TextStyle(
                                                height: 1.3,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text(
                                            '${((((downloadinfo.totalsize / 1024) / 1000) * 100).roundToDouble()) / 100}  MB',
                                            textAlign: TextAlign.left,
                                            style: TextStyle(height: 2.2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                      ]));
            });

        Dio dio = Dio();

        await dio.download(
          uri,
          savePath,
          onReceiveProgress: (rcv, total) {
            downloadinfo.calculatedownloaded(rcv / total * 100, total);
            print(' ${rcv.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}');
          },
          deleteOnError: true,
        ).then((_) async {
          // await PhoneApp.sharedPreferences.setString(fileName, fileName);
          Navigator.of(keyloader.currentContext, rootNavigator: true).pop(); //
          downloadinfo.calculatedownloaded(0.00, 0);
          Fiberchat.toast(
            'File Downloaded in $Appname folder.',
          );

          //  OpenFile.open('${knockDir.path}/$fileName');
        }).catchError((err) {
          print(err.toString());
          Navigator.of(keyloader.currentContext, rootNavigator: true).pop(); //
          Fiberchat.toast(
            'Error Occured While Downloading',
          );
        });
      }
    } else {
      Fiberchat.showRationale(
          'Permission to access Storage needed to download File.');
      Navigator.pushReplacement(
          context, new MaterialPageRoute(builder: (context) => OpenSettings()));
    }
  });
}
