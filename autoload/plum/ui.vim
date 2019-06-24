function! plum#ui#Run(spec)
  let spec = a:spec

  "save state
  let store = get(b:, 'plum_ui_store', s:EmptyStore())
  let bufferActions = get(b:, plum_actions, [])

  " get commands with holes filled with store values
  let commands = []
  for c in spec.commands
    let value = c.value
    let name = c.name
    for kv in store.holes
      let value = plum#ui#StringReplace(value, '{{'.kv[0].'}}', kv[1])
      let nome = plum#ui#StringReplace(name, '{{'.kv[0].'}}', kv[1])
    endfor
    let commands = commands + [[name, value]]
  endfor

  let fullName = spec.name
  let back = spec.back
  while type(back) !=# type(v:null)
    let fullName = back.name . '>>' fullName
    let back = back.back
  endwhile

  " get display formatted commands
  let displayedCommands = []
  for kv in commands
    let displayName = fullName . '>> ' kv[0]
    let displayedCommands = displayedCommands + [[displayName, kv[1]]
  endfor

  " get screen content
  let contentPane = system(spec.update.value)
  let commandPaneLines = []
  for kv in displayedCommands
    let commandPaneLines = commandPaneLines + [kv[0]]
  endfor

  " draw panes: requires an existing window
  " clear window
  enew
  " make buffer scratch
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  " append lines
  call append(0, contentPane)
  call append(line('$'), commandPaneLines)
  " make sure users cannot modify the content of the window
  " for simplicity
  setlocal nomodifiable

  " register action
  let b:plum_actions = [???] + get(b:, 'plum_actions', [])

  " update the store
  let b:plum_ui_store = ???
endfunction

function! plum#ui#IsCommand(context)
  let context = a:context
  let store = b:plum_ui_store
  let curline = getline(line('.'))
  
  " match ui commands
  let uiCommands = plum#ui#UiCommands(store.spec)
  for uicmd in uiCommands
    if uicmd.name ==# curline
      let spec.match = uicmd
      return 1
    endif
  endfor
  
  " match runtime commands
  let runtimeCommands = plum#ui#RuntimeCommands(store.spec, store.holes)
  for runcmd in runtimeCommands
    if runcmd.name ==# curline
      let spec.match = runcmd
      return 1
    endif
  endfor

  " match Children

  " match using extractors
  for ext in spec.extractors


endfunction

function! plum#ui#UiCommands(spec)
  let spec = a:spec
  let fullName = plum#ui#GetFullName(spec)
  let uiCommands = []
  for value in ["update", "back", "top"]
    let name = fullName . '>>ui>> ' . value
    let uiCommands = uiCommands + 
          \ [{ 'type': 'UiCommand', 'name': name, 'value': value }]
  endfor
  return uiCommands
endfunction

function! plum#ui#Example()
  return { 'name': 'plum-git'
        \, 'update': plum#ui#Cmd('git status')
        \, 'extractors': [
        \    { 'staged': 'stagedfn' },
        \    { 'untracked' : 'untrackedfn' } ]
        \, '[patch]': {
        \    'extractors': [
        \      { 'staged': 'patchstagedfn' },
        \      { 'unstaged': 'patchunstagedfn' } ],
        \    'git patch {{unstaged}}': plum#ui#Cmd() }
        \, 'git add -A' : plum#ui#Cmd()
        \, 'git add {{untracked}}' : plum#ui#Cmd()
        \, 'git reset HEAD -- {{staged}}' : plum#ui#Cmd() }
endfunction

function! plum#ui#Cmd(...)
  if a:0 ==# 0
    return s:EmptyCommand()
  elseif type(a:1) ==# type("")
    return s:Command(a:1)
  endif
endfunction

function! plum#ui#Keywords()
  return ['name', 'back', 'top', 'update', 'extractors', 'commands', 'children']
endfunction

function! plum#ui#Reify(name, spec, back)
  let spec = a:spec
  if type(a:back) == type(v:null)
    let spec = deepcopy(a:spec)
  endif
  let spec.name = a:name
  let spec.back = a:back

  " set spec.back
  if type(spec.back) ==# type(v:null)
    let spec.top = spec
  else
    let spec.top = spec.back.top
  endif

  " get all possible holes
  let possible_holes = []
  for obj in spec.extractors
    for kv in items(obj)
      let possible_holes = possible_holes + [kv[0]]
    endfor
  endfor

  " set spec.update
  if has_key(spec, 'update')
    if spec.update.type ==# 'EmptyCommand'
      " if command is EmptyCommand then we create an non-epmty command
      " with an value that generates no output. This way it will be named 
      " update, but it will not generate any output on update.
      let spec.update =
            \ s:ReifiedCommand('update', s:Command('printf ""'), possible_holes)
    else
      let spec.update =
            \ s:ReifiedCommand('update', spec.update, possible_holes)
    endif
  else
    let spec.update = spec.back.update
  endif

  " categorize non-keywords
  let commandsKv = []
  let childrenKv = []
  let keywords = plum#ui#Keywords()
  for kv in items(spec)
    if index(keywords, kv[0]) >= 0
      continue
    endif
    if has_key(kv[1], 'type') &&
          \ (kv[1].type ==# 'Command' || kv[1].type ==# 'EmptyCommand')
      let commandsKv = commandsKv + [kv]
    else
      let childrenKv = childrenKv + [kv]
    endif
  endfor

  " delete non-keywords
  for kv in items(spec)
    if index(keywords, kv[0]) < 0
      call remove(spec, kv[0])
    endif
  endfor

  " reify commands
  let spec.commands = []
  for kv in commandsKv
    let spec.commands = spec.commands + 
          \ [s:ReifiedCommand(kv[0], kv[1], possible_holes)]
  endfor

  " reify extractors
  let extractors = []
  for obj in spec.extractors
    for kv in items(obj)
      let ext = { 'name': kv[0], 'apply': kv[1], 'commands' : [] }
      for c in spec.commands
        if index(c.holes, ext.name) >= 0
          let ext.commands = ext.commands + [c]
        endif
      endfor
      let extractors = extractors + [ext]
    endfor
  endfor
  let spec.extractors = extractors

  " reify children
  let children = []
  for kv in childrenKv
    let name = kv[0]
    let childSpec = kv[1]
    let children = children +
          \ [plum#ui#Reify(name, childSpec, spec)]
  endfor
  let spec.children = children 

  return spec
endfunction

function! s:EmptyCommand()
  return { 'type' : 'EmptyCommand' }
endfunction

function! s:Command(value)
  return { 'type' : 'Command', 'value': a:value }
endfunction

function! s:ReifiedCommand(name, user_command, possible_holes)
  let name = a:name
  let user_command = a:user_command
  let possible_holes = a:possible_holes
  let reified_command = {
        \ 'type': 'ReifiedCommand',
        \ 'name': name,
        \ 'value': name,
        \ 'holes': [] }
  if has_key(user_command, 'value')
    let reified_command.value = user_command.value
  endif
  for hole in possible_holes
    if plum#ui#StringContains(reified_command.value, '{{'.hole.'}}')
      let reified_command.holes = reified_command.holes + [hole]
    endif
  endfor
  return reified_command
endfunction

function! plum#ui#StringContains(haystack, needle)
  let haystack = a:haystack
  let needle = a:needle
  let needleSize = len(needle)
  let i = 0
  while i < len(haystack)
    if strpart(haystack, i, needleSize) ==# needle
      return v:true
    endif
    let i = i + 1
  endwhile
  return v:false
endfunction

function! s:EmptyStore()
  return { 'holes' : [] }
endfunction
