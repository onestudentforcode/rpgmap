# 地图数据 Schema（P1 工作流）

地图 = **JSON 源数据**（`content/`，手工维护）→ **bake**（`tools/bake_maps.py`，校验+规范化）
→ **烘焙产物**（`content/baked/`，运行时唯一读取物，进 git）。
改地图 = 改源 JSON → 重跑 bake → 提交（源与产物都进 git，可 diff、可回溯、确定性）。

## 1. 地图源数据 `content/maps/<id>.json`

| 字段 | 说明 |
|------|------|
| `schema` | 恒为 1 |
| `id` | 必须与文件名一致 |
| `name` | 显示名 |
| `theme` | 主题 id → `content/themes/<theme>.json` |
| `spawn` / `spawn_face` | 初始出生格 / 朝向（up/down/left/right） |
| `layout` | ASCII 字符画，行等宽；一字符 = 一格 |
| `legend` | 字符 → 语义图块；可选 `wall:true`（画到墙层）、`object`（物件 id） |
| `portals` | 传送门列表：`{cell, to, spawn, face}`；双向各写一条 |
| `interactions` | 字符 → `{name, pages[]}` 纯氛围对话（有选项/改状态的交互 P3 才引入，且将来走引擎） |

约定：物件字符所在格自动铺 `tile` 指定的地面；`wall:true` 字符只画墙层不铺地。

## 2. 主题包 `content/themes/<id>.json`

| 字段 | 说明 |
|------|------|
| `tile_size` | 图块边长（当前 32） |
| `textures` | tileset / objects / player 三张贴图的路径与尺寸（manifest 的依据） |
| `tiles` | 语义名 → `{atlas:[列,行], solid?}`；solid 图块烘焙出全格碰撞 |
| `objects` | 物件名 → `{region}` 或 `{frames:[...]}`（两帧待机），可选 `box`（脚底碰撞盒）、`zone_offset`（交互区偏移，如电梯） |
| `player` | `prompt_region`（E 提示在 objects 图集上的区域）、`prompt_texture` |

换肤（P2）= 新增主题 JSON + 换贴图，地图源数据不动。

## 3. 烘焙产物 `content/baked/`

```
baked/
  index.json                      # {default_theme, themes, default_map, maps}
  <theme>/theme.json              # 运行时玩家配置（贴图路径、帧尺寸、提示区域）
  <theme>/maps/<id>.json          # 规范化地图（唯一运行时格式）
  <theme>/manifest.json           # 美术采购单（见 §4）
```

规范化地图要点（Godot 侧 `scripts/map_host.gd` 只读这些）：

- `tiles`：本图用到的语义图块表（主题声明顺序）`{name, atlas, solid}`
- `ground` / `walls`：逐格图块索引平铺数组（行优先，`-1` = 空），长度 = 宽×高
- `objects`：`{kind, cell, region|frames, box?, zone_offset}` —— 区域已从主题解析为具体像素
- `interactions`：`{char, cells[], name, pages, zone_offset}` —— 同字符多格共享一份文案
- `portals`：`{cell, to, spawn, face}`

## 4. bake 校验清单

- 结构：schema/id/文件名一致、行等宽、字符全覆盖、atlas 越界检查
- 图例引用的图块/物件必须在主题中定义
- 出生点 / 传送格 / 传送落点：在界内、不落在实心图块、落点不压对方触发格（防回弹）
- 门户双向配对：A→B 必须存在 B→A；不支持跨主题传送
- 交互：必须有物件锚点、文案非空、字符确实出现在布局中
- **确定性**：同一源数据重复 bake，产物逐字节一致（sort_keys + 固定遍历）

## 5. 常用命令

```bash
python tools/bake_maps.py                # 烘焙（校验失败即退出，不写产物）
python tools/gen_placeholder_assets.py   # 重新生成占位美术（含逐行 QC）
godot --headless --path . -- --selftest  # 17 项逻辑自测
godot --path . -- --shots=DIR            # 窗口截图验收（5 张）
```
