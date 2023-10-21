# donutz

A Fennel-based environment for algorithmic composition

## Prior work

This project is based on [8fl](https://git.sr.ht/~nasser/8fl), using some
of the same interfaces and concepts, but with a different implementation.

## Installation and Use

Given Renoise version `X.Y.Z` (like `3.4.2`):

    git clone --recurse-submodules git@github.com:ejconlon/donutz.git
    donutz/symlink.sh X.Y.Z

Then reload your Renoise plugins. Access the REPL hosted in Renoise with

    telnet 127.0.0.1 9876

However, you will probably enjoy the experience more with `socat`:

    socat READLINE,history=$HOME/.telnet_history TCP:127.0.0.1:9876

## Neovim setup

First add a custom filetype

```
vim.filetype.add {
  extension = {
    dz = function(path, bufnr)
      return 'donutz',
        function(bufnr)
          vim.api.nvim_buf_set_option(0, 'commentstring', ';; %s')
        end
    end,
  },
}
```

Now configure treesitter: Add `fennel` to your installed
languages and alias the new filetype:

```
vim.treesitter.language.register('fennel', 'donutz')
```

To send commands to the `donutz` REPL, configure `iron.nvim`
something like this:

```
require('iron.core').setup {
  config = {
    repl_definition = {
      donutz = {
        command = 'socat READLINE,history=$HOME/.telnet_history TCP:127.0.0.1:9876'
      },
    },
  },
  ignore_blank_lines = true,
}
```

## License

This project is MIT-licensed. It contains vendored poritions of the Fennel
language source code, which is also [MIT-licensed](
https://github.com/bakpakin/Fennel/blob/main/LICENSE).

