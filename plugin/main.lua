local repl = require('repl')

function renoiseStatus(msg)
  renoise.app():show_status('Z: ' .. msg)
end

function renoiseWarning(msg)
  renoise.app():show_warning('Z: ' .. msg)
end

function onSocketError(err)
  renoiseStatus(tostring(err))
end

function onSocketAccepted(sst)
  return function(socket)
    local ix = socket.peer_port
    renoiseStatus('Connnected ' .. tostring(ix))
    local write = function(data)
      socket:send(data)
    end
    local st = repl.mkState(write, { renoise = renoise })
    local conn = { write = write, st = st }
    sst.conns[ix] = conn
    repl.onStart(write)
  end
end

function onSocketMessage(sst)
  return function(socket, inp)
    local ix = socket.peer_port
    local conn = sst.conns[ix]
    if conn == nil then
      renoiseStatus('Zombie ' .. tostring(ix))
      return
    else
      repl.onInput(conn.write, conn.st, inp)
    end
  end
end

function onUnload(sst)
  return function()
    if sst.server ~= nil then
      renoiseStatus('Shutting down server')
      sst.server:stop()
      sst.server:close()
      sst.server = nil
    end
  end
end

function main()
  if _G.renoise == nil then
    -- Just a regular repl - note that renoisey things will not work
    repl.run { renoise = nil }
  else
    local prefs = renoise.tool().preferences
    if prefs == nil then
      prefs = renoise.Document.create('preferences') {
        hostname = '0.0.0.0',
        port = 9876
      }
      renoise.tool().preferences = prefs
    end

    local sst = { server = nil, conns = {} }
    renoise.tool().tool_will_unload_observable:add_notifier(onUnload(sst))

    local server, err = renoise.Socket.create_server(prefs.hostname.value, prefs.port.value)

    if err then
      renoiseWarning(tostring(err))
    else
      sst.server = server
      local serverConf = {
        socket_error = onSocketError,
        socket_accepted = onSocketAccepted(sst),
        socket_message = onSocketMessage(sst),
      }
      renoiseStatus('Starting server')
      sst.server:run(serverConf)
    end
  end
end

main()
