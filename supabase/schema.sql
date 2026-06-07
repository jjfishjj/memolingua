
-- Create app roles enum
CREATE TYPE public.app_role AS ENUM ('admin', 'user');

-- Create user_roles table
CREATE TABLE public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function for role checking
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- RLS for user_roles
CREATE POLICY "Users can view own roles" ON public.user_roles
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage roles" ON public.user_roles
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Create profiles table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    preferred_language TEXT DEFAULT 'english',
    preferred_difficulty TEXT DEFAULT 'intermediate',
    enable_data_collection BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture')
  );
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Conversations table
CREATE TABLE public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    language TEXT NOT NULL,
    scenario TEXT NOT NULL,
    difficulty TEXT NOT NULL DEFAULT 'intermediate',
    speed TEXT NOT NULL DEFAULT 'normal',
    tone TEXT NOT NULL DEFAULT 'semi-formal',
    mode TEXT NOT NULL DEFAULT 'practice',
    score_fluency NUMERIC,
    score_grammar NUMERIC,
    score_vocabulary NUMERIC,
    score_logic NUMERIC,
    score_overall NUMERIC,
    score_feedback TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    is_anonymized BOOLEAN DEFAULT false
);
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own conversations" ON public.conversations
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own conversations" ON public.conversations
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own conversations" ON public.conversations
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all conversations" ON public.conversations
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Messages table
CREATE TABLE public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    correction TEXT,
    suggestion TEXT,
    audio_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own messages" ON public.messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND c.user_id = auth.uid()
  ));
CREATE POLICY "Users can insert own messages" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND c.user_id = auth.uid()
  ));
CREATE POLICY "Admins can view all messages" ON public.messages
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
ALTER TABLE public.profiles ADD COLUMN learning_style text DEFAULT NULL;-- Allow admins to read all profiles
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Allow admins to insert conversations (for mock data generation)
CREATE POLICY "Admins can insert conversations"
ON public.conversations
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Allow admins to insert messages (for mock data generation)
CREATE POLICY "Admins can insert messages"
ON public.messages
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Allow admins to view all messages
-- (already exists, skip if error)
UPDATE public.user_roles SET role = 'admin' WHERE user_id = '2fa4a76c-8486-4cda-825f-1d144c8dd0d9';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (user_id, display_name, avatar_url, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture'),
    NEW.email
  );
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user');
  RETURN NEW;
END;
$function$;

-- Add image_url column to messages table
ALTER TABLE public.messages ADD COLUMN image_url text;

-- Create storage bucket for chat images
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-images', 'chat-images', true);

-- Allow authenticated users to upload
CREATE POLICY "Users can upload chat images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat-images');

-- Allow public read
CREATE POLICY "Public can read chat images" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'chat-images');

-- 1. energy_points: 能量點數帳戶
CREATE TABLE public.energy_points (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  balance INTEGER NOT NULL DEFAULT 0,
  lifetime_earned INTEGER NOT NULL DEFAULT 0,
  last_daily_login DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.energy_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own energy" ON public.energy_points FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own energy" ON public.energy_points FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own energy" ON public.energy_points FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can view all energy" ON public.energy_points FOR SELECT USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can manage all energy" ON public.energy_points FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE TRIGGER update_energy_points_updated_at BEFORE UPDATE ON public.energy_points
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. energy_transactions: 點數交易紀錄
CREATE TABLE public.energy_transactions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('practice_reward','daily_login','task_complete','purchase','shop_redeem','match_cost')),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.energy_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own transactions" ON public.energy_transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own transactions" ON public.energy_transactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can view all transactions" ON public.energy_transactions FOR SELECT USING (public.has_role(auth.uid(), 'admin'));

-- 3. user_interests: 兩層式興趣泡泡
CREATE TABLE public.user_interests (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  target_language TEXT NOT NULL DEFAULT 'english',
  learning_goals TEXT[] NOT NULL DEFAULT '{}',
  interest_topics TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_interests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own interests" ON public.user_interests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can upsert own interests" ON public.user_interests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own interests" ON public.user_interests FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Authenticated can view all interests for matching" ON public.user_interests FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admins can manage interests" ON public.user_interests FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE TRIGGER update_user_interests_updated_at BEFORE UPDATE ON public.user_interests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 4. daily_matches: 每日配對
CREATE TABLE public.daily_matches (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  matched_user_id UUID NOT NULL,
  compatibility_score INTEGER NOT NULL DEFAULT 0,
  match_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_free BOOLEAN NOT NULL DEFAULT true,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.daily_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own matches" ON public.daily_matches FOR SELECT USING (auth.uid() = user_id OR auth.uid() = matched_user_id);
CREATE POLICY "Users can insert own matches" ON public.daily_matches FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own matches" ON public.daily_matches FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = matched_user_id);
CREATE POLICY "Admins can view all matches" ON public.daily_matches FOR SELECT USING (public.has_role(auth.uid(), 'admin'));

CREATE INDEX idx_daily_matches_user_date ON public.daily_matches (user_id, match_date);

-- 5. friendships: 語伴關係 & 親密度
CREATE TABLE public.friendships (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_a_id UUID NOT NULL,
  user_b_id UUID NOT NULL,
  intimacy_score INTEGER NOT NULL DEFAULT 0,
  title TEXT NOT NULL DEFAULT '陌生人',
  chat_bg_color TEXT,
  message_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_a_id, user_b_id)
);
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own friendships" ON public.friendships FOR SELECT USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
CREATE POLICY "Users can insert friendships" ON public.friendships FOR INSERT WITH CHECK (auth.uid() = user_a_id OR auth.uid() = user_b_id);
CREATE POLICY "Users can update own friendships" ON public.friendships FOR UPDATE USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
CREATE POLICY "Admins can view all friendships" ON public.friendships FOR SELECT USING (public.has_role(auth.uid(), 'admin'));

CREATE TRIGGER update_friendships_updated_at BEFORE UPDATE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 6. shop_items: 配配幣商城
CREATE TABLE public.shop_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price INTEGER NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('avatar_frame','chat_bg','article_style','physical')),
  duration_days INTEGER,
  stock INTEGER,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view active items" ON public.shop_items FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);
CREATE POLICY "Admins can manage shop items" ON public.shop_items FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE TRIGGER update_shop_items_updated_at BEFORE UPDATE ON public.shop_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 7. user_purchases: 用戶購買紀錄
CREATE TABLE public.user_purchases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  shop_item_id UUID NOT NULL REFERENCES public.shop_items(id),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own purchases" ON public.user_purchases FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own purchases" ON public.user_purchases FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can view all purchases" ON public.user_purchases FOR SELECT USING (public.has_role(auth.uid(), 'admin'));

-- 8. Auto-create energy_points on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (user_id, display_name, avatar_url, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture'),
    NEW.email
  );
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user');
  INSERT INTO public.energy_points (user_id, balance, lifetime_earned) VALUES (NEW.id, 50, 50);
  INSERT INTO public.user_interests (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$function$;

-- Enable realtime for matches and friendships
ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.friendships;
