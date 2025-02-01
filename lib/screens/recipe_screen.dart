import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/animations.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  String? _recipe;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: 'AIzaSyCoax7u0MmNt4aNsv3oWeSxociT66zNnV8',
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();
    if (ingredient.isNotEmpty) {
      setState(() {
        _ingredients.add(ingredient);
        _ingredientController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _ingredients.clear();
      _recipe = null;
    });
  }

  Future<void> _generateRecipe() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some ingredients first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prompt = '''
Generate a recipe using these ingredients: ${_ingredients.join(', ')}.
Format the response as follows:
Recipe Name:
Cooking Time:
Servings:
Additional Ingredients Needed (if any):
Instructions:
1.
2.
3.
...
Note: Keep the response concise and direct, like a recipe card. No introductory text or AI-like responses.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      setState(() {
        _recipe = response.text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating recipe: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 0,
                child: const Text(
                  'Recipe Generator',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ingredientController,
                        decoration: InputDecoration(
                          hintText: 'Add an ingredient',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _addIngredient(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _addIngredient,
                      icon: const Icon(Icons.add_circle),
                      color: Theme.of(context).primaryColor,
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_ingredients.isNotEmpty)
                StaggeredSlideTransition(
                  animation: _fadeAnimation,
                  index: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Ingredients:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _clearAll,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear All'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _ingredients.asMap().entries.map((entry) {
                            return Chip(
                              label: Text(entry.value),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _removeIngredient(entry.key),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateRecipe,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.restaurant_menu),
                        label: Text(_isLoading ? 'Generating...' : 'Generate Recipe'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (_recipe != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _generateRecipe,
                        icon: const Icon(Icons.refresh),
                        color: Theme.of(context).primaryColor,
                        tooltip: 'Generate Another Recipe',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_recipe != null)
                Expanded(
                  child: StaggeredSlideTransition(
                    animation: _fadeAnimation,
                    index: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _recipe!,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 