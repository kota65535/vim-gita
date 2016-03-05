function! s:is_available(candidate) abort
  let necessary_attributes = [
      \ 'is_remote',
      \ 'is_selected',
      \ 'name',
      \ 'remote',
      \ 'linkto',
      \ 'record',
      \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:action(candidates, options) abort
  let options = extend({
        \ 'merge': 0,
        \}, a:options)
  let branch_names = []
  for candidate in a:candidates
    if s:is_available(candidate)
      call add(branch_names, candidate.name)
    endif
  endfor
  if empty(branch_names)
    return
  endif
  call gita#command#rebase#call({
        \ 'quiet': 0,
        \ 'commits': branch_names,
        \ 'merge': options.merge,
        \})
endfunction

function! gita#action#rebase#define(disable_mapping) abort
  call gita#action#define('rebase', function('s:action'), {
        \ 'description': 'Rebase HEAD from the commit (fast-forward)',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('rebase:merge', function('s:action'), {
        \ 'description': 'Rebase HEAD by merging the commit',
        \ 'mapping_mode': 'n',
        \ 'options': { 'merge': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
