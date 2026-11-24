import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'OmegaCollection',
      minimumSize: Size(850, 550),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setTitle('OmegaCollection');
      // Inicia em janela normal para evitar artefatos na primeira renderização.
      // O usuário ainda pode maximizar manualmente pelo botão do Windows.
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const OmegaApp());
}

const red = Color(0xFFC81024);
const silver = Color(0xFFC7CBD2);
const bg = Color(0xFF111216);
const categories = ['Filmes', 'Séries', 'Livros', 'Jogos', 'Sites'];
const builtinIcons = [Icons.movie_outlined, Icons.tv_outlined, Icons.menu_book_outlined, Icons.sports_esports_outlined, Icons.language_outlined];
IconData categoryIcon(String category) => categories.contains(category) ? builtinIcons[categories.indexOf(category)] : Icons.category_outlined;
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
Map<String, dynamic> defaultCategory(String name) => {'id': name, 'nome': name, 'padrao': true, 'oculta': false, 'campos': <dynamic>[]};

class Store {
  static Future<File> get file async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}omega_collection.json');
  }
  static Map<String, dynamic> decode(String source) {
    final root = jsonDecode(source);
    if (root is! Map || root['items'] is! List || (root['version'] != 1 && root['version'] != 2)) {
      throw const FormatException('Arquivo de coleção incompatível.');
    }
    final categoryList = root['version'] == 2 && root['categorias'] is List
        ? (root['categorias'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : categories.map(defaultCategory).toList();
    final names = categoryList.map((e) => e['id'].toString()).toSet();
    if (categoryList.any((c) => c['id'] is! String || c['nome'] is! String || c['campos'] is! List) || names.length != categoryList.length) {
      throw const FormatException('Categorias inválidas no backup.');
    }
    final items = (root['items'] as List).map((e) {
      if (e is! Map || !names.contains(e['categoria'])) throw const FormatException('Registro inválido no backup.');
      return Map<String, dynamic>.from(e);
    }).toList();
    return {'version': 2, 'items': items, 'categorias': categoryList};
  }
  static String encode(List<Map<String, dynamic>> items, List<Map<String, dynamic>> cats) =>
      const JsonEncoder.withIndent('  ').convert({'version': 2, 'categorias': cats, 'items': items});
  static Future<Map<String, dynamic>> load() async {
    final f = await file;
    if (!await f.exists()) return {'items': <Map<String, dynamic>>[], 'categorias': categories.map(defaultCategory).toList()};
    return decode(await f.readAsString());
  }
  static Future<void> save(List<Map<String, dynamic>> items, List<Map<String, dynamic>> cats) async {
    final f = await file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(encode(items, cats), flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}

class OmegaApp extends StatelessWidget {
  const OmegaApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'OmegaCollection', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark).copyWith(
        primary: red, onPrimary: Colors.white,
        primaryContainer: const Color(0xFF710B19), onPrimaryContainer: Colors.white,
        secondary: red, onSecondary: Colors.white,
        surface: bg, onSurface: silver,
        surfaceContainer: const Color(0xFF1C1D22),
        surfaceContainerHigh: const Color(0xFF25262B),
        onSurfaceVariant: silver,
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: red, foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF55202A),
        disabledForegroundColor: const Color(0xFFBBA9AC),
      )),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: silver),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF1C1D22), modalBackgroundColor: Color(0xFF1C1D22)),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1C1D22)),
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF17181D), surfaceTintColor: Colors.transparent),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: red)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: red, side: const BorderSide(color: red))),
      cardTheme: CardThemeData(color: const Color(0xFF22252D)),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    home: const Home());
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _HomeState(); }
class _HomeState extends State<Home> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> categoryDefs = categories.map(defaultCategory).toList();
  bool loading = true;
  String search = '';
  String? selectedCategory;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final result = await Store.load(); if (mounted) setState(() {items = List<Map<String, dynamic>>.from(result['items']); categoryDefs = List<Map<String, dynamic>>.from(result['categorias']); loading = false;}); }
    catch (e) { if (mounted) {setState(() => loading = false); _message('Erro ao carregar: $e');} }
  }
  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> _persist(List<Map<String, dynamic>> next, [List<Map<String, dynamic>>? nextCats]) async {
    try { await Store.save(next, nextCats ?? categoryDefs); if (mounted) setState(() { items = next; if (nextCats != null) categoryDefs = nextCats; }); }
    catch (e) { _message('Não foi possível salvar: $e'); }
  }
  Future<void> _edit(String category, [Map<String, dynamic>? existing]) async {
    final updated = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => Editor(category: category, existing: existing, definition: categoryDefs.firstWhere((e) => e['id'] == category))));
    if (updated == null) return;
    final next = [...items];
    if (existing == null) {next.add(updated);} else {
      final index = next.indexWhere((e) => e['id'] == existing['id']);
      if (index < 0) return;
      next[index] = updated;
    }
    await _persist(next);
  }
  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir registro?'), content: const Text('Esta ação não pode ser desfeita.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir'))]));
    if (ok == true) await _persist(items.where((e) => e['id'] != item['id']).toList());
  }
  Future<void> _export() async {
    try {
      final bytes = utf8.encode(Store.encode(items, categoryDefs));
      final result = await FilePicker.platform.saveFile(dialogTitle: 'Exportar coleção', fileName: 'omega_collection_backup.json', type: FileType.custom, allowedExtensions: ['json'], bytes: Uint8List.fromList(bytes));
      if (result != null) _message('Backup exportado.');
    } catch (e) { _message('Falha ao exportar: $e'); }
  }
  Future<void> _import() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (picked == null) return;
      final p = picked.files.single;
      final bytes = p.bytes ?? (p.path != null ? await File(p.path!).readAsBytes() : null);
      if (bytes == null) throw const FormatException('Não foi possível ler o arquivo.');
      final decoded = Store.decode(utf8.decode(bytes));
      final imported = List<Map<String, dynamic>>.from(decoded['items']);
      final importedCats = List<Map<String, dynamic>>.from(decoded['categorias']);
      if (!mounted) return;
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Importar backup?'),
        content: const Text('Isso substituirá todos os registros atuais. Exporte um backup antes, se necessário.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Substituir'))]));
      if (ok == true) {await _persist(imported, importedCats); setState(() {selectedCategory = null; search = '';}); _message('Coleção importada.');}
    } catch (e) { _message('Falha ao importar: $e'); }
  }
  Future<void> _openSite(String value) async {
    final raw = value.trim(); if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null || !['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) { _message('Endereço inválido.'); return; }
    try { if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _message('Não foi possível abrir o site.'); }
    catch (_) { _message('Não foi possível abrir o site.'); }
  }
  Future<void> _manageCategories() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CategoryManager(
      definitions: categoryDefs, items: items,
      onSave: (cats, records) async { await _persist(records, cats); if (selectedCategory != null && !cats.any((c) => c['id'] == selectedCategory)) setState(() => selectedCategory = null); },
    )));
  }
  @override Widget build(BuildContext context) {
    final visibleCategories = categoryDefs.where((c) => c['oculta'] != true && items.any((i) => i['categoria'] == c['id'])).map((e) => e['id'].toString()).toList();
    return Scaffold(appBar: AppBar(title: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Ω', style: TextStyle(color: red, fontSize: 32, fontWeight: FontWeight.bold)), SizedBox(width: 10), Text('OmegaCollection')])),
      drawer: Drawer(child: SafeArea(child: ListView(children: [const ListTile(title: Text('OmegaCollection'), subtitle: Text('Sua coleção. Seu universo.')),
        ListTile(leading: const Icon(Icons.file_upload_outlined, color: red), title: const Text('Exportar JSON', style: TextStyle(color: red)), onTap: () {Navigator.pop(context); _export();}),
        ListTile(leading: const Icon(Icons.file_download_outlined, color: red), title: const Text('Importar JSON', style: TextStyle(color: red)), onTap: () {Navigator.pop(context); _import();}),
        ]))),
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(
          heroTag: 'manage_categories',
          backgroundColor: const Color(0xFF25262B), foregroundColor: Colors.white,
          icon: const Icon(Icons.tune), label: const Text('Gerenciar categorias'),
          onPressed: _manageCategories,
        ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(heroTag: 'new_record', backgroundColor: red, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Novo registro'), onPressed: () async {
        final category = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [const ListTile(title: Text('Escolha a categoria')),
          for (final c in categoryDefs.where((e) => e['oculta'] != true)) ListTile(leading: Icon(categoryIcon(c['id'].toString())), title: Text(c['nome'].toString()), onTap: () => Navigator.pop(ctx, c['id']))])));
        if (category != null) _edit(category);
      }),
      ]),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
        if (selectedCategory != null) ...[
          Row(children: [IconButton(onPressed: () => setState(() {selectedCategory = null; search = '';}), icon: const Icon(Icons.arrow_back)),
            Expanded(child: Text(categoryDefs.firstWhere((e) => e['id'] == selectedCategory)['nome'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 12),
        ],
        TextField(key: ValueKey(selectedCategory), onChanged: (v) => setState(() => search = v.toLowerCase()),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: selectedCategory == null ? 'Pesquisar em todos os registros...' : 'Pesquisar registros...')),
        const SizedBox(height: 18),
        if (selectedCategory == null && search.trim().isEmpty) ...[
          if (visibleCategories.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 64), child: Center(child: Text('Nenhuma categoria com registros visíveis.\nToque em Novo registro ou gerencie suas categorias.', textAlign: TextAlign.center))),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth >= 850 ? 4 : constraints.maxWidth >= 480 ? 3 : 2,
              childAspectRatio: 1.45,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final category in visibleCategories)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() { selectedCategory = category; search = ''; }),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(categoryIcon(category), color: red, size: 34),
                            const SizedBox(height: 8),
                            Text(categoryDefs.firstWhere((e) => e['id'] == category)['nome'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            const SizedBox(height: 5),
                            Text(
                              () {
                                final n = items.where((e) => e['categoria'] == category).length;
                                return '$n ${n == 1 ? 'registro' : 'registros'}';
                              }(),
                              style: const TextStyle(color: silver),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ] else if (selectedCategory == null) ...[
          // Pesquisa global: procura registros em todas as categorias.
          // Evita pesquisar a capa em base64, que não é texto do registro.
          for (final item in items.where((e) => categoryDefs.any((c) => c['id'] == e['categoria'] && c['oculta'] != true) && e.entries.any((entry) =>
              entry.key != 'capaBase64' &&
              entry.value.toString().toLowerCase().contains(search.trim()))))
            Card(child: ListTile(
              leading: CoverImage(base64Value: '${item['capaBase64'] ?? ''}', size: 54),
              title: Text(_title(item)),
              subtitle: Text('${categoryDefs.firstWhere((c) => c['id'] == item['categoria'])['nome']} · ${_subtitle(item)}', maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                final category = '${item['categoria']}';
                if (category == 'Sites' && '${item['site'] ?? ''}'.trim().isNotEmpty) {
                  _openSite('${item['site']}');
                } else {
                  _edit(category, item);
                }
              },
              trailing: PopupMenuButton<String>(
                onSelected: (choice) {
                  if (choice == 'edit') _edit('${item['categoria']}', item);
                  if (choice == 'delete') _delete(item);
                  if (choice == 'open') _openSite('${item['site'] ?? ''}');
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  if (item['categoria'] == 'Sites' && '${item['site'] ?? ''}'.trim().isNotEmpty)
                    const PopupMenuItem(value: 'open', child: Text('Abrir no navegador')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            )),
          if (!items.any((e) => categoryDefs.any((c) => c['id'] == e['categoria'] && c['oculta'] != true) && e.entries.any((entry) =>
              entry.key != 'capaBase64' &&
              entry.value.toString().toLowerCase().contains(search.trim()))))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Nenhum registro encontrado.')),
            ),
        ] else ...[
          for (final item in items.where((e) => e['categoria'] == selectedCategory && e.values.toString().toLowerCase().contains(search)))
            Card(child: ListTile(
              leading: CoverImage(base64Value: '${item['capaBase64'] ?? ''}', size: 54),
              title: Text(_title(item)), subtitle: Text(_subtitle(item), maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => selectedCategory == 'Sites' && '${item['site'] ?? ''}'.trim().isNotEmpty ? _openSite('${item['site']}') : _edit(selectedCategory!, item),
              trailing: PopupMenuButton<String>(onSelected: (choice) {if (choice == 'edit') _edit(selectedCategory!, item); if (choice == 'delete') _delete(item); if (choice == 'open') _openSite('${item['site'] ?? ''}');},
                itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  if (selectedCategory == 'Sites' && '${item['site'] ?? ''}'.isNotEmpty) const PopupMenuItem(value: 'open', child: Text('Abrir no navegador')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir'))]))),
        ]
      ]));
  }

  String _title(Map<String, dynamic> item) {
    for (final key in ['nome', 'site', 'descricao', 'colecao', 'observacoes']) {
      final value = '${item[key] ?? ''}'.trim(); if (value.isNotEmpty) return value;
    }
    final values = item['personalizados'];
    if (values is Map) { for (final v in values.values) { if ('$v'.trim().isNotEmpty) return '$v'; } }
    return 'Registro sem título';
  }
  String _subtitle(Map<String, dynamic> item) {
    if (item['categoria'] == 'Séries') return '${(item['temporadas'] as List? ?? []).length} temporada(s) · ${item['colecao'] ?? ''}';
    if (item['categoria'] == 'Sites') return '${item['descricao'] ?? ''}';
    final parts = ['autor', 'ano', 'formato', 'preco', 'avaliacao', 'situacao', 'colecao'].map((k) => '${item[k] ?? ''}').where((v) => v.isNotEmpty).toList();
    if (item['personalizados'] is Map) parts.addAll((item['personalizados'] as Map).values.map((v) => '$v').where((v) => v.isNotEmpty));
    return parts.join(' · ');
  }
}

class Editor extends StatefulWidget {
  final String category; final Map<String, dynamic>? existing; final Map<String, dynamic> definition;
  const Editor({super.key, required this.category, required this.definition, this.existing});
  @override State<Editor> createState() => _EditorState();
}
class _EditorState extends State<Editor> {
  late final Map<String, TextEditingController> fields;
  late List<Map<String, String>> seasons;
  String formato = '', avaliacao = '', situacao = '';
  String capaBase64 = '';
  final Map<String, TextEditingController> customControllers = {};
  final Map<String, String> customSelections = {};
  List<Map<String, dynamic>> get customFields => (widget.definition['campos'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<void> pickCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'], withData: true);
      if (result == null) return;
      final selected = result.files.single;
      final bytes = selected.bytes ?? (selected.path == null ? null : await File(selected.path!).readAsBytes());
      if (bytes == null) throw const FormatException('Imagem indisponível.');
      if (bytes.length > 3 * 1024 * 1024) throw const FormatException('Escolha uma imagem de até 3 MB.');
      if (mounted) setState(() => capaBase64 = base64Encode(bytes));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível selecionar a capa: $e'))); }
  }
  final keys = ['nome', 'ano', 'autor', 'preco', 'site', 'descricao', 'colecao', 'observacoes'];
  @override void initState() {
    super.initState(); final old = widget.existing ?? {};
    fields = {for (final k in keys) k: TextEditingController(text: '${old[k] ?? ''}')};
    capaBase64 = '${old['capaBase64'] ?? ''}';
    formato = '${old['formato'] ?? ''}'; avaliacao = '${old['avaliacao'] ?? ''}'; situacao = '${old['situacao'] ?? ''}';
    final oldCustom = old['personalizados'] is Map ? old['personalizados'] as Map : <String, dynamic>{};
    for (final f in customFields) {
      final id = f['id'].toString();
      customControllers[id] = TextEditingController(text: '${oldCustom[id] ?? ''}');
      customSelections[id] = '${oldCustom[id] ?? ''}';
    }
    seasons = (old['temporadas'] as List? ?? []).map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry('$k', '$v')))).toList();
  }
  @override void dispose() {for (final c in fields.values) {c.dispose();} for (final c in customControllers.values) {c.dispose();} super.dispose();}
  Widget input(String key, String label, {TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: fields[key], keyboardType: keyboard, maxLines: key == 'observacoes' || key == 'descricao' ? 3 : 1, decoration: InputDecoration(labelText: label)));
  Widget dropdown(String label, String value, List<String> choices, ValueChanged<String> update) => Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), items: ['', ...choices].map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'Não informado' : v))).toList(), onChanged: (v) => setState(() => update(v ?? ''))));
  Future<void> addSeason([int? index]) async {
    final previous = index == null ? <String, String>{} : seasons[index];
    final number = TextEditingController(text: previous['numero'] ?? '');
    final name = TextEditingController(text: previous['nome'] ?? '');
    final year = TextEditingController(text: previous['ano'] ?? '');
    final result = await showDialog<Map<String, String>>(context: context, builder: (ctx) => AlertDialog(title: Text(index == null ? 'Adicionar temporada' : 'Editar temporada'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número')),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome (opcional)')),
      TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () {if ([number.text, name.text, year.text].every((e) => e.trim().isEmpty)) return;
          Navigator.pop(ctx, {'numero': number.text.trim(), 'nome': name.text.trim(), 'ano': year.text.trim()});}, child: const Text('Salvar'))]));
    number.dispose(); name.dispose(); year.dispose();
    if (result != null) setState(() {if (index == null) {seasons.add(result);} else {seasons[index] = result;}});
  }
  Widget customInput(Map<String, dynamic> field) {
    final id = field['id'].toString();
    final type = field['tipo'].toString();
    final label = field['nome'].toString();
    if (type == 'Seleção' || type == 'Sim/Não') {
      final opts = type == 'Sim/Não' ? ['Sim', 'Não'] : (field['opcoes'] as List? ?? []).map((e) => e.toString()).toList();
      final value = customSelections[id] ?? '';
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(
        key: ValueKey('$id:$value'), initialValue: value.isEmpty || !opts.contains(value) ? '' : value,
        decoration: InputDecoration(labelText: label),
        items: ['', ...opts].map((e) => DropdownMenuItem(value: e, child: Text(e.isEmpty ? 'Não informado' : e))).toList(),
        onChanged: (v) => setState(() => customSelections[id] = v ?? ''),
      ));
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
      controller: customControllers[id],
      keyboardType: type == 'Número' ? TextInputType.number : type == 'Data' ? TextInputType.datetime : TextInputType.text,
      decoration: InputDecoration(labelText: '$label${type == 'Data' ? ' (DD/MM/AAAA)' : ''}'),
    ));
  }
  void save() {
    final values = {for (final e in fields.entries) e.key: e.value.text.trim()};
    final personalized = <String, String>{for (final f in customFields) f['id'].toString(): f['tipo'] == 'Seleção' || f['tipo'] == 'Sim/Não' ? (customSelections[f['id'].toString()] ?? '') : (customControllers[f['id'].toString()]?.text.trim() ?? '')};
    final hasText = values.values.any((v) => v.isNotEmpty) || personalized.values.any((v) => v.isNotEmpty);
    if (!hasText && formato.isEmpty && avaliacao.isEmpty && situacao.isEmpty && seasons.isEmpty && capaBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha ao menos um campo.'))); return;
    }
    final record = <String, dynamic>{'id': widget.existing?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(), 'categoria': widget.category, ...values, 'personalizados': personalized,
      if (capaBase64.isNotEmpty) 'capaBase64': capaBase64,
      if (widget.category != 'Sites') 'formato': formato,
      if (widget.category == 'Jogos') ...{'avaliacao': avaliacao, 'situacao': situacao},
      if (widget.category == 'Séries') 'temporadas': seasons};
    Navigator.pop(context, record);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.existing == null ? 'Novo: ${widget.category}' : 'Editar: ${widget.category}')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.category != 'Sites') input('nome', 'Nome'),
      if (widget.category == 'Filmes' || widget.category == 'Livros') input('ano', 'Ano', keyboard: TextInputType.number),
      if (widget.category == 'Livros') input('autor', 'Autor'),
      if (widget.category != 'Sites') dropdown('Formato', formato, widget.category == 'Livros' ? ['Físico', 'E-book'] : ['Físico', 'Digital'], (v) => formato = v),
      if (widget.category == 'Jogos') ...[input('preco', 'Preço pago (R\$)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        dropdown('Avaliação', avaliacao, ['Bom', 'Ruim'], (v) => avaliacao = v),
        dropdown('Situação', situacao, ['Baixar', 'Não baixar', 'Terminei', 'Abandonei'], (v) => situacao = v)],
      if (widget.category == 'Sites') ...[input('site', 'Endereço do site'), input('descricao', 'Sobre o que é o site')],
      if (widget.category == 'Séries') ...[
        const Text('Temporadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        for (var i = 0; i < seasons.length; i++) ListTile(title: Text('Temporada ${seasons[i]['numero']?.isEmpty == true ? '?' : seasons[i]['numero']} ${seasons[i]['nome'] ?? ''}'),
          subtitle: Text('Ano: ${seasons[i]['ano']?.isEmpty == true ? 'não informado' : seasons[i]['ano']}'),
          onTap: () => addSeason(i), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => seasons.removeAt(i)))),
        OutlinedButton.icon(onPressed: () => addSeason(), icon: const Icon(Icons.add), label: const Text('Adicionar temporada')),
        const SizedBox(height: 12)
      ],
      if (widget.category != 'Sites') ...[
        const SizedBox(height: 12),
        Row(children: [CoverImage(base64Value: capaBase64, size: 88), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton.icon(onPressed: pickCover, icon: const Icon(Icons.image_outlined), label: const Text('Escolher capa')),
            if (capaBase64.isNotEmpty) TextButton(onPressed: () => setState(() => capaBase64 = ''), child: const Text('Remover capa')),
            const Text('PNG, JPG ou WebP (até 3 MB). A capa fica dentro do backup JSON.', style: TextStyle(fontSize: 12, color: silver)),
          ]))]), const SizedBox(height: 12),
      ],
      if (customFields.isNotEmpty) ...[const SizedBox(height: 12), const Text('Campos personalizados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12)],
      for (final field in customFields) customInput(field),
      input('colecao', 'Coleção (opcional)'), input('observacoes', 'Observações'),
      const SizedBox(height: 12), FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Salvar registro')),
      const SizedBox(height: 20), const Text('Todos os campos são opcionais, mas pelo menos um precisa ter dados.', textAlign: TextAlign.center, style: TextStyle(color: silver))
    ]));
}


