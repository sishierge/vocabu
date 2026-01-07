import 'package:flutter/foundation.dart';
import 'online_materials_service.dart';

/// 在线听力素材服务
class ListeningMaterialsService {
  static final ListeningMaterialsService instance = ListeningMaterialsService._();
  ListeningMaterialsService._();

  /// 素材源列表
  static final List<MaterialSource> sources = [
    MaterialSource(
      id: 'manythings_daily',
      name: '日常对话',
      description: '来自Tatoeba的日常英语对话句子',
      category: '基础',
      sentenceCount: 100,
      difficulty: '初级',
      icon: '💬',
    ),
    MaterialSource(
      id: 'manythings_travel',
      name: '旅行英语',
      description: '旅行场景常用句子和对话',
      category: '场景',
      sentenceCount: 80,
      difficulty: '初级',
      icon: '✈️',
    ),
    MaterialSource(
      id: 'manythings_business',
      name: '商务英语',
      description: '职场和商务场景常用表达',
      category: '职场',
      sentenceCount: 90,
      difficulty: '中级',
      icon: '💼',
    ),
    MaterialSource(
      id: 'manythings_academic',
      name: '学术英语',
      description: '学术写作和讨论常用句型',
      category: '学术',
      sentenceCount: 60,
      difficulty: '高级',
      icon: '📚',
    ),
    MaterialSource(
      id: 'manythings_idioms',
      name: '英语习语',
      description: '常用英语习语和俗语',
      category: '进阶',
      sentenceCount: 50,
      difficulty: '中级',
      icon: '🎯',
    ),
    MaterialSource(
      id: 'manythings_news',
      name: '新闻英语',
      description: '新闻报道常用句型和表达',
      category: '进阶',
      sentenceCount: 70,
      difficulty: '中级',
      icon: '📰',
    ),
    // 新增更多素材
    MaterialSource(
      id: 'manythings_movies',
      name: '影视台词',
      description: '经典电影和电视剧的常用台词',
      category: '场景',
      sentenceCount: 80,
      difficulty: '中级',
      icon: '🎬',
    ),
    MaterialSource(
      id: 'manythings_life',
      name: '生活常用语',
      description: '日常生活中最实用的英语表达',
      category: '基础',
      sentenceCount: 100,
      difficulty: '初级',
      icon: '🏠',
    ),
    MaterialSource(
      id: 'manythings_tech',
      name: '科技英语',
      description: '科技、编程和IT行业常用表达',
      category: '职场',
      sentenceCount: 70,
      difficulty: '中级',
      icon: '💻',
    ),
    MaterialSource(
      id: 'manythings_interview',
      name: '面试英语',
      description: '求职面试常用问答和表达',
      category: '职场',
      sentenceCount: 60,
      difficulty: '中级',
      icon: '👔',
    ),
    // BBC Learning English 系列
    MaterialSource(
      id: 'bbc_6minute',
      name: 'BBC 6分钟英语',
      description: 'BBC经典英语学习节目，词汇丰富',
      category: '进阶',
      sentenceCount: 80,
      difficulty: '中级',
      icon: '🎧',
    ),
    MaterialSource(
      id: 'bbc_work',
      name: 'BBC 职场英语',
      description: 'English at Work职场场景对话',
      category: '职场',
      sentenceCount: 70,
      difficulty: '中级',
      icon: '🏢',
    ),
    MaterialSource(
      id: 'bbc_news',
      name: 'BBC 新闻英语',
      description: 'BBC News Review新闻词汇和表达',
      category: '进阶',
      sentenceCount: 60,
      difficulty: '高级',
      icon: '📺',
    ),
    MaterialSource(
      id: 'bbc_speak',
      name: 'BBC 地道英语',
      description: 'The English We Speak日常俗语和习误',
      category: '场景',
      sentenceCount: 50,
      difficulty: '中级',
      icon: '🗣️',
    ),
    MaterialSource(
      id: 'bbc_pronunciation',
      name: 'BBC 发音教程',
      description: '英式发音技巧和练习',
      category: '基础',
      sentenceCount: 40,
      difficulty: '初级',
      icon: '🔊',
    ),
    // === 在线素材 ===
    MaterialSource(
      id: 'voa_slow',
      name: 'VOA 慢速英语',
      description: 'Voice of America慢速英语新闻，带真实音频',
      category: '在线',
      sentenceCount: 25,
      difficulty: '初级',
      icon: '🇺🇸',
    ),
    MaterialSource(
      id: 'bbc_learning',
      name: 'BBC Learning English',
      description: 'BBC学习英语节目，纯正英式发音',
      category: '在线',
      sentenceCount: 20,
      difficulty: '中级',
      icon: '🇬🇧',
    ),
    MaterialSource(
      id: 'daily_english',
      name: '每日英语短句',
      description: '精选每日励志英语短句，配有翻译',
      category: '在线',
      sentenceCount: 20,
      difficulty: '初级',
      icon: '📅',
    ),
    MaterialSource(
      id: 'ted_talks',
      name: 'TED 演讲精选',
      description: 'TED经典演讲语录，思想与语言的碰撞',
      category: '在线',
      sentenceCount: 20,
      difficulty: '高级',
      icon: '🎤',
    ),
    MaterialSource(
      id: 'news_english',
      name: '新闻英语听力',
      description: '精选新闻片段，提高听力水平',
      category: '在线',
      sentenceCount: 20,
      difficulty: '中高级',
      icon: '📰',
    ),
  ];

