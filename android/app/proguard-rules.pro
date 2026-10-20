# ML Kit text recognition: only the Latin model is included; the plugin
# also references the Chinese / Devanagari / Japanese / Korean ones.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# WorkManager's Room database (created by reflection at app start). R8 removed
# its constructor in 1.0.5 (10) and every phone crashed on launch with
# "NoSuchMethodException: WorkDatabase_Impl.<init>" (2026-10-20).
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(...); }
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep class androidx.work.** { *; }
