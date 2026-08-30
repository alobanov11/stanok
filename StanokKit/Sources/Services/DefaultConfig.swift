import Foundation

public enum DefaultConfig {

    private static var ghostty: String {
        """
        font-family = Fira Code
        font-size = 15
        adjust-cell-height = 40%
        adjust-box-thickness = -60%

        cursor-style = bar
        cursor-style-blink = true
        cursor-opacity = 0.7

        window-padding-x = 16
        window-padding-y = 14,14

        background-opacity = 0
        scrollback-limit = 2000000

        input = " source \(AppPaths.shellInit.path(percentEncoded: false))\\n"
        """
    }

    private static var shellInit: String {
        """
        autoload -Uz add-zsh-hook add-zle-hook-widget

        typeset -g _stanok_started=0
        typeset -g STANOK_PLACEHOLDER=${STANOK_PLACEHOLDER:-"Введите команду"}

        HISTSIZE=50000
        SAVEHIST=50000
        setopt APPEND_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY
        setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

        PROMPT=''
        RPROMPT=''

        _stanok_gap() {
          if (( ! _stanok_started )); then
            _stanok_started=1
            return
          fi

          print -r -- ""
        }

        _stanok_hint() {
          if [[ -z $BUFFER ]]; then
            POSTDISPLAY=$STANOK_PLACEHOLDER
            region_highlight=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=8")
          else
            POSTDISPLAY=""
            region_highlight=()
          fi
        }

        add-zsh-hook precmd _stanok_gap

        if [[ -o interactive ]]; then
          zle -N _stanok_hint
          add-zle-hook-widget line-init _stanok_hint
          add-zle-hook-widget line-pre-redraw _stanok_hint
          bindkey '^[^[' kill-buffer
        fi

        clear
        """
    }

    public static func seed() {
        write(ghostty, to: AppPaths.ghosttyConfig)
        write(shellInit, to: AppPaths.shellInit)
    }

    private static func write(_ contents: String, to url: URL) {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: url.path(percentEncoded: false)) else { return }

        do {
            try manager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try (contents + "\n").write(to: url, atomically: true, encoding: .utf8)
            Log.terminal.info("seeded \(url.path(percentEncoded: false))")
        } catch {
            Log.terminal
                .error("cannot seed \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
