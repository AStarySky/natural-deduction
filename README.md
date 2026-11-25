# Natural Deduction

一个用**拖拽卡片拼证明树**来学习自然演绎（Natural Deduction）的二维矢量解谜游戏。

- 源码仓库：<https://github.com/AStarySky/natural-deduction>

- 引擎：Godot **4.7**（GDScript，`gl_compatibility` 渲染器）
- 主场景：`res://ui/main.tscn`
- 目标平台：桌面（Windows / macOS / Linux）
- 逻辑核心与 UI 完全解耦，同一套规则语义同时驱动游戏与无头 CLI


---

## 玩法

每一关给出若干**前提**和一个**目标公式**。从底部规则架拖出规则卡，把前提或已推导出的结论插入规则卡的输入槽，直到拼出一棵根节点等于目标的合法证明树。

把最终证明块拖到右上角的 **GOAL** 芯片（或点击芯片检查最近一个规则块）：

- `WAITING`：尚未提交
- `INCOMPLETE`：证明块缺少输入
- `MISMATCH`：结论与目标公式不同
- `INVALID`：结论正确，但证明树内部有规则或作用域错误
- `VALID`：整棵树通过结构化验证，解锁 **NEXT**

关卡按 **7 个章节顺序解锁**：完成当前核心关后解锁下一关，完成一章的 6 个核心关后解锁下一章。前 6 章各有 3 个、第 7 章有 1 个可选挑战关；挑战完成度会被记录，但不影响章节解锁。进度保存在 `user://progress.cfg`，退出后仍保留。

### 操作

| 操作 | 方式 |
|---|---|
| 取用规则 / 前提 | 从底部规则架或左侧 Premises 面板按住拖出 |
| 插入输入槽 | 拖到槽附近自动吸附（36 px 接近范围，弹簧落入） |
| 拖出已插入的块 | 直接拖走；原槽清空 |
| 复制整棵子树 | `Ctrl` + 拖拽源块，或点击规则卡右上角复制按钮 |
| 删除块 | 拖到右下角 **TRASH**（判定范围比卡片大 32 px） |
| 撤销上一步 | 点击顶部 **UNDO**，或按 `Ctrl+Z`；恢复最近的移动、吸附、删除、复制、侧切换或目标提交 |
| 取消拖动 | `Esc`：已有块回到原位，从面板新拖出的块被丢弃 |
| 提交目标 | 把证明块拖到 **GOAL** 芯片（判定向外扩展 6 px），或点击芯片 |
| 缩放画布 | 鼠标滚轮（0.3× – 3.0×） |
| 平移画布 | 中键 / 右键拖拽，或在空白画布上左键拖拽 |
| 输入公式 | Formula Builder 中直接键盘输入（无输入框），预览区实时显示识别后的公式；`Enter` 提交，`Esc` 取消 |
| 快速规则 | 数字键 `1–9`：生成当前规则架对应编号的规则卡 |
| 快速假设 | `A`：打开 ASSUME（仅第二章及以后） |
| 编辑假设 | 最大化 Assume 窗口后点 `EDIT`；同组的所有假设副本同步改成新公式 |
| L/R 开关 | 点击一次切换，不需要点对应半边 |
| 检查目标 | `Enter`：检查当前画布上最后一个根规则块 |
| 静音 | `M`（同时静音 BGM 与音效） |
| 全屏 | 桌面版默认全屏启动；`F11` 切换全屏/窗口；标题页 Settings 里也有开关 |
| 卡片尺寸 | 标题页 Settings 可在 Compact 与 Comfort 公式卡之间切换；默认 Compact |
| 音量 | 点击右上角喇叭静音；右键打开总音量滑条（BGM + SFX） |
| 标题页菜单 | **CREDITS** 查看素材授权；**SETTINGS** 分别调整 Music / SFX、静音和全屏 |

快捷键只在关卡界面生效；打开 Formula Builder 或章节规则介绍、正在拖拽/吸附/平移时会自动禁用；除 `Ctrl+Z` 撤销外，带 Shift/Ctrl/Alt/Cmd 的组合键不会触发数字/Enter 等快捷键。Enter 在作用域浮窗打开时不会检查外层目标。验证音效只在规则真正完成、或拆开输入后重新拼回时播放；拿起/放下整块和 Undo 不会重播。

### 假设与蕴含引入

