let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Prelude = s:V.import('Prelude')

function! s:smart_string(value) abort
  let vtype = type(a:value)
  if s:Prelude.is_string(a:value)
    return a:value
  elseif s:Prelude.is_number(a:value)
    return a:value ? string(a:value) : ''
  elseif s:Prelude.is_list(a:value) || s:Prelude.is_dict(a:value)
    return !empty(a:value) ? string(a:value) : ''
  else
    return string(a:value)
  endif
endfunction

function! hita#util#string#format(format, format_map, data) abort
  " format rule:
  "   %{<left>|<right>}<key>
  "     '<left><value><right>' if <value> != ''
  "     ''                     if <value> == ''
  "   %{<left>}<key>
  "     '<left><value>'        if <value> != ''
  "     ''                     if <value> == ''
  "   %{|<right>}<key>
  "     '<value><right>'       if <value> != ''
  "     ''                     if <value> == ''
  if empty(a:data)
    return ''
  endif
  let pattern_base = '\v\%%%%(\{([^\}\|]*)%%(\|([^\}\|]*)|)\}|)%s'
  let str = copy(a:format)
  for [key, Value] in items(a:format_map)
    if s:Prelude.is_funcref(Value)
      let result = s:smart_string(call(Value, [a:data], a:format_map))
    else
      let result = s:smart_string(get(a:data, Value, ''))
    endif
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', escape(result, '\')) : ''
    let str = substitute(str, '\C' . pattern, repl, 'g')
    unlet! Value
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction
function! hita#util#string#remove_ansi_sequences(val) abort
  return substitute(a:val, '\v\e\[%(%(\d;)?\d{1,2})?[mK]', '', 'g')
endfunction
function! hita#util#string#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction
function! hita#util#string#ensure_eol(text) abort
  return a:text =~# '\n$' ? a:text : a:text . "\n"
endfunction
function! hita#util#string#capitalize(text) abort
  return substitute(a:text, '\w\+', '\u\0', "")
endfunction


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
