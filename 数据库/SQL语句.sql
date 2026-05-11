--数据库建表与初始化--
-- 1. 创建 users 表
CREATE TABLE IF NOT EXISTS users (phone TEXT PRIMARY KEY, name TEXT NOT NULL, password TEXT NOT NULL, session_id TEXT, college TEXT DEFAULT '', major TEXT DEFAULT '', class_name TEXT DEFAULT '', qq TEXT DEFAULT '', wechat TEXT DEFAULT '', bio TEXT DEFAULT '', is_first_login INTEGER DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

-- 2. 动态为 users 表添加字段
ALTER TABLE users ADD COLUMN skills TEXT DEFAULT ''
ALTER TABLE users ADD COLUMN honors TEXT DEFAULT ''
ALTER TABLE users ADD COLUMN student_id TEXT DEFAULT ''

-- 3. 创建 user_sessions 表
CREATE TABLE IF NOT EXISTS user_sessions (session_id TEXT PRIMARY KEY, phone TEXT UNIQUE)

-- 4. 创建 projects 表
CREATE TABLE IF NOT EXISTS projects (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, leader_phone TEXT NOT NULL, description TEXT, tags TEXT, base_members INTEGER NOT NULL DEFAULT 1, required_members INTEGER NOT NULL DEFAULT 3, status TEXT DEFAULT '招募中', is_deleted INTEGER DEFAULT 0, is_hidden INTEGER DEFAULT 0, FOREIGN KEY (leader_phone) REFERENCES users (phone))

-- 5. 创建 applications 表
CREATE TABLE IF NOT EXISTS applications (id INTEGER PRIMARY KEY AUTOINCREMENT, proj_id INTEGER, applicant_phone TEXT NOT NULL, status TEXT DEFAULT '待审核', applicant_visible INTEGER DEFAULT 1, leader_visible INTEGER DEFAULT 1, FOREIGN KEY (proj_id) REFERENCES projects (id), FOREIGN KEY (applicant_phone) REFERENCES users (phone))

-- 6. 动态为 applications 表添加字段
ALTER TABLE applications ADD COLUMN leader_read INTEGER DEFAULT 0
ALTER TABLE applications ADD COLUMN applicant_read INTEGER DEFAULT 0

-- 7. 创建申请表唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_proj_user ON applications(proj_id, applicant_phone)

-- 8. 创建 messages 表
CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, sender_phone TEXT NOT NULL, chat_type TEXT NOT NULL, target_id TEXT NOT NULL, content TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

-- 9. 创建 chat_state 表
CREATE TABLE IF NOT EXISTS chat_state (phone TEXT, chat_type TEXT, target_id TEXT, last_read_msg_id INTEGER DEFAULT 0, cleared_up_to_msg_id INTEGER DEFAULT 0, PRIMARY KEY (phone, chat_type, target_id))

-- 10. 检查是否为空库 (用于初始化数据)
SELECT COUNT(*) FROM users

-- 11. 插入初始化测试账号
INSERT INTO users (phone, student_id, name, password, college, major, skills, is_first_login) VALUES (?, ?, ?, ?, ?, ?, ?, ?)

-- 12. 插入初始化招募项目
INSERT INTO projects (title, leader_phone, description, tags, base_members, required_members, status) VALUES (?, ?, ?, ?, ?, ?, ?)

-- 13. 插入初始化群聊系统消息
INSERT INTO messages (sender_phone, chat_type, target_id, content) VALUES (?, ?, ?, ?)

--用户认证与个人资料 (User & Auth)--
-- 1. 根据 session_id 获取当前用户
SELECT u.* FROM users u JOIN user_sessions s ON u.phone = s.phone WHERE s.session_id = ?

-- 2. 检查 session_id 是否有效
SELECT phone FROM user_sessions WHERE session_id = ?

-- 3. 获取用户公开资料
SELECT phone, name, college, major, class_name, qq, wechat, bio, skills, honors, student_id FROM users WHERE phone = ?

-- 4. 用户注册
INSERT INTO users (phone, name, password, student_id, is_first_login) VALUES (?, ?, ?, ?, 1)

-- 5. 登录/注册时刷新会话
DELETE FROM user_sessions WHERE phone = ?
INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)

-- 6. 登录验证 (支持手机号或学号)
SELECT phone FROM users WHERE (phone=? OR student_id=?) AND password=?

-- 7. 修改密码校验
SELECT phone FROM users WHERE phone=? AND password=?

-- 8. 执行修改密码
UPDATE users SET password=? WHERE phone=?

