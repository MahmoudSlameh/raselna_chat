/// The SDK's own fixed texts. Everything the bot says comes from the server
/// as is. Pass your own instance to `RaselnaChat.init(strings: …)` to change
/// any of them.
class RaselnaStrings {
  const RaselnaStrings({
    required this.online,
    required this.typing,
    required this.connecting,
    required this.offline,
    required this.placeholder,
    required this.send,
    required this.showOptions,
    required this.chooseOption,
    required this.close,
    required this.restart,
    required this.continueBack,
    required this.retry,
    required this.queued,
    required this.you,
    required this.stepOf,
    required this.pausedTitle,
    required this.pausedHint,
    required this.copy,
    required this.copied,
    required this.ended,
    required this.handoffTitle,
    required this.handoffCatalog,
    required this.handoffCart,
    required this.handoffForm,
    required this.handoffSecret,
    required this.handoffOther,
    required this.handoffOpen,
    required this.handoffWaiting,
    required this.handoffBack,
    required this.handoffFailed,
    required this.products,
    required this.slotsEmpty,
    required this.loadFailed,
    required this.tryAgain,
    required this.genericError,
    required this.tooMany,
    required this.unavailable,
    required this.invalidPhone,
    required this.invalidNumber,
    required this.invalidEmail,
    required this.invalidEmpty,
    required this.pickDate,
    required this.poweredBy,
    required this.raselna,
    required this.botSaid,
    this.shop = RaselnaShopStrings.ar,
  });

  /// Arabic (the default).
  static const ar = RaselnaStrings(
    online: 'متصل الآن',
    typing: 'يكتب…',
    connecting: 'عم نوصل…',
    offline: 'ما في إنترنت. رح نبعت رسائلك لما يرجع.',
    placeholder: 'اكتب رسالة…',
    send: 'إرسال',
    showOptions: 'عرض الخيارات',
    chooseOption: 'اختار من القائمة',
    close: 'إغلاق',
    restart: 'البدء من جديد',
    continueBack: 'رجعت؟ كمّل المحادثة',
    retry: 'لم تُرسل. إعادة المحاولة',
    queued: 'بانتظار الإرسال',
    you: 'أنت',
    stepOf: 'الخطوة {n} من {m}',
    pausedTitle: 'رقم المحادثة',
    pausedHint: 'ارجع بهالرقم لتكمّل من نفس النقطة.',
    copy: 'نسخ',
    copied: 'انتسخ',
    ended: 'انتهت المحادثة.',
    handoffTitle: 'هالخطوة بتكمل بصفحة آمنة',
    handoffCatalog: 'تصفّح القائمة واختار يلي بدك ياه، وبعدين ارجع لهون.',
    handoffCart: 'راجع سلتك وأكّدها، وبعدين ارجع لهون.',
    handoffForm: 'عبّي المعلومات بصفحة وحدة، وبعدين ارجع لهون.',
    handoffSecret: 'هالمعلومة سرية، فمنطلبها بصفحة آمنة مو جوّا التطبيق.',
    handoffOther: 'هالخطوة بتشتغل بالمتصفح. بعد ما تخلص ارجع لهون.',
    handoffOpen: 'متابعة بالمتصفح',
    handoffWaiting: 'خلصت؟ ارجع لهون ومنكمّل.',
    handoffBack: 'رجعت؟ كمّل',
    handoffFailed: 'ما قدرنا نفتح الصفحة. جرّب مرة تانية.',
    products: '{n} منتج',
    slotsEmpty: 'ما في مواعيد فاضية هلأ.',
    loadFailed: 'ما قدرنا نفتح المحادثة.',
    tryAgain: 'جرّب مرة تانية',
    genericError: 'صار خطأ. جرّب مرة تانية.',
    tooMany: 'طلبات كتير ورا بعض. استنى دقيقة وجرّب.',
    unavailable: 'المحادثة مو متاحة حالياً. جرّب بعد شوي.',
    invalidPhone: 'اكتب رقم موبايل صحيح.',
    invalidNumber: 'اكتب أرقام بس.',
    invalidEmail: 'اكتب إيميل صحيح.',
    invalidEmpty: 'اكتب جوابك أول.',
    pickDate: 'اختار التاريخ',
    poweredBy: 'مدعوم من',
    raselna: 'راسلنا',
    botSaid: '{bot} قال',
  );

