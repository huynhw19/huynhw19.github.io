// Public browser configuration only. Never put OAuth client secrets here.
// Fill these in after completing AUTH-SETUP.md.
window.CONFIGKIT_AUTH = {
  supabaseUrl: '',
  supabaseAnonKey: ''
};

// Brand the OAuth page only; the rest of the site keeps its existing header.
(() => {
  const addOAuthLogo = () => {
    if (!window.location.pathname.endsWith('/login.html')) return;
    const header = document.querySelector('header');
    if (!header || header.querySelector('.oauth-app-logo')) return;

    const logo = document.createElement('img');
    logo.className = 'oauth-app-logo';
    logo.src = 'configkit-oauth-logo.svg';
    logo.alt = 'ConfigKit';
    logo.width = 40;
    logo.height = 40;
    logo.style.cssText = 'width:40px;height:40px;display:inline-block;vertical-align:middle;margin-right:10px;border-radius:12px';
    header.prepend(logo);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addOAuthLogo, {once:true});
  } else {
    addOAuthLogo();
  }
})();
