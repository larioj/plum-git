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
    return 1
  endif
  return 0
endfunction

function! plum#git#InitPane(context)
  let context = a:context
  new
  call plum#ui#Run(get(g:, 'plum_git_ui_spec', plum#git#UiSpec()))
endfunction

function! plum#git#UiSpec()
  return { 'name': 'plum-git'
        \, 'update': plum#ui#spec#Cmd('git status')
        \, 'extractors': 
        \    [ { 'staged': function('plum#git#MatchStaged') }
        \    , { 'unstaged': function('plum#git#MatchUnstaged') } 
        \    ]
        \, 'git add -A' : plum#ui#spec#Cmd()
        \, 'git reset HEAD': plum#ui#spec#Cmd()
        \, 'git add {{unstaged}}' : plum#ui#spec#Cmd()
        \, 'git reset HEAD -- {{staged}}' : plum#ui#spec#Cmd()
        \, 'git commit': plum#ui#spec#Cmd()
        \, 'git push': plum#ui#spec#Cmd()
        \, 'git diff': plum#ui#spec#Cmd(
        \     "bash -ic 'git diff --color=always | less -r'")
        \, '[patch]':
        \    { 'git add {{unstaged}} --patch': plum#ui#spec#Cmd()
        \    }
        \}
endfunction

function! plum#git#MatchStaged(context)
  let context = a:context
  if plum#git#MatchFileWithType(context) && 
        \ context.match.type ==# 'staged'
    let context.match = context.match.value
    return 1
  endif
  return 0
endfunction

function! plum#git#MatchUnstaged(context)
  let context = a:context
  if plum#git#MatchFileWithType(context) && 
        \ context.match.type ==# 'unstaged'
    let context.match = context.match.value
    return 1
  endif
  return 0
endfunction

function! plum#git#MatchFileWithType(context)
  let context = a:context
  if context.mode !=# 'n'
    return 0
  endif
  let curline = getline(line('.'))
  let trimmedline = trim(curline)
  let type = v:null
  let value = v:null

  let newFileText = 'new file:'
  let modifiedText = 'modified:'

  if s:StartsWith(trimmedline, newFileText)
    let value = trim(s:DropPrefix(trimmedline, newFileText))
  elseif s:StartsWith(trimmedline, modifiedText)
    let value = trim(s:DropPrefix(trimmedline, modifiedText))
  endif

  if value !=# v:null
    let type = 'staged'
    let lnum = line('.') - 1
    while lnum > 0
      let l = getline(lnum)
      if l =~# 'not staged'
        let type = 'unstaged'
        break
      endif
      let lnum = lnum - 1
    endwhile
    let context.match = { 'type': type, 'value': value }
    return 1
  endif

  if filereadable(trimmedline) || isdirectory(trimmedline)
    let context.match = { 'type': 'unstaged', 'value': trimmedline }
    return 1
  endif
  return 0
endfunction

function! s:StartsWith(full, prefix)
  let full = a:full
  let prefix = a:prefix
  if strpart(full, 0, len(prefix)) ==# prefix
    return v:true
  endif
  return v:false
endfunction

function! s:DropPrefix(full, prefix)
  let full = a:full
  let prefix = a:prefix
  if s:StartsWith(full, prefix)
    return strpart(full, len(prefix))
  endif
  return full
endfunction
