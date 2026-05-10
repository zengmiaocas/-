-- 1. 用户表 (Users)
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    skills TEXT DEFAULT '',
    honors TEXT DEFAULT '',
    student_id TEXT DEFAULT ''
);

-- 2. 用户会话表 (User Sessions)
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id TEXT PRIMARY KEY, 
    phone TEXT UNIQUE
);

-- 3. 招募项目表 (Projects)
CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    leader_phone TEXT NOT NULL,
    description TEXT,
    tags TEXT,
    base_members INTEGER NOT NULL DEFAULT 1,
    required_members INTEGER NOT NULL DEFAULT 3,
    status TEXT DEFAULT '招募中',
    is_deleted INTEGER DEFAULT 0,
    is_hidden INTEGER DEFAULT 0,
    FOREIGN KEY (leader_phone) REFERENCES users (phone)
);

-- 4. 组队申请表 (Applications)
CREATE TABLE IF NOT EXISTS applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    proj_id INTEGER,
    applicant_phone TEXT NOT NULL,
    status TEXT DEFAULT '待审核',
    applicant_visible INTEGER DEFAULT 1,
    leader_visible INTEGER DEFAULT 1,
    leader_read INTEGER DEFAULT 0,
    applicant_read INTEGER DEFAULT 0,
    FOREIGN KEY (proj_id) REFERENCES projects (id), 
    FOREIGN KEY (applicant_phone) REFERENCES users (phone)
);
-- 为申请表创建唯一索引，防止同一用户对同一项目重复发起有效申请
CREATE UNIQUE INDEX IF NOT EXISTS idx_proj_user ON applications(proj_id, applicant_phone);

-- 5. 消息记录表 (Messages)
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_phone TEXT NOT NULL,
    chat_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. 聊天游标状态表 (Chat State)
CREATE TABLE IF NOT EXISTS chat_state (
    phone TEXT,
    chat_type TEXT,
    target_id TEXT,
    last_read_msg_id INTEGER DEFAULT 0,
    cleared_up_to_msg_id INTEGER DEFAULT 0,
    PRIMARY KEY (phone, chat_type, target_id)
);
