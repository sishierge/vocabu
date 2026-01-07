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
using System.Windows.Media.Animation;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DanmuOverlay
{
    public partial class MainWindow : Window
    {
        private TcpListener? _tcpListener;
        private TcpClient? _client;
        private NetworkStream? _stream;
        private CancellationTokenSource? _cts;
        private bool _isRunning = true;
        private bool _isPaused = false;

        private List<WordItem> _words = new();
        private int _currentWordIndex = 0;
        private Random _random = new();

        // 轨道系统 - 防止弹幕重叠
        private Dictionary<int, DateTime> _trackOccupancy = new(); // 轨道号 -> 释放时间
        private const double TRACK_HEIGHT = 70; // 每个轨道的高度（像素）
        private const double TRACK_GAP = 10; // 轨道间隙

        // 配置
        private double _areaTop = 5;
        private double _areaHeight = 60;
        private double _speed = 0.6;
        private double _fontSize = 20;
        private int _spawnInterval = 5;
        private bool _showTranslation = true;
        private Color _wordColor = Colors.White;
        private Color _transColor = Color.FromRgb(255, 215, 0);
        private Color _bgColor = Color.FromRgb(91, 108, 255);
        private double _opacity = 0.85;
        private string _examplePosition = "bottom-center";
        private double _exampleOffsetY = 80;

        public MainWindow()
        {
            InitializeComponent();
            Loaded += MainWindow_Loaded;
            Closing += MainWindow_Closing;

            // 设置选择性点击穿透 - 只有弹幕元素可点击，透明区域穿透
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
        /// 透明区域穿透点击，弹幕元素可以点击
        /// </summary>
        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            const int WM_NCHITTEST = 0x0084;
            const int HTTRANSPARENT = -1;
            const int HTCLIENT = 1;
            
            if (msg == WM_NCHITTEST)
            {
                // 获取鼠标位置
                int x = (short)(lParam.ToInt32() & 0xFFFF);
                int y = (short)(lParam.ToInt32() >> 16);
                var point = PointFromScreen(new Point(x, y));
                
                // 检查是否点击在可交互元素上
                var hitElement = MainGrid.InputHitTest(point) as DependencyObject;
                
                // 向上遍历可视树，检查是否有Border（弹幕容器）
                while (hitElement != null)
                {
                    if (hitElement is Border border && border != ExamplePanel && border != MasteredToast)
                    {
                        // 点击在弹幕上 - 允许交互
                        handled = true;
                        return new IntPtr(HTCLIENT);
                    }
                    if (hitElement == ExamplePanel || hitElement == MasteredToast)
                    {
                        // 点击在例句面板或提示框上 - 允许交互
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
            // 启动TCP服务器
            StartTcpServer();

            // 启动弹幕生成循环
            StartDanmuLoop();
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
                _tcpListener = new TcpListener(IPAddress.Loopback, 9527);
                _tcpListener.Start();
                Console.WriteLine("TCP Server started on port 9527");

                _cts = new CancellationTokenSource();

                while (_isRunning)
                {
                    try
                    {
                        _client = await _tcpListener.AcceptTcpClientAsync();
                        _stream = _client.GetStream();
                        Console.WriteLine("Client connected");

                        // 处理客户端消息
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

                    // 按换行分割处理多条命令
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
                        case "CONFIG":
                            ApplyConfig(obj["config"] as JObject);
                            break;

                        case "WORDS":
                            LoadWords(obj["words"] as JArray);
                            break;

                        case "PAUSE":
                            _isPaused = true;
                            break;

                        case "RESUME":
                            _isPaused = false;
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

        private void ApplyConfig(JObject? config)
        {
            if (config == null) return;

            try
            {
                if (config["areaTop"] != null) _areaTop = config["areaTop"]!.Value<double>();
                if (config["areaHeight"] != null) _areaHeight = config["areaHeight"]!.Value<double>();
                if (config["speed"] != null) _speed = config["speed"]!.Value<double>();
                if (config["fontSize"] != null) _fontSize = config["fontSize"]!.Value<double>();
                if (config["interval"] != null) _spawnInterval = config["interval"]!.Value<int>();
                if (config["showTranslation"] != null) _showTranslation = config["showTranslation"]!.Value<bool>();
                if (config["opacity"] != null) _opacity = config["opacity"]!.Value<double>();
                if (config["examplePosition"] != null) _examplePosition = config["examplePosition"]!.ToString();
                if (config["exampleOffsetY"] != null) _exampleOffsetY = config["exampleOffsetY"]!.Value<double>();

                // 解析颜色
                if (config["wordColor"] != null) _wordColor = ParseColor(config["wordColor"]!.ToString());
                if (config["transColor"] != null) _transColor = ParseColor(config["transColor"]!.ToString());
                if (config["bgColor"] != null) _bgColor = ParseColor(config["bgColor"]!.ToString());

                UpdateExamplePanelPosition();
                Console.WriteLine($"Config applied: speed={_speed}, fontSize={_fontSize}, interval={_spawnInterval}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ApplyConfig error: {ex.Message}");
            }
        }

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
                else if (hex.Length == 8)
                {
                    return Color.FromArgb(
                        Convert.ToByte(hex.Substring(0, 2), 16),
                        Convert.ToByte(hex.Substring(2, 2), 16),
                        Convert.ToByte(hex.Substring(4, 2), 16),
                        Convert.ToByte(hex.Substring(6, 2), 16));
                }
            }
            catch { }
            return Colors.White;
        }

        private void LoadWords(JArray? wordsArray)
        {
            if (wordsArray == null) return;

            try
            {
                _words.Clear();
                foreach (var item in wordsArray)
                {
                    _words.Add(new WordItem
                    {
                        Word = item["Word"]?.ToString() ?? "",
                        Translation = item["Translation"]?.ToString() ?? "",
                        Example = item["Example"]?.ToString() ?? "",
                        ExampleTrans = item["ExampleTrans"]?.ToString() ?? ""
                    });
                }

                // 打乱顺序
                ShuffleWords();
                _currentWordIndex = 0;

                Console.WriteLine($"Loaded {_words.Count} words");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"LoadWords error: {ex.Message}");
            }
        }

        private void ShuffleWords()
        {
            for (int i = _words.Count - 1; i > 0; i--)
            {
                int j = _random.Next(i + 1);
                (_words[i], _words[j]) = (_words[j], _words[i]);
            }
        }

        /// <summary>
        /// 发送消息到 Flutter 客户端
        /// </summary>
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

        #region 弹幕逻辑

        private async void StartDanmuLoop()
        {
            while (_isRunning)
            {
                if (!_isPaused && _words.Count > 0)
                {
                    Dispatcher.Invoke(() =>
                    {
                        SpawnDanmu(_words[_currentWordIndex]);
                        _currentWordIndex = (_currentWordIndex + 1) % _words.Count;

                        // 如果循环完一轮，重新打乱
                        if (_currentWordIndex == 0)
                        {
                            ShuffleWords();
                        }
                    });
                }

                await Task.Delay(_spawnInterval * 1000);
            }
        }

        private void SpawnDanmu(WordItem word)
        {
            var screenWidth = SystemParameters.PrimaryScreenWidth;
            var screenHeight = SystemParameters.PrimaryScreenHeight;

            // 计算弹幕区域
            var topY = screenHeight * _areaTop / 100;
            var areaH = screenHeight * _areaHeight / 100;

            // 计算可用轨道数
            var trackHeight = TRACK_HEIGHT + TRACK_GAP;
            var numTracks = (int)(areaH / trackHeight);
            if (numTracks < 1) numTracks = 1;

            // 查找可用轨道
            var availableTrack = FindAvailableTrack(numTracks);
            if (availableTrack < 0)
            {
                // 没有可用轨道，跳过这个弹幕
                return;
            }

            // 计算Y位置
            var y = topY + availableTrack * trackHeight;

            // 创建弹幕控件
            var danmuBorder = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb((byte)(_opacity * 255), _bgColor.R, _bgColor.G, _bgColor.B)),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(16, 10, 16, 10),
                Cursor = Cursors.Hand,
                Tag = word // 保存单词数据用于点击事件
            };

            // 添加阴影效果
            danmuBorder.Effect = new System.Windows.Media.Effects.DropShadowEffect
            {
                ShadowDepth = 2,
                BlurRadius = 15,
                Opacity = 0.4,
                Color = _bgColor
            };

            var stack = new StackPanel();

            // 单词
            var wordText = new TextBlock
            {
                Text = word.Word,
                Foreground = new SolidColorBrush(_wordColor),
                FontSize = _fontSize,
                FontWeight = FontWeights.Bold,
                FontFamily = new FontFamily("Segoe UI, Microsoft YaHei UI")
            };
            stack.Children.Add(wordText);

            // 翻译
            if (_showTranslation && !string.IsNullOrEmpty(word.Translation))
            {
                var transText = new TextBlock
                {
                    Text = word.Translation,
                    Foreground = new SolidColorBrush(_transColor),
                    FontSize = _fontSize - 3,
                    Margin = new Thickness(0, 4, 0, 0),
                    FontFamily = new FontFamily("Microsoft YaHei UI")
                };
                stack.Children.Add(transText);
            }

            danmuBorder.Child = stack;

            // 点击事件 - 显示例句
            danmuBorder.MouseLeftButtonDown += (s, e) =>
            {
                ShowExample(word);
                e.Handled = true;
            };

            // 双击事件 - 标记为已掌握
            danmuBorder.MouseLeftButtonDown += (s, e) =>
            {
                if (e.ClickCount == 2)
                {
                    MarkAsMastered(word);
                    e.Handled = true;
                }
            };

            // 添加到画布
            Canvas.SetLeft(danmuBorder, screenWidth);
            Canvas.SetTop(danmuBorder, y);
            DanmuCanvas.Children.Add(danmuBorder);

            // 测量宽度
            danmuBorder.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
            var width = danmuBorder.DesiredSize.Width;

            // 计算轨道释放时间（当弹幕右边缘离开屏幕右边缘时，新弹幕可以进入同一轨道）
            var clearTime = (width + 50) / (100 * _speed); // 额外50像素间距
            _trackOccupancy[availableTrack] = DateTime.Now.AddSeconds(clearTime);

            // 动画 - 从右向左移动
            var duration = TimeSpan.FromSeconds((screenWidth + width) / (100 * _speed));
            var animation = new DoubleAnimation
            {
                From = screenWidth,
                To = -width,
                Duration = duration,
                EasingFunction = null // Linear movement
            };

            // 捕获轨道号用于清理
            var trackToRelease = availableTrack;
            animation.Completed += (s, e) =>
            {
                DanmuCanvas.Children.Remove(danmuBorder);
            };

            danmuBorder.BeginAnimation(Canvas.LeftProperty, animation);
        }

        /// <summary>
        /// 查找可用轨道
        /// </summary>
        private int FindAvailableTrack(int numTracks)
        {
            var now = DateTime.Now;
            var availableTracks = new List<int>();

            // 清理过期的轨道占用记录，同时收集可用轨道
            var expiredTracks = new List<int>();
            foreach (var kvp in _trackOccupancy)
            {
                if (kvp.Value < now)
                {
                    expiredTracks.Add(kvp.Key);
                }
            }
            foreach (var track in expiredTracks)
            {
                _trackOccupancy.Remove(track);
            }

            // 查找未被占用的轨道
            for (int i = 0; i < numTracks; i++)
            {
                if (!_trackOccupancy.ContainsKey(i) || _trackOccupancy[i] < now)
                {
                    availableTracks.Add(i);
                }
            }

            if (availableTracks.Count == 0)
            {
                return -1; // 没有可用轨道
            }

            // 随机选择一个可用轨道
            return availableTracks[_random.Next(availableTracks.Count)];
        }

        private void ShowExample(WordItem word)
        {
            // 显示单词信息，即使没有例句
            if (string.IsNullOrEmpty(word.Example))
            {
                // 没有例句时，显示单词和翻译
                ExampleEnglish.Text = $"📖 {word.Word}";
                ExampleChinese.Text = word.Translation;
            }
            else
            {
                ExampleEnglish.Text = word.Example;
                ExampleChinese.Text = string.IsNullOrEmpty(word.ExampleTrans)
                    ? word.Translation
                    : word.ExampleTrans;
            }

            ExamplePanel.Visibility = Visibility.Visible;

            // 5秒后自动隐藏
            Task.Delay(5000).ContinueWith(_ =>
            {
                Dispatcher.Invoke(() =>
                {
                    ExamplePanel.Visibility = Visibility.Collapsed;
                });
            });
        }

        private void ExamplePanel_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            ExamplePanel.Visibility = Visibility.Collapsed;
        }

        /// <summary>
        /// 双击标记为已掌握 - 发送消息到 Flutter
        /// </summary>
        private void MarkAsMastered(WordItem word)
        {
            // 发送到Flutter
            SendToFlutter(new
            {
                type = "WORD_MASTERED",
                word = word.Word
            });

            // 显示提示
            MasteredWord.Text = word.Word;
            MasteredToast.Visibility = Visibility.Visible;

            // 淡入动画
            var fadeIn = new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(200));
            MasteredToast.BeginAnimation(OpacityProperty, fadeIn);

            // 2秒后隐藏
            Task.Delay(2000).ContinueWith(_ =>
            {
                Dispatcher.Invoke(() =>
                {
                    var fadeOut = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(300));
                    fadeOut.Completed += (s, e) => MasteredToast.Visibility = Visibility.Collapsed;
                    MasteredToast.BeginAnimation(OpacityProperty, fadeOut);
                });
            });

            // 从列表中移除该单词
            _words.RemoveAll(w => w.Word == word.Word);

            Console.WriteLine($"Marked as mastered: {word.Word}");
        }

        private void UpdateExamplePanelPosition()
        {
            switch (_examplePosition)
            {
                case "top-center":
                    ExamplePanel.VerticalAlignment = VerticalAlignment.Top;
                    ExamplePanel.HorizontalAlignment = HorizontalAlignment.Center;
                    ExamplePanel.Margin = new Thickness(0, _exampleOffsetY, 0, 0);
                    break;
                case "bottom-left":
                    ExamplePanel.VerticalAlignment = VerticalAlignment.Bottom;
                    ExamplePanel.HorizontalAlignment = HorizontalAlignment.Left;
                    ExamplePanel.Margin = new Thickness(50, 0, 0, _exampleOffsetY);
                    break;
                case "bottom-right":
                    ExamplePanel.VerticalAlignment = VerticalAlignment.Bottom;
                    ExamplePanel.HorizontalAlignment = HorizontalAlignment.Right;
                    ExamplePanel.Margin = new Thickness(0, 0, 50, _exampleOffsetY);
                    break;
                default: // bottom-center
                    ExamplePanel.VerticalAlignment = VerticalAlignment.Bottom;
                    ExamplePanel.HorizontalAlignment = HorizontalAlignment.Center;
                    ExamplePanel.Margin = new Thickness(0, 0, 0, _exampleOffsetY);
                    break;
            }
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
            // WS_EX_TRANSPARENT 会让整个窗口穿透鼠标事件，导致无法点击弹幕显示例句
            SetWindowLong(hwnd, GWL_EXSTYLE, extendedStyle | WS_EX_LAYERED);
        }

        #endregion
    }

    /// <summary>
    /// 单词数据模型
    /// </summary>
    public class WordItem
    {
        public string Word { get; set; } = "";
        public string Translation { get; set; } = "";
        public string Example { get; set; } = "";
        public string ExampleTrans { get; set; } = "";
    }
}
