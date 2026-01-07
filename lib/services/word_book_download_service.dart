/// 词书下载服务 - 提供在线词书下载功能
class WordBookDownloadService {
  static final WordBookDownloadService instance = WordBookDownloadService._();
  WordBookDownloadService._();

  /// 根据词书名获取词书内容
  Future<Map<String, dynamic>?> fetchWordBook(String bookName) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 根据不同的词书名返回对应的词汇
    if (bookName.contains('CET-4') || bookName.contains('四级')) {
      return _getCet4Words();
    } else if (bookName.contains('CET-6') || bookName.contains('六级')) {
      return _getCet6Words();
    } else if (bookName.contains('高中') || bookName.contains('高考')) {
      return _getHighSchoolWords();
    } else if (bookName.contains('中考') || bookName.contains('初中')) {
      return _getMiddleSchoolWords();
    } else if (bookName.contains('TOEFL') || bookName.contains('托福')) {
      return _getToeflWords();
    } else if (bookName.contains('IELTS') || bookName.contains('雅思')) {
      return _getIeltsWords();
    } else if (bookName.contains('考研')) {
      return _getGraduateWords();
    } else if (bookName.contains('商务') || bookName.contains('BEC')) {
      return _getBusinessWords();
    } else if (bookName.contains('生活') || bookName.contains('日常')) {
      return _getDailyWords();
    } else if (bookName.contains('旅游')) {
      return _getTravelWords();
    } else if (bookName.contains('新概念')) {
      return _getNewConceptWords();
    }

