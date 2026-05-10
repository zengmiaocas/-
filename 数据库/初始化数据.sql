-- 1. 插入测试用户
-- 队长：张三 (密码: 123)
INSERT INTO users (phone, name, password, student_id, college, major, skills, is_first_login) 
VALUES ('13800000001', '张三', 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', '202300000001', '计算机学院', '软件工程', 'Python, FastAPI, Vue', 0);

-- 队员：李四 (密码: 123)
INSERT INTO users (phone, name, password, student_id, college, major, skills, is_first_login) 
VALUES ('13800000002', '李四', 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', '202300000002', '设计学院', '数字媒体', 'UI设计, Figma', 0);

-- 2. 插入测试项目
-- 张三发布了一个招募
INSERT INTO projects (id, title, leader_phone, description, tags, base_members, required_members, status) 
VALUES (1, '【急创大赛】寻一位靠谱UI设计', '13800000001', '目前已有两名后端，缺一位精通Figma的UI设计师一起打比赛。', 'UI设计, 前端', 2, 3, '招募中');

-- 3. 插入系统建群消息
INSERT INTO messages (sender_phone, chat_type, target_id, content) 
VALUES ('system', 'group', '1', '【系统】项目队伍已创建成功！');

-- 4. 插入李四的申请记录
-- 李四申请加入项目 (状态默认为 '待审核')
INSERT INTO applications (proj_id, applicant_phone, status, applicant_visible, leader_visible, leader_read, applicant_read) 
VALUES (1, '13800000002', '待审核', 1, 1, 0, 1);

-- 5. 插入一条私聊消息测试
-- 张三主动私聊李四
INSERT INTO messages (sender_phone, chat_type, target_id, content) 
VALUES ('13800000001', 'private', '13800000002', '你好，看了你的简历，请问你什么时候有空沟通一下？');