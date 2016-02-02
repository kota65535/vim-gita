let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! gita#option#init(content_type, options, ...) abort
  let options = deepcopy(a:options)
  let content_type = gita#get_meta('content_type', '')
  if !empty(a:content_type)&& content_type =~# a:content_type
    call extend(options, gita#get_meta('options', {}), 'keep')
  endif
  call extend(options, get(a:000, 0, {}), 'keep')
  return options
endfunction

function! gita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif

  let content_type = gita#get_meta('content_type')
  if content_type =~# '^\%(status\|commit\|blame-navi\|blame-view\)$'
    let candidate = get(gita#action#get_candidates(), 0, {})
    if has_key(candidate, 'commit')
      let a:options.commit = candidate.commit
    elseif has_key(candidate, 'revision')
      let a:options.commit = candidate.revision
    endif
  endif
  if empty(get(a:options, 'commit'))
    if !empty(gita#get_meta('commit'))
      let a:options.commit = gita#get_meta('commit')
    endif
  endif
endfunction

function! gita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  endif
  let content_type = gita#get_meta('content_type')
  if content_type =~# '^\%(status\|commit\|blame-navi\|blame-view\)$'
    let candidate = get(gita#action#get_candidates(), 0, {})
    if has_key(candidate, 'path')
      let a:options.filename = candidate.path
      return
    elseif has_key(candidate, 'filename')
      let a:options.filename = candidate.filename
      return
    endif
  endif
  if empty(get(a:options, 'filename'))
    if !empty(gita#get_meta('filename'))
      let a:options.filename = gita#get_meta('filename')
    elseif !empty(gita#expand('%'))
      " NOTE:
      " gita#expand() always return a real absolute path or ''
      let a:options.filename = gita#expand('%')
    endif
  endif
endfunction

function! gita#option#assign_selection(options) abort
  if has_key(a:options, 'selection')
    let a:options.selection = map(
          \ split(a:options.selection, '-'),
          \ 'str2nr(v:val)',
          \)
  else
    let a:options.selection = a:options.__range__
  endif

  if gita#get_meta('content_type') =~# '^blame-\%(navi\|view\)%'
    let line_start = get(a:options.selection, 0, 0)
    let line_end = get(a:options.selection, 1, line_end)
    let a:options.selection = [
          \ gita#command#blame#get_pseudo_linenum(line_start),
          \ gita#command#blame#get_pseudo_linenum(line_end),
          \]
  endif
endfunction
