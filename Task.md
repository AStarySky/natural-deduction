```markdown
# 任务：实现 Natural Deduction 解密游戏的命令行最小可运行单元（CLI MUR）

## 角色与上下文
你是一个严谨的 GDScript 工程师。我们在开发一个二维矢量扁平风格的自然演绎（Natural Deduction）解密游戏，最终形态是玩家拖拽规则节点拼出证明树。当前阶段只做**纯逻辑核心 + 可交互的 CLI REPL**，不做任何 UI、渲染、拖拽、动画或美术资源。CLI 是连接层的第一次真实实现，渲染层暂时用文本代替。

## 目标
实现一个可在 Godot 4.x 无头运行的命令行版本，能够：
1. 把用户输入的公式字符串解析为命题逻辑 AST。
2. 维护前提列表、证明树和目标公式。
3. 通过命令逐条应用自然演绎规则，生成新节点。
4. 文本渲染当前证明树，并递归验证整棵树是否合法、根是否等于目标。
5. 用一段可执行的命令脚本作为回归测试，同时充当 CLI 用法文档。

## 技术约束
- 语言：GDScript，Godot 4.x，纯逻辑脚本，不继承 Node，不依赖场景树。
- 目录：
  - `res://logic/`：公式 AST、解析器、规则、证明树、验证器
  - `res://cli/`：REPL 主循环、命令解析、文本树渲染
  - `res://tests/`：命令脚本与自动化跑脚本的入口
- 不引入任何第三方插件或矢量插件。
- 不使用 `print` 作为唯一验证手段；核心逻辑返回结构化结果，CLI 只负责展示。
- 每个公开函数必须有明确返回类型和简短注释。
- 公式内部用枚举或字符串常量表示连接词，`to_string()` 输出使用 `~ & | ->`，不依赖 Unicode 渲染。

## 数据结构要求

### Formula（公式 AST）
至少支持：
- `Atom(name: String)`
- `Not(child: Formula)`
- `And(left: Formula, right: Formula)`
- `Or(left: Formula, right: Formula)`
- `Implies(left: Formula, right: Formula)`

要求：
- `equals(other: Formula) -> bool` 做结构相等比较。
- `to_string() -> String` 用于调试和 CLI 展示，例如 `A -> B`、`A & B`、`~A`、`A | B`。
- 公式应视为不可变；规则应用时构造新对象，不修改已有 AST。

### ProofNode（证明树节点）
- `id: String`，唯一标识。前提节点用 `p1`、`p2`…；规则节点用 `n1`、`n2`…。
- `formula: Formula`
- `rule_id: String`，前提节点为 `"premise"`。
- `premise_ids: Array[String]`，按规则定义的插槽顺序记录来源节点 id。
- `extra: Dictionary`，用于记录 `or_intro_left/right` 显式传入的另一侧公式等附加参数。

### ProofTree
- 持有所有节点，支持按 id 查找。
- `add_premise(formula) -> ProofNode`
- `apply_rule(rule_id, premise_ids, extra_formula = null) -> RuleResult`
- `validate(root_id: String, goal: Formula) -> ValidationResult`
- `to_text() -> String` 文本渲染，缩进表示父子关系，每行形如：
  `[n2] C  (rule: impl_elim, premises: n1, p3)`
  前提节点标注 `rule: premise`。

### RuleResult
- `ok: bool`
- `node: ProofNode`（成功时）
- `error: String`（失败时，必须可读，说明哪条规则、期望什么、实际收到什么）

### ValidationResult
- `ok: bool`
- `errors: Array[String]`，每条错误说明节点 id、期望公式、实际公式或规则不匹配原因。

## 规则集（第一版只做这些，不要扩展）
规则 id 与精确语义：

1. `impl_elim`（→ 消除 / Modus Ponens）
   - 输入两个前提：`A` 和 `A -> B`（顺序不限，但要有确定匹配策略，见下）
   - 输出：`B`

2. `and_elim_left`
   - 输入：`A & B`，输出 `A`

3. `and_elim_right`
   - 输入：`A & B`，输出 `B`

4. `and_intro`
   - 输入：`A` 和 `B`（顺序不限）
   - 输出：`A & B`

5. `or_intro_left`
   - 输入：`A`
   - 额外参数：另一侧公式 `B`
   - 输出：`A | B`

6. `or_intro_right`
   - 输入：`B`
   - 额外参数：另一侧公式 `A`
   - 输出：`A | B`

7. `double_neg_elim`
   - 输入：`~~A`，输出 `A`

