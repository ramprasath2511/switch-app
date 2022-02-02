import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fiberchat/constants/app_constants.dart';
import 'package:fiberchat/integrations/provider/call_history_provider.dart';
import 'package:flutter/material.dart';

class InfiniteListView extends StatefulWidget {
  final FirestoreDataProviderCALLHISTORY firestoreDataProviderCALLHISTORY;
  final String datatype;
  final Widget list;
  final Query refdata;
  final bool isreverse;
  final EdgeInsets padding;
  final String parentid;
  const InfiniteListView({
    this.firestoreDataProviderCALLHISTORY,
    this.datatype,
    this.isreverse,
    this.padding,
    this.parentid,
    this.list,
    this.refdata,
    Key key,
  }) : super(key: key);

  @override
  _InfiniteListViewState createState() => _InfiniteListViewState();
}

class _InfiniteListViewState extends State<InfiniteListView> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    scrollController.addListener(scrollListener);
    if (widget.datatype == 'CALLHISTORY') {
      widget.firestoreDataProviderCALLHISTORY
          .fetchNextData(widget.datatype, widget.refdata, true);
    } else {}
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.offset >=
            scrollController.position.maxScrollExtent / 2 &&
        !scrollController.position.outOfRange) {
      if (widget.datatype == 'CALLHISTORY') {
        if (widget.firestoreDataProviderCALLHISTORY.hasNext) {
          widget.firestoreDataProviderCALLHISTORY
              .fetchNextData(widget.datatype, widget.refdata, false);
        }
      } else {}
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        physics: ScrollPhysics(),
        shrinkWrap: true,
        reverse: widget.isreverse == null || widget.isreverse == false
            ? false
            : true,
        controller: scrollController,
        padding: widget.padding == null ? EdgeInsets.all(0) : widget.padding,
        children: widget.datatype == 'CALLHISTORY'
            ?
            //-----PRODUCTS
            [
                Container(child: widget.list),
                (widget.firestoreDataProviderCALLHISTORY.hasNext == true)
                    ? Center(
                        child: GestureDetector(
                          onTap: () {
                            widget.firestoreDataProviderCALLHISTORY
                                .fetchNextData(
                                    widget.datatype, widget.refdata, false);
                          },
                          child: Container(
                            height: 205,
                            width: 205,
                            child: Center(
                              child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      fiberchatLightGreen)),
                            ),
                          ),
                        ),
                      )
                    : widget.firestoreDataProviderCALLHISTORY.recievedDocs
                                .length <
                            1
                        ? Align(
                            alignment: Alignment.center,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                    28,
                                    MediaQuery.of(context).size.height / 3.7,
                                    28,
                                    10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Container(
                                        padding: EdgeInsets.all(22),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          // borderRadius: BorderRadius.all(
                                          //   Radius.circular(20),
                                          // ),
                                        ),
                                        height: 100,
                                        width: 100,
                                        child: Icon(Icons.call,
                                            size: 60, color: Colors.grey)),
                                    SizedBox(
                                      height: 30,
                                    ),
                                    Text(
                                      'No Call History',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      'All Video & Audio call history will be shown here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13.9,
                                          fontWeight: FontWeight.w400),
                                    ),
                                    SizedBox(
                                      height: 30,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SizedBox(),
              ]
            : [],
      );
}
