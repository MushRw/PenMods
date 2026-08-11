# Rime 输入法数据包（rime.zip）

随 PenMods 分发的中州韵（Rime）拼音输入法数据，部署到 `/userdisk/Music/Rime`。

## 内容

- **明月拼音（luna_pinyin）**：`luna_pinyin.schema.yaml`、`luna_pinyin.dict.yaml`、`pinyin.yaml`，
  来源 [rime/rime-luna-pinyin](https://github.com/rime/rime-luna-pinyin)
- **预设词库**：`essay.txt`（常用词频，`use_preset_vocabulary` 依赖），来源 [rime/rime-essay](https://github.com/rime/rime-essay)
- **基础配置**：`default.yaml`、`punctuation.yaml`、`key_bindings.yaml`、`symbols.yaml`，
  来源 [rime/rime-prelude](https://github.com/rime/rime-prelude)

`default.yaml` 已精简为只启用 `luna_pinyin` 一个方案。

## 部署

- mod 启动时若 `/userdisk/Music/Rime/luna_pinyin.schema.yaml` 缺失，会自动从
  `/userdata/PenMods/rime.zip` 解压部署（不会覆盖已存在的自定义方案）
- 首次部署后 librime 会在 `/userdisk/Music/Rime/build/` 下生成编译词库（.bin）

## 使用

键盘输入页**长按 "abc" 键**切换拼音模式，直接输拼音出候选词。
自定义输入方案可放在 `/userdisk/Music/Rime`（mod 只部署缺失的默认文件，不覆盖用户数据）。

## 许可

Rime 数据为 LGPL-2.1 许可（rime-luna-pinyin / rime-essay / rime-prelude），分发时保留上游来源。