注意：
- 不要实现 → 引入、∨ 消除、¬ 引入、RAA、假设和子证明。
- 顺序不限的规则（`impl_elim`、`and_intro`）要尝试两种匹配，任一成功即返回。
- `or_intro_left/right` 缺少额外公式时必须返回明确错误，不允许猜测。
- 规则应用失败不得产生半成品节点。

## 公式解析器
- 递归下降解析，支持 `~ & | ->` 和括号。
- 优先级（高到低）：`~` > `&` > `|` > `->`。
- `->` 右结合，例如 `A -> B -> C` 解析为 `A -> (B -> C)`。
- 支持多字符原子名，例如 `P1`、`Rain`。原子名不能包含 `~ & | ( ) - >` 和空格。
- 解析失败返回结构化错误，说明位置和原因，不得静默返回空公式。

## CLI 命令集（最小够用）
REPL 逐行读取命令，执行后打印结果。命令：

```
premise <formula>              添加前提，分配 pN，打印节点 id 和公式
goal <formula>                 设置目标公式
apply <rule_id> <id1> [id2] [extra_formula]
                               应用规则，打印新节点 id 和公式；失败打印可读错误
tree                           文本渲染当前证明树
validate                       运行证明检查器，检查当前证明树根是否等于 goal
help                           打印命令说明
quit                           退出
```

语义约定：
- `apply` 允许先构造中间节点、稍后再连到 goal；不要求新节点立即等于目标。
- `validate` 以“当前证明树中最后生成的规则节点”为根，若还没有规则节点则报错说明。
- 允许同一前提或中间结论被多次使用。
- 目标公式未设置时 `validate` 返回明确错误。

## 验收脚本（必须能跑通）
在 `res://tests/mur_cli_script.txt` 中写入以下命令脚本，并实现一个测试入口（例如 `res://tests/run_cli_script.gd`）按行喂给 CLI，收集输出并做断言。

### 脚本 A：正确证明
```
premise A
premise A -> B
premise B -> C
goal C
apply impl_elim p1 p2
apply impl_elim n1 p3
validate
tree
```

断言：
- 两次 `apply` 都返回成功，新节点公式分别为 `B` 和 `C`。
- `validate` 返回 `ok == true`，无错误。
- `tree` 输出包含 `[n2] C` 和两次 `impl_elim`。

### 脚本 B：错误证明被拒绝
```
premise A
premise A -> B
goal B
apply and_intro p1 p2
validate
```

断言：
- `and_intro` 成功生成 `A & (A -> B)`。
- `validate` 返回 `ok == false`，错误信息指出根公式 `A & (A -> B)` 不等于目标 `B`。

### 脚本 C：规则输入不匹配
```
premise A
premise B
apply impl_elim p1 p2
```

断言：
- `apply` 返回失败，错误信息说明没有找到 `A -> ?` 或 `? -> ?` 形式的匹配。

### 脚本 D：∧ 引入与消除链路
```
premise A
premise B
goal B
apply and_intro p1 p2
apply and_elim_right n1
validate
```

断言：`validate` 返回 `ok == true`。

### 脚本 E：∨ 引入缺额外公式
```
premise A
apply or_intro_left p1
```

断言：返回明确错误，提示缺少另一侧公式。

### 脚本 F：∨ 引入带额外公式
```
premise A
goal A | B
apply or_intro_left p1 B
validate
```

断言：`apply` 成功，`validate` 返回 `ok == true`。

### 脚本 G：解析器错误处理
```
premise A ->
goal (A & B
```

断言：两条命令都返回可读的解析错误，不崩溃，不产生空公式节点。

## 输出要求
完成后请报告：
1. 创建的文件列表及每个文件职责。
2. 如何从命令行无头运行验收脚本（Godot 4.x 的 `--headless --script` 或等价方式）。
3. 每个脚本的实际输出摘要与断言结果；若失败，说明原因。
4. 设计取舍：`ProofNode` 用 id 引用还是对象引用、`impl_elim` 的匹配顺序策略、解析器优先级实现方式。
5. 明确列出**没有实现**的内容（UI、拖拽、假设、→ 引入、∨ 消除等），避免范围蔓延。

## 不要做
- 不要创建任何场景文件、Control 节点、UI、拖拽逻辑、动画、美术资源。
- 不要引入 Godot 矢量插件或第三方库。
- 不要实现第一版规则集之外的规则。
- 不要为了让验收脚本通过而放宽验证逻辑；验证必须是结构化、递归、基于规则语义的。
- 不要让 `validate` 只比对根公式而跳过中间节点检查。
```