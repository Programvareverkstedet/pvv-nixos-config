{ config, pkgs, ... }:

{
  users.users.danio = {
    isNormalUser = true;
    extraGroups = [ "drift" "nix-builder-users" "wheel" ];
    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCp8iMOx3eTiG5AmDh2KjKcigf7xdRKn9M7iZQ4RqP0np0UN2NUbu+VAMJmkWFyi3JpxmLuhszU0F1xY+3qM3ARduy1cs89B/bBE85xlOeYhcYVmpcgPR5xduS+TuHTBzFAgp+IU7/lgxdjcJ3PH4K0ruGRcX1xrytmk/vdY8IeSk3GVWDRrRbH6brO4cCCFjX0zJ7G6hBQueTPQoOy3jrUvgpRkzZY4ZCuljXtxbuX5X/2qWAkp8ca0iTQ5FzNA5JUyj+DWeEzjIEz6GrckOdV2LjWpT9+CtOqoPZOUudE1J9mJk4snNlMQjE06It7Kr50bpwoPqnxjo7ZjlHFLezl"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDpGSDczzDOhTETCj+uB5e3/9QbOCaVW1knM+n1ey0n6LXH7uiPPmzuZiqfzmfbB1z4bjM2zpn3D6Et6zRCrBUjhTZqf/5GoNlvhVA6QYmBmBp98b8oY7juj5cmu55voxD0S5rC1mQMnWAAf8e8OPbkhs9Lt0XlOYdotLNIZQubzWqE2DK45g/h17ELJs+jkNXoalFjLvLXWzE/C+3pYoeNJVGHfVMTIwt7o64E6JXhxuYTYdSIuzd+BjntkSCXzcAzBFMRwkdlFVoBtLUMMcMQl39kcXv7lAQ8pv+8b1j1N9WuQVf1qEAcZguaimI1ifbXP5d841pZPApCj5KXectIEldfTrcwg8rZpd2UfYS/3XCcOuidBGprY7XsU/jz8wHbH68UjUrsLyaOMnG2ChYztnf63vm3gRs3Fc6FqTycpgYOPDeZBVTcMyPGgtiZvhnTeY20xFS5lK6M+dmgaDqH24kPLiwYSpUF2NK+Rg/2bZxvt/GaSr4U6fJGi3FCJOM= root@DanixLaptop"
    ];
  };
}
