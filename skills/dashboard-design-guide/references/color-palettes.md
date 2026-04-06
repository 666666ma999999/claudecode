# デジタル庁 ダッシュボードデザインテンプレート 公式カラーパレット

出典: https://www.digital.go.jp/resources/dashboard-guidebook/color-palette/color-code
GitHub: https://github.com/digital-go-jp/policy-dashboard-assets

## 共通色（全テーマ共通）

### テキスト
| 名称 | HEX |
|---|---|
| Text (Black) | #000000 |
| Text (White) | #FFFFFF |
| Label | #626264 |
| Link | #0017C1 |

### 背景
| 名称 | HEX |
|---|---|
| Standard | #F8F8FB |
| Control | #F1F1F4 |

### セマンティック（共通）
| 名称 | HEX |
|---|---|
| Success | #197A4B |
| Error (Blue/LightBlue/Cyan/Green/SolidGray) | #CE0000 |
| Error (Orange/Red) | #850000 |

---

## 1. Solid Gray

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #4D4D4D |

### チャート
| 名称 | HEX | 用途 |
|---|---|---|
| SolidGray 900 | #1A1A1A | 主要系列 |
| SolidGray 700 | #4D4D4D | 第2系列 |
| SolidGray 536 | #767676 | 第3系列 |
| SolidGray 400 | #999999 | 第4系列 |
| SolidGray 200 | #CCCCCC | 薄色 |
| SolidGray 50 | #F2F2F2 | 最薄 |
| Yellow 800 | #A58000 | アクセント |
| Yellow 600 | #D2A400 | アクセント |
| Yellow 400 | #FFC700 | アクセント |

### セマンティック
| 名称 | HEX |
|---|---|
| Blue 600 | #3460FB |
| Blue 200 | #C5D7FB |
| Blue 50 | #E8F1FE |
| Red 600 | #FE3939 |
| Red 200 | #FFBBBB |
| Red 50 | #FDEEEE |

---

## 2. Blue

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #0017C1 |

### チャート
| 名称 | HEX | 用途 |
|---|---|---|
| Blue 1200 | #000060 | 最濃 |
| Blue 900 | #0017C1 | 主要系列 |
| Blue 600 | #3460FB | 第2系列 |
| Blue 400 | #7096F8 | 第3系列 |
| Blue 200 | #C5D7FB | 薄色 |
| Blue 50 | #D9E6FF | 最薄 |
| Yellow 800 | #A58000 | アクセント |
| Yellow 600 | #D2A400 | アクセント |
| Yellow 400 | #FFC700 | アクセント |
| SolidGray 800 | #333333 | 補助 |
| SolidGray 600 | #666666 | 補助 |
| SolidGray 400 | #999999 | 補助 |
| SolidGray 200 | #CCCCCC | 補助 |

### Power BI dataColors順序（GitHub JSON）
```
["#0017C1", "#3460FB", "#7096F8", "#C5D7FB", "#E8F1FE", "#FE3939", "#FFBBBB", "#F8F8FB"]
```

---

## 3. Light Blue

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #0055AD |

### チャート
| 名称 | HEX |
|---|---|
| LightBlue 1200 | #00234B |
| LightBlue 900 | #0055AD |
| LightBlue 600 | #008BF2 |
| LightBlue 400 | #57B8FF |
| LightBlue 200 | #C0E4FF |
| LightBlue 50 | #F0F9FF |
| Yellow 800 | #A58000 |
| Yellow 600 | #D2A400 |
| Yellow 400 | #FFC700 |

---

## 4. Cyan

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #006F83 |

### チャート
| 名称 | HEX |
|---|---|
| Cyan 1200 | #003741 |
| Cyan 900 | #006F83 |
| Cyan 600 | #00A3BF |
| Cyan 400 | #2BC8E4 |
| Cyan 200 | #99F2FF |
| Cyan 50 | #E9F7F9 |
| Green 800 | #197A4B |
| Green 600 | #259D63 |
| Green 400 | #51B883 |

---

## 5. Green

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #115A36 |

