-- A decomposed fennel repl that allows us to incrementally
-- feed input (e.g. from a socket) from lua.

local repl = require('fennel.repl')
local view = require('fennel.view')
local compiler = require('fennel.compiler')
local specials = require('fennel.specials')

-- From 8fl - try fennel.view to render to string,
-- but fallback gracefully to tostring and type output
function stringify(obj)
  local ok, string = pcall(view, obj)
  if ok then
    return string
  end
  local ok, string = pcall(tostring, obj)
  if ok then
    return string
  end
  return '#<' .. tostring(type(obj)) .. '>'
end

function mkState(write, addl)
  local env0 = { {
      _G = _G,
      print = function(...)
        local first = true
        local output = ''
        for i, v in ipairs(arg) do
          output = output .. stringify(v)
          if first then
            first = false
          else
            output = output .. '\t'
          end
        end
        output = output .. '\n'
        write(output)
      end,
    }
  } 
  if addl ~= nil then
    for k, v in pairs(addl) do
      if env0[k] ~= nil then
        error('Duplicate environment key: ' .. k)
      else
        env0[k] = v
      end
    end
  end
  return {
    buf = '',
    scope = compiler['make-scope'](),
    env = specials['wrap-env'](env0),
  }
end

-- Given buffer, return true if ready to evaluate input.
-- We approximate this by checking paren matches. String
-- escapes are very rudimentary.
-- string -> bool
function isReady(buf)
  local depth = 0
  local escaping = false
  local state = 'normal'

  for i = 1, #buf do
    local c = buf:sub(i,i)
    if state == 'singleq' then
      if escaping then
        escaping = false
      elseif c == '\'' then
        state = 'normal'
      else
        escaping = c == '\\'
      end
    elseif state == 'doubleq' then
      if escaping then
        escaping = false
      elseif c == '"' then
        state = 'normal'
      else
        escaping = c == '\\'
      end
    elseif state == 'comment' then
      if c == '\n' then
        state = 'normal'
      end
    elseif state == 'normal' then 
      -- first check pair chars
      if c == '(' then
        depth = depth + 1
      elseif c == ')' then
        if depth == 0 then
          -- known depth mismatch, send now for error
          return true
        else
          depth = depth - 1
        end
      elseif c == '\'' then
        state = 'singleq'
      elseif c == '"' then
        state = 'doubleq'
      end

      -- now check comment escape
      if c == ';' then
        if escaping then
          escaping = false
          state = 'comment'
        else
          escaping = true
        end
      else
        escaping = false
      end
    else
      error('Internal error: invalid state: ' .. state)
    end
  end

  -- If normal, we are ready when matched (depth == 0)
  -- otherwise we are waiting for end quote/newline
  return depth == 0 or state ~= 'normal'
end

function eval(write, st)
    local ok, code = pcall(compiler['compile-string'], st.buf, { scope = st.scope })
    if not ok then
        error('Failed to compile ' .. code)
    end
    local f, err
    if _G.loadstring then
      f, err = loadstring(code)
      if not err then
        setfenv(f, st.env)
      end
    else
      f, err = load(code, code, 't', st.env)
    end
    if err then
        error('Failed to load ' .. code .. ' error: ' .. err)
    end
    local ok, result = pcall(f)
    if not ok then
        error('Failed to call ' .. result)
    end
    return result
end

function onStart(write)
  write('ooo donutz ooo\n>> ')
end

function step(write, st)
  local output = ''
  if isReady(st.buf) then
    local ok, result = pcall(eval, write, st)
    st.buf = '' 
    if ok then
      output = output .. stringify(result)
    else
      output = output .. 'Error: ' .. result
    end
    output = output .. '\n>> '
  else
    output = output .. '..'
  end
  write(output)
end

function onInput(write, st, inp)
  if #inp > 0 then
    st.buf = st.buf .. inp .. '\n'
    step(write, st)
  end
end

function run(addl)
  local write = io.write
  local st = mkState(write, addl)
  onStart(write)
  local inp = io.read()
  while inp ~= nil do
    onInput(write, st, inp)
    inp = io.read()
  end
end

return {
  stringify = stringify,
  mkState = mkState,
  onStart = onStart,
  onInput = onInput,
  run = run,
}
