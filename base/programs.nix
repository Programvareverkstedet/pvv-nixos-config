{ pkgs, lib, ... }:
{
  # We don't need fonts on headless machines
  fonts.fontconfig.enable = lib.mkDefault false;

  # Extra packags for better terminal emulator compatibility in SSH sessions
  environment.enableAllTerminfo = true;

  environment.systemPackages = with pkgs; [
    # Debug dns outside resolvectl
    dig

    # Debug and find files
    file

    # Process json data
    jq

    # Check computer specs
    lshw

    # Check who is keeping open files
    lsof

    # Scan for open ports with netstat
    net-tools

    # Grep for files quickly
    ripgrep

    # Copy files over the network
    rsync

    # Access various state, often in /var/lib
    sqlite-interactive

    # Debug software which won't debug itself
    strace

    # Download files from the internet
    wget
  ];

  # Clone/push nix config and friends
  programs.git.enable = true;

  # Gitea gpg, oysteikt sops, etc.
  programs.gnupg.agent.enable = true;

  # Monitor the wellbeing of the machines
  programs.htop.enable = true;

  # Keep sessions running during work over SSH
  programs.tmux.enable = true;

  # Same reasoning as tmux
  programs.screen.enable = true;

  # Edit files on the system without resorting to joe(1)
  programs.nano.enable = true;
  # Same reasoning as nano
  programs.vim.enable = true;
  # Same reasoning as vim
  programs.neovim.enable = true;

  # Some people like this shell for some reason
  programs.zsh.enable = true;
}
