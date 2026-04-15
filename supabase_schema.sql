-- ============================================================
-- ArtUp — Supabase SQL Schema
-- Paste this entire file into Supabase → SQL Editor → Run
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── PROFILES ────────────────────────────────────────────────
create table public.profiles (
  id           uuid references auth.users on delete cascade primary key,
  handle       text unique not null,
  full_name    text not null default '',
  bio          text not null default '',
  avatar_url   text not null default '',
  website      text not null default '',
  created_at   timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, handle, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'handle', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'avatar_url', '')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── POSTS ────────────────────────────────────────────────────
create table public.posts (
  id           uuid default uuid_generate_v4() primary key,
  author_id    uuid references public.profiles(id) on delete cascade not null,
  title        text not null,
  description  text not null default '',
  image_url    text not null,
  category     text not null default '2D Illustration',
  tags         text[] not null default '{}',
  visibility   text not null default 'public' check (visibility in ('public','followers','private')),
  likes_count  int not null default 0,
  created_at   timestamptz default now()
);

-- ── LIKES ────────────────────────────────────────────────────
create table public.likes (
  id        uuid default uuid_generate_v4() primary key,
  post_id   uuid references public.posts(id) on delete cascade not null,
  user_id   uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);

-- Auto update likes_count on posts
create or replace function public.handle_like_insert()
returns trigger as $$
begin
  update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.handle_like_delete()
returns trigger as $$
begin
  update public.posts set likes_count = likes_count - 1 where id = old.post_id;
  return old;
end;
$$ language plpgsql security definer;

create trigger on_like_insert after insert on public.likes
  for each row execute procedure public.handle_like_insert();

create trigger on_like_delete after delete on public.likes
  for each row execute procedure public.handle_like_delete();

-- ── COMMENTS ─────────────────────────────────────────────────
create table public.comments (
  id         uuid default uuid_generate_v4() primary key,
  post_id    uuid references public.posts(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  body       text not null,
  created_at timestamptz default now()
);

-- ── FOLLOWS ──────────────────────────────────────────────────
create table public.follows (
  id           uuid default uuid_generate_v4() primary key,
  follower_id  uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at   timestamptz default now(),
  unique(follower_id, following_id)
);

-- ── CONVERSATIONS ─────────────────────────────────────────────
create table public.conversations (
  id           uuid default uuid_generate_v4() primary key,
  participant1 uuid references public.profiles(id) on delete cascade not null,
  participant2 uuid references public.profiles(id) on delete cascade not null,
  last_message text not null default '',
  updated_at   timestamptz default now(),
  unique(participant1, participant2)
);

-- ── MESSAGES ─────────────────────────────────────────────────
create table public.messages (
  id              uuid default uuid_generate_v4() primary key,
  conversation_id uuid references public.conversations(id) on delete cascade not null,
  sender_id       uuid references public.profiles(id) on delete cascade not null,
  body            text not null,
  created_at      timestamptz default now()
);

-- Auto update conversation's last_message + updated_at
create or replace function public.handle_new_message()
returns trigger as $$
begin
  update public.conversations
  set last_message = new.body, updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_message_insert after insert on public.messages
  for each row execute procedure public.handle_new_message();

-- ── ROW LEVEL SECURITY ────────────────────────────────────────
alter table public.profiles     enable row level security;
alter table public.posts        enable row level security;
alter table public.likes        enable row level security;
alter table public.comments     enable row level security;
alter table public.follows      enable row level security;
alter table public.conversations enable row level security;
alter table public.messages     enable row level security;

-- Profiles: anyone can read, only owner can update
create policy "Public profiles are viewable by everyone" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);

-- Posts: public posts visible to all, followers/private handled in app
create policy "Public posts viewable by all" on public.posts for select using (visibility = 'public' or author_id = auth.uid());
create policy "Users can insert own posts" on public.posts for insert with check (auth.uid() = author_id);
create policy "Users can update own posts" on public.posts for update using (auth.uid() = author_id);
create policy "Users can delete own posts" on public.posts for delete using (auth.uid() = author_id);

-- Likes
create policy "Likes viewable by all" on public.likes for select using (true);
create policy "Users can like" on public.likes for insert with check (auth.uid() = user_id);
create policy "Users can unlike" on public.likes for delete using (auth.uid() = user_id);

