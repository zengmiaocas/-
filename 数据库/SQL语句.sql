--初始化数据库--
-- 创建 users 表
CREATE TABLE IF NOT EXISTS users (phone TEXT PRIMARY KEY, name TEXT NOT NULL, password TEXT NOT NULL, session_id TEXT, college TEXT DEFAULT '', major TEXT DEFAULT '', class_name TEXT DEFAULT '', qq TEXT DEFAULT '', wechat TEXT DEFAULT '', bio TEXT DEFAULT '', is_first_login INTEGER DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

-- 升级 users 表 (增加字段)
ALTER TABLE users ADD COLUMN skills TEXT DEFAULT ''
ALTER TABLE users ADD COLUMN honors TEXT DEFAULT ''
ALTER TABLE users ADD COLUMN student_id TEXT DEFAULT ''

-- 创建会话表
CREATE TABLE IF NOT EXISTS user_sessions (session_id TEXT PRIMARY KEY, phone TEXT UNIQUE)

-- 创建 projects 表
CREATE TABLE IF NOT EXISTS projects (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, leader_phone TEXT NOT NULL, description TEXT, tags TEXT, base_members INTEGER NOT NULL DEFAULT 1, required_members INTEGER NOT NULL DEFAULT 3, status TEXT DEFAULT '招募中', is_deleted INTEGER DEFAULT 0, is_hidden INTEGER DEFAULT 0, FOREIGN KEY (leader_phone) REFERENCES users (phone))

-- 创建 applications 表
CREATE TABLE IF NOT EXISTS applications (id INTEGER PRIMARY KEY AUTOINCREMENT, proj_id INTEGER, applicant_phone TEXT NOT NULL, status TEXT DEFAULT '待审核', applicant_visible INTEGER DEFAULT 1, leader_visible INTEGER DEFAULT 1, FOREIGN KEY (proj_id) REFERENCES projects (id), FOREIGN KEY (applicant_phone) REFERENCES users (phone))

-- 升级 applications 表
ALTER TABLE applications ADD COLUMN leader_read INTEGER DEFAULT 0
ALTER TABLE applications ADD COLUMN applicant_read INTEGER DEFAULT 0

-- 建立索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_proj_user ON applications(proj_id, applicant_phone)

-- 创建 messages 表
CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, sender_phone TEXT NOT NULL, chat_type TEXT NOT NULL, target_id TEXT NOT NULL, content TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

-- 创建 chat_state 表
CREATE TABLE IF NOT EXISTS chat_state (phone TEXT, chat_type TEXT, target_id TEXT, last_read_msg_id INTEGER DEFAULT 0, cleared_up_to_msg_id INTEGER DEFAULT 0, PRIMARY KEY (phone, chat_type, target_id))

--账号与身份验证
SELECT u.* FROM users u JOIN user_sessions s ON u.phone = s.phone WHERE s.session_id = ?
    
SELECT phone FROM user_sessions WHERE session_id = ?
    
INSERT INTO users (phone, name, password, student_id, is_first_login) VALUES (?, ?, ?, ?, 1)
DELETE FROM user_sessions WHERE phone = ?
INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)

SELECT phone FROM users WHERE (phone=? OR student_id=?) AND password=?
DELETE FROM user_sessions WHERE phone = ?
INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)

SELECT phone FROM users WHERE phone=? AND password=?
UPDATE users SET password=? WHERE phone=?

DELETE FROM user_sessions WHERE session_id = ?

--用户资料查询与更新--
SELECT phone, name, college, major, class_name, qq, wechat, bio, skills, honors, student_id FROM users WHERE phone = ?

UPDATE users SET name=?, college=?, major=?, class_name=?, qq=?, wechat=?, bio=?, skills=?, honors=? WHERE phone=?

UPDATE users SET is_first_login=0 WHERE phone=?

