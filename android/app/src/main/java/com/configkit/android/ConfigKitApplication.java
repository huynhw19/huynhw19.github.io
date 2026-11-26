package com.configkit.android;

import android.app.Application;

import com.posthog.android.PostHogAndroid;
import com.posthog.android.PostHogAndroidConfig;

public class ConfigKitApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();

        if (BuildConfig.POSTHOG_API_KEY.isEmpty()) {
            if (BuildConfig.DEBUG) {
                throw new IllegalStateException("POSTHOG_API_KEY variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once POSTHOG_API_KEY is configured");
            }
            return;
        }

        if (BuildConfig.POSTHOG_HOST.isEmpty()) {
            if (BuildConfig.DEBUG) {
                throw new IllegalStateException("POSTHOG_HOST variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once POSTHOG_HOST is configured");
            }
            return;
        }

        PostHogAndroidConfig config = new PostHogAndroidConfig(
            BuildConfig.POSTHOG_API_KEY,
            BuildConfig.POSTHOG_HOST
        );
        config.getErrorTrackingConfig().setAutoCapture(true);
        config.getLogs().setServiceName("configkit-android");
        config.getLogs().setEnvironment(BuildConfig.DEBUG ? "development" : "production");

        PostHogAndroid.setup(this, config);
    }
}
