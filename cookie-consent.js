/* ConfigKit site-wide privacy and consent manager. Optional analytics loads only after explicit consent. */
(() => {
  'use strict';
  const KEY = 'configkit-cookie-consent-v3';
  const OLD_KEY = 'configkit-cookie-consent-v2';
  const LEGACY_KEY = 'configkit-cookie-consent-v1';
  const defaults = { essential: true, preferences: false, externalMedia: false, analytics: false };
  let consent = null;
  try {
    consent = JSON.parse(localStorage.getItem(KEY) || 'null');
  } catch (_) {}
  if (!consent || consent.version !== 3 || !consent.categories) consent = null;

  const styles = `
    #ck-consent-banner{position:fixed;z-index:2147483000;left:16px;right:16px;bottom:16px;max-width:980px;margin:auto;padding:18px;background:#fff;color:#17231f;border:1px solid #dce7df;border-radius:16px;box-shadow:0 18px 55px rgba(15,35,25,.24);font:15px/1.55 system-ui,-apple-system,"Segoe UI",sans-serif}
    #ck-consent-banner[hidden]{display:none}#ck-consent-banner h2{font-size:1.12rem;margin:0 0 5px}#ck-consent-banner p{margin:0 0 8px;color:#586b61}#ck-consent-banner a{color:#176344;font-weight:650}
    #ck-consent-banner .ck-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}#ck-consent-banner button{cursor:pointer;font:inherit;font-weight:700;padding:9px 13px;border:1px solid #dce7df;border-radius:9px;background:#fff;color:#17231f}
    #ck-consent-banner button.ck-primary{background:#176344;color:#fff;border-color:#176344}
    #ck-consent-banner .ck-options{border-top:1px solid #e4eae6;margin-top:12px;padding-top:12px;display:grid;gap:9px}#ck-consent-banner .ck-options[hidden]{display:none}
    #ck-consent-banner label{display:flex;gap:9px;align-items:flex-start}#ck-consent-banner input{margin-top:5px;accent-color:#176344}
    .ck-media-blocked{display:grid;place-items:center;min-height:150px;padding:20px;text-align:center;background:#edf4ef;color:#31483b;border:1px solid #dce7df;border-radius:12px;font:14px/1.5 system-ui,sans-serif}
    .ck-media-blocked button{margin-top:9px;padding:8px 12px;border:1px solid #176344;border-radius:8px;background:#176344;color:#fff;font:inherit;font-weight:650;cursor:pointer}
    @media(max-width:650px){#ck-consent-banner{left:9px;right:9px;bottom:9px;padding:15px}#ck-consent-banner .ck-actions button{flex:1 1 130px}}
  `;
  const style = document.createElement('style'); style.textContent = styles; document.head.append(style);
  const banner = document.createElement('section');
  banner.id = 'ck-consent-banner'; banner.hidden = true; banner.setAttribute('role','region'); banner.setAttribute('aria-label','Cookie and privacy choices');
  banner.innerHTML = `
    <h2>🍪 Your privacy choices</h2>
    <p>ConfigKit uses essential browser storage for security and core features. You can separately choose optional preferences, external media and privacy-friendly analytics. Analytics is off unless you opt in.</p>
    <p><a href="/privacy.html#cookies">Read the Privacy Policy</a></p>
    <div class="ck-actions">
      <button type="button" data-action="reject">Reject optional</button>
      <button type="button" data-action="customize">Customize</button>
      <button type="button" class="ck-primary" data-action="accept">Accept all</button>
    </div>
    <div class="ck-options" hidden>
      <strong>Optional categories</strong>
      <label><input type="checkbox" checked disabled><span><strong>Essential</strong> — remembers this choice and supports core site/security functions. Always active.</span></label>
      <label><input type="checkbox" data-category="preferences"><span><strong>Preferences</strong> — remembers choices such as your selected language where supported.</span></label>
      <label><input type="checkbox" data-category="externalMedia"><span><strong>External media</strong> — loads embedded content, such as videos and maps, from third-party providers.</span></label>
      <label><input type="checkbox" data-category="analytics"><span><strong>Anonymous analytics (optional)</strong> — counts page visits and page paths so we can improve ConfigKit. No names, emails, grades, form contents, clicks or session recordings are collected.</span></label>
      <div class="ck-actions"><button type="button" class="ck-primary" data-action="save">Save my choices</button></div>
    </div>`;
  document.body.append(banner);
  const launcher = document.createElement('a');
  launcher.href = '#cookie-settings'; launcher.setAttribute('data-cookie-settings','');
  launcher.textContent = 'Cookie settings';
  launcher.style.cssText = 'position:fixed;z-index:999;right:12px;bottom:12px;padding:7px 10px;border:1px solid #dce7df;border-radius:999px;background:#fff;color:#176344;font:600 12px/1.3 system-ui,sans-serif;text-decoration:none;box-shadow:0 3px 12px rgba(0,0,0,.12)';
  document.body.append(launcher);
  const options = banner.querySelector('.ck-options');
  const pref = banner.querySelector('[data-category="preferences"]');
  const media = banner.querySelector('[data-category="externalMedia"]');
  const analytics = banner.querySelector('[data-category="analytics"]');

  function allowed(category) { return category === 'essential' || !!consent?.categories?.[category]; }
  function publish() {
    window.ConfigKitConsent = {
      get: () => consent ? JSON.parse(JSON.stringify(consent.categories)) : null,
      has: allowed,
      open: () => openSettings(),
      reset: () => { try { localStorage.removeItem(KEY); localStorage.removeItem(OLD_KEY); localStorage.removeItem(LEGACY_KEY); } catch (_) {} consent = null; banner.hidden = false; options.hidden = true; scanMedia(); stopAnalytics(); },
      onChange: (callback) => { window.addEventListener('configkit:consentchange', () => callback(window.ConfigKitConsent.get())); }
    };
  }
  function scanMedia() {
    document.querySelectorAll('iframe[data-cookie-src],img[data-cookie-src]').forEach(el => {
      const src = el.getAttribute('data-cookie-src');
      if (!src) return;
      if (allowed('externalMedia')) {
        if (!el.getAttribute('src')) el.setAttribute('src', src);
        const placeholder = el.previousElementSibling;
        if (placeholder?.classList.contains('ck-media-blocked')) placeholder.remove();
      } else {
        if (el.hasAttribute('src')) el.removeAttribute('src');
        if (!el.previousElementSibling?.classList.contains('ck-media-blocked')) {
          const holder = document.createElement('div'); holder.className = 'ck-media-blocked';
          const content = document.createElement('div');
          const message = document.createElement('div'); message.textContent = 'This content is hosted by an external provider and has not been loaded.';
          const button = document.createElement('button'); button.type = 'button'; button.textContent = 'Review external media settings'; button.addEventListener('click', openSettings);
          content.append(message, button); holder.append(content); el.parentNode.insertBefore(holder, el);
        }
      }
    });
  }

  function capturePageView() {
    if (!allowed('analytics') || !window.posthog || typeof window.posthog.capture !== 'function') return;
    const cleanPath = window.location.pathname || '/';
    window.posthog.capture('$pageview', {
      $current_url: window.location.origin + cleanPath,
      $pathname: cleanPath
    });
  }
  function stopAnalytics() {
    if (window.__configKitPosthogReady && window.posthog) {
      try { window.posthog.opt_out_capturing(); window.posthog.reset(); } catch (_) {}
    }
  }
  function startAnalytics() {
    if (!allowed('analytics')) return;
    if (window.__configKitPosthogReady) {
      try { window.posthog.opt_in_capturing(); capturePageView(); } catch (_) {}
      return;
    }
    const configScript = document.createElement('script');
    configScript.src = '/posthog-config.js';
    configScript.onload = () => {
      const config = window.CONFIGKIT_POSTHOG;
      if (!config || !config.token || !config.apiHost) return;
      (function (t, e) {
        var o, n, p, r;
        e.__SV || (window.posthog = e, e._i = [], e.init = function (i, s, a) {
          function g(t, e) {
            var o = e.split('.');
            2 === o.length && (t = t[o[0]], e = o[1]);
            t[e] = function () { t.push([e].concat(Array.prototype.slice.call(arguments, 0))); };
          }
          p = t.createElement('script'); p.type = 'text/javascript'; p.crossOrigin = 'anonymous'; p.async = true;
          p.src = s.api_host.replace('.i.posthog.com', '-assets.i.posthog.com').replace('.posthog.com', '-assets.posthog.com') + '/static/array.js';
          r = t.getElementsByTagName('script')[0]; r.parentNode.insertBefore(p, r);
          var u = e;
          void 0 !== a ? u = e[a] = [] : a = 'posthog';
          u.people = u.people || [];
          u.toString = function (t) { var e = 'posthog'; 'posthog' !== a && (e += '.' + a); return t || (e += ' (stub)'), e; };
          u.people.toString = function () { return u.toString(1) + '.people (stub)'; };
          o = 'init capture register register_once unregister unregister_for_session opt_out_capturing opt_in_capturing reset get_distinct_id get_session_id get_property'.split(' ');
          for (n = 0; n < o.length; n++) g(u, o[n]);
          e._i.push([i, s, a]);
        }, e.__SV = 1);
      })(document, window.posthog || []);
      window.posthog.init(config.token, {
        api_host: config.apiHost,
        defaults: '2026-08-30',
        autocapture: false,
        capture_pageview: false,
        capture_pageleave: false,
        disable_session_recording: true,
        disable_surveys: true,
        capture_heatmaps: false,
        capture_performance: false,
        person_profiles: 'identified_only',
        persistence: 'localStorage',
        respect_dnt: true,
        before_send: function (event) {
          if (!event || !event.properties) return event;
          const props = event.properties;
          ['$referrer', '$referring_domain', '$initial_referrer', '$initial_referring_domain', '$entry_current_url', '$initial_current_url', '$search_engine'].forEach(key => { delete props[key]; });
          if (props.$current_url) props.$current_url = window.location.origin + (window.location.pathname || '/');
          if (props.$pathname) props.$pathname = window.location.pathname || '/';
          return event;
        }
      });
      window.__configKitPosthogReady = true;
      capturePageView();
    };
    configScript.onerror = () => console.warn('ConfigKit analytics configuration could not be loaded.');
    document.head.append(configScript);
  }
  function syncAnalytics() {
    if (allowed('analytics')) startAnalytics();
    else stopAnalytics();
  }

  function openSettings() {
    banner.hidden = false; options.hidden = false;
    pref.checked = allowed('preferences'); media.checked = allowed('externalMedia'); analytics.checked = allowed('analytics');
    banner.scrollIntoView({behavior:'smooth',block:'nearest'});
  }
  function save(preferences, externalMedia, analyticsChoice) {
    consent = {version:3,updatedAt:new Date().toISOString(),categories:{...defaults,preferences:!!preferences,externalMedia:!!externalMedia,analytics:!!analyticsChoice}};
    try { localStorage.setItem(KEY,JSON.stringify(consent)); localStorage.removeItem(OLD_KEY); } catch (_) {}
    banner.hidden = true; options.hidden = true; publish(); scanMedia(); syncAnalytics();
    window.dispatchEvent(new CustomEvent('configkit:consentchange',{detail:consent.categories}));
  }
  // Bind each consent action directly. This avoids delegated-click edge cases
  // on mobile browsers and ensures the Save button always closes the banner.
  banner.querySelectorAll('button[data-action]').forEach(button => {
    button.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();
      const action = button.dataset.action;
      if (action === 'accept') save(true,true,true);
      else if (action === 'reject') save(false,false,false);
      else if (action === 'customize') {
        options.hidden = !options.hidden;
        pref.checked = allowed('preferences');
        media.checked = allowed('externalMedia');
        analytics.checked = allowed('analytics');
      } else if (action === 'save') {
        save(pref.checked,media.checked,analytics.checked);
      }
    });
  });
  document.addEventListener('click', event => {
    const link = event.target.closest('a[href="#cookie-settings"],[data-cookie-settings]');
    if (link) { event.preventDefault(); openSettings(); }
  });
  publish();
  if (consent) { banner.hidden = true; scanMedia(); syncAnalytics(); }
  else banner.hidden = false;
})();
