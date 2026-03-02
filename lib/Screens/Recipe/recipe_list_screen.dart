import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../services/Recipe/recipe_service.dart';
import 'recipe_detail_screen.dart';

class RecipeListScreen extends StatefulWidget {
  final String userRole;

  const RecipeListScreen({super.key, required this.userRole});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final RecipeService _recipeService = RecipeService();
  List<Recipe> _recipes = [];
  bool _loading = true;
  bool? _filterActive;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);
    final list = await _recipeService.getRecipes(
      activeOnly: _filterActive,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (mounted) setState(() {
      _recipes = list;
      _loading = false;
    });
  }

  void _openNewRecipe() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipeId: null, userRole: widget.userRole),
      ),
    );
    if (added == true) _loadRecipes();
  }

  void _openRecipe(Recipe recipe) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipeId: recipe.id, userRole: widget.userRole),
      ),
    );
    if (updated == true) {
      _loadRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.7),
              elevation: 0,
              centerTitle: false,
              title: const Text(
                'Receptúry',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Hľadať podľa názvu alebo produktu',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _loadRecipes();
              },
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Všetky'),
                  selected: _filterActive == null,
                  onSelected: (_) {
                    setState(() => _filterActive = null);
                    _loadRecipes();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Aktívne'),
                  selected: _filterActive == true,
                  onSelected: (_) {
                    setState(() => _filterActive = true);
                    _loadRecipes();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Neaktívne'),
                  selected: _filterActive == false,
                  onSelected: (_) {
                    setState(() => _filterActive = false);
                    _loadRecipes();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _recipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Žiadne receptúry',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _openNewRecipe,
                              icon: const Icon(Icons.add),
                              label: const Text('Nová receptúra'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _recipes.length,
                        itemBuilder: (context, index) {
                          final r = _recipes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: r.isActive
                                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: r.isActive ? const Color(0xFF4CAF50) : Colors.grey,
                                ),
                              ),
                              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${r.finishedProductName ?? r.finishedProductUniqueId} • ${r.outputQuantity} ${r.unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: r.isActive
                                          ? const Color(0xFF4CAF50).withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      r.isActive ? 'Aktívna' : 'Neaktívna',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: r.isActive ? const Color(0xFF2E7D32) : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => _openRecipe(r),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRecipe,
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nová receptúra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
