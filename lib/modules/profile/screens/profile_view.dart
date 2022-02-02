// import 'package:admob_flutter/admob_flutter.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/Admob/admob.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';

class ProfileView extends StatelessWidget {
  final Map<String, dynamic> user;
  ProfileView(this.user);

  @override
  Widget build(BuildContext context) {
    final _width = MediaQuery.of(context).size.width;
    final _height = MediaQuery.of(context).size.height;
    String name = Fiberchat.getNickname(user), about = user[ABOUT_ME] ?? '';
    return Fiberchat.getNTPWrappedWidget(Scaffold(
        backgroundColor: fiberchatDeepGreen,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: fiberchatDeepGreen,
        ),
        body: Center(
            child: Column(
          children: <Widget>[
            SizedBox(
              height: _height / 29,
            ),
            Fiberchat.avatar(user, radius: 100.0),
            Padding(
              child: new Text(
                name,
                style: new TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _width / 12,
                    color: Colors.white),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 5),
            ),
            Padding(
              child: new Text(
                user[PHONE],
                style: new TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _width / 18,
                    color: Colors.white70),
              ),
              padding: EdgeInsets.fromLTRB(20, 5, 20, 10),
            ),
            new Padding(
              padding: new EdgeInsets.only(top: 0),
              child: new Text(
                about.isEmpty ? 'Hey there! I am using SwitchApp.' : about,
                style: new TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: _width / 22,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            //TODO ADMOB CODE
            // IsBannerAdShow == true
            //     ? Container(
            //         margin: EdgeInsets.only(bottom: 5.0, top: 40),
            //         child: AdmobBanner(
            //           adUnitId: getBannerAdUnitId(),
            //           adSize: AdmobBannerSize.MEDIUM_RECTANGLE,
            //           listener:
            //               (AdmobAdEvent event, Map<String, dynamic> args) {
            //             // handleEvent(event, args, 'Banner');
            //           },
            //           onBannerCreated: (AdmobBannerController controller) {
            //             // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
            //             // Normally you don't need to worry about disposing this yourself, it's handled.
            //             // If you need direct access to dispose, this is your guy!
            //             // controller.dispose();
            //           },
            //         ),
            //       )
            //     : SizedBox(
            //         height: 0,
            //       ),
          ],
        ))));
  }
}
