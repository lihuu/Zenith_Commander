# Zenith Commander Swift 设计规范

> 目标：保持代码可维护、可测试、并发安全；让插件化/能力扩展更简单；避免不必要的生命周期与 ARC 复杂度（尤其是测试环境下的时序/释放相关问题）。

## 1. 总体设计原则

### 1.1 Struct First

- **默认使用 `struct`**。
- 只有在语义上必须时才使用 `class`（见 §2）。
- 通过 **Protocol + 组合** 完成抽象与多态，避免以继承作为复用手段。

### 1.2 Protocol for Abstraction, Composition for Reuse

- 抽象：使用 `protocol` 定义能力边界（Capability / Service / Runner）。
- 复用：使用组合（把依赖作为属性注入），优先用 `extension` 提供默认实现。
- 避免“BaseClass + override”式的层级结构。

### 1.3 Side-effect Free Construction

- `init` / `makeCapabilities()` **只做组装，不启动副作用**：
  - 不启动 Task
  - 不注册观察者
  - 不创建 DispatchSource/Timer
  - 不触发 IO 探测
- 副作用必须显式：`start()` / `activate()` / `attach()` 由 `PluginManager`/上层生命周期统一管理。

---

## 2. 什么时候用 class

### 2.1 必须使用 class 的场景（允许）

- **需要身份（Identity）**：多处共享同一实例，要求“这就是同一个对象”。
- **需要生命周期（Lifecycle）**：必须在 `deinit` 中释放资源（监听器、句柄、XPC、观察者、文件监控等）。
- **需要引用语义的共享可变状态**：例如 `ObservableObject` / ViewModel / AppState。
- **需要与 Objective-C / Cocoa 强交互**：`@objc`、KVO、某些 AppKit API 约束等。

### 2.2 class 的强制约束（必须遵守）

- 除非确有必要，`class` 一律标记为 `final`。
- class 作为“服务/工具”时，必须回答：
  - 为什么需要 identity？
  - 为什么需要 deinit？
  - 为什么不能是 struct？
- class 持有异步任务/资源时，必须提供显式的 `stop()` / `invalidate()`，并保证幂等。

---

## 3. 什么时候用 struct

### 3.1 推荐使用 struct 的场景（默认）

- Capability / Plugin / Provider / Command 描述对象
- 无状态或轻状态的服务（只提供行为）
- 纯计算/解析/格式化（Formatter/Parser）
- 数据模型（value semantics）

### 3.2 struct 的注意事项

- 避免在 struct 中隐藏共享可变状态（例如通过全局单例/静态变量变相共享）。
- 大体积数据结构注意拷贝成本；必要时引入 Copy-on-Write 或把大对象放入引用类型容器。

---

## 4. 并发与线程安全

### 4.1 默认目标：可在并发环境下安全

- 能标注 `Sendable` 的类型尽量标注（尤其是跨 Task 传递的数据）。
- 共享可变状态：
  - 优先用 `actor` 管理
  - 或使用单线程隔离（MainActor / 专用队列）
- 避免在异步闭包中捕获临时指针/短生命周期对象。

### 4.2 Continuation 使用规范（硬规则）

- `withChecked(Throwing)Continuation`：
  - **必须保证 exactly once resume**（一次且仅一次）
  - 任意 early-return 都必须最终 resume（成功或失败）
- 任何回调桥接 async 都要有“resumeOnce gate”（锁或原子标志）。

---

## 5. 工具执行与外部进程（ToolRunner 规范）

### 5.1 ToolRunner 的类型选择

- `ToolRunner` 的实现如果无状态：**用 struct**。
- 只有当需要持有长期资源（例如进程池、复用管道、缓存、观察者）才允许用 class。

### 5.2 外部命令执行（Process）

- 尽量避免依赖 `PATH`，优先使用绝对路径（必要时做候选路径探测）。
- stdout/stderr 读取必须确保不会死锁：
  - 输出量可能很大时，避免在 termination 后一次性 read（必要时异步读）。
- `terminationHandler`：
  - 使用后清理：`proc.terminationHandler = nil`
  - 避免循环引用与重复触发。
- 解析输出应与实例生命周期解耦（例如 static parser）。

---

## 6. 插件系统（Capability & Plugin）

### 6.1 能力边界

- Plugin 只负责组装 capabilities，不执行副作用。
- Capability 只暴露最小 API；内部实现细节不外泄。
- 所有依赖通过 `context` 或构造参数注入，禁止 Capability 内部“全局查找依赖”。

### 6.2 UI 与 Service 分离

- UI Contribution 与 Service/Provider 分离：
  - UI 只负责展示与事件派发
  - Service 只负责业务与数据
- 任何 UI 相关能力必须显式标注 MainActor/线程约束。

---

## 7. 测试规范

### 7.1 单测必须可重复、可控

- 单测中优先使用 Mock ToolRunner / Mock Context，避免真实系统调用与不确定 IO。
- 禁止在 `init` 阶段启动后台任务导致“测试结束释放时随机崩溃”。
- 对并发桥接点（continuation）必须有专项测试：
  - 不会 double-resume
  - 不会漏-resume
  - cancellation 行为符合预期

### 7.2 避免 Heisenbug 的建议

- 遇到“加 print / 加空 deinit 就不崩”的情况：
  - 这是时序/布局改变导致的症状，不是修复
  - 需要回到并发/内存模型检查（continuation、回调、资源释放顺序）。

---

## 8. 代码风格与工程约定（建议）

- public API 注释齐全（尤其是 Plugin 与 Capability）。
- 文件命名：
  - `GitPlugin.swift`, `GitCommandProvider.swift`, `ToolRunner.swift` 等按职责命名。
- `extension` 分文件：
  - 一个 type 多个职责时，按能力拆分 `Type+Feature.swift`。

---

## 9. 决策清单（写代码前先问自己）

使用 struct 还是 class：

1. 我需要“身份”吗（同一实例在多处共享）？
2. 我需要 `deinit` 做清理吗？
3. 我需要 `ObservableObject`/ObjC 交互吗？
4. 我有共享可变状态且必须引用语义吗？
5. 我害怕被复制带来语义问题/性能问题吗？

- 全部 No：用 **struct**
- 任意 Yes：考虑 **class**（并尽量 `final`）
