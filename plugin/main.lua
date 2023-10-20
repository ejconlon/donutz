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

function mkReplState(write, addl)
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

function replOnValues(write, xs)
  write(table.concat(xs, '\t') .. '\n')
end

function replOnError(write, errtype, err, luaSource)
  local output 
  if errtype == 'Lua Compile' then
    message = 
      'Bad code generated - likely a bug with the compiler:\n' ..
      '--- Generated Lua Start ---\n' ..
      luaSource .. '\n' ..
      '--- Generated Lua End ---\n'
  elseif errtype == 'Runtime' then
    output = compiler.traceback(stringify(err), 4) .. '\n'
  else
    output = string.format('%s error: %s\n', errtype, stringify(err))
  end
  write(output)
end

function replStart(write)
  write('>> ')
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

function replEval(write, st)
    write('--- BUF  ---\n')
    for i = 1, #st.buf do
      local c = st.buf:sub(i,i)
      local d = string.byte(c)
      if c == '\n' then
        c = ' '
        d = '<NEWLINE>'
      elseif c == ' ' then
        c = ' '
        d = '<SPACE>'
      end
      write(tostring(i) .. '\t' .. c .. '\t' .. d .. '\n')
    end
    local ok, code = pcall(compiler['compile-string'], st.buf, { scope = st.scope })
    if not ok then
        error('Failed to compile ' .. code)
    end
    write('--- CODE ---\n')
    write(code .. '\n')
    write('------------\n')
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

function replStep(write, st)
  local output = ''
  if isReady(st.buf) then
    local ok, result = pcall(replEval, write, st)
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

function replInp(write, st, inp)
  if #inp > 0 then
    st.buf = st.buf .. inp .. '\n'
    replStep(write, st)
  end
end

function replLocal()
  local write = io.write
  local st = mkReplState(write, { renoise = nil })
  replStart(write)
  local inp = io.read()
  while inp ~= nil do
    replInp(write, st, inp)
    inp = io.read()
  end
end

function onSocketError(err)
  renoise.app():show_status('Z: ' .. tostring(err))
end

function onSocketAccepted(sst)
  return function(socket)
    local ix = socket.peer_port
    renoise.app():show_status('Z: Connnected ' .. tostring(ix))
    local write = function(data)
      socket:send(data)
    end
    local st = mkReplState(write, { renoise = renoise })
    local conn = { write = write, st = st }
    sst.conns[ix] = conn
  end
end

function onSocketMessage(sst)
  return function(socket, inp)
    local ix = socket.peer_port
    local conn = sst.conns[ix]
    if conn == nil then
      renoise.app():show_status('Z: Zombie ' .. tostring(ix))
      return
    else
      -- Recv EOF to request disconnect
      local isEof = inp:sub(-1) == '\04'
      if isEof then
        -- TODO figure this out - close ruins the socket
        -- sst.conns[ix] = nil
        -- socket:close()
        -- renoise.app():show_status('Z: Disconnected ' .. tostring(ix))
      else
        replInp(conn.write, conn.st, inp)
      end
    end
  end
end

function onUnload(sst)
  return function()
    if sst.server ~= nil then
      renoise.app():show_status('Z: Shutting down server')
      sst.server:stop()
      sst.server:close()
      sst.server = nil
    end
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

    local sst = { server = nil, conns = {} }
    renoise.tool().tool_will_unload_observable:add_notifier(onUnload(sst))

    local server, err = renoise.Socket.create_server(prefs.hostname.value, prefs.port.value)

    if err then
      renoise.app():show_warning('Z: ' .. tostring(err))
    else
      sst.server = server
      local serverConf = {
        socket_error = onSocketError,
        socket_accepted = onSocketAccepted(sst),
        socket_message = onSocketMessage(sst),
      }
      renoise.app():show_status('Z: Starting server')
      sst.server:run(serverConf)
    end
  end
end

main()