游戏中的 `→ 引入` 通过**假设浮窗**完成：

1. 点击左侧 **ASSUME**，用公式构建器输入假设 `A`（可直接键盘输入，`Enter` 提交，`Esc` 取消）；
2. 会打开一个带独立无限画布的浮窗，假设同时出现在 Premises 面板；
3. 在浮窗里用任意规则推导出结论 `B`；
4. 点击黄色圆点最小化：生成标记卡 `A → B`，可继续拖入其他规则；
5. 红色圆点关闭/丢弃；绿色圆点放大到全屏或还原。浮窗可以嵌套，子浮窗被父窗口裁剪。
6. 全屏作用域只在左上角保留紧凑的窗口控制条；游戏标题、关卡名和中央 HUD 会隐藏，避免遮挡画布。
7. 浮窗打开时，仍可在窗口外的背景上平移/缩放桌面画布；顶层浮窗会跟着背景一起移动和缩放。浮窗内仍可用自己的滚轮/中键操作其内层画布。
8. 依赖当前 Assume 假设的块不能拖出该作用域，也不能提交到 GOAL；只有不依赖该假设的结论才能离开。这样不会把未解除的假设“空手套白狼”，被拦下时会显示 **“Want to cheat huh, no way.”**。
9. Assume 窗口仍打开时按 `Enter` 或点击 GOAL，不会偷偷检查内部画布，而是弹出 **FINISH THE ASSUMPTION** 提示：先用黄色圆点最小化/完成当前窗口，再检查外层目标。

### 规则集

全量规则架共有 9 张卡（`logic/rules.gd` 中的 `PALETTE_ORDER`），但会随章节逐步解锁：
第一章只有 →E / ∧E / ∧I / ~~E 四张；第二章加入 ASSUME；第三章加入 ∨I / ∨E；第四章加入 ↔E / ↔I；第五章加入 ¬I；第六章全部开放；第七章没有新规则，作为纯综合终章。规则卡右上角的数字对应键盘快捷键 `1–9`；`A` 在 ASSUME 已解锁时打开假设构建器。Double negation 卡只提供消去方向；`A ⊢ ~~A` 需要通过矛盾/反证组合出来，不再提供 E/I 侧切换。

| 卡 | 语义 |
|---|---|
| Implication elimination | `A, A → B ⊢ B`（输入顺序任意） |
| Conjunction elimination (L/R) | `A & B ⊢ A` 或 `⊢ B`，卡上 L/R 切换 |
| Conjunction introduction | `A, B ⊢ A & B` |
| Disjunction introduction (L/R) | 证明一侧，并在 “other” 槽填入另一侧，`⊢ A \| B` |
| Disjunction elimination（蕴含编码） | `A \| B, A → C, B → C ⊢ C` |
| Biconditional introduction（蕴含编码） | `A → B, B → A ⊢ A ↔ B` |
| Biconditional elimination | `A, A ↔ B ⊢ B`（顺序任意） |
| Negation introduction（蕴含编码） | `A → B, A → ~B ⊢ ~A` |
| Double negation elimination | `~~A ⊢ A`；`A ⊢ ~~A` 用反证/矛盾推出，不提供直接的 ~~I 卡 |

逻辑核心还实现了完整的**作用域规则**，供 CLI 与验证器使用：

- `impl_intro`：`[A] ... B ⊢ A → B`
- `or_elim`：`A \| B, [A] ... C, [B] ... C ⊢ C`
- `iff_intro`：`[A] ... B, [B] ... A ⊢ A ↔ B`
- `not_intro`：`[A] ... B, ~B ⊢ ~A`
- `not_elim`（经典）：`[~A] ... B, ~B ⊢ A`

以及 CLI 保留的捷径规则 `ds`（析取三段论）、`lem`（排中律）。

证明以 **id 引用的 DAG** 组织：同一前提可以被多个规则反复使用；重复节点在文本树中显示 `(see above)`。

---

## 运行

### 游戏

用 Godot 4.7 打开 `project.godot`，按 **F5**；或：

```bash
godot --path "D:/Godot/Natural Deduction"
```

Windows 下建议使用 `Godot_v4.7.2-stable_win64_console.exe` 以便看到 stdout。

桌面版默认以全屏启动（`window/size/mode=3`），逻辑分辨率仍是 1280×720；`F11` 切回 1280×720 窗口。Web 版可通过页面按钮或浏览器全屏。

