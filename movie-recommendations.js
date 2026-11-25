(() => {
 const status=document.getElementById('recommend-status'),host=document.getElementById('recommend-results');
 if(!status||!host)return;
 const cfg=window.CONFIGKIT_AUTH||{};
 const say=(message,error=false)=>{status.textContent=message;status.classList.toggle('error',error);};
 const posterPath=value=>typeof value==='string'&&/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$/i.test(value);
 const safeHttps=value=>{try{const u=new URL(value);return u.protocol==='https:'?u.href:null;}catch(_){return null;}};
 const render=async(db,movies,scores,savedIds)=>{
  host.replaceChildren();
  const candidates=movies.filter(m=>!savedIds.has(m.id));
  const ranked=candidates.map(movie=>{
   const genre=(movie.genre||'').trim().toLowerCase();
   const score=(genre?scores.get(genre)||0:0);
   return {movie,score};
  }).sort((a,b)=>b.score-a.score||Number(b.movie.average_rating||0)-Number(a.movie.average_rating||0)||Number(b.movie.review_count||0)-Number(a.movie.review_count||0));
  const picks=ranked.slice(0,8);
  if(!picks.length){say('No new public films to recommend yet. Add more films to your watchlist or check back later.');return;}
  say(scores.size?'Your picks are ranked using genres from your saved films and 4–5 star ratings.':'Explore these community films while we learn your preferences.');
  for(const {movie,score} of picks){
   const card=document.createElement('article');card.className='movie';
   const poster=document.createElement('div');poster.className='poster';poster.textContent='🎬';
   let src=safeHttps(movie.poster_url);
   if(!src&&posterPath(movie.poster_url)){const {data}=await db.storage.from('configkit-movie-posters').createSignedUrl(movie.poster_url,3600);src=data?.signedUrl||null;}
   if(src){const img=document.createElement('img');img.src=src;img.alt='Poster for '+movie.title;img.loading='lazy';img.referrerPolicy='no-referrer';poster.replaceChildren(img);}
   const body=document.createElement('div');body.className='movie-body';
   const title=document.createElement('h3');title.textContent=movie.title;
   const meta=document.createElement('p');meta.textContent=[movie.genre,movie.release_year].filter(Boolean).join(' · ')||'Independent film';
   const rating=document.createElement('p');rating.textContent=movie.review_count?'★ '+Number(movie.average_rating).toFixed(1)+' / 5 · '+movie.review_count+' reviews':'Not rated yet';
   const reason=document.createElement('p');reason.textContent=score?'Matches genres you have saved or rated highly.':'Popular community pick.';
   const link=document.createElement('a');link.href='movie.html?id='+encodeURIComponent(movie.id);link.textContent='View movie →';
   body.append(title,meta,rating,reason,link);card.append(poster,body);host.append(card);
  }
 };
 const load=async()=>{
  if(!cfg.supabaseUrl||!cfg.supabaseAnonKey||!window.supabase?.createClient){say('Movie recommendations are not configured.',true);return;}
  say('Finding films you might enjoy…');host.replaceChildren();
  try{
   const db=window.supabase.createClient(cfg.supabaseUrl,cfg.supabaseAnonKey);
   const {data:auth,error:authError}=await db.auth.getSession();if(authError)throw authError;
   const user=auth?.session?.user;
   if(!user){say('Sign in to get recommendations based on your watchlist and ratings.');return;}
   const [movieResult,watchResult,reviewResult]=await Promise.all([
    db.from('configkit_movies').select('id,title,description,genre,release_year,poster_url,created_at').eq('visibility','public').order('created_at',{ascending:false}).limit(150),
    db.from('configkit_movie_watchlist').select('movie_id').eq('user_id',user.id),
    db.from('configkit_movie_reviews').select('movie_id,rating').eq('user_id',user.id)
   ]);
   if(movieResult.error)throw movieResult.error;if(watchResult.error)throw watchResult.error;if(reviewResult.error)throw reviewResult.error;
   const movies=movieResult.data||[],savedIds=new Set((watchResult.data||[]).map(x=>x.movie_id));
   const scores=new Map();
   const addGenre=(movieId,weight)=>{const movie=movies.find(m=>m.id===movieId);const genre=(movie?.genre||'').trim().toLowerCase();if(genre)scores.set(genre,(scores.get(genre)||0)+weight);};
   savedIds.forEach(id=>addGenre(id,2));
   (reviewResult.data||[]).filter(r=>Number(r.rating)>=4).forEach(r=>addGenre(r.movie_id,Number(r.rating)));
   const [allReviews]=await Promise.all([db.from('configkit_movie_reviews').select('movie_id,rating').in('movie_id',movies.map(m=>m.id).slice(0,150))]);
   if(allReviews.error)throw allReviews.error;
   const aggregates=new Map();
   (allReviews.data||[]).forEach(r=>{const current=aggregates.get(r.movie_id)||{sum:0,count:0};current.sum+=Number(r.rating);current.count++;aggregates.set(r.movie_id,current);});
   movies.forEach(m=>{const a=aggregates.get(m.id);m.review_count=a?.count||0;m.average_rating=a?.count?a.sum/a.count:0;});
   await render(db,movies,scores,savedIds);
  }catch(error){say(error.message||'Could not load recommendations.',true);}
 };
 document.getElementById('recommend-refresh')?.addEventListener('click',load);
 load();
})();