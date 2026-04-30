-- 用户表
CREATE TABLE IF NOT EXISTS users (
    phone TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    password TEXT NOT NULL,
    session_id TEXT,
    college TEXT DEFAULT '',
    major TEXT DEFAULT '',
    class_name TEXT DEFAULT '',
    qq TEXT DEFAULT '',
    wechat TEXT DEFAULT '',
    bio TEXT DEFAULT '',
    is_first_login INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 动态添加的字段（如果表已存在）
ALTER TABLE users ADD COLUMN skills TEXT DEFAULT '';
ALTER TABLE users ADD COLUMN honors TEXT DEFAULT '';
ALTER TABLE users ADD COLUMN student_id TEXT DEFAULT '';

-- 会话表
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id TEXT PRIMARY KEY,
    phone TEXT UNIQUE
);
