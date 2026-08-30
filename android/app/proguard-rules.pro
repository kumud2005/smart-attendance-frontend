# ============================================================
# GOOGLE ML KIT
# Used by QR scanning and face/liveness analysis.
# ML Kit registrars/classes are accessed reflectively.
# ============================================================

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**


# ============================================================
# ONNX RUNTIME
# CRITICAL:
# ONNX Runtime JNI looks up ai.onnxruntime Java classes/methods.
# R8 must not remove or rename them.
# ============================================================

-keep class ai.onnxruntime.** { *; }


# ============================================================
# REFLECTION / JNI METADATA
# ============================================================

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod