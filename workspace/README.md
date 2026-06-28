# MemoryAssistant

一个面向 iPhone 的“记忆助手”MVP，用来记录和检索日常信息，包括：

- 某个东西放在哪里
- 明天或某天的具体工作安排
- 任意备忘内容
- 通过 Siri / Shortcuts 快速提问并得到答案

## 当前实现

- `iOS 原生 SwiftUI` 界面
- `本地优先` 数据存储，使用 JSON 持久化到应用沙盒
- `统一记录模型`，同时覆盖位置记忆、日程安排、通用备忘
- `关键词优先搜索`，支持按标题、详情、地点、标签检索
- `App Intents` 集成，支持 Siri 查询和“明天安排”快捷指令
- `App 内语音录入`，可把中文语音转换成文字并辅助填写记录
- `Siri 新增记录`，支持直接说一句话写入本地记忆库

## 项目结构

- `project.yml`: XcodeGen 配置文件
- `MemoryAssistant/App`: App 入口
- `MemoryAssistant/Models`: 数据模型
- `MemoryAssistant/Services`: 存储与搜索逻辑
- `MemoryAssistant/ViewModels`: 视图模型
- `MemoryAssistant/Views`: SwiftUI 页面
- `MemoryAssistant/Intents`: Siri / App Intents 集成

## 在 Mac 上运行

前提：

- macOS
- Xcode 15+
- 建议安装 `XcodeGen`

生成工程：

```bash
brew install xcodegen
cd /path/to/MemoryAssistant
xcodegen generate
open MemoryAssistant.xcodeproj
```

然后在 Xcode 中：

1. 选择 iPhone 模拟器或真机
2. 运行 App
3. 首次运行后可在系统 `Shortcuts` 中看到该 App 提供的快捷动作
4. 也可以直接对 Siri 说类似的话：

- “用记忆助手找 护照在哪里”
- “在记忆助手中查询 明天安排”
- “打开记忆助手看看明天安排”
- “用记忆助手记录 护照放在书房第二层抽屉”

## Siri 说明

本项目使用 `App Intents`，适合第一版快速接入 Siri / Shortcuts。

当前已提供三个 Intent：

- `FindMemoryIntent`: 根据自然语言查询最相关记录
- `CaptureMemoryIntent`: 根据一句自然语言新增记录
- `TomorrowScheduleIntent`: 汇总明天的日程安排

如果你后续希望做到更自然的“免打开 App 回答”，建议继续增强：

- 搜索排序和语义检索
- 领域词识别，例如“放哪了”“几点开会”“谁负责”
- 更丰富的 App Shortcut 短语
- 需要跨设备时增加云端同步

## 第二版测试

你在 Mac 上生成并运行工程后，就可以立刻开始第一轮测试。

建议用 `真机` 测试语音与 Siri，原因是：

- `App 内语音录入` 需要麦克风和语音识别权限
- `Siri / Shortcuts` 在真机上的体验更完整

第一轮建议测试这些场景：

1. 手动新增：
   - 新建一条位置记录，例如“护照”
   - 新建一条日程记录，例如“明天下午 3 点开会”
2. App 内语音录入：
   - 打开新建记录页
   - 点击“开始录音”
   - 说“帮我记一下护照放在书房第二层抽屉”
   - 点击“应用识别结果”，确认标题、位置、说明是否自动填入
3. Siri 新增：
   - 对 Siri 说“用记忆助手记录 钥匙放在玄关柜左边”
4. Siri 查询：
   - 对 Siri 说“用记忆助手找 钥匙在哪里”
5. 明天安排：
   - 先录入一条明天的日程
   - 再对 Siri 说“查看记忆助手的明天安排”

## 第二版限制

- 语音理解目前是 `规则解析`，适合位置、时间、简单备忘，不是完整自然语言智能体
- 时间识别目前优先支持“今天 / 明天 + 数字时间”，例如“明天下午 3 点”
- 更复杂表达如“下周三”“月底前”“后天上午”还需要继续扩展

## 安卓扩展建议

虽然第一版采用 iOS 原生实现，但结构上已经把核心能力拆成了：

- 记录模型
- 搜索规则
- 持久化接口

未来支持安卓时，建议：

1. 抽离为后端 API 或共享数据协议
2. 安卓端用 Kotlin + Jetpack Compose
3. 接入 Android Assistant / App Actions
4. 若需要多端同步，再引入云端账号体系

## 当前限制

- 这里生成的是可直接继续开发的源码，不在当前 Linux 沙箱内编译 iOS App
- 搜索目前以关键词和简单规则为主，还不是向量语义检索
- 多设备同步、账号体系、拍照录入、语音转文字暂未加入第一版
