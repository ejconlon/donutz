default:
  just --list

repl:
  cd plugin && rlwrap lua main.lua

compile-fennel-mod name:
  cd submodules/fennel/src && fennel --compile fennel/{{name}}.fnl > ../../../plugin/fennel/{{name}}.lua

compile-fennel:
  rm -rf plugin/fennel
  mkdir plugin/fennel
  just compile-fennel-mod repl
  just compile-fennel-mod compiler
  just compile-fennel-mod friend
  just compile-fennel-mod parser
  just compile-fennel-mod specials
  just compile-fennel-mod utils
  just compile-fennel-mod view

