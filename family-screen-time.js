(()=> {
  const config=window.CONFIGKIT_AUTH||{};
  const params=new URLSearchParams(location.search);
  const childId=params.get('child');
  const page=location.pathname.split('/').pop();
  if(!childId||!/^[0-9a-f-]{36}$/i.test(childId)||!['kids-zone.html','kids-messages.html'].includes(page))return;
  if(!config.supabaseUrl||!config.supabaseAnonKey||!window.supabase?.createClient)return;

  const storageKey=page==='kids-messages.html'?'configkit-kid-'+childId:undefined;
  const client=window.supabase.createClient(config.supabaseUrl,config.supabaseAnonKey,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false,...(storageKey?{storageKey}:{})}
  });
  const activity=page==='kids-messages.html'?'kids_messages':'kids_zone';
  let running=false,busy=false,timer=null,overlay=null;

  function showLimit(used,limit){
    if(!overlay){
      overlay=document.createElement('section');
      overlay.setAttribute('role','alertdialog');
      overlay.setAttribute('aria-modal','true');
      overlay.setAttribute('aria-labelledby','screen-time-title');
      overlay.style.cssText='position:fixed;inset:0;z-index:2147483647;background:rgba(20,26,42,.96);color:#fff;display:grid;place-items:center;padding:24px;text-align:center;font:16px/1.6 system-ui,sans-serif';
      const card=document.createElement('div');
      card.style.cssText='max-width:440px;background:#fff;color:#24304a;border-radius:20px;padding:28px;box-shadow:0 20px 60px #0006';
      const title=document.createElement('h1');title.id='screen-time-title';title.textContent='Time for a break 🌿';
      const message=document.createElement('p');message.id='screen-time-message';
      const note=document.createElement('p');note.textContent='Your parent or guardian set a daily ConfigKit limit. Ask them if you need more time.';
      card.append(title,message,note);overlay.append(card);document.body.append(overlay);
    }
    const message=overlay.querySelector('#screen-time-message');
    message.textContent='You have used '+Math.floor(used/60)+' of '+limit+' minutes of your daily ConfigKit screen time.';
  }
  function clearLimit(){if(overlay){overlay.remove();overlay=null;}}
  async function heartbeat(){
    if(busy||document.visibilityState!=='visible')return;
    busy=true;
    try{
      const {data,error}=await client.rpc('kids_screen_time_heartbeat',{p_child_id:childId,p_activity:activity});
      if(error)throw error;
      const row=Array.isArray(data)?data[0]:data;
      if(row&&!row.allowed&&row.limit_minutes!==null)showLimit(row.used_seconds||0,row.limit_minutes);
      else clearLimit();
    }catch(error){
      console.warn('ConfigKit family screen-time check was unavailable:',error.message||error);
    }finally{busy=false;}
  }
  async function start(){
    if(running)return;
    running=true;
    await heartbeat();
    timer=window.setInterval(heartbeat,60000);
  }
  client.auth.getSession().then(({data,error})=>{
    if(!error&&data?.session)void start();
  }).catch(()=>{});
  client.auth.onAuthStateChange((_event,session)=>{
    if(session)void start();
    else{
      running=false;
      if(timer)window.clearInterval(timer);
      timer=null;clearLimit();
    }
  });
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')void heartbeat();});
})();