class CoverImage extends StatelessWidget {
  final String base64Value;
  final double size;
  const CoverImage({super.key, required this.base64Value, required this.size});
  @override Widget build(BuildContext context) {
    if (base64Value.isEmpty) return SizedBox(width: size * .75, height: size, child: const Icon(Icons.image_outlined, color: silver));
    try {
      return ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(base64Decode(base64Value), width: size * .75, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)));
    } catch (_) { return SizedBox(width: size * .75, height: size, child: const Icon(Icons.broken_image_outlined)); }
  }
}

class CategoryManager extends StatefulWidget {
  final List<Map<String, dynamic>> definitions;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(List<Map<String, dynamic>>, List<Map<String, dynamic>>) onSave;
  const CategoryManager({super.key, required this.definitions, required this.items, required this.onSave});
  @override State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  late List<Map<String, dynamic>> defs;
  late List<Map<String, dynamic>> records;
  @override void initState() {
    super.initState();
    defs = widget.definitions.map((e) => jsonDecode(jsonEncode(e)) as Map<String, dynamic>).toList();
    records = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  Future<void> commit() async {
    await widget.onSave(defs, records);
    if (mounted) setState(() {});
  }
  Future<void> addCategory() async {
    final name = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Nova categoria'), content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome da categoria')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim()), child: const Text('Criar'))]));
    name.dispose();
    if (result == null || result.isEmpty) return;
    if (defs.any((e) => e['nome'].toString().toLowerCase() == result.toLowerCase())) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já existe uma categoria com esse nome.')));
      return;
    }
    defs.add({'id': 'custom_${newId()}', 'nome': result, 'padrao': false, 'oculta': false, 'campos': <dynamic>[]});
    await commit();
  }
  Future<void> editCategory(Map<String, dynamic> category) async {
    final name = TextEditingController(text: category['nome'].toString());
    final newName = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Renomear categoria'), content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim()), child: const Text('Salvar'))]));
    name.dispose();
    if (newName == null || newName.isEmpty) return;
    if (defs.any((c) => c['id'] != category['id'] && c['nome'].toString().toLowerCase() == newName.toLowerCase())) return;
    category['nome'] = newName;
    await commit();
  }
  Future<void> removeCategory(Map<String, dynamic> category) async {
    final count = records.where((e) => e['categoria'] == category['id']).length;
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Excluir ${category['nome']}?'),
      content: Text('Esta categoria contém $count registro(s). A exclusão definitiva apagará todos eles. Exporte um backup JSON antes se quiser preservá-los.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'hide'), child: const Text('Apenas ocultar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Excluir categoria e registros'))]));
    if (result == 'hide') {category['oculta'] = true; await commit();}
    if (result == 'delete') {
      defs.removeWhere((e) => e['id'] == category['id']);
      records.removeWhere((e) => e['categoria'] == category['id']);
      await commit();
    }
  }
  Future<void> addField(Map<String, dynamic> category) async {
    final name = TextEditingController();
    final options = TextEditingController();
    String type = 'Texto';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: const Text('Novo campo'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do campo (ex.: Local)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Tipo'),
          items: ['Texto', 'Número', 'Data', 'Seleção', 'Sim/Não'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => update(() => type = v ?? 'Texto')),
        if (type == 'Seleção') ...[const SizedBox(height: 12), TextField(controller: options, maxLines: 4, decoration: const InputDecoration(labelText: 'Opções (uma por linha)'))],
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () {
          final label = name.text.trim();
          final opts = options.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
          if (label.isEmpty || (type == 'Seleção' && opts.isEmpty)) return;
          Navigator.pop(ctx, {'id': 'field_${newId()}', 'nome': label, 'tipo': type, 'opcoes': opts});
        }, child: const Text('Adicionar'))],
    )));
    name.dispose(); options.dispose();
    if (result == null) return;
    final fields = category['campos'] as List;
    if (fields.any((f) => (f as Map)['nome'].toString().toLowerCase() == result['nome'].toString().toLowerCase())) return;
    fields.add(result);
    await commit();
  }
  Future<void> editField(Map<String, dynamic> category, Map<String, dynamic> field) async {
    final name = TextEditingController(text: field['nome'].toString());
    final options = TextEditingController(text: (field['opcoes'] as List? ?? []).join('\n'));
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Editar campo'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
        if (field['tipo'] == 'Seleção') TextField(controller: options, maxLines: 4, decoration: const InputDecoration(labelText: 'Opções (uma por linha)')),
        const SizedBox(height: 8), Text('Tipo: ${field['tipo']} (fixo)', style: const TextStyle(color: silver)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, {'nome': name.text.trim(), 'opcoes': options.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()}), child: const Text('Salvar'))]));
    name.dispose(); options.dispose();
    if (result == null || result['nome'].toString().isEmpty) return;
    field['nome'] = result['nome'];
    if (field['tipo'] == 'Seleção') field['opcoes'] = result['opcoes'];
    await commit();
  }
  Future<void> deleteField(Map<String, dynamic> category, Map<String, dynamic> field) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Excluir campo ${field['nome']}?'),
      content: const Text('Os valores preenchidos neste campo serão apagados dos registros desta categoria. Faça backup antes, se necessário.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir campo'))]));
    if (ok != true) return;
    (category['campos'] as List).removeWhere((e) => (e as Map)['id'] == field['id']);
    for (final item in records.where((e) => e['categoria'] == category['id'])) {
      if (item['personalizados'] is Map) (item['personalizados'] as Map).remove(field['id']);
    }
    await commit();
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gerenciar categorias')),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: red, foregroundColor: Colors.white,
      onPressed: addCategory, icon: const Icon(Icons.add), label: const Text('Nova categoria')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
      const Text('Personalize as categorias e os campos. Os campos originais das categorias padrão são preservados.', style: TextStyle(color: silver)),
      const SizedBox(height: 14),
      for (final category in defs) Card(child: ExpansionTile(
        leading: Icon(categoryIcon(category['id'].toString()), color: red),
        title: Text(category['nome'].toString()),
        subtitle: Text('${category['padrao'] == true ? 'Padrão' : 'Personalizada'} · ${records.where((e) => e['categoria'] == category['id']).length} registros${category['oculta'] == true ? ' · Oculta' : ''}'),
        children: [
          Wrap(spacing: 4, children: [
            TextButton.icon(onPressed: () => editCategory(category), icon: const Icon(Icons.edit_outlined), label: const Text('Renomear')),
            TextButton.icon(onPressed: () {category['oculta'] = category['oculta'] != true; commit();},
              icon: Icon(category['oculta'] == true ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              label: Text(category['oculta'] == true ? 'Mostrar' : 'Ocultar')),
            TextButton.icon(onPressed: () => removeCategory(category), icon: const Icon(Icons.delete_outline, color: red), label: const Text('Excluir', style: TextStyle(color: red))),
          ]),
          for (final f in (category['campos'] as List)) ListTile(
            title: Text((f as Map)['nome'].toString()), subtitle: Text(f['tipo'].toString()),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Editar campo', icon: const Icon(Icons.edit_outlined), onPressed: () => editField(category, f as Map<String, dynamic>)),
              IconButton(tooltip: 'Excluir campo', icon: const Icon(Icons.delete_outline), onPressed: () => deleteField(category, f as Map<String, dynamic>)),
            ]),
          ),
          TextButton.icon(onPressed: () => addField(category), icon: const Icon(Icons.add, color: red), label: const Text('Adicionar campo')),
          const SizedBox(height: 8),
        ],
      )),
      for (final builtin in categories.where((name) => !defs.any((e) => e['id'] == name)))
        ListTile(leading: const Icon(Icons.restore, color: red), title: Text('Restaurar $builtin'),
          subtitle: const Text('Recriar categoria padrão vazia'),
          onTap: () {defs.add(defaultCategory(builtin)); commit();}),
      if (defs.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma categoria ativa. Crie uma ou restaure uma categoria padrão.', textAlign: TextAlign.center)),
    ]),
  );
}
