@echo off
chcp 65001 >nul
where python >nul 2>nul
if %errorlevel%==0 (
    python "%~dp0install.py" %*
) else (
    echo [错误] 未找到 Python，请安装 Python 3.8+ 并加入 PATH
    pause
)
