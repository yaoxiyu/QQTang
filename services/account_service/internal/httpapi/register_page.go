package httpapi

import (
	"html/template"
	"net/http"
)

var registerPageTemplate = template.Must(template.New("register-page").Parse(`<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QQTang Account Register</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f4efe6;
      --panel: #fffaf2;
      --ink: #2d241f;
      --muted: #6a5950;
      --line: #d7c7bb;
      --accent: #bf5a36;
      --accent-strong: #9f4322;
      --ok: #2f7d4c;
      --error: #b53f33;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top, rgba(191,90,54,0.12), transparent 32%),
        linear-gradient(180deg, #f7f1e7 0%, var(--bg) 100%);
      display: grid;
      place-items: center;
      padding: 24px;
    }
    .panel {
      width: min(100%, 420px);
      background: rgba(255,250,242,0.96);
      border: 1px solid var(--line);
      border-radius: 18px;
      box-shadow: 0 24px 60px rgba(56, 33, 20, 0.12);
      padding: 24px;
    }
    h1 { margin: 0 0 8px; font-size: 28px; }
    p { margin: 0 0 16px; color: var(--muted); line-height: 1.5; }
    label {
      display: block;
      margin: 14px 0 6px;
      font-size: 14px;
      font-weight: 600;
    }
    input {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 12px 14px;
      font-size: 15px;
      background: #fff;
      color: var(--ink);
    }
    input:focus {
      outline: 2px solid rgba(191,90,54,0.22);
      border-color: var(--accent);
    }
    button {
      width: 100%;
      margin-top: 18px;
      border: 0;
      border-radius: 12px;
      padding: 12px 14px;
      font-size: 15px;
      font-weight: 700;
      color: #fff;
      background: linear-gradient(180deg, var(--accent) 0%, var(--accent-strong) 100%);
      cursor: pointer;
    }
    button:disabled {
      opacity: 0.65;
      cursor: wait;
    }
    .status {
      min-height: 24px;
      margin-top: 14px;
      font-size: 14px;
      line-height: 1.5;
    }
    .status.ok { color: var(--ok); }
    .status.error { color: var(--error); }
    .tip {
      margin-top: 16px;
      padding-top: 12px;
      border-top: 1px solid var(--line);
      font-size: 13px;
      color: var(--muted);
    }
    code {
      font-family: Consolas, "Courier New", monospace;
      font-size: 12px;
      background: rgba(45,36,31,0.06);
      padding: 2px 6px;
      border-radius: 6px;
    }
  </style>
</head>
<body>
  <main class="panel">
    <h1>注册账号</h1>
    <p>创建完成后，回到客户端登录页，使用相同账号和密码登录。</p>
    <form id="register-form">
      <label for="account">账号</label>
      <input id="account" name="account" type="text" maxlength="64" autocomplete="username" placeholder="例如 player001" required>

      <label for="nickname">昵称</label>
      <input id="nickname" name="nickname" type="text" maxlength="32" autocomplete="nickname" placeholder="显示名" required>

      <label for="password">密码</label>
      <input id="password" name="password" type="password" minlength="8" autocomplete="new-password" placeholder="至少 8 位" required>

      <label for="confirm-password">确认密码</label>
      <input id="confirm-password" name="confirm-password" type="password" minlength="8" autocomplete="new-password" placeholder="再次输入密码" required>

      <button id="submit-button" type="submit">创建账号</button>
      <div id="status" class="status"></div>
    </form>
    <div class="tip">
      当前页面直接调用 <code>/api/v1/auth/register</code>。成功后无需停留在网页，可直接返回客户端。
    </div>
  </main>
  <script>
    const form = document.getElementById('register-form');
    const statusEl = document.getElementById('status');
    const submitButton = document.getElementById('submit-button');

    function setStatus(text, kind) {
      statusEl.textContent = text || '';
      statusEl.className = kind ? 'status ' + kind : 'status';
    }

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      const account = document.getElementById('account').value.trim();
      const nickname = document.getElementById('nickname').value.trim();
      const password = document.getElementById('password').value;
      const confirmPassword = document.getElementById('confirm-password').value;

      if (!account || !nickname || !password) {
        setStatus('账号、昵称和密码都必须填写。', 'error');
        return;
      }
      if (password !== confirmPassword) {
        setStatus('两次输入的密码不一致。', 'error');
        return;
      }

      submitButton.disabled = true;
      setStatus('正在创建账号...', '');

      try {
        const response = await fetch('/api/v1/auth/register', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            account,
            nickname,
            password,
            client_platform: 'web_register'
          })
        });
        const payload = await response.json();
        if (!response.ok || !payload.ok) {
          setStatus(payload.message || payload.error_code || '注册失败', 'error');
          return;
        }
        form.reset();
        setStatus('账号创建成功，请回到客户端登录。', 'ok');
      } catch (error) {
        setStatus('无法连接账号服务，请稍后重试。', 'error');
      } finally {
        submitButton.disabled = false;
      }
    });
  </script>
</body>
</html>`))

func serveRegisterPage(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_ = registerPageTemplate.Execute(w, nil)
}
