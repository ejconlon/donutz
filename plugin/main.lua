local repl = require('fennel.repl')
local compiler = require('fennel.compiler')
local specials = require('fennel.specials')

function readChunk(write, flush, read)
  return function(ps)
    local prompt
    if ps['stack-size'] == 0 then prompt = '> ' else prompt '. ' end
    write(prompt)
    flush()
    local input = read()
    if input then input = input .. '\n' end
    return input
  end
end

function onValues(write)
  return function(xs)
    write(table.concat(xs, '\t'))
    write('\n')
  end
end

function onError(write)
  return function(xs)
    write(table.concat(xs, '\t'))
    write('\n')
  end
end

function onError(write)
  return function(errtype, err, luaSource)
    local message
    if errtype == 'Lua Compile' then
      message = 
        'Bad code generated - likely a bug with the compiler:\n' ..
        '--- Generated Lua Start ---\n' ..
        luaSource .. '\n' ..
        '--- Generated Lua End ---\n'
    elseif message == 'Runtime' then
      message = compiler.traceback(tostring(err), 4) .. '\n'
    else
      message = string.format('%s error: %s\n', errtype, tostring(err))
    end
    write(message)
  end
end

function mkEnv()
  return specials['wrap-env'] { _G = _G, renoise = _G.renoise }
end

function main()
  if _G.renoise == nil then
    -- Just a regular repl - note that renoisey things will not work
    opts = {
      readChunk = readChunk(io.write, io.flush, io.read),
      onValues = onValues(io.write),
      onError = onError(io.write),
      env = mkEnv() ,
    }
    repl(opts)
  else
    -- TODO Allow host/port to be configurable
    server, err = renoise.Socket.create_server('0.0.0.0', 2020)
    if err then
      renoise.app():show_warning('Z: ' .. socket_error)
      return
    else
      renoise.tool().tool_will_unload_observable:add_notifier(function ()
        renoise.app():show_status('Z: Shutting down server')
        server:close()
      end)
      server:run {
        socket_error = function(errorMsg)
          renoise.app():show_status('Z: ' .. errorMsg)
        end,
        socket_accepted = function(socket)
          print('TODO')
        end,
        socket_message = function(socket, message)
          print('TODO')
        end,
      }
    end
  end
end

main()
