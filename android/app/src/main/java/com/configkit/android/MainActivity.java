package com.configkit.android;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import com.posthog.android.PostHogAndroid;

import java.io.OutputStream;
import java.util.ArrayList;

public class MainActivity extends Activity {
    private static final String HOME = "https://huynhw19.github.io/";
    private static final int FILE_CHOOSER_REQUEST = 1001;
    private static final int DOWNLOAD_REQUEST = 1002;

    private WebView webView;
    private ValueCallback<Uri[]> fileChooserCallback;
    private byte[] pendingDownload;
    private String pendingFilename;
    private String pendingMimeType;

    private final class DownloadBridge {
        @JavascriptInterface
        public void saveBase64(String encoded, String filename, String mimeType) {
            try {
                pendingDownload = Base64.decode(encoded, Base64.DEFAULT);
                pendingFilename = safeFilename(filename);
                pendingMimeType = (mimeType == null || mimeType.isEmpty())
                    ? "application/octet-stream" : mimeType;
                runOnUiThread(() -> {
                    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType(pendingMimeType);
                    intent.putExtra(Intent.EXTRA_TITLE, pendingFilename);
                    startActivityForResult(intent, DOWNLOAD_REQUEST);
                });
            } catch (Exception error) {
                runOnUiThread(() -> Toast.makeText(MainActivity.this,
                    "Could not prepare the download.", Toast.LENGTH_LONG).show());
            }
        }
    }

    private String safeFilename(String name) {
        if (name == null || name.trim().isEmpty()) return "ConfigKit-download";
        return name.replaceAll("[\\\\/:*?\"<>|]", "_");
    }

    private boolean isConfigKitHost(Uri uri) {
        return "https".equalsIgnoreCase(uri.getScheme())
            && "huynhw19.github.io".equalsIgnoreCase(uri.getHost());
    }

    private void captureEvent(String event) {
        if (!BuildConfig.POSTHOG_API_KEY.isEmpty() && !BuildConfig.POSTHOG_HOST.isEmpty()) {
            PostHogAndroid.getInstance().capture(event);
        }
    }

    private void logForPostHog(String message) {
        if (!BuildConfig.POSTHOG_API_KEY.isEmpty() && !BuildConfig.POSTHOG_HOST.isEmpty()) {
            PostHogAndroid.getInstance().getLogger().info(message, null);
        }
    }

    private void installSiteDownloadBridge() {
        webView.removeJavascriptInterface("ConfigKitFiles");
        webView.addJavascriptInterface(new DownloadBridge(), "ConfigKitFiles");
        String script = "(function(){"
            + "if(window.__configKitDownloadHook)return;"
            + "window.__configKitDownloadHook=true;"
            + "document.addEventListener('click',function(event){"
            + "var link=event.target.closest&&event.target.closest('a[download]');"
            + "if(!link||!link.href||!link.href.startsWith('blob:'))return;"
            + "event.preventDefault();"
            + "fetch(link.href).then(function(r){return r.blob();}).then(function(blob){"
            + "var reader=new FileReader();"
            + "reader.onloadend=function(){var value=String(reader.result);"
            + "var comma=value.indexOf(',');"
            + "if(comma>=0&&window.ConfigKitFiles){"
            + "window.ConfigKitFiles.saveBase64(value.slice(comma+1),link.download||'ConfigKit-download',blob.type);}};"
            + "reader.readAsDataURL(blob);"
            + "}).catch(function(){console.error('ConfigKit download failed');});"
            + "},true);})();";
        webView.evaluateJavascript(script, null);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        webView = new WebView(this);
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.getSettings().setAllowFileAccess(false);
        webView.getSettings().setAllowContentAccess(false);
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                    WebChromeClient.FileChooserParams params) {
                if (fileChooserCallback != null) fileChooserCallback.onReceiveValue(null);
                fileChooserCallback = callback;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                return true;
            }
        });
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (!isConfigKitHost(uri)) view.removeJavascriptInterface("ConfigKitFiles");
                // Keep HTTPS navigation in the WebView so hosted OAuth redirects
                // can complete. Never load plaintext HTTP or custom schemes.
                return !"https".equalsIgnoreCase(uri.getScheme());
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                Uri uri = Uri.parse(url);
                if (isConfigKitHost(uri)) installSiteDownloadBridge();
                else view.removeJavascriptInterface("ConfigKitFiles");
            }
        });
        setContentView(webView);
        logForPostHog("ConfigKit WebView shell initialized");
        if (savedInstanceState == null) webView.loadUrl(HOME);
        else webView.restoreState(savedInstanceState);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == FILE_CHOOSER_REQUEST && fileChooserCallback != null) {
            Uri[] results = null;
            if (resultCode == RESULT_OK && data != null) {
                if (data.getClipData() != null) {
                    ArrayList<Uri> uris = new ArrayList<>();
                    for (int i = 0; i < data.getClipData().getItemCount(); i++)
                        uris.add(data.getClipData().getItemAt(i).getUri());
                    results = uris.toArray(new Uri[0]);
                } else if (data.getData() != null) results = new Uri[]{data.getData()};
            }
            fileChooserCallback.onReceiveValue(results);
            if (results != null) {
                captureEvent("file_upload_selected");
                logForPostHog("File upload selection returned to the WebView");
            }
            fileChooserCallback = null;
        } else if (requestCode == DOWNLOAD_REQUEST) {
            if (resultCode == RESULT_OK && data != null && data.getData() != null && pendingDownload != null) {
                try (OutputStream output = getContentResolver().openOutputStream(data.getData())) {
                    if (output == null) throw new IllegalStateException("No output stream");
                    output.write(pendingDownload);
                    captureEvent("file_download_saved");
                    logForPostHog("WebView download written to Android storage");
                    Toast.makeText(this, "Download saved.", Toast.LENGTH_LONG).show();
                } catch (Exception error) {
                    Toast.makeText(this, "Could not save the download.", Toast.LENGTH_LONG).show();
                }
            }
            pendingDownload = null;
            pendingFilename = null;
            pendingMimeType = null;
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (webView != null) webView.saveState(outState);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        if (fileChooserCallback != null) fileChooserCallback.onReceiveValue(null);
        if (webView != null) webView.destroy();
        super.onDestroy();
    }
}
