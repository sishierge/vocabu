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
using System.Windows.Shapes;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace CarouselOverlay
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
        private int _currentIndex = 0;
        private int _intervalSeconds = 5;
        private int _styleIndex = 0;

        // 样式颜色数组 - 与 Flutter 端保持一致
        private static readonly Color[] StyleColors = new[]
        {
            Color.FromRgb(91, 108, 255),   // 0: 蓝紫 #5B6CFF
            Color.FromRgb(46, 125, 50),    // 1: 深绿 #2E7D32
            Color.FromRgb(233, 30, 99),    // 2: 粉红 #E91E63
            Color.FromRgb(0, 188, 212),    // 3: 青色 #00BCD4
            Color.FromRgb(255, 152, 0),    // 4: 橙色 #FF9800
            Color.FromRgb(156, 39, 176),   // 5: 紫色 #9C27B0
        };

        // 拖拽
        private bool _isDragging = false;
        private Point _dragStart;

        public MainWindow()
        {
            InitializeComponent();
            Loaded += MainWindow_Loaded;
            Closing += MainWindow_Closing;

            // 拖拽移动窗口
            CardBorder.MouseLeftButtonDown += CardBorder_MouseLeftButtonDown;
            CardBorder.MouseMove += CardBorder_MouseMove;
            CardBorder.MouseLeftButtonUp += CardBorder_MouseLeftButtonUp;

            // 点击切换下一个
            CardBorder.MouseRightButtonDown += (s, e) => ShowNext();
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            // 初始位置：右下角
            var screenWidth = SystemParameters.PrimaryScreenWidth;
            var screenHeight = SystemParameters.PrimaryScreenHeight;
            Left = screenWidth - Width - 50;
            Top = screenHeight - Height - 100;

            // 立即应用默认样式，避免显示白色背景
            ApplyStyle(_styleIndex);

            StartTcpServer();
            StartCarouselLoop();
        }

        private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
        {
            _isRunning = false;
            _cts?.Cancel();
            _stream?.Close();
            _client?.Close();
            _tcpListener?.Stop();
        }

        #region 拖拽

        private void CardBorder_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            _isDragging = true;
            _dragStart = e.GetPosition(this);
            CardBorder.CaptureMouse();
        }

        private void CardBorder_MouseMove(object sender, MouseEventArgs e)
        {
            if (_isDragging)
            {
                var pos = e.GetPosition(this);
                Left += pos.X - _dragStart.X;
                Top += pos.Y - _dragStart.Y;
            }
        }

        private void CardBorder_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
        {
            _isDragging = false;
            CardBorder.ReleaseMouseCapture();
        }

        #endregion

        #region TCP 通信

        private async void StartTcpServer()
        {
            try
            {
                _tcpListener = new TcpListener(IPAddress.Loopback, 9528);
                _tcpListener.Start();
                Console.WriteLine("Carousel TCP Server started on port 9528");

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

            if (config["interval"] != null)
                _intervalSeconds = config["interval"]!.Value<int>();

            if (config["styleIndex"] != null)
            {
                _styleIndex = config["styleIndex"]!.Value<int>();
                ApplyStyle(_styleIndex);
            }

            if (config["position"] != null)
            {
                ApplyPosition(config["position"]!.ToString());
            }
        }

        private void ApplyStyle(int styleIndex)
        {
            if (styleIndex < 0 || styleIndex >= StyleColors.Length)
                styleIndex = 0;

            var color = StyleColors[styleIndex];

            // 应用背景颜色（带透明度）
            CardBorder.Background = new SolidColorBrush(Color.FromArgb(230, color.R, color.G, color.B));

            // 单词和音标使用白色
            WordText.Foreground = new SolidColorBrush(Colors.White);
            PhoneticText.Foreground = new SolidColorBrush(Color.FromArgb(200, 255, 255, 255));

            // 翻译使用金色
            TransText.Foreground = new SolidColorBrush(Color.FromRgb(255, 215, 0));
        }

        private void ApplyPosition(string position)
        {
            var screenWidth = SystemParameters.PrimaryScreenWidth;
            var screenHeight = SystemParameters.PrimaryScreenHeight;

            switch (position)
            {
                case "top-left":
                    Left = 50;
                    Top = 50;
                    break;
                case "top-right":
                    Left = screenWidth - Width - 50;
                    Top = 50;
                    break;
                case "bottom-left":
                    Left = 50;
                    Top = screenHeight - Height - 100;
                    break;
                case "bottom-right":
                default:
                    Left = screenWidth - Width - 50;
                    Top = screenHeight - Height - 100;
                    break;
            }
        }

        private void LoadWords(JArray? wordsArray)
        {
            if (wordsArray == null) return;

            _words.Clear();
            foreach (var item in wordsArray)
            {
                _words.Add(new WordItem
                {
                    Word = item["Word"]?.ToString() ?? "",
                    Phonetic = item["Phonetic"]?.ToString() ?? "",
                    Translation = item["Translation"]?.ToString() ?? ""
                });
            }

            _currentIndex = 0;
            UpdateDots();

            if (_words.Count > 0)
            {
                ShowWord(_words[0]);
            }

            Console.WriteLine($"Loaded {_words.Count} words");
        }

        #endregion

        #region 轮播逻辑

        private async void StartCarouselLoop()
        {
            while (_isRunning)
            {
                await Task.Delay(_intervalSeconds * 1000);

                if (!_isPaused && _words.Count > 0)
                {
                    Dispatcher.Invoke(() => ShowNext());
                }
            }
        }

        private void ShowNext()
        {
            if (_words.Count == 0) return;

            _currentIndex = (_currentIndex + 1) % _words.Count;
            ShowWordWithAnimation(_words[_currentIndex]);
            UpdateDots();
        }

        private void ShowWord(WordItem word)
        {
            WordText.Text = word.Word;
            PhoneticText.Text = word.Phonetic;
            TransText.Text = word.Translation;
        }

        private void ShowWordWithAnimation(WordItem word)
        {
            // 淡出
            var fadeOut = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(150));
            fadeOut.Completed += (s, e) =>
            {
                ShowWord(word);
                // 淡入
                var fadeIn = new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(150));
                CardBorder.BeginAnimation(OpacityProperty, fadeIn);
            };
            CardBorder.BeginAnimation(OpacityProperty, fadeOut);
        }

        private void UpdateDots()
        {
            DotsPanel.Children.Clear();

            for (int i = 0; i < Math.Min(_words.Count, 10); i++)
            {
                var dot = new Ellipse
                {
                    Width = 8,
                    Height = 8,
                    Margin = new Thickness(3, 0, 3, 0),
                    Fill = i == _currentIndex % 10
                        ? new SolidColorBrush(Color.FromRgb(91, 108, 255))
                        : new SolidColorBrush(Color.FromRgb(200, 200, 200))
                };
                DotsPanel.Children.Add(dot);
            }
        }

        #endregion
    }

    class WordItem
    {
        public string Word { get; set; } = "";
        public string Phonetic { get; set; } = "";
        public string Translation { get; set; } = "";
    }
}
