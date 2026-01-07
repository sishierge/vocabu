using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace StickyOverlay
{
    public partial class MainWindow : Window
    {
        private TcpListener? _tcpListener;
        private TcpClient? _client;
        private NetworkStream? _stream;
        private CancellationTokenSource? _cts;
        private bool _isRunning = true;

        private readonly List<StickerControl> _stickers = new();

        // 贴纸样式预设
        private static readonly List<StickerStyle> _styles = new()
        {
            new StickerStyle { BgColor = "#FFE066", TextColor = "#333333", BorderColor = "#FFD700" }, // 黄色便签
            new StickerStyle { BgColor = "#7EC8E3", TextColor = "#FFFFFF", BorderColor = "#5BA8C8" }, // 蓝色
            new StickerStyle { BgColor = "#98D8AA", TextColor = "#FFFFFF", BorderColor = "#78B89A" }, // 绿色
            new StickerStyle { BgColor = "#FF9AA2", TextColor = "#FFFFFF", BorderColor = "#DF7A82" }, // 粉色
            new StickerStyle { BgColor = "#B19CD9", TextColor = "#FFFFFF", BorderColor = "#917CB9" }, // 紫色
        };

        public MainWindow()
        {
            InitializeComponent();
            Loaded += MainWindow_Loaded;
            Closing += MainWindow_Closing;

            // 设置选择性点击穿透 - 只有贴纸可交互，透明区域穿透
            this.SourceInitialized += (s, e) =>
            {
                var helper = new System.Windows.Interop.WindowInteropHelper(this);
                var source = System.Windows.Interop.HwndSource.FromHwnd(helper.Handle);
                source?.AddHook(WndProc);
                
                // 只设置 WS_EX_LAYERED（不设置 WS_EX_TRANSPARENT）
                var extendedStyle = GetWindowLong(helper.Handle, GWL_EXSTYLE);
                SetWindowLong(helper.Handle, GWL_EXSTYLE, extendedStyle | WS_EX_LAYERED);
            };
        }

        /// <summary>
        /// 窗口消息处理 - 实现选择性点击穿透
        /// </summary>
        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            const int WM_NCHITTEST = 0x0084;
            const int HTTRANSPARENT = -1;
            const int HTCLIENT = 1;
            
            if (msg == WM_NCHITTEST)
            {
                int x = (short)(lParam.ToInt32() & 0xFFFF);
                int y = (short)(lParam.ToInt32() >> 16);
                var point = PointFromScreen(new Point(x, y));
                
                // 检查是否点击在贴纸上
                var hitElement = StickyCanvas.InputHitTest(point) as DependencyObject;
                
                while (hitElement != null)
                {
                    if (hitElement is Border)
                    {
                        // 点击在贴纸上 - 允许交互
                        handled = true;
                        return new IntPtr(HTCLIENT);
                    }
                    hitElement = VisualTreeHelper.GetParent(hitElement);
                }
                
                // 透明区域 - 穿透点击
                handled = true;
                return new IntPtr(HTTRANSPARENT);
            }
            return IntPtr.Zero;
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            StartTcpServer();
        }

        private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
        {
            _isRunning = false;
            _cts?.Cancel();
            _stream?.Close();
            _client?.Close();
            _tcpListener?.Stop();
        }

        #region TCP 通信

        private async void StartTcpServer()
        {
            try
            {
                _tcpListener = new TcpListener(IPAddress.Loopback, 9529);
                _tcpListener.Start();
                Console.WriteLine("Sticky TCP Server started on port 9529");

                _cts = new CancellationTokenSource();

                while (_isRunning)
                {
                    try
                    {
                        _client = await _tcpListener.AcceptTcpClientAsync();
                        _stream = _client.GetStream();
                        Console.WriteLine("Client connected");

                        await HandleClientAsync(_stream, _cts.Token);
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Client error: {ex.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"TCP Server error: {ex.Message}");
            }
        }

        private async Task HandleClientAsync(NetworkStream stream, CancellationToken ct)
        {
            var buffer = new byte[65536];
            var messageBuffer = new StringBuilder();

            while (_isRunning && !ct.IsCancellationRequested)
            {
                try
                {
                    int bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, ct);
                    if (bytesRead == 0) break;

                    messageBuffer.Append(Encoding.UTF8.GetString(buffer, 0, bytesRead));

                    string data = messageBuffer.ToString();
                    int newlineIndex;
                    while ((newlineIndex = data.IndexOf('\n')) >= 0)
                    {
                        string jsonLine = data.Substring(0, newlineIndex).Trim();
                        data = data.Substring(newlineIndex + 1);

                        if (!string.IsNullOrEmpty(jsonLine))
                        {
                            ProcessCommand(jsonLine);
                        }
                    }
                    messageBuffer.Clear();
                    messageBuffer.Append(data);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Read error: {ex.Message}");
                    break;
                }
            }
        }

        private void ProcessCommand(string json)
        {
            try
            {
                var obj = JObject.Parse(json);
                var cmd = obj["cmd"]?.ToString();

                Dispatcher.Invoke(() =>
                {
                    switch (cmd)
                    {
                        case "ADD_STICKER":
                            AddSticker(obj["sticker"] as JObject);
                            break;

                        case "LOAD_SPACE":
                            LoadSpace(obj["stickers"] as JArray);
                            break;

                        case "CLEAR":
                            ClearStickers();
                            break;

                        case "STOP":
                            _isRunning = false;
                            Application.Current.Shutdown();
                            break;
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ProcessCommand error: {ex.Message}");
            }
        }

        #endregion

        #region 贴纸操作

        private void AddSticker(JObject? stickerData)
        {
            if (stickerData == null) return;

            var word = stickerData["word"]?.ToString() ?? "";
            var phonetic = stickerData["phonetic"]?.ToString() ?? "";
            var translation = stickerData["translation"]?.ToString() ?? "";
            var x = stickerData["x"]?.Value<double>() ?? 100;
            var y = stickerData["y"]?.Value<double>() ?? 100;
            var styleIndex = stickerData["styleIndex"]?.Value<int>() ?? 0;

            CreateSticker(word, phonetic, translation, x, y, styleIndex);
        }

        private void LoadSpace(JArray? stickersArray)
        {
            if (stickersArray == null) return;

            ClearStickers();

            foreach (var item in stickersArray)
            {
                AddSticker(item as JObject);
            }
        }

        private void ClearStickers()
        {
            foreach (var sticker in _stickers)
            {
                StickyCanvas.Children.Remove(sticker.Border);
            }
            _stickers.Clear();
        }

        private void CreateSticker(string word, string phonetic, string translation, double x, double y, int styleIndex)
        {
            var style = _styles[styleIndex % _styles.Count];
            var bgColor = ParseColor(style.BgColor);
            var textColor = ParseColor(style.TextColor);
            var borderColor = ParseColor(style.BorderColor);

            var border = new Border
            {
                Background = new SolidColorBrush(bgColor),
                BorderBrush = new SolidColorBrush(borderColor),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(12, 10, 12, 10),
                Cursor = Cursors.SizeAll,
                MinWidth = 120,
                Effect = new DropShadowEffect
                {
                    ShadowDepth = 3,
                    BlurRadius = 10,
                    Opacity = 0.3,
                    Color = Colors.Black
                }
            };

            var stack = new StackPanel();

            // 单词
            var wordText = new TextBlock
            {
                Text = word,
                Foreground = new SolidColorBrush(textColor),
                FontSize = 16,
                FontWeight = FontWeights.Bold,
                FontFamily = new FontFamily("Segoe UI, Microsoft YaHei UI")
            };
            stack.Children.Add(wordText);

            // 音标
            if (!string.IsNullOrEmpty(phonetic))
            {
                var phoneticText = new TextBlock
                {
                    Text = phonetic,
                    Foreground = new SolidColorBrush(Color.FromArgb(180, textColor.R, textColor.G, textColor.B)),
                    FontSize = 12,
                    Margin = new Thickness(0, 2, 0, 0),
                    FontFamily = new FontFamily("Segoe UI")
                };
                stack.Children.Add(phoneticText);
            }

            // 翻译
            var transText = new TextBlock
            {
                Text = translation,
                Foreground = new SolidColorBrush(Color.FromArgb(220, textColor.R, textColor.G, textColor.B)),
                FontSize = 13,
                Margin = new Thickness(0, 4, 0, 0),
                TextWrapping = TextWrapping.Wrap,
                MaxWidth = 200,
                FontFamily = new FontFamily("Microsoft YaHei UI")
            };
            stack.Children.Add(transText);

            border.Child = stack;

            // 拖拽功能
            var sticker = new StickerControl { Border = border, Word = word };
            bool isDragging = false;
            Point dragStart = new Point();

            border.MouseLeftButtonDown += (s, e) =>
            {
                isDragging = true;
                dragStart = e.GetPosition(StickyCanvas);
                border.CaptureMouse();
                e.Handled = true;
            };

            border.MouseMove += (s, e) =>
            {
                if (isDragging)
                {
                    var pos = e.GetPosition(StickyCanvas);
                    var left = Canvas.GetLeft(border) + (pos.X - dragStart.X);
                    var top = Canvas.GetTop(border) + (pos.Y - dragStart.Y);
                    Canvas.SetLeft(border, left);
                    Canvas.SetTop(border, top);
                    dragStart = pos;
                }
            };

            border.MouseLeftButtonUp += (s, e) =>
            {
                isDragging = false;
                border.ReleaseMouseCapture();

                // 通知 Flutter 位置更新
                SendPositionUpdate(sticker.Word, Canvas.GetLeft(border), Canvas.GetTop(border));
            };

            // 右键删除
            border.MouseRightButtonDown += (s, e) =>
            {
                StickyCanvas.Children.Remove(border);
                _stickers.Remove(sticker);
                SendStickerRemoved(sticker.Word);
                e.Handled = true;
            };

            Canvas.SetLeft(border, x);
            Canvas.SetTop(border, y);
            StickyCanvas.Children.Add(border);
            _stickers.Add(sticker);
        }

        private void SendPositionUpdate(string word, double x, double y)
        {
            SendToFlutter(new
            {
                type = "POSITION_UPDATE",
                word = word,
                x = x,
                y = y
            });
        }

        private void SendStickerRemoved(string word)
        {
            SendToFlutter(new
            {
                type = "STICKER_REMOVED",
                word = word
            });
        }

        private void SendToFlutter(object message)
        {
            try
            {
                if (_stream != null && _stream.CanWrite)
                {
                    var json = JsonConvert.SerializeObject(message);
                    var bytes = Encoding.UTF8.GetBytes(json + "\n");
                    _stream.Write(bytes, 0, bytes.Length);
                    _stream.Flush();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"SendToFlutter error: {ex.Message}");
            }
        }

        #endregion

        #region 辅助方法

        private Color ParseColor(string hex)
        {
            try
            {
                hex = hex.TrimStart('#');
                if (hex.Length == 6)
                {
                    return Color.FromRgb(
                        Convert.ToByte(hex.Substring(0, 2), 16),
                        Convert.ToByte(hex.Substring(2, 2), 16),
                        Convert.ToByte(hex.Substring(4, 2), 16));
                }
            }
            catch { }
            return Colors.Yellow;
        }

        #endregion

        #region 窗口穿透

        private const int WS_EX_TRANSPARENT = 0x00000020;
        private const int WS_EX_LAYERED = 0x00080000;
        private const int GWL_EXSTYLE = -20;

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

        private void SetWindowExTransparent(IntPtr hwnd)
        {
            var extendedStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
            // 只设置 WS_EX_LAYERED，不设置 WS_EX_TRANSPARENT
            // WS_EX_TRANSPARENT 会让整个窗口穿透鼠标事件，导致贴纸无法拖动
            SetWindowLong(hwnd, GWL_EXSTYLE, extendedStyle | WS_EX_LAYERED);
        }

        #endregion
    }

    class StickerControl
    {
        public Border Border { get; set; } = null!;
        public string Word { get; set; } = "";
    }

    class StickerStyle
    {
        public string BgColor { get; set; } = "#FFE066";
        public string TextColor { get; set; } = "#333333";
        public string BorderColor { get; set; } = "#FFD700";
    }
}
