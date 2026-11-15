import 'package:flutter/widgets.dart';

/// The icon set used across Handoff.
///
/// Backed by the `broken` icon font (the same one watchtower ships): ~900
/// line icons drawn at one weight, so every glyph in the UI matches. Only the
/// icons the app actually uses are declared here.
class AppIcons {
  const AppIcons._();

  static const String _f = 'broken';
  static const String _ff = 'broken_filled';

  // Navigation / shell
  static const IconData menu = IconData(0xea83, fontFamily: _f);
  static const IconData add = IconData(0xec7e, fontFamily: _f);
  static const IconData addCircle = IconData(0xec80, fontFamily: _f);
  static const IconData search = IconData(0xe9b8, fontFamily: _f);
  static const IconData settings = IconData(0xe9a2, fontFamily: _f);
  static const IconData logout = IconData(0xea9a, fontFamily: _f);
  static const IconData home = IconData(0xeace, fontFamily: _f);
  static const IconData more = IconData(0xea4a, fontFamily: _f);
  static const IconData close = IconData(0xebc0, fontFamily: _f);
  static const IconData arrowLeft = IconData(0xec56, fontFamily: _f);
  static const IconData arrowRight = IconData(0xec53, fontFamily: _f);
  static const IconData arrowDown = IconData(0xec5b, fontFamily: _f);
  static const IconData arrowUp = IconData(0xec48, fontFamily: _f);

  // Conversations
  static const IconData message = IconData(0xea71, fontFamily: _f);
  static const IconData messageText = IconData(0xea73, fontFamily: _f);
  static const IconData messageAdd = IconData(0xea80, fontFamily: _f);
  static const IconData messages = IconData(0xea6c, fontFamily: _f);
  static const IconData user = IconData(0xe92b, fontFamily: _f);
  static const IconData clock = IconData(0xebc1, fontFamily: _f);
  static const IconData refresh = IconData(0xe9da, fontFamily: _f);

  // Composer / actions
  static const IconData send = IconData(0xe9a8, fontFamily: _f);
  static const IconData paperclip = IconData(0xea25, fontFamily: _f);
  static const IconData copy = IconData(0xeb9d, fontFamily: _f);
  static const IconData copySuccess = IconData(0xeb9e, fontFamily: _f);
  static const IconData tickCircle = IconData(0xe954, fontFamily: _f);
  static const IconData tickSquare = IconData(0xe952, fontFamily: _f);
  static const IconData trash = IconData(0xe942, fontFamily: _f);
  static const IconData edit = IconData(0xeb57, fontFamily: _f);
  static const IconData star = IconData(0xe974, fontFamily: _f);
  static const IconData eye = IconData(0xeb3f, fontFamily: _f);
  static const IconData eyeSlash = IconData(0xeb40, fontFamily: _f);
  static const IconData lock = IconData(0xea9e, fontFamily: _f);

  // Agent / run state
  static const IconData play = IconData(0xea0e, fontFamily: _f);
  static const IconData pause = IconData(0xea1f, fontFamily: _f);
  static const IconData stop = IconData(0xe96e, fontFamily: _f);
  static const IconData stopCircle = IconData(0xe96f, fontFamily: _f);
  static const IconData flash = IconData(0xeb2c, fontFamily: _f);
  static const IconData flashCircle = IconData(0xeb2e, fontFamily: _f);
  static const IconData cpu = IconData(0xeb98, fontFamily: _f);
  static const IconData verify = IconData(0xe92a, fontFamily: _f);
  static const IconData danger = IconData(0xeb92, fontFamily: _f);
  static const IconData info = IconData(0xeac4, fontFamily: _f);
  static const IconData timer = IconData(0xe949, fontFamily: _f);
  static const IconData statusUp = IconData(0xe973, fontFamily: _f);

  // Tools / content
  static const IconData document = IconData(0xeb5e, fontFamily: _f);
  static const IconData folder = IconData(0xeb23, fontFamily: _f);
  static const IconData sun = IconData(0xe967, fontFamily: _f);
  static const IconData moon = IconData(0xea4e, fontFamily: _f);
  static const IconData notification = IconData(0xea2a, fontFamily: _f);
  static const IconData notificationStatus = IconData(0xea2b, fontFamily: _f);
  static const IconData code = IconData(0xeb98, fontFamily: _f);
  static const IconData terminal = IconData(0xeb5e, fontFamily: _f);

  // Filled variants
  static const IconData messageFilled = IconData(0xea82, fontFamily: _ff);
  static const IconData likeFilled = IconData(0xe901, fontFamily: _ff);
}
