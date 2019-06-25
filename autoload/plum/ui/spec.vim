function! plum#ui#spec#UpdateRuntime(spec, holes)
  let spec = deepcopy(a:spec)
  let holes = a:holes

  " we only fill holes at the top level since at the moment
  " we don't support global holes

  " fill holes in spec.commands and spec.extractors.commands
  let spec.runtime = {}
  let spec.runtime.commands = s:FillHoles(spec, holes)
  let spec.runtime.extractors = []
  for e in spec.extractors
    let ext = deepcopy(e)
    let ext.commands = s:FillHoles(ext, holes)
    let spec.runtime.extractors = spec.runtime.extractors + [ext]
  endfor
  return spec
endfunction

function! plum#ui#spec#Reify(name, spec, back)
  let name = a:name
  let spec = deepcopy(a:spec)
  let back = a:back

  " set misc required fields
  let spec.type = 'Spec'
  let spec.back = back
  if type(spec.back) ==# type(v:null)
    let spec.top = spec
    let spec.name = name
  else
    let spec.top = spec.back.top
    let spec.name = spec.back.name . '#' . name
  endif

  " get all possible holes
  let possible_holes = []
  for obj in spec.extractors
    for kv in items(obj)
      let possible_holes = possible_holes + [kv[0]]
    endfor
  endfor

  " set update
  let name = spec.name . '#update>> update'
  let value = v:null
  let holes = [] " we don't support holes for update commands
  if has_key(spec, 'update')
    let value = spec.update.value
  else
    let value = spec.back.update.value
  endif
  let spec.update = s:Command('UpdateCommand', name, value, holes)

  " set ui commands
  let spec.uiCommands = []
  for value in ['update', 'back', 'top']
    let name = spec.name . '#ui>> ' . value
    let spec.uiCommands = spec.uiCommands +
          \ [s:Command('UiCommand', name, value, [])]
  endfor

  " categorize non-keywords
  let commandsKv = []
  let childrenKv = []
  let keywords = plum#ui#spec#Keywords()
  for kv in items(spec)
    if index(keywords, kv[0]) >= 0
      continue
    endif
    if has_key(kv[1], 'type') &&
          \ ('UserCommand' ==# kv[1].type || 
          \  'EmptyUserCommand' ==# kv[1].type)
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
    let name = spec.name .'>> ' . kv[0]
    let value = kv[0]
    if has_key(kv[1], 'value')
      let value = kv[1].value
    endif
    let holes = s:ExtractHoles(value, possible_holes)
    let spec.commands = spec.commands + 
          \ [s:Command('Command', name, value, holes)]
  endfor

  " reify extractors
  let extractors = []
  for obj in spec.extractors
    for kv in items(obj)
      let ext = { 'type': 'Extractor'
            \   , 'name': kv[0]
            \   , 'IsMatch': kv[1]
            \   , 'commands' : [] }
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
          \ [plum#ui#spec#Reify(name, childSpec, spec)]
  endfor
  let spec.children = children 

  return spec
endfunction

function! plum#ui#spec#Keywords()
  return [ 'name', 'back', 'top', 'update' 
        \, 'uiCommands', 'extractors', 'commands', 'children']
endfunction

function! s:Command(type, name, value, holes)
  return { 'type': a:type
        \, 'name': a:name
        \, 'value': a:value
        \, 'holes': a:holes
        \}
endfunction

function! s:FillHoles(obj, holes)
  let obj = a:obj
  let holes = a:holes
  let commands = []
  for c in obj.commands
    let cmd = deepcopy(c)
    for kv in holes
      let idx = index(cmd.holes, kv[0])
      if idx >= 0
        let cmd.value = s:StringReplace(cmd.value, '{{'.kv[0].'}}', kv[1])
        let cmd.name = s:StringReplace(cmd.name, '{{'.kv[0].'}}', kv[1])
        call remove(cmd.holes, idx)
      endif
    endfor
    let commands = commands + [cmd]
  endfor
  return commands
endfunction

function! s:ExtractHoles(value, possible_holes)
  let value = a:value
  let possible_holes = a:possible_holes
  let holes = []
  for hole in possible_holes
    if s:StringContains(value, '{{' . hole . '}}')
      let holes = holes + [hole]
    endif
  endfor
  return holes
endfunction

function! s:StringContains(haystack, needle)
  return s:FindStringIndex(a:haystack, a:needle) >= 0
endfunction

function! s:FindStringIndex(haystack, needle)
  let haystack = a:haystack
  let needle = a:needle
  let needleSize = len(needle)
  let i = 0
  while i < len(haystack)
    if strpart(haystack, i, needleSize) ==# needle
      return i
    endif
    let i = i + 1
  endwhile
  return -1
endfunction

function! s:StringReplace(haystack, needle, new_needle)
  let haystack = a:haystack
  let needle = a:needle
  let new_needle = a:new_needle
  let needleStart = s:FindStringIndex(haystack, needle)
  if needleStart < 0
    return haystack
  endif
  let needleEnd = needleStart + len(needle)
  return haystack[0:needleStart-1] . new_needle . haystack[needleEnd:-1]
endfunction

function! plum#ui#spec#Cmd(...)
  if a:0 ==# 0
    return { 'type': 'EmptyUserCommand' }
  endif
  return { 'type': 'UserCommand', 'value': a:1 }
endfunction

function! plum#ui#spec#Example()
  return { 'name': 'plum-git'
        \, 'update': plum#ui#spec#Cmd('git status')
        \, 'extractors': [
        \    { 'staged': 'stagedfn' },
        \    { 'untracked' : 'untrackedfn' } ]
        \, '[patch]': {
        \    'extractors': [
        \      { 'staged': 'patchstagedfn' },
        \      { 'unstaged': 'patchunstagedfn' } ],
        \    'git patch {{unstaged}}': plum#ui#spec#Cmd() }
        \, 'git add -A' : plum#ui#spec#Cmd()
        \, 'git add {{untracked}}' : plum#ui#spec#Cmd()
        \, 'git reset HEAD -- {{staged}}' : plum#ui#spec#Cmd() }
endfunction
