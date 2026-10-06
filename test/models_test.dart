import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/utils/formatters.dart';
import 'package:sport_shop/models/enums.dart';
import 'package:sport_shop/models/order.dart';
import 'package:sport_shop/models/order_item.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/sport_requirement.dart';
import 'package:sport_shop/models/user.dart';

void main() {
  group('User', () {
    test('toMap → fromMap сохраняет данные', () {
      final User user = User(
        id: 1,
        email: 'maria@mail.kz',
        passwordHash: 'hash',
        role: UserRole.customer,
        firstName: 'Мария',
        lastName: 'Габдулина',
        phone: '+7 708 777 5555',
        createdAt: DateTime(2026, 5, 12),
      );
      final User restored = User.fromMap(user.toMap());

      expect(restored.fullName, 'Мария Габдулина');
      expect(restored.role, UserRole.customer);
      expect(restored.greetingName, 'Мария');
    });

    test('toJson не содержит хеш пароля', () {
      final User user = User(
        email: 'a@b.kz',
        passwordHash: 'secret',
        role: UserRole.customer,
        createdAt: DateTime(2026),
      );
      expect(user.toJson().containsKey('password_hash'), isFalse);
    });
  });

  group('Product', () {
    test('цена из SQLite как int читается как double', () {
      final Product product = Product.fromMap({
        'id': 5,
        'name': 'Спортивная футболка',
        'price': 4990,
        'category_id': 1,
        'sport_id': 1,
        'size': 'S, M,L',
        'stock': 3,
      });
      expect(product.price, 4990.0);
      expect(product.availableSizes, ['S', 'M', 'L']);
      expect(product.isAvailable, isTrue);
    });
  });

  group('Enums', () {
    test('уровень по стажу', () {
      expect(SportLevel.fromExperience(0), SportLevel.beginner);
      expect(SportLevel.fromExperience(2), SportLevel.amateur);
      expect(SportLevel.fromExperience(6), SportLevel.experienced);
    });

    test('неизвестный статус → Новый', () {
      expect(OrderStatus.fromValue('???'), OrderStatus.newOrder);
    });

    test('is_mandatory 1/0 → bool', () {
      final SportRequirement requirement = SportRequirement.fromMap({
        'sport_id': 1,
        'product_id': 2,
        'level': 'beginner',
        'is_mandatory': 1,
      });
      expect(requirement.isMandatory, isTrue);
      expect(requirement.toMap()['is_mandatory'], 1);
    });
  });

  group('Order', () {
    test('toJson → fromJson с позициями', () {
      final Order order = Order(
        id: 1024,
        userId: 1,
        status: OrderStatus.inTransit,
        totalPrice: 6800,
        createdAt: DateTime(2026, 5, 12),
        deliveryMethod: DeliveryMethod.pickup,
        items: const [
          OrderItem(productId: 1, quantity: 2, price: 1500),
          OrderItem(productId: 2, quantity: 1, price: 3800),
        ],
      );
      final Order restored = Order.fromJson(order.toJson());

      expect(restored.items.length, 2);
      expect(restored.itemsCount, 3);
      expect(restored.status, OrderStatus.inTransit);
      expect(restored.deliveryMethod, DeliveryMethod.pickup);
    });
  });

  group('Formatters', () {
    test('цена в тенге', () {
      // В русской локали разделитель тысяч — неразрывный пробел
      // (в разных версиях intl — U+00A0 или U+202F).
      final String text =
          Formatters.price(4990).replaceAll(RegExp('[\u00A0\u202F]'), ' ');
      expect(text, '4 990 ₸');
    });

    test('номер заказа', () {
      expect(Formatters.orderNumber(1024), '#1024');
    });
  });
}
