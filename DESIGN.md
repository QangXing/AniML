# AniML 项目设计文档

> 一款面向 Android 的**可视化 HTML 动画制作器**。用户在横屏手机上以 WYSIWYG 方式编辑动画，最终产物是一份可独立运行的 HTML 文件。

---

## 1. 项目概述

- **产品名称**：AniML（Animation Markup Layer）
- **平台**：Android APK（Flutter 3.x + Dart 3）
- **默认方向**：强制横屏（`landscape`）
- **核心定位**：
  - 把「动画」视为一个可被可视化编辑的 HTML 页面。
  - 编辑器的渲染页就是最终要导出的 HTML 画布。
  - 编辑器本身只负责**布局、动画参数、资源编排**，不直接渲染像素；真正的渲染由 WebView 完成。

---

## 2. 核心概念

| 概念 | 说明 |
|------|------|
| **渲染页（Render Page）** | 占据整个横屏手机屏幕的白色背景区域，是用户看到的全部工作区。 |
| **渲染区（Render Area）** | 渲染页中一块带有浅边框的矩形区域，真正用来显示/运行用户导入的 HTML。 |
| **坐标系** | 以渲染区左上角为原点 `(0,0)`，X 轴向右，Y 轴向下，单位为逻辑像素 `px`。编辑时可在背景上叠加浅色网格和坐标轴。 |
| **像素大小** | 渲染区的宽、高可按像素精确设置，例如 `1920×1080`、`1280×720`、`1080×1080`。 |
| **长宽比** | 提供常用比例：`16:9`、`4:3`、`1:1`、`9:16`、`自定义`。 |
| **两种模式** | **搜索模式**（浏览/手势控制）与 **更改模式**（编辑 HTML 内容）。 |

---

## 3. 技术栈

| 层级 | 选型 | 说明 |
|------|------|------|
| UI 框架 | Flutter 3.x（Dart 3） | 跨平台、手势丰富、APK 构建成熟。 |
| HTML 渲染引擎 | `flutter_inappwebview` | 在 Flutter 内嵌高性能 WebView，可注入 JS、监听事件、调用 DOM API。 |
| 状态管理 | `flutter_riverpod` | 管理渲染区配置、模式、项目数据、WebView 控制器等。 |
| 文件/存储 | `file_picker`、`path_provider`、`shared_preferences` | 导入 HTML/资源、缓存项目、保存用户偏好。 |
| 动画时序 | 自定义 Timeline Model + CSS/JS 注入 | 编辑器维护关键帧，最终编译为 CSS `@keyframes` 或 JS 动画。 |
| 编译打包 | Dart 脚本 + 正则/简单解析 | 将 CSS、JS、图片等资源内联为 Data URI，输出单一 HTML。 |

---

## 4. UI/UX 设计

### 4.1 页面结构

```
┌──────────────────────────────────────────────────────────────┐
│  系统状态栏（隐藏或沉浸，保留电量/时间）                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                    ┌─────────────────────┐                   │
│                    │                     │                   │
│       渲染页        │     渲染区           │     属性/图层面板   │
│     (纯白背景)      │  (浅边框 + 网格坐标)  │    (可收起)        │
│                    │                     │                   │
│                    └─────────────────────┘                   │
│                                                              │
│  🔍  ✏️                                                       │
│  (左下角工具栏)                                               │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 渲染页

- **背景色**：默认 `#FFFFFF`（纯白）。
- **溢出处理**：当渲染区经过缩放/旋转后超出屏幕时，渲染页应允许内容溢出显示，不裁剪。
- **沉浸模式**：隐藏 Android 底部导航栏，最大化编辑区域；用户从底部上滑可临时唤出。

### 4.3 渲染区

- **边框**：极浅的灰色边框，例如 `#E5E5E5` / `0.5dp`，保证任何白色 HTML 背景下都能看见边界。
- **阴影**：可选的轻微投影，让渲染区在纯白背景上更立体。
- **坐标系**：
  - 原点在左上角。
  - 绘制浅灰色 X/Y 轴线（`#DCDCDC`）。
  - 网格步长随缩放动态变化：`10px`、`50px`、`100px`。
  - 轴线上标注刻度值（`0`、`100`、`200`…）。
- **尺寸设置**：
  - 支持手动输入宽、高。
  - 下拉选择常用比例与分辨率。
  - 修改尺寸时，WebView 的 `viewport` 同步更新。

### 4.4 左下角工具栏

- **位置**：屏幕左下角，距离边缘 `16dp`。
- **样式**：两个圆形/圆角矩形按钮，纯灰色图标（`#9E9E9E`），无文字，激活时颜色加深（`#616161`）。
- **图标**：
  - 🔍 放大镜：进入「搜索/浏览模式」。
  - ✏️ 铅笔：进入「更改/编辑模式」。

