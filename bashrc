# Container bashrc for claude-sandbox

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Terminal settings - only in interactive shells with a tty
if [[ $- == *i* ]] && [ -t 0 ]; then
    stty -echoctl 2>/dev/null
fi

# Vi mode with custom keybindings
#set -o vi

# ^p check for partial match in history
bind -m vi-insert "\C-p":dynamic-complete-history
# ^n cycle through the list of partial matches
bind -m vi-insert "\C-n":menu-complete
# ^l clear screen
bind -m vi-insert "\C-l":clear-screen

# Aliases
alias vi='vim'

# Git prompt
if [ -f /usr/share/git-core/contrib/completion/git-prompt.sh ]; then
    . /usr/share/git-core/contrib/completion/git-prompt.sh
    GIT_PS1_SHOWDIRTYSTATE=1
    GIT_PS1_SHOWUNTRACKEDFILES=1
    GIT_PS1_SHOWUPSTREAM="auto"
    export PS1='\[\033[01;35m\][sandbox]\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\[\033[33m\]$(__git_ps1 " (%s)")\[\033[00m\]\$ '
else
    export PS1='[claude-sandbox] \w $ '
fi

# PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:/usr/local/bin:$PATH"

# History configuration
export HISTSIZE=100000
export HISTFILESIZE=1000000
export HISTCONTROL="erasedups"
export HISTIGNORE='&:[ ]*:exit:history:clear'

# Editor configuration
export VISUAL=vim
export EDITOR=vim

# npm global prefix (avoids needing sudo for global installs)
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

# Source user's custom environment if present
# Create ~/.claude-sandbox.env to add custom variables (e.g., Vertex AI config)
if [ -f "$HOME/.claude-sandbox.env" ]; then
    . "$HOME/.claude-sandbox.env"
fi
