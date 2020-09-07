fu! esearch#adapter#parse#lua#import() abort
  return function('esearch#adapter#parse#lua#parse')
endfu

if g:esearch#has#nvim_lua
  fu! esearch#adapter#parse#lua#parse(data, from, to) abort dict
    return luaeval('{esearch.parse.lines(_A[1], _A[2])}', [a:data[a:from : a:to], self._adapter.parser])
  endfu
else
  fu! esearch#adapter#parse#lua#parse(data, from, to) abort dict
    let [parsed, separators_count] = luaeval('vim.list({esearch.parse.lines(_A[1], _A[2])})', [a:data[a:from : a:to], self._adapter.parser])
    return [parsed, float2nr(separators_count)]
  endfu
endif