    // 默认返回基础词汇
    return _getBasicWords();
  }

  Map<String, dynamic> _getCet4Words() {
    return {
      'bookName': 'CET-4 四级核心词汇',
      'words': [
        {'word': 'abandon', 'trans': 'v. 放弃，遗弃', 'symbol': '/əˈbændən/', 'example': 'Don\'t abandon your dreams.'},
        {'word': 'ability', 'trans': 'n. 能力，才能', 'symbol': '/əˈbɪləti/', 'example': 'She has the ability to succeed.'},
        {'word': 'abnormal', 'trans': 'adj. 不正常的', 'symbol': '/æbˈnɔːml/', 'example': 'His behavior was abnormal.'},
        {'word': 'abolish', 'trans': 'v. 废除，废止', 'symbol': '/əˈbɒlɪʃ/', 'example': 'They want to abolish the law.'},
        {'word': 'absorb', 'trans': 'v. 吸收，吸引', 'symbol': '/əbˈzɔːb/', 'example': 'Plants absorb carbon dioxide.'},
        {'word': 'abstract', 'trans': 'adj. 抽象的', 'symbol': '/ˈæbstrækt/', 'example': 'Art can be abstract.'},
        {'word': 'abundant', 'trans': 'adj. 丰富的，充裕的', 'symbol': '/əˈbʌndənt/', 'example': 'Natural resources are abundant here.'},
        {'word': 'academic', 'trans': 'adj. 学术的', 'symbol': '/ˌækəˈdemɪk/', 'example': 'Academic research is important.'},
        {'word': 'accelerate', 'trans': 'v. 加速', 'symbol': '/əkˈseləreɪt/', 'example': 'We need to accelerate the process.'},
        {'word': 'access', 'trans': 'n. 接近，通道', 'symbol': '/ˈækses/', 'example': 'We have access to the internet.'},
        {'word': 'accommodate', 'trans': 'v. 容纳，提供住宿', 'symbol': '/əˈkɒmədeɪt/', 'example': 'The hotel can accommodate 200 guests.'},
        {'word': 'accompany', 'trans': 'v. 陪伴，伴随', 'symbol': '/əˈkʌmpəni/', 'example': 'Let me accompany you home.'},
        {'word': 'accomplish', 'trans': 'v. 完成，实现', 'symbol': '/əˈkʌmplɪʃ/', 'example': 'We accomplished our goal.'},
        {'word': 'account', 'trans': 'n. 账户；v. 解释', 'symbol': '/əˈkaʊnt/', 'example': 'Open a bank account.'},
        {'word': 'accumulate', 'trans': 'v. 积累，积聚', 'symbol': '/əˈkjuːmjəleɪt/', 'example': 'Wealth accumulates over time.'},
        {'word': 'accurate', 'trans': 'adj. 精确的，准确的', 'symbol': '/ˈækjərət/', 'example': 'The data is accurate.'},
        {'word': 'achieve', 'trans': 'v. 达到，实现', 'symbol': '/əˈtʃiːv/', 'example': 'You can achieve your dreams.'},
        {'word': 'acknowledge', 'trans': 'v. 承认，感谢', 'symbol': '/əkˈnɒlɪdʒ/', 'example': 'I acknowledge my mistake.'},
        {'word': 'acquire', 'trans': 'v. 获得，取得', 'symbol': '/əˈkwaɪər/', 'example': 'Acquire new skills.'},
        {'word': 'adapt', 'trans': 'v. 适应，改编', 'symbol': '/əˈdæpt/', 'example': 'Adapt to changes.'},
        {'word': 'adequate', 'trans': 'adj. 足够的，适当的', 'symbol': '/ˈædɪkwət/', 'example': 'Adequate sleep is important.'},
        {'word': 'adjust', 'trans': 'v. 调整，适应', 'symbol': '/əˈdʒʌst/', 'example': 'Adjust the settings.'},
        {'word': 'admire', 'trans': 'v. 钦佩，欣赏', 'symbol': '/ədˈmaɪər/', 'example': 'I admire your courage.'},
        {'word': 'admit', 'trans': 'v. 承认，准许进入', 'symbol': '/ədˈmɪt/', 'example': 'Admit your mistake.'},
        {'word': 'adopt', 'trans': 'v. 采用，收养', 'symbol': '/əˈdɒpt/', 'example': 'Adopt new methods.'},
        {'word': 'advance', 'trans': 'v. 前进；n. 进步', 'symbol': '/ədˈvɑːns/', 'example': 'Technology advances rapidly.'},
        {'word': 'advantage', 'trans': 'n. 优势，好处', 'symbol': '/ədˈvɑːntɪdʒ/', 'example': 'Take advantage of opportunities.'},
        {'word': 'adventure', 'trans': 'n. 冒险', 'symbol': '/ədˈventʃər/', 'example': 'Life is an adventure.'},
        {'word': 'advertise', 'trans': 'v. 做广告', 'symbol': '/ˈædvətaɪz/', 'example': 'Advertise the product.'},
        {'word': 'affect', 'trans': 'v. 影响，感动', 'symbol': '/əˈfekt/', 'example': 'It affects everyone.'},
      ],
    };
  }

  Map<String, dynamic> _getCet6Words() {
    return {
      'bookName': 'CET-6 六级核心词汇',
      'words': [
        {'word': 'abbreviate', 'trans': 'v. 缩写，缩短', 'symbol': '/əˈbriːvieɪt/', 'example': 'Abbreviate the document.'},
        {'word': 'abide', 'trans': 'v. 遵守，忍受', 'symbol': '/əˈbaɪd/', 'example': 'Abide by the rules.'},
        {'word': 'abstain', 'trans': 'v. 戒除，弃权', 'symbol': '/əbˈsteɪn/', 'example': 'Abstain from voting.'},
        {'word': 'absurd', 'trans': 'adj. 荒谬的', 'symbol': '/əbˈsɜːd/', 'example': 'The idea is absurd.'},
        {'word': 'accelerate', 'trans': 'v. 加速，促进', 'symbol': '/əkˈseləreɪt/', 'example': 'Accelerate economic growth.'},
        {'word': 'accessible', 'trans': 'adj. 可接近的', 'symbol': '/əkˈsesəbl/', 'example': 'Make education accessible.'},
        {'word': 'acclaim', 'trans': 'v. 称赞；n. 喝彩', 'symbol': '/əˈkleɪm/', 'example': 'The film received acclaim.'},
        {'word': 'accustom', 'trans': 'v. 使习惯', 'symbol': '/əˈkʌstəm/', 'example': 'Accustom yourself to hard work.'},
        {'word': 'acquaint', 'trans': 'v. 使认识，使熟悉', 'symbol': '/əˈkweɪnt/', 'example': 'Acquaint yourself with the rules.'},
        {'word': 'adjacent', 'trans': 'adj. 邻近的', 'symbol': '/əˈdʒeɪsnt/', 'example': 'Adjacent buildings.'},
        {'word': 'adverse', 'trans': 'adj. 不利的，有害的', 'symbol': '/ˈædvɜːs/', 'example': 'Adverse weather conditions.'},
        {'word': 'advocate', 'trans': 'v. 提倡；n. 倡导者', 'symbol': '/ˈædvəkeɪt/', 'example': 'Advocate for change.'},
        {'word': 'aesthetic', 'trans': 'adj. 美学的', 'symbol': '/iːsˈθetɪk/', 'example': 'Aesthetic value.'},
        {'word': 'affiliate', 'trans': 'v. 使附属', 'symbol': '/əˈfɪlieɪt/', 'example': 'Affiliated companies.'},
        {'word': 'afflict', 'trans': 'v. 折磨，使痛苦', 'symbol': '/əˈflɪkt/', 'example': 'Diseases afflict many.'},
        {'word': 'aggregate', 'trans': 'v. 聚集；n. 总计', 'symbol': '/ˈæɡrɪɡət/', 'example': 'Aggregate data.'},
        {'word': 'aggravate', 'trans': 'v. 加重，恶化', 'symbol': '/ˈæɡrəveɪt/', 'example': 'Don\'t aggravate the situation.'},
        {'word': 'agitate', 'trans': 'v. 搅动，激动', 'symbol': '/ˈædʒɪteɪt/', 'example': 'Agitate for reform.'},
        {'word': 'alienate', 'trans': 'v. 使疏远', 'symbol': '/ˈeɪliəneɪt/', 'example': 'Don\'t alienate your friends.'},
        {'word': 'alleviate', 'trans': 'v. 减轻，缓和', 'symbol': '/əˈliːvieɪt/', 'example': 'Alleviate the pain.'},
      ],
    };
  }

  Map<String, dynamic> _getHighSchoolWords() {
    return {
      'bookName': '高中英语核心词汇',
      'words': [
        {'word': 'ability', 'trans': 'n. 能力', 'symbol': '/əˈbɪləti/', 'example': 'Reading ability is important.'},
        {'word': 'about', 'trans': 'prep. 关于', 'symbol': '/əˈbaʊt/', 'example': 'Tell me about it.'},
        {'word': 'above', 'trans': 'prep. 在...上面', 'symbol': '/əˈbʌv/', 'example': 'The sky above us.'},
        {'word': 'accept', 'trans': 'v. 接受', 'symbol': '/əkˈsept/', 'example': 'Accept the offer.'},
        {'word': 'accident', 'trans': 'n. 事故，意外', 'symbol': '/ˈæksɪdənt/', 'example': 'A car accident.'},
        {'word': 'achieve', 'trans': 'v. 实现，达到', 'symbol': '/əˈtʃiːv/', 'example': 'Achieve your goal.'},
        {'word': 'across', 'trans': 'prep. 穿过', 'symbol': '/əˈkrɒs/', 'example': 'Walk across the street.'},
        {'word': 'action', 'trans': 'n. 行动', 'symbol': '/ˈækʃn/', 'example': 'Take action now.'},
        {'word': 'activity', 'trans': 'n. 活动', 'symbol': '/ækˈtɪvəti/', 'example': 'Outdoor activities.'},
        {'word': 'actually', 'trans': 'adv. 实际上', 'symbol': '/ˈæktʃuəli/', 'example': 'Actually, I disagree.'},
        {'word': 'add', 'trans': 'v. 增加，添加', 'symbol': '/æd/', 'example': 'Add some sugar.'},
        {'word': 'address', 'trans': 'n. 地址', 'symbol': '/əˈdres/', 'example': 'What\'s your address?'},
        {'word': 'advantage', 'trans': 'n. 优势', 'symbol': '/ədˈvɑːntɪdʒ/', 'example': 'Have an advantage.'},
        {'word': 'advice', 'trans': 'n. 建议', 'symbol': '/ədˈvaɪs/', 'example': 'Good advice.'},
        {'word': 'afford', 'trans': 'v. 负担得起', 'symbol': '/əˈfɔːd/', 'example': 'Can\'t afford it.'},
        {'word': 'afraid', 'trans': 'adj. 害怕的', 'symbol': '/əˈfreɪd/', 'example': 'Don\'t be afraid.'},
        {'word': 'after', 'trans': 'prep. 在...之后', 'symbol': '/ˈɑːftər/', 'example': 'After school.'},
        {'word': 'again', 'trans': 'adv. 再次', 'symbol': '/əˈɡen/', 'example': 'Try again.'},
        {'word': 'against', 'trans': 'prep. 反对', 'symbol': '/əˈɡenst/', 'example': 'Against the wall.'},
        {'word': 'age', 'trans': 'n. 年龄', 'symbol': '/eɪdʒ/', 'example': 'What\'s your age?'},
      ],
    };
  }

  Map<String, dynamic> _getMiddleSchoolWords() {
    return {
      'bookName': '中考英语核心词汇',
      'words': [
        {'word': 'able', 'trans': 'adj. 能够的', 'symbol': '/ˈeɪbl/', 'example': 'Be able to swim.'},
        {'word': 'about', 'trans': 'prep. 关于', 'symbol': '/əˈbaʊt/', 'example': 'What about you?'},
        {'word': 'above', 'trans': 'prep. 在上方', 'symbol': '/əˈbʌv/', 'example': 'Above the table.'},
        {'word': 'accident', 'trans': 'n. 事故', 'symbol': '/ˈæksɪdənt/', 'example': 'An accident happened.'},
        {'word': 'across', 'trans': 'prep. 穿过', 'symbol': '/əˈkrɒs/', 'example': 'Across the road.'},
        {'word': 'act', 'trans': 'v. 行动', 'symbol': '/ækt/', 'example': 'Act quickly.'},
        {'word': 'activity', 'trans': 'n. 活动', 'symbol': '/ækˈtɪvəti/', 'example': 'School activity.'},
        {'word': 'add', 'trans': 'v. 添加', 'symbol': '/æd/', 'example': 'Add more water.'},
        {'word': 'address', 'trans': 'n. 地址', 'symbol': '/əˈdres/', 'example': 'Home address.'},
        {'word': 'advice', 'trans': 'n. 建议', 'symbol': '/ədˈvaɪs/', 'example': 'Take my advice.'},
        {'word': 'afraid', 'trans': 'adj. 害怕', 'symbol': '/əˈfreɪd/', 'example': 'I\'m afraid of dogs.'},
        {'word': 'after', 'trans': 'prep. 在...后', 'symbol': '/ˈɑːftər/', 'example': 'After lunch.'},
        {'word': 'afternoon', 'trans': 'n. 下午', 'symbol': '/ˌɑːftərˈnuːn/', 'example': 'Good afternoon.'},
        {'word': 'again', 'trans': 'adv. 再次', 'symbol': '/əˈɡen/', 'example': 'Say it again.'},
        {'word': 'age', 'trans': 'n. 年龄', 'symbol': '/eɪdʒ/', 'example': 'At the age of 10.'},
      ],
    };
  }

  Map<String, dynamic> _getToeflWords() {
    return {
      'bookName': 'TOEFL 托福核心词汇',
      'words': [
        {'word': 'abandon', 'trans': 'v. 放弃', 'symbol': '/əˈbændən/', 'example': 'Abandon the project.'},
        {'word': 'aberrant', 'trans': 'adj. 异常的', 'symbol': '/æˈberənt/', 'example': 'Aberrant behavior.'},
        {'word': 'abolish', 'trans': 'v. 废除', 'symbol': '/əˈbɒlɪʃ/', 'example': 'Abolish slavery.'},
        {'word': 'abridge', 'trans': 'v. 删节', 'symbol': '/əˈbrɪdʒ/', 'example': 'Abridge the novel.'},
        {'word': 'abstain', 'trans': 'v. 戒绝', 'symbol': '/əbˈsteɪn/', 'example': 'Abstain from alcohol.'},
        {'word': 'abstract', 'trans': 'adj. 抽象的', 'symbol': '/ˈæbstrækt/', 'example': 'Abstract thinking.'},
        {'word': 'abundant', 'trans': 'adj. 丰富的', 'symbol': '/əˈbʌndənt/', 'example': 'Abundant resources.'},
        {'word': 'accelerate', 'trans': 'v. 加速', 'symbol': '/əkˈseləreɪt/', 'example': 'Accelerate development.'},
        {'word': 'accessible', 'trans': 'adj. 可获得的', 'symbol': '/əkˈsesəbl/', 'example': 'Accessible information.'},
        {'word': 'accommodate', 'trans': 'v. 容纳', 'symbol': '/əˈkɒmədeɪt/', 'example': 'Accommodate guests.'},
        {'word': 'accumulate', 'trans': 'v. 积累', 'symbol': '/əˈkjuːmjəleɪt/', 'example': 'Accumulate knowledge.'},
        {'word': 'accurate', 'trans': 'adj. 准确的', 'symbol': '/ˈækjərət/', 'example': 'Accurate measurement.'},
        {'word': 'acknowledge', 'trans': 'v. 承认', 'symbol': '/əkˈnɒlɪdʒ/', 'example': 'Acknowledge receipt.'},
        {'word': 'acquire', 'trans': 'v. 获取', 'symbol': '/əˈkwaɪər/', 'example': 'Acquire skills.'},
        {'word': 'adapt', 'trans': 'v. 适应', 'symbol': '/əˈdæpt/', 'example': 'Adapt to environment.'},
      ],
    };
  }

  Map<String, dynamic> _getIeltsWords() {
    return {
      'bookName': 'IELTS 雅思核心词汇',
      'words': [
        {'word': 'abandon', 'trans': 'v. 放弃，遗弃', 'symbol': '/əˈbændən/', 'example': 'Abandon the plan.'},
        {'word': 'ability', 'trans': 'n. 能力', 'symbol': '/əˈbɪləti/', 'example': 'Language ability.'},
        {'word': 'abroad', 'trans': 'adv. 在国外', 'symbol': '/əˈbrɔːd/', 'example': 'Study abroad.'},
        {'word': 'absence', 'trans': 'n. 缺席', 'symbol': '/ˈæbsəns/', 'example': 'In the absence of.'},
        {'word': 'absolute', 'trans': 'adj. 绝对的', 'symbol': '/ˈæbsəluːt/', 'example': 'Absolute truth.'},
        {'word': 'absorb', 'trans': 'v. 吸收', 'symbol': '/əbˈzɔːb/', 'example': 'Absorb information.'},
        {'word': 'abstract', 'trans': 'adj. 抽象的', 'symbol': '/ˈæbstrækt/', 'example': 'Abstract concept.'},
        {'word': 'academic', 'trans': 'adj. 学术的', 'symbol': '/ˌækəˈdemɪk/', 'example': 'Academic writing.'},
        {'word': 'accelerate', 'trans': 'v. 加速', 'symbol': '/əkˈseləreɪt/', 'example': 'Accelerate growth.'},
        {'word': 'accept', 'trans': 'v. 接受', 'symbol': '/əkˈsept/', 'example': 'Accept the offer.'},
        {'word': 'access', 'trans': 'n. 进入；v. 访问', 'symbol': '/ˈækses/', 'example': 'Access to education.'},
        {'word': 'accompany', 'trans': 'v. 陪伴', 'symbol': '/əˈkʌmpəni/', 'example': 'Accompany a friend.'},
        {'word': 'accomplish', 'trans': 'v. 完成', 'symbol': '/əˈkʌmplɪʃ/', 'example': 'Accomplish the task.'},
        {'word': 'account', 'trans': 'n. 账户', 'symbol': '/əˈkaʊnt/', 'example': 'Bank account.'},
        {'word': 'accurate', 'trans': 'adj. 精确的', 'symbol': '/ˈækjərət/', 'example': 'Accurate description.'},
      ],
    };
  }

  Map<String, dynamic> _getGraduateWords() {
    return {
      'bookName': '考研英语核心词汇',
      'words': [
        {'word': 'abandon', 'trans': 'v. 放弃，遗弃', 'symbol': '/əˈbændən/', 'example': 'Abandon hope.'},
        {'word': 'abbreviation', 'trans': 'n. 缩写', 'symbol': '/əˌbriːviˈeɪʃn/', 'example': 'Use abbreviations.'},
        {'word': 'abide', 'trans': 'v. 遵守', 'symbol': '/əˈbaɪd/', 'example': 'Abide by the law.'},
        {'word': 'abnormal', 'trans': 'adj. 反常的', 'symbol': '/æbˈnɔːml/', 'example': 'Abnormal behavior.'},
        {'word': 'abolish', 'trans': 'v. 废除', 'symbol': '/əˈbɒlɪʃ/', 'example': 'Abolish the system.'},
        {'word': 'abound', 'trans': 'v. 大量存在', 'symbol': '/əˈbaʊnd/', 'example': 'Fish abound in the lake.'},
        {'word': 'abrupt', 'trans': 'adj. 突然的', 'symbol': '/əˈbrʌpt/', 'example': 'An abrupt change.'},
        {'word': 'absorb', 'trans': 'v. 吸收', 'symbol': '/əbˈzɔːb/', 'example': 'Absorb nutrients.'},
        {'word': 'abstract', 'trans': 'adj. 抽象的', 'symbol': '/ˈæbstrækt/', 'example': 'Abstract art.'},
        {'word': 'absurd', 'trans': 'adj. 荒谬的', 'symbol': '/əbˈsɜːd/', 'example': 'An absurd idea.'},
        {'word': 'abundant', 'trans': 'adj. 丰富的', 'symbol': '/əˈbʌndənt/', 'example': 'Abundant evidence.'},
        {'word': 'abuse', 'trans': 'v. 滥用', 'symbol': '/əˈbjuːz/', 'example': 'Abuse power.'},
        {'word': 'academic', 'trans': 'adj. 学术的', 'symbol': '/ˌækəˈdemɪk/', 'example': 'Academic research.'},
        {'word': 'accelerate', 'trans': 'v. 加速', 'symbol': '/əkˈseləreɪt/', 'example': 'Accelerate the process.'},
        {'word': 'access', 'trans': 'n. 入口', 'symbol': '/ˈækses/', 'example': 'Access to knowledge.'},
      ],
    };
  }

  Map<String, dynamic> _getBusinessWords() {
    return {
      'bookName': '商务英语核心词汇',
      'words': [
        {'word': 'account', 'trans': 'n. 账户', 'symbol': '/əˈkaʊnt/', 'example': 'Open an account.'},
        {'word': 'acquisition', 'trans': 'n. 收购', 'symbol': '/ˌækwɪˈzɪʃn/', 'example': 'Company acquisition.'},
        {'word': 'agenda', 'trans': 'n. 议程', 'symbol': '/əˈdʒendə/', 'example': 'Meeting agenda.'},
        {'word': 'agreement', 'trans': 'n. 协议', 'symbol': '/əˈɡriːmənt/', 'example': 'Sign an agreement.'},
        {'word': 'asset', 'trans': 'n. 资产', 'symbol': '/ˈæset/', 'example': 'Company assets.'},
        {'word': 'audit', 'trans': 'n. 审计', 'symbol': '/ˈɔːdɪt/', 'example': 'Financial audit.'},
        {'word': 'balance', 'trans': 'n. 余额', 'symbol': '/ˈbæləns/', 'example': 'Account balance.'},
        {'word': 'bankrupt', 'trans': 'adj. 破产的', 'symbol': '/ˈbæŋkrʌpt/', 'example': 'Go bankrupt.'},
        {'word': 'benefit', 'trans': 'n. 利益', 'symbol': '/ˈbenɪfɪt/', 'example': 'Employee benefits.'},
        {'word': 'bidding', 'trans': 'n. 投标', 'symbol': '/ˈbɪdɪŋ/', 'example': 'Competitive bidding.'},
        {'word': 'bond', 'trans': 'n. 债券', 'symbol': '/bɒnd/', 'example': 'Government bond.'},
        {'word': 'budget', 'trans': 'n. 预算', 'symbol': '/ˈbʌdʒɪt/', 'example': 'Annual budget.'},
        {'word': 'capital', 'trans': 'n. 资本', 'symbol': '/ˈkæpɪtl/', 'example': 'Raise capital.'},
        {'word': 'commerce', 'trans': 'n. 商业', 'symbol': '/ˈkɒmɜːs/', 'example': 'E-commerce.'},
        {'word': 'contract', 'trans': 'n. 合同', 'symbol': '/ˈkɒntrækt/', 'example': 'Sign a contract.'},
      ],
    };
  }

  Map<String, dynamic> _getDailyWords() {
    return {
      'bookName': '日常生活英语词汇',
      'words': [
        {'word': 'breakfast', 'trans': 'n. 早餐', 'symbol': '/ˈbrekfəst/', 'example': 'Have breakfast.'},
        {'word': 'lunch', 'trans': 'n. 午餐', 'symbol': '/lʌntʃ/', 'example': 'Lunch time.'},
        {'word': 'dinner', 'trans': 'n. 晚餐', 'symbol': '/ˈdɪnər/', 'example': 'Family dinner.'},
        {'word': 'shopping', 'trans': 'n. 购物', 'symbol': '/ˈʃɒpɪŋ/', 'example': 'Go shopping.'},
        {'word': 'weather', 'trans': 'n. 天气', 'symbol': '/ˈweðər/', 'example': 'Nice weather.'},
        {'word': 'weekend', 'trans': 'n. 周末', 'symbol': '/ˌwiːkˈend/', 'example': 'On weekends.'},
        {'word': 'holiday', 'trans': 'n. 假日', 'symbol': '/ˈhɒlədeɪ/', 'example': 'Summer holiday.'},
        {'word': 'friend', 'trans': 'n. 朋友', 'symbol': '/frend/', 'example': 'Best friend.'},
        {'word': 'family', 'trans': 'n. 家庭', 'symbol': '/ˈfæməli/', 'example': 'Family time.'},
        {'word': 'home', 'trans': 'n. 家', 'symbol': '/həʊm/', 'example': 'Go home.'},
        {'word': 'work', 'trans': 'n. 工作', 'symbol': '/wɜːk/', 'example': 'Go to work.'},
        {'word': 'school', 'trans': 'n. 学校', 'symbol': '/skuːl/', 'example': 'Go to school.'},
        {'word': 'hospital', 'trans': 'n. 医院', 'symbol': '/ˈhɒspɪtl/', 'example': 'Visit hospital.'},
        {'word': 'restaurant', 'trans': 'n. 餐厅', 'symbol': '/ˈrestrɒnt/', 'example': 'Chinese restaurant.'},
        {'word': 'supermarket', 'trans': 'n. 超市', 'symbol': '/ˈsuːpəmɑːkɪt/', 'example': 'Go to supermarket.'},
      ],
    };
  }

  Map<String, dynamic> _getTravelWords() {
    return {
      'bookName': '旅游英语词汇',
      'words': [
        {'word': 'airport', 'trans': 'n. 机场', 'symbol': '/ˈeəpɔːt/', 'example': 'At the airport.'},
        {'word': 'passport', 'trans': 'n. 护照', 'symbol': '/ˈpɑːspɔːt/', 'example': 'Show your passport.'},
        {'word': 'visa', 'trans': 'n. 签证', 'symbol': '/ˈviːzə/', 'example': 'Apply for a visa.'},
        {'word': 'luggage', 'trans': 'n. 行李', 'symbol': '/ˈlʌɡɪdʒ/', 'example': 'Check luggage.'},
        {'word': 'reservation', 'trans': 'n. 预订', 'symbol': '/ˌrezəˈveɪʃn/', 'example': 'Make a reservation.'},
        {'word': 'hotel', 'trans': 'n. 酒店', 'symbol': '/həʊˈtel/', 'example': 'Hotel room.'},
        {'word': 'tour', 'trans': 'n. 旅游', 'symbol': '/tʊər/', 'example': 'City tour.'},
        {'word': 'guide', 'trans': 'n. 导游', 'symbol': '/ɡaɪd/', 'example': 'Tour guide.'},
        {'word': 'ticket', 'trans': 'n. 票', 'symbol': '/ˈtɪkɪt/', 'example': 'Buy a ticket.'},
        {'word': 'destination', 'trans': 'n. 目的地', 'symbol': '/ˌdestɪˈneɪʃn/', 'example': 'Final destination.'},
        {'word': 'souvenir', 'trans': 'n. 纪念品', 'symbol': '/ˌsuːvəˈnɪər/', 'example': 'Buy souvenirs.'},
        {'word': 'currency', 'trans': 'n. 货币', 'symbol': '/ˈkʌrənsi/', 'example': 'Exchange currency.'},
        {'word': 'customs', 'trans': 'n. 海关', 'symbol': '/ˈkʌstəmz/', 'example': 'Go through customs.'},
        {'word': 'departure', 'trans': 'n. 出发', 'symbol': '/dɪˈpɑːtʃər/', 'example': 'Departure time.'},
        {'word': 'arrival', 'trans': 'n. 到达', 'symbol': '/əˈraɪvl/', 'example': 'Arrival gate.'},
      ],
    };
  }

  Map<String, dynamic> _getNewConceptWords() {
    return {
      'bookName': '新概念英语词汇',
      'words': [
        {'word': 'excuse', 'trans': 'v. 原谅', 'symbol': '/ɪkˈskjuːz/', 'example': 'Excuse me.'},
        {'word': 'pardon', 'trans': 'n. 原谅', 'symbol': '/ˈpɑːdn/', 'example': 'I beg your pardon.'},
        {'word': 'handbag', 'trans': 'n. 手提包', 'symbol': '/ˈhændbæɡ/', 'example': 'A leather handbag.'},
        {'word': 'umbrella', 'trans': 'n. 雨伞', 'symbol': '/ʌmˈbrelə/', 'example': 'Take an umbrella.'},
        {'word': 'ticket', 'trans': 'n. 票', 'symbol': '/ˈtɪkɪt/', 'example': 'Buy a ticket.'},
        {'word': 'number', 'trans': 'n. 号码', 'symbol': '/ˈnʌmbər/', 'example': 'Phone number.'},
        {'word': 'nationality', 'trans': 'n. 国籍', 'symbol': '/ˌnæʃəˈnæləti/', 'example': 'What\'s your nationality?'},
        {'word': 'keyboard', 'trans': 'n. 键盘', 'symbol': '/ˈkiːbɔːd/', 'example': 'Computer keyboard.'},
        {'word': 'operator', 'trans': 'n. 操作员', 'symbol': '/ˈɒpəreɪtər/', 'example': 'Telephone operator.'},
        {'word': 'engineer', 'trans': 'n. 工程师', 'symbol': '/ˌendʒɪˈnɪər/', 'example': 'Software engineer.'},
        {'word': 'policeman', 'trans': 'n. 警察', 'symbol': '/pəˈliːsmən/', 'example': 'Call a policeman.'},
        {'word': 'postman', 'trans': 'n. 邮递员', 'symbol': '/ˈpəʊstmən/', 'example': 'The postman delivers mail.'},
        {'word': 'nurse', 'trans': 'n. 护士', 'symbol': '/nɜːs/', 'example': 'The nurse helps patients.'},
        {'word': 'hairdresser', 'trans': 'n. 理发师', 'symbol': '/ˈheədresər/', 'example': 'Visit the hairdresser.'},
        {'word': 'housewife', 'trans': 'n. 家庭主妇', 'symbol': '/ˈhaʊswaɪf/', 'example': 'She is a housewife.'},
      ],
    };
  }

  Map<String, dynamic> _getBasicWords() {
    return {
      'bookName': '基础英语词汇',
      'words': [
        {'word': 'hello', 'trans': 'int. 你好', 'symbol': '/həˈləʊ/', 'example': 'Hello, how are you?'},
        {'word': 'goodbye', 'trans': 'int. 再见', 'symbol': '/ˌɡʊdˈbaɪ/', 'example': 'Goodbye, see you later.'},
        {'word': 'thank', 'trans': 'v. 感谢', 'symbol': '/θæŋk/', 'example': 'Thank you very much.'},
        {'word': 'please', 'trans': 'adv. 请', 'symbol': '/pliːz/', 'example': 'Please help me.'},
        {'word': 'sorry', 'trans': 'adj. 抱歉的', 'symbol': '/ˈsɒri/', 'example': 'I\'m sorry.'},
        {'word': 'yes', 'trans': 'adv. 是', 'symbol': '/jes/', 'example': 'Yes, I can.'},
        {'word': 'no', 'trans': 'adv. 不', 'symbol': '/nəʊ/', 'example': 'No, thanks.'},
        {'word': 'good', 'trans': 'adj. 好的', 'symbol': '/ɡʊd/', 'example': 'Good morning.'},
        {'word': 'bad', 'trans': 'adj. 坏的', 'symbol': '/bæd/', 'example': 'Bad weather.'},
        {'word': 'big', 'trans': 'adj. 大的', 'symbol': '/bɪɡ/', 'example': 'A big house.'},
        {'word': 'small', 'trans': 'adj. 小的', 'symbol': '/smɔːl/', 'example': 'A small dog.'},
        {'word': 'happy', 'trans': 'adj. 快乐的', 'symbol': '/ˈhæpi/', 'example': 'Happy birthday.'},
        {'word': 'sad', 'trans': 'adj. 悲伤的', 'symbol': '/sæd/', 'example': 'I feel sad.'},
        {'word': 'love', 'trans': 'n. 爱', 'symbol': '/lʌv/', 'example': 'I love you.'},
        {'word': 'like', 'trans': 'v. 喜欢', 'symbol': '/laɪk/', 'example': 'I like it.'},
      ],
    };
  }
}
