// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

// For the development of human civilization and science and technology

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/settings.dart';
import 'package:violet/variables.dart';
import 'locale.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';

DateTime currentBackPressTime;
final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

const _filesToWarmup = [
  'assets/flare/Loading2.flr',
  'assets/flare/likeUtsua.flr'
];

Future<void> warmupFlare() async {
  for (final filename in _filesToWarmup) {
    await cachedActor(rootBundle, filename);
  }
}

Future<void> initDB() async {
  await Bookmark.getInstance();
  await User.getInstance();
}

FirebaseAnalytics analytics;
FirebaseAnalyticsObserver observer;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize();
  FlareCache.doesPrune = false;

  Crashlytics.instance.enableInDevMode = true;
  FlutterError.onError = Crashlytics.instance.recordFlutterError;

  analytics = FirebaseAnalytics();
  observer = FirebaseAnalyticsObserver(analytics: analytics);
  var id = (await SharedPreferences.getInstance()).getString('fa_userid');
  if (id == null) {
    var ii = sha1.convert(utf8.encode(DateTime.now().toString()));
    id = ii.toString();
    (await SharedPreferences.getInstance()).setString('fa_userid', id);
  }
  await analytics.setUserId(id);

  await Settings.init();
  await initDB();
  await Variables.init();
  await HitomiIndexs.init();

  warmupFlare().then((_) {
    runApp(
      DynamicTheme(
        defaultBrightness: Brightness.light,
        data: (brightness) => new ThemeData(
          accentColor: Settings.majorColor,
          // primaryColor: Settings.majorColor,
          // primarySwatch: Settings.majorColor,
          brightness: brightness,
        ),
        themedWidgetBuilder: (context, theme) {
          return MaterialApp(
            navigatorObservers: [
              FirebaseAnalyticsObserver(analytics: analytics),
            ],
            theme: theme,
            home: SplashPage(),
            supportedLocales: [
              const Locale('en', 'US'),
              const Locale('ko', 'KR'),
              const Locale('ja', 'JP'),
              const Locale('zh', 'CH'),
              const Locale('it', 'IT'),
            ],
            routes: <String, WidgetBuilder>{
              '/AfterLoading': (BuildContext context) => WillPopScope(
                    child: new AfterLoadingPage(),
                    onWillPop: () {
                      DateTime now = DateTime.now();
                      if (currentBackPressTime == null ||
                          now.difference(currentBackPressTime) >
                              Duration(seconds: 2)) {
                        currentBackPressTime = now;
                        scaffoldKey.currentState.showSnackBar(new SnackBar(
                          duration: Duration(seconds: 2),
                          content: new Text(
                            Translations.of(context).trans('closedoubletap'),
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.grey.shade800,
                        ));
                        return Future.value(false);
                      }
                      return Future.value(true);
                    },
                  ),
              '/DatabaseDownload': (BuildContext context) =>
                  new DataBaseDownloadPage(),
            },
            localizationsDelegates: [
              const TranslationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate
            ],
            localeResolutionCallback:
                (Locale locale, Iterable<Locale> supportedLocales) {
              if (Settings.language != null) {
                if (Settings.language.contains('_')) {
                  var ss = Settings.language.split('_');
                  if (ss.length == 2)
                    return Locale.fromSubtags(
                        languageCode: ss[0], scriptCode: ss[1]);
                  else
                    return Locale.fromSubtags(
                        languageCode: ss[0],
                        scriptCode: ss[1],
                        countryCode: ss[2]);
                } else
                  return Locale(Settings.language);
              }

              if (locale == null) {
                debugPrint("*language locale is null!!!");
                if (Settings.language == null) {
                  Settings.setLanguage(supportedLocales.first.languageCode);
                }
                return supportedLocales.first;
              }

              for (Locale supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode ||
                    supportedLocale.countryCode == locale.countryCode) {
                  debugPrint("*language ok $supportedLocale");
                  if (Settings.language == null) {
                    Settings.setLanguage(supportedLocale.languageCode);
                  }
                  return supportedLocale;
                }
              }

              debugPrint("*language to fallback ${supportedLocales.first}");
              if (Settings.language == null)
                Settings.setLanguage(supportedLocales.first.languageCode);
              return supportedLocales.first;
            },
          );
        },
      ),
    );
  });
}
