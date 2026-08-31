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
        zmodload zsh/complist
        zmodload zsh/stat
        zmodload zsh/datetime
        zmodload zsh/mathfunc

        typeset -g _stanok_started=0
        typeset -g STANOK_PLACEHOLDER=${STANOK_PLACEHOLDER:-"Введите команду"}
        typeset -g STANOK_HIST_HALFLIFE=${STANOK_HIST_HALFLIFE:-604800}
        typeset -g STANOK_MENU_LIMIT=${STANOK_MENU_LIMIT:-30}
        typeset -g STANOK_TITLE_MIN_DURATION=${STANOK_TITLE_MIN_DURATION:-1}

        typeset -gA _stanok_hist_weight
        typeset -g _stanok_hist_offset=0
        typeset -ga _stanok_ranked
        typeset -gA _stanok_bucket
        typeset -g _stanok_suggestion=""
        typeset -g _stanok_title_gen=0
        typeset -g _stanok_title_gen_file="${TMPDIR:-/tmp}/stanok-title-gen-$$"

        HISTSIZE=50000
        SAVEHIST=50000
        setopt APPEND_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY
        setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

        PROMPT=''
        RPROMPT=''

        _stanok_hist_file() {
          print -r -- ${HISTFILE:-$HOME/.zsh_history}
        }

        _stanok_add_weight() {
          local cmd=$1 ts=$2 now=$3
          local age=$(( now - ts ))
          (( age < 0 )) && age=0
          local w=$(( exp(-0.69314718055994530942 * age / STANOK_HIST_HALFLIFE) ))
          _stanok_hist_weight[$cmd]=$(( ${_stanok_hist_weight[$cmd]:-0} + w ))
        }

        _stanok_ingest_chunk() {
          local chunk=$1
          [[ -z $chunk ]] && return

          local -a raw
          raw=("${(@f)chunk}")

          local now=$EPOCHSECONDS
          local buf="" line ts cmd
          for line in $raw; do
            if [[ -n $buf ]]; then
              buf+=$'\\n'"$line"
            else
              buf=$line
            fi

            if [[ $buf == *'\\' ]]; then
              buf=${buf%?}
              continue
            fi

            line=$buf
            buf=""

            if [[ $line == ': '[0-9]*':'*';'* ]]; then
              ts=${line#: }
              ts=${ts%%:*}
              cmd=${line#*;}
            else
              ts=$now
              cmd=$line
            fi

            [[ -z $cmd ]] && continue
            _stanok_add_weight "$cmd" "$ts" "$now"
          done
        }

        _stanok_rebuild_history_cache() {
          local file=$(_stanok_hist_file)
          _stanok_hist_weight=()
          _stanok_hist_offset=0
          [[ -f $file ]] || return

          _stanok_ingest_chunk "$(<$file)"
          _stanok_hist_offset=$(zstat +size $file 2>/dev/null)
          [[ -z $_stanok_hist_offset ]] && _stanok_hist_offset=0
        }

        _stanok_refresh_history_cache() {
          local file=$(_stanok_hist_file)
          [[ -f $file ]] || return

          local size=$(zstat +size $file 2>/dev/null)
          [[ -z $size ]] && return

          if (( size < _stanok_hist_offset )); then
            _stanok_rebuild_history_cache
            return
          fi

          (( size == _stanok_hist_offset )) && return

          local chunk=$(tail -c +$(( _stanok_hist_offset + 1 )) -- $file 2>/dev/null)
          _stanok_ingest_chunk "$chunk"
          _stanok_hist_offset=$size
        }

        _stanok_rebuild_ranked() {
          local -a scored
          local k
          for k in ${(k)_stanok_hist_weight}; do
            scored+=("${_stanok_hist_weight[$k]}"$'\\t'"$k")
          done

          local -a sorted
          sorted=(${(On)scored})

          _stanok_ranked=()
          local entry
          for entry in $sorted; do
            _stanok_ranked+=("${entry#*$'\\t'}")
          done

          _stanok_bucket=()
          local c key
          for c in $_stanok_ranked; do
            key=${c[1]}
            _stanok_bucket[$key]+="$c"$'\\n'
          done
        }

        _stanok_gap() {
          if (( ! _stanok_started )); then
            _stanok_started=1
            _stanok_refresh_history_cache
            _stanok_rebuild_ranked
            return
          fi

          print -r -- ""
          _stanok_refresh_history_cache
          _stanok_rebuild_ranked
        }

        _stanok_hint() {
          if [[ -z $BUFFER ]]; then
            POSTDISPLAY=$STANOK_PLACEHOLDER
            region_highlight=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=8")
            _stanok_suggestion=""
            return
          fi

          if [[ -n $RBUFFER ]]; then
            POSTDISPLAY=""
            region_highlight=()
            _stanok_suggestion=""
            return
          fi

          local key=${BUFFER[1]}
          local -a candidates
          [[ -n ${_stanok_bucket[$key]} ]] && candidates=("${(@f)_stanok_bucket[$key]}")

          local cand match=""
          for cand in $candidates; do
            if [[ $cand == "$BUFFER"?* ]]; then
              match=$cand
              break
            fi
          done

          if [[ -n $match ]]; then
            _stanok_suggestion=$match
            POSTDISPLAY=${match#"$BUFFER"}
            region_highlight=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=8")
          else
            _stanok_suggestion=""
            POSTDISPLAY=""
            region_highlight=()
          fi
        }

        _stanok_accept_or_forward() {
          if [[ -z $RBUFFER && -n $_stanok_suggestion ]]; then
            BUFFER=$_stanok_suggestion
            CURSOR=${#BUFFER}
            POSTDISPLAY=""
            region_highlight=()
            _stanok_suggestion=""
          else
            zle forward-char
          fi
        }

        _stanok_menu_completer() {
          local prefix=${LBUFFER##*$'\\n'}
          local -a matches
          local c n=0
          for c in $_stanok_ranked; do
            if [[ -z $prefix || $c == "$prefix"* ]]; then
              matches+=("$c")
              (( ++n >= STANOK_MENU_LIMIT )) && break
            fi
          done

          (( ${#matches} == 0 )) && return 1
          compadd -U -Q -V stanok-history -o nosort -a matches
          compstate[insert]=menu
          compstate[list]=list
        }

        _stanok_down_dispatch() {
          if [[ $RBUFFER == *$'\\n'* ]]; then
            zle down-line-or-history
          else
            zle _stanok_menu_widget
          fi
        }

        _stanok_title_set() {
          print -n -- $'\\e]2;'"$1"$'\\a'
        }

        _stanok_title_sanitize() {
          local text=${1//$'\\n'/ }
          text=$(print -rn -- "$text" | tr -d '\\000-\\037\\177')
          (( ${#text} > 60 )) && text=${text[1,60]}
          print -r -- "$text"
        }

        _stanok_title_preexec() {
          local cmd=$1
          [[ $cmd == ' '* ]] && return

          local text
          text=$(_stanok_title_sanitize "$cmd")
          [[ -z $text ]] && return

          (( _stanok_title_gen++ ))
          print -r -- $_stanok_title_gen >| $_stanok_title_gen_file 2>/dev/null

          local gen=$_stanok_title_gen
          (
            sleep $STANOK_TITLE_MIN_DURATION
            [[ -f $_stanok_title_gen_file ]] || exit
            current=$(<$_stanok_title_gen_file)
            [[ $current == $gen ]] || exit
            _stanok_title_set "$text"
          ) &!
        }

        _stanok_title_precmd() {
          (( _stanok_title_gen++ ))
          print -r -- $_stanok_title_gen >| $_stanok_title_gen_file 2>/dev/null
          _stanok_title_set ""
        }

        _stanok_title_cleanup() {
          rm -f -- $_stanok_title_gen_file 2>/dev/null
        }

        add-zsh-hook precmd _stanok_gap
        add-zsh-hook preexec _stanok_title_preexec
        add-zsh-hook precmd _stanok_title_precmd
        add-zsh-hook zshexit _stanok_title_cleanup

        if [[ -o interactive ]]; then
          zle -N _stanok_hint
          zle -N _stanok_accept_or_forward
          zle -N _stanok_down_dispatch
          zle -C _stanok_menu_widget complete-word _stanok_menu_completer

          add-zle-hook-widget line-init _stanok_hint
          add-zle-hook-widget line-pre-redraw _stanok_hint

          bindkey '^[^[' kill-buffer
          bindkey '^[[C' _stanok_accept_or_forward
          bindkey '^[OC' _stanok_accept_or_forward
          bindkey '^[[B' _stanok_down_dispatch
          bindkey '^[OB' _stanok_down_dispatch
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
