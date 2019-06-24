# Plum UI
## Files
-   autoload/plum/ui.vim
-   autoload/plum/git.vim
-   autoload/plum/ui/spec.vim

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
  type: UpdateCommand
  name: 'plum-git#update>> update'
  value: git status
  holes: []
uiCommands:
- type: UiCommand
  name: 'plum-git#ui>> update'
  value: update
  holes: []
- type: UiCommand
  name: 'plum-git#ui>> back'
  value: back
  holes: []
- type: UiCommand
  name: 'plum-git#ui>> top'
  value: top
  holes: []
commands:
- type: Command
  name: 'plum-git>> git add -A'
  value: git add -A
  holes: []
- type: Command
  name: 'plum-git>> git reset HEAD'
  value: git reset HEAD
  holes: []
- type: Command
  name: 'plum-git>> git add {{unstaged}}'
  value: git add {{unstaged}}
  holes: [unstaged]
- type: Command
  name: 'plum-git>> git add {{untracked}}'
  value: git add {{untracked}}
  holes: [untracked]
- type: Command
  name: 'plum-git>> git reset HEAD -- {{staged}}'
  value: git reset HEAD -- {{staged}}
  holes: [staged]
children:
- name: plum-git#[patch]
  top: <..>
  back: <..>
  update:
    type: ReifiedCommand
    name: update
    value: git status
    holes: []
  .... 
extractors:
- name: staged
  IsMatch: function(???)
  commands:
  - type: Command
    name: git reset HEAD -- {{staged}}
    value: git reset HEAD -- {{staged}}
    holes: [staged]
- name: unstaged
  IsMatch: function(???)
  commands:
  - type: ReifiedCommand
    name: git add {{unstaged}}
    value: git add {{unstaged}}
    holes: [unstaged]
- name: untracked
  IsMatch: function(???)
  commands:
  - type: ReifiedCommand
    name: git add {{untracked}}
    value: git add {{untracked}}
    holes: [untracked]

```
