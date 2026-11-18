(() => {
  const mount = document.getElementById('activity-centre');
  if (!mount) return;
  const list = document.getElementById('activity-list');
  const counts = document.getElementById('activity-counts');
  const search = document.getElementById('activity-search');
  const refresh = document.getElementById('activity-refresh');
  let clientRef = null;
  let userId = null;
  let items = [];
  let filter = 'all';
  let loading = false;

  const dateLabel = value => {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Recently' : new Intl.DateTimeFormat(undefined, {dateStyle:'medium', timeStyle:'short'}).format(date);
  };
  const node = (tag, className, text) => {
    const el = document.createElement(tag);
    if (className) el.className = className;
    if (text !== undefined) el.textContent = String(text);
    return el;
  };
  const showError = message => {
    list.replaceChildren(node('div', 'activity-empty', message));
  };

  async function load() {
    if (!clientRef || !userId || loading) return;
    loading = true;
    refresh.disabled = true;
    refresh.textContent = 'Refreshing…';
    list.replaceChildren(node('div', 'activity-empty', 'Loading recent activity…'));
    try {
      const results = await Promise.allSettled([
        clientRef.from('configkit_notifications').select('id,category,event_type,title,body,action_url,created_at,read_at,dismissed_at').eq('user_id', userId).is('dismissed_at', null).order('created_at', {ascending:false}).limit(20),
        clientRef.from('saved_profiles').select('id,profile_name,filename,tool,created_at').eq('user_id', userId).order('created_at', {ascending:false}).limit(12),
        clientRef.from('configkit_profiles').select('id,name,folder,created_at,updated_at').eq('user_id', userId).order('updated_at', {ascending:false}).limit(12),
        clientRef.from('configkit_profile_versions').select('id,profile_id,filename,version_number,created_at').eq('user_id', userId).order('created_at', {ascending:false}).limit(12),
        clientRef.from('planner_items').select('id,title,item_type,status,created_at,completed_at,updated_at').eq('user_id', userId).order('updated_at', {ascending:false}).limit(12),
        clientRef.from('user_achievements').select('achievement_key,earned_at').eq('user_id', userId).order('earned_at', {ascending:false}).limit(20)
      ]);
      const failed = results.filter(result => result.status === 'rejected' || result.value?.error);
      const rowsBySource = results.map(result =>
        result.status === 'fulfilled' && !result.value?.error ? (result.value.data || []) : []
      );
      const rows = [];
      const [notifications, saved, profiles, versions, planner, achievements] = rowsBySource;
      notifications.forEach(row => rows.push({
        id:'notification:'+row.id, source:'notifications', category:row.category, title:row.title, body:row.body,
        date:row.created_at, unread:!row.read_at, actionUrl:row.action_url, notificationId:row.id
      }));
      saved.forEach(row => rows.push({
        id:'saved:'+row.id, source:'profiles', category:'Profile download', icon:'📥',
        title:'Downloaded a configuration profile', body:row.profile_name || row.filename || 'Saved profile',
        date:row.created_at, actionUrl:'#saved-profiles'
      }));
      profiles.forEach(row => rows.push({
        id:'profile:'+row.id, source:'profiles', category:'Profile library', icon:'🗂️',
        title:'Updated a saved profile', body:row.name + (row.folder ? ' · '+row.folder : ''),
        date:row.updated_at || row.created_at, actionUrl:'profile-library.html'
      }));
      versions.forEach(row => rows.push({
        id:'version:'+row.id, source:'profiles', category:'Profile version', icon:'🕘',
        title:'Saved profile version '+row.version_number, body:row.filename,
        date:row.created_at, actionUrl:'profile-library.html'
      }));
      planner.forEach(row => rows.push({
        id:'planner:'+row.id, source:'planner', category:'Planner', icon:row.status === 'completed' ? '✅' : '📅',
        title:row.status === 'completed' ? 'Completed a planner item' : 'Updated a planner item',
        body:row.title, date:row.completed_at || row.updated_at || row.created_at, actionUrl:'planner.html'
      }));
      achievements.forEach(row => rows.push({
        id:'achievement:'+row.achievement_key, source:'milestones', category:'Achievement',
        title:'Achievement earned', body:String(row.achievement_key || '').replaceAll('_',' '),
        date:row.earned_at, icon:'🏅', actionUrl:'dashboard.html#achievements'
      }));
      items = rows.sort((a,b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      const unreadCount = items.filter(item => item.source === 'notifications' && item.unread).length;
      counts.replaceChildren();
      [['Recent events',items.length],['Unread notifications',unreadCount],['Achievements',items.filter(item=>item.source==='milestones').length]].forEach(([label,value]) => {
        const span = node('span');
        span.append(node('strong','',String(value)), document.createTextNode(' '+label));
        counts.append(span);
      });
      const footer = document.getElementById('activity-footer');
      footer.textContent = failed.length
        ? 'Some activity sources could not be loaded. Available records are shown; refresh to try again.'
        : 'Showing your latest activity across notifications, profiles, planner updates and achievements.';
      render();
    } catch (error) {
      showError('Activity could not be loaded. Please refresh to try again.');
      const footer = document.getElementById('activity-footer');
      footer.textContent = 'The activity check encountered an error. Your other dashboard features are unaffected.';
      console.error('Could not load ConfigKit activity:', error);
    } finally {
      loading = false;
      refresh.disabled = false;
      refresh.textContent = 'Refresh';
    }
  }

  function render() {
    const query = search.value.trim().toLocaleLowerCase();
    const visible = items.filter(item =>
      (filter === 'all' || item.source === filter) &&
      (!query || (item.title+' '+item.body+' '+item.category).toLocaleLowerCase().includes(query))
    );
    list.replaceChildren();
    if (!visible.length) {
      list.append(node('div','activity-empty',items.length ? 'No activity matches this filter.' : 'No activity yet. Your ConfigKit updates will appear here as you use the workspace.'));
      return;
    }
    visible.slice(0,30).forEach(item => {
      const row = node('article','activity-row'+(item.unread ? ' unread' : ''));
      row.append(node('span','activity-symbol',item.icon || (item.source === 'notifications' ? '🔔' : '•')));
      const copy = node('div','activity-copy');
      copy.append(node('strong','',item.title),node('p','',item.body),node('small','',item.category+' · '+dateLabel(item.date)));
      const actions = node('div','activity-actions');
      if (item.actionUrl) {
        const link = node('a','', 'Open');
        link.href = item.actionUrl;
        link.style.fontWeight = '600';
        actions.append(link);
      }
      if (item.notificationId && item.unread) {
        const mark = node('button','','Mark read');
        mark.type = 'button';
        mark.addEventListener('click', async () => {
          mark.disabled = true;
          const {error} = await clientRef.from('configkit_notifications').update({read_at:new Date().toISOString()}).eq('id',item.notificationId).eq('user_id',userId);
          if (error) { mark.disabled = false; mark.textContent = 'Try again'; return; }
          item.unread = false;
          void load();
        });
        actions.append(mark);
      }
      row.append(copy,actions);
      list.append(row);
    });
    if (visible.length > 30) list.append(node('div','activity-empty','Showing the 30 most recent matching events.'));
  }

  mount.querySelectorAll('[data-activity-filter]').forEach(button => {
    button.addEventListener('click', () => {
      filter = button.dataset.activityFilter;
      mount.querySelectorAll('[data-activity-filter]').forEach(other => other.setAttribute('aria-pressed', String(other === button)));
      render();
    });
  });
  search.addEventListener('input', render);
  refresh.addEventListener('click', () => void load());
  window.CONFIGKIT_ACTIVITY_CENTRE = (client, id) => {
    clientRef = client;
    userId = id;
    void load();
  };
})();
