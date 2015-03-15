"******************************************************************************
" Git status (--porcelain) parser
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital ======================================================================
let s:const = {}
let s:const.status_pattern     = '\v^([ MDARCU\?!])([ MDUA\?!])\s("[^"]+"|[^ ]+)%(\s-\>\s("[^"]+"|[^ ]+)|)$'
let s:const.status_pattern2    = '\v^([ MDARCU\?!])([ MDUA\?!])\s("[^"]+"|.+)$'
let s:const.conflicted_pattern = '\v^%(DD|AU|UD|UA|DU|AA|UU)$'
let s:const.staged_pattern     = '\v^%([MARC][ MD]|D[ M])$'
let s:const.unstaged_pattern   = '\v^%([ MARC][MD]|DM)$'
let s:const.untracked_pattern  = '\v^\?\?$'
let s:const.ignored_pattern    = '\v^!!$'

function! s:_vital_loaded(V) dict abort
  " define constant variables
  call extend(self, s:const)
endfunction


function! s:parse_record(line, ...) abort " {{{
  let opts = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  for pattern in [s:const.status_pattern, s:const.status_pattern2]
    let m = matchlist(a:line, pattern)
    let result = {}
    if len(m) > 5 && m[4] !=# ''
      " 'XY PATH1 -> PATH2' pattern
      let result.index = m[1]
      let result.worktree = m[2]
      let result.path = substitute(m[3], '\v%(^"|"$)', '', 'g')
      let result.path2 = substitute(m[4], '\v%(^"|"$)', '', 'g')
      let result.record = a:line
      let result.sign = m[1] . m[2]
      let result.is_conflicted = s:is_conflicted(result.sign)
      let result.is_staged = s:is_staged(result.sign)
      let result.is_unstaged = s:is_unstaged(result.sign)
      let result.is_untracked = s:is_untracked(result.sign)
      let result.is_ignored = s:is_ignored(result.sign)
      return result
    elseif len(m) > 4 && m[3] !=# ''
      " 'XY PATH' pattern
      let result.index = m[1]
      let result.worktree = m[2]
      let result.path = substitute(m[3], '\v%(^"|"$)', '', 'g')
      let result.record = a:line
      let result.sign = m[1] . m[2]
      let result.is_conflicted = s:is_conflicted(result.sign)
      let result.is_staged = s:is_staged(result.sign)
      let result.is_unstaged = s:is_unstaged(result.sign)
      let result.is_untracked = s:is_untracked(result.sign)
      let result.is_ignored = s:is_ignored(result.sign)
      return result
    endif
  endfor
  if opts.fail_silently
    return {}
  endif
  throw printf('vital: VCS.Git.StatusParser: Parsing a record failed: "%s"', a:line)
endfunction " }}}
function! s:parse(status, ...) abort " {{{
  let opts = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let obj = {
        \ 'all': [],
        \ 'conflicted': [],
        \ 'staged': [],
        \ 'unstaged': [],
        \ 'untracked': [],
        \ 'ignored': [],
        \}
  for line in split(a:status, '\v%(\r?\n)+')
    let result = s:parse_record(line, opts)
    call add(obj.all, result)
    if result.is_conflicted
      call add(obj.conflicted, result)
    elseif result.is_staged && result.is_unstaged
      call add(obj.staged, result)
      call add(obj.unstaged, result)
    elseif result.is_staged
      call add(obj.staged, result)
    elseif result.is_unstaged
      call add(obj.unstaged, result)
    elseif result.is_untracked
      call add(obj.untracked, result)
    elseif result.is_ignored
      call add(obj.ignored, result)
    endif
  endfor
  return obj
endfunction " }}}

function! s:is_conflicted(sign) " {{{
  return a:sign =~# s:const.conflicted_pattern
endfunction " }}}
function! s:is_staged(sign) " {{{
  return a:sign =~# s:const.staged_pattern
endfunction " }}}
function! s:is_unstaged(sign) " {{{
  return a:sign =~# s:const.unstaged_pattern
endfunction " }}}
function! s:is_untracked(sign) " {{{
  return a:sign =~# s:const.untracked_pattern
endfunction " }}}
function! s:is_ignored(sign) " {{{
  return a:sign =~# s:const.ignored_pattern
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker