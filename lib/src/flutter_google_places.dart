library flutter_google_places.src;

import 'dart:async';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class PlacesAutocompleteWidget extends StatefulWidget {
  final String apiKey;
  final String? startText;
  final String hint;
  final BorderRadius? overlayBorderRadius;
  final Location? location;
  final num? offset;
  final num? radius;
  final String? language;
  final String? sessionToken;
  final List<String>? types;
  final List<Component>? components;
  final bool? strictbounds;
  final String? region;
  final Mode mode;
  final Widget? logo;
  final ValueChanged<PlacesAutocompleteResponse>? onError;
  final int debounce;
  final InputDecoration? decoration;

  /// optional - sets 'proxy' value in google_maps_webservice
  ///
  /// In case of using a proxy the baseUrl can be set.
  /// The apiKey is not required in case the proxy sets it.
  /// (Not storing the apiKey in the app is good practice)
  final String? proxyBaseUrl;

  /// optional - set 'client' value in google_maps_webservice
  ///
  /// In case of using a proxy url that requires authentication
  /// or custom configuration
  final BaseClient? httpClient;

  PlacesAutocompleteWidget({
    required this.apiKey,
    this.mode = Mode.fullscreen,
    this.hint = "Search",
    this.overlayBorderRadius,
    this.offset,
    this.location,
    this.radius,
    this.language,
    this.sessionToken,
    this.types,
    this.components,
    this.strictbounds,
    this.region,
    this.logo,
    this.onError,
    Key? key,
    this.proxyBaseUrl,
    this.httpClient,
    this.startText,
    this.debounce = 300,
    this.decoration,
  }) : super(key: key);

  @override
  State<PlacesAutocompleteWidget> createState() {
    if (mode == Mode.fullscreen) {
      return _PlacesAutocompleteScaffoldState();
    }
    return _PlacesAutocompleteOverlayState();
  }

  static PlacesAutocompleteState? of(BuildContext context) =>
      context.findAncestorStateOfType<PlacesAutocompleteState>();
}

class _PlacesAutocompleteScaffoldState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: AppBarPlacesAutoCompleteTextField(
        textDecoration: widget.decoration,
      ),
    );
    final body = PlacesAutocompleteResult(
      onTap: Navigator
          .of(context)
          .pop,
      logo: widget.logo,
    );
    return Scaffold(appBar: appBar, body: body);
  }
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final headerTopLeftBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.topLeft
        : Radius.circular(2);

    final headerTopRightBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.topRight
        : Radius.circular(2);

    final header = Column(children: <Widget>[
      Material(
          color: theme.dialogBackgroundColor,
          borderRadius: BorderRadius.only(
              topLeft: headerTopLeftBorderRadius,
              topRight: headerTopRightBorderRadius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                color: theme.brightness == Brightness.light
                    ? Colors.black45
                    : null,
                icon: _iconBack,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Expanded(
                  child: Padding(
                    child: _textField(context),
                    padding: const EdgeInsets.only(right: 8.0),
                  )),
            ],
          )),
      Divider(
        //height: 1.0,
      )
    ]);

    Widget body;

    final bodyBottomLeftBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.bottomLeft
        : Radius.circular(2);

    final bodyBottomRightBorderRadius = widget.overlayBorderRadius != null
        ? widget.overlayBorderRadius!.bottomRight
        : Radius.circular(2);

    if (_searching) {
      body = Stack(
        children: <Widget>[_Loader()],
        alignment: FractionalOffset.bottomCenter,
      );
    } else if (_queryTextController!.text.isEmpty ||
        _response == null ||
        _response!.predictions.isEmpty) {
      body = Material(
        color: theme.dialogBackgroundColor,
        child: widget.logo ?? PoweredByGoogleImage(),
        borderRadius: BorderRadius.only(
          bottomLeft: bodyBottomLeftBorderRadius,
          bottomRight: bodyBottomRightBorderRadius,
        ),
      );
    } else {
      body = SingleChildScrollView(
        child: Material(
          borderRadius: BorderRadius.only(
            bottomLeft: bodyBottomLeftBorderRadius,
            bottomRight: bodyBottomRightBorderRadius,
          ),
          color: theme.dialogBackgroundColor,
          child: ListBody(
            children: _response!.predictions
                .map(
                  (p) =>
                  PredictionTile(
                    prediction: p,
                    onTap: Navigator
                        .of(context)
                        .pop,
                  ),
            )
                .toList(),
          ),
        ),
      );
    }

    final container = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
        child: Stack(children: <Widget>[
          header,
          Padding(padding: EdgeInsets.only(top: 48.0), child: body),
        ]));

    if (Theme
        .of(context)
        .platform == TargetPlatform.iOS) {
      return Padding(padding: EdgeInsets.only(top: 8.0), child: container);
    }
    return container;
  }

  Icon get _iconBack =>
      Theme
          .of(context)
          .platform == TargetPlatform.iOS
          ? Icon(Icons.arrow_back_ios)
          : Icon(Icons.arrow_back);

  Widget _textField(BuildContext context) =>
      TextField(
        controller: _queryTextController,
        autofocus: true,
        style: TextStyle(
            color: Theme
                .of(context)
                .brightness == Brightness.light
                ? Colors.black87
                : null,
            fontSize: 16.0),
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Theme
                    .of(context)
                    .brightness == Brightness.light
                    ? Colors.black45
                    : null,
                fontSize: 16.0,
              ),
              border: InputBorder.none,
            ),
      );
}

