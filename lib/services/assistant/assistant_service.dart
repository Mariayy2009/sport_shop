import '../../data/repositories/product_repository.dart';
import '../../models/chat_message.dart';
import '../../models/product.dart';
import '../../models/sport.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import 'assistant_engine.dart';

/// Точка входа для чата с ИИ-помощником:
/// собирает контекст (каталог, профиль) и передаёт его движку.
class AssistantService {
  AssistantService(this._engine, this._productRepository);

  final AssistantEngine _engine;
  final ProductRepository _productRepository;

  Future<AssistantReply> ask({
    required List<ChatMessage> history,
    User? user,
    UserSizes? sizes,
  }) async {
    final List<Product> catalog = await _productRepository.getProducts();
    final List<Sport> sports = await _productRepository.getSports();
    return _engine.reply(
      AssistantContext(
        catalog: catalog,
        sports: sports,
        user: user,
        sizes: sizes,
      ),
      history,
    );
  }
}
