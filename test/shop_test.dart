// Widget tests for the native rich steps (0.2.0): catalogue, product sheet,
// cart, checkout form, price range and finder results.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

import 'helpers.dart';

const _catalog = ProductListPrompt(
  categories: [
    ProductCategory(id: 'k1', name: 'معجنات'),
    ProductCategory(id: 'k2', name: 'حلويات'),
  ],
  products: [
    Product(
      id: 'p1',
      name: 'كرواسون زعتر',
      category: 'k1',
      price: '6,000 ل.س',
      unit: 'قطعة',
      groups: [
        ProductGroup(
          name: 'الحشوة',
          required: true,
          choices: [
            ProductChoice(id: 'o1', name: 'زعتر بس'),
            ProductChoice(id: 'o2', name: 'زعتر وجبنة', price: '+1,000'),
          ],
        ),
      ],
    ),
    Product(
      id: 'p2',
      name: 'معمول بالتمر',
      category: 'k2',
      price: '120,000 ل.س',
      unit: 'كيلو',
      step: 0.25,
      max: 5,
    ),
    Product(
      id: 'p3',
      name: 'بسبوسة',
      category: 'k2',
      price: '15,000 ل.س',
      available: false,
    ),
    Product(id: 'p4', name: 'كعك', category: 'k1', price: '8,000 ل.س'),
    Product(id: 'p5', name: 'دونات', category: 'k2', price: '7,000 ل.س'),
    Product(id: 'p6', name: 'خبز فرنسي', category: 'k1', price: '5,000 ل.س'),
    Product(id: 'p7', name: 'كيك برتقال', category: 'k2', price: '45,000 ل.س'),
  ],
  cartCount: 1,
  cartTotal: '8,000 ل.س',
  doneLabel: 'عرض السلة',
);