-- 9. 登出
DELETE FROM user_sessions WHERE session_id = ?

-- 10. 取消首次登录标记
UPDATE users SET is_first_login=0 WHERE phone=?

-- 11. 更新个人资料
UPDATE users SET name=?, college=?, major=?, class_name=?, qq=?, wechat=?, bio=?, skills=?, honors=? WHERE phone=?

--招募项目与申请管理 (Projects & Applications)--
-- 1. 查询大厅项目列表与状态
SELECT p.*, u.name as leader_name, (SELECT status FROM applications WHERE proj_id = p.id AND applicant_phone = ?) as my_status, (SELECT COUNT(*) FROM applications WHERE proj_id = p.id AND status = '已同意') as approved_count FROM projects p JOIN users u ON p.leader_phone = u.phone WHERE p.is_deleted = 0 AND (p.is_hidden = 0 OR p.leader_phone = ?) ORDER BY p.id DESC

-- 2. 查询我的申请记录
SELECT a.id as app_id, p.id as proj_id, p.title, a.status FROM applications a JOIN projects p ON a.proj_id = p.id WHERE a.applicant_phone = ? AND p.is_deleted = 0 AND a.applicant_visible = 1 ORDER BY a.id DESC

-- 3. 队长查询收到的申请
SELECT a.id as app_id, p.id as proj_id, p.title, u.phone as applicant_phone, u.name as applicant_name, u.honors as applicant_honors, a.status FROM applications a JOIN projects p ON a.proj_id = p.id JOIN users u ON a.applicant_phone = u.phone WHERE p.leader_phone = ? AND p.is_deleted = 0 AND a.leader_visible = 1 ORDER BY a.id DESC

-- 4. 红点统计：待审核数量 & 申请反馈数量
SELECT COUNT(*) FROM applications a JOIN projects p ON a.proj_id = p.id WHERE p.leader_phone = ? AND p.is_deleted = 0 AND a.status = '待审核' AND a.leader_read = 0
SELECT COUNT(*) FROM applications WHERE applicant_phone = ? AND status IN ('已同意', '已拒绝', '已移出') AND applicant_visible = 1 AND applicant_read = 0

-- 5. 查询各项目已同意的成员
SELECT a.proj_id, u.phone, u.name FROM applications a JOIN users u ON a.applicant_phone = u.phone WHERE a.status = '已同意'

-- 6. 标记为已读
UPDATE applications SET leader_read=1 WHERE id IN (SELECT a.id FROM applications a JOIN projects p ON a.proj_id=p.id WHERE p.leader_phone=? AND a.status='待审核')
UPDATE applications SET applicant_read=1 WHERE applicant_phone=? AND status IN ('已同意', '已拒绝', '已移出')

-- 7. 发布新项目
INSERT INTO projects (title, leader_phone, description, tags, base_members, required_members) VALUES (?, ?, ?, ?, ?, ?)

-- 8. 切换隐藏状态 / 删除项目 / 切换招募状态
SELECT is_hidden FROM projects WHERE id = ? AND leader_phone = ?
UPDATE projects SET is_hidden = ? WHERE id = ?
UPDATE projects SET is_deleted=1 WHERE id=? AND leader_phone=?
SELECT status FROM projects WHERE id=?
UPDATE projects SET status=? WHERE id=?

-- 9. 申请加入项目逻辑
SELECT id, status FROM applications WHERE proj_id=? AND applicant_phone=?
UPDATE applications SET status='待审核', applicant_visible=1, leader_visible=1, leader_read=0 WHERE id=?
INSERT INTO applications (proj_id, applicant_phone, leader_read, applicant_read) VALUES (?, ?, 0, 1)

-- 10. 撤销申请 / 隐藏记录
UPDATE applications SET status='已取消', applicant_visible=0 WHERE id=? AND applicant_phone=? AND status='待审核'
UPDATE applications SET applicant_visible=0 WHERE id=? AND applicant_phone=?
UPDATE applications SET leader_visible=0 WHERE id=?

-- 11. 队长审批操作
UPDATE applications SET status=?, applicant_read=0 WHERE id=?
SELECT base_members, required_members FROM projects WHERE id = ?
SELECT COUNT(*) FROM applications WHERE proj_id=? AND status='已同意'
UPDATE projects SET status='已截止', is_hidden=1 WHERE id=?

-- 12. 移出成员
SELECT name FROM users WHERE phone = ?
UPDATE applications SET status='已移出', applicant_read=0 WHERE proj_id=? AND applicant_phone=?

