package com.aiassistant.pro.ui.components

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.aiassistant.pro.data.model.AIService

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun AIWebView(
    service: AIService,
    onLoadingChanged: (Boolean) -> Unit,
    onUrlChanged: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var webView: WebView? by remember { mutableStateOf(null) }
    var isLoading by remember { mutableStateOf(false) }
    var hasError by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf("") }
    
    // Update loading state
    LaunchedEffect(isLoading) {
        onLoadingChanged(isLoading)
    }
    
    // Reload when service changes
    LaunchedEffect(service.url) {
        webView?.loadUrl(service.url)
        hasError = false
        errorMessage = ""
    }
    
    Box(modifier = modifier) {
        AndroidView(
            factory = { context ->
                WebView(context).apply {
                    webViewClient = object : WebViewClient() {
                        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                            super.onPageStarted(view, url, favicon)
                            isLoading = true
                            url?.let { onUrlChanged(it) }
                        }
                        
                        override fun onPageFinished(view: WebView?, url: String?) {
                            super.onPageFinished(view, url)
                            isLoading = false
                            
                            // Inject custom JavaScript for better integration
                            view?.evaluateJavascript(
                                """
                                // Prevent context menu on long press
                                document.addEventListener('contextmenu', function(e) {
                                    e.preventDefault();
                                });
                                
                                // Handle file input clicks
                                document.addEventListener('click', function(e) {
                                    if (e.target.type === 'file') {
                                        // File input detected
                                        Android.onFileInputClick();
                                    }
                                });
                                
                                // Enhance mobile experience
                                var viewport = document.querySelector('meta[name=viewport]');
                                if (!viewport) {
                                    viewport = document.createElement('meta');
                                    viewport.name = 'viewport';
                                    document.getElementsByTagName('head')[0].appendChild(viewport);
                                }
                                viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                                """.trimIndent(),
                                null
                            )
                        }
                        
                        override fun onReceivedError(
                            view: WebView?,
                            request: WebResourceRequest?,
                            error: WebResourceError?
                        ) {
                            super.onReceivedError(view, request, error)
                            isLoading = false
                            hasError = true
                            errorMessage = error?.description?.toString() ?: "Unknown error"
                        }
                        
                        override fun shouldOverrideUrlLoading(
                            view: WebView?,
                            request: WebResourceRequest?
                        ): Boolean {
                            // Allow navigation within the same domain
                            val url = request?.url?.toString() ?: return false
                            val serviceDomain = service.url.substringAfter("://").substringBefore("/")
                            val requestDomain = url.substringAfter("://").substringBefore("/")
                            
                            return if (requestDomain.contains(serviceDomain) || serviceDomain.contains(requestDomain)) {
                                false // Allow navigation
                            } else {
                                // External link, could open in external browser
                                true
                            }
                        }
                    }
                    
                    webChromeClient = object : WebChromeClient() {
                        override fun onPermissionRequest(request: PermissionRequest?) {
                            // Handle permissions for camera, microphone, etc.
                            request?.grant(request.resources)
                        }
                        
                        override fun onShowFileChooser(
                            webView: WebView?,
                            filePathCallback: ValueCallback<Array<Uri>>?,
                            fileChooserParams: FileChooserParams?
                        ): Boolean {
                            // Handle file selection
                            // This would need to be implemented with proper file picker
                            return true
                        }
                        
                        override fun onGeolocationPermissionsShowPrompt(
                            origin: String?,
                            callback: GeolocationPermissions.Callback?
                        ) {
                            // Handle location permissions
                            callback?.invoke(origin, false, false)
                        }
                    }
                    
                    settings.apply {
                        javaScriptEnabled = true
                        domStorageEnabled = true
                        databaseEnabled = true
                        allowFileAccess = true
                        allowContentAccess = true
                        allowFileAccessFromFileURLs = false
                        allowUniversalAccessFromFileURLs = false
                        mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                        cacheMode = WebSettings.LOAD_DEFAULT
                        userAgentString = userAgentString?.replace("; wv", "") // Remove webview identifier
                        
                        // Enable modern web features
                        setSupportZoom(true)
                        builtInZoomControls = true
                        displayZoomControls = false
                        useWideViewPort = true
                        loadWithOverviewMode = true
                        
                        // Media settings
                        mediaPlaybackRequiresUserGesture = false
                        setSupportMultipleWindows(false)
                    }
                    
                    // Add JavaScript interface for communication
                    addJavascriptInterface(object {
                        @JavascriptInterface
                        fun onFileInputClick() {
                            // Handle file input clicks
                        }
                        
                        @JavascriptInterface
                        fun log(message: String) {
                            // Handle JavaScript console logs
                        }
                    }, "Android")
                    
                    webView = this
                    loadUrl(service.url)
                }
            },
            update = { webView ->
                // Update WebView if needed
            },
            modifier = Modifier.fillMaxSize()
        )
        
        // Error state overlay
        if (hasError) {
            Card(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(16.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Connection Error",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = errorMessage.ifEmpty { "Failed to load ${service.displayName}" },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = {
                            hasError = false
                            errorMessage = ""
                            webView?.reload()
                        }
                    ) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}