class _Loader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(maxHeight: 2.0),
        child: LinearProgressIndicator());
  }
}

class PlacesAutocompleteResult extends StatefulWidget {
  final ValueChanged<Prediction>? onTap;
  final Widget? logo;

  PlacesAutocompleteResult({this.onTap, this.logo});

  @override
  _PlacesAutocompleteResult createState() => _PlacesAutocompleteResult();
}

class _PlacesAutocompleteResult extends State<PlacesAutocompleteResult> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context)!;
    assert(state != null);

    if (state._queryTextController!.text.isEmpty ||
        state._response == null ||
        state._response!.predictions.isEmpty) {
      final children = <Widget>[];
      return Stack(children: children);
    }
    return PredictionsListView(
      predictions: state._response!.predictions,
      onTap: widget.onTap,
    );
  }
}

class AppBarPlacesAutoCompleteTextField extends StatefulWidget {
  final InputDecoration? textDecoration;
  final TextStyle? textStyle;

  AppBarPlacesAutoCompleteTextField(
      {Key? key, this.textDecoration, this.textStyle})
      : super(key: key);

  @override
  _AppBarPlacesAutoCompleteTextFieldState createState() =>
      _AppBarPlacesAutoCompleteTextFieldState();
}

class _AppBarPlacesAutoCompleteTextFieldState
    extends State<AppBarPlacesAutoCompleteTextField> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context)!;
    assert(state != null);

    return Container(
        child: TextField(
          textAlignVertical: TextAlignVertical.center,
          cursorColor: Color(0xff3E4958),
          autocorrect: true,
          controller: state._queryTextController,
          style: widget.textStyle ?? _defaultStyle(),
          decoration:
          widget.textDecoration ?? _defaultDecoration(state.widget.hint),
        )
    );
  }

  InputDecoration _defaultDecoration(String hint) {
    return InputDecoration(
      isCollapsed: true,
      hintText: "Your destination",
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 15, horizontal: 15),
        child: SvgPicture.asset(
          "assets/icons/search_icon.svg",
          width: 30,
          height: 30,
          fit: BoxFit.fill,
        ),
      ),
      hintStyle: TextStyle(
          color: Color.fromRGBO(26, 32, 61, 0.3),
          fontSize: 16.sp,
          fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Color(0xfff4f4f4),
      contentPadding: EdgeInsets.symmetric(vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          width: 0,
          style: BorderStyle.none,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide:
        BorderSide(color: Color(0xff360377), width: 1),
      ),
    );
  }

  TextStyle _defaultStyle() {
    return TextStyle(
        color: Color(0xff3E4958),
        fontSize: 16.sp,
        fontWeight: FontWeight.w400);
  }
}

class PoweredByGoogleImage extends StatelessWidget {
  final _poweredByGoogleWhite =
      "packages/flutter_google_places/assets/google_white.png";
  final _poweredByGoogleBlack =
      "packages/flutter_google_places/assets/google_black.png";

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Padding(
          padding: EdgeInsets.all(16.0),
          child: Image.asset(
            Theme
                .of(context)
                .brightness == Brightness.light
                ? _poweredByGoogleWhite
                : _poweredByGoogleBlack,
            scale: 2.5,
          ))
    ]);
  }
}

class PredictionsListView extends StatelessWidget {
  final List<Prediction> predictions;
  final ValueChanged<Prediction>? onTap;

  PredictionsListView({required this.predictions, this.onTap});

  ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return
      Column(
        children: [
          ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(top: 34.h),
            children: predictions
                .map((Prediction p) =>
                PredictionTile(prediction: p, onTap: onTap))
                .toList(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset("assets/icons/pin_choose_icon.svg"),
              SizedBox(width: 9.w,),
              Text("Choose on the Map", style: TextStyle(
                  color: Color(0xff360377),
                  fontSize: 16,
                  fontWeight: FontWeight.w400
              ),)
            ],
          )

        ],
      );
  }
}

class PredictionTile extends StatelessWidget {
  final Prediction prediction;
  final ValueChanged<Prediction>? onTap;

  PredictionTile({required this.prediction, this.onTap});

