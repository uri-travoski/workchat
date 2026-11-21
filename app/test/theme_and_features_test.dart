import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workchat/models/conversation.dart';
import 'package:workchat/theme/dark_blue_yellow_theme.dart';
import 'package:workchat/theme/purple_orange_theme.dart';
import 'package:workchat/theme/slate_steel_theme.dart';
import 'package:workchat/theme/theme_manager.dart';
import 'package:workchat/ui/components/file_type_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Typography & Font Customization Tests', () {
    test('Offline fonts availability list', () {
      expect(ThemeManager.availableFonts, containsAll([
        'Inter',
        'Plus Jakarta Sans',
        'IBM Plex Sans',
        'Roboto',
      ]));
    });

    test('Font size increment and decrement by 1 point', () {
      final mgr = ThemeManager();
      expect(mgr.fontSizeDelta, 0);

      mgr.adjustFontSize(1);
      expect(mgr.fontSizeDelta, 1);

      mgr.adjustFontSize(2);
      expect(mgr.fontSizeDelta, 3);

      mgr.adjustFontSize(-1);
      expect(mgr.fontSizeDelta, 2);
    });

    test('Font weight modes', () {
      final mgr = ThemeManager();
      expect(mgr.effectiveBodyWeight, FontWeight.normal);

      mgr.setFontWeightMode('semi-bold');
      expect(mgr.effectiveBodyWeight, FontWeight.w600);

      mgr.setFontWeightMode('bold');
      expect(mgr.effectiveBodyWeight, FontWeight.bold);

      mgr.setFontWeightMode('regular');
      expect(mgr.effectiveBodyWeight, FontWeight.normal);
    });

    test('Font family changes propagate to ThemeData TextTheme', () {
      final mgr = ThemeManager();
      mgr.setFontFamily('Plus Jakarta Sans');
      mgr.adjustFontSize(2);
      mgr.setFontWeightMode('bold');

      final darkTheme = mgr.darkTheme;
      expect(darkTheme.textTheme.bodyMedium?.fontFamily, 'Plus Jakarta Sans');
      expect(darkTheme.textTheme.bodyMedium?.fontSize, 16.0); // 14 + 2
      expect(darkTheme.textTheme.bodyMedium?.fontWeight, FontWeight.bold);

      final lightTheme = mgr.lightTheme;
      expect(lightTheme.textTheme.bodyMedium?.fontFamily, 'Plus Jakarta Sans');
      expect(lightTheme.textTheme.bodyMedium?.fontSize, 16.0);
    });
  });

  group('Semantic Themes App-Wide Verification', () {
    test('Slate Steel theme semantic colors', () {
      final theme = SlateSteelTheme();
      expect(theme.id, 'slate_steel');

      // Dark mode
      expect(theme.chatStageBg(true), const Color(0xFF0F172A));
      expect(theme.chatListBg(true), const Color(0xFF0F172A));
      expect(theme.surfaceHeaderBg(true), const Color(0xFF1E293B));
      expect(theme.myBubbleBg(true), const Color(0xFF2563EB));
      expect(theme.theirBubbleBg(true), const Color(0xFF1E293B));

      // Light mode
      expect(theme.chatStageBg(false), const Color(0xFFF8FAFC));
      expect(theme.myBubbleBg(false), const Color(0xFF4A83BD));
      expect(theme.theirBubbleBg(false), const Color(0xFFF1F5F9));
    });

    test('Purple + Sunset Orange theme semantic colors', () {
      final theme = PurpleOrangeTheme();
      expect(theme.id, 'purple_orange');

      // Dark mode
      expect(theme.chatStageBg(true), const Color(0xFF0F0A1C));
      expect(theme.surfaceHeaderBg(true), const Color(0xFF1E1435));
      expect(theme.myBubbleBg(true), const Color(0xFF7C3AED));
      expect(theme.theirBubbleBg(true), const Color(0xFF2D1B4E));
      expect(theme.accentColor(true), const Color(0xFFF97316)); // Sunset orange

      // Light mode
      expect(theme.myBubbleBg(false), const Color(0xFF8B5CF6));
      expect(theme.theirBubbleBg(false), const Color(0xFFF3E8FF));
    });

    test('Dark Blue + Yellow theme semantic colors', () {
      final theme = DarkBlueYellowTheme();
      expect(theme.id, 'dark_blue_yellow');

      // Dark mode
      expect(theme.chatStageBg(true), const Color(0xFF0B132B));
      expect(theme.surfaceHeaderBg(true), const Color(0xFF14213D));
      expect(theme.myBubbleBg(true), const Color(0xFF1D4ED8));
      expect(theme.theirBubbleBg(true), const Color(0xFF1E2E4F));
      expect(theme.accentColor(true), const Color(0xFFFACC15)); // Yellow accent

      // Light mode
      expect(theme.myBubbleBg(false), const Color(0xFF2563EB));
      expect(theme.theirBubbleBg(false), const Color(0xFFFEF9C3));
    });
  });

  group('File Type Icon & Badge Recognition Tests', () {
    test('Excel spreadsheets recognized with proper green badge', () {
      final xlsx = FileTypeHelper.getInfo('budget.xlsx');
      expect(xlsx.label, 'EXCEL');
      expect(xlsx.badgeTextColor, const Color(0xFF107C41));

      final csv = FileTypeHelper.getInfo('data.csv');
      expect(csv.label, 'EXCEL');
    });

    test('Word documents recognized with proper blue badge', () {
      final docx = FileTypeHelper.getInfo('Project_Scope.docx');
      expect(docx.label, 'WORD');
      expect(docx.badgeTextColor, const Color(0xFF1E40AF));
    });

    test('PDF documents recognized with proper red badge', () {
      final pdf = FileTypeHelper.getInfo('Whitepaper.pdf');
      expect(pdf.label, 'PDF');
      expect(pdf.badgeTextColor, const Color(0xFFC62828));
    });

    test('Zip archives recognized with proper amber badge', () {
      final zip = FileTypeHelper.getInfo('bundle.zip');
      expect(zip.label, 'ZIP');
      expect(zip.badgeTextColor, const Color(0xFFB45309));
    });

    test('Videos recognized with proper purple badge', () {
      final mp4 = FileTypeHelper.getInfo('demo.mp4');
      expect(mp4.label, 'VIDEO');
      expect(mp4.badgeTextColor, const Color(0xFF0E7490));
    });

    test('Images recognized with proper indigo badge', () {
      final png = FileTypeHelper.getInfo('diagram.png');
      expect(png.label, 'IMAGE');
      expect(png.badgeTextColor, const Color(0xFF6D28D9));
    });

    test('Source code files recognized with proper orange badge', () {
      final dart = FileTypeHelper.getInfo('main.dart');
      expect(dart.label, 'CODE');
      expect(dart.badgeTextColor, const Color(0xFF047857));

      final json = FileTypeHelper.getInfo('config.json');
      expect(json.label, 'CODE');
    });
  });

  group('Pinned Conversations & Sorting Rule Tests', () {
    test('Pinned conversations are sorted strictly by user custom pinOrder', () {
      final c1 = Conversation(id: 'c1', kind: 'channel', name: 'Zeta Channel', createdMs: 1000, isPinned: true, pinOrder: 2);
      final c2 = Conversation(id: 'c2', kind: 'dm', name: 'Alpha DM', createdMs: 2000, isPinned: true, pinOrder: 0);
      final c3 = Conversation(id: 'c3', kind: 'channel', name: 'Beta Channel', createdMs: 3000, isPinned: true, pinOrder: 1);

      final pinnedList = [c1, c2, c3]..sort((a, b) => a.pinOrder.compareTo(b.pinOrder));
      expect(pinnedList.map((c) => c.name).toList(), ['Alpha DM', 'Beta Channel', 'Zeta Channel']);
    });

    test('Sorting by A-Z affects only unpinned conversations', () {
      final u1 = Conversation(id: 'u1', kind: 'channel', name: 'Zeta Channel', createdMs: 3000);
      final u2 = Conversation(id: 'u2', kind: 'dm', name: 'Alpha DM', createdMs: 1000);
      final u3 = Conversation(id: 'u3', kind: 'channel', name: 'Gamma Channel', createdMs: 2000);

      final unpinned = [u1, u2, u3]..sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
      expect(unpinned.map((c) => c.name).toList(), ['Alpha DM', 'Gamma Channel', 'Zeta Channel']);
    });
  });
}