### CLI（无头）

```bash
# 交互式 REPL
godot --headless --path . -s res://cli/main.gd

# 执行命令文件
godot --headless --path . -s res://cli/main.gd -- --file res://tests/mur_cli_script.txt
```

CLI 命令：

```
premise <formula>               添加前提（p1, p2, ...）
assume <formula>                添加未解除假设（a1, a2, ...）
goal <formula>                  设置目标公式
apply <rule> <args...>          应用规则（n1, n2, ...）
tree                            文本渲染当前证明树
validate                        验证最后生成的规则节点是否等于 goal
help                            命令说明
quit                            退出
```

公式语法：`~ & | -> <->`（也接受 `→` / `↔`）与括号；优先级 `~ > & > | > -> > <->`；
`->` 和 `<->` 右结合；原子名可多字符。

作用域规则的参数顺序：

```
apply impl_intro <assumption> <proof>
apply or_elim    <disj> <assumption> <proof> <assumption> <proof>
apply iff_intro  <assumption> <proof> <assumption> <proof>
apply not_intro  <assumption> <proof> <proof>
apply not_elim   <assumption> <proof> <proof>
```

`validate` 默认要求根节点的自由假设集合为空（所有假设均已解除）。

---

## 测试

全部为 `SceneTree` 无头入口：

```bash
GODOT=godot   # 或 D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless

$GODOT --headless --path . -s res://tests/run_cli_script.gd     # CLI 验收脚本 A–G
$GODOT --headless --path . -s res://tests/run_scoped_cli.gd     # 作用域规则 CLI
$GODOT --headless --path . -s res://tests/run_invalid_proofs.gd # 错误/不可靠证明的拒绝集
$GODOT --headless --path . -s res://tests/run_book_examples.gd  # 教材改编证明
$GODOT --headless --path . -s res://tests/run_stability.gd      # 解析/作用域/长链稳定性
$GODOT --headless --path . -s res://tests/run_curriculum.gd     # 61 关解法与规则白名单
$GODOT --headless --path . -s res://tests/run_progress.gd       # 顺序解锁与进度持久化
$GODOT --headless --path . -s res://tests/run_ui_model.gd       # UI 模型与场景 drop
$GODOT --headless --path . -s res://tests/run_ui_contracts.gd   # 61 关加载与 UI 工厂契约
$GODOT --headless --path . -s res://tests/run_ui_layout.gd      # Compact/Comfort 公式卡尺寸
$GODOT --headless --path . -s res://tests/run_scope_limits.gd   # 五层 Assume 深度/关闭/Undo
$GODOT --headless --path . -s res://tests/run_ui_scoped.gd      # 假设浮窗与作用域卡
$GODOT --headless --path . -s res://tests/run_chapter_ui.gd     # 章节页/规则架/ASSUME 解锁
$GODOT --headless --path . -s res://tests/run_shortcuts.gd      # 数字规则/A 快捷键与触发边界
$GODOT --headless --path . -s res://tests/run_formula_builder.gd # 构建器输入与校验
$GODOT --headless --path . -s res://tests/run_audio_smoke.gd    # 音效表与 headless 行为
$GODOT --headless --path . -s res://tests/run_title_idle.gd     # 标题页/弹窗与动效开关
```

在当前版本（Godot 4.7.2）上的结果：

| 套件 | 断言数 | 失败 |
|---|---:|---:|
| `run_cli_script`（7 个脚本） | 44 | 0 |
| `run_scoped_cli` | 25 | 0 |
| `run_invalid_proofs` | 50 | 0 |
| `run_book_examples`（17 题） | 17 | 0 |
| `run_stability` | 1177 | 0 |
| `run_curriculum` | 1263 | 0 |
| `run_progress` | 40 | 0 |
| `run_ui_model` | 103 | 0 |
| `run_ui_contracts` | 966 | 0 |
| `run_ui_layout` | 49 | 0 |
| `run_scope_limits` | 23 | 0 |
| `run_ui_scoped` | 216 | 0 |
| `run_chapter_ui` | 43 | 0 |
| `run_shortcuts` | 35 | 0 |
| `run_formula_builder` | 22 | 0 |
| `run_audio_smoke` | 943 | 0 |
| `run_title_idle` | 47 | 0 |

