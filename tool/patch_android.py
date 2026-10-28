"""Дописывает в сгенерированный `flutter create` Android-проект то, что нужно
для напоминаний: desugaring, разрешения, ресиверы, название и иконку."""
import pathlib
import re
import shutil

root = pathlib.Path(__file__).resolve().parent.parent
app = root / "android" / "app"

# --- build.gradle(.kts): core library desugaring для flutter_local_notifications
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"
if kts.exists():
    s = kts.read_text()
    if "isCoreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(s)
else:
    s = groovy.read_text()
    if "coreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(s)

# --- постоянный ключ подписи: обновления ставятся поверх, данные сохраняются
KS_PASS = "0u68dsiRJbyxbDsaMbNVp8uu"
if kts.exists():
    s = kts.read_text()
    if 'create("murochka")' not in s:
        block = (
            '    signingConfigs {\n'
            '        create("murochka") {\n'
            '            storeFile = file("../../tool/murochka.jks")\n'
            f'            storePassword = "{KS_PASS}"\n'
            '            keyAlias = "murochka"\n'
            f'            keyPassword = "{KS_PASS}"\n'
            '        }\n'
            '    }\n\n'
            '    buildTypes {'
        )
        s = s.replace("    buildTypes {", block, 1)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("murochka")')
        kts.write_text(s)
else:
    s = groovy.read_text()
    if "murochka.jks" not in s:
        block = (
            "    signingConfigs {\n"
            "        murochka {\n"
            "            storeFile file('../../tool/murochka.jks')\n"
            f"            storePassword '{KS_PASS}'\n"
            "            keyAlias 'murochka'\n"
            f"            keyPassword '{KS_PASS}'\n"
            "        }\n"
            "    }\n\n"
            "    buildTypes {"
        )
        s = s.replace("    buildTypes {", block, 1)
        s = s.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.murochka")
        groovy.write_text(s)

# --- R8: не вырезать типы Gson, иначе плагин уведомлений не может
# сохранить расписание ("Missing type parameter")
(app / "proguard-rules.pro").write_text("""
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-keep class com.dexterous.** { *; }
-dontwarn com.google.gson.**
""")
if kts.exists():
    s = kts.read_text()
    if 'proguard-rules.pro' not in s:
        s = s.replace('signingConfig = signingConfigs.getByName("murochka")',
                      'signingConfig = signingConfigs.getByName("murochka")\n'
                      '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', 1)
        kts.write_text(s)
else:
    s = groovy.read_text()
    if 'proguard-rules.pro' not in s:
        s = s.replace("signingConfig signingConfigs.murochka",
                      "signingConfig signingConfigs.murochka\n"
                      "            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'", 1)
        groovy.write_text(s)

# --- AndroidManifest.xml
mf = app / "src" / "main" / "AndroidManifest.xml"
m = mf.read_text()
m = re.sub(r'android:label="[^"]*"', 'android:label="Мурочка"', m, count=1)
perms = """
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
"""
receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
if "POST_NOTIFICATIONS" not in m:
    m = re.sub(r"(<manifest[^>]*>)", r"\1" + perms.replace("\\", "\\\\"), m, count=1)
if "ScheduledNotificationReceiver" not in m:
    m = m.replace("</application>", receivers + "    </application>", 1)
if "showWhenLocked" not in m:
    m = m.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"', 1)
mf.write_text(m)

# --- иконка-клубок
res = app / "src" / "main" / "res"
for dens in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    src = root / "tool" / "icons" / f"ic_launcher_{dens}.png"
    dst = res / f"mipmap-{dens}" / "ic_launcher.png"
    if src.exists() and dst.parent.exists():
        shutil.copy(src, dst)

kt = (kts.read_text() if kts.exists() else groovy.read_text())
assert "murochka" in kt and ("getByName(\"murochka\")" in kt or "signingConfigs.murochka" in kt), "signing not patched"
assert "proguard-rules.pro" in kt, "proguard not patched"
print("Android patched")
