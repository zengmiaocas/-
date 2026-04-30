import sqlite3
import uvicorn
import hashlib
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Form, Request, Response
from fastapi.responses import RedirectResponse, JSONResponse

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
        conn.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="校园组队系统 - 纯后端API", lifespan=lifespan)


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
        exists = conn.cursor().execute("SELECT phone FROM user_sessions WHERE session_id = ?",
                                       (session_id,)).fetchone()
        return {"status": "valid"} if exists else {"status": "logged_out"}


def alert_and_redirect(msg: str, url: str = "/"):
    # 这里保留原函数，但您可以按需改用 JSON 响应
    return JSONResponse({"msg": msg, "redirect": url})


# --- 4. 账号操作 API（注册、登录、修改密码、登出）---
@app.post("/do_register")
async def do_register(student_id: str = Form(...), name: str = Form(...), phone: str = Form(...),
                      password: str = Form(...), confirm_password: str = Form(...)):
    if not student_id.isdigit() or len(student_id) != 12:
        return JSONResponse({"error": "学号必须严格为12位纯数字！"}, status_code=400)
    if password != confirm_password:
        return JSONResponse({"error": "两次输入的密码不一致！"}, status_code=400)

    new_sess = generate_session_id()
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        try:
            conn.execute("INSERT INTO users (phone, name, password, student_id, is_first_login) VALUES (?, ?, ?, ?, 1)",
                         (phone, name, hash_password(password), student_id))
            conn.execute("DELETE FROM user_sessions WHERE phone = ?", (phone,))
            conn.execute("INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)", (new_sess, phone))
            conn.commit()
        except sqlite3.IntegrityError:
            return JSONResponse({"error": "手机号或学号已被注册过！"}, status_code=400)

    response = JSONResponse({"msg": "注册成功", "redirect": "/"})
    response.set_cookie("session_token", new_sess, max_age=604800)
    return response


@app.post("/do_login")
async def do_login(username: str = Form(...), password: str = Form(...)):
    new_sess = generate_session_id()
    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        user = conn.cursor().execute("SELECT phone FROM users WHERE (phone=? OR student_id=?) AND password=?",
                                     (username, username, hash_password(password))).fetchone()
        if not user:
            return JSONResponse({"error": "账号或密码错误！"}, status_code=401)

        phone = user[0]
        conn.execute("DELETE FROM user_sessions WHERE phone = ?", (phone,))
        conn.execute("INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)", (new_sess, phone))
        conn.commit()

    response = JSONResponse({"msg": "登录成功", "redirect": "/"})
    response.set_cookie("session_token", new_sess, max_age=604800)
    return response


@app.post("/change_password")
async def change_password(request: Request,
                          student_id: str = Form(...),
                          phone: str = Form(...),
                          old_password: str = Form(...),
                          new_password: str = Form(...),
                          confirm_new_password: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return JSONResponse({"error": "登录已过期，请重新登录！"}, status_code=401)

    if new_password != confirm_new_password:
        return JSONResponse({"error": "两次输入的新密码不一致！"}, status_code=400)

    if user['phone'] != phone or user['student_id'] != student_id:
        return JSONResponse({"error": "填写的学号或手机号与当前登录账号不匹配！"}, status_code=400)

    with sqlite3.connect(DB_FILE, timeout=10) as conn:
        curr = conn.cursor().execute("SELECT phone FROM users WHERE phone=? AND password=?",
                                     (phone, hash_password(old_password))).fetchone()
        if not curr:
            return JSONResponse({"error": "旧密码错误！"}, status_code=400)

        conn.execute("UPDATE users SET password=? WHERE phone=?", (hash_password(new_password), phone))
        conn.commit()

    return JSONResponse({"msg": "密码修改成功，下次请使用新密码登录"})


@app.get("/logout")
async def logout(request: Request):
    session_id = request.cookies.get("session_token")
    if session_id:
        with sqlite3.connect(DB_FILE, timeout=10) as conn:
            conn.execute("DELETE FROM user_sessions WHERE session_id = ?", (session_id,))
            conn.commit()

    response = JSONResponse({"msg": "已安全退出"})
    response.delete_cookie("session_token")
    return response


if __name__ == "__main__":
    print("===================================================")
    print("🚀 校园组队系统启动成功！")
    print("🌐 访问地址: http://127.0.0.1:8000")
    print("===================================================")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")