在编辑器内运行 CLI 验收：打开 `tests/run_cli_script_editor.gd`，使用 **File > Run**；它会以子进程方式调用上面的无头 runner。

---

## 架构

```text
输入/拖拽 (ui/main.gd)
   │
   ├─ UI 块图：BlockSocket / FormulaBlock / RuleBlock / ScopedRuleBlock
   │      每张卡显式 refresh() 自底向上重算 OUT 公式与 EMPTY/PENDING/ERROR/VALID
   │
   ├─ 假设浮窗：ScopeWindow（独立 CanvasView）+ ScopeMarkerBlock（A → B）
   │
   └─ ProofAdapter：把块图翻译成 ProofTree
             │
             ▼
        logic/：Formula AST · Parser · Rules · ScopedRules · ProofTree.validate
             ▲
             │
        CLI：CliSession 命令 → 同一套 ProofTree
```

设计要点：

- **逻辑层无场景树依赖**：全部 `RefCounted`，不使用 `class_name`（避免 headless 启动依赖编辑器的全局类缓存），彼此通过 `preload` 别名引用。
- **验证不是只比根公式**：对每个可达节点重新执行规则推导，比对记录公式与 context，检测未知 id、环路、错误解除和跨作用域使用。
- **作用域 = 假设节点 + context 集合**：普通规则对输入 context 求并；作用域规则显式解除绑定假设并检查分支隔离。
- **UI 显式刷新**：没有长驻结果信号；结构变化统一调用 `main.refresh_machine()`。
- **自定义拖拽**：真实块被提升到全屏 `drag_layer` 跟随鼠标；落点选择「最近空槽 + 面积最小」，用欠阻尼弹簧完成吸附。
- **音频池**：12 路复用播放器，cue 具备冷却、分组限流、优先级抢占。音色分为三类：**UI 按钮**使用真实的 `button_click` / `button_hover` 点击声，**纸张卡片**使用 `card_hover`、`card_lift`、`card_place` 等纸张录音，**物理键盘**使用 `typing_key` 单键录音。纸张交互使用 3–6 个真实录音变体，同一 cue 与同一交互组内都不会连续重播同一素材，并叠加随机音高/音量偏移。变体还会按**动作长度窗口**筛选（hover < 0.15 s、lift/place 约 0.2–0.3 s、open > 0.3 s、delete > 0.38 s），避免翻页声被替换成短点击。音量/静音持久化到 `user://audio_settings.cfg`，headless 下不创建运行时。
- **BGM**：80 秒无缝循环的原创 8-bit 曲目（120 BPM、C 大调、40 小节），和声使用 maj7 / m7 / 9 / sus / 13 等扩展和弦。结构为五段式层进：稀疏主旋律 → 对位副旋律从 intro 后半进入 → 半速 breakdown + 军鼓 build → **8 小节副旋律华彩（主旋律完全让位，用十六分音符跑动、长音和上行 build）** → 低八度叠层的高潮；主旋律使用长音、留白和动机变化，而非连续八分音符。主副旋律共用「上行三音 + 下行回应」的动机：副旋律进入时先以移调/倒影陈述该动机，华彩每小节也先陈述动机、再用十六分音符加花，而不是单纯跑音阶。段落交界使用挂留音、弱起 pickup、军鼓 build/fill 和 crash 连接，避免突然切段。副旋律是一条独立写作的对位线，有自己的节奏、轮廓和进入点，而不是和弦长音垫底，因此主旋律不再是唯一的旋律声部。所有旋律与和弦声部都使用 ADSR（attack / decay / sustain / release）包络：主旋律采用较窄的 12.5% 脉冲并降低音量，副旋律在主段/高潮使用较宽的 25% 脉冲、intro 与 breakdown 使用三角波；华彩段副旋律使用偏中置的 25% 脉冲和轻微 vibrato。立体声混音把琶音放左、副旋律放右，低频与鼓保持居中，让各层更容易分辨。音色上叠加并行 48 级量化、低采样保持、持续底噪和稀疏爆点。独立 `Music` 总线，跟随统一的静音/音量设置，启动时淡入。

### 易踩坑 / 实现笔记

这些细节看起来不起眼，但改拖拽、作用域或 Undo 时非常容易回归：

#### 作用域拖拽与依赖

