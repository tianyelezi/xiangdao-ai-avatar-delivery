# 向导AI / 啊对对队自动化数字人系统

这是面向客户交付的 DUIX Avatar 本地部署包。客户端 UI 已定制为「向导AI / 啊对对队自动化数字人系统」，并保留 DUIX 授权要求中的 `Built with DUIX.COM` 声明。

## 客户使用方式

客户下载 Release 里的 `向导AI-在线一键部署器.exe`，右键以管理员身份运行。部署器会自动完成：

- 下载并安装向导AI客户端。
- 检查或安装 Docker Desktop。
- 拉取数字人后端 Docker 镜像。
- 写入本地后端配置和 TTS 启动补丁。
- 创建桌面入口 `启动 向导AI` 和 `停止 向导AI`。
- 启动后端服务并打开客户端。

默认数据目录：

- 如果存在 D 盘：`D:\duix_avatar_data`
- 如果没有 D 盘：`C:\duix_avatar_data`

## Release 资产

发布 Release 时需要上传：

- `XiangdaoAI-client-portable.zip`
- `向导AI-在线一键部署器.exe`

## 构建在线部署器

在 `installer` 目录运行：

```powershell
.\build-online-installer.ps1 -RepoOwner <你的GitHub用户名或组织名> -RepoName xiangdao-ai-avatar-delivery
```

生成文件在 `dist\向导AI-在线一键部署器.exe`。

## 授权注意

本项目基于 DUIX.COM 技术构建。分发时必须随包保留 `LICENSE-DUIX` 和 `NOTICE.txt`，并在界面或文档中保留 `Built with DUIX.COM`。
