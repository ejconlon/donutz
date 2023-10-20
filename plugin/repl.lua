--- A deconstructed fennel repl that allows us to incrementally
-- feed input (e.g. from a socket) from lua.
-- @module repl

local repl = require('fennel.repl')
local view = require('fennel.view')
local compiler = require('fennel.compiler')
local specials = require('fennel.specials')
local splice = require('vendor.splice')

--- From 8fl - try fennel.view to render to string,
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

--- Read contents of a file into a string
function fread(fn)
  local f = io.open(fn, 'r')
  io.input(f)
  local buf = io.read('*all')
  io.close(f)
  io.input(io.stdin)
  return buf
end
  
--- Check if file exists
function fexists(fn)
   local f = io.open(fn, 'r')
   local exists = f ~= nil
   if exists then
     io.close(f)
   end
   io.input(io.stdin)
   return exists
end

--- Find a usable filename for the module or error out.
function resolveModuleFileName(mod, fn)
  if fn == nil then
    local base = mod:gsub('%.', '/')
    fn = base .. '.lua'
    if not fexists(fn) then
      fn = base .. '/init.fnl'
    end
  end

  if not fexists(fn) then
    error('Module ' .. mod .. ' not found at path ' .. fn .. '\n')
  end

  return fn
end

--- Lookup packages in the current environment and return
-- tables suitable for constructing a new sub-environment.
function lookupPkgs(pkgs)
  local loaded = {}
  local locals = {}
  if pkgs ~= nil then
    for _, v in ipairs(pkgs) do
      local contents = _G.package.loaded[v.mod]
      loaded[v.mod] = contents
      locals[v.name] = contents
    end
  end
  return loaded, locals
end

--- Create a new sub-environment.
function mkEnv(write, config)
  local loaded, locals = lookupPkgs(config.pkgs)

  local env = {
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
  }

  -- TODO put require, reload, inline in env 

  if config.defns ~= nil then
    for k, v in pairs(config.defns) do
      if env[k] ~= nil then
        error('Duplicate environment key: ' .. k)
      else
        env[k] = v
      end
    end
  end

  return specials['wrap-env'](env)
end

--- Evaluate fennel code in the given context
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

--- Evaluate the module at the given file path
function modEval(write, config, buf, fn)
  local env = mkEnv(write, config)
  local scope = compiler['make-scope']()
  return rawEval(write, env, buf, scope, false, fn)
end

-- NOTE on Fennel REPL scope:
--
-- locals are stored in in
-- env.___replLocals___
--
-- modules are stored in
-- env._G.package.loaded (map from module name to module defn)

--- Require the given module with a sub-environment
function rawRequire(write, config, env, mod, fn, reload)
  local res = env._G.package.loaded[mod]
  if reload or res == nil then
    fn = resolveModuleFileName(mod, fn)
    local buf = fread(fn)
    res = modEval(write, config, buf, fn)
    env._G.package.loaded[mod] = res
  end
  return res
end

--- Import module with local name
function rawImport(write, config, env, name, mod, fn, reload)
  local res = rawRequire(write, config, env, mod, fn, reload)
  env.___replLocals___[name] = res
end

--- Inline module exports
function rawInline(write, config, env, mod, fn, reload)
  local res = rawRequire(write, config, env, mod, fn, reload)
  for k, v in pairs(res) do
    env.___replLocals___[k] = v
  end
end

--- Creates REPL state with appropriate sub-environment
function mkState(write, config)
  return {
    buf = '',
    scope = compiler['make-scope'](),
    env = mkEnv(write, config)
  }
end

--- Cal on REPL start
function onStart(write, st, config)
  if config.imports ~= nil then
    for _, v in ipairs(config.imports) do
      local ok, err = pcall(rawImport, write, config, st.env, v.name, v.mod, v.fn, false)
      if not ok then
        write('Failed to import ' .. v.mod .. ': ' .. err .. '\n')
      end
    end
  end
  if config.inlines ~= nil then
    for _, v in ipairs(config.inlines) do
      local ok, err = pcall(rawInline, write, config, st.env, v.mod, v.fn, false)
      if not ok then
        write('Failed to inline ' .. v.mod .. ': ' .. err .. '\n')
      end
    end
  end
  write('ooo donutz ooo\n>> ')
end

--- Given buffer, return true if ready to evaluate input.
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

--- Call on additional input
function onInput(write, st, inp)
  if #inp > 0 then
    st.buf = st.buf .. inp .. '\n'
    local output = ''
    if isReady(st.buf) then
      local ok, result = pcall(rawEval, write, st.env, st.buf, st.scope, true)
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
end

--- Run a local repl
function run(config)
  local st = mkState(io.write, config)
  onStart(io.write, st, config)
  local inp = io.read()
  while inp ~= nil do
    onInput(io.write, st, inp)
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
