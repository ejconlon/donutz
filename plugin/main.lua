local repl = require('fennel')

-- TODO read values from socket
function readChunk(ps)
  local prompt
  if ps['stack-size'] == 0 then prompt = '> ' else prompt '. ' end
  io.write(prompt)
  io.flush()
  local input = io.read()
  if input then input = input .. '\n' end
  return input
end

function main()
  repl.repl {
    ['readChunk'] = readChunk,
    -- ['onValues'] = onValues, -- TODO write values to socket, see default-on-values
    -- ['onError'] = onError, -- TODO write errors to socket, see default-on-error
    -- ['env'] = env, -- TODO add renoise to env
  }  
end

main()
