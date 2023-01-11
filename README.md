# vim-camelcomplete

Vim 9 plugin to complete `CamelCase` and `snake_case` identifier abbreviations.

## Introduction

This plugin provides an insert-mode completion function that allows you to expand
`CamelCase` and `snake_case` abbreviations into their full identifiers.  For instance,

| Identifier       | Abbreviation |
| :--------------- | :----------- |
| `setForwardMark` | `sFM`        |
| `open_last_file` | `olf`        |
| `channel34Types` | `c3T`        |

As an example (with \* representing the cursor position),

```
  obj.sFM* --> (invoke camelcomplete) --> obj.setForwardMark*
```

**Note**: for performance, this plugin is written in `vim9script` so you'll need
Vim 9 (or perhaps a late 8.2 would work as well, though I haven't tested it).

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
  imap <C-X><C-A>    <Plug>CamelCompleteRefreshAndComplete
```

This will set `'completefunc'` to a script-local completion function in
`camelcomplete.vim`, and set up `<C-X><C-A>` to scan all listed buffers and complete the
abbreviation before the cursor. You can, of course, use any `{lhs}` mapping you'd like. I
prefer `<M-/>`, since it's only one keystroke, but some terminals won't register `<M-/>`
properly.

## More Information

See [`doc/camelcomplete.txt`](https://github.com/jessepav/vim-camelcomplete/blob/master/doc/camelcomplete.txt)
for more details.
