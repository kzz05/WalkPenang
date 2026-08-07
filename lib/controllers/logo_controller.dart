/// Controller for the branding splash.
///
/// Owns how long the logo stays on screen; the view only paints it.
class LogoController {
  static const splashDuration = Duration(milliseconds: 3000);

  Future<void> waitForSplash() => Future.delayed(splashDuration);
}
