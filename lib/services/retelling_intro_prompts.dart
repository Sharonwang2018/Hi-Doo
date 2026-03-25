import 'dart:math';

/// 启发式复述引导语：随机专业引导语池 + 多维题库（年龄/绘本类型）。
/// 页面初始化时从 professionalPrompts 随机抽一条播放；多维 pick 仍可用于扩展。
class RetellingIntroPrompts {
  RetellingIntroPrompts._();

  /// 随机专业引导语池：启发式、口语化、避免“作业感”，中英一一对应
  static const List<({String zh, String en})> professionalPrompts = [
    // 你提供的 5 条
    (zh: '宝贝，这本书里哪一个画面让你觉得最有趣？快来跟我分享一下吧～', en: 'Which picture in this book did you find most fun? Come share it with me!'),
    (zh: '故事讲完啦！如果你是书里的小主角，你会想去哪里探险呢？', en: 'The story is over! If you were the main character, where would you want to go on an adventure?'),
    (zh: '书里谁是你最喜欢的好朋友呀？他做了什么了不起的事情？讲给我听听吧～', en: 'Who is your favorite friend in the book? What amazing things did they do? Tell me!'),
    (zh: '刚才看的那本书，你觉得最神奇的地方在哪里？我好想知道呀！', en: 'In the book you just read, what was the most magical part? I really want to know!'),
    (zh: '如果你来给这个故事编一个不一样的结尾，会发生什么好玩的事呢？', en: 'If you could give this story a different ending, what fun thing would happen?'),
    // 画面与细节
    (zh: '你记得最牢的是哪一页或哪一句话？给我们讲讲吧～', en: 'Which page or sentence do you remember best? Tell us about it!'),
    (zh: '书里有没有让你笑出来或有点难过的情节？说说看～', en: 'Was there a part that made you laugh or feel a little sad? Tell us!'),
    (zh: '如果只能选一个画面画下来，你会选哪个？为什么呀？', en: 'If you could only draw one picture from the book, which would you pick? Why?'),
    // 角色与联结
    (zh: '如果你是书里的一个角色，你最想当谁？为什么？', en: 'If you could be any character in the book, who would you be? Why?'),
    (zh: '书里的小主人公最厉害的地方是什么？你来讲讲～', en: 'What is the main character really good at? You tell us!'),
    (zh: '这本书里谁最需要帮助？后来怎么样了？', en: 'Who in the book needed help the most? What happened in the end?'),
    // 想象与延伸
    (zh: '如果故事还有下一页，你猜会发生什么？', en: 'If the story had one more page, what do you think would happen?'),
    (zh: '假如你可以进到书里玩一天，你最想去哪个场景？', en: 'If you could step into the book for a day, which place would you go?'),
    (zh: '这个故事里你觉得最“哇”的一刻是哪里？', en: 'What was the most “wow” moment in this story?'),
    // 感受与喜好
    (zh: '讲讲这本书里你最喜欢或印象最深的地方吧～', en: 'Tell us what you liked or remember most about this book.'),
    (zh: '看完这本书，你心里是开心、紧张还是别的？随便说说～', en: 'After reading this book, did you feel happy, excited, or something else? Just say it!'),
    (zh: '你觉得书里谁最勇敢？他做了什么事？', en: 'Who do you think was the bravest in the book? What did they do?'),
    // 复述与表达
    (zh: '用你自己的话，给没读过的人讲一讲这个故事吧～', en: 'In your own words, tell someone who hasn’t read it what this story is about.'),
    (zh: '这本书讲了一个什么故事？你记得多少就讲多少～', en: 'What is this book about? Tell us as much as you remember!'),
    (zh: '小主人公一开始遇到了什么麻烦？后来呢？', en: 'What trouble did the main character run into at first? And then what?'),
    // 好奇与追问
    (zh: '有没有哪一点你特别想再读一遍？为什么？', en: 'Is there one part you’d want to read again? Why?'),
    (zh: '书里有什么是你以前不知道的？跟我们说说～', en: 'What’s something in the book you didn’t know before? Tell us!'),
    (zh: '看完以后你最想跟谁分享这本书？你会怎么介绍？', en: 'Who would you most want to share this book with? How would you describe it?'),
    // 低龄友好、短句
    (zh: '这本书里你最喜欢谁？跟爸爸妈妈说说吧～', en: 'Who do you like best in this book? Tell us about them!'),
    (zh: '小主人公最后怎么样了？你来讲讲～', en: 'What happened to the main character in the end? You tell us!'),
    (zh: '随便讲讲这本书里你觉得好玩、难过、或者很厉害的地方～', en: 'Just tell us something from the book that was fun, sad, or really cool.'),
  ];

  /// 年龄档：preschool 3-6，primary 6-9，general 通用
  static const String agePreschool = 'preschool';
  static const String agePrimary = 'primary';
  static const String ageGeneral = 'general';

  /// 绘本类型：story 故事/情节，emotion 情绪，nature 自然/动物，adventure 冒险，general 通用
  static const String typeStory = 'story';
  static const String typeEmotion = 'emotion';
  static const String typeNature = 'nature';
  static const String typeAdventure = 'adventure';
  static const String typeGeneral = 'general';

