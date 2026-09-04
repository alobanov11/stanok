<div align="center">

# Stanok

**A native macOS terminal built around branches, diffs and coding agents.**

Ghostty-fast rendering, a single workspace of terminal columns, and a git
inspector that turns any branch or commit into a review — without leaving the app.

</div>

---

## Why

A terminal is where the work happens, but everything around it lives elsewhere:
the diff is in the editor, the branch list is in a git client, the agent session
is in a third window. Stanok keeps them in one place.

- **One workspace, not tabs.** Terminals share a single area and lay out as
  columns — or rows on a vertical display. Panels that no longer fit move into a
  live thumbnail strip and come back when the window grows.
- **Git as a first-class panel.** Branches, working-tree changes and commits in
  one inspector. Double-click a branch or a commit to open its review.
- **Reviews with real folding.** Diffs render with ribbons in the gutter: bright
  ribbons expand hidden context, dim ones mark additions, red ones removals.
- **Agents are just commands.** Claude Code, Codex and friends are tracked as
  ordinary processes — status, duration, exit code — with no provider knowledge
  in the core.
- **Anything you pin.** Add folders and repositories from other projects and
  browse their files and branches side by side.

## Build

Requirements: macOS 26+, Apple Silicon, Xcode with `MacOSX26.2.sdk`
(Zig 0.15.2 does not link SDK 26.4+, [ziglang/zig#31658](https://github.com/ziglang/zig/issues/31658)),
Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`) and
[mise](https://mise.jdx.dev) — the Zig toolchain is pinned in `mise.toml`.

```sh
git submodule update --init --recursive
./scripts/build-ghostty.sh   # GhosttyKit.xcframework -> .build/ghostty/
make install                 # release build -> /Applications/Stanok.app
```

Or open `Stanok.xcodeproj` and build the `Stanok` scheme.

## Under the hood

SwiftUI with `@Observable`, Swift 6 strict concurrency, and three targets whose
boundaries the compiler enforces: `StanokKit` never links `GhosttyKit`, so the
terminal engine stays swappable. See [ARCHITECTURE.md](ARCHITECTURE.md).

Rendering is [libghostty](https://github.com/ghostty-org/ghostty), pinned as a
submodule and used unpatched.

## License

[MIT](LICENSE) © Anton Lobanov
