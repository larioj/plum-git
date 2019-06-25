function! plum#ui#Run(userSpec)
  let userSpec = a:userSpec
  let spec = plum#ui#spec#Reify(userSpec.name, userSpec, v:null)
  call plum#ui#Render(spec)
endfunction

function! plum#ui#Render(spec)
  let spec = a:spec
  let store = get(b:, 'plum_ui_store', s:EmptyStore(spec))
  let spec = plum#ui#spec#UpdateRuntime(spec, store.holes)

  " get screen content
  let commandPaneLines = []
  for obj in spec.uiCommands + spec.runtime.commands + spec.children
    let commandPaneLines = commandPaneLines + [obj.name]
  endfor
  let commandPaneLines = commandPaneLines

  let termCmd = spec.update.value
  for l in commandPaneLines
    let termCmd = termCmd . " ;  echo '" . l . "'"
  endfor
  let bufNum = term_start(['/bin/sh', '-ic', termCmd], { 'curwin' : 1 })
  call term_wait(bufNum)

  let b:plum_actions = [plum#ui#InternalAction()] + get(b:, 'plum_actions', [])
  let b:plum_ui_store = store
endfunction

function! plum#ui#InternalAction()
  return plum#CreateAction(
        \ 'plum#ui#InternalAction',
        \ function('plum#ui#IsCommand'),
        \ function('plum#ui#ApplyCommand'))
endfunction

function! plum#ui#IsCommand(context)
  let context = a:context
  let store = b:plum_ui_store
  let spec = plum#ui#spec#UpdateRuntime(store.spec, store.holes)
  let curline = getline(line('.'))

  for obj in spec.uiCommands + spec.runtime.commands + spec.children
    if obj.name ==# curline
      let context.match = obj
      return 1
    endif
  endfor

  " match using extractors
  let i = 0
  while i < len(spec.extractors)
    let ext = spec.extractors[i]
    if ext.IsMatch(context)
      let value = context.match
      let store.holes = [[ext.name, value]] + store.holes
      let spec = plum#ui#spec#UpdateRuntime(store.spec, store.holes)
      let context.match = spec.runtime.extractors[i]
      return 1
    endif
    let i = i + 1
  endwhile

  return 0
endfunction

function! plum#ui#ApplyCommand(context)
  let context = a:context
  let store = b:plum_ui_store
  let spec = store.spec
  let match = context.match

  let nextspec = spec
  let emptyStore = v:false

  if match.type ==# 'UiCommand'
    if match.value ==# 'top'
      let nextspec = spec.top
      let emptyStore = v:true
    elseif match.value ==# 'back' && type(spec.back) !=# type(v:null)
      let nextspec = spec.back
      let emptyStore = v:true
    elseif match.value ==# 'back'
      let emptyStore = v:true
    else " must be update
      " don't reset holes
    endif
  elseif match.type ==# 'Command'
    if len(match.holes) ==# 0
      silent execute '! ' . match.value
      redraw!
      let emptyStore = v:true
    else
      " don't reset holes
    endif
  elseif match.type ==# 'Extractor'
    if len(match.commands) ==# 0
      " don't reset holes
    elseif len(match.commands) ==# 1 && len(match.commands[0].holes) ==# 0
      silent execute '! ' . match.commands[0].value
      redraw!
      let emptyStore = v:true
    else
      " don't reset store
    endif
  else " Must be a childSpec
    let nextspec = match
    let emptyStore = v:true
  endif

  if emptyStore
    let b:plum_ui_store = s:EmptyStore(nextspec)
  endif
  call plum#ui#Render(nextspec)
endfunction

function! s:EmptyStore(spec)
  return { 'spec': a:spec, 'holes' : [] }
endfunction
