# google_mobile_ads가 끌고 오는 WorkManager 2.7.0(Room 2.2.5)은 WorkDatabase_Impl을
# 이름으로 찾아 만든다. R8이 이 클래스를 지워서 릴리스 앱이 시작하자마자 죽었다(2026-10-14).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
