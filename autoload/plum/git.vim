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
  return [
        \ 'plum-git: add all', 
        \ 'plum-git: unstage all', 
        \ 'plum-git: commit',
        \ 'plum-git: push'
        \ ]
endfunction

function! s:DrawPane(context)
  let context = a:context
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  execute '$read ! git status' 
  execute '1,1d'
  let extraText = s:extraCommands()
  call append(line('$'), extraText)
  setlocal nomodifiable
  let b:plum_actions = [ plum#git#StagedToggle() ]
endfunction

function! plum#git#InitPane(context)
  let context = a:context
  new
  call s:DrawPane(context)
endfunction

function! plum#git#StagedToggle()
  return plum#CreateAction(
        \ 'plum#git#StagedToggle',
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
    let context.staged = 1
    let lnum = line('.') - 1
    while lnum > 0
      let l = getline(lnum)
      if l =~# 'not staged'
        let context.staged = 0
        break
      endif
      let lnum = lnum - 1
    endwhile
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
  let savedl = line('.')
  let savedc = col('.')
  let newFileText = 'new file:'
  let modifiedText = 'modified:'
  let commands = s:extraCommands()
  let addAll = commands[0]
  let unstageAll = commands[1]
  let commit = commands[2]
  let push = commands[3]
  let cmd = ''
  if context.match ==# addAll
    let cmd = 'git add -A'
  elseif context.match ==# unstageAll
    let cmd = 'git reset HEAD'
  elseif context.match ==# commit
    let cmd = 'git commit'
  elseif context.match ==# push
    let cmd = 'git push'
  elseif context.match =~#  newFileText
    let path = trim(strpart(trim(context.match), len(newFileText)))
    let cmd = 'git reset HEAD -- ' . path
  elseif context.match =~# modifiedText
    let path = trim(strpart(trim(context.match), len(modifiedText)))
    if context.staged
      let cmd = 'git reset HEAD -- ' . path
    else
      let cmd = 'git add ' . path
    endif
  else
    let cmd = 'git add ' . context.match
  endif
  silent execute '! ' . cmd
  redraw
  enew
  call s:DrawPane(context)
  call cursor(savedl, savedc)
endfunction
