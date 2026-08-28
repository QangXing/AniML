/// 应用内置的示例 HTML（无导入时直接可用）。
const String kDefaultHtml = '''
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { margin:0; box-sizing:border-box; }
  html, body { width:100%; height:100%; background:#eef3fb; font-family:-apple-system,'Helvetica Neue',Arial,sans-serif; }
  body { overflow:hidden; }
  .deck { width:100%; height:100vh; display:grid; grid-template-columns:repeat(auto-fit,minmax(160px,1fr)); gap:14px; padding:18px; align-content:start; }
  .card { background:linear-gradient(160deg,#ffffff,#f6f9ff); border-radius:16px; padding:16px 18px;
          box-shadow:0 6px 18px rgba(90,120,220,.10); border:1px solid #e6edfb; }
  .card h3 { font-size:15px; color:#2f3b57; }
  .card p  { font-size:12px; color:#7b8aa6; margin-top:6px; line-height:1.5; }
  .hero { grid-column:1/-1; background:linear-gradient(120deg,#5b7cfa,#8a5bfa); color:#fff; border:none; }
  .hero h2 { font-size:22px; font-weight:700; }
  .hero p  { color:rgba(255,255,255,.85); }
  .dot { width:10px;height:10px;border-radius:50%;background:#5b7cfa; animation:pulse 1s infinite; display:inline-block; margin-right:6px; }
  @keyframes pulse { 0%,100%{transform:scale(1);opacity:1;} 50%{transform:scale(1.4);opacity:.5;} }
</style>
</head>
<body>
  <div class="deck">
    <div class="card hero">
      <h2>HTML Render Studio</h2>
      <p><span class="dot"></span>示例页面 · 可在左右切换搜索 / 更改 / 拍摄三种模式</p>
    </div>
    <div class="card"><h3>预览窗口</h3><p>中间浅边框即为“渲染区”，页面会在窗口内外同时绘制。</p></div>
    <div class="card"><h3>自由变换</h3><p>搜索模式下拖动平移、双指缩放与旋转。</p></div>
    <div class="card"><h3>像素输出</h3><p>更改模式可调整渲染区长宽、比例与输出像素。</p></div>
    <div class="card"><h3>录制成片</h3><p>拍摄模式按设定时长抓取实时像素，合成为 MP4。</p></div>
    <div class="card"><h3>Flutter UI</h3><p>毛玻璃、白色简洁风，移动端横屏操作。</p></div>
    <div class="card"><h3>可以旋转</h3><p>拖动旋转滑杆即可任意旋转页面视图。</p></div>
  </div>
</body>
</html>
''';

/// 可选择的输出分辨率预设。
const List<({String label, int w, int h})> kOutputPresets = [
  (label: '1920 × 1080 (全高清)', w: 1920, h: 1080),
  (label: '1280 × 720 (高清)', w: 1280, h: 720),
  (label: '1080 × 1920 (竖屏)', w: 1080, h: 1920),
  (label: '1024 × 1024 (方形)', w: 1024, h: 1024),
  (label: '3840 × 2160 (4K)', w: 3840, h: 2160),
];

/// 方向基准预设（渲染区比例）。
const List<({String label, int w, int h})> kAspectPresets = [
  (label: '横屏 16:9', w: 16, h: 9),
  (label: '竖屏 9:16', w: 9, h: 16),
  (label: '方形 1:1', w: 1, h: 1),
  (label: '平板 4:3', w: 4, h: 3),
  (label: '超宽 21:9', w: 21, h: 9),
];