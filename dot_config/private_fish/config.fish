if status is-interactive
    # Commands to run in interactive sessions can go here
    starship init fish | source
    fish_ssh_agent
end
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim
