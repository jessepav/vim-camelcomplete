# vim-camelcomplete

Vim Lua plugin to complete `CamelCase`, `snake_case`, and `dash-words` identifier
abbreviations.

I'd originally written this plugin in `vim9script`, but it turned out to be too slow for
processing large buffers without delay. Using LuaJIT, the current version is very fast;
though I don't know what performance would be like using the PUC Lua interpreter.

The `vim9script` branch is still available:

  https://github.com/jessepav/vim-camelcomplete/tree/master


## Introduction

This plugin provides a lightweight insert-mode completion function that allows you to
expand `CamelCase`, `snake_case`, and `dash-words` abbreviations into their full
identifiers. It is purely textual, and doesn't require setting up language servers or
defining a project structure; rather, it operates like `<C-P>/<C-N>`, but on identifier
abbreviations rather than prefixes.

For instance,

| Identifier       | Abbreviation |
| :--------------- | :----------- |
| `setForwardMark` | `sFM`        |
| `open_last_file` | `olf`        |
| `channel34Types` | `c3T`        |
| `margin-top`     | `mt`         |

As an example (with \* representing the cursor position),

```
  obj.sFM* --> (invoke camelcomplete) --> obj.setForwardMark*
```

## Installation

Use your favorite plugin manager.

For instace, with [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'jessepav/vim-camelcomplete'
```

Also (ay...) the plugin uses a few Lua modules for regexp ergonomics and JSON encoding.
The easiest way to get these modules up and running is by using LuaRocks.

On a a Debian/Ubuntu system:

```sh
sudo apt install luarocks
sudo luarocks install lrexlib-pcre2 dkjson
```

## Usage

Quick Start:

In your `.vimrc`, add these lines

```
  set completefunc=CamelCompleteFunc
  imap <C-X><C-A>    <Plug>CamelCompleteRefreshAndComplete
```

This will set `'completefunc'` to a completion function in `camelcomplete.vim`, and set up
`<C‑X><C‑A>` to scan all listed buffers and complete the abbreviation before the cursor.
You can, of course, use any `{lhs}` mapping you'd like. I prefer `<M‑/>`, since it's only
one keystroke, but some terminals won't register `<M‑/>` properly.

## More Information

See [`doc/camelcomplete.txt`](https://github.com/jessepav/vim-camelcomplete/blob/lua/doc/camelcomplete.txt)
for more details.
