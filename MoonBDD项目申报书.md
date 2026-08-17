# MoonBDD 项目申报书

- 项目名称：MoonBDD：MoonBit 原生 ROBDD 与符号状态空间分析工具包
- 参赛者：欧阳金辉；联系方式：19386561764
- GitHub 仓库：https://github.com/oyjh0381/MoonBDD
- Gitlink 仓库链接：待从 GitHub 公开仓库导入并同步
- 项目方向：MoonBit 原生基础算法库、配置约束分析与有限状态符号验证
- 项目性质：原创项目，非移植；许可证：Apache License 2.0

## 项目简介与使用场景
MoonBDD 使用纯 MoonBit 实现规范化约简有序二元决策图（ROBDD），以显式 Manager、固定变量顺序、唯一表和 ITE 缓存紧凑表示布尔函数，并通过结构化资源预算控制指数级最坏情况。
项目面向 MoonBit 库作者、配置与权限策略工具、数字逻辑应用及协议验证工具，适用于特性组合校验、语义关系比较、满足赋值解释、精确模型计数、约束冲突定位和有限状态空间可达性分析。

## 核心功能
- 提供常量、变量、ITE、NOT/AND/OR/XOR/蕴含/等价，以及带位置诊断和稳定优先级的布尔表达式编译器。
- 支持 Restriction、Composition、支持集、存在/全称量化、单模型、有界模型枚举、UInt64 溢出检测与内部大整数精确模型计数。
- 提供有界真值表、不相交满足立方体、部分赋值判定、蕴含/等价/互斥反例、骨干变量，以及命名约束的冗余分析和删除极小冲突集。
- 提供确定性 JSON Schema v1 严格导入导出、DOT、统计、规范表达式、非破坏式显式重排和确定性相邻窗口优化。
- 支持当前/下一状态变量配对、关系乘积、量化与重命名构成的有界符号可达性，并在不变量失败时返回可执行反例模型。
- Native CLI 提供 `compile`、`stats`、`sat-one`、`count`、`truth-table`、`cubes`、`backbone`、`diagnose`、`dot`、`reorder` 和 `reach`，支持参数、stdin 与显式文件输入及机器可读错误。

## 实现方案、边界与交付
采用可移植 MoonBit 核心与 Native CLI 两级架构，19 个 `.mbt` 文件、4606 行 MoonBit 源码，其中非空且非行注释有效代码 4124 行；Wasm、Wasm-GC、JavaScript、Native 四目标各 46 项测试通过，Native CLI 16 个进程场景通过，并提供三个可运行示例、跨平台 CI、性能基线和可复现 LOC 检查。
v0.1 为单线程内存型 ROBDD，不提供 CTL/LTL、无限状态证明、SAT/SMT 求解器、并行 Manager、后台自动重排、稳定二进制格式或 Graphviz 渲染；ROBDD 仅在同一变量顺序下规范，恶劣顺序仍可能指数膨胀。
项目为原创 MoonBit 实现，不移植 CUDD、BuDDy 或 Sylvan 源码；ROBDD 理论资料和直接依赖在 `THIRD_PARTY_NOTICES.md` 中披露，未包含私有、闭源、商业或来源不明代码。交付公开 GitHub/Gitlink 仓库、20 个有效提交、Apache-2.0 源码、完整 README/设计与安全文档、示例、测试和 CI，并发布 `oyjh0381/moonbdd@0.1.0` 至 mooncakes.io。
