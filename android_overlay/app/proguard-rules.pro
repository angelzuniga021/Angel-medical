# JCA selects provider implementations by class name at runtime.
# Preserve their names and constructors in the release APK.
-keep class org.bouncycastle.jcajce.provider.** { *; }