  /// 获取素材内容
  Future<List<Map<String, String>>> fetchMaterialContent(String sourceId) async {
    try {
      // 根据不同的sourceId返回不同的内容
      switch (sourceId) {
        case 'manythings_daily':
          return _getDailySentences();
        case 'manythings_travel':
          return _getTravelSentences();
        case 'manythings_business':
          return _getBusinessSentences();
        case 'manythings_academic':
          return _getAcademicSentences();
        case 'manythings_idioms':
          return _getIdiomSentences();
        case 'manythings_news':
          return _getNewsSentences();
        case 'manythings_movies':
          return _getMovieSentences();
        case 'manythings_life':
          return _getLifeSentences();
        case 'manythings_tech':
          return _getTechSentences();
        case 'manythings_interview':
          return _getInterviewSentences();
        case 'bbc_6minute':
          return _getBBC6MinuteSentences();
        case 'bbc_work':
          return _getBBCWorkSentences();
        case 'bbc_news':
          return _getBBCNewsSentences();
        case 'bbc_speak':
          return _getBBCSpeakSentences();
        case 'bbc_pronunciation':
          return _getBBCPronunciationSentences();
        // 在线素材
        case 'voa_slow':
        case 'bbc_learning':
        case 'daily_english':
        case 'ted_talks':
        case 'news_english':
          return OnlineMaterialsService.instance.fetchOnlineMaterial(sourceId);
        default:
          return [];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching material: $e');
      }
      return [];
    }
  }


  // 预置的日常对话句子
  List<Map<String, String>> _getDailySentences() {
    return [
      {'en': 'Good morning! How did you sleep?', 'cn': '早上好！你睡得怎么样？'},
      {'en': "I'm running late for work today.", 'cn': '我今天上班要迟到了。'},
      {'en': 'Could you please pass me the salt?', 'cn': '你能把盐递给我吗？'},
      {'en': 'The weather is really nice today.', 'cn': '今天天气真不错。'},
      {'en': 'I need to go grocery shopping this weekend.', 'cn': '这个周末我需要去买菜。'},
      {'en': 'What time does the movie start?', 'cn': '电影几点开始？'},
      {'en': "I've been learning English for three years.", 'cn': '我学英语已经三年了。'},
      {'en': 'Could you recommend a good restaurant nearby?', 'cn': '你能推荐附近一家好餐厅吗？'},
      {'en': "I'm sorry, I didn't catch what you said.", 'cn': '抱歉，我没听清你说什么。'},
      {'en': 'Let me check my schedule and get back to you.', 'cn': '让我查一下日程再回复你。'},
      {'en': 'The train leaves at half past nine.', 'cn': '火车九点半出发。'},
      {'en': 'I prefer tea over coffee in the morning.', 'cn': '早上我更喜欢喝茶而不是咖啡。'},
      {'en': 'Do you have any plans for the holidays?', 'cn': '你假期有什么安排吗？'},
      {'en': 'I think we should take a different approach.', 'cn': '我认为我们应该采取不同的方法。'},
      {'en': 'The meeting has been postponed until next week.', 'cn': '会议推迟到下周了。'},
      {'en': 'Can you help me with this problem?', 'cn': '你能帮我解决这个问题吗？'},
      {'en': "I'm looking forward to seeing you again.", 'cn': '我期待再次见到你。'},
      {'en': 'Please feel free to ask if you have any questions.', 'cn': '如果有任何问题请随时问。'},
      {'en': 'I completely agree with your point of view.', 'cn': '我完全同意你的观点。'},
      {'en': "It's been a pleasure working with you.", 'cn': '很高兴与你共事。'},
      {'en': 'I apologize for the inconvenience caused.', 'cn': '对造成的不便我深表歉意。'},
      {'en': 'Could we schedule a meeting for tomorrow?', 'cn': '我们能安排明天开个会吗？'},
      {'en': "I'll send you the report by end of day.", 'cn': '我会在今天结束前把报告发给你。'},
      {'en': 'That sounds like a great idea!', 'cn': '这听起来是个好主意！'},
      {'en': "I'm not sure I understand what you mean.", 'cn': '我不太确定你的意思。'},
      {'en': "Let's grab lunch together sometime.", 'cn': '找个时间一起吃个午饭吧。'},
      {'en': 'I need to think about it before making a decision.', 'cn': '我需要考虑一下再做决定。'},
      {'en': 'The project is progressing well.', 'cn': '项目进展顺利。'},
      {'en': 'I appreciate your help with this matter.', 'cn': '感谢你在这件事上的帮助。'},
      {'en': 'We should discuss this in more detail.', 'cn': '我们应该更详细地讨论这件事。'},
      {'en': 'What do you usually do on weekends?', 'cn': '你周末通常做什么？'},
      {'en': 'I enjoy reading books in my free time.', 'cn': '我空闲时喜欢看书。'},
      {'en': 'How long have you lived in this city?', 'cn': '你在这个城市住了多久？'},
      {'en': 'The traffic is terrible during rush hour.', 'cn': '高峰期交通很糟糕。'},
      {'en': "I'll be there in about ten minutes.", 'cn': '我大约十分钟后到。'},
      {'en': 'Could you speak a little slower, please?', 'cn': '你能说慢一点吗？'},
      {'en': 'I had a great time at the party last night.', 'cn': '我昨晚在聚会上玩得很开心。'},
      {'en': "It's getting late. I should go home.", 'cn': '时间不早了，我该回家了。'},
      {'en': 'Do you mind if I open the window?', 'cn': '你介意我开窗吗？'},
      {'en': "I've heard a lot about you.", 'cn': '我听说了很多关于你的事。'},
      {'en': 'What a coincidence to meet you here!', 'cn': '在这里遇到你真是太巧了！'},
      {'en': 'I need to charge my phone.', 'cn': '我需要给手机充电。'},
      {'en': 'The food here is absolutely delicious.', 'cn': '这里的食物非常美味。'},
      {'en': 'I forgot to bring my umbrella.', 'cn': '我忘了带伞。'},
      {'en': "Let's keep in touch.", 'cn': '让我们保持联系。'},
      {'en': 'I really enjoyed our conversation.', 'cn': '我很享受我们的交谈。'},
      {'en': 'Take care of yourself.', 'cn': '照顾好自己。'},
      {'en': 'See you next time!', 'cn': '下次见！'},
      {'en': 'Have a safe trip!', 'cn': '一路平安！'},
      {'en': 'Best wishes for your future!', 'cn': '祝你前程似锦！'},
    ];
  }

