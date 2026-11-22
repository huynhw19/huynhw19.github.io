create table if not exists public.configkit_templates (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references auth.users(id) on delete cascade,
  creator_name text not null default 'ConfigKit member',
  title text not null check (char_length(btrim(title)) between 3 and 100),
  description text not null default '' check (char_length(description) <= 1200),
  category text not null check (category in ('Documents','Presentations','Mobileconfig','Productivity','Education','Creative','Other')),
  template_format text not null check (template_format in ('ckdoc','ckslides','mobileconfig','json','xml','txt')),
  file_name text not null check (char_length(file_name) between 1 and 160),
  template_content text not null check (char_length(template_content) between 1 and 500000),
  tags text[] not null default '{}'::text[] check (cardinality(tags) <= 10),
  status text not null default 'published' check (status in ('draft','published')),
  moderation_status text not null default 'visible' check (moderation_status in ('visible','hidden')),
  download_count bigint not null default 0 check (download_count >= 0),
  is_official boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists configkit_templates_public_listing_idx
  on public.configkit_templates (is_official desc, created_at desc)
  where status='published' and moderation_status='visible';
create index if not exists configkit_templates_category_idx
  on public.configkit_templates (category, created_at desc)
  where status='published' and moderation_status='visible';
alter table public.configkit_templates enable row level security;
revoke all on public.configkit_templates from anon, public;
grant select on public.configkit_templates to anon, authenticated;
grant insert (creator_id,creator_name,title,description,category,template_format,file_name,template_content,tags,status,moderation_status,updated_at)
  on public.configkit_templates to authenticated;
grant update (creator_name,title,description,category,template_format,file_name,template_content,tags,status,updated_at)
  on public.configkit_templates to authenticated;
grant delete on public.configkit_templates to authenticated;
drop policy if exists "Public can browse published ConfigKit templates" on public.configkit_templates;
create policy "Public can browse published ConfigKit templates"
  on public.configkit_templates for select to anon, authenticated
  using (status='published' and moderation_status='visible');
drop policy if exists "Creators can view their own ConfigKit templates" on public.configkit_templates;
create policy "Creators can view their own ConfigKit templates"
  on public.configkit_templates for select to authenticated
  using (creator_id=(select auth.uid()));
drop policy if exists "Members can publish their own ConfigKit templates" on public.configkit_templates;
create policy "Members can publish their own ConfigKit templates"
  on public.configkit_templates for insert to authenticated
  with check (creator_id=(select auth.uid()) and is_official=false and download_count=0);
drop policy if exists "Creators can update their own ConfigKit templates" on public.configkit_templates;
create policy "Creators can update their own ConfigKit templates"
  on public.configkit_templates for update to authenticated
  using (creator_id=(select auth.uid()) and is_official=false)
  with check (creator_id=(select auth.uid()) and is_official=false);
drop policy if exists "Creators can delete their own ConfigKit templates" on public.configkit_templates;
create policy "Creators can delete their own ConfigKit templates"
  on public.configkit_templates for delete to authenticated
  using (creator_id=(select auth.uid()) and is_official=false);

insert into public.configkit_templates
  (creator_name,title,description,category,template_format,file_name,template_content,tags,status,is_official)
select 'ConfigKit','Project Brief','A structured starting point for describing a project, its goals, milestones and next steps.','Documents','ckdoc','project-brief.ckdoc.json',
'{
  "format":"configkit-doc",
  "version":1,
  "title":"Project Brief",
  "content":"# Project Brief\n\n## Overview\nDescribe the project in a few sentences.\n\n## Goals\n- Goal 1\n- Goal 2\n\n## Audience\nWho is this for?\n\n## Milestones\n1. Discovery\n2. Build\n3. Review\n4. Launch\n\n## Next steps\n- [ ] First action\n- [ ] Second action",
  "updatedAt":"2026-11-22T00:00:00.000Z"
}'::text,
array['project','planning','document'],'published',true
where not exists (select 1 from public.configkit_templates where is_official and file_name='project-brief.ckdoc.json');

insert into public.configkit_templates
  (creator_name,title,description,category,template_format,file_name,template_content,tags,status,is_official)
select 'ConfigKit','Pitch Deck Starter','A concise presentation outline for introducing an idea, explaining the problem and proposing a solution.','Presentations','ckslides','pitch-deck-starter.ckslides.json',
'{
  "format":"configkit-slides",
  "version":1,
  "title":"Pitch Deck Starter",
  "description":"A simple structure for presenting an idea.",
  "slides":[
    "# The idea\n\nOne-sentence introduction",
    "# The problem\n\nWho experiences it, and why does it matter?",
    "# The solution\n\nExplain your approach and what makes it useful.",
    "# How it works\n\nShow the key steps or experience.",
    "# Next steps\n\nWhat happens after this presentation?"
  ],
  "updatedAt":"2026-11-22T00:00:00.000Z"
}'::text,
array['presentation','pitch','slides'],'published',true
where not exists (select 1 from public.configkit_templates where is_official and file_name='pitch-deck-starter.ckslides.json');

insert into public.configkit_templates
  (creator_name,title,description,category,template_format,file_name,template_content,tags,status,is_official)
select 'ConfigKit','Web Clip Example','An illustrative Apple Web Clip configuration profile. Replace the example identifiers and UUIDs, review the URL and inspect the profile before installing or distributing it.','Mobileconfig','mobileconfig','web-clip-example.mobileconfig',
'<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key><string>com.apple.webClip.managed</string>
      <key>PayloadVersion</key><integer>1</integer>
      <key>PayloadIdentifier</key><string>com.example.webclip</string>
      <key>PayloadUUID</key><string>12345678-1234-4234-8234-123456789ABC</string>
      <key>Label</key><string>Example Website</string>
      <key>URL</key><string>https://example.com/</string>
      <key>IsRemovable</key><true/>
    </dict>
  </array>
  <key>PayloadDisplayName</key><string>Example Web Clip</string>
  <key>PayloadIdentifier</key><string>com.example.webclip.profile</string>
  <key>PayloadUUID</key><string>87654321-4321-4321-8321-CBA987654321</string>
  <key>PayloadVersion</key><integer>1</integer>
  <key>PayloadType</key><string>Configuration</string>
  <key>PayloadOrganization</key><string>ConfigKit Example</string>
</dict>
</plist>',
array['apple','web clip','mobileconfig'],'published',true
where not exists (select 1 from public.configkit_templates where is_official and file_name='web-clip-example.mobileconfig');
