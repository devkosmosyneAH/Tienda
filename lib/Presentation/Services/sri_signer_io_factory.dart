import 'package:flutter/foundation.dart';

import 'sri_signer.dart';
import 'sri_signer_native.dart';

SriSigner createSriSigner(TargetPlatform platform) {
  if (platform == TargetPlatform.windows ||
      platform == TargetPlatform.android) {
    return SriNativeSigner();
  }
  return SriUnsupportedSigner();
}