  // 旅行英语句子
  List<Map<String, String>> _getTravelSentences() {
    return [
      {'en': "I'd like to book a table for two, please.", 'cn': '我想预订一张两人桌。'},
      {'en': 'Could I see the menu, please?', 'cn': '我能看一下菜单吗？'},
      {'en': 'What do you recommend?', 'cn': '你有什么推荐的？'},
      {'en': "I'll have the steak, medium rare.", 'cn': '我要一份牛排，五分熟。'},
      {'en': 'Is this dish spicy?', 'cn': '这道菜辣吗？'},
      {'en': 'Could we have some more water, please?', 'cn': '能再给我们一些水吗？'},
      {'en': "I'm allergic to peanuts.", 'cn': '我对花生过敏。'},
      {'en': 'The food was delicious, thank you.', 'cn': '食物很美味，谢谢。'},
      {'en': 'Could we have the bill, please?', 'cn': '请结账。'},
      {'en': 'Do you accept credit cards?', 'cn': '你们接受信用卡吗？'},
      {'en': 'Where is the nearest pharmacy?', 'cn': '最近的药店在哪里？'},
      {'en': 'How do I get to the train station?', 'cn': '怎么去火车站？'},
      {'en': 'Is it within walking distance?', 'cn': '步行能到吗？'},
      {'en': 'Could you call a taxi for me?', 'cn': '你能帮我叫辆出租车吗？'},
      {'en': 'How much is the fare to the airport?', 'cn': '去机场多少钱？'},
      {'en': "I'd like a single room for two nights.", 'cn': '我想要一间单人房住两晚。'},
      {'en': 'What time is breakfast served?', 'cn': '早餐几点供应？'},
      {'en': 'Is there WiFi in the room?', 'cn': '房间里有WiFi吗？'},
      {'en': 'Could I have a wake-up call at seven?', 'cn': '能在七点叫醒我吗？'},
      {'en': "I'd like to check out, please.", 'cn': '我想退房。'},
      {'en': 'Do you have this in a larger size?', 'cn': '这个有大一号的吗？'},
      {'en': 'Can I try this on?', 'cn': '我能试穿一下吗？'},
      {'en': 'How much is this?', 'cn': '这个多少钱？'},
      {'en': 'Is there a discount?', 'cn': '有折扣吗？'},
      {'en': "I'll take it.", 'cn': '我要了。'},
      {'en': 'Could you wrap it as a gift?', 'cn': '能包装成礼物吗？'},
      {'en': "I'm just looking, thanks.", 'cn': '我只是看看，谢谢。'},
      {'en': 'Do you have anything cheaper?', 'cn': '有便宜一点的吗？'},
      {'en': 'I need to exchange some money.', 'cn': '我需要换一些钱。'},
      {'en': "What's the exchange rate today?", 'cn': '今天的汇率是多少？'},
      {'en': 'Where is the departure gate?', 'cn': '登机口在哪里？'},
      {'en': 'My flight has been delayed.', 'cn': '我的航班延误了。'},
      {'en': "I'd like a window seat, please.", 'cn': '我想要靠窗的座位。'},
      {'en': 'Is this seat taken?', 'cn': '这个座位有人吗？'},
      {'en': 'Excuse me, where is the restroom?', 'cn': '请问洗手间在哪里？'},
      {'en': "I've lost my luggage.", 'cn': '我的行李丢了。'},
      {'en': 'Could you help me with my bags?', 'cn': '你能帮我拿一下行李吗？'},
      {'en': "I'd like to rent a car.", 'cn': '我想租一辆车。'},
      {'en': 'Is parking available nearby?', 'cn': '附近有停车位吗？'},
      {'en': 'What are the must-see attractions here?', 'cn': '这里有哪些必看的景点？'},
    ];
  }

