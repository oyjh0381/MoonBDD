# MoonBDD

MoonBDD 是原创 Apache-2.0 MoonBit 库与 Native CLI，提供规范化的约简有序二元
决策图（ROBDD）以及有界有限状态符号可达性分析。

主要能力包括显式 Manager 所有权、固定变量顺序、ITE 与常用布尔运算、表达式解析、
限制/组合/量化、满足赋值、精确模型计数、确定性 JSON v1、DOT、非破坏式变量重排和
互斥协议可达性示例。分析层还提供有界真值表、不相交满足立方体、部分赋值判定、
蕴含/等价/互斥反例、骨干变量以及命名约束集诊断，可定位冗余策略或删除极小冲突。所有可能指数增长的入口
均受资源预算约束，超限返回结构化错误。

要求 `moonc >= 0.10.16`；本次验证工具链为 moon 0.1.20261016、
moonc 0.10.16+b1a0e846e。验证脚本需要 Python 3.10 以上，Native CLI 需要 C 工具链。
私有仓库需要 GitHub 访问授权。

```sh
moon update
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/moonbdd --target native -- stats a,b "a & b"
moon run cmd/moonbdd --target native -- truth-table a,b "a ^ b" 4
moon run cmd/moonbdd --target native -- cubes a,b,c "(a & b) | (!a & c)" 8
moon run cmd/moonbdd --target native -- diagnose a,b "enable=a;disable=!a"
moon run examples/mutex_reachability
```

`reach` 的初始状态和不变量只能依赖当前状态变量，迁移关系只能依赖声明的
当前/后继变量对；未配对维度返回 `InvalidArgument`。环境输入应先显式量化。
Manager 和状态编码保存私有数组，变量名访问器返回独立副本。

CI 在 Linux、macOS、Windows 检查、构建、测试并运行示例。
Windows 遇到官方编译器拒绝扩展路径时，使用仓库自带的
`tools/windows/moon.ps1` 替代 `moon`；需要 MSVC 与 Windows SDK。
完整本地验证和敏感信息扫描命令见 [测试说明](docs/TESTING.md)。

ROBDD 只在同一变量顺序下具有规范性，某些公式仍可能指数膨胀。0.1 版本不提供
CTL/LTL、无限状态证明、SAT/SMT、并行 Manager、后台自动重排或稳定二进制格式。

项目为原创 MoonBit 实现，不移植 CUDD、BuDDy 或 Sylvan 源码。算法资料与来源说明
见 `THIRD_PARTY_NOTICES.md`。
