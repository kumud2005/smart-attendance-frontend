//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_onnxruntime/flutter_onnxruntime_plugin.h>
#include <geolocator_windows/geolocator_windows.h>
#include <public_file_saver/public_file_saver_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterOnnxruntimePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterOnnxruntimePlugin"));
  GeolocatorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GeolocatorWindows"));
  PublicFileSaverPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PublicFileSaverPluginCApi"));
}
