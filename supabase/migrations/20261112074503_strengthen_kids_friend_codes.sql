alter table public.family_children
  alter column friend_code set default upper(substr(encode(gen_random_bytes(10), 'hex'), 1, 16));
update public.family_children
set friend_code = upper(substr(encode(gen_random_bytes(10), 'hex'), 1, 16))
where char_length(friend_code) <> 16;
alter table public.family_children drop constraint if exists family_children_friend_code_length_check;
alter table public.family_children add constraint family_children_friend_code_length_check check (char_length(friend_code) = 16);