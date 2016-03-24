let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita show',
          \ 'description': 'Show a content of a commit or a file',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<path>',
          \ 'complete_unknown': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--repository', '-r',
          \ 'show a summary of the repository instead of a file content', {
          \   'conflicts': ['worktree', 'ancestor', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--worktree', '-w',
          \ 'open a content of a file in working tree', {
          \   'conflicts': ['repository', 'ancestor', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--ancestors', '-1',
          \ 'open a content of a file in a common ancestor during merge', {
          \   'conflicts': ['repository', 'worktree', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--ours', '-2',
          \ 'open a content of a file in our side during merge', {
          \   'conflicts': ['repository', 'worktree', 'ancestors', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--theirs', '-3',
          \ 'open a content of a file in thier side during merge', {
          \   'conflicts': ['repository', 'worktree', 'ancestors', 'ours'],
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'a line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ '--patch',
          \ 'show a content of a file in PATCH mode. It force to open an INDEX file content',
          \)
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit which you want to see.',
          \   'if nothing is specified, it show a content of the index.',
          \   'if <commit> is specified, it show a content of the named <commit>.',
          \   'if <commit1>..<commit2> is specified, it show a content of the named <commit1>',
          \   'if <commit1>...<commit2> is specified, it show a content of a common ancestor of commits',
          \], {
          \   'complete': function('gita#complete#commitish'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if get(a:options, 'repository')
        let a:options.filename = ''
        unlet a:options.repository
      elseif get(a:options, 'ancestor')
        let a:options.commit = ':1'
        unlet a:options.ancestor
      elseif get(a:options, 'ours')
        let a:options.commit = ':2'
        unlet a:options.ours
      elseif get(a:options, 'theirs')
        let a:options.commit = ':3'
        unlet a:options.theirs
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction

function! gita#command#show#execute(args, options) abort
  let git = gita#core#get_or_fail()
  let object = a:args[0]
  let commit = matchstr(object, '^[^:]*')
  let filename = matchstr(object, '^[^:]*:\zs.*$')
  if commit =~# '^.\{-}\.\.\..\{-}$'
    " support A...B style
    let [lhs, rhs] = s:GitTerm.split_range(commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let commit = s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
  elseif commit =~# '^.\{-}\.\..\{-}$'
    " support A..B style
    let commit  = s:GitTerm.split_range(commit)[0]
  endif
  let object = empty(filename) ? commit : commit . ':' . filename
  let args = ['show'] + [object]
  return gita#execute(git, args, a:options)
endfunction

function! gita#command#show#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options)
  call gita#content#show#open(options)
endfunction

function! gita#command#show#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
