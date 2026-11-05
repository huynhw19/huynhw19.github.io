// Public browser configuration only. Never put OAuth client secrets here.
// Fill these in after completing AUTH-SETUP.md.
window.CONFIGKIT_AUTH = {
  supabaseUrl: 'https://gwhqnqzzlgslwgijkkpt.supabase.co',
  supabaseAnonKey: 'sb_publishable_qf35m_HhuP-QC_lFVlfmWg_VLPoUY7w',
  // Public Cloudflare Turnstile site key. Keep the corresponding secret in Supabase only.
  turnstileSiteKey: ''
};

// Brand the OAuth page and expose account links only after sign-in.
(() => {
  const isLoginPage = () => /(?:^|\/)login(?:\.html)?$/.test(window.location.pathname);

  const addLoginEnhancements = () => {
    if (!isLoginPage()) return;

    const header = document.querySelector('header');
    if (header && !header.querySelector('.oauth-app-logo')) {
      const logo = document.createElement('img');
      logo.className = 'oauth-app-logo';
      logo.src = 'configkit-oauth-logo.svg';
      logo.alt = 'ConfigKit';
      logo.width = 40;
      logo.height = 40;
      logo.style.cssText = 'width:40px;height:40px;display:inline-block;vertical-align:middle;margin-right:10px;border-radius:12px';
      header.prepend(logo);
    }

    const account = document.getElementById('account');
    if (!account || account.dataset.accountObserver) return;
    account.dataset.accountObserver = 'true';

    const addAccountLinks = () => {
      const dashboardLink = account.querySelector('.dashboard-link');
      const discussionLink = account.querySelector('.builder-discussion-link');
      const settingsLink = account.querySelector('.account-settings-link');
      if (account.hidden) {
        dashboardLink?.remove();
        discussionLink?.remove();
        settingsLink?.remove();
        return;
      }
      if (!dashboardLink) {
        const link = document.createElement('a');
        link.className = 'dashboard-link';
        link.href = 'dashboard.html';
        link.textContent = 'Open dashboard →';
        link.style.cssText = 'display:block;margin-top:8px;font-weight:600';
        account.append(document.createElement('br'), link);
      }
      if (!discussionLink) {
        const link = document.createElement('a');
        link.className = 'builder-discussion-link';
        link.href = 'builder-discussion.html';
        link.textContent = 'Open builder discussion →';
        link.style.cssText = 'display:block;margin-top:8px;font-weight:600';
        account.append(document.createElement('br'), link);
      }
      if (!settingsLink) {
        const link = document.createElement('a');
        link.className = 'account-settings-link';
        link.href = 'account-settings.html';
        link.textContent = 'Account settings →';
        link.style.cssText = 'display:block;margin-top:6px;font-weight:600';
        account.append(document.createElement('br'), link);
      }
    };

    const observer = new MutationObserver(addAccountLinks);
    observer.observe(account, {attributes: true, childList: true, subtree: true});
    addAccountLinks();
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addLoginEnhancements, {once: true});
  } else {
    addLoginEnhancements();
  }
})();

// Add Turnstile verification to the email/password auth flows on the login page.
// Supabase validates the token using the secret configured in its Auth dashboard.
(() => {
  const isLoginPage = () => /(?:^|\/)login(?:\.html)?$/.test(window.location.pathname);
  if (!isLoginPage()) return;

  const config = window.CONFIGKIT_AUTH || {};
  let token = '';
  let widgetId = null;
  let turnstile = null;
  let sdk;

  const resetWidget = () => {
    token = '';
    if (turnstile && widgetId !== null) turnstile.reset(widgetId);
  };

  const withCaptcha = (method, getOptions, setOptions) => async (...args) => {
    turnstileSiteKey: '0x4AAAAAAF0lgF9cPbDl120'
      throw new Error('Email sign-in requires Turnstile setup. Add the site key to auth-config.js and configure CAPTCHA in Supabase.');
    }
    if (!token) throw new Error('Please complete the human verification challenge and try again.');
    const captchaToken = token;
    token = '';
    setOptions(args, captchaToken, getOptions(args));
    try {
      return await method(...args);
    } finally {
      resetWidget();
    }
  };

  const protectClient = client => {
    if (!client?.auth || client.auth.__configKitCaptcha) return client;
    const auth = client.auth;
    auth.__configKitCaptcha = true;
    if (typeof auth.signUp === 'function') {
      const original = auth.signUp.bind(auth);
      auth.signUp = withCaptcha(original, args => args[0]?.options || {}, (args, captchaToken, options) => {
        args[0] = {...args[0], options:{...options, captchaToken}};
      });
    }
    if (typeof auth.signInWithPassword === 'function') {
      const original = auth.signInWithPassword.bind(auth);
      auth.signInWithPassword = withCaptcha(original, args => args[0]?.options || {}, (args, captchaToken, options) => {
        args[0] = {...args[0], options:{...options, captchaToken}};
      });
    }
    if (typeof auth.resetPasswordForEmail === 'function') {
      const original = auth.resetPasswordForEmail.bind(auth);
      auth.resetPasswordForEmail = withCaptcha(original, args => args[1] || {}, (args, captchaToken, options) => {
        args[1] = {...options, captchaToken};
      });
    }
    return client;
  };

  // Supabase's UMD script loads immediately after this config file; wrap its
  // client factory so existing login code receives CAPTCHA-protected methods.
  try {
    Object.defineProperty(window, 'supabase', {
      configurable: true,
      get: () => sdk,
      set: value => {
        sdk = value;
        if (value?.createClient && !value.createClient.__configKitCaptcha) {
          const createClient = value.createClient.bind(value);
          const wrapped = (...args) => protectClient(createClient(...args));
          wrapped.__configKitCaptcha = true;
          value.createClient = wrapped;
        }
      }
    });
  } catch (error) {
    console.error('Could not initialize login CAPTCHA integration.', error);
  }

  const setupWidget = () => {
    const form = document.getElementById('emailForm');
    if (!form) return;
    const container = document.createElement('div');
    container.id = 'turnstile-container';
    container.style.cssText = 'margin:16px 0;min-height:65px';
    const message = document.createElement('p');
    message.id = 'turnstile-help';
    message.className = 'muted';
    message.setAttribute('role', 'status');
    message.style.margin = '6px 0';
    const actions = form.querySelector('.form-actions');
    if (actions) form.insertBefore(container, actions);
    else form.append(container);
    form.insertBefore(message, container.nextSibling);

    if (!config.turnstileSiteKey) {
      message.textContent = 'Human verification is not configured yet. Email sign-in is unavailable until Turnstile is set up.';
      message.className = 'status error';
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    script.async = true;
    script.defer = true;
    script.onload = () => {
      turnstile = window.turnstile;
      if (!turnstile) {
        message.textContent = 'Could not load human verification. Check your connection and reload the page.';
        return;
      }
      widgetId = turnstile.render(container, {
        sitekey: config.turnstileSiteKey,
        callback: value => { token = value; message.textContent = ''; },
        'expired-callback': () => { token = ''; message.textContent = 'Verification expired. Please complete it again.'; },
        'error-callback': () => { token = ''; message.textContent = 'Verification failed to load. Please try again.'; }
      });
    };
    script.onerror = () => { message.textContent = 'Could not load human verification. Check your connection and reload the page.'; };
    document.head.append(script);
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', setupWidget, {once:true});
  else setupWidget();
})();
