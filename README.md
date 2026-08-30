# stanok

Нативный macOS-терминал под собственный воркфлоу: ветки вместо worktree,
панель изменений, статусы кодинг-агентов. Терминал рендерит libghostty.

## Требования

- macOS 26+, Apple Silicon
- Xcode с `MacOSX26.2.sdk` (Zig 0.15.2 не линкует SDK 26.4+, ziglang/zig#31658)
- Metal Toolchain: `xcodebuild -downloadComponent MetalToolchain`
- `mise` — тулчейн Zig закреплён в `mise.toml`

## Сборка

```sh
git submodule update --init --recursive
./scripts/build-ghostty.sh   # GhosttyKit.xcframework -> .build/ghostty/
```

Затем открыть `Stanok.xcodeproj` и собрать схему `Stanok`.

## Устройство

- `ThirdParty/ghostty` — подмодуль, закреплён на `6057f8d` (последний коммит
  на релизном Zig 0.15.2; `main` уже требует неизданный 0.16.0).
- Патчей к ghostty нет. Появятся — класть в `patches/ghostty/` и накатывать
  в `build-ghostty.sh`, не коммитя внутрь подмодуля.
- `Stanok/` — синхронизированная папка Xcode: новые файлы подхватываются
  без правки `project.pbxproj`.