  // 商务英语句子
  List<Map<String, String>> _getBusinessSentences() {
    return [
      {'en': "Let me introduce myself. I'm the project manager.", 'cn': '让我自我介绍一下，我是项目经理。'},
      {'en': 'Thank you for taking the time to meet with us.', 'cn': '感谢您抽出时间与我们会面。'},
      {'en': "I'd like to discuss the quarterly results.", 'cn': '我想讨论一下季度业绩。'},
      {'en': 'Could you elaborate on that point?', 'cn': '你能详细说明一下那一点吗？'},
      {'en': "Let's move on to the next item on the agenda.", 'cn': '让我们进入议程的下一项。'},
      {'en': 'I have a few concerns about the timeline.', 'cn': '我对时间表有一些担忧。'},
      {'en': 'We need to stay within budget.', 'cn': '我们需要控制在预算之内。'},
      {'en': 'The deadline has been extended by two weeks.', 'cn': '截止日期延长了两周。'},
      {'en': "I'll follow up with an email after the meeting.", 'cn': '会后我会发邮件跟进。'},
      {'en': "Let's schedule a follow-up meeting for next Monday.", 'cn': '让我们安排下周一的跟进会议。'},
      {'en': "I'm calling to inquire about your services.", 'cn': '我打电话是想了解你们的服务。'},
      {'en': 'Could you put me through to the sales department?', 'cn': '能帮我转接销售部门吗？'},
      {'en': "I'm afraid he's in a meeting right now.", 'cn': '恐怕他现在正在开会。'},
      {'en': 'Would you like to leave a message?', 'cn': '你要留言吗？'},
      {'en': "I'll make sure he gets your message.", 'cn': '我会确保他收到您的留言。'},
      {'en': 'Please find attached the document you requested.', 'cn': '请查收您要求的附件文档。'},
      {'en': "I'm writing to confirm our meeting tomorrow.", 'cn': '我写信确认我们明天的会议。'},
      {'en': 'Thank you for your prompt response.', 'cn': '感谢您的及时回复。'},
      {'en': 'I look forward to hearing from you soon.', 'cn': '期待尽快收到您的回复。'},
      {'en': "Please don't hesitate to contact me if you have any questions.", 'cn': '如有任何问题，请随时联系我。'},
      {'en': 'We need to increase our market share.', 'cn': '我们需要增加市场份额。'},
      {'en': 'The competition is getting stronger.', 'cn': '竞争越来越激烈。'},
      {'en': 'We should focus on customer satisfaction.', 'cn': '我们应该关注客户满意度。'},
      {'en': 'Innovation is key to our success.', 'cn': '创新是我们成功的关键。'},
      {'en': 'We need to streamline our processes.', 'cn': '我们需要简化流程。'},
      {'en': 'The proposal has been approved by management.', 'cn': '提案已获管理层批准。'},
      {'en': "We're ahead of schedule.", 'cn': '我们进度超前。'},
      {'en': 'The client has requested some changes.', 'cn': '客户要求做一些修改。'},
      {'en': 'We need more resources to complete this project.', 'cn': '我们需要更多资源来完成这个项目。'},
      {'en': "Let's wrap up and summarize the key points.", 'cn': '让我们总结一下要点。'},
    ];
  }

  // 学术英语句子
  List<Map<String, String>> _getAcademicSentences() {
    return [
      {'en': 'This study aims to investigate the relationship between...', 'cn': '本研究旨在探讨...之间的关系。'},
      {'en': 'The results suggest that there is a significant correlation.', 'cn': '结果表明存在显著相关性。'},
      {'en': 'Previous research has shown that...', 'cn': '以往的研究表明...'},
      {'en': 'The methodology used in this study includes...', 'cn': '本研究采用的方法包括...'},
      {'en': 'Data was collected through surveys and interviews.', 'cn': '数据通过问卷调查和访谈收集。'},
      {'en': 'The sample consisted of 200 participants.', 'cn': '样本包括200名参与者。'},
      {'en': 'The findings are consistent with previous studies.', 'cn': '研究结果与以往研究一致。'},
      {'en': 'Further research is needed to confirm these results.', 'cn': '需要进一步研究来证实这些结果。'},
      {'en': 'The limitations of this study include...', 'cn': '本研究的局限性包括...'},
      {'en': 'In conclusion, this research demonstrates that...', 'cn': '总之，本研究表明...'},
      {'en': 'The hypothesis was supported by the evidence.', 'cn': '假设得到了证据的支持。'},
      {'en': 'A qualitative approach was adopted for this research.', 'cn': '本研究采用了定性方法。'},
      {'en': 'The data was analyzed using statistical software.', 'cn': '数据使用统计软件进行分析。'},
      {'en': 'The theoretical framework is based on...', 'cn': '理论框架基于...'},
      {'en': 'This paper contributes to the existing literature by...', 'cn': '本文通过...为现有文献做出贡献。'},
      {'en': 'The implications of this study are significant for...', 'cn': '本研究的意义对...很重要。'},
      {'en': 'According to the author, the main argument is...', 'cn': '根据作者的观点，主要论点是...'},
      {'en': 'It can be argued that...', 'cn': '可以认为...'},
      {'en': 'However, it should be noted that...', 'cn': '然而，应该注意的是...'},
      {'en': 'In contrast to previous findings...', 'cn': '与以往研究结果相反...'},
    ];
  }