- 拖拽时不能用 `main.canvas` / `_canvas_view`（它们指向最内层激活作用域）；必须从鼠标下的 Control 向上找第一个 `CanvasView`（`_drop_view_at`），得到真正的目标 canvas/view。否则外层块永远只能在当前 Assume 内移动。
- 拖拽 origin 要记录 `_origin_canvas`，不能只比较 `parent == canvas`；否则 Assume 打开时拿起外层块，取消或失败会丢块。
- socket 搜索必须限定在目标 canvas；否则会吸附到另一层的隐藏槽。
- 跨作用域移动要检查自由假设：`_context_groups_for_canvas` 沿 `parent_record` 链收集可见 group；`get_free_assumptions()` 里的 group 必须全部在目标 context 中。GOAL 按 base canvas（空 context）检查；失败显示 **“Want to cheat huh, no way.”**。
- 不依赖目标作用域假设的块仍允许移出；`ScopeMarkerBlock` 的自由假设不包含自身 group，所以已解除的 `A -> B` 可以离开窗口。
- **ScopeMarkerBlock 不能拖进自己的窗口**：标记的 `get_window_record()` 指回原作用域；目标 canvas 的记录链（含 parent_record）只要包含该窗口，就拒绝并显示 **“Infinite recurrsion huh, no way.”**。只比较“是不是同一个 canvas”不够，因为拖进它的嵌套子作用域也会成环。

#### 嵌套窗口布局

- `ScopeWindow.desktop_layer` 必须高于 `inner_view`（当前 z=10）；否则嵌套窗口尺寸正确但会被父 canvas 盖住，看起来像“没有全屏”。
- 不要只在 `set_fullscreen()` 里同步重排嵌套窗口：此时 Control 容器还没完成布局，`desktop_layer.size` 仍是旧值。必须监听 `desktop_layer.resized`（`_on_desktop_resized`）再同步。
- 非最大化子窗口在父 desktop 尺寸变化时要重新套用当前 parent bounds 的默认布局（父 desktop 的 82%，最小/最大夹取，居中 + 层级 offset），而不是保留旧像素尺寸。这样“先开 Q 再最大化 P”和“先最大化 P 再开 Q”结果一致。
- 最大化子窗口继续填满 parent；还原最大化窗口时也回到当前 parent 的默认布局，不恢复旧的 `_contained_normal_size`。`contained_offset_y` 在窗口创建时固定，保证不同路径位置一致。
- 顶层窗口跟随 base canvas 的 pan/zoom：记录 `base_anchor`，同步 `window.scale = base zoom` 和位置；内层 canvas 仍有自己的 pan/zoom。全屏时 scale 重置为 1，退出后再 sync。
- 每一层 `ScopeWindow` 的 desktop layer 都要高于自己的 inner canvas；嵌套放大/还原会递归更新所有后代。
- 全局浮动 UI（Premises / Rules / GOAL / Trash / UNDO）固定在 `Z_UI_OVERLAY = 1000`，所有 scope layer 及其嵌套 desktop 都在它下面；否则嵌套 z-index 会逐层累加，Assume 窗口就会盖住周边面板。拖拽层 / 模态 / Toast 分别是 2000 / 3000 / 4000，仍高于 UI。
- Premises 面板不是固定 y：`_update_palette_clearance()` 只测量**从根节点开始连续 fullscreen/maximized** 的标题栏链，把 Premises 的顶部 spacer 推到这条链的最低底部，避免窗口红黄绿三个点被面板挡住。一旦遇到第一个非最大化窗口就 `break`；它下面的 maximized 窗口位于普通父窗口内部，不需要再推 Premises。结果按帧延迟刷新（`_palette_clearance_dirty`），因为标题栏位置要等容器布局完成。
- 作用域限制针对的是**同时打开的窗口**，不是逻辑嵌套本身：`MAX_OPEN_SCOPES = 5`（最多同时打开 5 个 Assume 窗口）和 `MAX_MAXIMIZED_SCOPES = 3`（其中最多 3 个同时 fullscreen/maximized）。逻辑层、CLI 和已最小化为 marker 的假设不计数，可以继续有很多很多层。超过时分别显示 **“Too many open assumption windows, no way.”** / **“Too many maximized windows, no way.”**。还原任意一层会释放一个最大化槽位。
- `_scope_layer` 在树顺序中也要放在 `_ui_overlay` 之前。只改 z-index 不够，因为 Godot 的 GUI 输入命中还受树顺序影响；全屏退出、Undo 关闭作用域等路径都要保持这个顺序。

#### Undo

- 快照必须覆盖 `_base_canvas` + 所有 `_scope_open[].inner_canvas` 的根块（深拷贝 + 位置 + goal root index）；否则跨作用域动作无法恢复。
- 创建快照时 `duplicate_block()` 会临时生成 VALID 规则卡，必须用 `_suppress_rule_feedback` 包住，否则“开始拖拽”本身会播放 `rule_valid`。这是之前反复响的实际原因。
- Undo 恢复时要同时设 `_undo_restoring` 和 `_suppress_rule_feedback`；否则重验证会响 `rule_valid` / `goal_valid`。`_on_undo` 末尾还要清掉 pending feedback。
- **新建 Assume 窗口本身是一个 Undo 动作**：打开窗口会推入 `{"kind":"scope_open","record":...}`，Undo 会关闭该窗口并恢复父画布；嵌套窗口按栈逐个撤销。关闭/完成 Assume、加载关卡、Reset 仍会清空历史；Undo 不会重新创建已经关闭的作用域。最多保留 40 步。
- 快照里的 `ScopeMarkerBlock` 会复制结论子树，但不会复制 `window_record`；它仍可作为证明值使用，但不保证能重新打开原来的假设窗口。新增作用域类型前先检查 `duplicate_block`。
- 快照 `goal_index` 只记录根块；GOAL 当前链接到嵌套块时，Undo 不会恢复这个链接（实际玩法中目标是根块）。

#### 音效反馈

- `rule_valid` 只在规则实际发生 EMPTY/PENDING -> VALID 时触发；普通 `refresh()` 不触发；拆开输入再拼回会触发，这是预期行为。
- `goal_valid` 在 solved false -> true 时触发；Undo 中由 `_undo_restoring` 抑制。不要重新加“每关只响一次”或“每块只响一次”的抑制，否则拆开+拼回不再响。
- 拖拽开始时的快照会造成规则副本短暂变 VALID；必须抑制这一路反馈，否则“拿起/放下整块”会响，而它和拆开+拼回不是一回事。
- Toast 使用 `make_display_label()` 时注意其默认 `clip_text = true`；放进 PanelContainer 后最小宽度会塌成 25px，文字直接看不见。需要 `clip_text = false` 并关闭 overrun trimming。

#### Web 字体

- 内嵌 Baloo 2 没有 `↔`，Nunito / Patrick Hand 连 `→` 都没有；Web 没有系统字体 fallback。所有**文字型**公式必须使用 ASCII `->` / `<->`；公式卡由 `FormulaVisual` 自定义绘制箭头，不受影响。
- 内嵌字体也没有 `★`（U+2605）。Levels 页的可选关现在直接沿用正常编号 `7 / 8 / 9`，不再依赖任何星形字符；可选状态改用文本 `OPTIONAL`。
- 嵌套窗口层 z-index 和父窗口缩放同时存在时，输入命中和绘制顺序要分开验证；只检查 `size` 正确不足以证明窗口真的可见。

### 目录结构

```text
project.godot              工程配置（4.7、1280×720、GL Compatibility）
export_presets.cfg         Web 导出预设（单线程，排除开发文件）
ui/main.tscn               唯一场景，根节点挂 main.gd
ui/main.gd                 页面/拖拽/浮窗/构建器总控制器
ui/title_page.gd           标题页、四张规则卡与 Credits/Settings 入口
ui/title_modal.gd          Credits/Settings 共用的纸质弹窗外壳
ui/credits_modal.gd        标题页 Credits（音乐/音效/字体授权）
ui/settings_modal.gd       标题页设置（Music/SFX/静音/全屏/卡片尺寸）
ui/level_bank.gd           7 章、61 关的课程、规则解锁与关卡数据
ui/progress_store.gd       顺序解锁、挑战状态与 user:// 进度持久化
ui/chapter_tab.gd          章节标签（进度/锁定/选中）
ui/rule_intro_card.gd      首次进入章节的新规则介绍卡
ui/*.gd                    卡片、槽、画布、目标、调色板、样式等
logic/                     公式 AST、解析器、规则、证明树、验证结果
cli/                       无头 CLI 会话与入口
tests/                     13 个无头测试入口 + CLI 验收脚本
audio/                     SFX 池、BGM、总线布局、授权文件
audio/sfx/paper/           纸张音效变体（连续播放不重复同一录音）
audio/sfx/typing/          Formula Builder 的键盘敲击音
audio/sfx/ui/              UI 按钮点击与悬停音（与卡片音色分开）
audio/music/               8-bit BGM 循环与音乐授权说明
tools/generate_bgm.py      BGM 合成脚本（可重新生成）
ui/fonts/                  Baloo 2 / Nunito / Patrick Hand（OFL）
ui/props/                  Rain / Wet / Slippery / Dangerous 图标
```

