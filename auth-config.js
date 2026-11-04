// Public browser configuration only. Never put OAuth client secrets here.
// Fill these in after completing AUTH-SETUP.md.
window.CONFIGKIT_AUTH = {
  supabaseUrl: '',
  supabaseAnonKey: ''
};

// Brand the OAuth page and expose the builder discussion only after sign-in.
(() => {
  const addLoginEnhancements = () => {
    if (!window.location.pathname.endsWith('/login.html')) return;

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
    if (!account || account.dataset.discussionObserver) return;
    account.dataset.discussionObserver = 'true';

    const addDiscussionLink = () => {
      const existing = account.querySelector('.builder-discussion-link');
      if (account.hidden) {
        existing?.remove();
        return;
      }
      if (!existing) {
        const link = document.createElement('a');
        link.className = 'builder-discussion-link';
        link.href = 'builder-discussion.html';
        link.textContent = 'Open builder discussion →';
        link.style.cssText = 'display:block;margin-top:8px;font-weight:600';
        account.append(document.createElement('br'), link);
      }
    };

    new MutationObserver(addDiscussionLink).observe(account, {attributes:true, childList:true, subtree:true});
    addDiscussionLink();
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addLoginEnhancements, {once:true});
  } else {
    addLoginEnhancements();
  }
})();
