-- A decomposed fennel repl that allows us to incrementally
-- feed input (e.g. from a socket) from lua.

local repl = require('fennel.repl')
local view = require('fennel.view')
local compiler = require('fennel.compiler')
local specials = require('fennel.specials')
local splice = require('vendor.splice')

STDLIB_PKGS = {
  {name = 'string', mod = 'string'},
}

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

function mkState(write, pkgs, defns)
  -- forward-declare st so we can refer to it
  -- when we define require
  local st = {
    buf = '',
    scope = compiler['make-scope'](),
  }

  local loaded = {}
  local locals = {}
  if pkgs ~= nil then
    for _, v in ipairs(pkgs) do
      local contents = _G.package.loaded[v.mod]
      loaded[v.mod] = contents
      locals[v.name] = contents
    end
  end

  local env0 = {
    -- TODO what else should go in globals?
    _G = { package = { loaded = loaded } },
    ___replLocals___ = locals,
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
    -- TODO put require in there
  } 

  if defns ~= nil then
    for k, v in pairs(defns) do
      if env0[k] ~= nil then
        error('Duplicate environment key: ' .. k)
      else
        env0[k] = v
      end
    end
  end

  st.env = specials['wrap-env'](env0)

  return st
end

function lineEval(write, st)
  return rawEval(write, st.env, st.buf, st.scope, true)
end

function modEval(write, buf, fn)
  env = specials['wrap-env']({_G = {packages}})
  scope = compiler['make-scope']()
  return rawEval(write, env, buf, scope, false, fn)
end

function fread(fn)
  local f = io.open(fn, 'r')
  io.input(f)
  local buf = io.read('*all')
  io.close(f)
  io.input(io.stdin)
  return buf
end

-- NOTE on Fennel REPL scope:
--
-- locals are stored in in
-- env.___replLocals___
--
-- modules are stored in
-- env._G.package.loaded (map from module name to module defn)

function rawRequire(write, st, mod, fn, reload)
  local res = st.env._G.package.loaded[mod]
  if reload or res == nil then
    buf = fread(fn)
    res = modEval(write, buf, fn)
    st.env._G.package.loaded[mod] = res
  end
  return res
end

-- Import module with local name
function import(write, st, name, mod, fn, reload)
  local res = rawRequire(write, st, mod, fn, reload)
  st.env.___replLocals___[name] = res
end

-- Inline module exports
function inline(write, st, mod, fn, reload)
  local res = rawRequire(write, st, mod, fn, reload)
  for k, v in pairs(res) do
    st.env.___replLocals___[k] = v
  end
end

-- Evaluate fennel code in the given context
function rawEval(write, env, buf, scope, shouldSplice, source)
  local ok, code = pcall(compiler['compile-string'], buf, { scope = scope })
  if not ok then
    error('Failed to compile ' .. code)
  end

  local spliced
  if shouldSplice then
    spliced = splice(env, code, scope)
  else
    spliced = code
  end

  local f, err
  if _G.loadstring then
    f, err = loadstring(spliced)
    if not err then
      setfenv(f, env)
    end
  else
    f, err = load(spliced, source, 't', env)
  end
  if err then
    error('Failed to load ' .. spliced .. ' error: ' .. err)
  end

  local ok, result = pcall(f)
  if not ok then
    error('Failed to call ' .. result)
  end

  return result
end

function onStart(write, st, imports, inlines)
  if imports ~= nil then
    for _, v in ipairs(imports) do
      local ok, err = pcall(import, write, st, v.name, v.mod, v.fn, false)
      if not ok then
        write('Failed to import ' .. v.mod .. ' from ' .. v.fn .. ': ' .. err)
      end
    end
  end
  if inlines ~= nil then
    for _, v in ipairs(inlines) do
      local ok, err = pcall(inline, write, st, v.mod, v.fn, false)
      if not ok then
        write('Failed to inline ' .. v.mod .. ' from ' .. v.fn .. ': ' .. err)
      end
    end
  end
  write('ooo donutz ooo\n>> ')
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

function step(write, st)
  local output = ''
  if isReady(st.buf) then
    local ok, result = pcall(lineEval, write, st)
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

function run(pkgs, defns, imports, inlines)
  local st = mkState(io.write, pkgs, defns)
  onStart(io.write, st, imports, inlines)
  local inp = io.read()
  while inp ~= nil do
    onInput(io.write, st, inp)
    inp = io.read()
  end
end

return {
  STDLIB_PKGS = STDLIB_PKGS,
  stringify = stringify,
  mkState = mkState,
  onStart = onStart,
  onInput = onInput,
  run = run,
}
