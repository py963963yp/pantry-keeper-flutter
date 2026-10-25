import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PantryApp());
}

class PantryApp extends StatelessWidget {
  const PantryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2D765F);
    return MaterialApp(
      title: '小食仓',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: const Color(0xFFF6F7F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7F4),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE6EAE5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        ),
      ),
      home: const PantryHomePage(),
    );
  }
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.expiryDate,
    this.isConsumed = false,
  });

  final String id;
  final String name;
  final String category;
  final String quantity;
  final DateTime expiryDate;
  final bool isConsumed;

  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  PantryItem copyWith({bool? isConsumed}) {
    return PantryItem(
      id: id,
      name: name,
      category: category,
      quantity: quantity,
      expiryDate: expiryDate,
      isConsumed: isConsumed ?? this.isConsumed,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'expiryDate': expiryDate.toIso8601String(),
        'isConsumed': isConsumed,
      };

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: json['quantity'] as String,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      isConsumed: json['isConsumed'] as bool? ?? false,
    );
  }
}

enum PantryFilter { all, expiring, consumed }

const categories = <String, String>{
  '水果': '🍎',
  '蔬菜': '🥬',
  '乳品': '🥛',
  '主食': '🍞',
  '肉类': '🥩',
  '其他': '📦',
};

class PantryHomePage extends StatefulWidget {
  const PantryHomePage({super.key});

  @override
  State<PantryHomePage> createState() => _PantryHomePageState();
}

class _PantryHomePageState extends State<PantryHomePage> {
  static const storageKey = 'pantry_items_v1';

  List<PantryItem> items = [];
  PantryFilter filter = PantryFilter.all;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(storageKey);
    if (saved != null) {
      try {
        final decoded = jsonDecode(saved) as List<dynamic>;
        items = decoded
            .map((entry) => PantryItem.fromJson(
                  Map<String, dynamic>.from(entry as Map),
                ))
            .toList();
      } on Object {
        items = [];
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> saveItems() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> addItem() async {
    final item = await showDialog<PantryItem>(
      context: context,
      builder: (_) => const AddItemDialog(),
    );
    if (item == null || !mounted) return;
    setState(() => items.add(item));
    await saveItems();
  }

  Future<void> toggleConsumed(PantryItem item) async {
    setState(() {
      final index = items.indexWhere((entry) => entry.id == item.id);
      if (index >= 0) {
        items[index] = item.copyWith(isConsumed: !item.isConsumed);
      }
    });
    await saveItems();
  }

  Future<void> deleteItem(PantryItem item) async {
    setState(() => items.removeWhere((entry) => entry.id == item.id));
    await saveItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${item.name}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            setState(() => items.add(item));
            saveItems();
          },
        ),
      ),
    );
  }

  List<PantryItem> get visibleItems {
    final result = items.where((item) {
      switch (filter) {
        case PantryFilter.all:
          return true;
        case PantryFilter.expiring:
          return !item.isConsumed && item.daysUntilExpiry <= 3;
        case PantryFilter.consumed:
          return item.isConsumed;
      }
    }).toList();
    result.sort((first, second) {
      if (first.isConsumed != second.isConsumed) {
        return first.isConsumed ? 1 : -1;
      }
      return first.expiryDate.compareTo(second.expiryDate);
    });
    return result;
  }

  int get activeCount => items.where((item) => !item.isConsumed).length;

  int get expiringCount => items
      .where((item) => !item.isConsumed && item.daysUntilExpiry <= 3)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.kitchen_rounded, color: Color(0xFF2D765F)),
            SizedBox(width: 9),
            Text('小食仓', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-item-button'),
        onPressed: addItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget buildContent() {
    final visible = visibleItems;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        buildSummaryCard(),
        const SizedBox(height: 24),
        buildFilters(),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              '库存清单',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${visible.length} 项',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          buildEmptyState()
        else
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PantryItemCard(
                item: item,
                onToggleConsumed: () => toggleConsumed(item),
                onDelete: () => deleteItem(item),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF39866B), Color(0xFF225B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '冰箱里的新鲜',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '一眼看清，吃得刚刚好',
                      style: TextStyle(color: Color(0xFFD5EEE2), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.eco_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SummaryStat(label: '在库食材', value: '$activeCount'),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: Colors.white.withValues(alpha: 0.25),
              ),
              SummaryStat(label: '3 天内到期', value: '$expiringCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildFilters() {
    const filters = <(PantryFilter, String)>[
      (PantryFilter.all, '全部'),
      (PantryFilter.expiring, '快到期'),
      (PantryFilter.consumed, '已吃完'),
    ];
    return Wrap(
      spacing: 9,
      children: filters.map((entry) {
        final selected = filter == entry.$1;
        return ChoiceChip(
          label: Text(entry.$2),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => filter = entry.$1),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFDDEFE5),
          side: BorderSide(
            color: selected ? const Color(0xFF9BCAB0) : const Color(0xFFE8EBE6),
          ),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFF205A47) : Colors.black87,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget buildEmptyState() {
    final filtered = filter != PantryFilter.all;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9ECE7)),
      ),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.check_circle_outline : Icons.kitchen_outlined,
            size: 42,
            color: const Color(0xFF82A995),
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? '这里暂时空空的' : '还没有添加食材',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            filtered ? '换个分类看看吧' : '点「记一笔」开始管理保质期',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class SummaryStat extends StatelessWidget {
  const SummaryStat({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFFD5EEE2))),
      ],
    );
  }
}