-- Comments
create policy "Comments viewable by all" on public.comments for select using (true);
create policy "Users can comment" on public.comments for insert with check (auth.uid() = author_id);
create policy "Users can delete own comments" on public.comments for delete using (auth.uid() = author_id);

-- Follows
create policy "Follows viewable by all" on public.follows for select using (true);
create policy "Users can follow" on public.follows for insert with check (auth.uid() = follower_id);
create policy "Users can unfollow" on public.follows for delete using (auth.uid() = follower_id);

-- Conversations: only participants can see
create policy "Participants can view conversations" on public.conversations for select using (auth.uid() = participant1 or auth.uid() = participant2);
create policy "Users can create conversations" on public.conversations for insert with check (auth.uid() = participant1 or auth.uid() = participant2);
create policy "Participants can update conversations" on public.conversations for update using (auth.uid() = participant1 or auth.uid() = participant2);

-- Messages: only participants can see/send
create policy "Participants can view messages" on public.messages for select using (
  exists (
    select 1 from public.conversations c
    where c.id = conversation_id and (c.participant1 = auth.uid() or c.participant2 = auth.uid())
  )
);
create policy "Users can send messages" on public.messages for insert with check (auth.uid() = sender_id);

-- ── STORAGE BUCKETS ──────────────────────────────────────────
-- Run these in Supabase → Storage → New Bucket (or via SQL):
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('posts', 'posts', true) on conflict do nothing;

create policy "Avatar images are publicly accessible" on storage.objects for select using (bucket_id = 'avatars');
create policy "Users can upload avatars" on storage.objects for insert with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "Users can update avatars" on storage.objects for update using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Post images are publicly accessible" on storage.objects for select using (bucket_id = 'posts');
create policy "Users can upload post images" on storage.objects for insert with check (bucket_id = 'posts' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "Users can delete own post images" on storage.objects for delete using (bucket_id = 'posts' and auth.uid()::text = (storage.foldername(name))[1]);

-- ── HELPER VIEWS ─────────────────────────────────────────────
-- Posts with author info joined (useful for feed queries)
create or replace view public.posts_with_author as
select
  p.*,
  pr.handle        as author_handle,
  pr.full_name     as author_name,
  pr.avatar_url    as author_avatar
from public.posts p
join public.profiles pr on pr.id = p.author_id;

-- Follower / following counts per profile
create or replace view public.profile_stats as
select
  pr.id,
  pr.handle,
  pr.full_name,
  pr.bio,
  pr.avatar_url,
  pr.website,
  count(distinct f1.follower_id) as followers_count,
  count(distinct f2.following_id) as following_count,
  count(distinct po.id)           as posts_count
from public.profiles pr
left join public.follows f1 on f1.following_id = pr.id
left join public.follows f2 on f2.follower_id  = pr.id
left join public.posts   po on po.author_id    = pr.id
group by pr.id;

-- ── SCHEMA UPDATE v2 ─────────────────────────────────────────────────────────
-- Run this block in Supabase SQL Editor after initial schema setup

-- Add image_urls column to posts (if not already present)
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS image_urls text[] NOT NULL DEFAULT '{}';

-- Refresh the posts_with_author view to include image_urls
CREATE OR REPLACE VIEW public.posts_with_author AS
SELECT
  p.*,
  pr.handle      AS author_handle,
  pr.full_name   AS author_name,
  pr.avatar_url  AS author_avatar
FROM public.posts p
JOIN public.profiles pr ON pr.id = p.author_id;

-- ── LINKED ACCOUNTS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.linked_accounts (
  id         uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  owner_id   uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  linked_id  uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(owner_id, linked_id)
);

ALTER TABLE public.linked_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view linked accounts"
  ON public.linked_accounts FOR SELECT USING (true);

CREATE POLICY "Users can add linked accounts"
  ON public.linked_accounts FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can remove linked accounts"
  ON public.linked_accounts FOR DELETE
  USING (auth.uid() = owner_id);

-- ── ADD age_rating TO POSTS ───────────────────────────────────────────────────
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS age_rating text NOT NULL DEFAULT 'All Ages'
  CHECK (age_rating IN ('All Ages', '13+', '17+', '18+'));

-- Refresh view again to include age_rating
CREATE OR REPLACE VIEW public.posts_with_author AS
SELECT
  p.*,
  pr.handle      AS author_handle,
  pr.full_name   AS author_name,
  pr.avatar_url  AS author_avatar
FROM public.posts p
JOIN public.profiles pr ON pr.id = p.author_id;
