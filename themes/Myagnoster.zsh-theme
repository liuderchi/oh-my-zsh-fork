# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
REVERSE_DISPLAY=true  #  "$(random_boolean)"  http://tldp.org/LDP/abs/html/randomvar.html
set_reverse_display() { if [ "$REVERSE_DISPLAY" = true ]; then REVERSE_DISPLAY=false; else REVERSE_DISPLAY=true; fi }
prompt_segment() {
  # NOTE $1, $2 can be "green" "2" or "230" to support 256 color mode, since iterm support _xterm-256color_
  # TODO use wrapper style to swap arguments
  local bg fg
  if [ "$REVERSE_DISPLAY" = true ]; then
    [[ -n $2 ]] && bg="%K{$2}" || bg="%k"
    [[ -n $1 ]] && fg="%F{$1}" || fg="%f"
    if [[ $CURRENT_BG != 'NONE' && $2 != $CURRENT_BG ]]; then
      echo -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
    else
      echo -n "%{$bg%}%{$fg%} "
    fi
    CURRENT_BG=$2
  else
    [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
    [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
    if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
      echo -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
    else
      echo -n "%{$bg%}%{$fg%} "
    fi
    CURRENT_BG=$1
  fi
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    # prompt_segment black default "%(!.%{%F{yellow}%}.)"    # do not show user name
    prompt_segment black black "%(!.%{%F{yellow}%}.)"    # do not show user name
  fi
}

# Node version
prompt_node_nvm() {
  parse_node_version() {
    node -v | awk -F '.' 'BEGIN { OFS = "." }{print $1, $2}'  # vA.B.C -> vA.B
  }

  nvm_missing_warn() {
    if ! nvm_exist; then   # return value not zero
      echo -n "⚠️"  # macOS emoji
    fi
  }
  nvm_exist() { which nvm 1>/dev/null }
  prompt_set_color() {
    if nvm_exist; then
      prompt_segment cyan black
    else
      prompt_segment yellow black
    fi
  }
  prompt_set_color
  echo -n "⬢ $(parse_node_version)$(nvm_missing_warn)"
}

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0 '         # 
    # PL_BRANCH_CHAR=$'\uf09b'         # DEREK 
    # PL_BRANCH_CHAR=$'\uf126'         # DEREK 

  }
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green black
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR}${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_bzr() {
    (( $+commands[bzr] )) || return
    if (bzr status >/dev/null 2>&1); then
        status_mod=`bzr status | head -n1 | grep "modified" | wc -m`
        status_all=`bzr status | head -n1 | wc -m`
        revision=`bzr log | head -n2 | tail -n1 | sed 's/^revno: //'`
        if [[ $status_mod -gt 0 ]] ; then
            prompt_segment yellow black
            echo -n "bzr@"$revision "✚ "
        else
            if [[ $status_all -gt 0 ]] ; then
                prompt_segment yellow black
                echo -n "bzr@"$revision

            else
                prompt_segment green black
                echo -n "bzr@"$revision
            fi
        fi
    fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green black
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green black
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory
CWD_NUM=0    # control var for cwd
set_cwd_num() { CWD_NUM=${1:-0} }
build_cwd_expansion() {
  count_pwd_size() { echo -n $(print -rD $PWD | awk -F/ '{print NF}') }
  print_ignoring_indicator() { if [ $(count_pwd_size) -gt 1 ] && [ $(count_pwd_size) -gt $CWD_NUM ]; then echo -n "…/"; fi }   # or 💬
  echo -n "$(print_ignoring_indicator)"%"$CWD_NUM"c
  # cwd for zsh http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html
}
prompt_dir() {
  # prompt_segment blue black '%~'
  prompt_segment blue black "$(build_cwd_expansion)"

  # DEREK
  # CURRENT_BG=yello
  # echo -n "$FG[000]$BG[130]%~"   # 256 work but not simple
  # echo -n "%{%F{000}%K{130}%}%~"  # fail
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  echo -n "%(?:%{%F{green}%}➜ :%{%F{red}%}➜ )"   # arrow from rubbyrussell theme

  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙ "
  # NOTE require-reboot
  [[ -f /var/run/reboot-required ]] && symbols+="%{%F{yellow}%}↻"  # U+21BB

  # [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
  [[ -n "$symbols" ]] && prompt_segment black black "$symbols"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  # prompt_context
  prompt_dir
  prompt_git
  prompt_node_nvm
  prompt_bzr
  prompt_hg
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt)'
# NEWLINE=$'\n'
# PROMPT='%{%f%b%k%}$(build_prompt)${NEWLINE}'
# TODO extend %F%f to be $FG[000]
# TODO extend %K%k to be $BG[000]

# Date or Time
prompt_date() {
  # NOTE list available colors $ which colors
  # prompt_segment white black '\uf017 %D{%m/%d %H:%M:%S}'  # fa-calendar, fa-clock-o
  # prompt_segment none blue '\uf017 %D{%H:%M}'  # fa-calendar, fa-clock-o
  # prompt_segment none blue '🕕 %D{%H:%M}'  # NOTE MAC support only one font: source-code-pro
  # prompt_segment none blue '%D{%H:%M}'  # NOTE on macOS 13 emoji causes text display error when hitting `tab` key for completion
  prompt_segment blue black '%D{%H:%M}'  # for reversed prompt_segment
}

prompt_history_num() {
  prompt_segment blue black '%h'  # for reversed prompt_segment
}

set_rps1() {
if [ "$RPS1" = "" ]; then
  RPS1='$(prompt_history_num)$(prompt_date)'
else
  RPS1=''
fi }

RPS1='$(prompt_history_num)$(prompt_date)'
