import sqlite3
import hashlib
import uuid
from fastapi import FastAPI, Form, Request, Response
from fastapi.responses import RedirectResponse, HTMLResponse

app = FastAPI()

@app.on_event("startup")
def startup():
    init_auth_db()

def get_current_user(request: Request):
    session_id = request.cookies.get("session_token")
    if not session_id:
        return None
    with sqlite3.connect(DB_FILE) as conn:
        conn.row_factory = sqlite3.Row
        user = conn.execute(
            "SELECT u.* FROM users u JOIN user_sessions s ON u.phone = s.phone WHERE s.session_id = ?",
            (session_id,)
        ).fetchone()
    return user

# ---------- 登录页面 ----------
@app.get("/login", response_class=HTMLResponse)
async def login_page():
    return """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8"><title>登录/注册</title></head>
    <body>
        <h2>登录</h2>
        <form action="/do_login" method="post">
            <input type="text" name="username" placeholder="手机号/学号" required><br>
            <input type="password" name="password" placeholder="密码" required><br>
            <button type="submit">登录</button>
        </form>
        <hr>
        <h2>注册</h2>
        <form action="/do_register" method="post">
            <input type="text" name="student_id" placeholder="12位学号" required><br>
            <input type="text" name="name" placeholder="姓名" required><br>
            <input type="tel" name="phone" placeholder="手机号" required><br>
            <input type="password" name="password" placeholder="密码" required><br>
            <input type="password" name="confirm_password" placeholder="确认密码" required><br>
            <button type="submit">注册</button>
        </form>
    </body>
    </html>
    """

# ---------- 注册处理 ----------
@app.post("/do_register")
async def do_register(
    student_id: str = Form(...),
    name: str = Form(...),
    phone: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...)
):
    if not student_id.isdigit() or len(student_id) != 12:
        return HTMLResponse("<script>alert('学号必须为12位数字');history.back();</script>")
    if password != confirm_password:
        return HTMLResponse("<script>alert('两次密码不一致');history.back();</script>")
    
    new_sess = generate_session_id()
    with sqlite3.connect(DB_FILE) as conn:
        try:
            conn.execute(
                "INSERT INTO users (phone, name, password, student_id) VALUES (?, ?, ?, ?)",
                (phone, name, hash_password(password), student_id)
            )
            conn.execute("DELETE FROM user_sessions WHERE phone = ?", (phone,))
            conn.execute("INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)", (new_sess, phone))
            conn.commit()
        except sqlite3.IntegrityError:
            return HTMLResponse("<script>alert('手机号或学号已被注册');history.back();</script>")
    
    resp = RedirectResponse(url="/", status_code=303)
    resp.set_cookie("session_token", new_sess, max_age=604800)
    return resp

# ---------- 登录处理 ----------
@app.post("/do_login")
async def do_login(username: str = Form(...), password: str = Form(...)):
    new_sess = generate_session_id()
    with sqlite3.connect(DB_FILE) as conn:
        user = conn.execute(
            "SELECT phone FROM users WHERE (phone=? OR student_id=?) AND password=?",
            (username, username, hash_password(password))
        ).fetchone()
        if not user:
            return HTMLResponse("<script>alert('账号或密码错误');history.back();</script>")
        phone = user[0]
        conn.execute("DELETE FROM user_sessions WHERE phone = ?", (phone,))
        conn.execute("INSERT INTO user_sessions (session_id, phone) VALUES (?, ?)", (new_sess, phone))
        conn.commit()
    
    resp = RedirectResponse(url="/", status_code=303)
    resp.set_cookie("session_token", new_sess, max_age=604800)
    return resp

# ---------- 登出 ----------
@app.get("/logout")
async def logout(request: Request):
    session_id = request.cookies.get("session_token")
    if session_id:
        with sqlite3.connect(DB_FILE) as conn:
            conn.execute("DELETE FROM user_sessions WHERE session_id = ?", (session_id,))
            conn.commit()
    resp = RedirectResponse(url="/login", status_code=303)
    resp.delete_cookie("session_token")
    return resp

# ---------- 会话检查（可选） ----------
@app.get("/api/check_session")
async def check_session(request: Request):
    session_id = request.cookies.get("session_token")
    if not session_id:
        return {"status": "logged_out"}
    with sqlite3.connect(DB_FILE) as conn:
        exists = conn.execute("SELECT phone FROM user_sessions WHERE session_id = ?", (session_id,)).fetchone()
    return {"status": "valid"} if exists else {"status": "logged_out"}

# ---------- 修改密码（可选） ----------
@app.post("/change_password")
async def change_password(
    request: Request,
    student_id: str = Form(...),
    phone: str = Form(...),
    old_password: str = Form(...),
    new_password: str = Form(...),
    confirm_new_password: str = Form(...)
):
    user = get_current_user(request)
    if not user:
        return {"msg": "未登录"}
    if new_password != confirm_new_password:
        return {"msg": "新密码两次输入不一致"}
    if user['phone'] != phone or user['student_id'] != student_id:
        return {"msg": "验证信息不匹配"}
    with sqlite3.connect(DB_FILE) as conn:
        cur = conn.execute(
            "SELECT phone FROM users WHERE phone=? AND password=?",
            (phone, hash_password(old_password))
        ).fetchone()
        if not cur:
            return {"msg": "旧密码错误"}
        conn.execute("UPDATE users SET password=? WHERE phone=?", (hash_password(new_password), phone))
        conn.commit()
    return {"msg": "密码修改成功"}

# ---------- 简单首页（需要登录） ----------
@app.get("/")
async def home(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=303)
    return HTMLResponse(f"<h1>欢迎 {user['name']}</h1><a href='/logout'>登出</a>")