  // 英语习语句子
  List<Map<String, String>> _getIdiomSentences() {
    return [
      {'en': "It's raining cats and dogs outside.", 'cn': '外面下着倾盆大雨。'},
      {'en': "Don't put all your eggs in one basket.", 'cn': '不要把所有鸡蛋放在一个篮子里。'},
      {'en': "Break a leg! I know you'll do great.", 'cn': '祝你好运！我知道你会表现很棒的。'},
      {'en': 'That exam was a piece of cake.', 'cn': '那次考试简直是小菜一碟。'},
      {'en': "Let's call it a day and go home.", 'cn': '今天就到这里吧，回家吧。'},
      {'en': "He's been feeling under the weather lately.", 'cn': '他最近身体不太舒服。'},
      {'en': 'The ball is in your court now.', 'cn': '现在轮到你决定了。'},
      {'en': "Don't beat around the bush, just tell me.", 'cn': '别绕弯子了，直接告诉我。'},
      {'en': "It costs an arm and a leg.", 'cn': '这太贵了。'},
      {'en': 'We need to bite the bullet and do it.', 'cn': '我们需要咬紧牙关去做。'},
      {'en': 'Actions speak louder than words.', 'cn': '行动胜于言语。'},
      {'en': "You can't judge a book by its cover.", 'cn': '不能以貌取人。'},
      {'en': 'Every cloud has a silver lining.', 'cn': '黑暗中总有一线光明。'},
      {'en': "It's no use crying over spilt milk.", 'cn': '覆水难收，后悔无益。'},
      {'en': 'Better late than never.', 'cn': '迟做总比不做好。'},
      {'en': 'Two heads are better than one.', 'cn': '三个臭皮匠顶个诸葛亮。'},
      {'en': 'Practice makes perfect.', 'cn': '熟能生巧。'},
      {'en': "When in Rome, do as the Romans do.", 'cn': '入乡随俗。'},
      {'en': "The early bird catches the worm.", 'cn': '早起的鸟儿有虫吃。'},
      {'en': "Don't count your chickens before they hatch.", 'cn': '不要过早乐观。'},
    ];
  }

  // 新闻英语句子
  List<Map<String, String>> _getNewsSentences() {
    return [
      {'en': 'Breaking news: A major earthquake has struck the region.', 'cn': '突发新闻：该地区发生强烈地震。'},
      {'en': 'The President announced a new policy today.', 'cn': '总统今天宣布了一项新政策。'},
      {'en': 'Stock markets fell sharply amid growing concerns.', 'cn': '由于担忧加剧，股市大幅下跌。'},
      {'en': 'Scientists have made a breakthrough discovery.', 'cn': '科学家们取得了突破性发现。'},
      {'en': 'The election results are expected tomorrow.', 'cn': '选举结果预计明天公布。'},
      {'en': 'Talks between the two nations have resumed.', 'cn': '两国之间的会谈已经恢复。'},
      {'en': 'The company reported record profits this quarter.', 'cn': '该公司本季度公布了创纪录的利润。'},
      {'en': 'Severe weather warnings have been issued.', 'cn': '已发布恶劣天气警报。'},
      {'en': 'The unemployment rate has dropped to five percent.', 'cn': '失业率已降至百分之五。'},
      {'en': 'A new study reveals the health benefits of exercise.', 'cn': '一项新研究揭示了运动对健康的好处。'},
      {'en': 'The government has proposed new environmental regulations.', 'cn': '政府提出了新的环境法规。'},
      {'en': 'Protests continue in the capital city.', 'cn': '首都的抗议活动仍在继续。'},
      {'en': 'The economic outlook remains uncertain.', 'cn': '经济前景仍然不确定。'},
      {'en': 'Experts warn of potential risks ahead.', 'cn': '专家警告前方存在潜在风险。'},
      {'en': 'The treaty was signed by both parties.', 'cn': '条约已由双方签署。'},
      {'en': 'Oil prices have risen significantly this week.', 'cn': '本周油价大幅上涨。'},
      {'en': 'The investigation is still ongoing.', 'cn': '调查仍在进行中。'},
      {'en': 'New technology is transforming the industry.', 'cn': '新技术正在改变这个行业。'},
      {'en': 'The summit will be held next month.', 'cn': '峰会将于下月举行。'},
      {'en': 'According to official sources...', 'cn': '据官方消息来源称...'},
    ];
  }

  // 影视台词
  List<Map<String, String>> _getMovieSentences() {
    return [
      {'en': "May the Force be with you.", 'cn': '愿原力与你同在。'},
      {'en': "I'll be back.", 'cn': '我会回来的。'},
      {'en': "Here's looking at you, kid.", 'cn': '我望着你呢，孩子。'},
      {'en': "You can't handle the truth!", 'cn': '你承受不了真相！'},
      {'en': "Life is like a box of chocolates.", 'cn': '生活就像一盒巧克力。'},
      {'en': "I'm the king of the world!", 'cn': '我是世界之王！'},
      {'en': "To infinity and beyond!", 'cn': '飞向无限，超越极限！'},
      {'en': "Just keep swimming.", 'cn': '继续游，不要停。'},
      {'en': "Why so serious?", 'cn': '为什么这么严肃？'},
      {'en': "I see dead people.", 'cn': '我能看见死人。'},
      {'en': "After all, tomorrow is another day.", 'cn': '毕竟，明天又是新的一天。'},
      {'en': "You talking to me?", 'cn': '你在跟我说话吗？'},
      {'en': "The first rule of Fight Club is: you do not talk about Fight Club.", 'cn': '搏击俱乐部的第一条规矩是：你不能谈论搏击俱乐部。'},
      {'en': "Houston, we have a problem.", 'cn': '休斯顿，我们有麻烦了。'},
      {'en': "Winter is coming.", 'cn': '凛冬将至。'},
      {'en': "I am Iron Man.", 'cn': '我是钢铁侠。'},
      {'en': "With great power comes great responsibility.", 'cn': '能力越大，责任越大。'},
      {'en': "You jump, I jump.", 'cn': '你跳，我也跳。'},
      {'en': "I'll never let go.", 'cn': '我永远不会放手。'},
      {'en': "Keep your friends close, but your enemies closer.", 'cn': '亲近你的朋友，更要亲近你的敌人。'},
    ];
  }

