import 'package:contacts_service/contacts_service.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/modules/models/DataModel.dart';
import 'package:fiberchat/utils/services/open_settings.dart';
import 'package:fiberchat/utils/services/utils.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:localstorage/localstorage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsSelect extends StatefulWidget {
  const ContactsSelect({
    @required this.currentUserNo,
    @required this.model,
    @required this.biometricEnabled,
    @required this.prefs,
    @required this.onSelect,
  });
  final String currentUserNo;
  final DataModel model;
  final SharedPreferences prefs;
  final bool biometricEnabled;
  final Function(String contactname, String contactphone) onSelect;

  @override
  _ContactsSelectState createState() => new _ContactsSelectState();
}

class _ContactsSelectState extends State<ContactsSelect>
    with AutomaticKeepAliveClientMixin {
  Map<String, String> contacts;
  Map<String, String> _filtered = new Map<String, String>();

  @override
  bool get wantKeepAlive => true;

  final TextEditingController _filter = new TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _filter.dispose();
  }

  loading() {
    return Stack(children: [
      Container(
        child: Center(
            child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(fiberchatBlue),
        )),
      )
    ]);
  }

  @override
  initState() {
    super.initState();
    getContacts();
  }

  String getNormalizedNumber(String number) {
    if (number == null) return null;
    return number.replaceAll(new RegExp('[^0-9+]'), '');
  }

  _isHidden(String phoneNo) {
    Map<String, dynamic> _currentUser = widget.model.currentUser;
    return _currentUser[HIDDEN] != null &&
        _currentUser[HIDDEN].contains(phoneNo);
  }

  Future<Map<String, String>> getContacts({bool refresh = false}) async {
    Completer<Map<String, String>> completer =
        new Completer<Map<String, String>>();

    LocalStorage storage = LocalStorage(CACHED_CONTACTS);

    Map<String, String> _cachedContacts = {};
    print('FETCHING CONTACTS 1');
    completer.future.then((c) {
      c.removeWhere((key, val) => _isHidden(key));
      if (mounted) {
        setState(() {
          this.contacts = this._filtered = c;
        });
      }
    });
    print('FETCHING CONTACTS 2');

    Fiberchat.checkAndRequestPermission(PermissionGroup.contacts).then((res) {
      print('FETCHING CONTACTS 3');
      if (res) {
        storage.ready.then((ready) async {
          if (ready) {
            print('FETCHING CONTACTS 4');
            // var _stored = await storage.getItem(CACHED_CONTACTS);
            // if (_stored == null)
            //   _cachedContacts = new Map<String, String>();
            // else
            //   _cachedContacts = Map.from(_stored);

            // if (refresh == false && _cachedContacts.isNotEmpty)
            //   completer.complete(_cachedContacts);
            // else {
            String getNormalizedNumber(String number) {
              if (number == null) return null;
              return number.replaceAll(new RegExp('[^0-9+]'), '');
            }

            print('FETCHING CONTACTS 5');
            ContactsService.getContacts(withThumbnails: false)
                .then((Iterable<Contact> contacts) async {
              contacts.where((c) => c.phones.isNotEmpty).forEach((Contact p) {
                if (p?.displayName != null && p.phones.isNotEmpty) {
                  List<String> numbers = p.phones
                      .map((number) {
                        String _phone = getNormalizedNumber(number.value);
                        if (!_phone.startsWith('+')) {
                          // If the country code is not available,
                          // the most probable country code
                          // will be that of current user.
                          String cc = widget.model.currentUser[COUNTRY_CODE]
                              .toString()
                              .substring(1);
                          String trunk;
                          trunk = CountryCode_TrunkCode.firstWhere(
                              (list) => list.first == cc)?.toList()?.last;
                          if (trunk == null || trunk.isEmpty) trunk = '-';
                          if (_phone.startsWith(trunk)) {
                            _phone = _phone.replaceFirst(RegExp(trunk), '');
                          }
                          _phone = '+$cc$_phone';
                          return _phone;
                        }
                        return _phone;
                      })
                      .toList()
                      .where((s) => s != null)
                      .toList();
                  print('FETCHING CONTACTS 6');
                  numbers.forEach((number) {
                    _cachedContacts[number] = p.displayName;
                    setState(() {});
                  });
                  setState(() {});
                }
              });
              print('FETCHING CONTACTS 7');
              // await storage.setItem(CACHED_CONTACTS, _cachedContacts);
              completer.complete(_cachedContacts);
            });
          }
          // }
        });
      } else {
        Fiberchat.showRationale(
            'Permission to access contacts is needed to connect with people you know.');
        Navigator.pushReplacement(context,
            new MaterialPageRoute(builder: (context) => OpenSettings()));
      }
    }).catchError((onError) {
      Fiberchat.showRationale('Error occured: $onError');
    });

    return completer.future;
  }

  Icon _searchIcon = new Icon(Icons.search);
  Widget _appBarTitle = new Text('Select Contact to Share');

  void _searchPressed() {
    setState(() {
      if (this._searchIcon.icon == Icons.search) {
        this._searchIcon = new Icon(Icons.close);
        this._appBarTitle = new TextField(
          autofocus: true,
          style: TextStyle(color: fiberchatWhite),
          controller: _filter,
          decoration: new InputDecoration(
              hintText: 'Search ', hintStyle: TextStyle(color: fiberchatWhite)),
        );
      } else {
        this._searchIcon = new Icon(Icons.search);
        this._appBarTitle = new Text('Select Contact to Share');

        _filter.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Fiberchat.getNTPWrappedWidget(ScopedModel<DataModel>(
        model: widget.model,
        child:
            ScopedModelDescendant<DataModel>(builder: (context, child, model) {
          return Scaffold(
              backgroundColor: fiberchatWhite,
              appBar: AppBar(
                backgroundColor: fiberchatDeepGreen,
                centerTitle: false,
                title: _appBarTitle,
                actions: <Widget>[
                  IconButton(
                    icon: _searchIcon,
                    onPressed: _searchPressed,
                  )
                ],
              ),
              body: contacts == null
                  ? loading()
                  : RefreshIndicator(
                      onRefresh: () {
                        return getContacts(refresh: true);
                      },
                      child: _filtered.isEmpty
                          ? ListView(children: [
                              Padding(
                                  padding: EdgeInsets.only(
                                      top: MediaQuery.of(context).size.height /
                                          2.5),
                                  child: Center(
                                    child: Text('No search results.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: fiberchatWhite,
                                        )),
                                  ))
                            ])
                          : ListView.builder(
                              padding: EdgeInsets.all(10),
                              itemCount: _filtered.length,
                              itemBuilder: (context, idx) {
                                MapEntry user =
                                    _filtered.entries.elementAt(idx);
                                String phone = user.key;
                                return ListTile(
                                  leading: CircleAvatar(
                                      backgroundColor: fiberchatgreen,
                                      radius: 22.5,
                                      child: Text(
                                        Fiberchat.getInitials(user.value),
                                        style: TextStyle(color: fiberchatWhite),
                                      )),
                                  title: Text(user.value,
                                      style: TextStyle(color: fiberchatBlack)),
                                  subtitle: Text(phone,
                                      style: TextStyle(color: fiberchatGrey)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10.0, vertical: 0.0),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onSelect(user.value, phone);
                                  },
                                );
                              },
                            )));
        })));
  }
}
