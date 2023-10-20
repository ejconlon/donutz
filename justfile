default:
  just --list

repl:
  cd plugin && rlwrap lua main.lua

# rlwrap makes telnet escapes difficult
# otherwise telnet 127.0.0.1 9876 works ok but lacks readline/EOF handling
remote:
  socat READLINE,history=$HOME/.telnet_history TCP:127.0.0.1:9876

compile-fennel-mod name:
  cd submodules/fennel/src && fennel --compile fennel/{{name}}.fnl > ../../../plugin/fennel/{{name}}.lua

compile-fennel:
  rm -rf plugin/fennel
  mkdir plugin/fennel
  cp submodules/fennel/LICENSE plugin/fennel
  just compile-fennel-mod repl
  just compile-fennel-mod compiler
  just compile-fennel-mod friend
  just compile-fennel-mod parser
  just compile-fennel-mod specials
  just compile-fennel-mod utils
  just compile-fennel-mod view

compile-vendor-mod name:
  cd vendor && fennel --compile {{name}}.fnl > ../plugin/vendor/{{name}}.lua

compile-vendor:
  rm -rf plugin/vendor
  mkdir plugin/vendor
  just compile-vendor-mod splice

compile-deps: compile-fennel compile-vendor
