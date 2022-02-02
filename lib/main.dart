import 'dart:core';
import 'dart:io';
// import 'package:admob_flutter/admob_flutter.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/homepage/screens/homepage.dart';
import 'package:fiberchat/integrations/provider/DownloadInfoProvider.dart';
import 'package:fiberchat/integrations/provider/call_history_provider.dart';
import 'package:fiberchat/integrations/provider/user_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  //TODO ADMOB CODE
  // if (IsBannerAdShow == true ||
  //     IsInterstitialAdShow == true ||
  //     IsVideoAdShow == true) Admob.initialize();
  // if (Platform.isIOS == true &&
  //     (IsBannerAdShow == true ||
  //         IsInterstitialAdShow == true ||
  //         IsVideoAdShow == true)) await Admob.requestTrackingAuthorization();

  binding.renderView.automaticSystemUiAdjustment = false;

  await Firebase.initializeApp();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    bool inDebug = false;
    assert(() {
      inDebug = true;
      return true;
    }());
    // In debug mode, use the normal error widget which shows
    // the error message:
    if (inDebug) return ErrorWidget(details.exception);
    // In release builds, show a yellow-on-blue message instead:
    return Container(
      alignment: Alignment.center,
      child: Text(
        'Error! ${details.exception}',
        style: TextStyle(color: Colors.yellow),
        textDirection: TextDirection.ltr,
      ),
    );
  };
  // Here we would normally runApp() the root widget, but to demonstrate
  // the error handling we artificially fail:
  runApp(OverlaySupport(child: FiberchatWrapper()));
}

class FiberchatWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, AsyncSnapshot<SharedPreferences> snapshot) {
          if (snapshot.hasData) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => DownloadInfoprovider()),
                ChangeNotifierProvider(create: (_) => UserProvider()),
                ChangeNotifierProvider(
                    create: (_) => FirestoreDataProviderCALLHISTORY()),
              ],
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: Homepage(
                    currentUserNo: snapshot.data.getString(PHONE),
                    isSecuritySetupDone:
                        snapshot.data.getBool(IS_SECURITY_SETUP_DONE),
                  )),
            );
          }
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => UserProvider()),
            ],
            child: MaterialApp(
                theme: ThemeData(
                  primaryColor: fiberchatgreen,
                  primaryColorLight: fiberchatgreen,
                ),
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Container(
                      child: Center(
                          child: Column(
                    children: [
                      SizedBox(
                        height: 15,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Image.asset(AppLogoPath
                            // width: 200,
                            ),
                      ),
                      SizedBox(
                        height: 0,
                      ),
                    ],
                  ))),
                )),
          );
        });
  }
}
