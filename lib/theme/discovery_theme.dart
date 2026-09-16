import 'package:flutter/material.dart';

import 'package:walkpenang/theme/app_theme.dart';

/// The Discovery module's theme — now simply the shared app theme.
///
/// This module used to carry its own palette (`discovery_colors.dart`), its
/// own fonts and its own corner radii, which is why its screens read as a
/// different app from the rest of WalkPenang. All of it has been folded into
/// [AppColors]/[AppType]/[AppRadius] and [buildAppTheme].
///
/// The name is kept only so the Discovery screens and their widget tests keep
/// compiling. Prefer [buildAppTheme] in new code.
final ThemeData discoveryTheme = buildAppTheme();
