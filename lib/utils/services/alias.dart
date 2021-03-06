import 'dart:io';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';

class AliasForm extends StatefulWidget {
  final Map<String, dynamic> user;
  final DataModel model;
  AliasForm(this.user, this.model);

  @override
  _AliasFormState createState() => _AliasFormState();
}

class _AliasFormState extends State<AliasForm> {
  TextEditingController _alias;

  File _imageFile;

  @override
  void initState() {
    super.initState();
    _alias =
        new TextEditingController(text: Fiberchat.getNickname(widget.user));
  }

  Future getImage(File image) {
    setState(() {
      _imageFile = image;
    });
    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    String name = Fiberchat.getNickname(widget.user);
    return Theme(
        child: AlertDialog(
          actions: <Widget>[
            FlatButton(
                child: Text(
                  'REMOVE ALIAS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: widget.user[ALIAS_NAME] != null ||
                        widget.user[ALIAS_AVATAR] != null
                    ? () {
                        widget.model.removeAlias(widget.user[PHONE]);
                        Navigator.pop(context);
                      }
                    : null),
            FlatButton(
                child: Text(
                  'SET ALIAS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_alias.text.isNotEmpty) {
                    if (_alias.text != name || _imageFile != null) {
                      widget.model.setAlias(
                          _alias.text, _imageFile, widget.user[PHONE]);
                    }
                    Navigator.pop(context);
                  }
                })
          ],
          contentPadding: EdgeInsets.all(20),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 120,
                  height: 120,
                  child: Stack(children: [
                    Center(
                        child: Fiberchat.avatar(widget.user,
                            image: _imageFile, radius: 50)),
                    // Positioned(
                    //     bottom: 0,
                    //     right: 0,
                    //     child: FloatingActionButton(
                    //       mini: true,
                    //       child: Icon(Icons.edit),
                    //       onPressed: () {
                    //         Navigator.push(
                    //             context,
                    //             MaterialPageRoute(
                    //                 builder: (context) => HybridImagePicker(
                    //                       title: 'Pick an image',
                    //                       callback: getImage,
                    //                       profile: true,
                    //                     )));
                    //       },
                    //     )),
                  ])),
              TextFormField(
                autovalidateMode: AutovalidateMode.always,
                controller: _alias,
                decoration: InputDecoration(hintText: 'Alias name'),
                validator: (val) {
                  if (val.trim().isEmpty) return 'Name cannot be empty!';
                  return null;
                },
              )
            ]),
          ),
        ),
        data: FiberchatTheme);
  }
}
