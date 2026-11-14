# android/app/proguard-rules.pro
# AGP 9 bật R8 full mode: class khởi tạo qua reflection bị xoá constructor mặc định
# → crash lúc mở app bản release (NoSuchMethodException ...<init> []).

# Room / WorkManager (plugin workmanager) — WorkDatabase_Impl tạo bằng reflection
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }

# Firebase ComponentRegistrar — ComponentDiscovery tạo bằng reflection
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# AndroidX Startup initializers
-keep class * implements androidx.startup.Initializer { <init>(); }
