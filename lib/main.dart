import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const OmegaApp()); }

const red = Color(0xFFD72632);
const silver = Color(0xFFC7CBD2);
const bg = Color(0xFF111216);
const categories = ['Filmes', 'Séries', 'Livros', 'Jogos', 'Sites'];
const icons = [Icons.movie_outlined, Icons.tv_outlined, Icons.menu_book_outlined, Icons.sports_esports_outlined, Icons.language_outlined];

class Store {
  static Future<File> get file async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}omega_collection.json');
  }
  static Map<String, dynamic> decode(String source) {
    final root = jsonDecode(source);
    if (root is! Map || root['version'] != 1 || root['items'] is! List) {
      throw const FormatException('Arquivo de coleção incompatível.');
    }
    final items = (root['items'] as List).map((e) {
      if (e is! Map || !categories.contains(e['categoria'])) {
        throw const FormatException('Registro inválido.');
      }
      return Map<String, dynamic>.from(e);
    }).toList();
    return {'version': 1, 'items': items};
  }
  static String encode(List<Map<String, dynamic>> items) =>
      const JsonEncoder.withIndent('  ').convert({'version': 1, 'items': items});
  static Future<List<Map<String, dynamic>>> load() async {
    final f = await file;
    if (!await f.exists()) return [];
    return List<Map<String, dynamic>>.from(decode(await f.readAsString())['items']);
  }
  static Future<void> save(List<Map<String, dynamic>> items) async {
    final f = await file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(encode(items), flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}

class OmegaApp extends StatelessWidget {
  const OmegaApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'OmegaCollection', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: silver),
      cardTheme: CardThemeData(color: const Color(0xFF22252D)),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    home: const Home());
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _HomeState(); }
class _HomeState extends State<Home> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String search = '';
  String? selectedCategory;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final result = await Store.load(); if (mounted) setState(() {items = result; loading = false;}); }
    catch (e) { if (mounted) {setState(() => loading = false); _message('Erro ao carregar: $e');} }
  }
  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> _persist(List<Map<String, dynamic>> next) async {
    try { await Store.save(next); if (mounted) setState(() => items = next); }
    catch (e) { _message('Não foi possível salvar: $e'); }
  }
  Future<void> _edit(String category, [Map<String, dynamic>? existing]) async {
    final updated = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => Editor(category: category, existing: existing)));
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
      final bytes = utf8.encode(Store.encode(items));
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
      final imported = List<Map<String, dynamic>>.from(Store.decode(utf8.decode(bytes))['items']);
      if (!mounted) return;
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Importar backup?'),
        content: const Text('Isso substituirá todos os registros atuais. Exporte um backup antes, se necessário.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Substituir'))]));
      if (ok == true) {await _persist(imported); _message('Coleção importada.');}
    } catch (e) { _message('Falha ao importar: $e'); }
  }
  Future<void> _openSite(String value) async {
    final raw = value.trim(); if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null || !['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) { _message('Endereço inválido.'); return; }
    try { if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _message('Não foi possível abrir o site.'); }
    catch (_) { _message('Não foi possível abrir o site.'); }
  }
  @override Widget build(BuildContext context) {
    final visibleCategories = categories.where((c) => items.any((i) => i['categoria'] == c)).toList();
    return Scaffold(appBar: AppBar(title: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Ω', style: TextStyle(color: red, fontSize: 32, fontWeight: FontWeight.bold)), SizedBox(width: 10), Text('OmegaCollection')])),
      drawer: Drawer(child: SafeArea(child: ListView(children: [const ListTile(title: Text('OmegaCollection'), subtitle: Text('Sua coleção. Seu universo.')),
        ListTile(leading: const Icon(Icons.file_upload_outlined), title: const Text('Exportar JSON'), onTap: () {Navigator.pop(context); _export();}),
        ListTile(leading: const Icon(Icons.file_download_outlined), title: const Text('Importar JSON'), onTap: () {Navigator.pop(context); _import();})]))),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: red, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Novo registro'), onPressed: () async {
        final category = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [const ListTile(title: Text('Escolha a categoria')),
          for (var i = 0; i < categories.length; i++) ListTile(leading: Icon(icons[i]), title: Text(categories[i]), onTap: () => Navigator.pop(ctx, categories[i]))])));
        if (category != null) _edit(category);
      }),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
        if (selectedCategory != null) ...[
          Row(children: [IconButton(onPressed: () => setState(() {selectedCategory = null; search = '';}), icon: const Icon(Icons.arrow_back)),
            Expanded(child: Text(selectedCategory!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 12),
        ],
        TextField(key: ValueKey(selectedCategory), onChanged: (v) => setState(() => search = v.toLowerCase()),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: selectedCategory == null ? 'Pesquisar categorias...' : 'Pesquisar registros...')),
        const SizedBox(height: 18),
        if (selectedCategory == null) ...[
          if (visibleCategories.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 64), child: Center(child: Text('Sua coleção está vazia.\nToque em Novo registro para começar.', textAlign: TextAlign.center))),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth >= 850 ? 4 : constraints.maxWidth >= 480 ? 3 : 2,
              childAspectRatio: 1.45,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final category in visibleCategories.where((c) => c.toLowerCase().contains(search)))
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() { selectedCategory = category; search = ''; }),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icons[categories.indexOf(category)], color: red, size: 34),
                            const SizedBox(height: 8),
                            Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
    return 'Registro sem título';
  }
  String _subtitle(Map<String, dynamic> item) {
    if (item['categoria'] == 'Séries') return '${(item['temporadas'] as List? ?? []).length} temporada(s) · ${item['colecao'] ?? ''}';
    if (item['categoria'] == 'Sites') return '${item['descricao'] ?? ''}';
    return ['autor', 'ano', 'formato', 'preco', 'avaliacao', 'situacao', 'colecao'].map((k) => '${item[k] ?? ''}').where((v) => v.isNotEmpty).join(' · ');
  }
}

class Editor extends StatefulWidget {
  final String category; final Map<String, dynamic>? existing;
  const Editor({super.key, required this.category, this.existing});
  @override State<Editor> createState() => _EditorState();
}
class _EditorState extends State<Editor> {
  late final Map<String, TextEditingController> fields;
  late List<Map<String, String>> seasons;
  String formato = '', avaliacao = '', situacao = '';
  String capaBase64 = '';
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
    seasons = (old['temporadas'] as List? ?? []).map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry('$k', '$v')))).toList();
  }
  @override void dispose() {for (final c in fields.values) {c.dispose();} super.dispose();}
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
  void save() {
    final values = {for (final e in fields.entries) e.key: e.value.text.trim()};
    final hasText = values.values.any((v) => v.isNotEmpty);
    if (!hasText && formato.isEmpty && avaliacao.isEmpty && situacao.isEmpty && seasons.isEmpty && capaBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha ao menos um campo.'))); return;
    }
    final record = <String, dynamic>{'id': widget.existing?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(), 'categoria': widget.category, ...values,
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
