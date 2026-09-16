# Android Manifest — Share Target Setup

Add this `intent-filter` inside the `<activity>` block of
`android/app/src/main/AndroidManifest.xml` (the existing launcher activity,
usually named `.MainActivity`):

```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="image/*" />
</intent-filter>
```

This is what makes "ScreenBridge" appear in the native Android Share Sheet
whenever the user shares an image (including screenshots) from the gallery,
Photos app, or the screenshot's own share prompt.

No other manifest changes are needed — `receive_sharing_intent` handles the
rest via the `ShareIntentHandler` class in `lib/services/`.