--实时聊天与消息系统 (Messages & Chats)--
-- 1. 轮询获取新消息 (群聊+私聊混合查询，其中 {placeholders} 为 Python 动态拼装的 ?)
SELECT m.*, u.name as sender_name FROM messages m LEFT JOIN users u ON m.sender_phone = u.phone WHERE m.id > ? AND m.sender_phone != ? AND ((m.chat_type = 'private' AND m.target_id = ?) OR (m.chat_type = 'group' AND m.target_id IN ({placeholders}))) ORDER BY m.id ASC

-- 2. 轮询获取新消息 (仅私聊兜底查询)
SELECT m.*, u.name as sender_name FROM messages m LEFT JOIN users u ON m.sender_phone = u.phone WHERE m.id > ? AND m.sender_phone != ? AND m.chat_type = 'private' AND m.target_id = ? ORDER BY m.id ASC

-- 3. 获取用户参与的群聊和私聊列表
SELECT id as target_id, title as name, 'group' as type FROM projects WHERE leader_phone = ? AND is_deleted = 0 UNION SELECT p.id, p.title, 'group' FROM projects p JOIN applications a ON p.id = a.proj_id WHERE a.applicant_phone = ? AND a.status = '已同意' AND p.is_deleted = 0
SELECT DISTINCT u.phone as target_id, u.name as name, 'private' as type FROM messages m JOIN users u ON (u.phone = m.target_id AND m.sender_phone = ?) OR (u.phone = m.sender_phone AND m.target_id = ?) WHERE m.chat_type = 'private' AND u.phone != ?

-- 4. 读取聊天游标状态及未读数
SELECT last_read_msg_id, cleared_up_to_msg_id FROM chat_state WHERE phone=? AND chat_type=? AND target_id=?
SELECT COUNT(*) FROM messages WHERE chat_type='group' AND target_id=? AND sender_phone!=? AND id>? AND id>?
SELECT COUNT(*) FROM messages WHERE chat_type='private' AND sender_phone=? AND target_id=? AND id>? AND id>?
SELECT cleared_up_to_msg_id FROM chat_state WHERE phone=? AND chat_type=? AND target_id=?

-- 5. 获取历史消息 (群聊 & 私聊)
SELECT m.*, u.name as sender_name FROM messages m LEFT JOIN users u ON m.sender_phone = u.phone WHERE chat_type = 'group' AND target_id = ? AND m.id > ? ORDER BY created_at ASC
SELECT m.*, u.name as sender_name FROM messages m LEFT JOIN users u ON m.sender_phone = u.phone WHERE chat_type = 'private' AND ((sender_phone = ? AND target_id = ?) OR (sender_phone = ? AND target_id = ?)) AND m.id > ? ORDER BY created_at ASC

-- 6. 更新阅读游标状态
SELECT 1 FROM chat_state WHERE phone=? AND chat_type=? AND target_id=?
UPDATE chat_state SET last_read_msg_id=? WHERE phone=? AND chat_type=? AND target_id=?
INSERT INTO chat_state (phone, chat_type, target_id, last_read_msg_id) VALUES (?, ?, ?, ?)

-- 7. 发送消息 / 写入系统消息
INSERT INTO messages (sender_phone, chat_type, target_id, content) VALUES (?, ?, ?, ?)
INSERT INTO messages (sender_phone, chat_type, target_id, content) VALUES ('system', 'group', ?, ?)

-- 8. 清空聊天记录 (获取最大消息ID并更新游标)
SELECT MAX(id) FROM messages WHERE chat_type='group' AND target_id=?
SELECT MAX(id) FROM messages WHERE chat_type='private' AND ((sender_phone=? AND target_id=?) OR (sender_phone=? AND target_id=?))
UPDATE chat_state SET cleared_up_to_msg_id=?, last_read_msg_id=? WHERE phone=? AND chat_type=? AND target_id=?
INSERT INTO chat_state (phone, chat_type, target_id, cleared_up_to_msg_id, last_read_msg_id) VALUES (?, ?, ?, ?, ?)

-- 9. 获取聊天群成员身份
SELECT leader_phone FROM projects WHERE id = ?
SELECT u.phone, u.name, '队长' as role FROM projects p JOIN users u ON p.leader_phone = u.phone WHERE p.id = ? UNION SELECT u.phone, u.name, '队员' as role FROM applications a JOIN users u ON a.applicant_phone = u.phone WHERE a.proj_id = ? AND a.status = '已同意'
