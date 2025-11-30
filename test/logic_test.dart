import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sobriety_app/main.dart';

void main() {
  group('DrinkItem Constants', () {
    test('Beer 5% 350ml should be 14g', () {
      final beer350 = kDrinkItems.firstWhere((d) => d.id == 1);
      expect(beer350.name, 'ビール/酎ハイ (5%) 350ml');
      expect(beer350.alcoholAmount, 14.0);
    });

    test('Whiskey 40% 30ml should be 9.6g', () {
      final whiskey = kDrinkItems.firstWhere((d) => d.id == 6);
      expect(whiskey.name, 'ウィスキーシングル (40%) 30ml');
      expect(whiskey.alcoholAmount, 9.6);
    });

    test('Beer 5% 500ml should be 20g', () {
      final beer500 = kDrinkItems.firstWhere((d) => d.id == 2);
      expect(beer500.alcoholAmount, 20.0);
    });
  });

  group('AlcoholService Calculation', () {
    late AlcoholService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = AlcoholService();
    });

    test('Single beer should calculate 14g total', () async {
      final date = DateTime(2024, 1, 1);
      final items = {1: 1}; // 1x Beer 350ml

      await service.saveRecord(date, items);
      final record = await service.getRecord(date);

      expect(record, isNotNull);
      expect(record!['totalAlcohol'], 14.0);
    });

    test('Two beers should calculate 28g total', () async {
      final date = DateTime(2024, 1, 2);
      final items = {1: 2}; // 2x Beer 350ml

      await service.saveRecord(date, items);
      final record = await service.getRecord(date);

      expect(record, isNotNull);
      expect(record!['totalAlcohol'], 28.0);
    });

    test('Mixed drinks should calculate correct total', () async {
      final date = DateTime(2024, 1, 3);
      final items = {
        1: 1, // 1x Beer 350ml (14g)
        6: 2, // 2x Whiskey (9.6g each = 19.2g)
      };

      await service.saveRecord(date, items);
      final record = await service.getRecord(date);

      expect(record, isNotNull);
      expect(record!['totalAlcohol'], 33.2); // 14 + 19.2
    });

    test('Non-existent date should return null', () async {
      final date = DateTime(2024, 12, 31);
      final record = await service.getRecord(date);

      expect(record, isNull);
    });

    test('Saved items should persist correctly', () async {
      final date = DateTime(2024, 1, 4);
      final items = {
        1: 2, // 2x Beer 350ml
        5: 1, // 1x Horoyoi (8.4g)
      };

      await service.saveRecord(date, items);
      final record = await service.getRecord(date);

      expect(record, isNotNull);
      expect(record!['items'], isNotEmpty);
      expect(record['items']['1'], 2);
      expect(record['items']['5'], 1);
      expect(record['totalAlcohol'], 36.4); // 28 + 8.4
    });
  });

  group('Alcohol Calculation Formula', () {
    test('Manual calculation verification for beer', () {
      // Formula: Volume(ml) × ABV(%) × 0.8(density) / 100
      // Beer 350ml × 5% → 350 × 5 × 0.8 / 100 = 14g
      final calculated = 350 * 5 * 0.8 / 100;
      final expected = kDrinkItems.firstWhere((d) => d.id == 1).alcoholAmount;
      expect(calculated, expected);
    });

    test('Manual calculation verification for whiskey', () {
      // Whiskey 30ml × 40% → 30 × 40 × 0.8 / 100 = 9.6g
      final calculated = 30 * 40 * 0.8 / 100;
      final expected = kDrinkItems.firstWhere((d) => d.id == 6).alcoholAmount;
      expect(calculated, expected);
    });
  });
}
