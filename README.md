# Plum Git
Common git flows under `$ git status`

## Files
-   autoload/plum/git.vim
-   autoload/plum/ui.vim
-   autoload/plum/ui/spec.vim

## Test
    $ git status
    $ git status -s

## Install
Install with you favorite plugin manager.

## Required Configuration
```viml
" Add MagicStatus to Zeroth index, unless you know better
let g:plum_actions = [
      \ plum#git#MagicStatus(),
      ....
]
```