Future<FakeTransport> _pump(
  WidgetTester tester,
  Prompt prompt, {
  ChatTurn Function(ReplyBody)? onReply,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final t = FakeTransport(
    onStart: () => turn(prompt),
    onReply: onReply ?? (_) => turn(prompt, []),
  );
  await pumpChat(tester, t);
  return t;
}

void main() {
  group('catalogue', () {
    testWidgets('card, bar, sheet with search and categories', (tester) async {
      await _pump(tester, _catalog);
      expect(find.text('القائمة'), findsOneWidget);
      expect(find.text('7 منتج'), findsOneWidget);
      expect(
        find.text('منتج واحد'),
        findsOneWidget,
        reason: 'cart count in the bar',
      );
      expect(find.text('8,000 ل.س'), findsOneWidget);

      await tester.tap(find.text('تصفّح القائمة'));
      await tester.pumpAndSettle();
      expect(find.text('الكل'), findsOneWidget);
      expect(
        find.text('نفد'),
        findsOneWidget,
        reason: 'sold out shows, not addable',
      );

      await tester.tap(find.text('حلويات'));
      await tester.pumpAndSettle();
      expect(find.text('كعك'), findsNothing);
      expect(find.text('دونات'), findsOneWidget);

      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'خبز');
      await tester.pumpAndSettle();
      expect(find.text('خبز فرنسي'), findsOneWidget);
      expect(find.text('دونات'), findsNothing);
    });

    testWidgets('product sheet: a required option, then add sends the action', (
      tester,
    ) async {
      final t = await _pump(tester, _catalog);
      await tester.tap(find.text('تصفّح القائمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('كرواسون زعتر'));
      await tester.pumpAndSettle();

      final add = find.text('أضف للسلة');
      expect(add, findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(t.replies, isEmpty, reason: 'the filling is required');

      await tester.tap(find.text('زعتر وجبنة'));
      await tester.tap(find.bySemanticsLabel(RegExp('زيادة')).last);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      final a = t.replies.single as ActionReply;
      expect(a.type, 'add');
      expect(a.product, 'p1');
      expect(a.qty, 2);
      expect(a.options, ['o2']);
      expect(find.text('➕ 2 × كرواسون زعتر'), findsOneWidget);
    });

    testWidgets('quarter-kilo steps start at 1 and move by 0.25', (
      tester,
    ) async {
      final t = await _pump(tester, _catalog);
      await tester.tap(find.text('تصفّح القائمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('معمول بالتمر'));
      await tester.pumpAndSettle();
      expect(find.text('1 كيلو'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('إنقاص')).last);
      await tester.pumpAndSettle();
      expect(find.text('0.75 كيلو'), findsOneWidget);
      await tester.tap(find.text('أضف للسلة'));
      await tester.pumpAndSettle();
      expect((t.replies.single as ActionReply).qty, 0.75);
    });

    testWidgets('go to cart from the bar', (tester) async {
      final t = await _pump(tester, _catalog);
      await tester.tap(find.text('عرض السلة'));
      await tester.pumpAndSettle();
      expect((t.replies.single as ActionReply).type, 'done');
    });
  });

  group('cart', () {
    const cart = CartPrompt(
      lines: [
        CartLine(
          id: 'l1',
          name: 'كعك',
          qty: 2,
          max: 10,
          unit: 'كيس',
          unitPrice: '8,000 ل.س',
          total: '16,000 ل.س',
        ),
        CartLine(
          id: 'l2',
          name: 'كرواسون',
          options: 'زعتر وجبنة',
          qty: 1,
          total: '7,000 ل.س',
        ),
      ],
      subtotal: '23,000 ل.س',
      canCheckout: true,
      moreLabel: 'إضافة منتجات',
      confirmLabel: 'تأكيد الطلب',
    );

    testWidgets('lines, totals, steppers and remove', (tester) async {
      final t = await _pump(tester, cart);
      expect(find.text('23,000 ل.س'), findsOneWidget);
      expect(find.text('زعتر وجبنة'), findsOneWidget);
      expect(find.text('8,000 ل.س / كيس'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('زيادة كعك'));
      await tester.pumpAndSettle();
      var a = t.replies.last as ActionReply;
      expect(a.type, 'set_qty');
      expect(a.line, 'l1');
      expect(a.qty, 3);

      await tester.tap(find.bySemanticsLabel('حذف كرواسون'));
      await tester.pumpAndSettle();
      a = t.replies.last as ActionReply;
      expect(a.type, 'remove');
      expect(a.line, 'l2');
    });

    testWidgets('confirm and add more', (tester) async {
      final t = await _pump(tester, cart);
      await tester.tap(find.text('تأكيد الطلب'));
      await tester.pumpAndSettle();
      expect((t.replies.last as ActionReply).type, 'confirm');
      await tester.tap(find.text('إضافة منتجات'));
      await tester.pumpAndSettle();
      expect((t.replies.last as ActionReply).type, 'more');
    });

    testWidgets('confirm is disabled when the server says not yet', (
      tester,
    ) async {
      final t = await _pump(
        tester,
        const CartPrompt(
          confirmLabel: 'تأكيد الطلب',
          emptyText: 'السلة فاضية.',
        ),
      );
      expect(find.text('السلة فاضية.'), findsOneWidget);
      await tester.tap(find.text('تأكيد الطلب'));
      await tester.pumpAndSettle();
      expect(t.replies, isEmpty);
    });
  });

  group('checkout form', () {
    const form = FormPrompt(
      title: 'بيانات الطلب',
      submitLabel: 'إرسال الطلب',
      openLabel: 'عبّي بيانات الطلب',
      summary: [LabelValue('المجموع', '23,000 ل.س')],
      fields: [
        FormFieldSpec(
          name: 'fulfillment',
          label: 'طريقة الاستلام',
          type: FormFieldKind.choice,
          required: true,
          value: 'pickup',
          options: [
            FieldOption(id: 'delivery', label: 'توصيل'),
            FieldOption(id: 'pickup', label: 'استلام'),
          ],
        ),
        FormFieldSpec(
          name: 'address',
          label: 'العنوان',
          type: FormFieldKind.textarea,
          required: true,
          showIfField: 'fulfillment',
          showIfValue: 'delivery',
        ),
        FormFieldSpec(name: 'name', label: 'الاسم', required: true),
        FormFieldSpec(
          name: 'phone',
          label: 'رقم الموبايل',
          type: FormFieldKind.phone,
          required: true,
        ),
        FormFieldSpec(
          name: 'notes',
          label: 'ملاحظات',
          type: FormFieldKind.textarea,
        ),
      ],
    );

    testWidgets('opens by itself, show_if, local checks, then submit', (
      tester,
    ) async {
      final t = await _pump(tester, form);
      // The sheet opened on its own.
      expect(find.text('إرسال الطلب'), findsOneWidget);
      expect(
        find.text('العنوان'),
        findsNothing,
        reason: 'pickup hides the address',
      );

      await tester.tap(find.text('توصيل'));
      await tester.pumpAndSettle();
      expect(find.text('العنوان'), findsOneWidget);

      await tester.tap(find.text('إرسال الطلب'));
      await tester.pumpAndSettle();
      expect(find.text('هالحقل مطلوب.'), findsNWidgets(3));
      expect(t.replies, isEmpty);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'المزة، شارع الجلاء');
      await tester.enterText(fields.at(1), 'سلمى');
      await tester.enterText(fields.at(2), '12');
      await tester.tap(find.text('إرسال الطلب'));
      await tester.pumpAndSettle();
      expect(find.text('اكتب رقم موبايل صحيح.'), findsOneWidget);

      await tester.enterText(fields.at(2), '٠٩٩١٢٣٤٥٦٧');
      await tester.tap(find.text('إرسال الطلب'));
      await tester.pumpAndSettle();
      final a = t.replies.single as ActionReply;
      expect(a.type, 'submit');
      expect(a.values, {
        'fulfillment': 'delivery',
        'address': 'المزة، شارع الجلاء',
        'name': 'سلمى',
        'phone': '0991234567',
        'notes': '',
      });
      expect(find.text('📝 أرسلت بيانات الطلب'), findsOneWidget);
    });

    testWidgets("the server's field errors show on the reopened form", (
      tester,
    ) async {
      await _pump(
        tester,
        const FormPrompt(
          error: 'في معلومات ناقصة.',
          fields: [
            FormFieldSpec(
              name: 'phone',
              label: 'رقم الموبايل',
              type: FormFieldKind.phone,
              required: true,
              value: '0991',
              error: 'الرقم قصير.',
            ),
          ],
        ),
      );
      expect(find.text('الرقم قصير.'), findsOneWidget);
      expect(find.text('في معلومات ناقصة.'), findsWidgets);
    });
  });

  group('finder', () {
    testWidgets('range: numbers only, then min and max', (tester) async {
      final t = await _pump(
        tester,
        const FormPrompt(
          isRange: true,
          title: 'الميزانية',
          fields: [
            FormFieldSpec(name: 'min', label: 'من'),
            FormFieldSpec(name: 'max', label: 'لحد'),
          ],
        ),
      );
      final boxes = find.byType(TextField);
      await tester.enterText(boxes.at(0), 'abc');
      await tester.tap(find.text('تمام'));
      await tester.pumpAndSettle();
      expect(find.text('اكتب أرقام بس.'), findsOneWidget);

      await tester.enterText(boxes.at(0), '١٠٠');
      await tester.enterText(boxes.at(1), '500');
      await tester.tap(find.text('تمام'));
      await tester.pumpAndSettle();
      expect((t.replies.single as ActionReply).values, {
        'min': '100',
        'max': '500',
      });
      expect(find.text('100 – 500'), findsOneWidget);
    });

    testWidgets('range: "any" sends empty bounds', (tester) async {
      final t = await _pump(
        tester,
        const FormPrompt(
          isRange: true,
          fields: [
            FormFieldSpec(name: 'min', label: 'من'),
            FormFieldSpec(name: 'max', label: 'لحد'),
          ],
        ),
      );
      await tester.tap(find.text('ما بتفرق'));
      await tester.pumpAndSettle();
      expect((t.replies.single as ActionReply).values, {'min': '', 'max': ''});
    });

    const pick = ProductListPrompt(
      isPick: true,
      total: 5,
      hasMore: true,
      contactLabel: 'احكي مع حدا',
      products: [
        Product(
          id: 'x1',
          name: 'نوفا X5',
          categoryName: 'موبايل',
          price: r'$249',
          code: 'NX5-128',
          attributes: [LabelValue('الشاشة', '6.5 إنش')],
          details: [LabelValue('الذاكرة', '128GB')],
        ),
        Product(id: 'x2', name: 'لومن A3', price: r'$189'),
      ],
    );

    testWidgets('results: details sheet, select, more, restart, contact', (
      tester,
    ) async {
      final t = await _pump(tester, pick);
      expect(find.text('5 منتجات'), findsOneWidget);
      expect(find.text('الشاشة: 6.5 إنش'), findsOneWidget);

      await tester.tap(find.text('التفاصيل').first);
      await tester.pumpAndSettle();
      expect(find.text('رقم المنتج: NX5-128'), findsOneWidget);
      expect(find.text('128GB'), findsOneWidget);
      await tester.tap(find.text('بدي هاد').last);
      await tester.pumpAndSettle();
      var a = t.replies.last as ActionReply;
      expect(a.type, 'select');
      expect(a.product, 'x1');
      expect(find.text('✅ نوفا X5'), findsOneWidget);

      for (final (label, type) in [
        ('عرض المزيد', 'more'),
        ('ابدأ من جديد', 'restart'),
        ('احكي مع حدا', 'contact'),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        a = t.replies.last as ActionReply;
        expect(a.type, type);
      }
    });
  });

  testWidgets('a rich step stays visible but disabled while offline', (
    tester,
  ) async {
    final t = await _pump(
      tester,
      const CartPrompt(
        lines: [CartLine(id: 'l1', name: 'كعك', qty: 2)],
        canCheckout: true,
        confirmLabel: 'تأكيد الطلب',
      ),
    );
    t.offline = true;
    await tester.tap(find.bySemanticsLabel('زيادة كعك'));
    await tester.pumpAndSettle();
    expect(find.text('كعك'), findsOneWidget, reason: 'the cart is still shown');
    final before = t.idempotencyKeys.length;
    await tester.tap(find.text('تأكيد الطلب'));
    await tester.pumpAndSettle();
    expect(
      t.idempotencyKeys.length,
      before,
      reason: 'disabled while a reply waits',
    );
    // Back online: the queued reply goes out on its own retry timer.
    t.offline = false;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(t.replies.single, isA<ActionReply>());
  });

  testWidgets('large text (200%) on the catalogue and cart', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ctl = controllerFor(FakeTransport(onStart: () => turn(_catalog)));
    addTearDown(ctl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(body: RaselnaChatView(controller: ctl)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
