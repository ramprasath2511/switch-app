import 'dart:async';
import 'dart:ui';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/core/security/screens/security.dart';
import 'package:fiberchat/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_entry_text_field/pin_entry_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fiberchat/utils/widgets/E2EE/e2ee.dart' as e2ee;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title, @required this.issecutitysetupdone})
      : super(key: key);

  final String title;
  final bool issecutitysetupdone;

  @override
  LoginScreenState createState() => new LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;
  final _phoneNo = TextEditingController();
  final _smsCode = TextEditingController();
  final _name = TextEditingController();
  String phoneCode = DEFAULT_COUNTTRYCODE_NUMBER;
  final storage = new FlutterSecureStorage();

  // Country _selected = Country(
  //   asset: "assets/flags/in_flag.png",
  //   dialingCode: "91",
  //   isoCode: "IN",
  //   name: "India",
  // );
  int _currentStep = 0;

  String verificationId;
  bool isLoading = false;
  bool isLoading2 = true;
  bool isverficationsent = false;
  dynamic isLoggedIn = false;
  User currentUser;

  @override
  void initState() {
    super.initState();
  }

  Future<void> verifyPhoneNumber() async {
    final PhoneVerificationCompleted verificationCompleted =
        (AuthCredential phoneAuthCredential) {
      handleSignIn(authCredential: phoneAuthCredential);
    };

    final PhoneVerificationFailed verificationFailed =
        (FirebaseAuthException authException) {
      Fiberchat.reportError(
          '${authException.message} Phone: ${_phoneNo.text} Country Code: $phoneCode ',
          authException.code);
      setState(() {
        isLoading = false;
        isLoading2 = true;
        _currentStep = 0;
        isverficationsent = false;
      });

      Fiberchat.toast(
          'Authentication failed - ${authException.message}. Try again later.');
    };

    final PhoneCodeSent codeSent =
        (String verificationId, [int forceResendingToken]) async {
      setState(() {
        isLoading = false;
        isLoading2 = false;
        isverficationsent = true;
      });

      this.verificationId = verificationId;
    };

    final PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout =
        (String verificationId) {
      setState(() {
        isLoading = false;
        isLoading2 = false;
        isverficationsent = false;
      });

      this.verificationId = verificationId;
    };

    await firebaseAuth.verifyPhoneNumber(
        phoneNumber: (phoneCode + _phoneNo.text).trim(),
        timeout: const Duration(seconds: 30),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout);
  }

  Future<Null> handleSignIn({AuthCredential authCredential}) async {
    prefs = await SharedPreferences.getInstance();
    if (isLoading == false) {
      this.setState(() {
        isLoading = true;
      });
    }

    var phoneNo = (phoneCode + _phoneNo.text).trim();

    AuthCredential credential;
    if (authCredential == null)
      credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _smsCode.text,
      );
    else
      credential = authCredential;
    UserCredential firebaseUser;
    try {
      firebaseUser = await firebaseAuth
          .signInWithCredential(credential)
          .catchError((err) async {
        await Fiberchat.reportError(err, 'signInWithCredential');
        Fiberchat.toast(
            'Make sure your Phone Number/OTP Code is correct and try again later.');
        if (mounted)
          setState(() {
            _currentStep = 0;

            isLoading = false;
            isLoading2 = false;
          });
        return null;
      });
    } catch (e) {
      await Fiberchat.reportError(e, 'signInWithCredential catch block');
      Fiberchat.toast(
          'Make sure your Phone Number/OTP Code is correct and try again later.');
      if (mounted)
        setState(() {
          _currentStep = 0;

          isLoading = false;
          isLoading2 = false;
        });
      return;
    }

    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection(USERS)
          .where(ID, isEqualTo: firebaseUser.user.uid)
          .get();
      final List<DocumentSnapshot> documents = result.docs;
      final pair = await e2ee.X25519().generateKeyPair();

      if (documents.isEmpty) {
        await storage.write(key: PRIVATE_KEY, value: pair.secretKey.toBase64());
        // Update data to server if new user
        await FirebaseFirestore.instance.collection(USERS).doc(phoneNo).set({
          PUBLIC_KEY: pair.publicKey.toBase64(),
          PRIVATE_KEY: pair.secretKey.toBase64(),
          COUNTRY_CODE: phoneCode,
          NICKNAME: _name.text.trim(),
          PHOTO_URL: firebaseUser.user.photoURL,
          ID: firebaseUser.user.uid,
          PHONE: phoneNo,
          AUTHENTICATION_TYPE: AuthenticationType.passcode.index,
          ABOUT_ME: ''
        }, SetOptions(merge: true));

        // Write data to local
        currentUser = firebaseUser.user;
        await prefs.setString(ID, currentUser.uid);
        await prefs.setString(NICKNAME, _name.text.trim());
        await prefs.setString(PHOTO_URL, currentUser.photoURL);
        await prefs.setString(PHONE, phoneNo);
        await prefs.setString(COUNTRY_CODE, phoneCode);
        unawaited(Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    Security(phoneNo, setPasscode: true, onSuccess: () async {
                      unawaited(Navigator.pushReplacement(
                          context,
                          new MaterialPageRoute(
                              builder: (context) => FiberchatWrapper())));
                      Fiberchat.toast('Welcome to $Appname');
                    }))));
        // FiberchatWrapper())));

      } else {
        await storage.write(key: PRIVATE_KEY, value: documents[0][PRIVATE_KEY]);
        // Always set the authentication type to passcode while signing in
        // so they would have to set up fingerprint only after going through
        // passcode first.
        // This prevents using fingerprint of other users as soon as logging in.
        await FirebaseFirestore.instance.collection(USERS).doc(phoneNo).set({
          AUTHENTICATION_TYPE: AuthenticationType.passcode.index,
          // PUBLIC_KEY: pair.publicKey.toBase64()
        }, SetOptions(merge: true));
        // Write data to local
        await prefs.setString(ID, documents[0][ID]);
        await prefs.setString(NICKNAME, documents[0][NICKNAME]);
        await prefs.setString(PHOTO_URL, documents[0][PHOTO_URL]);
        await prefs.setString(ABOUT_ME, documents[0][ABOUT_ME] ?? '');
        await prefs.setString(PHONE, documents[0][PHONE]);
        if (widget.issecutitysetupdone == false ||
            widget.issecutitysetupdone == null) {
          print('SURPASSED');
          unawaited(Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      Security(phoneNo, setPasscode: true, onSuccess: () async {
                        unawaited(Navigator.pushReplacement(
                            context,
                            new MaterialPageRoute(
                                builder: (context) => FiberchatWrapper())));
                      }))));
        } else {
          print('UNDRPASSED');
          unawaited(Navigator.pushReplacement(context,
              new MaterialPageRoute(builder: (context) => FiberchatWrapper())));
          Fiberchat.toast('Welcome back!');
        }
      }
    } else {
      Fiberchat.toast("Failed to log in.");
    }
  }

  customclippath(double w, double h) {
    return ClipPath(
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fiberchatgreen,
                fiberchatDeepGreen,
              ]),
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 40,
            ),
            Text(
              'Welcome to',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 15,
            ),
            Image.asset(
              AppLogoPath,
              width: w / 1.3,
            ),
            SizedBox(
              height: 0,
            ),
          ],
        ),
      ),
    );
  }

  // final _enterNumberFormKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;
    var h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: fiberchatDeepGreen,
      //   // appBar: AppBar(
      //   //   backgroundColor: fiberchatBlack,
      //   //   title: Text(
      //   //     widget.title,
      //   //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      //   //   ),
      //   // ),
      body: SingleChildScrollView(
          child: Column(
        children: <Widget>[
          Stack(
            overflow: Overflow.visible,
            children: <Widget>[
              customclippath(w, h),
              _currentStep == 0
                  ? Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 3.0,
                            color: Colors.white.withOpacity(0.3),
                            spreadRadius: 1.0,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      ),
                      margin: EdgeInsets.fromLTRB(
                          15, MediaQuery.of(context).size.height / 2.3, 16, 0),
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: 13,
                          ),
                          Container(
                            margin: EdgeInsets.only(top: 10),
                            padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                            // height: 63,
                            height: 83,
                            width: w / 1.24,
                            child: InpuTextBox(
                              controller: _name,
                              leftrightmargin: 0,
                              showIconboundary: false,
                              boxcornerradius: 5.5,
                              // padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                              // height: 63,
                              boxheight: 50,
                              hinttext: ' Enter Full name',

                              prefixIconbutton: Icon(
                                Icons.person,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(top: 0),
                            // padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                            // height: 63,
                            height: 63,
                            width: w / 1.24,
                            child: Form(
                              // key: _enterNumberFormKey,
                              child: MobileInputWithOutline(
                                buttonhintTextColor: fiberchatGrey,
                                borderColor: fiberchatGrey.withOpacity(0.2),
                                controller: _phoneNo,
                                initialCountryCode: DEFAULT_COUNTTRYCODE_ISO,
                                onSaved: (phone) {
                                  setState(() {
                                    phoneCode = phone.countryCode;
                                  });
                                  print(phoneCode);
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(17),
                            child: Text(
                              'Send a SMS Code to verify your number',
                              textAlign: TextAlign.center,
                              // style: TextStyle(color: Mycolors.black),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(13, 22, 13, 8),
                            child: isLoading == true
                                ? Center(
                                    child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                fiberchatLightGreen)),
                                  )
                                : MySimpleButton(
                                    buttoncolor:
                                        fiberchatLightGreen.withOpacity(0.99),
                                    buttontext: 'Send Verification Code',
                                    onpressed: () {
                                      RegExp e164 =
                                          new RegExp(r'^\+[1-9]\d{1,14}$');
                                      if (_name.text.trim().isNotEmpty) {
                                        String _phone =
                                            _phoneNo.text.toString().trim();
                                        if (_phone.isNotEmpty &&
                                            e164.hasMatch(phoneCode + _phone)) {
                                          verifyPhoneNumber();
                                          setState(() {
                                            isLoading = true;
                                            _currentStep = 1;
                                          });
                                        } else {
                                          Fiberchat.toast(
                                              'Please enter a valid number.');
                                        }
                                      } else {
                                        Fiberchat.toast(
                                            'Name cannot be empty!');
                                      }
                                    },
                                  ),
                          ),

                          //
                          SizedBox(
                            height: 22,
                          )
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 3.0,
                            color: Colors.white.withOpacity(0.3),
                            spreadRadius: 1.0,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      ),
                      margin: EdgeInsets.fromLTRB(
                          15, MediaQuery.of(context).size.height / 2.3, 16, 0),
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: 13,
                          ),
                          Container(
                            // height: 70,
                            child: Padding(
                              padding: const EdgeInsets.all(11.0),
                              child: PinEntryTextField(
                                showFieldAsBox: true,
                                fields: 6,
                                onSubmit: (String pin) {
                                  _smsCode.text = pin;
                                },
                              ),
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.all(17),
                            child: Text(
                              isverficationsent == false
                                  ? 'Sending SMS Code to $phoneCode-${_phoneNo.text}'
                                  : 'Enter the 6-digit Verification Code sent to $phoneCode-${_phoneNo.text}',
                              textAlign: TextAlign.center,
                              style: TextStyle(height: 1.5),

                              // style: TextStyle(color: Mycolors.black),
                            ),
                          ),
                          isLoading2 == true
                              ? Center(
                                  child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          fiberchatLightGreen)),
                                )
                              : Padding(
                                  padding: EdgeInsets.fromLTRB(13, 22, 13, 8),
                                  child: MySimpleButton(
                                    buttoncolor:
                                        fiberchatLightGreen.withOpacity(0.99),
                                    buttontext: 'Verify OTP',
                                    onpressed: () {
                                      if (_smsCode.text.length == 6) {
                                        setState(() {
                                          isLoading2 = true;
                                        });
                                        handleSignIn();
                                      } else
                                        Fiberchat.toast(
                                            'Please enter the correct OTP Code');
                                    },
                                  ),
                                ),
                          InkWell(
                            onTap: isLoading2 == true
                                ? () {}
                                : () {
                                    setState(() {
                                      isLoading = false;
                                      _currentStep = 0;
                                    });
                                  },
                            child: Padding(
                                padding: EdgeInsets.fromLTRB(13, 22, 13, 8),
                                child: Center(
                                  child: Text(
                                    'BACK',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                )),
                          ),
                          //
                          SizedBox(
                            height: 22,
                          )
                        ],
                      ),
                    )
            ],
          ),
        ],
      )),
    );
  }
}

