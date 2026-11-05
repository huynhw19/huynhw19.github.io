// Public browser configuration only. Never put OAuth client secrets here.
// Fill these in after completing AUTH-SETUP.md.
window.CONFIGKIT_AUTH = {
  supabaseUrl: 'https://gwhqnqzzlgslwgijkkpt.supabase.co',
  supabaseAnonKey: 'sb_publishable_qf35m_HhuP-QC_lFVlfmWg_VLPoUY7w'
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
