import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english('English'),
  hindi('Hindi'),
  hinglish('Hinglish');

  const AppLanguage(this.label);
  final String label;

  static AppLanguage fromLabel(String label) {
    return AppLanguage.values.firstWhere(
      (language) => language.label == label,
      orElse: () => AppLanguage.english,
    );
  }
}

class AppLanguageController extends ChangeNotifier {
  static const _prefsKey = 'app_language';

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguage.fromLabel(
      prefs.getString(_prefsKey) ?? AppLanguage.english.label,
    );
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.label);
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing above this context.');
    return scope!.notifier!;
  }

  static AppLanguage languageOf(BuildContext context) {
    return controllerOf(context).language;
  }
}

class AppLocalizations {
  AppLocalizations(this.language);

  final AppLanguage language;

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(AppLanguageScope.languageOf(context));
  }

  String text(String value) {
    if (language != AppLanguage.hindi) return value;
    return _hi[value] ?? value;
  }
}

extension AppTextLocalizations on String {
  String tr(BuildContext context) => AppLocalizations.of(context).text(this);
}

const Map<String, String> _hi = {
  'English': 'English',
  'Hindi': 'Hindi',
  'Hinglish': 'Hinglish',
  'Skip': 'छोड़ें',
  'Next': 'आगे',
  'Get Started': 'शुरू करें',
  'Welcome to Trandia': 'Trandia में आपका स्वागत है',
  'Your social hub to connect and share.': 'जुड़ने और शेयर करने का आपका सोशल हब।',
  'Explore Features': 'फीचर्स देखें',
  'Chat, follow, and discover new content daily.': 'चैट करें, फॉलो करें और रोज नया कंटेंट खोजें।',
  'Stay Updated': 'अपडेट रहें',
  'Receive notifications and never miss out.': 'नोटिफिकेशन पाएं और कुछ भी मिस न करें।',
  'Welcome back': 'वापसी पर स्वागत है',
  'Sign in to continue': 'जारी रखने के लिए साइन इन करें',
  'Email': 'ईमेल',
  'Password': 'पासवर्ड',
  'Enter your password': 'अपना पासवर्ड दर्ज करें',
  'Forgot password?': 'पासवर्ड भूल गए?',
  'Sign in': 'साइन इन',
  'Signing in...': 'साइन इन हो रहा है...',
  'OR': 'या',
  'Continue with Google': 'Google के साथ जारी रखें',
  "Don't have an account?  ": 'खाता नहीं है?  ',
  'Sign up': 'साइन अप',
  'Create account': 'खाता बनाएं',
  'Join the conversation': 'बातचीत में शामिल हों',
  'Name': 'नाम',
  'Username': 'यूजरनेम',
  'Your full name': 'आपका पूरा नाम',
  'Create a password': 'पासवर्ड बनाएं',
  'Sending verification...': 'वेरिफिकेशन भेजा जा रहा है...',
  'Continue': 'जारी रखें',
  'Already have an account?  ': 'पहले से खाता है?  ',
  'Try instead:': 'इसके बजाय आजमाएं:',
  'SELECT YOUR DATE OF BIRTH': 'अपनी जन्म तिथि चुनें',
  'Check your email': 'अपना ईमेल देखें',
  'We sent a verification link to': 'हमने वेरिफिकेशन लिंक भेजा है',
  'Open Email App': 'ईमेल ऐप खोलें',
  "I've Verified - Continue": 'मैंने वेरिफाई कर लिया - जारी रखें',
  'Sending...': 'भेजा जा रहा है...',
  'Resend in ': 'फिर भेजें ',
  'Resend verification email': 'वेरिफिकेशन ईमेल फिर भेजें',
  '<- Go back': '<- वापस जाएं',
  'Messages': 'मैसेज',
  'Search messages': 'मैसेज खोजें',
  'ACTIVE NOW': 'अभी एक्टिव',
  'Could not load chats': 'चैट लोड नहीं हो सकीं',
  'Retry': 'फिर कोशिश करें',
  'CHATS': 'चैट',
  'No messages yet': 'अभी कोई मैसेज नहीं',
  'Search for someone to start chatting': 'चैट शुरू करने के लिए किसी को खोजें',
  'Message': 'मैसेज',
  'now': 'अभी',
  'Reply': 'जवाब दें',
  'Delete': 'डिलीट',
  'Delete Chat': 'चैट डिलीट करें',
  'Delete this conversation? This cannot be undone.': 'यह बातचीत डिलीट करें? इसे वापस नहीं किया जा सकता।',
  'Cancel': 'रद्द करें',
  'Delete Message': 'मैसेज डिलीट करें',
  'Delete this message for everyone?': 'यह मैसेज सभी के लिए डिलीट करें?',
  'Could not load messages': 'मैसेज लोड नहीं हो सके',
  'Replying to': 'जवाब दे रहे हैं',
  'End-to-end encrypted': 'एंड-टू-एंड एन्क्रिप्टेड',
  'Messages are secured with end-to-end encryption.\nOnly you and the recipient can read them.': 'मैसेज एंड-टू-एंड एन्क्रिप्शन से सुरक्षित हैं।\nसिर्फ आप और प्राप्तकर्ता इन्हें पढ़ सकते हैं।',
  'Notifications': 'नोटिफिकेशन',
  'All': 'सभी',
  'Follows': 'फॉलो',
  'No notifications yet': 'अभी कोई नोटिफिकेशन नहीं',
  "When someone follows you, it'll show up here": 'जब कोई आपको फॉलो करेगा, वह यहां दिखेगा',
  "Couldn't load notifications": 'नोटिफिकेशन लोड नहीं हो सके',
  'Check your connection and try again': 'कनेक्शन जांचें और फिर कोशिश करें',
  'Follow': 'फॉलो',
  'Follow back': 'वापस फॉलो करें',
  'Settings': 'सेटिंग्स',
  'Search settings': 'सेटिंग्स खोजें',
  'ACCOUNT': 'अकाउंट',
  'Edit profile': 'प्रोफाइल एडिट करें',
  'Name, bio, links and photo': 'नाम, बायो, लिंक और फोटो',
  'Privacy': 'प्राइवेसी',
  'Private account, mentions, tags': 'प्राइवेट अकाउंट, मेंशन, टैग',
  'Security': 'सुरक्षा',
  'Password and login activity': 'पासवर्ड और लॉगिन गतिविधि',
  'PREFERENCES': 'पसंद',
  'Activity status': 'एक्टिविटी स्टेटस',
  'Show when you are active': 'जब आप एक्टिव हों तो दिखाएं',
  'Private account': 'प्राइवेट अकाउंट',
  'Only followers see your posts': 'सिर्फ फॉलोअर आपकी पोस्ट देखें',
  'Language': 'भाषा',
  'Parental Control': 'पैरेंटल कंट्रोल',
  'MORE': 'और',
  'Saved': 'सेव्ड',
  'Posts and collections': 'पोस्ट और कलेक्शन',
  'Archive': 'आर्काइव',
  'Stories and hidden posts': 'स्टोरी और छिपी पोस्ट',
  'Help': 'सहायता',
  'Support and app info': 'सपोर्ट और ऐप जानकारी',
  'Log out': 'लॉग आउट',
  'Parental control settings will be implemented here.': 'पैरेंटल कंट्रोल सेटिंग्स यहां लागू होंगी।',
  'Search Results': 'खोज परिणाम',
  'Clear': 'साफ करें',
  'No users found': 'कोई यूजर नहीं मिला',
  'Recent': 'हालिया',
  'Suggested for you': 'आपके लिए सुझाव',
  'See all': 'सभी देखें',
  'Discover': 'खोजें',
  'Photos': 'फोटो',
  'Videos': 'वीडियो',
  'New post': 'नई पोस्ट',
  'Fun': 'फन',
  'Learn': 'लर्न',
  'Edit': 'एडिट',
  'Crop': 'क्रॉप',
  'Filter': 'फिल्टर',
  'Adjust': 'एडजस्ट',
  'Trim': 'ट्रिम',
  'Tag people': 'लोगों को टैग करें',
  'Add location': 'लोकेशन जोड़ें',
  'Add music': 'म्यूजिक जोड़ें',
  'Audience': 'ऑडियंस',
  'Also share to your story': 'अपनी स्टोरी में भी शेयर करें',
  'Hide like and view counts': 'लाइक और व्यू काउंट छिपाएं',
  'Turn off commenting': 'कमेंट बंद करें',
  'Share': 'शेयर',
  'Uploading': 'अपलोड हो रहा है',
  'Posting your video...': 'आपका वीडियो पोस्ट हो रहा है...',
  'Compressing': 'कंप्रेस हो रहा है',
  'Publishing': 'पब्लिश हो रहा है',
  'Cancel upload': 'अपलोड रद्द करें',
  'Posted successfully': 'सफलतापूर्वक पोस्ट हुआ',
  'Your video is now live in ': 'आपका वीडियो अब लाइव है ',
  '. It may take a moment to appear in friends feeds.': '. दोस्तों की फीड में दिखने में थोड़ा समय लग सकता है।',
  'Drag the handles to trim - 44s selected': 'ट्रिम करने के लिए हैंडल खींचें - 44 सेकंड चुने गए',
  'Share to story': 'स्टोरी में शेयर करें',
  'View post': 'पोस्ट देखें',
  'Create another': 'एक और बनाएं',
  'Followers': 'फॉलोअर',
  'Following': 'फॉलोइंग',
  'Posts': 'पोस्ट',
  'Reels': 'रील्स',
  'Tagged': 'टैग्ड',
  'Your Story': 'आपकी स्टोरी',
  'likes': 'लाइक',
  'Please fill in all fields': 'कृपया सभी फील्ड भरें',
  'Could not connect to server. Check your network.': 'सर्वर से कनेक्ट नहीं हो सका। अपना नेटवर्क जांचें।',
  'Could not connect. Check your network.': 'कनेक्ट नहीं हो सका। अपना नेटवर्क जांचें।',
  'Google sign-in failed. Try again.': 'Google साइन-इन विफल रहा। फिर कोशिश करें।',
  'Password must be at least 6 characters': 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
  'That username is taken. Choose another.': 'यह यूजरनेम लिया जा चुका है। दूसरा चुनें।',
  'Please wait while we check your username...': 'यूजरनेम जांचने तक कृपया प्रतीक्षा करें...',
  'Please fix the username before continuing.': 'जारी रखने से पहले यूजरनेम ठीक करें।',
};