### 4.5 右侧面板

- **属性面板**：调整选中元素的 `left/top/width/height/opacity/rotate/scale` 等。
- **图层面板**：列出 HTML 中的主要容器/元素，支持显隐、锁定、重命名。
- **时间轴面板**（MVP 之后）：关键帧、播放控制、时长设置。
- 所有面板默认可滑动收起，留出最大渲染区。

---

## 5. 两种操作模式

### 5.1 搜索模式（浏览/手势模式）

> 图标：放大镜。该模式下用户像操作地图一样观察整个渲染页。

- **单指拖动**：平移整个渲染区。
- **双指捏合**：缩放渲染区，范围 `0.1x ~ 5.0x`。
- **双指旋转**：以屏幕中心或双指中点为支点旋转渲染区，范围 `-180° ~ 180°`。
- **双击**：还原为 `1.0x`、无旋转、居中显示。
- **事件拦截**：所有手势被 Flutter 的 `GestureDetector` 捕获，不传递给 WebView。

### 5.2 更改模式（编辑模式）

> 图标：铅笔。该模式下用户直接与 HTML 内容交互。

- **点击**：通过 WebView 注入的 JS 脚本命中 DOM 元素，显示选中框（marching ants）。
- **拖动**：移动选中的元素，实时更新 CSS `transform/left/top`。
- **缩放/旋转手柄**：选中元素四角出现控制点，拖动可缩放、旋转。
- **文本编辑**：双击文本元素唤起软键盘，直接修改内容。
- **属性输入**：右侧面板同步显示并允许精确输入。
- **新增元素**：工具栏可扩展按钮，插入矩形、文本、图片、SVG 等（生成对应 HTML）。

---

## 6. HTML 导入与渲染

### 6.1 导入流程

1. 用户点击「导入」按钮。
2. 调用 `file_picker` 选择 `.html`、`.htm`，或选择一个包含 `index.html` 的文件夹/zip。
3. 解析 HTML，提取 `<link>`、`<script>`、`<img>`、`<style>` 等外部资源引用。
4. 将资源路径映射到本地临时目录，设置 WebView `baseUrl`。
5. 加载到渲染区 WebView。

### 6.2 WebView 要求

- 启用 `JavaScriptCanOpenWindowsAutomatically: false`。
- 允许本地文件访问。
- 注入一个全局 `window._AniML` 对象，用于与 Flutter 通信：
  - `selectElement(selector)`：选中元素。
  - `getElementStyles()`：返回选中元素的 CSS 属性。
  - `setElementStyles(styles)`：更新 CSS 属性。
  - `getBoundingBox()`：返回元素相对于渲染区的位置尺寸。

### 6.3 安全沙箱

- 禁止 HTML 自动跳转、弹窗。
- 动画中使用的 `fetch/XHR` 仅允许本地资源或明确配置的白名单。
- 不执行未经验证的外部脚本（导入时可选净化处理）。

---

## 7. 动画制作

### 7.1 动画表达方式

- **CSS Keyframes**：编辑器生成 `@keyframes`，绑定到元素 class。
- **CSS Transitions**：通过属性变化触发。
- **JS 动画**：针对复杂曲线或逐帧控制，注入 `requestAnimationFrame` 脚本。

### 7.2 时间轴

- 轨道按元素分组。
- 关键帧记录时间、属性值、缓动函数。
- 支持播放、暂停、循环、逐帧前进/后退。
- 导出时合并为 CSS 或内联 JS。

### 7.3 资源管理

- 项目文件格式：`.animl_project`（实际为 JSON 文件）。
- 项目目录结构：

```
MyProject.animl/
├── project.json          # 项目元数据、渲染区配置、时间轴
├── index.html            # 当前正在编辑的 HTML
├── assets/               # 引用的本地资源
│   ├── images/
│   ├── fonts/
│   └── scripts/
└── thumbnails/
    └── preview.png
```

---

## 8. 数据模型

### 8.1 项目配置（ProjectConfig）

```json
{
  "name": "未命名项目",
  "version": "1.0.0",
  "canvas": {
    "width": 1920,
    "height": 1080,
    "backgroundColor": "#FFFFFF",
    "showGrid": true,
    "gridSize": 50
  },
  "viewport": {
    "scale": 1.0,
    "offsetX": 0.0,
    "offsetY": 0.0,
    "rotation": 0.0
  },
  "assets": [
    {"id": "img_001", "type": "image", "path": "assets/images/logo.png"}
  ],
  "timeline": {
    "duration": 5000,
    "tracks": []
  }
}
```

### 8.2 状态管理划分

