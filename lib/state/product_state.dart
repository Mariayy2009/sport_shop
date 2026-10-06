import 'package:flutter/foundation.dart';

import '../data/repositories/product_repository.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_filter.dart';
import '../models/sport.dart';

/// Сортировка каталога.
enum ProductSort {
  byName('По названию'),
  priceAsc('Сначала дешевле'),
  priceDesc('Сначала дороже');

  const ProductSort(this.label);

  final String label;
}

/// Состояние каталога: список товаров, фильтр, справочники.
class ProductState extends ChangeNotifier {
  ProductState(this._repository);

  final ProductRepository _repository;

  List<Product> _products = [];
  List<Sport> _sports = [];
  List<ProductCategory> _categories = [];
  List<String> _allSizes = [];
  ProductFilter _filter = const ProductFilter();
  ProductSort _sort = ProductSort.byName;
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Sport> get sports => _sports;
  List<ProductCategory> get categories => _categories;
  List<String> get allSizes => _allSizes;
  ProductFilter get filter => _filter;
  ProductSort get sort => _sort;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Загрузка справочников и каталога при старте приложения.
  Future<void> init() async {
    try {
      _sports = await _repository.getSports();
      _categories = await _repository.getCategories();
      final List<Product> all = await _repository.getProducts();
      _allSizes = _collectSizes(all);
    } catch (error) {
      debugPrint('Ошибка загрузки справочников: $error');
    }
    await loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = _sorted(await _repository.getProducts(_filter));
      _error = null;
    } catch (error) {
      debugPrint('Ошибка загрузки каталога: $error');
      _error = 'Не удалось загрузить товары. Потяните вниз, чтобы обновить';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilter(ProductFilter filter) {
    _filter = filter;
    return loadProducts();
  }

  Future<void> search(String query) => applyFilter(_filter.withQuery(query));

  Future<void> resetFilters() => applyFilter(_filter.cleared());

  /// Каталог одного вида спорта (плитки на главной).
  Future<void> showSport(int sportId) =>
      applyFilter(ProductFilter(sportId: sportId));

  /// Весь каталог без фильтров.
  Future<void> showAll() => applyFilter(const ProductFilter());

  void setSort(ProductSort sort) {
    _sort = sort;
    _products = _sorted(_products);
    notifyListeners();
  }

  String? sportName(int? id) {
    for (final Sport sport in _sports) {
      if (sport.id == id) return sport.name;
    }
    return null;
  }

  String? categoryName(int? id) {
    for (final ProductCategory category in _categories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  List<Product> _sorted(List<Product> source) {
    final List<Product> list = List.of(source);
    switch (_sort) {
      case ProductSort.byName:
        list.sort((a, b) => a.name.compareTo(b.name));
      case ProductSort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  /// Все размеры из каталога: сначала буквенные по порядку, затем числовые.
  static List<String> _collectSizes(List<Product> products) {
    const List<String> letterOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
    final Set<String> sizes = {
      for (final Product product in products) ...product.availableSizes,
    };
    int rank(String size) {
      final int letterIndex = letterOrder.indexOf(size);
      if (letterIndex >= 0) return letterIndex;
      final int? number =
          int.tryParse(RegExp(r'^\d+').firstMatch(size)?.group(0) ?? '');
      return number == null ? 100000 : 1000 + number;
    }

    return sizes.toList()
      ..sort((a, b) {
        final int byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
  }
}
