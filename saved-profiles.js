// ConfigKit download history: saves profile metadata only, never the generated XML or credentials.
(() => {
  const config = window.CONFIGKIT_AUTH || {};
  if (!config.supabaseUrl || !config.supabaseAnonKey || !window.supabase?.createClient) return;
  const client = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  const toolForPage = () => ({
    'index.html': 'Wi-Fi builder',
    'dns-builder.html': 'DNS builder',
    'webclip-builder.html': 'Web clip builder',
    'prepare-profile.html': 'Profile inspector',
    'mobileconfig-builder.html': 'Mobileconfig Studio',
    'developer-dashboard.html': 'Developer XML studio'
  }[location.pathname.split('/').pop() || 'index.html'] || 'ConfigKit');
  const notify = message => {
    let node = document.getElementById('saved-profile-notice');
    if (!node) {
      node = document.createElement('p');
      node.id = 'saved-profile-notice';
      node.setAttribute('role', 'status');
      node.style.cssText = 'position:fixed;right:16px;bottom:16px;z-index:1000;max-width:min(420px,calc(100vw - 32px));padding:12px 16px;border-radius:10px;background:#174b39;color:#fff;box-shadow:0 8px 24px #0002;font:14px/1.45 system-ui,sans-serif';
      document.body.append(node);
    }
    node.textContent = message;
    node.hidden = false;
  };
  async function save(details) {
    try {
      const { data: { user }, error: authError } = await client.auth.getUser();
      if (authError) throw authError;
      if (!user) return;
      const { error } = await client.from('saved_profiles').insert({
        user_id: user.id,
        profile_name: String(details.profileName || 'Downloaded profile').trim().slice(0, 120) || 'Downloaded profile',
        filename: String(details.filename || 'profile.mobileconfig').slice(0, 255),
        tool: String(details.tool || toolForPage()).slice(0, 80),
        mime_type: 'application/x-apple-aspen-config',
        file_size: Number.isSafeInteger(details.fileSize) && details.fileSize >= 0 ? details.fileSize : 0
      });
      if (error) throw error;
      notify('Saved to your ConfigKit profile history. The file itself stays in your device downloads.');
      if (typeof window.refreshSavedProfiles === 'function') window.refreshSavedProfiles();
    } catch (error) {
      console.warn('Could not save ConfigKit download history:', error);
      notify('Your file downloaded, but its history could not be saved. Check your connection and sign-in.');
    }
  }
  window.ConfigKitSavedProfiles = { save };
  document.addEventListener('click', event => {
    const link = event.target.closest?.('a[download]');
    if (!link || !/\.mobileconfig$/i.test(link.download || '')) return;
    const filename = link.download || 'profile.mobileconfig';
    const field = document.querySelector('#profile-name');
    const profileName = link.dataset.profileName || field?.value?.trim() || filename.replace(/\.mobileconfig$/i, '').replace(/[-_]+/g, ' ');
    void save({ profileName, filename, tool: link.dataset.saveTool || toolForPage() });
  }, true);

  const list = document.getElementById('saved-profiles-list');
  if (list) {
    const empty = document.getElementById('saved-profiles-empty');
    window.refreshSavedProfiles = async () => {
      list.replaceChildren();
      const { data: { user }, error: authError } = await client.auth.getUser();
      if (authError || !user) { empty.textContent = 'Sign in to view your saved profile history.'; empty.hidden = false; return; }
      const { data, error } = await client.from('saved_profiles')
        .select('id, profile_name, filename, tool, created_at')
        .order('created_at', { ascending: false }).limit(50);
      if (error) { empty.textContent = 'Could not load saved profiles. Please refresh the page.'; empty.hidden = false; return; }
      if (!data.length) { empty.textContent = 'No downloads saved yet. Generate and download a profile while signed in, and it will appear here.'; empty.hidden = false; return; }
      empty.hidden = true;
      for (const item of data) {
        const row = document.createElement('article');
        row.style.cssText = 'display:flex;justify-content:space-between;align-items:flex-start;gap:12px;flex-wrap:wrap;padding:12px 0;border-bottom:1px solid #e4eae6';
        const details = document.createElement('div');
        const title = document.createElement('strong'); title.textContent = item.profile_name;
        const meta = document.createElement('p'); meta.style.cssText = 'margin:3px 0;color:#66736d;font-size:.92rem';
        meta.textContent = item.filename + ' · ' + item.tool + ' · ' + new Date(item.created_at).toLocaleString();
        details.append(title, meta);
        const remove = document.createElement('button'); remove.type = 'button'; remove.textContent = 'Remove';
        remove.style.cssText = 'border:1px solid #e4eae6;border-radius:8px;padding:6px 10px;background:white;cursor:pointer;font:inherit';
        remove.addEventListener('click', async () => {
          remove.disabled = true;
          const { error: deleteError } = await client.from('saved_profiles').delete().eq('id', item.id);
          if (deleteError) { remove.disabled = false; notify('Could not remove this history item.'); return; }
          void window.refreshSavedProfiles();
        });
        row.append(details, remove); list.append(row);
      }
    };
    void window.refreshSavedProfiles();
  }
})();