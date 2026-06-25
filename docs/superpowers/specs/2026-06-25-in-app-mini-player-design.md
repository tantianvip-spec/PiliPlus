# In-App Mini Player (应用内小窗播放器)

## 概述

为 PiliPlus 添加一个应用内浮动小窗播放器功能。当用户在 App 内从视频详情页导航到其他页面时，视频以小窗形式悬浮播放，类似于 YouTube 的应用内画中画。此功能仅在 App 内部生效，不涉及系统级 PiP。

## 触发方式

1. **自动触发**：用户在视频详情页（`/videoV` 或 `/liveRoom`）播放视频后，通过返回手势或导航到其他页面时，小窗自动出现并继续播放
2. **手动触发**：在播放器控制栏中增加一个"最小化"按钮，用户点击后进入小窗模式并返回上一页

## 小窗操作

- 播放/暂停
- 关闭小窗（停止播放并销毁）
- 点击小窗主体区域展开回到视频详情页
- 拖拽到屏幕任意位置
- 精简进度条

## 架构设计

### 核心原则

**不需要第二个 Player 实例。** `PlPlayerController` 已经是全局单例，其 `VideoController`（media-kit 渲染层）在小窗和全尺寸页面之间切换。由于路由切换时旧页面的 widget 树会被销毁，不会出现两个 VideoController 同时渲染的冲突。

### 组件

#### MiniPlayerController（新增）

`lib/plugin/pl_player/mini_player/controller.dart`

一个 `GetxController`，管理小窗的显示状态和位置：

- `RxBool isVisible` — 小窗是否显示
- `Rx<Offset> position` — 小窗在屏幕上的偏移位置（用于拖拽）
- `void show()` — 显示小窗
- `void hide()` — 隐藏小窗
- `void toggle()` — 切换显示状态
- 内部监听 `PlPlayerController._instance` 的播放状态
- 内部监听路由变化，自动控制显示/隐藏

**路由监听逻辑：**

```
离开 /videoV 或 /liveRoom → 如果正在播放 → show()
回到 /videoV 或 /liveRoom → hide()
关闭小窗 → 调用 PlPlayerController.dispose() + hide()
```

#### MiniPlayerWidget（新增）

`lib/plugin/pl_player/mini_player/view.dart`

浮动 widget，包含：

- **容器**：`ClipRRect`（圆角 12px）+ `Material`（elevation 8）
- **视频画面**：`SimpleVideo(controller: plPlayerController.videoController!)` 直接复用播放器渲染
- **控制条覆盖层**：底部半透明黑色条
  - 播放/暂停按钮（左侧）
  - 精简进度条（中间，拇指隐藏，只显示进度线）
  - 关闭按钮（右侧 X 图标）
- **拖拽**：`GestureDetector.onPanUpdate` 实现自由拖动
- **点击展开**：点击视频区域触发 `Get.toNamed('/videoV')` 回到视频详情页
- **出现动画**：从底部滑入 + 淡入（300ms）
- **消失动画**：滑出到底部 + 淡出（200ms）

**尺寸：**

- 默认宽度：屏幕宽度的 35%
- 高度按 16:9 比例计算
- 最小宽度：120px
- 默认位置：右下角，距底部 16px、右侧 16px
- 拖拽后停留在用户放置的位置

### 集成点

#### 1. MainApp.build() — 叠加小窗层

`lib/pages/main/view.dart`

在 `MainApp.build()` 的 Scaffold 外部包裹 `Stack`，叠加小窗：

```dart
child = Stack(
  children: [
    child,  // 原有的 Scaffold（包含导航栏 + PageView）
    Obx(
      () => miniPlayerController.isVisible.value
          ? MiniPlayerWidget()
          : const SizedBox.shrink(),
    ),
  ],
);
```

在 `_MainAppState.initState()` 中初始化 `MiniPlayerController`。

#### 2. 视频详情页路由离开时触发

`lib/pages/video/view.dart`

在 `_VideoDetailPageVState.didPushNext()` 中增加逻辑：当播放器正在播放时，调用 `MiniPlayerController.instance.show()`。

#### 3. 播放器控制栏增加最小化按钮

`lib/plugin/pl_player/view/view.dart` 或 `header_control.dart`

在底部控制栏右侧增加一个最小化按钮（`Icons.picture_in_picture_alt`），点击后：

1. 调用 `MiniPlayerController.instance.show()`
2. 调用 `Get.back()` 返回上一页

#### 4. 小窗关闭时处理播放器销毁

`MiniPlayerController.hide()` 或关闭按钮回调中：

```dart
PlPlayerController.instance?.dispose();
```

### 数据流

```
用户导航离开视频页
        │
        ▼
VideoDetailPageV.didPushNext()
        │
        ▼
MiniPlayerController.show()
        │
        ▼
MiniPlayerWidget 显示 (AnimatedSlide 从底部滑入)
        │
        ▼
SimpleVideo 复用 PlPlayerController.videoController
        │
        ▼
用户操作小窗：
  ├─ 点击视频区域 → Get.toNamed('/videoV') → MiniPlayerController.hide()
  ├─ 播放/暂停 → PlPlayerController.play()/pause()
  ├─ 拖动进度条 → PlPlayerController.seekTo()
  ├─ 拖拽位置 → 更新 MiniPlayerController.position
  └─ 关闭 → PlPlayerController.dispose() + MiniPlayerController.hide()
```

## 平台适配

- **Android/iOS**：使用 Flutter widget 层实现，不涉及平台原生代码
- **桌面端（Windows/Linux/macOS）**：同样生效，但桌面端已有独立的桌面 PiP 功能（`enterDesktopPip`），小窗作为补充
- **Pad**：小窗尺寸可适当增大（屏幕宽度的 30%）

## 边界情况

1. **无视频播放时**：MiniPlayerController 不显示
2. **视频播放完毕**：小窗保持显示，显示"已播放完毕"状态或自动关闭
3. **多个页面快速导航**：通过防抖避免小窗闪烁
4. **小窗中视频出错**：显示错误提示，保留小窗
5. **回到视频页后再次离开**：小窗重新出现，位置保持上一次拖拽的位置
6. **直接关闭 App**：无需特殊处理，App 销毁时小窗自然消失
7. **竖屏/横屏切换**：小窗位置自动适配，保持在可视区域内

## 文件清单

| 文件 | 操作 | 说明 |
|---|---|---|
| `lib/plugin/pl_player/mini_player/controller.dart` | 新增 | MiniPlayerController |
| `lib/plugin/pl_player/mini_player/view.dart` | 新增 | MiniPlayerWidget |
| `lib/pages/main/view.dart` | 修改 | 在 MainApp 中叠加小窗 |
| `lib/pages/video/view.dart` | 修改 | 路由离开时触发小窗显示 |
| `lib/plugin/pl_player/view/view.dart` | 修改 | 控制栏增加最小化按钮 |

## 后续扩展

- 可配置的小窗尺寸（用户设置）
- 小窗圆角可配置
- 小窗贴边自动吸附
