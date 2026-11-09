/* ConfigKit Developer Studio: local multi-file workspace.
   Files stay in this browser unless the user explicitly shares a supported profile. */
(() => {
  const editor = document.getElementById('xml-editor');
  const host = document.querySelector('.editor-card');
  if (!editor || !host) return;
  const KEY = 'configkit-developer-studio-files-v1';
  const activeKey = 'configkit-developer-studio-active-v1';
  const read = () => { try { const value=JSON.parse(localStorage.getItem(KEY)||'[]'); return Array.isArray(value)?value.filter(x=>x&&typeof x.name==='string'&&typeof x.content==='string'):[]; } catch (_) { return []; } };
  let files = read();
  let active = localStorage.getItem(activeKey) || '';
  const style = document.createElement('style');
  style.textContent = '.studio-files{background:#fff;border:1px solid #e4eae6;border-radius:1rem;padding:1.2rem;margin:1rem 0;box-shadow:0 12px 32px rgba(23,35,31,.06)}.studio-filebar{display:flex;gap:.5rem;flex-wrap:wrap;align-items:center}.studio-filebar select{min-width:min(100%,260px);flex:1}.studio-file-note{color:#66736d;font-size:.9rem}.studio-file-list{display:flex;gap:.4rem;flex-wrap:wrap;margin-top:.8rem}.studio-file-list button[aria-pressed=true]{background:#e8f4ed;border-color:#226b51;color:#174b39}.studio-files input[type=file]{max-width:100%}';
  document.head.append(style);
  const panel=document.createElement('section');
  panel.className='studio-files';
  panel.setAttribute('aria-labelledby','studio-files-title');
  panel.innerHTML='<h2 id="studio-files-title">Project files</h2><p class="studio-file-note">Create and edit multiple text files, or import files from your device. Your workspace is saved only in this browser; it is not a cloud backup.</p><div class="studio-filebar"><select id="studio-file-select" aria-label="Choose project file"><option value="">Current editor (unsaved)</option></select><button type="button" id="studio-new-file" class="primary">New file</button><button type="button" id="studio-save-file">Save file</button><button type="button" id="studio-download-file">Download</button><button type="button" id="studio-delete-file">Delete</button></div><div class="studio-filebar" style="margin-top:.7rem"><label for="studio-upload">Import files</label><input id="studio-upload" type="file" multiple><button type="button" id="studio-import">Import selected</button></div><div id="studio-file-list" class="studio-file-list" aria-label="Project file shortcuts"></div><p id="studio-file-status" class="studio-file-note" role="status" aria-live="polite"></p>';
  host.parentNode.insertBefore(panel,host);
  const $=id=>document.getElementById(id);
  const select=$('studio-file-select'), status=$('studio-file-status'), upload=$('studio-upload');
  const say=m=>{status.textContent=m;};
  const persist=()=>{try{localStorage.setItem(KEY,JSON.stringify(files));localStorage.setItem(activeKey,active);}catch(_){say('Could not save: browser storage is full. Download important files as backups.');}};
  const safeName=name=>{name=String(name||'untitled.txt').trim().replace(/[\\/\\0]/g,'-').slice(0,120);return name||'untitled.txt';};
  const current=()=>files.find(f=>f.id===active);
  const refresh=()=>{
    select.replaceChildren(new Option('Current editor (unsaved)',''));
    files.forEach(f=>select.add(new Option(f.name,f.id)));
    select.value=active;
    const list=$('studio-file-list');list.replaceChildren();
    files.forEach(f=>{const b=document.createElement('button');b.type='button';b.textContent=f.name;b.setAttribute('aria-pressed',String(f.id===active));b.addEventListener('click',()=>switchTo(f.id));list.append(b);});
  };
  const switchTo=id=>{
    const old=current();if(old)old.content=editor.value;
    active=id;const file=current();editor.value=file?file.content:'';editor.dispatchEvent(new Event('input',{bubbles:true}));persist();refresh();say(file?'Editing '+file.name:'Editing an unsaved buffer.');
  };
  const save=()=>{
    const f=current();if(f){f.content=editor.value;f.updatedAt=new Date().toISOString();persist();refresh();say('Saved '+f.name+' in this browser.');return;}
    createFile('untitled.txt',editor.value);
  };
  const createFile=(name,content='')=>{
    const id=(crypto.randomUUID?crypto.randomUUID():Date.now().toString(36)+Math.random().toString(36).slice(2));
    files.push({id,name:safeName(name),content,updatedAt:new Date().toISOString()});active=id;persist();refresh();editor.value=content;editor.dispatchEvent(new Event('input',{bubbles:true}));say('Created '+safeName(name)+'.');
  };
  $('studio-new-file').addEventListener('click',()=>{const name=prompt('File name (for example, app.js or notes.md):','new-file.txt');if(name===null)return;if(!name.trim()){say('Enter a file name.');return;}if(files.some(f=>f.name===safeName(name))){say('A file with that name already exists. Choose another name.');return;}const old=current();if(old)old.content=editor.value;createFile(name);});
  $('studio-save-file').addEventListener('click',save);
  select.addEventListener('change',()=>switchTo(select.value));
  $('studio-delete-file').addEventListener('click',()=>{const f=current();if(!f){say('Choose a saved project file first.');return;}if(!confirm('Delete '+f.name+' from this browser workspace?'))return;files=files.filter(x=>x.id!==active);active='';persist();refresh();editor.value='';editor.dispatchEvent(new Event('input',{bubbles:true}));say('File deleted from this browser workspace.');});
  $('studio-download-file').addEventListener('click',()=>{const f=current();const name=f?f.name:'editor.txt';const content=editor.value;const blob=new Blob([content],{type:'text/plain;charset=utf-8'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();URL.revokeObjectURL(url);say('Downloaded '+name+'.');});
  $('studio-import').addEventListener('click',async()=>{const chosen=[...upload.files];if(!chosen.length){say('Choose one or more files to import.');return;}let imported=0;for(const file of chosen){if(file.size>2*1024*1024){say(file.name+' is larger than 2 MB and was skipped.');continue;}try{const content=await file.text();const name=safeName(file.name);const existing=files.find(f=>f.name===name);if(existing){existing.content=content;existing.updatedAt=new Date().toISOString();active=existing.id;}else{const id=(crypto.randomUUID?crypto.randomUUID():Date.now().toString(36)+Math.random().toString(36).slice(2));files.push({id,name,content,updatedAt:new Date().toISOString()});active=id;}imported++;}catch(_){say('Could not read '+file.name+'.');}}upload.value='';persist();const f=current();editor.value=f?f.content:'';editor.dispatchEvent(new Event('input',{bubbles:true}));refresh();say(imported+' file(s) imported into this browser workspace.');});
  const share=document.getElementById('share-community');
  if(share)share.addEventListener('click',()=>{const f=current();if(f&&/\\.(mobileconfig|xml)$/i.test(f.name)){try{sessionStorage.setItem('configkit-share-profile',JSON.stringify({xml:editor.value,filename:f.name.endsWith('.xml')?f.name:f.name.replace(/\\.mobileconfig$/i,'.mobileconfig')}));}catch(_){say('Could not prepare the share handoff.');}}},true);
  editor.addEventListener('input',()=>{const f=current();if(f){f.content=editor.value;persist();}});
  refresh();
  const f=current();if(f){editor.value=f.content;editor.dispatchEvent(new Event('input',{bubbles:true}));}
  say(files.length+' project file(s) in this browser workspace.');
})();