//___CONSTRUCTORS----

class MySimpleButton extends StatefulWidget {
  final Color buttoncolor;
  final Color buttontextcolor;
  final Color shadowcolor;
  final String buttontext;
  final double width;
  final double height;
  final double spacing;
  final double borderradius;
  final Function onpressed;

  MySimpleButton(
      {this.buttontext,
      this.buttoncolor,
      this.height,
      this.spacing,
      this.borderradius,
      this.width,
      this.buttontextcolor,
      // this.icon,
      this.onpressed,
      // this.forcewidget,
      this.shadowcolor});
  @override
  _MySimpleButtonState createState() => _MySimpleButtonState();
}

class _MySimpleButtonState extends State<MySimpleButton> {
  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    return GestureDetector(
        onTap: widget.onpressed,
        child: Container(
          alignment: Alignment.center,
          width: widget.width ?? w - 40,
          height: widget.height ?? 50,
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(
            widget.buttontext ?? 'SUBMIT',
            style: TextStyle(
              letterSpacing: widget.spacing ?? 2,
              fontSize: 15,
              color: widget.buttontextcolor ?? Colors.white,
            ),
          ),
          decoration: BoxDecoration(
              color: widget.buttoncolor ?? Colors.primaries,
              //gradient: LinearGradient(colors: [bgColor, whiteColor]),
              boxShadow: [
                BoxShadow(
                    color: widget.shadowcolor ?? Colors.transparent,
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
              border: Border.all(
                color: widget.buttoncolor ?? fiberchatgreen,
              ),
              borderRadius:
                  BorderRadius.all(Radius.circular(widget.borderradius ?? 5))),
        ));
  }
}

class MobileInputWithOutline extends StatefulWidget {
  final String initialCountryCode;
  final String hintText;
  final double height;
  final double width;
  final TextEditingController controller;
  final Color borderColor;
  final Color buttonTextColor;
  final Color buttonhintTextColor;
  final TextStyle hintStyle;
  final String buttonText;
  final Function(PhoneNumber phone) onSaved;

