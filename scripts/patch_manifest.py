#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""تعديل AndroidManifest.xml لإضافة الأذونات والإشعارات"""
from pathlib import Path

p = Path("android/app/src/main/AndroidManifest.xml")
if not p.exists():
    raise SystemExit("AndroidManifest.xml غير موجود")

s = p.read_text()

# 1) الأذونات
permissions = [
    '    <uses-permission android:name="android.permission.INTERNET"/>',
    '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>',
    '    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
    '    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>',
    '    <uses-permission android:name="android.permission.CAMERA"/>',
    '    <uses-permission android:name="android.permission.VIBRATE"/>',
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    '    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>',
    '    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>',
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    '    <uses-permission android:name="android.permission.WAKE_LOCK"/>',
]
missing = [x for x in permissions if x not in s]
if missing:
    marker = '<application'
    if marker not in s:
        raise SystemExit("لم أجد application")
    s = s.replace(marker, '\n'.join(missing) + '\n    ' + marker, 1)

# 2) usesCleartextTraffic
if 'usesCleartextTraffic=' not in s:
    s = s.replace('<application', '<application android:usesCleartextTraffic="true"', 1)

# 3) Deep link
if 'android:scheme="kitabi"' not in s:
    intent = (
        '\n                  <intent-filter>\n'
        '                      <action android:name="android.intent.action.VIEW" />\n'
        '                      <category android:name="android.intent.category.DEFAULT" />\n'
        '                      <category android:name="android.intent.category.BROWSABLE" />\n'
        '                      <data android:scheme="kitabi" android:host="auth" />\n'
        '                  </intent-filter>\n              '
    )
    marker = '</activity>'
    if marker not in s:
        raise SystemExit("لم أجد activity")
    s = s.replace(marker, intent + marker, 1)

# 4) Receivers للإشعارات
if 'ScheduledNotificationReceiver' not in s:
    receivers = (
        '\n        '
        '<receiver android:exported="false" '
        'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
        '        '
        '<receiver android:exported="false" '
        'android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n    '
    )
    marker = '</application>'
    if marker not in s:
        raise SystemExit("لم أجد application")
    s = s.replace(marker, receivers + marker, 1)

p.write_text(s)
print("✅ تم تعديل AndroidManifest.xml بنجاح")
