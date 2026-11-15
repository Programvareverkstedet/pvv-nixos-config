{ pkgs, ... }:
{
  services.pvv-userweb = {
    packages = with pkgs; [
      # Useful packages for homepages
      exiftool
      gnuplot
      ikiwiki-full
      imagemagick
      jhead
      ruby
      sbcl
      sourceHighlight

      # Missing packages from tom
      # blosxom
      # pyblosxom
      # mediawiki (TODO: do people host their own mediawikis in userweb?)
      # nanoblogger

      # Version control
      cvs
      rcs
      git

      # Compression/Archival
      bzip2
      gnutar
      gzip
      lz4
      unzip
      xz
      zip
      zstd

      # Other tools you might expect to find on a normal system
      acl
      coreutils-full
      curl
      diffutils
      file
      findutils
      gawk
      gnugrep
      gnumake
      gnupg
      gnused
      less
      man
      util-linux
      vim
      wget
      which
      xdg-utils
    ];

    php.extensions = { all, ... }: with all; [
      bz2
      curl
      decimal
      gd
      imagick
      mysqli
      mysqlnd
      pgsql
      posix
      protobuf sqlite3
      uuid
      xml
      xsl
      zlib
      zstd

      pdo
      pdo_mysql
      pdo_pgsql
      pdo_sqlite
    ];

    perl.packages = perlPkgs: with perlPkgs; [
      pkgs.exiftool
      pkgs.ikiwiki
      pkgs.irssi
      pkgs.nix.libs.nix-perl-bindings

      CGI
      CGIFast
      ClassAccessor
      DBDPg
      DBDSQLite
      DBDmysql
      DBI
      DateTime
      DigestSHA1
      FCGI
      FileFindRule
      Git
      HTMLTemplate
      IOSocketSSL
      IOString
      IOStringy
      ImageMagick
      JSON
      JSONXS
      LWP
      LWPProtocolHttps
      ListMoreUtils
      MIMELite
      MailTools
      NetDNS
      StringCRC32
      Switch
      TemplateToolkit
      XMLLibXML
      XMLParser
    ];

    python3.packages = pythonPkgs: with pythonPkgs; [
      legacy-cgi

      matplotlib
      requests
    ];
  };
}
