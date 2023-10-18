default:
  just --list

repl:
  cd plugin && rlwrap lua main.lua

comp:
  cd submodules/fennel/src && fennel --compile fennel/repl.fnl > ../../../plugin/fennel.lua
  # cd submodules/fennel/src && fennel --compile fennel/view.fnl > ../../../plugin/fennelview.lua

