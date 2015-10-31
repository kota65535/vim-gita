if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

syntax clear
call gita#features#blame#define_highlights()
call gita#features#blame#define_syntax()

let b:current_syntax = "gita-blame-navi"
let &cpo = s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker