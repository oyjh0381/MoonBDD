// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "oyjh0381/moonbdd"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/oyjh0381/MoonBDD"

license = "Apache-2.0"

keywords = [
  "bdd",
  "robdd",
  "boolean-functions",
  "symbolic-analysis",
  "model-checking",
]

preferred_target = "wasm-gc"

description = "Canonical ROBDDs and bounded symbolic state-space analysis for MoonBit"
