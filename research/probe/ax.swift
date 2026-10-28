import AppKit
import ApplicationServices
print("AXIsProcessTrusted:", AXIsProcessTrusted())
print("CGPreflightScreenCaptureAccess:", CGPreflightScreenCaptureAccess())
for s in NSScreen.screens {
  print("screen", s.localizedName, "frame", s.frame, "scale", s.backingScaleFactor, "auxTR", s.auxiliaryTopRightArea as Any, "safe", s.safeAreaInsets)
}