--招募大厅--
-- 查询大厅所有未删除、未隐藏(或属于自己)的项目
SELECT p.*, u.name as leader_name, (SELECT status FROM applications WHERE proj_id = p.id AND applicant_phone = ?) as my_status, (SELECT COUNT(*) FROM applications WHERE proj_id = p.id AND status = '已同意') as approved_count FROM projects p JOIN users u ON p.leader_phone = u.phone WHERE p.is_deleted = 0 AND (p.is_hidden = 0 OR p.leader_phone = ?) ORDER BY p.id DESC

-- 查询我的申请记录
SELECT a.id as app_id, p.id as proj_id, p.title, a.status FROM applications a JOIN projects p ON a.proj_id = p.id WHERE a.applicant_phone = ? AND p.is_deleted = 0 AND a.applicant_visible = 1 ORDER BY a.id DESC

-- 查询别人对我的项目的申请记录
SELECT a.id as app_id, p.id as proj_id, p.title, u.phone as applicant_phone, u.name as applicant_name, u.honors as applicant_honors, a.status FROM applications a JOIN projects p ON a.proj_id = p.id JOIN users u ON a.applicant_phone = u.phone WHERE p.leader_phone = ? AND p.is_deleted = 0 AND a.leader_visible = 1 ORDER BY a.id DESC

-- 统计待审核红点
SELECT COUNT(*) FROM applications a JOIN projects p ON a.proj_id = p.id WHERE p.leader_phone = ? AND p.is_deleted = 0 AND a.status = '待审核' AND a.leader_read = 0

-- 统计我的申请结果红点
SELECT COUNT(*) FROM applications WHERE applicant_phone = ? AND status IN ('已同意', '已拒绝', '已移出') AND applicant_visible = 1 AND applicant_read = 0

-- 查取已同意的组员
SELECT a.proj_id, u.phone, u.name FROM applications a JOIN users u ON a.applicant_phone = u.phone WHERE a.status = '已同意'

--消息轮询与已读操作--
-- 获取当前用户建立的项目ID
SELECT id FROM projects WHERE leader_phone = ? AND is_deleted=0
-- 获取当前用户已加入的项目群聊ID
SELECT proj_id FROM applications WHERE applicant_phone = ? AND status = '已同意'
-- 查询未读消息 (如果有群聊)
SELECT m.*, u.name as sender_name FROM messages m LEFT JOIN users u ON m.sender_phone = u.phone WHERE m.id > ? AND m.sender_phone != ? AND ((m.chat_type = 'private' AND m.target_id = ?) OR (m.chat_type = 'group' AND m.target_id IN ({placeholders}))) ORDER BY m.id ASC
-- 查询未读消息 (如果没有群聊)
SELECT m.*, u.name as sender_name FROM messages m LEFT JOIN users u ON m.sender_phone = u.phone WHERE m.id > ? AND m.sender_phone != ? AND m.chat_type = 'private' AND m.target_id = ? ORDER BY m.id ASC

-- 队长一键已读申请
UPDATE applications SET leader_read=1 WHERE id IN (SELECT a.id FROM applications a JOIN projects p ON a.proj_id=p.id WHERE p.leader_phone=? AND a.status='待审核')
-- 申请者一键已读结果
UPDATE applications SET applicant_read=1 WHERE applicant_phone=? AND status IN ('已同意', '已拒绝', '已移出')

--项目与申请的变更操作--
SELECT is_hidden FROM projects WHERE id = ? AND leader_phone = ?
UPDATE projects SET is_hidden = ? WHERE id = ?

UPDATE projects SET is_deleted=1 WHERE id=? AND leader_phone=?

SELECT id, status FROM applications WHERE proj_id=? AND applicant_phone=?
-- 若重新申请
UPDATE applications SET status='待审核', applicant_visible=1, leader_visible=1, leader_read=0 WHERE id=?
-- 若首次申请
INSERT INTO applications (proj_id, applicant_phone, leader_read, applicant_read) VALUES (?, ?, 0, 1)

UPDATE applications SET status='已取消', applicant_visible=0 WHERE id=? AND applicant_phone=? AND status='待审核'

SELECT status FROM projects WHERE id=?
UPDATE projects SET status=? WHERE id=?
