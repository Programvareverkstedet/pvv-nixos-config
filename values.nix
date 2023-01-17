# Feel free to change the structure of this file

rec {
  gateway = "129.241.210.129";


  jokum = {
    ipv4 = "129.241.210.169";
    ipv6 = "2001:700:300:1900::169";
  };
  matrix = {
    ipv4 = jokum.ipv4;
    ipv6 = jokum.ipv6;
  };
  # Also on jokum
  turn = {
    ipv4 = "129.241.210.213";
    ipv6 = "2001:700:300:1900::213";
  };

  ildkule = {
    ipv4 = "129.241.210.187";
    ipv6 = "2001:700:300:1900::187";
  };
}