### 关卡与章节

内置 **7 章、61 关**（`ui/level_bank.gd`）：前 6 章各有 **6 核心 + 3 可选挑战**，第 7 章有 **6 核心 + 1 可选挑战**（42 核心 + 19 可选）。可选关不影响章节解锁。

1. **First Moves** — →E、∧E、∧I、~~E，第一关是拖拽教学。
2. **Suppose...** — 通过 ASSUME 浮窗学习 →I。
3. **Either Way** — ∨I、∨E（用 `or_elim_impl` 做分情况）。
4. **Both Ways** — ↔E、↔I，以及双条件传递。
5. **Contradiction** — ¬I，以及用 ¬I + ~~E 组合出 ¬E。
6. **Synthesis** — 用矛盾推导出 ~~I，并完成更长的混合证明。
7. **Grand Finale** — 没有新规则；Peirce、De Morgan、嵌套双条件等纯命题终极挑战。

章节数据包含稳定关卡 id、教学标签和可选挑战标记。每章完成前 6 个核心关后，第 7/8/9 关作为普通编号的 optional 关解锁；顶部栏会同时出现 **NEXT**（本章下一关，通常是第 7 关）和 **NEXT CHAPTER**（下一章第 1 关）。`tests/run_curriculum.gd` 会为每一关运行 CLI 解题脚本，并断言只使用了该章已解锁的规则；新增关卡来自 The Natural Deduction Pack 的命题逻辑部分（4.1–4.6），未引入量词或 identity。

进度保存到 `user://progress.cfg`；章节页显示每章核心关完成数、可选关完成状态和总进度。每章第 7/8/9 关都是 optional，完成前 6 个核心关即可进入下一章。未学到的规则卡会隐藏，ASSUME 在第二章才出现，第一次进入章节时会显示新规则介绍卡。

---

## 已知限制

- 当前版本只覆盖命题逻辑（L1）；∀/∃ 量词、谓词项与 identity（=）尚未实现，The Natural Deduction Pack 的 4.7–4.10 仍留作后续里程碑。
- 进度保存在 `user://progress.cfg`；目前没有游戏内“重置进度”按钮（可手动删除该文件）。
- 章节按顺序解锁；挑战关开放后不影响下一章解锁。
- 全量规则架有 9 张卡，但按章节隐藏未学规则；`ds`、`lem` 与完整作用域卡目前仅供 CLI/核心使用（`create_rule_block` 仍可创建作用域卡）。
- CLI 的 `validate` 只验证「最后生成的规则节点」，不自动寻找树中某个匹配目标的节点。
- `ui/demo_puzzle.gd` 与 `ui/canvas.gd` 中的 Godot 原生 drag/drop 接口是早期/测试用残留。
- `run_ui_scoped` 退出时会打印 RID/ObjectDB 泄漏警告（`main.queue_free()` 后未等待一帧），不影响断言结果。

## 素材与许可

- 项目代码：MIT License，详见 [`LICENSE`](LICENSE)；第三方字体、音效与习题资料保留各自许可。
- 字体：Baloo 2、Nunito、Patrick Hand，均为 SIL Open Font License（`ui/fonts/OFL-*.txt`）。
- 音效：Kenney Casino Audio / Interface Sounds 与 VSCO2 CE（CC0）；Formula Builder 键盘音为 eklee / qubodup 的 “Single Key Press Sounds”（CC-BY 3.0，署名见 `audio/sfx/CREDITS.md`）。全部授权文本见 `audio/licenses/`。
- BGM：`audio/music/deduction_loop.ogg` 是本项目原创合成曲目，无第三方采样或旋律，详见 `audio/music/CREDITS.md`。
- 习题参考：Alastair Carr, *The Natural Deduction Pack*。
