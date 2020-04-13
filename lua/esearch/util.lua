local util

local fnameescape
local filereadable

if vim.funcref == nil then
  function fnameescape(path)
    return vim.api.nvim_call_function('fnameescape', {path})
  end

  function filereadable(path, cache)
    if cache[path] then
      return true
    end
    local result = vim.api.nvim_call_function('filereadable', {path})

    if result == 1 then
      cache[path] = true;
      return true
    else
      cache[path] = false;
      return false
    end
  end
else
  function fnameescape(path)
    return vim.funcref('fnameescape')(path)
  end

  function filereadable(path, cache)
    if cache[path] then
      return true
    end
    local result = vim.funcref('filereadable')(path)

    if result == 1 then
      cache[path] = true;
      return true
    else
      cache[path] = false;
      return false
    end
  end
end


-- From https://www.lua.org/pil/20.4.html. Is used to perform unquoting
local function code(s)
  return (string.gsub(s, "\\([\\\"])", function (x)
            return string.format("\\%03d", string.byte(x))
          end))
end

local function decode(s)
  return (string.gsub(s, "\\(%d%d%d)", function (d)
            return "\\" .. string.char(d)
          end))
end

function parse_line(line, cache)
  local filename = ''

  -- At the moment only git adapter outputs lines that wrapped in "" when special
  -- characters are encountered
  if line:sub(1, 1) == '"' then
    local filename, line, text = code(line):match('"(.-)"[:%-](%d+)[:%-](.*)')
    if filename == nil then
      return
    end
    filename, line, text = decode(filename), decode(line), decode(text)

    local controls = {
      a      = '\a',
      b      = '\b',
      t      = '\t',
      n      = '\n',
      v      = '\v',
      f      = '\f',
      r      = '\r',
      z      = '\z',
      ['\\'] = '\\',
      ['\"'] = '\"',
      ['\033'] = string.char(27)
    }
    filename = filename:gsub('\\(.)', controls)
    if filereadable(filename, cache) then
      return filename, line, text
    end
  end

  -- try to find the first readable filename
  local filename_end = 1
  while true do
    filename_end, _ = line:find('[:%-]%d+[:%-]', filename_end + 1)

    if filename_end == nil then
      return
    end

    filename = line:sub(1, filename_end - 1)
    if filereadable(filename, cache) then
      break
    end
  end

  local line, text = line:match('(%d+)[:%-](.*)', filename_end)
  if line == nil or text == nil then
    return
  end

  return filename, line, text
end


util = {
  parse_line   = parse_line,
  filereadable = filereadable,
  fnameescape  = fnameescape,
}

return util