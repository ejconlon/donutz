default:
  just --list

repl:
  cd plugin && rlwrap lua main.lua

# rlwrap makes telnet escapes difficult
# otherwise telnet 127.0.0.1 9876 works ok but lacks readline/EOF handling
remote:
  socat READLINE,history=$HOME/.telnet_history TCP:127.0.0.1:9876

compile-fennel:
  rm -f plugin/{fennel,fennelview}.lua
  cd submodules/fennel && make fennel
  cp submodules/fennel/fennel.lua plugin/fennel.lua
  cp submodules/fennel/bootstrap/view.lua plugin/fennelview.lua

compile-vendor-mod name:
  cd vendor && fennel --compile {{name}}.fnl > ../plugin/vendor/{{name}}.lua

compile-vendor:
  rm -rf plugin/vendor
  mkdir plugin/vendor
  just compile-vendor-mod splice

compile-deps: compile-fennel compile-vendor
