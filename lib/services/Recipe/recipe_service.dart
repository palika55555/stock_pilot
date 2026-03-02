import '../../models/recipe.dart';
import '../../models/product.dart';
import '../Database/database_service.dart';

/// Ingredient row with current stock and sufficient flag for UI.
class RecipeIngredientWithStock {
  final RecipeIngredient ingredient;
  final double stockOnHand;
  final bool hasEnoughStock;
  final double requiredForPlanned;
  final String? unit;

  const RecipeIngredientWithStock({
    required this.ingredient,
    required this.stockOnHand,
    required this.hasEnoughStock,
    required this.requiredForPlanned,
    this.unit,
  });
}

class RecipeService {
  final DatabaseService _db = DatabaseService();

  Future<List<Recipe>> getRecipes({bool? activeOnly, String? search}) async {
    return _db.getRecipes(activeOnly: activeOnly, search: search);
  }

  Future<Recipe?> getRecipeById(int id) async {
    return _db.getRecipeById(id);
  }

  Future<int> saveRecipe(Recipe recipe, List<RecipeIngredient> ingredients) async {
    int recipeId;
    if (recipe.id == null) {
      recipeId = await _db.insertRecipe(recipe);
    } else {
      recipeId = recipe.id!;
      await _db.updateRecipe(recipe);
      await _db.deleteRecipeIngredientsByRecipeId(recipeId);
    }
    for (final ing in ingredients) {
      await _db.insertRecipeIngredient(ing.copyWith(recipeId: recipeId));
    }
    return recipeId;
  }

  Future<void> deleteRecipe(int id) async {
    await _db.deleteRecipe(id);
  }

  Future<List<RecipeIngredient>> getRecipeIngredients(int recipeId) async {
    return _db.getRecipeIngredients(recipeId);
  }

  /// For a given planned output quantity, get required qty per ingredient: (ingredient_qty / recipe_output_qty) * planned.
  double requiredQuantityForPlanned(Recipe recipe, RecipeIngredient ing, double plannedOutput) {
    if (recipe.outputQuantity <= 0) return 0;
    return (ing.quantity / recipe.outputQuantity) * plannedOutput;
  }

  /// Get ingredients with current stock in [warehouseId]. [plannedOutput] used for required amount.
  Future<List<RecipeIngredientWithStock>> getIngredientsWithStock(
    int recipeId,
    int? warehouseId,
    double plannedOutput,
  ) async {
    final recipe = await _db.getRecipeById(recipeId);
    if (recipe == null) return [];
    final ingredients = await _db.getRecipeIngredients(recipeId);
    final result = <RecipeIngredientWithStock>[];
    for (final ing in ingredients) {
      double stock = 0;
      Product? product;
      if (warehouseId != null) {
        final products = await _db.getProductsByWarehouseId(warehouseId);
        try {
          product = products.firstWhere((p) => p.uniqueId == ing.productUniqueId);
        } catch (_) {
          product = null;
        }
        if (product != null) stock = product.qty.toDouble();
      } else {
        product = await _db.getProductByUniqueId(ing.productUniqueId);
        if (product != null) stock = product.qty.toDouble();
      }
      final required = requiredQuantityForPlanned(recipe, ing, plannedOutput);
      result.add(RecipeIngredientWithStock(
        ingredient: ing,
        stockOnHand: stock,
        hasEnoughStock: stock >= required,
        requiredForPlanned: required,
        unit: ing.unit,
      ));
    }
    return result;
  }

  /// Material cost for one batch: sum of (ingredient_qty * product.purchasePrice) for each ingredient.
  Future<double> calculateMaterialCostForBatch(int recipeId, int? sourceWarehouseId) async {
    final recipe = await _db.getRecipeById(recipeId);
    if (recipe == null) return 0;
    final ingredients = await _db.getRecipeIngredients(recipeId);
    double total = 0;
    for (final ing in ingredients) {
      Product? p;
      if (sourceWarehouseId != null) {
        final list = await _db.getProductsByWarehouseId(sourceWarehouseId);
        try {
          p = list.firstWhere((x) => x.uniqueId == ing.productUniqueId);
        } catch (_) {
          p = null;
        }
      } else {
        p = await _db.getProductByUniqueId(ing.productUniqueId);
      }
      if (p != null) {
        total += ing.quantity * (p.purchasePrice);
      }
    }
    return _round(total);
  }

  /// Cost per unit (material only) for recipe: materialCostForBatch / outputQuantity.
  Future<double> materialCostPerUnit(int recipeId, int? sourceWarehouseId) async {
    final recipe = await _db.getRecipeById(recipeId);
    if (recipe == null || recipe.outputQuantity <= 0) return 0;
    final cost = await calculateMaterialCostForBatch(recipeId, sourceWarehouseId);
    return _round(cost / recipe.outputQuantity);
  }

  static double _round(double v) => (v * 100).round() / 100;
}