  static final List<_IntroPrompt> _bank = [
    // 情感/联结
    _IntroPrompt(
      zh: '如果你能变成书里的一个角色，你想当谁？为什么？',
      en: 'If you could be any character in this book, who would you be and why?',
      ageBands: [agePrimary, ageGeneral],
      bookTypes: [typeStory, typeEmotion, typeGeneral],
    ),
    _IntroPrompt(
      zh: '这本书里你最想和谁做朋友？说说为什么～',
      en: 'Who in this book would you most want to be friends with? Why?',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeStory, typeEmotion, typeGeneral],
    ),
    // 想象/延伸
    _IntroPrompt(
      zh: '如果故事还有下一页，你猜会发生什么？',
      en: 'If the story had one more page, what do you think would happen?',
      ageBands: [agePrimary, ageGeneral],
      bookTypes: [typeStory, typeAdventure, typeGeneral],
    ),
    _IntroPrompt(
      zh: '这本书里你觉得最厉害或最神奇的地方是哪里？',
      en: 'What do you think is the coolest or most amazing part of this book?',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeAdventure, typeNature, typeGeneral],
    ),
    // 复述/回忆
    _IntroPrompt(
      zh: '用两三句话讲给没读过的人听，你会怎么说？',
      en: 'In two or three sentences, how would you tell someone who hasn\'t read it?',
      ageBands: [agePrimary, ageGeneral],
      bookTypes: [typeStory, typeGeneral],
    ),
    _IntroPrompt(
      zh: '哪个画面或哪句话你记得最牢？能说说吗？',
      en: 'Which picture or sentence do you remember best? Can you tell us?',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeStory, typeEmotion, typeNature, typeGeneral],
    ),
    // 喜好/开放
    _IntroPrompt(
      zh: '讲讲这本书里你最喜欢或印象最深的地方吧～',
      en: 'Tell us what you liked or remember most about this book.',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeGeneral],
    ),
    _IntroPrompt(
      zh: '随便讲讲这本书里你觉得好玩、难过、或者很厉害的地方～',
      en: 'Just tell us something from the book that was fun, sad, or really cool.',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeEmotion, typeAdventure, typeGeneral],
    ),
    // 低龄友好
    _IntroPrompt(
      zh: '这本书里你最喜欢谁？跟爸爸妈妈说说吧～',
      en: 'Who do you like best in this book? Tell us about them.',
      ageBands: [agePreschool, ageGeneral],
      bookTypes: [typeStory, typeEmotion, typeNature, typeGeneral],
    ),
    _IntroPrompt(
      zh: '小主人公遇到了什么事？你记得的话就讲讲看～',
      en: 'What happened to the main character? Tell us what you remember.',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeStory, typeAdventure, typeGeneral],
    ),
    // 自然/动物
    _IntroPrompt(
      zh: '书里的小动物（或大自然）发生了什么？你来讲讲～',
      en: 'What happened to the animals or nature in the book? You tell us.',
      ageBands: [agePreschool, agePrimary, ageGeneral],
      bookTypes: [typeNature, typeStory, typeGeneral],
    ),
  ];

  static final _rng = Random();

  /// 页面初始化时从专业引导语池随机抽一条（满足产品设计：随机专业引导语池）
  static String pickProfessional(String language) {
    final p = professionalPrompts[_rng.nextInt(professionalPrompts.length)];
    return language == 'en' ? p.en : p.zh;
  }

  /// 根据书名与概要简单推断绘本类型（无后端时用）。
  static String? inferBookType(String? title, String? summary) {
    final text = '${title ?? ''} ${summary ?? ''}'.trim();
    if (text.isEmpty) return null;
    if (RegExp(r'恐龙|动物|森林|自然|植物|海洋|昆虫|鸟').hasMatch(text)) return typeNature;
    if (RegExp(r'情绪|生气|害怕|开心|难过|担心|勇敢|朋友|爱').hasMatch(text)) return typeEmotion;
    if (RegExp(r'冒险|探险|魔法|想象|奇遇|旅行|adventure|magic').hasMatch(text)) return typeAdventure;
    return typeStory;
  }

  /// 根据语言与可选年龄档、绘本类型选一条引导语。
  /// [ageBand] 不传或传 general 时与所有年龄匹配；[bookType] 同理。
  static String pick({
    required String language,
    String? ageBand,
    String? bookType,
  }) {
    final age = ageBand ?? ageGeneral;
    final type = bookType ?? typeGeneral;
    final candidates = _bank.where((p) {
      final ageOk = p.ageBands.contains(age) || p.ageBands.contains(ageGeneral);
      final typeOk = p.bookTypes.contains(type) || p.bookTypes.contains(typeGeneral);
      return ageOk && typeOk;
    }).toList();
    if (candidates.isEmpty) {
      final fallback = _bank.first;
      return language == 'en' ? fallback.en : fallback.zh;
    }
    final chosen = candidates[_rng.nextInt(candidates.length)];
    return language == 'en' ? chosen.en : chosen.zh;
  }
}

class _IntroPrompt {
  const _IntroPrompt({
    required this.zh,
    required this.en,
    this.ageBands = const [RetellingIntroPrompts.ageGeneral],
    this.bookTypes = const [RetellingIntroPrompts.typeGeneral],
  });
  final String zh;
  final String en;
  final List<String> ageBands;
  final List<String> bookTypes;
}