  // 生活常用语
  List<Map<String, String>> _getLifeSentences() {
    return [
      {'en': "What's for dinner tonight?", 'cn': '今晚吃什么？'},
      {'en': "Did you remember to lock the door?", 'cn': '你记得锁门了吗？'},
      {'en': "I'll do the dishes after dinner.", 'cn': '晚饭后我来洗碗。'},
      {'en': "The wifi password is on the fridge.", 'cn': 'WiFi密码在冰箱上。'},
      {'en': "Could you turn off the lights?", 'cn': '你能关灯吗？'},
      {'en': "I need to do laundry today.", 'cn': '我今天需要洗衣服。'},
      {'en': "Let's order takeout tonight.", 'cn': '今晚我们点外卖吧。'},
      {'en': "The trash needs to be taken out.", 'cn': '垃圾需要倒了。'},
      {'en': "I'm exhausted. I need some sleep.", 'cn': '我累坏了，需要睡一觉。'},
      {'en': "What time do you want to wake up?", 'cn': '你想几点起床？'},
      {'en': "I'll pick up some groceries on my way home.", 'cn': '我回家路上顺便买些食材。'},
      {'en': "Is there any coffee left?", 'cn': '还有咖啡吗？'},
      {'en': "The remote control is under the couch.", 'cn': '遥控器在沙发底下。'},
      {'en': "I'm going to take a shower.", 'cn': '我去洗个澡。'},
      {'en': "Don't forget to brush your teeth.", 'cn': '别忘了刷牙。'},
      {'en': "What time does the store close?", 'cn': '商店几点关门？'},
      {'en': "I need to renew my driver's license.", 'cn': '我需要更新驾照。'},
      {'en': "The neighbors are having a party.", 'cn': '邻居在开派对。'},
      {'en': "I'll be home around six.", 'cn': '我大约六点到家。'},
      {'en': "Have you seen my keys anywhere?", 'cn': '你看到我的钥匙了吗？'},
    ];
  }

  // 科技英语
  List<Map<String, String>> _getTechSentences() {
    return [
      {'en': "Have you tried turning it off and on again?", 'cn': '你试过重启吗？'},
      {'en': "The system is experiencing some technical difficulties.", 'cn': '系统正在经历一些技术问题。'},
      {'en': "Please update your software to the latest version.", 'cn': '请将软件更新到最新版本。'},
      {'en': "You need to clear your browser cache.", 'cn': '你需要清除浏览器缓存。'},
      {'en': "The bug has been fixed in the latest patch.", 'cn': '这个bug已在最新补丁中修复。'},
      {'en': "Let me share my screen with you.", 'cn': '让我把屏幕分享给你。'},
      {'en': "The deadline for this sprint is Friday.", 'cn': '这个Sprint的截止日期是周五。'},
      {'en': "We need to refactor this code.", 'cn': '我们需要重构这段代码。'},
      {'en': "The API is returning an error.", 'cn': 'API返回了一个错误。'},
      {'en': "Can you push your changes to the repository?", 'cn': '你能把改动推送到仓库吗？'},
      {'en': "I'll create a pull request for review.", 'cn': '我会创建一个拉取请求供审查。'},
      {'en': "The server is down for maintenance.", 'cn': '服务器正在维护中。'},
      {'en': "We're using agile methodology for this project.", 'cn': '我们这个项目使用敏捷方法论。'},
      {'en': "The deployment was successful.", 'cn': '部署成功了。'},
      {'en': "Can you check the error logs?", 'cn': '你能检查一下错误日志吗？'},
      {'en': "We need to optimize database queries.", 'cn': '我们需要优化数据库查询。'},
      {'en': "The unit tests are all passing.", 'cn': '单元测试全部通过了。'},
      {'en': "Let's schedule a code review meeting.", 'cn': '让我们安排一个代码审查会议。'},
      {'en': "The feature will be rolled out next week.", 'cn': '这个功能将于下周上线。'},
      {'en': "Make sure to backup your data regularly.", 'cn': '确保定期备份你的数据。'},
    ];
  }

  // 面试英语
  List<Map<String, String>> _getInterviewSentences() {
    return [
      {'en': "Tell me about yourself.", 'cn': '请介绍一下你自己。'},
      {'en': "Why do you want to work for our company?", 'cn': '你为什么想在我们公司工作？'},
      {'en': "What are your greatest strengths?", 'cn': '你最大的优点是什么？'},
      {'en': "What do you consider your weaknesses?", 'cn': '你认为你的缺点是什么？'},
      {'en': "Where do you see yourself in five years?", 'cn': '你五年后想成为什么样子？'},
      {'en': "Why did you leave your last job?", 'cn': '你为什么离开上一份工作？'},
      {'en': "Can you describe a challenging situation you've faced?", 'cn': '你能描述一个你遇到的挑战吗？'},
      {'en': "How do you handle pressure and stress?", 'cn': '你如何应对压力？'},
      {'en': "What are your salary expectations?", 'cn': '你期望的薪资是多少？'},
      {'en': "Do you have any questions for us?", 'cn': '你有什么问题要问我们吗？'},
      {'en': "I'm a quick learner and very motivated.", 'cn': '我学习能力强，工作积极主动。'},
      {'en': "I work well both independently and in a team.", 'cn': '我既能独立工作也能团队合作。'},
      {'en': "I'm passionate about this industry.", 'cn': '我对这个行业充满热情。'},
      {'en': "I can start immediately if needed.", 'cn': '如果需要，我可以立即入职。'},
      {'en': "What does a typical day look like in this role?", 'cn': '这个职位的日常工作是什么样的？'},
      {'en': "What opportunities are there for professional development?", 'cn': '有哪些职业发展机会？'},
      {'en': "How would you describe the company culture?", 'cn': '您如何描述公司文化？'},
      {'en': "Thank you for the opportunity to interview.", 'cn': '感谢您给我面试的机会。'},
      {'en': "I look forward to hearing from you.", 'cn': '期待您的回复。'},
      {'en': "It was a pleasure meeting you today.", 'cn': '很高兴今天见到您。'},
    ];
  }

