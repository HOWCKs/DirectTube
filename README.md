# DirectTube

Baixador de vídeo e música para Android, com interface **neumórfica (soft UI)** e
resposta tátil em cada controle. Um único código-fonte Flutter; o iOS entra na v2.

> **Status:** v0.1.0 — primeira build funcional. Acompanhe a aba *Actions* para
> baixar o APK de cada commit.

---

## Por que este repositório existe

O DirectTube é um substituto moderno de apps como SnapTube: você cola um link
(ou busca), escolhe o formato e o arquivo vai para a biblioteca do aparelho.
Sem servidor intermediário obrigatório — a extração acontece **no dispositivo**.

## Stack

| Camada | Escolha | Motivo |
| --- | --- | --- |
| UI | Flutter (Material 3 + sistema neumórfico próprio) | Um código para Android e iOS, animações e sombras baratas |
| Extração | `youtube_explode_dart` (Dart puro) | Sem runtime Python no APK; funciona no primeiro dia |
| Extração (fallback) | yt-dlp via `MethodChannel` | 1000+ sites, plugável sem tocar em nenhuma tela |
| Áudio | `just_audio` | Reprodução local estável |
| Vídeo | `video_player` | Reprodução local oficial do Flutter |
| Estado | `ChangeNotifier` + `InheritedNotifier` | Zero dependência de package de injeção |
| Persistência | `shared_preferences` (fila + preferências) | Simples e suficiente |

## Arquitetura

```
lib/
├── core/            lógica pura (parser de links, formatação, haptics)
├── design/          sistema neumórfico: tokens, tema, widgets
├── l10n/            strings pt-BR e en (sem codegen)
├── data/
│   ├── models/      MediaItem, FormatOption, DownloadTask
│   ├── engine/      interface única + motores (YouTube nativo, yt-dlp)
│   └── services/    fila, gerenciador, arquivos, preferências, player
└── features/        home, downloads, player, biblioteca, ajustes
```

**Regra que sustenta o projeto:** as telas nunca falam com um motor. Elas falam
com `DownloadManager`, que escolhe o motor via `EngineRegistry`. Trocar ou
adicionar um motor (ex.: ligar o módulo yt-dlp) não altera uma linha de UI.

## Sistema de design

Contrato visual completo e interativo em
[`design/neumorphic-preview/index.html`](design/neumorphic-preview/index.html)
(abra no navegador; há vibração real em Android). Os mesmos valores estão
travados por testes em `test/design_tokens_test.dart`.

| Token | Valor |
| --- | --- |
| Superfície (fundo e cartões) | `#e0e5ec` |
| Sombra inferior-direita | `9px 9px 18px #bec3c9` |
| Sombra superior-esquerda | `-9px -9px 18px #ffffff` |
| Estado ativo | `inset` (pintado por `InnerShadowPainter`) |
| Raios | `16px` · `20px` · `24px` |
| Acento | `#4d6bfe` |
| Texto | `#2d3436` |

O Flutter não tem sombra `inset` em `BoxShadow`; o efeito pressionado é
desenhado por um `CustomPainter` que recorta a superfície e desfoca o
"mundo externo" para dentro (`lib/design/neu_palette.dart`).

## Como compilar

O esqueleto nativo (gradle wrapper e scripts) é gerado pelo Flutter e recebe as
configurações canônicas do projeto por cima:

```bash
flutter pub get
bash tool/setup_android.sh     # applicationId com.directtube.app + permissões
flutter run                    # ou: flutter build apk --release
```

A CI faz exatamente isso a cada push e publica o artefato
`directtube-debug.apk` na aba **Actions**.

### Ativando a CI (passo único)

O workflow está versionado em [`docs/ci-workflow.yml`](docs/ci-workflow.yml)
porque o token de integração usado no ambiente de desenvolvimento não tem a
permissão `workflows` do GitHub e não consegue criar arquivos em
`.github/workflows/`. Para ligar a esteira, copie o arquivo para o lugar certo:

```bash
mkdir -p .github/workflows
cp docs/ci-workflow.yml .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "ci: esteira de analyze, testes e build do APK"
git push
```

A partir daí, cada push gera o APK em **Actions → build-android → Artifacts**.

## Testes

```bash
flutter test
```

Cobrem a lógica que importa: parser de links (todas as formas de URL do
YouTube), fila de downloads (concorrência, pausa, retomada, restauração após
morte do app), sanitização de nomes de arquivo, formatação, serialização,
escolha de motor, tokens de design e comportamento tátil/visual dos controles.

## Limitações conhecidas (v0.1.0)

- **1080p+ exige muxing.** O YouTube serve vídeo e áudio separados acima de
  720p; juntar os dois pede FFmpeg. Esses formatos aparecem marcados e
  desabilitados — o app não promete o que não entrega.
- **Conversão para MP3** depende do mesmo módulo FFmpeg; hoje o áudio é salvo
  no formato original (M4A/WebM).
- **Módulo yt-dlp** está com a ponte pronta (`YtDlpEngine`), mas o binário
  Python não está empacotado no APK. Enquanto isso, `isAvailable()` devolve
  `false` e o motor é ignorado.
- **Download com a tela bloqueada** (foreground service) ainda não está
  implementado no lado nativo.

## Aviso legal

Baixe apenas conteúdo que você tem o direito de salvar. Respeite os termos de
uso das plataformas e os direitos autorais. Este app não é afiliado ao YouTube
nem a qualquer plataforma suportada.
