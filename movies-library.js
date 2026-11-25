(() => {
 const $=id=>document.getElementById(id), status=$('listing-status');
 if(!status)return;
 const cfg=window.CONFIGKIT_AUTH||{};
 const setStatus=(msg,error=false)=>{status.textContent=msg;status.classList.toggle('error',error);};
 if(!cfg.supabaseUrl||!cfg.supabaseAnonKey||!window.supabase?.createClient){setStatus('Movie listing service is not configured.',true);return;}
 const db=window.supabase.createClient(cfg.supabaseUrl,cfg.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
 const posterBucket='configkit-movie-posters';
 let user=null,editing=null;
 const safeHttps=value=>{if(!value)return null;try{const u=new URL(value);return u.protocol==='https:'?u.href:null;}catch(_){return null;}};
 const isStoredPoster=value=>typeof value==='string'&&/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$/i.test(value);
 const reset=()=>{$('listing-form').reset();$('listing-id').value='';$('listing-save').textContent='Save private listing';editing=null;};
 const showPoster=async(path,poster)=>{
   poster.textContent='🎬';
   if(!path)return;
   let src=safeHttps(path);
   if(isStoredPoster(path)){
     const {data,error}=await db.storage.from(posterBucket).createSignedUrl(path,3600);
     if(error||!data?.signedUrl)return;
     src=data.signedUrl;
   }
   if(!src)return;
   const img=document.createElement('img');img.src=src;img.alt='';img.loading='lazy';img.referrerPolicy='no-referrer';img.onerror=()=>{poster.textContent='🎬';};poster.replaceChildren(img);
 };
 const makeCard=(row,owner)=>{
   const card=document.createElement('article');card.className='listing-card';
   const poster=document.createElement('div');poster.className='listing-poster';showPoster(row.poster_url,poster);
   const body=document.createElement('div');body.className='listing-body';
   const title=document.createElement('h3');title.textContent=row.title;
   const meta=document.createElement('p');meta.textContent=[row.genre,row.release_year].filter(Boolean).join(' · ')||'Independent film';
   const desc=document.createElement('p');desc.textContent=row.description||'No synopsis provided.';
   body.append(title,meta,desc);
   if(row.trailer_url){const link=document.createElement('a');link.href=safeHttps(row.trailer_url)||'#';link.target='_blank';link.rel='noopener noreferrer';link.textContent='Watch trailer ↗';body.append(link);}
   if(owner){
     const badge=document.createElement('p');badge.textContent=row.visibility==='public'?'Public listing':'Private draft';body.append(badge);
     const actions=document.createElement('div');actions.className='listing-actions';
     const edit=document.createElement('button');edit.textContent='Edit';edit.addEventListener('click',()=>{
       editing=row;$('listing-id').value=row.id;$('listing-title').value=row.title;$('listing-description').value=row.description||'';$('listing-genre').value=row.genre||'';$('listing-year').value=row.release_year||'';$('listing-poster').value='';$('listing-trailer').value=row.trailer_url||'';$('listing-save').textContent='Save changes';setStatus('Choose a new poster only if you want to replace the current one.');window.scrollTo({top:0,behavior:'smooth'});
     });
     const toggle=document.createElement('button');toggle.className='primary';toggle.textContent=row.visibility==='public'?'Make private':'Publish';
     toggle.addEventListener('click',async()=>{
       const next=row.visibility==='public'?'private':'public';
       const {error}=await db.from('configkit_movies').update({visibility:next,updated_at:new Date().toISOString()}).eq('id',row.id).eq('user_id',user.id);
       if(error){setStatus(error.message,true);return;}
       setStatus(next==='public'?'Your movie listing is now public.':'Your movie listing is now private.');await refresh();
     });
     const del=document.createElement('button');del.className='danger';del.textContent='Delete';
     del.addEventListener('click',async()=>{
       if(!confirm('Delete “'+row.title+'”? This cannot be undone.'))return;
       const {error}=await db.from('configkit_movies').delete().eq('id',row.id).eq('user_id',user.id);
       if(error){setStatus(error.message,true);return;}
       if(isStoredPoster(row.poster_url))await db.storage.from(posterBucket).remove([row.poster_url]);
       if(editing?.id===row.id)reset();setStatus('Movie listing deleted.');await refresh();
     });
     actions.append(edit,toggle,del);body.append(actions);
   }
   card.append(poster,body);return card;
 };
 const load=async(host,own)=>{
   host.replaceChildren();
   let q=db.from('configkit_movies').select('id,user_id,title,description,genre,release_year,poster_url,trailer_url,visibility,created_at').order('created_at',{ascending:false}).limit(60);
   q=own?q.eq('user_id',user.id):q.eq('visibility','public');
   const {data,error}=await q;if(error)throw error;
   if(!data?.length){const p=document.createElement('p');p.className='muted';p.textContent=own?'You have not created any movie listings yet.':'No public creator listings yet. Be the first to publish one!';host.append(p);return;}
   data.forEach(row=>host.append(makeCard(row,own)));
 };
 const refresh=async()=>{try{await Promise.all([load($('my-listings'),true),load($('public-listings'),false)]);}catch(e){setStatus('Could not load movie listings: '+e.message,true);}};
 $('listing-form').addEventListener('submit',async e=>{
   e.preventDefault();const button=$('listing-save');button.disabled=true;
   let uploadedPath=null;
   try{
     const title=$('listing-title').value.trim(),year=$('listing-year').value?Number($('listing-year').value):null,trailerRaw=$('listing-trailer').value.trim(),file=$('listing-poster').files?.[0]||null;
     if(!title)throw new Error('Add a movie title.');
     if(year!==null&&(!Number.isInteger(year)||year<1888||year>2200))throw new Error('Enter a valid release year.');
     if(trailerRaw&&!safeHttps(trailerRaw))throw new Error('Trailer URL must use HTTPS.');
     if(file){
       const types={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'};
       const ext=types[file.type];
       if(!ext)throw new Error('Poster must be a JPEG, PNG or WebP image.');
       if(file.size>5*1024*1024)throw new Error('Poster must be 5 MB or smaller.');
       uploadedPath=user.id+'/'+crypto.randomUUID()+'.'+ext;
       const {error}=await db.storage.from(posterBucket).upload(uploadedPath,file,{contentType:file.type,cacheControl:'3600',upsert:false});
       if(error)throw error;
     }
     const oldPoster=editing?.poster_url||null;
     const payload={user_id:user.id,title,description:$('listing-description').value.trim(),genre:$('listing-genre').value.trim(),release_year:year,poster_url:uploadedPath||oldPoster,trailer_url:trailerRaw?safeHttps(trailerRaw):null,updated_at:new Date().toISOString()};
     let result;
     if(editing)result=await db.from('configkit_movies').update(payload).eq('id',editing.id).eq('user_id',user.id);
     else result=await db.from('configkit_movies').insert({...payload,visibility:'private'});
     if(result.error)throw result.error;
     if(uploadedPath&&isStoredPoster(oldPoster))await db.storage.from(posterBucket).remove([oldPoster]);
     setStatus(editing?'Movie listing updated.':'Movie listing saved privately. You can publish it from My movie listings.');reset();await refresh();
   }catch(e){
     if(uploadedPath)await db.storage.from(posterBucket).remove([uploadedPath]);
     setStatus(e.message||'Could not save movie listing.',true);
   }finally{button.disabled=false;}
 });
 $('listing-reset').addEventListener('click',reset);
 $('listing-refresh').addEventListener('click',()=>load($('my-listings'),true).catch(e=>setStatus(e.message,true)));
 $('public-refresh').addEventListener('click',()=>load($('public-listings'),false).catch(e=>setStatus(e.message,true)));
 (async()=>{
   try{
     const {data,error}=await db.auth.getSession();if(error)throw error;
     if(!data.session){
       setStatus('Sign in to create and manage movie listings.');
       const a=document.createElement('a');a.href='login.html?next=movies.html';a.textContent=' Sign in';status.append(a);
       $('my-listings').innerHTML='<p class="muted">Sign in to view your private listings.</p>';
       await load($('public-listings'),false);return;
     }
     user=data.session.user;setStatus('Signed in. New movie listings are private by default.');await refresh();
   }catch(e){setStatus('Could not start movie listings: '+e.message,true);}
 })();
})();
