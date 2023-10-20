local repl = require('fennel.repl')
local view = require('fennel.view')
local compiler = require('fennel.compiler')
local specials = require('fennel.specials')
local parser = require('fennel.parser')

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

function mkReplState(ioif)
  return {
    cont = false,
    buf = '',
    scope = compiler['make-scope'](),
    env = specials['wrap-env'] {
      _G = _G,
      renoise = _G.renoise,
      print = function(...)
        local first = true
        for i, v in ipairs(arg) do
          ioif.write(stringify(v))
          if first then
            first = false
          else
            ioif.write('\t')
          end
        end
        ioif.write('\n')
      end,
    }
  }
end

function mkLocalIOIF()
  return {
    write = io.write,
    flush = io.flush,
  }
end

function mkSocketIOIF(socket)
  return {
    write = function(data)
      socket:send(data)
    end,
    flush = function()
    end,
  }
end

function replOnValues(ioif, xs)
  ioif.write(table.concat(xs, '\t'))
  ioif.write('\n')
  ioif.flush()
end

function replOnError(ioif, errtype, err, luaSource)
  local message
  if errtype == 'Lua Compile' then
    message = 
      'Bad code generated - likely a bug with the compiler:\n' ..
      '--- Generated Lua Start ---\n' ..
      luaSource .. '\n' ..
      '--- Generated Lua End ---\n'
  elseif message == 'Runtime' then
    message = compiler.traceback(stringify(err), 4) .. '\n'
  else
    message = string.format('%s error: %s\n', errtype, stringify(err))
  end
  ioif.write(message)
  ioif.flush()
end

function replStart(ioif)
  ioif.write('>> ')
  ioif.flush()
end

-- Given buffer, return true if ready to evaluate input
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

function replEval(st)
    local ok, code = pcall(compiler['compile-string'], st.buf, { scope = st.scope })
    if not ok then
        error('Failed to compile ' .. code)
    end
    print('---')
    print(code)
    print('---')
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

function replStep(ioif, st)
  if isReady(st.buf) then
    local ok, result = pcall(replEval, st)
    st.buf = '' 
    if ok then
      if result ~= nil then
        ioif.write(stringify(result))
      end
    else
      ioif.write('Error: ') 
      ioif.write(result)
    end
    ioif.write('\n>> ')
  else
    ioif.write('..')
  end
  ioif.flush()
end

function replLocal()
  local ioif = mkLocalIOIF()
  local st = mkReplState(ioif)
  replStart(ioif)
  local inp = io.read()
  while inp ~= nil do
    if #inp > 0 then
      st.buf = st.buf .. inp .. '\n'
      replStep(ioif, st)
    end
    inp = io.read()
  end
end

function main()
  if _G.renoise == nil then
    -- Just a regular repl - note that renoisey things will not work
    replLocal()
  else
    local prefs = renoise.tool().preferences
    if prefs == nil then
      prefs = renoise.Document.create('donutzPrefs') {
        hostname = '0.0.0.0',
        port = 9876
      }
      renoise.tool().preferences = prefs
    end
    -- local server, err = renoise.Socket.create_server(prefs.hostname.value, prefs.port.value)
    -- if err then
    --   renoise.app():show_warning('Z: ' .. tostring(err))
    --   return
    -- else
    --   renoise.tool().tool_will_unload_observable:add_notifier(onUnload(server))
    --   local conns = {}
    --   local serverConf = {
    --     socket_error = onSocketError,
    --     socket_accepted = onSocketAccepted(conns),
    --     socket_message = onSocketMessage(conns),
    --   }
    --   server:run(serverConf)
    -- end
  end
end

main()

-- function onSocketError(err)
--   renoise.app():show_status('Z: ' .. tostring(err))
-- end
--
-- function onSocketAccepted(conns)
--   return function(socket)
--     local ix = socket.peer_port
--     renoise.app():show_status('Z: Connnected to ' .. tostring(socket.peer_port))
--     socket:send('ooo donutz ooo\n> ')
--     conns[ix] = { buf = '', coro = mkCoro(socket) }
--   end
-- end
--
-- function onSocketMessage(conns)
--   return function(socket, inp)
--     local ix = socket.peer_port
--     local buf = appendInput(conns[ix].buf, inp) 
--     while true do
--       local sexp, rest = consumeSexp(buf)
--       if sexp == nil then
--         conns[ix].buf = rest
--         break
--       else
--         buf = rest
--         coroutine.resume(conns[ix].coro, sexp)
--       end
--     end
--   end
-- end
--
-- function onUnload(server)
--   return function()
--     renoise.app():show_status('Z: Shutting down server')
--     server:stop()
--   end
-- end
