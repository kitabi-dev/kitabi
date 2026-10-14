CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  grade TEXT NOT NULL,
  muraqaba TEXT NOT NULL,
  role TEXT DEFAULT 'student',
  points INT DEFAULT 0,
  level INT DEFAULT 1,
  achievements INT DEFAULT 0,
  is_banned BOOLEAN DEFAULT FALSE,
  ban_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS books (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  grade TEXT NOT NULL,
  pdf_url TEXT,
  cover_url TEXT,
  description TEXT,
  size_kb INT DEFAULT 0,
  uploaded_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target_type TEXT DEFAULT 'all',
  target_value TEXT,
  sent_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  subject TEXT,
  grade TEXT,
  duration_min INT DEFAULT 0,
  uploaded_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  grade TEXT NOT NULL,
  questions JSONB DEFAULT '[]'::jsonb,
  duration_min INT DEFAULT 30,
  total_marks INT DEFAULT 100,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quiz_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  score INT DEFAULT 0,
  answers JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  content TEXT,
  subject TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_settings (
  id INT PRIMARY KEY DEFAULT 1,
  admin_password TEXT DEFAULT 'العلم نور',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO admin_settings (id, admin_password)
VALUES (1, 'العلم نور')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "all_users" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "all_books" ON books FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "all_notifications" ON notifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "all_videos" ON videos FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "all_quizzes" ON quizzes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "all_notes" ON notes FOR ALL USING (true) WITH CHECK (true);
