import 'package:flutter/material.dart';

/// Rolagem única e fluida nas telas OSCE (evita “travar” com scroll aninhado).
class OsceScrollPhysics {
  OsceScrollPhysics._();

  static const ScrollPhysics list = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );
}
