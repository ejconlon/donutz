default:
  just --list

repl:
  cd plugin && rlwrap lua main.lua

