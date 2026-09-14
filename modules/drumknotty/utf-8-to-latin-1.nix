{ pkgs }:
pkgs.writers.writePython3Bin "utf-8-to-latin-1" { libraries = [ ]; } ''
  """u2l: run PROGRAM under a pty, converting its UTF-8 output to ISO-8859-1
  for an 8-bit terminal, and converting keystrokes from ISO-8859-1 back to
  UTF-8 before sending them to the program. The reverse of luit.
  Usage: u2l PROGRAM [ARGS...]"""
  import codecs
  import os
  import pty
  import sys

  _decoder = codecs.getincrementaldecoder('utf-8')(errors='replace')


  def out_read(fd):
      data = os.read(fd, 4096)
      if not data:
          return data
      text = _decoder.decode(data)
      return text.encode('iso-8859-1', errors='replace')


  def in_read(fd):
      data = os.read(fd, 4096)
      if not data:
          return data
      return data.decode('iso-8859-1').encode('utf-8')


  def main():
      if len(sys.argv) < 2:
          print(f"usage: {sys.argv[0]} PROGRAM [ARGS...]", file=sys.stderr)
          sys.exit(1)
      pty.spawn(sys.argv[1:], out_read, in_read)


  if __name__ == '__main__':
      main()
''