  // BBC 6分钟英语
  List<Map<String, String>> _getBBC6MinuteSentences() {
    return [
      {'en': "Today we're looking at the topic of sustainable living.", 'cn': '今天我们要探讨可持续生活这个话题。'},
      {'en': "Before we begin, let's look at this week's question.", 'cn': '在开始之前，让我们看看本周的问题。'},
      {'en': "The answer might surprise you.", 'cn': '答案可能会让你感到惊讶。'},
      {'en': "Let's start by looking at some vocabulary.", 'cn': '让我们先来看一些词汇。'},
      {'en': "Carbon footprint refers to the amount of carbon dioxide released into the atmosphere.", 'cn': '碳足迹指的是释放到大气中的二氧化碳量。'},
      {'en': "Renewable energy comes from sources that won't run out.", 'cn': '可再生能源来自不会耗尽的来源。'},
      {'en': "Climate change is one of the biggest challenges we face today.", 'cn': '气候变化是我们今天面临的最大挑战之一。'},
      {'en': "Scientists are working on innovative solutions.", 'cn': '科学家们正在研究创新解决方案。'},
      {'en': "The gig economy has transformed how people work.", 'cn': '零工经济已经改变了人们的工作方式。'},
      {'en': "Artificial intelligence is reshaping many industries.", 'cn': '人工智能正在重塑许多行业。'},
      {'en': "Social media has changed the way we communicate.", 'cn': '社交媒体改变了我们的交流方式。'},
      {'en': "Mental health awareness has increased significantly.", 'cn': '心理健康意识已显著提高。'},
      {'en': "Remote working has become the new normal for many.", 'cn': '远程工作已成为许多人的新常态。'},
      {'en': "Biodiversity is essential for a healthy ecosystem.", 'cn': '生物多样性对健康的生态系统至关重要。'},
      {'en': "Urbanisation is happening at an unprecedented rate.", 'cn': '城市化正在以前所未有的速度发生。'},
      {'en': "That's all for this week's 6 Minute English.", 'cn': '以上就是本周的6分钟英语。'},
      {'en': "Don't forget to check out our website for more vocabulary.", 'cn': '别忘了访问我们的网站获取更多词汇。'},
      {'en': "See you next time!", 'cn': '下次再见！'},
    ];
  }

  // BBC 职场英语 (English at Work)
  List<Map<String, String>> _getBBCWorkSentences() {
    return [
      {'en': "I'd like to schedule a meeting with you.", 'cn': '我想和您安排一次会议。'},
      {'en': "Could you send me the report by end of day?", 'cn': '你能在今天结束前把报告发给我吗？'},
      {'en': "Let me walk you through the proposal.", 'cn': '让我给你详细介绍一下这个提案。'},
      {'en': "We need to touch base on this project.", 'cn': '我们需要就这个项目碰个头。'},
      {'en': "I'll loop you in on the email thread.", 'cn': '我会把你加入邮件讨论。'},
      {'en': "Can we take this offline?", 'cn': '我们可以私下讨论这个吗？'},
      {'en': "Let's circle back to that later.", 'cn': '我们稍后再讨论这个。'},
      {'en': "I'm swamped with work at the moment.", 'cn': '我现在工作忙得不可开交。'},
      {'en': "We need to think outside the box.", 'cn': '我们需要跳出固有思维。'},
      {'en': "Let's get the ball rolling on this.", 'cn': '让我们开始行动吧。'},
      {'en': "I'll get back to you on that.", 'cn': '这个问题我稍后回复你。'},
      {'en': "Can you give me a ballpark figure?", 'cn': '你能给我一个大概的数字吗？'},
      {'en': "We're on the same page.", 'cn': '我们想法一致。'},
      {'en': "Let's hit the ground running.", 'cn': '让我们快速启动。'},
      {'en': "I'll keep you posted on any updates.", 'cn': '有任何更新我会通知你。'},
      {'en': "We need to streamline our processes.", 'cn': '我们需要简化流程。'},
      {'en': "The deadline is tight but achievable.", 'cn': '截止日期很紧但可以完成。'},
      {'en': "Let's set up a recurring meeting.", 'cn': '让我们设置一个定期会议。'},
      {'en': "I'll action that immediately.", 'cn': '我会立即处理。'},
      {'en': "Thanks for your input on this.", 'cn': '感谢你对此的意见。'},
    ];
  }

