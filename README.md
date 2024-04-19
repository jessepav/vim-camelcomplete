# vim-camelcomplete

Vim 9 plugin to complete `CamelCase`, `snake_case`, and `dash-words` identifier
abbreviations.

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

**Note**: for performance, this plugin is written in `vim9script` using the
`matchbufline()` and `matchstrlist()` functions introduced in Vim `v9.1.0009`, and thus
you'll need a sufficiently new version of Vim to use it.

## Installation

Use your favorite plugin manager.

For instace, with [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'jessepav/vim-camelcomplete'
```

## Usage

Quick Start:

In your `.vimrc`, add these lines

```
CamelCompleteInstall
inoremap <C-X><C-A>    <Cmd>CamelCompleteRefreshBuffers 3<CR><C-X><C-U>
```

This will set `'completefunc'` to a script‑local completion function in
`camelcomplete.vim`, and set up `<C‑X><C‑A>` to scan all listed buffers and complete the
abbreviation before the cursor. You can, of course, use any `{lhs}` mapping you'd like. I
prefer `<M‑/>`, since it's only one keystroke, but some terminals won't register `<M‑/>`
properly.

## More Information

See [`doc/camelcomplete.txt`](https://github.com/jessepav/vim-camelcomplete/blob/master/doc/camelcomplete.txt)
for more details.
