set encoding=utf-8
let &runtimepath = join(map([$GODA_FIXTURE_E2E_PLUGIN, $GODA_FIXTURE_E2E_GODA], {_, dir -> escape(dir, ',')}) + [&runtimepath], ',')

let s:result = {}
try
  let s:result.reversed = goda_fixture#reverse('goda')
catch
  let s:result.error = v:exception . ' at ' . v:throwpoint
endtry

call writefile([json_encode(s:result)], $GODA_FIXTURE_E2E_OUT)
qall!
