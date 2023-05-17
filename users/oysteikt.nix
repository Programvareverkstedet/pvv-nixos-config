{ pkgs, ... }:
{
  users.users.oysteikt = {
    isNormalUser = true;
    description = "basement dweller";
    extraGroups = [
      "wheel"
      "drift"
    ];

    packages = with pkgs; [
      bottom
      exa
      neovim
      diskonaut
      ripgrep
      tmux
    ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC0aYHsiqfLCA0prSmEi6hZeQPCGxZYR7gp+3U99POUWJyycSVqXMhgVZHT8VEYGf+EZ/y5nL1bvna7ChBwQBzInB2mRW+TCLL3h1w9t/27vTHe3wV+fowTooD/paOErmWFO4yDBEJ3cYFMXowAd3GfvsBSFGPSsvSxghSzWj+kfhIFkXD02LZxn/hBQyCT6irp3Hwx1cBu8ic/l2ln64SLARuEmj4ITaafNC5wD2Gr5Jf3q+T9QtJeFPXSpJD7MtVMJ1VpgpfGBvlEYKggiQjxgu2BXHv1w3KIfyltTwhrcqHvttaJSuR5TreAgQ5+dZHmMr6XX8rFG+HEa8gND6NjGjHrJBxp53qgPtLAmBddvf8xQMYiq6+XST16nlRaAsjU3yr3VqCt7XhJiS2IV8JiIV3dok8nxzDX9sjdZeGchdnAnU6lcxDgnBvAcJRaWHwMCG8Ty9sJ4otgjr5A1GxRBndJIIuKzjpdtsrCAHg/K2zqFoKPJxN/K9zDWKNy0aEy2Akl3LgHF2QIuG5pUOmbyvbF8AoTudaz6Zu6JpVwOb9T9avFJBH4RHQ3mK0faBkrEmnkAg6JnDDMIt0XLALl88rI4kbdkVvJ2kaodvq799TCCw1PwMidgWX63LemWVBx+CL9ebXrsOkOthhMhkeaFXY9Am3Ee7rfD1tq3PGU1w== h7x4"
    ];
  };
}
