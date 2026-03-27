// Better Anonymity - Firefox Hardening Profile
// Ported from Legacy v0.1

// --- PREPARATION ---
user_pref("browser.aboutConfig.showWarning", false);

// --- STARTUP / SHUTDOWN ---
user_pref("browser.startup.page", 0); // Start with a blank page
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.newtabpage.enabled", false);
user_pref("privacy.sanitize.sanitizeOnShutdown", true); // Clear all data on shutdown
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.offlineApps", true);
user_pref("privacy.clearOnShutdown.sessions", true);
user_pref("privacy.clearOnShutdown.openWindows", true);

// --- TELEMETRY / DATA COLLECTION ---
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);

// --- SAFE BROWSING ---
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);

// --- FINGERPRINTING RESISTANCE / WEB METRICS ---
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("dom.battery.enabled", false);
user_pref("browser.startup.blankWindow", true);
user_pref("browser.display.use_system_colors", false);
user_pref("media.video_stats.enabled", false);

// --- WEBRTC (Prevent native IP leaks over VPN/Tor) ---
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.use_document_iceservers", false);
user_pref("media.peerconnection.video.enabled", false);
user_pref("media.peerconnection.identity.timeout", 1);
user_pref("media.peerconnection.turn.disable", true);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);

// --- DOM / HTML5 STORAGE ---
user_pref("dom.storage.enabled", false); // Break heavily tracked apps via localStorage
user_pref("dom.caches.enabled", false);
user_pref("browser.sessionstore.privacy_level", 2); // Never save passwords or states
user_pref("beacon.enabled", false); // Disable pinging on tab close

// --- NETWORK / CACHE / DNS ---
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-connection", false);
user_pref("browser.places.speculativeConnect.enabled", false);
user_pref("network.predictor.enabled", false);
user_pref("network.predictor.enable-prefetch", false);

// Referers
user_pref("network.http.referer.XOriginPolicy", 2); // Only send referrers when hosts match
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

// --- SEARCH / SUGGESTIONS ---
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);

// --- GEO-LOCATION / SENSORS ---
user_pref("geo.enabled", false);
user_pref("geo.wifi.uri", "http://127.0.0.1/");
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);

// --- PASSWORDS ---
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("browser.formfill.enable", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// --- PLUGINS / DRM ---
user_pref("media.gmp-widevinecdm.visible", false);
user_pref("media.gmp-widevinecdm.enabled", false);
user_pref("media.eme.enabled", false);

// --- EXPERIMENTS / POCKET ---
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
user_pref("messaging-system.rsexperimentloader.enabled", false);

// --- END PROFILE ---