  /// English.
  static const en = RaselnaStrings(
    online: 'Online',
    typing: 'typing…',
    connecting: 'Connecting…',
    offline: 'No internet. Your messages will be sent when it is back.',
    placeholder: 'Type a message…',
    send: 'Send',
    showOptions: 'Show options',
    chooseOption: 'Choose from the list',
    close: 'Close',
    restart: 'Start over',
    continueBack: 'Back? Continue the chat',
    retry: 'Not sent. Tap to retry',
    queued: 'Waiting to send',
    you: 'You',
    stepOf: 'Step {n} of {m}',
    pausedTitle: 'Conversation number',
    pausedHint: 'Use this number to continue where you left off.',
    copy: 'Copy',
    copied: 'Copied',
    ended: 'The conversation has ended.',
    handoffTitle: 'This step continues on a secure page',
    handoffCatalog:
        'Browse the menu and pick what you like, then come back here.',
    handoffCart: 'Review and confirm your cart, then come back here.',
    handoffForm: 'Fill in the details on one page, then come back here.',
    handoffSecret:
        'This is sensitive, so we ask for it on a secure page, not in the app.',
    handoffOther: 'This step runs in the browser. Come back here when done.',
    handoffOpen: 'Continue in browser',
    handoffWaiting: 'Done? Come back and we will carry on.',
    handoffBack: 'Back? Continue',
    handoffFailed: 'Could not open the page. Please try again.',
    products: '{n} products',
    slotsEmpty: 'No free times right now.',
    loadFailed: 'Could not open the chat.',
    tryAgain: 'Try again',
    genericError: 'Something went wrong. Please try again.',
    tooMany: 'Too many requests. Wait a minute and try again.',
    unavailable: 'The chat is not available right now. Try again soon.',
    invalidPhone: 'Enter a valid mobile number.',
    invalidNumber: 'Numbers only.',
    invalidEmail: 'Enter a valid email.',
    invalidEmpty: 'Type your answer first.',
    pickDate: 'Pick a date',
    poweredBy: 'Powered by',
    raselna: 'Raselna',
    botSaid: '{bot} said',
    shop: RaselnaShopStrings.en,
  );

  /// The built-in strings for a language code; Arabic for anything else.
  static RaselnaStrings forLocale(String locale) =>
      locale.toLowerCase().startsWith('en') ? en : ar;

  final String online;
  final String typing;
  final String connecting;
  final String offline;
  final String placeholder;
  final String send;
  final String showOptions;
  final String chooseOption;
  final String close;
  final String restart;
  final String continueBack;
  final String retry;
  final String queued;
  final String you;

  /// `{n}` and `{m}` are replaced.
  final String stepOf;
  final String pausedTitle;
  final String pausedHint;
  final String copy;
  final String copied;
  final String ended;
  final String handoffTitle;
  final String handoffCatalog;
  final String handoffCart;
  final String handoffForm;
  final String handoffSecret;
  final String handoffOther;
  final String handoffOpen;
  final String handoffWaiting;
  final String handoffBack;
  final String handoffFailed;

  /// `{n}` is replaced.
  final String products;
  final String slotsEmpty;
  final String loadFailed;
  final String tryAgain;
  final String genericError;
  final String tooMany;
  final String unavailable;
  final String invalidPhone;
  final String invalidNumber;
  final String invalidEmail;
  final String invalidEmpty;
  final String pickDate;
  final String poweredBy;
  final String raselna;

  /// Screen-reader prefix of a bot bubble; `{bot}` is replaced.
  final String botSaid;

  /// Catalogue, cart, form and finder texts.
  final RaselnaShopStrings shop;
}

/// Fixed texts of the native catalogue, cart, forms and finder results.
/// The tenant's own button labels from the server win where sent.
class RaselnaShopStrings {
  const RaselnaShopStrings({
    required this.menu,
    required this.browse,
    required this.all,
    required this.search,
    required this.noMatch,
    required this.noProducts,
    required this.add,
    required this.addToCart,
    required this.soldOut,
    required this.required,
    required this.optional,
    required this.quantity,
    required this.decrease,
    required this.increase,
    required this.remove,
    required this.cart,
    required this.cartEmpty,
    required this.oneItem,
    required this.items,
    required this.subtotal,
    required this.form,
    required this.fillForm,
    required this.sendOrder,
    required this.sent,
    required this.added,
    required this.changed,
    required this.removed,
    required this.fieldRequired,
    required this.details,
    required this.choose,
    required this.chose,
    required this.more,
    required this.startOver,
    required this.code,
    required this.from,
    required this.to,
    required this.ok,
    required this.anyRange,
    required this.numbersOnly,
    required this.close,
    required this.picture,
  });

