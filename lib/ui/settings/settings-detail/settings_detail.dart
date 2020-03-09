import 'dart:async';
import 'dart:io';

import 'package:cuacfm/injector/dependency_injector.dart';
import 'package:cuacfm/models/legal.dart';
import 'package:cuacfm/models/license.dart';
import 'package:cuacfm/models/radiostation.dart';
import 'package:cuacfm/utils/player_view.dart';
import 'package:cuacfm/utils/radiocom_colors.dart';
import 'package:cuacfm/utils/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injector/injector.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'settings_presenter_detail.dart';

enum LegalType { TERMS, PRIVACY, LICENSE, NONE }

class SettingsDetail extends StatefulWidget {
  SettingsDetail({Key key, this.legalType}) : super(key: key);
  final LegalType legalType;

  @override
  State createState() => new SettingsDetailState();
}

class SettingsDetailState extends State<SettingsDetail> with WidgetsBindingObserver
    implements SettingsDetailView {
  MediaQueryData _queryData;
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  SettingsDetailPresenter _presenter;
  RadioStation _radioStation;
  RadiocomColorsConract _colors;
  bool shouldShowPlayer = false;
  bool isContentUpdated = true;
  EventChannel _notificationEvent =
  EventChannel('cuacfm.flutter.io/updateNotification');
  SnackBar snackBarConnection;

  SettingsDetailState() {
    DependencyInjector().injectByView(this);
  }

  @override
  Widget build(BuildContext context) {
    _queryData = MediaQuery.of(context);
    _colors = Injector.appInstance.getDependency<RadiocomColorsConract>();
    return Scaffold(
      key: scaffoldKey,
      appBar: TopBar("settings_detail",
          title: getTitle(widget.legalType), topBarOption: TopBarOption.MODAL),
      backgroundColor: widget.legalType == LegalType.NONE ? _colors.transparent:_colors.palidwhite,
      body: _getBodyLayout(widget.legalType),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: PlayerView(
            isMini: false,
            isAtBottom: true,
            shouldShow: shouldShowPlayer,
            isPlayingAudio: _presenter.currentPlayer.isPlaying(),
            isExpanded: true,
            onDetailClicked: () {
              _presenter.onPodcastControlsClicked(
                  _presenter.currentPlayer.episode);
            },
            onMultimediaClicked: (isPlaying) {
              if (!mounted) return;
              setState(() {
                if (isPlaying) {
                  _presenter.onPause();
                } else {
                  _presenter.onResume();
                }
              });
            })
    );
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      MethodChannel('cuacfm.flutter.io/changeScreen').invokeMethod(
          'changeScreen', {"currentScreen": "settings_detail", "close": false});
    }
    _presenter = Injector.appInstance.getDependency<SettingsDetailPresenter>();
    shouldShowPlayer = _presenter.currentPlayer.isPlaying();
    _radioStation = Injector.appInstance.getDependency<RadioStation>();

    if (Platform.isAndroid) {
      _notificationEvent.receiveBroadcastStream().listen((onData) {
        if (_notificationEvent != null) {
          setState(() {
            _presenter.currentPlayer.release();
            _presenter.currentPlayer.isPodcast = false;
            _presenter.currentPlayer.episode = null;
            shouldShowPlayer = false;
          });
        }
      });
    }

    _presenter.currentPlayer.onConnection = (isError) {
      if (mounted) {
        new Timer(new Duration(milliseconds: 300), () {
          setState(() {});
        });
        if(isError){
          onConnectionError();
        }
      }
    };

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!isContentUpdated) {
          isContentUpdated = true;
          _presenter.onViewResumed();
        }
        break;
      case AppLifecycleState.paused:
        isContentUpdated = false;
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _notificationEvent = null;
    WidgetsBinding.instance.removeObserver(this);
    Injector.appInstance.removeByKey<SettingsDetailView>();
    super.dispose();
  }

  @override
  void onConnectionError() {
    if (snackBarConnection == null) {
      scaffoldKey.currentState..removeCurrentSnackBar();
      snackBarConnection = SnackBar(
        duration: Duration(seconds: 3),
        content: Text("No dispones de conexión a internet"),
      );
      scaffoldKey.currentState..showSnackBar(snackBarConnection);
    }
  }

  @override
  onNewData() {
    if (!mounted) return;
    setState(() {});
  }

  //layout

  Widget _getBodyLayout(LegalType legalType) {
    if (legalType == LegalType.LICENSE) {
      return _getLicense();
    } else if (legalType == LegalType.TERMS) {
      return _getTermsAndPrivacyLayout(legalType);
    } else if (legalType == LegalType.PRIVACY) {
      return _getTermsAndPrivacyLayout(legalType);
    } else if (legalType == LegalType.NONE) {
      return _getGallery();
    }
  }

  Widget _getLicense() {
    var licenses = License.getAll();
    var licenseList = List<Widget>();
    licenseList.add(SizedBox(height: 10));
    licenses.forEach((license) {
      licenseList.add(Container(
          margin: EdgeInsets.fromLTRB(0.0, 2.0, 0.0, 0.0),
          padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 5.0),
          width: _queryData.size.width,
          child: ListTile(
              title: Text(license.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _colors.black)),
              subtitle: new Column(children: <Widget>[
                Container(
                    margin: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 8.0),
                    height: 0.5,
                    width: _queryData.size.width * 0.8,
                    color: _colors.yellow),
                Text(license.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _colors.darkGrey))
              ]))));
    });
    licenseList.add(SizedBox(height: 80));
    return Container(
        color: _colors.palidwhitedark,
        child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            key: new ValueKey<String>("licenseNote"),
            child: Column(children: licenseList)));
  }

  Widget _getTermsAndPrivacyLayout(LegalType legalType) {
    String content =
        (legalType == LegalType.TERMS) ? Legal.terms : Legal.privacy;
    return Container(
        color: _colors.palidwhitedark,
        child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            key: new ValueKey<String>("termsprivacynote"),
            child: Column(children: [
              SizedBox(height: 20),
              ListTile(
                  title: Text(content,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _colors.black))),
              Container(
                  margin: EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 8.0),
                  height: 0.5,
                  width: _queryData.size.width * 0.8,
                  color: _colors.yellow),
              SizedBox(height: 80)
            ])));
  }

  Widget _getGallery(){
     return Container(
        child: PhotoViewGallery.builder(
          scrollPhysics: BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(_radioStation.station_photos[index]),
              initialScale: PhotoViewComputedScale.contained * 0.8,
             // heroAttributes:  HeroAttributes(tag: "tag1"),
            );
          },
          itemCount: _radioStation.station_photos.length,
          loadingBuilder: (context, event) => Center(
            child: Container(
              width: 20.0,
              height: 20.0,
              child: CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes,
              ),
            ),
          )
        )
    );
  }

  String getTitle(LegalType legalType) {
    if (legalType == LegalType.LICENSE) {
      return "Licencias de software";
    } else if (legalType == LegalType.TERMS) {
      return "Términos y condiciones";
    } else if (legalType == LegalType.PRIVACY) {
      return "Política de privacidad";
    } else {
      return "";
    }
  }
}