- `CanvasController`：渲染区尺寸、背景、网格、坐标系显示。
- `ViewportController`：缩放、平移、旋转（仅在搜索模式下响应手势）。
- `WebViewController`：加载 HTML、注入 JS、与 DOM 通信。
- `ModeController`：当前模式（搜索/更改）、工具状态。
- `ProjectController`：项目文件读写、资源索引、导出编译。

---

## 9. 手势与事件路由

- 渲染区上层覆盖一个 `GestureDetector`。
- 搜索模式：返回 `true` 消费事件，WebView 不可交互。
- 更改模式：GestureDetector 只处理选框/空白区域手势；对元素本身的点击/拖动交给 WebView 内部 JS 处理。
- 通过 `IgnorePointer` 或 `HitTestBehavior.translucent` 灵活切换。

---

## 10. 导出/编译

### 10.1 编译目标

- 单个自包含 `.html` 文件。
- 可选 `.zip` 包（HTML + 资源）。

### 10.2 编译步骤

1. 读取 `index.html`。
2. 将外部 CSS 内联到 `<style>`。
3. 将外部 JS 内联到 `<script>`。
4. 将图片/字体转为 Data URI。
5. 将编辑器生成的动画关键帧追加到 `<style>`。
6. 清理开发期注入的 `_AniML` 脚本与选中框样式。
7. 输出最终文件。

---

## 11. 性能与兼容性

- WebView 启用硬件加速。
- 复杂动画优先使用 CSS `transform` 和 `opacity`，避免触发重排。
- 对 JS 调用做防抖/节流，降低 Bridge 开销。
- 支持 Android 8.0+（API 26+）。
- 屏幕尺寸适配：针对手机横屏优化，最小宽度 600dp。

---

## 12. 权限

| 权限 | 用途 |
|------|------|
| `INTERNET` | WebView 本地文件加载可能依赖（低版本 Android）。 |
| `READ_EXTERNAL_STORAGE` | 导入本地 HTML/资源。 |
| `WRITE_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE` | 导出动画到用户可见目录（视 Android 版本而定）。 |
| `WAKE_LOCK` | 长时间预览动画时保持屏幕常亮。 |

---

## 13. 项目目录结构

```
animl/
├── android/                       # Android 原生配置
├── ios/                           # iOS 配置（预留）
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   │   ├── project_config.dart
│   │   ├── asset_item.dart
│   │   └── timeline.dart
│   ├── controllers/
│   │   ├── canvas_controller.dart
│   │   ├── viewport_controller.dart
│   │   ├── webview_controller.dart
│   │   ├── mode_controller.dart
│   │   └── project_controller.dart
│   ├── ui/
│   │   ├── render_page.dart
│   │   ├── render_area.dart
│   │   ├── bottom_toolbar.dart
│   │   ├── property_panel.dart
│   │   └── layer_panel.dart
│   ├── services/
│   │   ├── html_importer.dart
│   │   ├── html_compiler.dart
│   │   └── storage_service.dart
│   └── utils/
│       ├── constants.dart
│       └── js_bridge.dart
├── assets/
│   └── icons/
│       ├── search.svg
│       └── edit.svg
├── pubspec.yaml
└── DESIGN.md
```

---

## 14. 开发里程碑

| 阶段 | 目标 |
|------|------|
| **MVP** | 横屏渲染页、渲染区尺寸/比例可调、HTML 导入、搜索/更改模式、坐标系、纯灰工具栏、导出 HTML。 |
| **V1.0** | 元素选中与属性编辑、图层管理、基础动画关键帧、项目文件保存/打开。 |
| **V1.5** | 资源库、缓动函数库、预览播放器、撤销/重做、深色主题。 |
| **V2.0** | 组件模板、协同编辑（可选）、云同步、APK 发布。 |

---

## 15. 风险与待确认事项

1. **坐标系原点**：本文假设为渲染区左上角。若后续需求改为中心原点，需调整网格、属性面板和导出逻辑。
2. **HTML 复杂度**：如果用户导入大量 DOM 节点或重型 JS，WebView 性能可能下降，需要增加复杂度提示。
3. **手势冲突**：搜索模式下的旋转与系统分屏手势可能冲突，需要测试并做边缘保护。
4. **资源打包**：文件夹/zip 导入与单一 HTML 导入的体验需统一。
5. **横屏锁定**：是否允许用户临时切换竖屏查看效果，还是严格锁定横屏？

---

## 16. 结语

AniML 的核心理念是「让 HTML 动画像画图一样简单」。通过 Flutter 提供的高性能 UI 与 WebView 的 HTML 渲染能力结合，用户在手机上即可导入、编辑、预览并导出独立的 HTML 动画文件。
