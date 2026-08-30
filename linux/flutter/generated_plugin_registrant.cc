//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_onnxruntime/flutter_onnxruntime_plugin.h>
#include <public_file_saver/public_file_saver_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) flutter_onnxruntime_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterOnnxruntimePlugin");
  flutter_onnxruntime_plugin_register_with_registrar(flutter_onnxruntime_registrar);
  g_autoptr(FlPluginRegistrar) public_file_saver_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PublicFileSaverPlugin");
  public_file_saver_plugin_register_with_registrar(public_file_saver_registrar);
}
