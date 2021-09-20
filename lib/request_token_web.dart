import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:universal_html/html.dart' as html;
import 'package:webview_flutter/webview_flutter.dart';

import 'model/config.dart';
import 'model/token.dart';
import 'request/authorization_request.dart';

final logger = Logger('flutter_aad_oauth:web');

class RequestTokenWeb {
  final StreamController<Map<String, String>> _onCodeListener =
      new StreamController();
  final Config _config;
  late AuthorizationRequest _authorizationRequest;
  html.WindowBase? _popupWin;

  var _onCodeStream;

  RequestTokenWeb(Config config) : _config = config {
    _authorizationRequest = AuthorizationRequest(config);
  }

  Future<Token> requestToken() async {
    late Token token;
    final String urlParams = _constructUrlParams();
    if (_config.context != null) {
      String initialURL =
          ("${_authorizationRequest.url}?$urlParams").replaceAll(" ", "%20");

      _webAuth(initialURL);
    } else {
      throw Exception("Context is null. Please call setContext(context).");
    }

    var jsonToken = await _onCode.first;
    token = Token.fromJson(jsonToken);
    return token;
  }

  _webAuth(String initialURL) {
    html.window.onMessage.listen((event) {
      var tokenParms = ['access_token', 'code'];
      if (tokenParms
          .any((tokenparam) => event.data.toString().contains(tokenparam))) {
        _geturlData(event.data.toString());
      } else if (event.data.toString().contains("error")) {
        _closeWebWindow();
        throw new Exception("Access denied or authentation canceled.");
      }else{
        throw()
      }
    });
    _popupWin = html.window.open(
        initialURL, "Microsoft Auth", "width=800, height=900, scrollbars=yes");
  }

  _geturlData(String _url) {
    var url = _url.replaceFirst('#', "?");
    Uri uri = Uri.parse(url);

    if (uri.queryParameters["error"] != null) {
      _closeWebWindow();
      _onCodeListener
          .addError(new Exception("Access denied or authentation canceled."));
    }

    var token = uri.queryParameters;
    _onCodeListener.add(token);

    _closeWebWindow();
  }

  _closeWebWindow() {
    if (_popupWin != null) {
      _popupWin?.close();
      _popupWin = null;
    }
  }

  Future<void> clearCookies() async {
    CookieManager().clearCookies();
  }

  Stream<Map<String, String>> get _onCode =>
      _onCodeStream ??= _onCodeListener.stream.asBroadcastStream();

  String _constructUrlParams() =>
      _mapToQueryParams(_authorizationRequest.parameters);

  String _mapToQueryParams(Map<String, String> params) {
    final queryParams = <String>[];
    params
        .forEach((String key, String value) => queryParams.add("$key=$value"));
    return queryParams.join("&");
  }

  void setContext(BuildContext context) {
    _config.context = context;
  }
}
