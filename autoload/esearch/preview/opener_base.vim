let s:Buf = esearch#preview#buf#import()
let s:Log = esearch#log#import()
let [s:true, s:false, s:null, s:t_dict, s:t_float, s:t_func,
     \ s:t_list, s:t_number, s:t_string] = esearch#polyfill#definitions()

fu! esearch#preview#opener_base#import() abort
  return copy(s:OpenerBase)
endfu

let s:OpenerBase = {}

fu! s:OpenerBase.new(location, shape, emphasis, vars, opts, close_on) abort dict
  let new = copy(self)
  let new.location = a:location
  let new.shape    = a:shape
  let new.vars = a:vars
  let new.opts     = a:opts
  let new.close_on = a:close_on
  let new.emphasis = a:emphasis
  return new
endfu

fu! s:OpenerBase.shell() abort dict
  let current_win = esearch#win#stay()
  let self.buf = s:Buf.fetch_or_create(
        \ self.location.filename, g:esearch#preview#buffers)

  try
    call esearch#preview#close()
    let g:esearch#preview#win = self.popup
          \.new(self.buf, self.location, self.shape, self.close_on)
          \.open()
    let self.win = g:esearch#preview#win
    let self.win.upd_at = reltime()
    let self.win.cache_key = [self.opts, self.shape.align]
    call self.win.let(self.vars)
    call self.win.place_emphasis(self.emphasis)
    call self.win.reshape()
    call self.win.init_autoclose_events()
  catch
    call esearch#preview#close()
    call s:Log.error(v:exception . (g:esearch#env is 0 ? '' : v:throwpoint))
    return s:false
  finally
    noau keepj call current_win.restore()
  endtry

  return s:true
endfu
