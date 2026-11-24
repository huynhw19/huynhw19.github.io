/* ConfigKit site-wide privacy and consent manager. No advertising or analytics trackers are installed by this script. */
(() => {
  'use strict';
  const KEY = 'configkit-cookie-consent-v2';
  const OLD_KEY = 'configkit-cookie-consent-v1';
  const defaults = { essential: true, preferences: false, externalMedia: false };
  let consent = null;
  try {
    consent = JSON.parse(localStorage.getItem(KEY) || 'null');
    if (!consent) {
      const old = JSON.parse(localStorage.getItem(OLD_KEY) || 'null');
      if (old && old.version === 1 && old.categories) {
        consent = { version: 2, updatedAt: old.updatedAt || new Date().toISOString(), categories: { essential: true, preferences: !!old.categories.preferences, externalMedia: !!old.categories.externalMedia } };
        localStorage.setItem(KEY, JSON.stringify(consent));
      }
    }
  } catch (_) {}
  if (!consent || consent.version !== 2 || !consent.categories) consent = null;

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
    <p>ConfigKit uses essential browser storage for security and core features. You can choose whether to allow optional preferences and external media. We do not use advertising or analytics cookies.</p>
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
      <div class="ck-actions"><button type="button" class="ck-primary" data-action="save">Save my choices</button></div>
    </div>`;
  document.body.append(banner);
  const options = banner.querySelector('.ck-options');
  const pref = banner.querySelector('[data-category="preferences"]');
  const media = banner.querySelector('[data-category="externalMedia"]');

  function allowed(category) { return category === 'essential' || !!consent?.categories?.[category]; }
  function publish() {
    window.ConfigKitConsent = {
      get: () => consent ? JSON.parse(JSON.stringify(consent.categories)) : null,
      has: allowed,
      open: () => openSettings(),
      reset: () => { try { localStorage.removeItem(KEY); localStorage.removeItem(OLD_KEY); } catch (_) {} consent = null; banner.hidden = false; options.hidden = true; scanMedia(); },
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
  function openSettings() {
    banner.hidden = false; options.hidden = false;
    pref.checked = allowed('preferences'); media.checked = allowed('externalMedia');
    banner.scrollIntoView({behavior:'smooth',block:'nearest'});
  }
  function save(preferences, externalMedia) {
    consent = {version:2,updatedAt:new Date().toISOString(),categories:{...defaults,preferences:!!preferences,externalMedia:!!externalMedia}};
    try { localStorage.setItem(KEY,JSON.stringify(consent)); localStorage.removeItem(OLD_KEY); } catch (_) {}
    banner.hidden = true; options.hidden = true; publish(); scanMedia();
    window.dispatchEvent(new CustomEvent('configkit:consentchange',{detail:consent.categories}));
  }
  banner.addEventListener('click', event => {
    const action = event.target.closest('button')?.dataset.action;
    if (action === 'accept') save(true,true);
    if (action === 'reject') save(false,false);
    if (action === 'customize') { options.hidden = !options.hidden; pref.checked = allowed('preferences'); media.checked = allowed('externalMedia'); }
    if (action === 'save') save(pref.checked,media.checked);
  });
  document.addEventListener('click', event => {
    const link = event.target.closest('a[href="#cookie-settings"],[data-cookie-settings]');
    if (link) { event.preventDefault(); openSettings(); }
  });
  publish();
  if (consent) { banner.hidden = true; scanMedia(); }
  else banner.hidden = false;
})();
