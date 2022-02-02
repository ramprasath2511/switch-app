import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberchat/integrations/models/call.dart';
import 'package:fiberchat/integrations/provider/user_provider.dart';
import 'package:fiberchat/integrations/resources/call_methods.dart';
import 'package:fiberchat/integrations/screens/callscreens/pickup/pickup_screen.dart';

class PickupLayout extends StatelessWidget {
  final Widget scaffold;
  final CallMethods callMethods = CallMethods();

  PickupLayout({
    @required this.scaffold,
  });

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    return (userProvider != null && userProvider.getUser != null)
        ? StreamBuilder<DocumentSnapshot>(
            stream: callMethods.callStream(phone: userProvider.getUser.phone),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data.data() != null) {
                Call call = Call.fromMap(snapshot.data.data());

                if (!call.hasDialled) {
                  return PickupScreen(
                    call: call,
                    currentuseruid: userProvider.getUser.phone,
                  );
                }
              }
              return scaffold;
            },
          )
        : Scaffold(
            backgroundColor: fiberchatDeepGreen,
            body: Center(
              child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(fiberchatLightGreen)),
            ));
  }
}
