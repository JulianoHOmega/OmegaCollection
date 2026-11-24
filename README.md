<div align="center">

# Ω OmegaCollection

### Sua coleção. Seu universo.

**Organize filmes, séries, livros, jogos, sites e tudo o que você quiser — em um só lugar, mesmo offline.**

![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-Dispon%C3%ADvel-20232A?logo=windows&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-Dispon%C3%ADvel-20232A?logo=linux&logoColor=white)
![Android](https://img.shields.io/badge/Android-Dispon%C3%ADvel-20232A?logo=android&logoColor=white)
![MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-C81024)

**[⬇️ Windows](https://github.com/JulianoHOmega/OmegaCollection/releases/download/v2.0/OmegaCollection-windows.zip)** · **[⬇️ Linux](https://github.com/JulianoHOmega/OmegaCollection/releases/download/v2.0/OmegaCollection-linux.zip)** · **[⬇️ Android](https://github.com/JulianoHOmega/OmegaCollection/releases/download/v2.0/OmegaCollection-apk.zip)**

[Ver a Release v2.0](https://github.com/JulianoHOmega/OmegaCollection/releases/tag/v2.0) · [Reportar problema](https://github.com/JulianoHOmega/OmegaCollection/issues)

</div>

---

## ✨ O que é o OmegaCollection?

O **OmegaCollection** é um gerenciador pessoal de coleções, gratuito e de código aberto, desenvolvido em **Flutter** para **Windows, Linux e Android**. Organize seus registros sem precisar de conta ou conexão com a internet. O visual segue a identidade Ω em **preto, vermelho e prata**.

## 🗂️ Recursos

- **Filmes:** nome, ano, formato físico/digital, capa, coleção e observações.
- **Séries:** uma série com várias temporadas agrupadas, cada uma com número, nome opcional e ano; formato, capa e observações.
- **Livros:** nome, autor, ano, formato físico/e-book, capa, coleção e observações.
- **Jogos:** nome, preço pago, avaliação, situação, formato físico/digital, capa, coleção e observações.
- **Sites:** endereço e descrição, com opção de abrir o link no navegador.
- **Categorias personalizadas:** crie, renomeie, oculte, exclua e restaure categorias padrão.
- **Campos personalizados:** adicione campos às categorias originais ou criadas por você; tipos texto, número, data (entrada textual), seleção configurável e sim/não.
- **Busca global:** encontre registros de diferentes categorias na mesma pesquisa.
- **Capas:** imagens PNG, JPG ou WebP de até 3 MB, armazenadas no backup JSON.
- **Backup e restauração:** exporte e importe seus dados em JSON, inclusive categorias e campos personalizados.

A página inicial mostra apenas categorias visíveis com registros. Os campos são opcionais, mas cada registro precisa conter pelo menos uma informação.

## 📥 Downloads

| Plataforma | Download | Como usar |
| --- | --- | --- |
| 🪟 Windows | [OmegaCollection-windows.zip](https://github.com/JulianoHOmega/OmegaCollection/releases/download/v2.0/OmegaCollection-windows.zip) | Extraia o ZIP e execute o `.exe` na pasta extraída, mantendo os arquivos ao lado dele. |
| 🐧 Linux | [OmegaCollection-linux.zip](https://github.com/JulianoHOmega/OmegaCollection/releases/download/v2.0/OmegaCollection-linux.zip) | Extraia o ZIP, localize o executável e conceda permissão de execução se necessário. |
| 🤖 Android | [OmegaCollection-apk.zip](https://github.com/JulianoHOmega/OmegaCollection/releases/download/v2.0/OmegaCollection-apk.zip) | Extraia o ZIP, abra o `.apk` no Android e autorize a instalação quando solicitado. |

> **Atenção:** os arquivos acima são links fornecidos para a Release `v2.0`. A numeração da Release é independente da versão interna que pode aparecer no `pubspec.yaml`.

## 💾 Onde ficam os dados?

Os registros são armazenados localmente em `omega_collection.json`, no diretório de suporte do aplicativo, determinado pelo sistema operacional. O arquivo JSON usa o esquema **versão 2**, com suporte à importação de backups antigos da versão 1.

**Exporte um backup regularmente.** Desinstalar o aplicativo, especialmente no Android, pode apagar os dados locais. Importar um backup substitui os dados atuais após confirmação. O OmegaCollection **não sincroniza automaticamente** os dados entre dispositivos.

## 🛠️ Executar a partir do código-fonte

Instale o [Flutter SDK](https://docs.flutter.dev/get-started/install) e as ferramentas necessárias à plataforma. Na raiz do projeto:

```bash
flutter doctor
flutter create --platforms=windows,linux,android --project-name omega_collection .
flutter pub get
flutter run -d windows
```

Para Linux, use `flutter run -d linux`; para Android, selecione um dispositivo com `flutter devices` e use `flutter run -d <id-do-dispositivo>`.

Os diretórios nativos são gerados pelo `flutter create`. O script `scripts/apply_branding.py` aplica os ícones de marca durante o GitHub Actions. As compilações automatizadas ficam em [Actions](https://github.com/JulianoHOmega/OmegaCollection/actions).

## 🤝 Contribuições

Ideias, correções, documentação e melhorias são bem-vindas. Consulte o [CONTRIBUTING.md](CONTRIBUTING.md) antes de abrir um Pull Request. Você também pode registrar sugestões ou problemas em [Issues](https://github.com/JulianoHOmega/OmegaCollection/issues).

## 📜 Licença

Distribuído sob a **Licença MIT**. Consulte [LICENSE](LICENSE).

---

<div align="center">

**Ω OmegaCollection — Sua coleção. Seu universo.**

Desenvolvido por [JulianoHOmega](https://github.com/JulianoHOmega).

</div>