  MobileInputWithOutline(
      {this.height,
      this.width,
      this.borderColor,
      this.buttonhintTextColor,
      this.hintStyle,
      this.buttonTextColor,
      this.onSaved,
      this.hintText,
      this.controller,
      this.initialCountryCode,
      this.buttonText});
  @override
  _MobileInputWithOutlineState createState() => _MobileInputWithOutlineState();
}

class _MobileInputWithOutlineState extends State<MobileInputWithOutline> {
  BoxDecoration boxDecoration(
      {double radius = 5,
      Color bgColor = Colors.white,
      var showShadow = false}) {
    return BoxDecoration(
        color: bgColor,
        boxShadow: showShadow
            ? [
                BoxShadow(
                    color: fiberchatgreen, blurRadius: 10, spreadRadius: 2)
              ]
            : [BoxShadow(color: Colors.transparent)],
        border:
            Border.all(color: widget.borderColor ?? Colors.grey, width: 1.5),
        borderRadius: BorderRadius.all(Radius.circular(radius)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: widget.height ?? 50,
          width: widget.width ?? MediaQuery.of(context).size.width,
          decoration: boxDecoration(),
          child: IntlPhoneField(
              dropDownArrowColor:
                  widget.buttonhintTextColor ?? Colors.grey[300],
              textAlign: TextAlign.justify,
              initialCountryCode: widget.initialCountryCode,
              controller: widget.controller,
              style: TextStyle(
                  height: 1.5,
                  letterSpacing: 1,
                  fontSize: 16.0,
                  color: widget.buttonTextColor ?? Colors.black87,
                  fontWeight: FontWeight.bold),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(25, 0, 8, 0),
                  hintText: widget.hintText ?? 'Mobile Number',
                  hintStyle: widget.hintStyle ??
                      TextStyle(
                        letterSpacing: 1,
                        height: 1.5,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: widget.buttonhintTextColor ?? Colors.grey[300],
                      ),
                  fillColor: Colors.white,
                  filled: true,
                  border: new OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(10.0),
                    ),
                    borderSide: BorderSide.none,
                  )),
              onChanged: (phone) {
                widget.onSaved(phone);
              },
              validator: (v) {
                return null;
              },
              onSaved: widget.onSaved),
        ),
        Positioned(
            left: 110,
            child: Container(
              width: 1.5,
              height: widget.height ?? 48,
              color: widget.borderColor ?? Colors.grey,
            ))
      ],
    );
  }
}

