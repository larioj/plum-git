# Plum UI
## Files
-   autoload/plum/ui.vim
-   autoload/plum/git.vim
$ rm -d autoload/plum/spec

## Spec
```yaml
name: plum-git
update: cmd('git status')
extractors:
- staged    : function(() -> (int, {}))
- unstaged  : function(() -> (int, {}))
- untracked : function(() -> (int, {}))
[patch]:
  extractors:
  - unstaged  : function(() -> (int, {}))
  - untracked : function(() -> (int, {}))
'git add -A': cmd()
'git reset HEAD': cmd()
'git add {{unstaged}}': cmd()
'git add {{untracked}}': cmd()
'git reset HEAD -- {{staged}}': cmd()
```

## Reified Spec
```yaml
name: plum-git
back: null
top: <this>
update:
  type: ReifiedCommand
  name: update
  value: git status
  holes: []
extractors:
- name: staged
  apply: function(???)
  commands:
  - type: ReifiedCommand
    name: git reset HEAD -- {{staged}}
    value: git reset HEAD -- {{staged}}
    holes: [staged]
- name: unstaged
  apply: function(???)
  commands:
  - type: ReifiedCommand
    name: git add {{unstaged}}
    value: git add {{unstaged}}
    holes: [unstaged]
- name: untracked
  apply: function(???)
  commands:
  - type: ReifiedCommand
    name: git add {{untracked}}
    value: git add {{untracked}}
    holes: [untracked]
commands:
- type: ReifiedCommand
  name: git add -A
  value: git add -A
  holes: []
- type: ReifiedCommand
  name: git reset HEAD
  value: git reset HEAD
  holes: []
- type: ReifiedCommand
  name: git add {{unstaged}}
  value: git add {{unstaged}}
  holes: [unstaged]
- type: ReifiedCommand
  name: git add {{untracked}}
  value: git add {{untracked}}
  holes: [untracked]
- type: ReifiedCommand
  name: git reset HEAD -- {{staged}}
  value: git reset HEAD -- {{staged}}
  holes: [staged]
children:
- name: [patch]
  top: <..>
  back: <..>
  update:
    type: ReifiedCommand
    name: update
    value: git status
    holes: []
.... 
```
