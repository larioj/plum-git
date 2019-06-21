function! plum#git#MagicStatus()
  return plum#CreateAction(
        \ 'plum#git#MagicStatus',
        \ function('plum#git#IsStatus'),
        \ function('plum#git#InitPane')
        \ )
endfunction

function! plum#git#IsStatus(context)
  let context = a:context
  if context.mode != 'n'
    return 0
  endif
  let curline = trim(getline(line('.')))
  if curline ==# '$ git status'
    let context.match = 'git status'
    return 1
  endif
  return 0
endfunction

function! s:extraCommands()
  return ['plum-git: add all', 'plum-git: unstage all' ]
endfunction
  
function! plum#git#InitPane(context)
  new
  s:DrawPane(context)
endfunction

function! s:DrawPane(context)
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  execute '$read ! git status' 
  let extraText = s:extraCommands()
  append(line('$'), extraText)
  set nomodifiable
  let b:plum_actions = [ plum#git#StagedToggle() ]
endfunction

function! plum#git#StagedToggle()
  return plum#CreateAction(
        \ 'plum#git#StagedToggle'
        \ function('plum#git#IsFile'),
        \ function('plum#git#StagedToggleApply')
        \ )
endfunction

function! plum#git#IsFile(context)
  let context = a:context
  if context.mode !=# 'n'
    return 0
  endif
  let curline = getline(line('.'))
  if index(s:extraCommands(), curline) !=# -1
    let context.match = curline
    return 1
  endif
  if curline =~# 'new file:' || curline =~# 'modified:'
    let context.match = curline
    return 1
  endif
  let path = trim(curline)
  if filereadable(path) || isdirectory(path)
    let context.match = path
    return 1
  endif
  return 0
endfunction

function! plum#git#StagedToggleApply(context)
  let context = a:context
  let newFileText = 'new file:'
  let modifiedText = 'modified:'
  let commands = s:extraCommands()
  let addAll = commands[0]
  let unstageAll = commands[1]
  let cmd = ''
  if context.match ==# addAll
    let cmd = 'git add -A'
  elseif context.match ==# unstageAll
    let cmd = 'git reset HEAD'
  elseif context.match =~#  newFileText
    let path = trim(strpart(trim(context.match), len(newFileText)))
    let cmd = 'git reset HEAD -- ' . path
  elseif context.match =~# modifiedText
    let path = trim(strpart(trim(context.match), len(modifiedText)))
    let cmd = 'git add ' . path
  else
    let cmd = 'git add ' . context.match
  endif
  execute '! ' . cmd
  enew
  s:DrawPane(context)
endfunction
