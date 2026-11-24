# Contribuindo com o Ω OmegaCollection

Obrigado pelo interesse em melhorar o OmegaCollection! Contribuições de código, documentação, tradução, testes e sugestões são bem-vindas.

## Antes de começar

1. Consulte as [Issues](https://github.com/JulianoHOmega/OmegaCollection/issues) existentes para evitar duplicações.
2. Para mudanças maiores, abra uma Issue descrevendo a proposta antes de implementá-la.
3. Mantenha o objetivo do projeto: aplicativo offline, simples e multiplataforma.

## Ambiente de desenvolvimento

Instale o Flutter SDK e as ferramentas de desenvolvimento da sua plataforma. Depois execute:

```bash
flutter create --platforms=windows,linux,android --project-name omega_collection .
flutter pub get
flutter analyze lib
flutter test
```

O comando `flutter test` executa os testes disponíveis; caso ainda não existam testes automatizados no repositório, informe isso no Pull Request. Para executar o aplicativo, use `flutter run -d windows`, `flutter run -d linux` ou um dispositivo Android configurado.

## Enviando uma alteração

1. Faça um fork e crie uma branch descritiva, como `fix/corrigir-busca` ou `feat/novos-campos`.
2. Faça mudanças pequenas e relacionadas ao mesmo objetivo.
3. Execute `dart format lib`, `flutter analyze lib` e os testes aplicáveis.
4. Teste a interface nas plataformas disponíveis e descreva quais foram verificadas.
5. Abra um Pull Request explicando a mudança, o motivo e como foi testada. Inclua capturas de tela quando alterar a interface.

## Cuidados importantes

- **Não quebre backups antigos.** O armazenamento atual utiliza JSON versão 2 e aceita importação de backups versão 1.
- **Preserve os dados do usuário.** Mudanças de esquema devem ter migração e validação.
- **Não remova funcionalidades existentes sem discussão**, especialmente categorias padrão, temporadas agrupadas, capas e campos personalizados.
- **Evite dependências desnecessárias** e preserve o funcionamento offline.
- **Não inclua dados pessoais, backups reais, credenciais, chaves de assinatura, binários gerados ou arquivos temporários** nos commits.
- Mantenha a identidade visual do projeto em preto, vermelho e prata.
- Mudanças no GitHub Actions devem considerar Windows, Linux e Android.

## Reportando problemas

Abra uma [Issue](https://github.com/JulianoHOmega/OmegaCollection/issues) informando a plataforma, versão do aplicativo, passos para reproduzir, comportamento esperado e observado. Se possível, anexe logs e capturas de tela, removendo informações pessoais.

## Licença

Ao contribuir, você concorda que sua contribuição seja disponibilizada sob a [Licença MIT](LICENSE) do projeto.