class PantryItemCard extends StatelessWidget {
  const PantryItemCard({
    required this.item,
    required this.onToggleConsumed,
    required this.onDelete,
    super.key,
  });

  final PantryItem item;
  final VoidCallback onToggleConsumed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final urgencyColor = item.isConsumed
        ? Colors.grey
        : days < 0
            ? const Color(0xFFB64D42)
            : days <= 3
                ? const Color(0xFFB66B20)
                : const Color(0xFF397454);
    final expiryText = item.isConsumed
        ? '已吃完'
        : days < 0
            ? '已过期 ${-days} 天'
            : days == 0
                ? '今天到期'
                : days == 1
                    ? '明天到期'
                    : '$days 天后到期';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9ECE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5EF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              categories[item.category] ?? '📦',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    decoration: item.isConsumed
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.isConsumed
                        ? Colors.grey
                        : const Color(0xFF202721),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.category} · ${item.quantity}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  expiryText,
                  style: TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: item.isConsumed ? '移回库存' : '标记吃完',
            onPressed: onToggleConsumed,
            icon: Icon(
              item.isConsumed ? Icons.restart_alt_rounded : Icons.done_rounded,
              color: const Color(0xFF397454),
            ),
          ),
          IconButton(
            tooltip: '删除食材',
            onPressed: onDelete,
            icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class AddItemDialog extends StatefulWidget {
  const AddItemDialog({super.key});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final quantityController = TextEditingController(text: '1 份');
  String category = '水果';
  DateTime expiryDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> chooseExpiryDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: expiryDate.isBefore(today) ? today : expiryDate,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 10),
      helpText: '选择保质期',
    );
    if (selected != null) setState(() => expiryDate = selected);
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PantryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        category: category,
        quantity: quantityController.text.trim(),
        expiryDate: expiryDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = '${expiryDate.year}年${expiryDate.month}月${expiryDate.day}日';
    return AlertDialog(
      title: const Text('添加食材', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '食材名称',
                  hintText: '例如：牛奶',
                  prefixIcon: Icon(Icons.shopping_basket_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入食材名称' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: '分类',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories.keys
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry,
                        child: Text('${categories[entry]}  $entry'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => category = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: '数量',
                  hintText: '例如：2 盒',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入数量' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: chooseExpiryDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '保质期至',
                    prefixIcon: Icon(Icons.event_outlined),
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  child: Text(dateText),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加'),
        ),
      ],
    );
  }
}