  // BBC 新闻英语 (News Review)
  List<Map<String, String>> _getBBCNewsSentences() {
    return [
      {'en': "Today's top story comes from the world of politics.", 'cn': '今天的头条新闻来自政治领域。'},
      {'en': "The situation has escalated dramatically.", 'cn': '局势急剧升级。'},
      {'en': "Negotiations are at a critical juncture.", 'cn': '谈判正处于关键时刻。'},
      {'en': "The government has faced mounting pressure.", 'cn': '政府面临越来越大的压力。'},
      {'en': "A landmark decision was reached yesterday.", 'cn': '昨天做出了一项里程碑式的决定。'},
      {'en': "The economy shows signs of recovery.", 'cn': '经济显示出复苏的迹象。'},
      {'en': "Tensions remain high in the region.", 'cn': '该地区紧张局势依然严峻。'},
      {'en': "A breakthrough has been achieved in talks.", 'cn': '会谈取得了突破。'},
      {'en': "The crisis has deepened further.", 'cn': '危机进一步加深。'},
      {'en': "Leaders have called for immediate action.", 'cn': '领导人呼吁立即采取行动。'},
      {'en': "The scandal has rocked the political establishment.", 'cn': '丑闻震动了政治体制。'},
      {'en': "A state of emergency has been declared.", 'cn': '已宣布进入紧急状态。'},
      {'en': "The vote is expected to be close.", 'cn': '预计投票结果将非常接近。'},
      {'en': "Protests have erupted across the country.", 'cn': '全国各地爆发了抗议活动。'},
      {'en': "The impact is being felt worldwide.", 'cn': '影响正在全球范围内显现。'},
    ];
  }

  // BBC 地道英语 (The English We Speak)
  List<Map<String, String>> _getBBCSpeakSentences() {
    return [
      {'en': "It's raining cats and dogs out there!", 'cn': '外面下着瓢泼大雨！'},
      {'en': "I'm feeling a bit under the weather today.", 'cn': '我今天感觉有点不舒服。'},
      {'en': "That idea is a no-brainer.", 'cn': '那是个显而易见的选择。'},
      {'en': "Let's grab a bite to eat.", 'cn': '我们去吃点东西吧。'},
      {'en': "He always beats around the bush.", 'cn': '他总是拐弯抹角。'},
      {'en': "I'm going to hit the sack early tonight.", 'cn': '今晚我要早点睡。'},
      {'en': "She's got a lot on her plate right now.", 'cn': '她现在有很多事情要处理。'},
      {'en': "That's the last straw!", 'cn': '这是压垮骆驼的最后一根稻草！'},
      {'en': "Don't put all your eggs in one basket.", 'cn': '不要把所有鸡蛋放在一个篮子里。'},
      {'en': "He's barking up the wrong tree.", 'cn': '他找错对象了。'},
      {'en': "I'm going to call it a day.", 'cn': '我今天就到这里。'},
      {'en': "That really hit the spot.", 'cn': '那正合我意。'},
      {'en': "She's a breath of fresh air.", 'cn': '她让人耳目一新。'},
      {'en': "I'm on cloud nine!", 'cn': '我高兴极了！'},
      {'en': "Let's not rock the boat.", 'cn': '我们别惹麻烦了。'},
      {'en': "He spilled the beans about the surprise.", 'cn': '他泄露了惊喜的秘密。'},
      {'en': "I'm going to take it with a grain of salt.", 'cn': '我会持保留态度。'},
      {'en': "She's got cold feet about the wedding.", 'cn': '她对婚礼有点退缩。'},
    ];
  }

  // BBC 发音教程
  List<Map<String, String>> _getBBCPronunciationSentences() {
    return [
      {'en': "The 'th' sound can be voiced or voiceless.", 'cn': '"th"音可以是浊音或清音。'},
      {'en': "Put your tongue between your teeth for 'th'.", 'cn': '发"th"音时把舌头放在牙齿之间。'},
      {'en': "The schwa is the most common vowel sound in English.", 'cn': '中性元音是英语中最常见的元音。'},
      {'en': "Word stress can change the meaning of a word.", 'cn': '单词重音可以改变词义。'},
      {'en': "Practice tongue twisters to improve fluency.", 'cn': '练习绕口令来提高流利度。'},
      {'en': "She sells seashells by the seashore.", 'cn': '她在海边卖贝壳。（绕口令）'},
      {'en': "Peter Piper picked a peck of pickled peppers.", 'cn': '彼得·派珀摘了一配克腌辣椒。（绕口令）'},
      {'en': "How much wood would a woodchuck chuck?", 'cn': '土拨鼠能扔多少木头？（绕口令）'},
      {'en': "Intonation rises at the end of yes/no questions.", 'cn': '是非问句末尾语调上升。'},
      {'en': "Connected speech makes English sound more natural.", 'cn': '连读使英语听起来更自然。'},
      {'en': "The letter 'r' is not pronounced at the end of words in British English.", 'cn': '在英式英语中，单词末尾的字母r不发音。'},
      {'en': "Silent letters are common in English spelling.", 'cn': '不发音的字母在英语拼写中很常见。'},
      {'en': "Linking words together helps fluency.", 'cn': '单词连读有助于流利度。'},
      {'en': "Weak forms are used in unstressed syllables.", 'cn': '弱读形式用于非重读音节。'},
      {'en': "Practice minimal pairs to distinguish similar sounds.", 'cn': '练习最小对立对来区分相似的发音。'},
    ];
  }
}

/// 素材源信息
class MaterialSource {
  final String id;
  final String name;
  final String description;
  final String category;
  final int sentenceCount;
  final String difficulty;
  final String icon;

  MaterialSource({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.sentenceCount,
    required this.difficulty,
    required this.icon,
  });
}