  @override
  Widget build(BuildContext context) {
    return
      Column(
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: double.infinity,
            ),
            height: 80.h,
            child: ListTile(
              horizontalTitleGap: 12.w,
              leading: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset("assets/icons/pin_icon.svg"),
                  ],
                ),
              ),
              trailing: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset("assets/icons/arrow_icon.svg"),
                  ],
                ),
              ),
              title: Text(prediction.description!, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff3E4958)),),
              onTap: () {
                if (onTap != null) {
                  onTap!(prediction);
                }
              },
              subtitle: Text("Algeria", style: TextStyle(
                  color: Color(0xff97ADB6),
                  fontWeight: FontWeight.w400,
                  fontSize: 14),),
            ),
          ),
          SizedBox(height: 4.h,),
          Container(
            constraints: BoxConstraints(
              maxHeight: double.infinity,
            ),
            color: Color(0xffD5DDE0),
            height: 1,
            width: 335.w,
          ),
        ],
      );
  }
}

enum Mode { overlay, fullscreen }

abstract class PlacesAutocompleteState extends State<PlacesAutocompleteWidget> {
  TextEditingController? _queryTextController;
  PlacesAutocompleteResponse? _response;
  GoogleMapsPlaces? _places;
  late bool _searching;
  Timer? _debounce;

  final _queryBehavior = BehaviorSubject<String>.seeded('');

  @override
  void initState() {
    super.initState();

    _queryTextController = TextEditingController(text: widget.startText);
    _queryTextController!.selection = new TextSelection(
      baseOffset: 0,
      extentOffset: widget.startText?.length ?? 0,
    );

    _initPlaces();
    _searching = false;

    _queryTextController!.addListener(_onQueryChange);

    _queryBehavior.stream.listen(doSearch);
  }

  Future<void> _initPlaces() async {
    _places = GoogleMapsPlaces(
      apiKey: widget.apiKey,
      baseUrl: widget.proxyBaseUrl,
      httpClient: widget.httpClient,
      apiHeaders: await GoogleApiHeaders().getHeaders(),
    );
  }

  Future<Null> doSearch(String value) async {
    if (mounted && value.isNotEmpty && _places != null) {
      setState(() {
        _searching = true;
      });

      final res = await _places!.autocomplete(
        value,
        offset: widget.offset,
        location: widget.location,
        radius: widget.radius,
        language: widget.language,
        sessionToken: widget.sessionToken,
        types: widget.types!,
        components: widget.components!,
        strictbounds: widget.strictbounds!,
        region: widget.region,
      );

      if (res.errorMessage?.isNotEmpty == true ||
          res.status == "REQUEST_DENIED") {
        onResponseError(res);
      } else {
        onResponse(res);
      }
    } else {
      onResponse(null);
    }
  }

  void _onQueryChange() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: widget.debounce), () {
      if (!_queryBehavior.isClosed) {
        _queryBehavior.add(_queryTextController!.text);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    _places!.dispose();
    _debounce!.cancel();
    _queryBehavior.close();
    _queryTextController!.removeListener(_onQueryChange);
  }

  @mustCallSuper
  void onResponseError(PlacesAutocompleteResponse res) {
    if (!mounted) return;

    if (widget.onError != null) {
      widget.onError!(res);
    }
    setState(() {
      _response = null;
      _searching = false;
    });
  }

  @mustCallSuper
  void onResponse(PlacesAutocompleteResponse? res) {
    if (!mounted) return;

    setState(() {
      _response = res;
      _searching = false;
    });
  }
}

class PlacesAutocomplete {
  static Future<Prediction?> show({
    required BuildContext context,
    required String apiKey,
    Mode mode = Mode.fullscreen,
    String hint = "Search",
    BorderRadius? overlayBorderRadius,
    num? offset,
    Location? location,
    num? radius,
    String? language,
    String? sessionToken,
    List<String>? types,
    List<Component>? components,
    bool? strictbounds,
    String? region,
    Widget? logo,
    ValueChanged<PlacesAutocompleteResponse>? onError,
    String? proxyBaseUrl,
    Client? httpClient,
    InputDecoration? decoration,
    String startText = "",
  }) {
    final builder = (BuildContext ctx) =>
        PlacesAutocompleteWidget(
          apiKey: apiKey,
          mode: mode,
          overlayBorderRadius: overlayBorderRadius,
          language: language,
          sessionToken: sessionToken,
          components: components,
          types: types,
          location: location,
          radius: radius,
          strictbounds: strictbounds,
          region: region,
          offset: offset,
          hint: hint,
          logo: logo,
          onError: onError,
          proxyBaseUrl: proxyBaseUrl,
          httpClient: httpClient as BaseClient?,
          startText: startText,
          decoration: decoration,
        );

    if (mode == Mode.overlay) {
      return showDialog(context: context, builder: builder);
    }
    return Navigator.push(context, MaterialPageRoute(builder: builder));
  }
}