class InpuTextBox extends StatefulWidget {
  final Color boxbcgcolor;
  final Color boxbordercolor;
  final double boxcornerradius;
  final double fontsize;
  final double boxwidth;
  final double boxborderwidth;
  final double boxheight;
  final EdgeInsets forcedmargin;
  final double letterspacing;
  final double leftrightmargin;
  final TextEditingController controller;
  final Function(String val) validator;
  final Function(String val) onSaved;
  final Function(String val) onchanged;
  final TextInputType keyboardtype;
  final TextCapitalization textCapitalization;

  final String title;
  final String subtitle;
  final String hinttext;
  final String placeholder;
  final int maxLines;
  final int minLines;
  final int maxcharacters;
  final bool isboldinput;
  final bool obscuretext;
  final bool autovalidate;
  final bool disabled;
  final bool showIconboundary;
  final Widget sufficIconbutton;
  final List<TextInputFormatter> inputFormatter;
  final Widget prefixIconbutton;

  InpuTextBox(
      {this.controller,
      this.boxbordercolor,
      this.boxheight,
      this.fontsize,
      this.leftrightmargin,
      this.letterspacing,
      this.forcedmargin,
      this.boxwidth,
      this.boxcornerradius,
      this.boxbcgcolor,
      this.hinttext,
      this.boxborderwidth,
      this.onSaved,
      this.textCapitalization,
      this.onchanged,
      this.placeholder,
      this.showIconboundary,
      this.subtitle,
      this.disabled,
      this.keyboardtype,
      this.inputFormatter,
      this.validator,
      this.title,
      this.maxLines,
      this.autovalidate,
      this.prefixIconbutton,
      this.maxcharacters,
      this.isboldinput,
      this.obscuretext,
      this.sufficIconbutton,
      this.minLines});
  @override
  _InpuTextBoxState createState() => _InpuTextBoxState();
}

