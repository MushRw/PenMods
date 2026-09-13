# Rime 输入法数据包（rime.zip）

随 PenMods 分发的是**雾凇拼音**（[iDvel/rime-ice](https://github.com/iDvel/rime-ice)）数据，
部署到 `/userdisk/Music/Rime`，方案名 `rime_ice`。

## 为什么是"裁剪版"

词典笔（YDP02X，RK3326 / 460MB 内存）上跑的是 PenMods 静态链接的 **librime 1.15**，而它：

- **没有编译 Lua**（缺 `librime-lua`）→ 雾凇拼音的 13 处 `lua_translator` / `lua_filter`
  （时间日期、农历、纠错提示、v 模式、长词优先、置顶候选、计算器等）全部不可用；
- **没有 OpenCC 数据**（缺 `*.ocd2`）→ `simplifier`（Emoji、简繁切换）不可用；
- **只有约 250MB 可用内存** → 原版词库（`base` 16.6MB / `tencent` 17.3MB / `ext` 11.9MB）
  编译成 `table.bin` 需要 240MB 以上，直接 OOM。

所以本包做了三件事：

1. **词库按词频截取**：`cn_dicts/base.dict.yaml` 只保留权重 ≥ 1000 的词条（240,311 条），
   加上 `8105` 单字表（8,757 条）与 `others`，合计约 25 万条（原版雾凇 54 万条
   在笔上编译需要 240MB+ 内存，会 OOM）；
2. **删掉 Lua / OpenCC / 拆字组件**：`rime_ice.schema.yaml` 的 `engine` 只保留
   `ascii_composer / recognizer / key_binder / speller / punctuator / selector /
   navigator / express_editor`，翻译器只留 `punct_translator / script_translator /
   table_translator@custom_phrase / @melt_eng / @cn_en`，过滤器只留 `uniquifier`；
3. **不带 `essay.txt`**：雾凇拼音的词频写在词库里，不需要 `use_preset_vocabulary`
   （原明月拼音方案靠 5.9MB 的 essay.txt，编译出的 `table.bin` 反而是 13MB）；
4. **候选词数量**：`default.yaml` 的 `menu.page_size` 从上游默认 5 调到 **20**
   （键盘候选栏是横向可滑动的 ListView，一屏多给一些候选更好挑）。

保留下来的是：**雾凇拼音的词库与词频、模糊音（speller/algebra）、自定义短语、英文与中英混输**。

## 内容

```text
default.yaml            全局配置（schema_list 只留 rime_ice）
rime_ice.schema.yaml    输入方案（engine 已裁剪）
rime_ice.dict.yaml      主词库清单（import 8105 / base / others + 内联字母数字条目）
custom_phrase.txt       自定义短语
symbols_v.yaml          v 模式符号表（方案里 __include 引用）
melt_eng.dict.yaml      英文输入词库清单
cn_dicts/8105.dict.yaml 常用汉字单字表
cn_dicts/base.dict.yaml 核心词库（按词频截取）
cn_dicts/others.dict.yaml
en_dicts/en.dict.yaml / en_ext.dict.yaml  英文词库
en_dicts/cn_en.txt      中英混合词汇
```

真机实测（YDP02X，固件 2.1.2）：编译 < 1 分钟、内存无明显波动，产物
`rime_ice.table.bin` 约 7.1MB（明月拼音方案 13MB —— 本包词条数是它的 8 倍，
产物反而更小，因为不背 5.9MB 的 essay 预设词库）。

## 部署

- mod 启动时若 `/userdisk/Music/Rime/rime_ice.schema.yaml` 缺失，会自动从
  `/userdata/PenMods/rime.zip` 解压并用 `cp -rf` 部署（含 `cn_dicts/` 等子目录）；
- 只补默认文件，用户自己放在 `/userdisk/Music/Rime` 的方案/词库不受影响（同名文件会覆盖）；
- 首次部署后 librime 会在 `/userdisk/Music/Rime/build/` 下生成 `.bin` 编译产物；
- 想换回别的方案：把 `*.schema.yaml` 放进 `/userdisk/Music/Rime`，
  在 `default.yaml` 的 `schema_list` 里加一行即可。

## 使用

键盘输入页**长按 "abc" 键**切换拼音模式，直接输拼音出候选词（雾凇拼音的模糊音已启用）。

## 重新打包（调词库规模 / 跟随上游更新）

```bash
# 1) 取上游源码
curl -L https://github.com/iDvel/rime-ice/archive/refs/heads/main.zip -o rime-ice.zip
unzip -q rime-ice.zip -d third-party/

# 2) 生成数据包
#    --weight-min 控制词库规模：1000 ≈ 24 万条 / 约 2.9MB 包（当前默认）
#                                10000 ≈ 7.7 万条 / 约 1.2MB 包
#    --page-size  控制每页候选词数量（当前 20）
python scripts/make_rime_ice_pkg.py \
    --src third-party/rime-ice-main \
    --zip resource/rime/rime.zip
```

把 `--weight-min` 调到 `1000` 会收进更多长尾词（约 24 万条），代价是编译时间、
`table.bin` 体积和峰值内存都会上升；换完在笔上记得看 `/userdata/applog` 里的
Rime 日志有没有报错。

## 许可

- 雾凇拼音（rime-ice）：**GPL-3.0-only**（与本仓库一致），随包保留上游来源；
- 词库部分词条来自上游整理（含腾讯词向量等来源），本包只做按词频截取。
