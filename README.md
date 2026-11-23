# Ω OmegaCollection

Catálogo pessoal **offline** de filmes, séries, livros, jogos e sites. Tema preto, vermelho e prata.

## Funcionalidades v1.0 (código inicial)

- Filmes: nome e ano.
- Séries: cadastro único com lista editável de temporadas (número, nome e ano).
- Livros: nome, autor, ano e formato físico/e-book.
- Jogos: nome, preço pago, avaliação (bom/ruim) e situação (baixar/não baixar/terminei/abandonei).
- Sites: endereço, descrição e abertura no navegador padrão pelo menu do registro.
- Todas as categorias: coleção e observações; campos opcionais, exigindo pelo menos um dado.
- Início mostra somente categorias com registros; busca, edição e exclusão.
- Dados locais em JSON versionado, com exportação e importação de backup.

## Como preparar e executar

Instale o [Flutter SDK](https://docs.flutter.dev/get-started/install) e as dependências de compilação da plataforma. Na pasta do projeto:

```bash
flutter create --platforms=windows,linux,android --project-name omega_collection .
flutter pub get
flutter run -d windows  # no Windows
# flutter run -d linux   # no Linux
# flutter run -d <android-device-id>  # com dispositivo Android configurado
```

O `flutter create` gera os diretórios nativos, que não estão incluídos neste pacote inicial. Para conferir o ambiente, use `flutter doctor`.

## GitHub Actions

Envie os arquivos para um repositório novo no GitHub, preferencialmente `OmegaCollection`, com branch principal `main`. O workflow `.github/workflows/build.yml` compila em Windows, Linux e Android em runners separados, disponibilizando os resultados na aba **Actions**. Ao enviar uma tag `v1.0.0`, tenta publicar automaticamente os arquivos em **Releases**.

```bash
git init
git add .
git commit -m "Initial OmegaCollection Flutter app"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/OmegaCollection.git
git push -u origin main
# após validar as builds:
git tag v1.0.0
git push origin v1.0.0
```

**Android:** o APK inicial de release é assinado com a chave de desenvolvimento padrão do Flutter, quando disponível no runner. Antes de distribuir amplamente, configure uma chave de assinatura de produção persistente para futuras atualizações.

## Dados e backup

Os dados são gravados automaticamente em `omega_collection.json` dentro da pasta de suporte da aplicação, definida pelo sistema operacional via `path_provider`. No Android, desinstalar o app pode apagar esse arquivo. Use **Menu → Exportar JSON** para manter uma cópia externa; **Importar JSON** substitui os registros atuais após confirmação. Não é sincronização automática entre dispositivos.

O esquema JSON contém `version: 1` e `items: [...]`; cada item contém `id`, `categoria` e os campos específicos. As temporadas ficam dentro do mesmo item de série.

## Observações técnicas

Este é um **primeiro código-fonte**, não uma build previamente compilada ou testada no dispositivo. O funcionamento de seleção/exportação de arquivos e do navegador deve ser validado em cada plataforma. O app não solicita internet para a coleção; abrir sites usa o navegador do dispositivo. O símbolo Ω é temporário e pode ser substituído por ícones próprios para Windows, Linux e Android.

## Atualização v1.1 — Categorias e capas

A página inicial agora mostra apenas categorias que possuem registros. Clique na categoria para ver seus itens. Filmes, séries, livros e jogos possuem campo de formato físico/digital (livros: físico/e-book). Cada registro dessas categorias pode receber uma capa PNG/JPEG/WebP de até 3 MB. A imagem é codificada em Base64 no mesmo JSON, preservada na exportação/importação. JSON v1 permanece compatível com os backups anteriores. O tamanho do JSON aumenta conforme as imagens adicionadas.

Os ícones OmegaCollection são aplicados após `flutter create` pelo script `scripts/apply_branding.py`: `.ico` para Windows, ícones launcher Android e PNG para Linux (incluído no pacote Linux). Para usar o PNG como ícone no menu de aplicativos Linux, configure um arquivo `.desktop` no sistema.

**Atenção:** a compilação depende do GitHub Actions; não foram executados builds Flutter locais neste pacote.

## Ajustes v1.1.2

- Botões e destaques em vermelho mais forte (`#C81024`), sem o rosa claro do tema automático.
- Janela maximizada (não fullscreen) ao abrir no Windows e Linux via `window_manager`.
- Título da janela Windows alterado para `OmegaCollection`; nome do executável também.
- Recurso `.ico` aplicado ao EXE Windows durante o build. Se o Explorer mostrar o ícone antigo, teste o novo EXE em outra pasta ou atualize o cache de ícones do Windows.
- O nome interno do pacote Flutter continua `omega_collection` por compatibilidade com o projeto.

**Validação pendente:** execute o GitHub Actions e teste a janela, ícone e compilação em cada plataforma.