class _InpuTextBoxState extends State<InpuTextBox> {
  bool isobscuretext = false;
  @override
  void initState() {
    super.initState();
    setState(() {
      isobscuretext = widget.obscuretext ?? false;
    });
  }

  changeobscure() {
    setState(() {
      isobscuretext = !isobscuretext;
    });
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    return Align(
      child: Container(
        margin: EdgeInsets.fromLTRB(
            widget.leftrightmargin ?? 8, 5, widget.leftrightmargin ?? 8, 5),
        width: widget.boxwidth ?? w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              // color: Colors.white,
              height: widget.boxheight ?? 50,
              // decoration: BoxDecoration(
              //     color: widget.boxbcgcolor ?? Colors.white,
              //     border: Border.all(
              //         color:
              //             widget.boxbordercolor ?? Mycolors.grey.withOpacity(0.2),
              //         style: BorderStyle.solid,
              //         width: 1.8),
              //     borderRadius: BorderRadius.all(
              //         Radius.circular(widget.boxcornerradius ?? 5))),
              child: TextFormField(
                minLines: widget.minLines ?? null,
                maxLines: widget.maxLines ?? 1,
                controller: widget.controller ?? null,
                obscureText: isobscuretext ?? false,
                onSaved: widget.onSaved ?? (val) {},
                readOnly: widget.disabled ?? false,
                onChanged: widget.onchanged ?? (val) {},
                maxLength: widget.maxcharacters ?? null,
                validator: widget.validator ?? null,
                keyboardType: widget.keyboardtype ?? null,
                autovalidateMode: widget.autovalidate == true
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                inputFormatters: widget.inputFormatter ?? [],
                textCapitalization:
                    widget.textCapitalization ?? TextCapitalization.sentences,
                style: TextStyle(
                  letterSpacing: widget.letterspacing ?? null,
                  fontSize: widget.fontsize ?? 15,
                  fontWeight: widget.isboldinput == true
                      ? FontWeight.w600
                      : FontWeight.w400,
                  // fontFamily:
                  //     widget.isboldinput == true ? 'NotoBold' : 'NotoRegular',
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                    prefixIcon: widget.prefixIconbutton != null
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    width: widget.boxborderwidth ?? 1.5,
                                    color: widget.showIconboundary == true ||
                                            widget.showIconboundary == null
                                        ? Colors.grey.withOpacity(0.3)
                                        : Colors.transparent),
                              ),
                              // color: Colors.white,
                            ),
                            margin: EdgeInsets.only(
                                left: 2, right: 5, top: 2, bottom: 2),
                            // height: 45,
                            alignment: Alignment.center,
                            width: 50,
                            child: widget.prefixIconbutton != null
                                ? widget.prefixIconbutton
                                : null)
                        : null,
                    suffixIcon: widget.sufficIconbutton != null ||
                            widget.obscuretext == true
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                    width: widget.boxborderwidth ?? 1.5,
                                    color: widget.showIconboundary == true ||
                                            widget.showIconboundary == null
                                        ? Colors.grey.withOpacity(0.3)
                                        : Colors.transparent),
                              ),
                              // color: Colors.white,
                            ),
                            margin: EdgeInsets.only(
                                left: 2, right: 5, top: 2, bottom: 2),
                            // height: 45,
                            alignment: Alignment.center,
                            width: 50,
                            child: widget.sufficIconbutton != null
                                ? widget.sufficIconbutton
                                : widget.obscuretext == true
                                    ? IconButton(
                                        icon: Icon(
                                            isobscuretext == true
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.blueGrey),
                                        onPressed: () {
                                          changeobscure();
                                        })
                                    : null)
                        : null,
                    filled: true,
                    fillColor: widget.boxbcgcolor ?? Colors.white,
                    enabledBorder: OutlineInputBorder(
                      // width: 0.0 produces a thin "hairline" border
                      borderRadius:
                          BorderRadius.circular(widget.boxcornerradius ?? 1),
                      borderSide: BorderSide(
                          color: widget.boxbordercolor ??
                              Colors.grey.withOpacity(0.2),
                          width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      // width: 0.0 produces a thin "hairline" border
                      borderRadius:
                          BorderRadius.circular(widget.boxcornerradius ?? 1),
                      borderSide: BorderSide(color: fiberchatgreen, width: 1.5),
                    ),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(widget.boxcornerradius ?? 1),
                        borderSide: BorderSide(color: Colors.grey)),
                    contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                    // labelText: 'Password',
                    hintText: widget.hinttext ?? '',
                    // fillColor: widget.boxbcgcolor ?? Colors.white,

                    hintStyle: TextStyle(
                        letterSpacing: widget.letterspacing ?? 1.5,
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
