import sqlite3
import uvicorn
import hashlib
import uuid
import html
from contextlib import asynccontextmanager
from fastapi import FastAPI, Form, Request, Response
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse

DB_FILE = "campus_team_v11_clean.db"


# --- 1. 安全与辅助工具 ---
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()


def generate_session_id() -> str:
    return uuid.uuid4().hex


# --- 2. 数据库初始化 ---
def init_db():
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        cursor = conn.cursor()
        cursor.execute('''CREATE TABLE IF NOT EXISTS users
                          (
                              phone
                              TEXT
                              PRIMARY
                              KEY,
                              name
                              TEXT
                              NOT
                              NULL,
                              password
                              TEXT
                              NOT
                              NULL,
                              session_id
                              TEXT,
                              college
                              TEXT
                              DEFAULT
                              '',
                              major
                              TEXT
                              DEFAULT
                              '',
                              class_name
                              TEXT
                              DEFAULT
                              '',
                              qq
                              TEXT
                              DEFAULT
                              '',
                              wechat
                              TEXT
                              DEFAULT
                              '',
                              bio
                              TEXT
                              DEFAULT
                              '',
                              is_first_login
                              INTEGER
                              DEFAULT
                              1,
                              created_at
                              TIMESTAMP
                              DEFAULT
                              CURRENT_TIMESTAMP
                          )''')

        try:
            cursor.execute("ALTER TABLE users ADD COLUMN skills TEXT DEFAULT ''")
        except sqlite3.OperationalError:
            pass
        try:
            cursor.execute("ALTER TABLE users ADD COLUMN honors TEXT DEFAULT ''")
        except sqlite3.OperationalError:
            pass
        try:
            cursor.execute("ALTER TABLE users ADD COLUMN student_id TEXT DEFAULT ''")
        except sqlite3.OperationalError:
            pass

        cursor.execute("CREATE TABLE IF NOT EXISTS user_sessions (session_id TEXT PRIMARY KEY, phone TEXT UNIQUE)")
        # 其他表（projects, applications, messages, chat_state）的创建语句省略，因为登录注册不需要它们
        # 但如果你的代码中包含了这些表的创建，为了保持原样，这里也可以保留。为简洁起见，此处只保留了登录注册必需的表。
        conn.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="校园组队系统 - 仅登录注册版", lifespan=lifespan)


# --- 3. 核心查询接口 ---
def get_current_user(request: Request):
    session_id = request.cookies.get("session_token")
    if not session_id: return None
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        conn.row_factory = sqlite3.Row
        return conn.cursor().execute(
            "SELECT u.* FROM users u JOIN user_sessions s ON u.phone = s.phone WHERE s.session_id = ?",
            (session_id,)).fetchone()


@app.get("/api/check_session")
async def check_session(request: Request):
    session_id = request.cookies.get("session_token")
    if not session_id: return {"status": "logged_out"}
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        return {"status": "valid"} if conn.cursor().execute("SELECT phone FROM user_sessions WHERE session_id = ?",
                                                            (session_id,)).fetchone() else {"status": "logged_out"}


def alert_and_redirect(msg: str, url: str = "/"):
    return HTMLResponse(f"<script>alert('{msg}'); window.location.href='{url}';</script>")


# --- 4. 账号操作及页面路由 ---
@app.get("/login", response_class=HTMLResponse)
async def login_page():
    return """
    <!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><title>通行证</title><script src="https://cdn.tailwindcss.com"></script>
    <script>
        function toggleForm(id) { document.querySelectorAll('form').forEach(f=>f.classList.add('hidden')); document.getElementById(id).classList.remove('hidden'); }
        function toggleEye(inputId, iconId) {
            let p = document.getElementById(inputId); let i = document.getElementById(iconId);
            if(p.type==='password'){ p.type='text'; i.innerHTML='🙈'; } else { p.type='password'; i.innerHTML='👁️'; }
        }
    </script>
    </head><body class="bg-slate-50 h-screen flex items-center justify-center font-sans p-4">
        <div class="bg-white p-8 rounded-2xl shadow-xl w-full max-w-md border border-gray-100 relative overflow-hidden">
            <div class="absolute top-0 left-0 w-full h-2 bg-indigo-500"></div>

            <form id="login-form" action="/do_login" method="post" class="space-y-4">
                <h1 class="text-3xl font-black text-center text-indigo-600 mb-6">校园组队平台</h1>
                <input type="text" name="username" placeholder="学号 (12位) / 手机号" required class="w-full border p-3 rounded-lg outline-none focus:ring-2 ring-indigo-400">
                <div class="relative">
                    <input type="password" id="lp" name="password" placeholder="密码" required class="w-full border p-3 rounded-lg outline-none pr-10 focus:ring-2 ring-indigo-400">
                    <span id="le" onclick="toggleEye('lp','le')" class="absolute right-3 top-3 cursor-pointer opacity-60 hover:opacity-100 transition text-xl">👁️</span>
                </div>
                <button type="submit" class="w-full bg-indigo-600 text-white py-3 rounded-lg font-bold shadow-md hover:bg-indigo-700 transition">立即登录</button>
                <div class="flex justify-end text-sm mt-4">
                    <a href="#" onclick="toggleForm('reg-form')" class="text-indigo-600 font-bold hover:underline">没有账号？去注册</a>
                </div>
            </form>

            <form id="reg-form" action="/do_register" method="post" class="space-y-3 hidden">
                <h2 class="text-xl font-bold text-center mb-4 border-b pb-2">新用户注册</h2>
                <input type="text" name="student_id" placeholder="学号 (必须为12位数字)" minlength="12" maxlength="12" pattern="\d{12}" required class="w-full border p-2.5 rounded-lg outline-none focus:ring-2 ring-green-400">
                <input type="text" name="name" placeholder="真实姓名 / 昵称" required class="w-full border p-2.5 rounded-lg outline-none focus:ring-2 ring-green-400">
                <input type="tel" name="phone" placeholder="手机号码" required class="w-full border p-2.5 rounded-lg outline-none focus:ring-2 ring-green-400">
                <div class="relative">
                    <input type="password" id="rp1" name="password" placeholder="设置密码" required class="w-full border p-2.5 rounded-lg outline-none pr-10 focus:ring-2 ring-green-400">
                    <span id="re1" onclick="toggleEye('rp1','re1')" class="absolute right-3 top-2.5 cursor-pointer opacity-60 hover:opacity-100 transition text-xl">👁️</span>
                </div>
                <div class="relative">
                    <input type="password" id="rp2" name="confirm_password" placeholder="再次确认密码" required class="w-full border p-2.5 rounded-lg outline-none pr-10 focus:ring-2 ring-green-400">
                    <span id="re2" onclick="toggleEye('rp2','re2')" class="absolute right-3 top-2.5 cursor-pointer opacity-60 hover:opacity-100 transition text-xl">👁️</span>
                </div>
                <button type="submit" class="w-full bg-green-600 text-white py-2.5 rounded-lg font-bold hover:bg-green-700 transition mt-2">注册并登录</button>
                <div class="text-center text-sm mt-2"><a href="#" onclick="toggleForm('login-form')" class="text-gray-500 hover:underline">返回登录</a></div>
            </form>
        </div>
    </body></html>
    """


