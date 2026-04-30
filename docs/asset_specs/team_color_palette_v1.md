# team_color_palette_v1

## 定位

8 队伍色调色板规格，用于角色和未来附件的确定性重染。

## 规则

必须包含 team_id：

```text
1,2,3,4,5,6,7,8
```

推荐字段：

```text
palette_id,team_id,label,primary_color,secondary_color,outline_color,emissive_color,ui_color,content_hash
```

## 工程约束

- 禁止 AI 重新绘制 8 套队伍色。
- 队伍色必须由 base sprite、mask、palette 确定性生成。
- 生成后轮廓、帧数、pivot 必须与 base 一致。