  static const ar = RaselnaShopStrings(
    menu: 'القائمة',
    browse: 'تصفّح القائمة',
    all: 'الكل',
    search: 'دوّر على منتج',
    noMatch: 'ما لقينا منتج بهالاسم.',
    noProducts: 'ما في منتجات هلأ.',
    add: 'أضف',
    addToCart: 'أضف للسلة',
    soldOut: 'نفد',
    required: 'مطلوب',
    optional: 'اختياري',
    quantity: 'الكمية',
    decrease: 'إنقاص',
    increase: 'زيادة',
    remove: 'حذف',
    cart: 'السلة',
    cartEmpty: 'السلة فاضية',
    oneItem: 'منتج واحد',
    items: '{n} منتجات',
    subtotal: 'المجموع',
    form: 'بيانات الطلب',
    fillForm: 'عبّي بيانات الطلب',
    sendOrder: 'إرسال الطلب',
    sent: '📝 أرسلت بيانات الطلب',
    added: '➕ {qty} × {name}',
    changed: '✏️ {name} × {qty}',
    removed: '🗑️ {name}',
    fieldRequired: 'هالحقل مطلوب.',
    details: 'التفاصيل',
    choose: 'بدي هاد',
    chose: '✅ {name}',
    more: 'عرض المزيد',
    startOver: 'ابدأ من جديد',
    code: 'رقم المنتج',
    from: 'من',
    to: 'لحد',
    ok: 'تمام',
    anyRange: 'ما بتفرق',
    numbersOnly: 'اكتب أرقام بس.',
    close: 'إغلاق',
    picture: 'صورة {i} من {n}',
  );

  static const en = RaselnaShopStrings(
    menu: 'Menu',
    browse: 'Browse the menu',
    all: 'All',
    search: 'Search products',
    noMatch: 'No product by that name.',
    noProducts: 'No products right now.',
    add: 'Add',
    addToCart: 'Add to cart',
    soldOut: 'Sold out',
    required: 'Required',
    optional: 'Optional',
    quantity: 'Quantity',
    decrease: 'Decrease',
    increase: 'Increase',
    remove: 'Remove',
    cart: 'Cart',
    cartEmpty: 'Your cart is empty',
    oneItem: '1 item',
    items: '{n} items',
    subtotal: 'Subtotal',
    form: 'Order details',
    fillForm: 'Fill in the order details',
    sendOrder: 'Place order',
    sent: '📝 Sent my order details',
    added: '➕ {qty} × {name}',
    changed: '✏️ {name} × {qty}',
    removed: '🗑️ {name}',
    fieldRequired: 'This field is required.',
    details: 'Details',
    choose: 'I want this',
    chose: '✅ {name}',
    more: 'Show more',
    startOver: 'Start over',
    code: 'Product code',
    from: 'From',
    to: 'To',
    ok: 'OK',
    anyRange: 'Any',
    numbersOnly: 'Numbers only.',
    close: 'Close',
    picture: 'Picture {i} of {n}',
  );

  final String menu;
  final String browse;
  final String all;
  final String search;
  final String noMatch;
  final String noProducts;
  final String add;
  final String addToCart;
  final String soldOut;
  final String required;
  final String optional;
  final String quantity;
  final String decrease;
  final String increase;
  final String remove;
  final String cart;
  final String cartEmpty;
  final String oneItem;

  /// `{n}` is replaced.
  final String items;
  final String subtotal;
  final String form;
  final String fillForm;
  final String sendOrder;
  final String sent;

  /// `{qty}` and `{name}` are replaced.
  final String added;
  final String changed;
  final String removed;
  final String fieldRequired;
  final String details;
  final String choose;
  final String chose;
  final String more;
  final String startOver;
  final String code;
  final String from;
  final String to;
  final String ok;
  final String anyRange;
  final String numbersOnly;
  final String close;

  /// `{i}` and `{n}` are replaced.
  final String picture;

  String count(int n) =>
      n == 0
          ? cartEmpty
          : n == 1
          ? oneItem
          : items.replaceAll('{n}', '$n');
}
