# 记忆助手 MemoryAssistant

> 一个面向 iPhone 的本地优先"记忆助手"，帮你记录和快速检索生活中的点滴——东西放在哪、日程安排、备忘笔记，都能一句话查到。

![Platform](https://img.shields.io/badge/platform-iOS-orange)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## ✨ 主要功能

- 🧠 **AI 智能问答** — 用自然语言提问，AI 帮你从记忆库中找到答案（支持 DeepSeek / 通义千问模型）
- 📍 **位置记忆** — 记录物品存放位置，再也不用到处找东西
- 📅 **日程提醒** — 快速记录会议、约会、待办事项
- 📝 **通用备忘** — 灵感、想法、账号信息随手记
- 🎙️ **语音输入** — 长按说话就能记录，支持中文语音识别
- 🗣️ **Siri 集成** — 不用打开 App，直接对 Siri 说"钥匙放哪了"
- 🎨 **多主题切换** — 暖色 / 经典 / 玻璃 / 跟随系统，四种外观任你选
- 🔒 **本地优先** — 所有数据保存在本地沙盒，隐私安全

## 📱 界面预览

### 核心功能

| 首页智能问答 | 全部记录列表 |
|:---:|:---:|
| ![首页](screenshots/01-home.png) | ![全部记录](screenshots/04-records.png) |
| AI 自然语言提问，快速找到答案 | 分类浏览所有记忆记录 |

| 记录详情 | 新增记录 |
|:---:|:---:|
| ![记录详情](screenshots/05-record-detail.png) | ![新增记录](screenshots/06-record-form.png) |
| 查看和编辑完整记录信息 | 支持位置 / 日程 / 备忘三种类型 |

| 快速语音录入 | 设置中心 |
|:---:|:---:|
| ![快速记录](screenshots/07-quick-capture.png) | ![设置](screenshots/02-settings.png) |
| 长按说话，自动识别并分类 | 主题切换、数据管理、AI 配置 |

### AI 与会员

| AI 用量管理控制台 | Pro 会员升级 |
|:---:|:---:|
| ![管理控制台](screenshots/03-admin.png) | ![升级页](screenshots/08-upgrade.png) |
| 调用统计、请求日志、数据导出 | 解锁更多 AI 调用次数和高级功能 |

### 多主题支持

| 玻璃主题（暗色） | 经典主题（系统） |
|:---:|:---:|
| ![玻璃主题](screenshots/09-theme-glass.png) | ![经典主题](screenshots/10-theme-classic.png) |
| 深邃玻璃质感，沉浸式体验 | 清爽系统风格，简洁高效 |

> 还有暖色主题可选，在设置中随时切换，也支持跟随系统。

## 🏗️ 技术栈

- **语言**: Swift 5.9
- **框架**: SwiftUI + UIKit 混合
- **数据存储**: JSON 文件持久化（应用沙盒）
- **AI 能力**: 远程 LLM API（DeepSeek / 通义千问）
- **语音**: Speech 框架 + 本地规则解析
- **Siri**: App Intents 框架
- **内购**: StoreKit 2
- **构建工具**: XcodeGen

## 📁 项目结构

```
MemoryAssistant/
├── App/                    # App 入口与全局依赖
├── Models/                 # 数据模型（记录、主题、AI 服务等）
├── Services/               # 核心服务
│   ├── MemoryStore.swift   # 数据存储与搜索
│   ├── LLMService.swift    # AI 大模型服务
│   ├── LLMUsageTracker.swift  # AI 用量追踪
│   ├── LLMRequestLogger.swift # AI 请求日志
│   └── MemoryProStore.swift   # 会员与内购
├── ViewModels/             # 视图模型
├── Views/                  # SwiftUI 页面
│   ├── MemoryListView.swift   # 主页面
│   ├── SettingsView.swift     # 设置页
│   ├── AllRecordsView.swift   # 全部记录
│   ├── AdminConsoleView.swift # AI 管理控制台
│   └── Components/            # 通用组件
└── Intents/                # Siri / App Intents 集成
```

## 🚀 在 Mac 上运行

### 环境要求

- macOS 14+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（推荐）

### 生成工程

```bash
brew install xcodegen
cd MemoryAssistant/workspace
xcodegen generate
open MemoryAssistant.xcodeproj
```

然后在 Xcode 中：

1. 选择 iPhone 模拟器或真机
2. 按 `⌘R` 运行 App

### AI 功能配置（可选）

App 内置了 AI 问答能力，需要配置 API Key 才能使用：

1. 在 `MemoryAssistant/Services/LLMSecrets.swift` 中填入你的 API Key
2. 或在 App 内通过管理控制台配置

## 🤖 AI 用量管理

内置了完整的 AI 调用管理系统：

- **用量追踪** — 每日调用次数、Token 消耗、成功率统计
- **配额管理** — 免费版每日限制，Pro 版更高额度
- **请求日志** — 记录每次调用的模型、耗时、状态
- **数据导出** — 支持导出 JSON / CSV 格式
- **管理控制台** — 在设置页点击"AI 用量"进入

## 🧪 测试场景建议

### 基础功能
1. **手动新增记录** — 新建位置/日程/备忘各一条
2. **搜索记录** — 用关键词搜索，验证结果排序
3. **编辑与删除** — 修改记录内容、删除记录

### 语音与 Siri
1. **App 内语音录入** — 点击录音按钮，说"帮我记一下护照放在书房第二层抽屉"
2. **Siri 新增** — 对 Siri 说"用记忆助手记录 钥匙放在玄关柜左边"
3. **Siri 查询** — 对 Siri 说"用记忆助手找 钥匙在哪里"
4. **明天安排** — 录入明天日程后，对 Siri 说"查看记忆助手的明天安排"

### AI 功能
1. **自然语言提问** — 问"我钥匙放哪了"
2. **多轮对话** — 连续追问相关问题
3. **用量统计** — 在管理控制台查看调用记录

## 🔮 后续规划

- ☁️ iCloud 同步 — 多设备数据同步
- 🔍 向量检索 — 更精准的语义搜索
- 📸 拍照录入 — 拍照自动识别并记录
- 🌙 更多主题 — 持续优化视觉体验
- 📊 云端管理后台 — 面向运营者的用户与配额管理

## 📄 License

MIT
