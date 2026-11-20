let s:root = expand('<sfile>:p:h:h')

function! s:start() abort
  call goda#start(s:root . '/bin/goda-fixture')
endfunction

" Returns a:text reversed by the binary.
function! goda_fixture#reverse(text) abort
  if !goda#is_running('fixture')
    call goda#register('fixture', function('s:start'),
          \ #{version: 1, module: 'github.com/airRnot1106/goda-fixture.vim'})
  endif
  return goda#request('fixture', 'reverse', a:text)
endfunction
