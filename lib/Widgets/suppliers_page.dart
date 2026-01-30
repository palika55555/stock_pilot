import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/Widgets/add_supplier_modal.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> with TickerProviderStateMixin {
  // Animácia pre zoznam
  late final AnimationController _listController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Aby sklo v AppBar fungovalo správne
      backgroundColor: const Color(0xFFF0F2F5),
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
                'Dodávatelia',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 26),
              ),
              actions: [
                _buildCircularAction(Icons.search),
                _buildCircularAction(Icons.tune),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 40),
            _buildAnimatedStats(),
            _buildAnimatedList(),
          ],
        ),
      ),
      floatingActionButton: _buildAnimatedFAB(),
    );
  }

  Widget _buildCircularAction(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: IconButton(icon: Icon(icon, color: Colors.black87, size: 20), onPressed: () {}),
    );
  }

  Widget _buildAnimatedStats() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildStatCard('Celkovo', '42', Colors.indigoAccent),
          _buildStatCard('Aktívni', '38', Colors.green),
          _buildStatCard('V riešení', '4', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _PressableSupplierCard(index: index, controller: _listController);
      },
    );
  }

  Widget _buildAnimatedFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _addSupplierWindow(context),
      backgroundColor: Colors.black,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      label: const Text('Pridať', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      icon: const Icon(Icons.add, color: Colors.white),
      
    );
  }
  // Funkciu definuj mimo metódy build alebo ako samostatnú metódu v triede
void _addSupplierWindow(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, 
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const AddSupplierModal(),
  );
}
}

// Komponent pre kartu s efektom stlačenia a animáciou vstupu
class _PressableSupplierCard extends StatefulWidget {
  final int index;
  final AnimationController controller;
  const _PressableSupplierCard({required this.index, required this.controller});

  @override
  State<_PressableSupplierCard> createState() => _PressableSupplierCardState();
}

class _PressableSupplierCardState extends State<_PressableSupplierCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    // Animácia posunu zdola nahor
    final animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval((0.1 * widget.index).clamp(0, 1.0), 1.0, curve: Curves.easeOutQuart),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.96),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildElegantAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TechLogistics s.r.o.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('Doručenie: dnes o 14:00', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFE0E0E0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantAvatar() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Text('T', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
      ),
    );
  }
}