// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:killua_app/features/drive/notas/appflowy_custom_blocks.dart';
import 'package:killua_app/main.dart';
import 'package:killua_app/services/theme_config_service.dart';

void main() {
  testWidgets('monta la aplicación durante la carga de autenticación', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themeConfig = ThemeConfigService();
    await themeConfig.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeConfig,
        child: const KilluaApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renderiza bloques AppFlowy personalizados', (
    WidgetTester tester,
  ) async {
    final editorState = EditorState(
      document: buildCustomBlockDocument(
        blocks: [
          CustomBlockData(
            type: 'code_block',
            language: 'dart',
            content: 'void main() => print("ok");',
          ),
          CustomBlockData(
            type: 'link_preview',
            url: 'https://example.com',
            title: 'Example',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppFlowyEditor(
          editorState: editorState,
          editable: false,
          editorStyle: const EditorStyle.mobile(
            cursorColor: Colors.transparent,
            selectionColor: Colors.transparent,
            dragHandleColor: Colors.transparent,
          ),
          blockComponentBuilders: {
            ...standardBlockComponentBuilderMap,
            ...customBlockBuilders,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('void main() => print("ok");'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
  });
}