@app.post("/do_register")
async def do_register(student_id: str = Form(...), name: str = Form(...), phone: str = Form(...),
                      password: str = Form(...), confirm_password: str = Form(...)):
    if not student_id.isdigit() or len(student_id) != 12: return alert_and_redirect("学号必须严格为12位纯数字！",
                                                                                    "/login")
    if password != confirm_password: return alert_and_redirect("两次输入的密码不一致！", "/login")
    new_sess = generate_session_id()
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        try:
            conn.execute("INSERT INTO users (phone, name, password, student_id, is_first_login) VALUES (?, ?, ?, ?, 1)",
                         (phone, name, hash_password(password), student_id))
            conn.execute("DELETE FROM user_sessions WHERE phone = ?", (phone,))
            conn.execute("INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)", (new_sess, phone))
            conn.commit()
        except sqlite3.IntegrityError:
            return alert_and_redirect("手机号或学号已被注册过！", "/login")
    res = RedirectResponse(url="/", status_code=303);
    res.set_cookie("session_token", new_sess, max_age=604800);
    return res


@app.post("/do_login")
async def do_login(username: str = Form(...), password: str = Form(...)):
    new_sess = generate_session_id()
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        user = conn.cursor().execute("SELECT phone FROM users WHERE (phone=? OR student_id=?) AND password=?",
                                     (username, username, hash_password(password))).fetchone()
        if user:
            phone = user[0]
            conn.execute("DELETE FROM user_sessions WHERE phone = ?", (phone,))
            conn.execute("INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)", (new_sess, phone))
            conn.commit()
            res = RedirectResponse(url="/", status_code=303);
            res.set_cookie("session_token", new_sess, max_age=604800);
            return res
        return alert_and_redirect("❌ 账号或密码错误！", "/login")


@app.post("/change_password")
async def change_password(request: Request, student_id: str = Form(...), phone: str = Form(...),
                          old_password: str = Form(...), new_password: str = Form(...),
                          confirm_new_password: str = Form(...)):
    user = get_current_user(request)
    if not user: return JSONResponse({"msg": "登录已过期，请刷新页面重新登录！"})
    if new_password != confirm_new_password: return JSONResponse({"msg": "两次输入的新密码不一致！"})
    if user['phone'] != phone or user['student_id'] != student_id: return JSONResponse(
        {"msg": "填写的学号或手机号与当前登录账号不匹配，无法修改！"})

    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        curr = conn.cursor().execute("SELECT phone FROM users WHERE phone=? AND password=?",
                                     (phone, hash_password(old_password))).fetchone()
        if not curr: return JSONResponse({"msg": "❌ 您输入的旧密码错误！"})

        conn.execute("UPDATE users SET password=? WHERE phone=?", (hash_password(new_password), phone))
        conn.commit()
    return JSONResponse({"msg": "✅ 密码修改成功！下次请使用新密码登录。"})


@app.get("/logout")
async def logout(request: Request):
    session_id = request.cookies.get("session_token")
    if session_id:
        with sqlite3.connect(DB_FILE, timeout=10) as conn:
            conn.execute("DELETE FROM user_sessions WHERE session_id = ?", (session_id,));
            conn.commit()
    res = alert_and_redirect("已安全退出本设备！", "/login")
    res.delete_cookie("session_token")
    return res


if __name__ == "__main__":
    print("===================================================")
    print("🚀 登录注册服务启动成功！")
    print("🌐 访问地址: http://127.0.0.1:8000/login")
    print("===================================================")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")
