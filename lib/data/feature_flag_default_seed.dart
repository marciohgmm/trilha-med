import '../core/feature_flags/feature_modules.dart';
import '../models/feature_flag_model.dart';

/// Documentos padrão para `platform_feature_flags`.
class FeatureFlagDefaultSeed {
  FeatureFlagDefaultSeed._();

  static List<FeatureFlagModel> defaults() {
    return FeatureModules.all
        .map(FeatureFlagModel.enabledDefault)
        .toList(growable: false);
  }
}
