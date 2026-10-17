import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Idioma de la app: español de Colombia. Los textos propios ya están en
/// español; esto traduce los del sistema (calendario, copiar y pegar).
const Locale appLocale = Locale('es', 'CO');

const List<Locale> appSupportedLocales = [appLocale];

const List<LocalizationsDelegate<Object>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