### チャート
| 名称 | HEX |
|---|---|
| Green 1200 | #032213 |
| Green 900 | #115A36 |
| Green 600 | #259D63 |
| Green 400 | #51B883 |
| Green 200 | #9BD4B5 |
| Green 50 | #E6F5EC |
| Cyan 800 | #006F83 |
| Cyan 600 | #00A3BF |
| Cyan 400 | #2BC8E4 |

---

## 6. Orange

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #AC3E00 |

### チャート
| 名称 | HEX |
|---|---|
| Orange 1200 | #541E00 |
| Orange 900 | #AC3E00 |
| Orange 600 | #FB5B01 |
| Orange 400 | #FF8D44 |
| Orange 200 | #FFC199 |
| Orange 50 | #FFEEE2 |
| Yellow 800 | #A58000 |
| Yellow 600 | #D2A400 |
| Yellow 400 | #FFC700 |

---

## 7. Red

### 背景
| 名称 | HEX |
|---|---|
| Highlight | #CE0000 |

### チャート
| 名称 | HEX |
|---|---|
| Red 1200 | #620000 |
| Red 900 | #CE0000 |
| Red 600 | #FE3939 |
| Red 400 | #FF7171 |
| Red 200 | #FFBBBB |
| Red 50 | #FDEEEE |
| Yellow 800 | #A58000 |
| Yellow 600 | #D2A400 |
| Yellow 400 | #FFC700 |

---

## matplotlib用 Python辞書

```python
DIGITAL_AGENCY = {
    "common": {
        "text_black": "#000000",
        "text_white": "#FFFFFF",
        "label": "#626264",
        "link": "#0017C1",
        "bg_standard": "#F8F8FB",
        "bg_control": "#F1F1F4",
        "success": "#197A4B",
        "error": "#CE0000",
        "error_dark": "#850000",
    },
    "solid_gray": {
        "900": "#1A1A1A", "700": "#4D4D4D", "536": "#767676",
        "400": "#999999", "200": "#CCCCCC", "50": "#F2F2F2",
        "highlight": "#4D4D4D",
        "accent": ["#A58000", "#D2A400", "#FFC700"],
    },
    "blue": {
        "1200": "#000060", "900": "#0017C1", "600": "#3460FB",
        "400": "#7096F8", "200": "#C5D7FB", "50": "#D9E6FF",
        "highlight": "#0017C1",
        "accent": ["#A58000", "#D2A400", "#FFC700"],
        "dataColors": ["#0017C1", "#3460FB", "#7096F8", "#C5D7FB", "#E8F1FE", "#FE3939", "#FFBBBB", "#F8F8FB"],
    },
    "light_blue": {
        "1200": "#00234B", "900": "#0055AD", "600": "#008BF2",
        "400": "#57B8FF", "200": "#C0E4FF", "50": "#F0F9FF",
        "highlight": "#0055AD",
        "accent": ["#A58000", "#D2A400", "#FFC700"],
    },
    "cyan": {
        "1200": "#003741", "900": "#006F83", "600": "#00A3BF",
        "400": "#2BC8E4", "200": "#99F2FF", "50": "#E9F7F9",
        "highlight": "#006F83",
        "accent": ["#197A4B", "#259D63", "#51B883"],
    },
    "green": {
        "1200": "#032213", "900": "#115A36", "600": "#259D63",
        "400": "#51B883", "200": "#9BD4B5", "50": "#E6F5EC",
        "highlight": "#115A36",
        "accent": ["#006F83", "#00A3BF", "#2BC8E4"],
    },
    "orange": {
        "1200": "#541E00", "900": "#AC3E00", "600": "#FB5B01",
        "400": "#FF8D44", "200": "#FFC199", "50": "#FFEEE2",
        "highlight": "#AC3E00",
        "accent": ["#A58000", "#D2A400", "#FFC700"],
    },
    "red": {
        "1200": "#620000", "900": "#CE0000", "600": "#FE3939",
        "400": "#FF7171", "200": "#FFBBBB", "50": "#FDEEEE",
        "highlight": "#CE0000",
        "accent": ["#A58000", "#D2A400", "#FFC700"],
    },
    "gray_supplement": {
        "800": "#333333", "600": "#666666", "400": "#999999", "200": "#CCCCCC",
    },
}
```
