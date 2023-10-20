# donutz

A Fennel-based environment for algorithmic composition

## Installation and Use

Given Renoise version `X.Y.Z` (like `3.4.2`):

    git clone --recurse-submodules git@github.com:ejconlon/donutz.git
    donutz/symlink.sh X.Y.Z

Then reload your Renoise plugins. Access the REPL hosted in Renoise with

    telnet 127.0.0.1 9876

However, you will probably enjoy the experience more with `socat`:

    socat READLINE,history=$HOME/.telnet_history TCP:127.0.0.1:9876

## Prior work

This project is based on [8fl](https://git.sr.ht/~nasser/8fl).

## License

This project is MIT-licensed. It contains vendored poritions of the Fennel
language source code, which is also [MIT-licensed](
https://github.com/bakpakin/Fennel/blob/main/LICENSE).

