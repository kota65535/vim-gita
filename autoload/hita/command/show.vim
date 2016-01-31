let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:StringExt = s:V.import('Data.StringExt')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:WORKTREE = '@'

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [])
  return options
endfunction
function! s:get_ancestor_content(git, commit, filename, options) abort
  let [lhs, rhs] = s:GitTerm.split_range(a:commit)
  let lhs = empty(lhs) ? 'HEAD' : lhs
  let rhs = empty(rhs) ? 'HEAD' : rhs
  let commit = s:GitInfo.get_common_ancestor(git, lhs, rhs)
  return s:get_revision_content(a:git, commit, a:filename, a:options)
endfunction
function! s:get_revision_content(git, commit, filename, options) abort
  let options = s:pick_available_options(a:options)
  if empty(a:filename)
    let options['object'] = a:commit
  else
    let options['object'] = printf('%s:%s',
          \ a:commit,
          \ gita#get_relative_path(a:git, a:filename),
          \)
  endif
  let result = gita#execute(a:git, 'show', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction
function! s:get_diff_content(git, content, filename, options) abort
  let tempfile = tempname()
  let tempfile1 = tempfile . '.index'
  let tempfile2 = tempfile . '.buffer'
  try
    " save contents to temporary files
    call writefile(
          \ s:get_revision_content(a:git, '', a:filename, a:options),
          \ tempfile1,
          \)
    call writefile(a:content, tempfile2)
    " create a diff between index_content and content
    let result = gita#command#diff#call({
          \ 'no-index': 1,
          \ 'filenames': [tempfile1, tempfile2],
          \})
    if empty(result) || empty(result.content) || len(result.content) < 4
      " fail or no differences. Assume there are no differences
      call gita#throw('Attention: No differences')
    endif
    " replace tempfile1/tempfile2 in HEADER to a:filename
    "
    "   diff --git a/<tempfile1> b/<tempfile2>
    "   index XXXXXXX..XXXXXXX XXXXXX
    "   --- a/<tempfile1>
    "   +++ b/<tempfile2>
    "
    let src1 = s:StringExt.escape_regex(tempfile1)
    let src2 = s:StringExt.escape_regex(tempfile2)
    let repl = (tempfile =~# '^/' ? '/' : '') . s:Path.unixpath(
          \ s:Git.get_relative_path(a:git, a:filename)
          \)
    let content = result.content
    let content[0] = substitute(content[0], src1, repl, '')
    let content[0] = substitute(content[0], src2, repl, '')
    let content[2] = substitute(content[2], src1, repl, '')
    let content[3] = substitute(content[3], src2, repl, '')
    return content
  finally
    call delete(tempfile1)
    call delete(tempfile2)
  endtry
endfunction

function! s:on_BufWriteCmd() abort
  let tempfile = tempname()
  try
    let commit = gita#get_meta('commit', '')
    let options = gita#get_meta('options', {})
    let filename = gita#get_meta('filename', '')
    if !empty(commit) || empty(filename)
      call gita#throw(
            \ 'Attention:',
            \ 'Partial patching is only available in a INDEX file, namely',
            \ 'a file opened by ":Gita show [--filename={filename}]"',
            \)
    endif
    if exists('#BufWritePre')
      doautocmd BufWritePre
    endif
    let git = gita#get_or_fail()
    let content = s:get_diff_content(git, getline(1, '$'), filename, options)
    call writefile(content, tempfile)
    call gita#command#apply#call({
          \ 'filenames': [tempfile],
          \ 'cached': 1,
          \ 'verbose': 1,
          \})
    call gita#command#show#edit({'force': 1})
    if exists('#BufWritePost')
      doautocmd BufWritePost
    endif
    diffupdate
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  finally
    call delete(tempfile)
  endtry
endfunction

function! gita#command#show#bufname(...) abort
  let options = gita#option#init('^show$', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  if options.commit ==# s:WORKTREE
    return gita#variable#get_valid_filename(options.filename)
  endif
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filename)
        \ ? ''
        \ : gita#variable#get_valid_filename(options.filename)
  return gita#autocmd#bufname(git, {
        \ 'content_type': 'show',
        \ 'extra_options': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! gita#command#show#call(...) abort
  let options = gita#option#init('^show$', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if empty(options.filename)
    let filename = ''
    let content = s:get_revision_content(git, commit, filename, options)
  else
    let filename = gita#variable#get_valid_filename(options.filename)
    if commit =~# '^.\{-}\.\.\..*$'
      let content = s:get_ancestor_content(git, commit, filename, options)
    elseif commit =~# '^.\{-}\.\..*$'
      let commit  = s:GitTerm.split_range(commit)[0]
      let content = s:get_revision_content(git, commit, filename, options)
    else
      let content = s:get_revision_content(git, commit, filename, options)
    endif
  endif
  let result = {
        \ 'commit': commit,
        \ 'filename': filename,
        \ 'content': content,
        \}
  return result
endfunction
function! gita#command#show#open(...) abort
  let options = extend({
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#show#default_opener
        \ : options.opener
  let bufname = gita#command#show#bufname(options)
  if !empty(bufname)
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    " BufReadCmd will call ...#edit to apply the content
    call gita#util#select(options.selection)
  endif
endfunction
function! gita#command#show#read(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = gita#command#show#call(options)
  call gita#util#buffer#read_content(result.content)
endfunction
function! gita#command#show#edit(...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let result = gita#command#show#call(options)
  call gita#set_meta('content_type', 'show')
  call gita#set_meta('options', s:Dict.omit(options, ['force']))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('filename', result.filename)
  call gita#util#buffer#edit_content(result.content)
  if empty(result.filename)
    setfiletype git
    setlocal buftype=nowrite
    setlocal readonly
  else
    setlocal buftype=acwrite
    augroup vim_gita_internal_show_apply_diff
      autocmd! * <buffer>
      autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
    augroup END
    if empty(result.commit)
      setlocal noreadonly
    else
      setlocal readonly
    endif
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita show',
          \ 'description': 'Show a content of a commit or a file',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--summary',
          \ 'Show summary of the repository instead of file content', {
          \   'conflicts': ['filename'],
          \})
    call s:parser.add_argument(
          \ '--filename',
          \ 'A filename', {
          \   'complete': function('gita#variable#complete_filename'),
          \   'conflicts': ['summary'],
          \})
    call s:parser.add_argument(
          \ '--worktree',
          \ 'Open a content of a file in working tree', {
          \   'conflicts': ['summary'],
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'A line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to see.',
          \   'If nothing is specified, it show a content of the index.',
          \   'If <commit> is specified, it show a content of the named <commit>.',
          \   'If <commit1>..<commit2> is specified, it show a content of the named <commit1>',
          \   'If <commit1>...<commit2> is specified, it show a content of a common ancestor of commits',
          \], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'summary')
        let a:options.filename = ''
        unlet a:options.summary
      endif
      if has_key(a:options, 'worktree')
        let a:options.commit = s:WORKTREE
        unlet a:options.worktree
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#show#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  if has_key(options, 'selection')
    let options.selection = map(
          \ split(options.selection, '-'),
          \ 'str2nr(v:val)',
          \)
  else
    let options.selection = options.__range__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#show#default_options),
        \ options,
        \)
  call gita#command#show#open(options)
endfunction
function! gita#command#show#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#show', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})
