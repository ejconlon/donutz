local utils = require("fennel.utils")
local parser = require("fennel.parser")
local compiler = require("fennel.compiler")
local specials = require("fennel.specials")
local view = require("fennel.view")
local unpack = (table.unpack or _G.unpack)
local depth = 0
local function prompt_for(top_3f)
  if top_3f then
    return (string.rep(">", (depth + 1)) .. " ")
  else
    return (string.rep(".", (depth + 1)) .. " ")
  end
end
local function default_read_chunk(parser_state)
  io.write(prompt_for((0 == parser_state["stack-size"])))
  io.flush()
  local input = io.read()
  return (input and (input .. "\n"))
end
local function default_on_values(xs)
  io.write(table.concat(xs, "\9"))
  return io.write("\n")
end
local function default_on_error(errtype, err, lua_source)
  local function _2_()
    if (errtype == "Lua Compile") then
      return ("Bad code generated - likely a bug with the compiler:\n" .. "--- Generated Lua Start ---\n" .. lua_source .. "--- Generated Lua End ---\n")
    elseif (errtype == "Runtime") then
      return (compiler.traceback(tostring(err), 4) .. "\n")
    elseif true then
      local _ = errtype
      return ("%s error: %s\n"):format(errtype, tostring(err))
    else
      return nil
    end
  end
  return io.write(_2_())
end
local function splice_save_locals(env, lua_source, scope)
  local saves
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for name in pairs(env.___replLocals___) do
      local val_19_auto = ("local %s = ___replLocals___[%q]"):format((scope.manglings[name] or name), name)
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    saves = tbl_17_auto
  end
  local binds
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for raw, name in pairs(scope.manglings) do
      local val_19_auto
      if not scope.gensyms[name] then
        val_19_auto = ("___replLocals___[%q] = %s"):format(raw, name)
      else
        val_19_auto = nil
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    binds = tbl_17_auto
  end
  local gap
  if lua_source:find("\n") then
    gap = "\n"
  else
    gap = " "
  end
  local function _7_()
    if next(saves) then
      return (table.concat(saves, " ") .. gap)
    else
      return ""
    end
  end
  local function _10_()
    local _8_, _9_ = lua_source:match("^(.*)[\n ](return .*)$")
    if ((nil ~= _8_) and (nil ~= _9_)) then
      local body = _8_
      local _return = _9_
      return (body .. gap .. table.concat(binds, " ") .. gap .. _return)
    elseif true then
      local _ = _8_
      return lua_source
    else
      return nil
    end
  end
  return (_7_() .. _10_())
end
local function completer(env, scope, text)
  local max_items = 2000
  local seen = {}
  local matches = {}
  local input_fragment = text:gsub(".*[%s)(]+", "")
  local stop_looking_3f = false
  local function add_partials(input, tbl, prefix)
    local scope_first_3f = ((tbl == env) or (tbl == env.___replLocals___))
    local tbl_17_auto = matches
    local i_18_auto = #tbl_17_auto
    local function _12_()
      if scope_first_3f then
        return scope.manglings
      else
        return tbl
      end
    end
    for k, is_mangled in utils.allpairs(_12_()) do
      if (max_items <= #matches) then break end
      local val_19_auto
      do
        local lookup_k
        if scope_first_3f then
          lookup_k = is_mangled
        else
          lookup_k = k
        end
        if ((type(k) == "string") and (input == k:sub(0, #input)) and not seen[k] and ((":" ~= prefix:sub(-1)) or ("function" == type(tbl[lookup_k])))) then
          seen[k] = true
          val_19_auto = (prefix .. k)
        else
          val_19_auto = nil
        end
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    return tbl_17_auto
  end
  local function descend(input, tbl, prefix, add_matches, method_3f)
    local splitter
    if method_3f then
      splitter = "^([^:]+):(.*)"
    else
      splitter = "^([^.]+)%.(.*)"
    end
    local head, tail = input:match(splitter)
    local raw_head = (scope.manglings[head] or head)
    if (type(tbl[raw_head]) == "table") then
      stop_looking_3f = true
      if method_3f then
        return add_partials(tail, tbl[raw_head], (prefix .. head .. ":"))
      else
        return add_matches(tail, tbl[raw_head], (prefix .. head))
      end
    else
      return nil
    end
  end
  local function add_matches(input, tbl, prefix)
    local prefix0
    if prefix then
      prefix0 = (prefix .. ".")
    else
      prefix0 = ""
    end
    if (not input:find("%.") and input:find(":")) then
      return descend(input, tbl, prefix0, add_matches, true)
    elseif not input:find("%.") then
      return add_partials(input, tbl, prefix0)
    else
      return descend(input, tbl, prefix0, add_matches, false)
    end
  end
  for _, source in ipairs({scope.specials, scope.macros, (env.___replLocals___ or {}), env, env._G}) do
    if stop_looking_3f then break end
    add_matches(input_fragment, source)
  end
  return matches
end
local commands = {}
local function command_3f(input)
  return input:match("^%s*,")
end
local function command_docs()
  local _21_
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for name, f in pairs(commands) do
      local val_19_auto = ("  ,%s - %s"):format(name, ((compiler.metadata):get(f, "fnl/docstring") or "undocumented"))
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    _21_ = tbl_17_auto
  end
  return table.concat(_21_, "\n")
end
commands.help = function(_, _0, on_values)
  return on_values({("Welcome to Fennel.\nThis is the REPL where you can enter code to be evaluated.\nYou can also run these repl commands:\n\n" .. command_docs() .. "\n  ,return FORM - Evaluate FORM and return its value to the REPL's caller.\n  ,exit - Leave the repl.\n\nUse ,doc something to see descriptions for individual macros and special forms.\nValues from previous inputs are kept in *1, *2, and *3.\n\nFor more information about the language, see https://fennel-lang.org/reference")})
end
do end (compiler.metadata):set(commands.help, "fnl/docstring", "Show this message.")
local function reload(module_name, env, on_values, on_error)
  local _23_, _24_ = pcall(specials["load-code"]("return require(...)", env), module_name)
  if ((_23_ == true) and (nil ~= _24_)) then
    local old = _24_
    local _
    package.loaded[module_name] = nil
    _ = nil
    local ok, new = pcall(require, module_name)
    local new0
    if not ok then
      on_values({new})
      new0 = old
    else
      new0 = new
    end
    specials["macro-loaded"][module_name] = nil
    if ((type(old) == "table") and (type(new0) == "table")) then
      for k, v in pairs(new0) do
        old[k] = v
      end
      for k in pairs(old) do
        if (nil == (new0)[k]) then
          old[k] = nil
        else
        end
      end
      package.loaded[module_name] = old
    else
    end
    return on_values({"ok"})
  elseif ((_23_ == false) and (nil ~= _24_)) then
    local msg = _24_
    if msg:match("loop or previous error loading module") then
      package.loaded[module_name] = nil
      return reload(module_name, env, on_values, on_error)
    elseif (specials["macro-loaded"])[module_name] then
      specials["macro-loaded"][module_name] = nil
      return nil
    else
      local function _29_()
        local _28_ = msg:gsub("\n.*", "")
        return _28_
      end
      return on_error("Runtime", _29_())
    end
  else
    return nil
  end
end
local function run_command(read, on_error, f)
  local _32_, _33_, _34_ = pcall(read)
  if ((_32_ == true) and (_33_ == true) and (nil ~= _34_)) then
    local val = _34_
    local _35_, _36_ = pcall(f, val)
    if ((_35_ == false) and (nil ~= _36_)) then
      local msg = _36_
      return on_error("Runtime", msg)
    else
      return nil
    end
  elseif (_32_ == false) then
    return on_error("Parse", "Couldn't parse input.")
  else
    return nil
  end
end
commands.reload = function(env, read, on_values, on_error)
  local function _39_(_241)
    return reload(tostring(_241), env, on_values, on_error)
  end
  return run_command(read, on_error, _39_)
end
do end (compiler.metadata):set(commands.reload, "fnl/docstring", "Reload the specified module.")
commands.reset = function(env, _, on_values)
  env.___replLocals___ = {}
  return on_values({"ok"})
end
do end (compiler.metadata):set(commands.reset, "fnl/docstring", "Erase all repl-local scope.")
commands.complete = function(env, read, on_values, on_error, scope, chars)
  local function _40_()
    return on_values(completer(env, scope, table.concat(chars):gsub(",complete +", ""):sub(1, -2)))
  end
  return run_command(read, on_error, _40_)
end
do end (compiler.metadata):set(commands.complete, "fnl/docstring", "Print all possible completions for a given input symbol.")
local function apropos_2a(pattern, tbl, prefix, seen, names)
  for name, subtbl in pairs(tbl) do
    if (("string" == type(name)) and (package ~= subtbl)) then
      local _41_ = type(subtbl)
      if (_41_ == "function") then
        if ((prefix .. name)):match(pattern) then
          table.insert(names, (prefix .. name))
        else
        end
      elseif (_41_ == "table") then
        if not seen[subtbl] then
          local _43_
          do
            seen[subtbl] = true
            _43_ = seen
          end
          apropos_2a(pattern, subtbl, (prefix .. name:gsub("%.", "/") .. "."), _43_, names)
        else
        end
      else
      end
    else
    end
  end
  return names
end
local function apropos(pattern)
  local names = apropos_2a(pattern, package.loaded, "", {}, {})
  local tbl_17_auto = {}
  local i_18_auto = #tbl_17_auto
  for _, name in ipairs(names) do
    local val_19_auto = name:gsub("^_G%.", "")
    if (nil ~= val_19_auto) then
      i_18_auto = (i_18_auto + 1)
      do end (tbl_17_auto)[i_18_auto] = val_19_auto
    else
    end
  end
  return tbl_17_auto
end
commands.apropos = function(_env, read, on_values, on_error, _scope)
  local function _48_(_241)
    return on_values(apropos(tostring(_241)))
  end
  return run_command(read, on_error, _48_)
end
do end (compiler.metadata):set(commands.apropos, "fnl/docstring", "Print all functions matching a pattern in all loaded modules.")
local function apropos_follow_path(path)
  local paths
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for p in path:gmatch("[^%.]+") do
      local val_19_auto = p
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    paths = tbl_17_auto
  end
  local tgt = package.loaded
  for _, path0 in ipairs(paths) do
    if (nil == tgt) then break end
    local _51_
    do
      local _50_ = path0:gsub("%/", ".")
      _51_ = _50_
    end
    tgt = tgt[_51_]
  end
  return tgt
end
local function apropos_doc(pattern)
  local tbl_17_auto = {}
  local i_18_auto = #tbl_17_auto
  for _, path in ipairs(apropos(".*")) do
    local val_19_auto
    do
      local tgt = apropos_follow_path(path)
      if ("function" == type(tgt)) then
        local _52_ = (compiler.metadata):get(tgt, "fnl/docstring")
        if (nil ~= _52_) then
          local docstr = _52_
          val_19_auto = (docstr:match(pattern) and path)
        else
          val_19_auto = nil
        end
      else
        val_19_auto = nil
      end
    end
    if (nil ~= val_19_auto) then
      i_18_auto = (i_18_auto + 1)
      do end (tbl_17_auto)[i_18_auto] = val_19_auto
    else
    end
  end
  return tbl_17_auto
end
commands["apropos-doc"] = function(_env, read, on_values, on_error, _scope)
  local function _56_(_241)
    return on_values(apropos_doc(tostring(_241)))
  end
  return run_command(read, on_error, _56_)
end
do end (compiler.metadata):set(commands["apropos-doc"], "fnl/docstring", "Print all functions that match the pattern in their docs")
local function apropos_show_docs(on_values, pattern)
  for _, path in ipairs(apropos(pattern)) do
    local tgt = apropos_follow_path(path)
    if (("function" == type(tgt)) and (compiler.metadata):get(tgt, "fnl/docstring")) then
      on_values({specials.doc(tgt, path)})
      on_values({})
    else
    end
  end
  return nil
end
commands["apropos-show-docs"] = function(_env, read, on_values, on_error)
  local function _58_(_241)
    return apropos_show_docs(on_values, tostring(_241))
  end
  return run_command(read, on_error, _58_)
end
do end (compiler.metadata):set(commands["apropos-show-docs"], "fnl/docstring", "Print all documentations matching a pattern in function name")
local function resolve(identifier, _59_, scope)
  local _arg_60_ = _59_
  local ___replLocals___ = _arg_60_["___replLocals___"]
  local env = _arg_60_
  local e
  local function _61_(_241, _242)
    return (___replLocals___[scope.unmanglings[_242]] or env[_242])
  end
  e = setmetatable({}, {__index = _61_})
  local function _62_(...)
    local _63_, _64_ = ...
    if ((_63_ == true) and (nil ~= _64_)) then
      local code = _64_
      local function _65_(...)
        local _66_, _67_ = ...
        if ((_66_ == true) and (nil ~= _67_)) then
          local val = _67_
          return val
        elseif true then
          local _ = _66_
          return nil
        else
          return nil
        end
      end
      return _65_(pcall(specials["load-code"](code, e)))
    elseif true then
      local _ = _63_
      return nil
    else
      return nil
    end
  end
  return _62_(pcall(compiler["compile-string"], tostring(identifier), {scope = scope}))
end
commands.find = function(env, read, on_values, on_error, scope)
  local function _70_(_241)
    local _71_
    do
      local _72_ = utils["sym?"](_241)
      if (nil ~= _72_) then
        local _73_ = resolve(_72_, env, scope)
        if (nil ~= _73_) then
          _71_ = debug.getinfo(_73_)
        else
          _71_ = _73_
        end
      else
        _71_ = _72_
      end
    end
    if ((_G.type(_71_) == "table") and ((_71_).what == "Lua") and (nil ~= (_71_).source) and (nil ~= (_71_).linedefined) and (nil ~= (_71_).short_src)) then
      local source = (_71_).source
      local line = (_71_).linedefined
      local src = (_71_).short_src
      local fnlsrc
      do
        local t_76_ = compiler.sourcemap
        if (nil ~= t_76_) then
          t_76_ = (t_76_)[source]
        else
        end
        if (nil ~= t_76_) then
          t_76_ = (t_76_)[line]
        else
        end
        if (nil ~= t_76_) then
          t_76_ = (t_76_)[2]
        else
        end
        fnlsrc = t_76_
      end
      return on_values({string.format("%s:%s", src, (fnlsrc or line))})
    elseif (_71_ == nil) then
      return on_error("Repl", "Unknown value")
    elseif true then
      local _ = _71_
      return on_error("Repl", "No source info")
    else
      return nil
    end
  end
  return run_command(read, on_error, _70_)
end
do end (compiler.metadata):set(commands.find, "fnl/docstring", "Print the filename and line number for a given function")
commands.doc = function(env, read, on_values, on_error, scope)
  local function _81_(_241)
    local name = tostring(_241)
    local path = (utils["multi-sym?"](name) or {name})
    local ok_3f, target = nil, nil
    local function _82_()
      return (utils["get-in"](scope.specials, path) or utils["get-in"](scope.macros, path) or resolve(name, env, scope))
    end
    ok_3f, target = pcall(_82_)
    if ok_3f then
      return on_values({specials.doc(target, name)})
    else
      return on_error("Repl", ("Could not find " .. name .. " for docs."))
    end
  end
  return run_command(read, on_error, _81_)
end
do end (compiler.metadata):set(commands.doc, "fnl/docstring", "Print the docstring and arglist for a function, macro, or special form.")
commands.compile = function(env, read, on_values, on_error, scope)
  local function _84_(_241)
    local allowedGlobals = specials["current-global-names"](env)
    local ok_3f, result = pcall(compiler.compile, _241, {env = env, scope = scope, allowedGlobals = allowedGlobals})
    if ok_3f then
      return on_values({result})
    else
      return on_error("Repl", ("Error compiling expression: " .. result))
    end
  end
  return run_command(read, on_error, _84_)
end
do end (compiler.metadata):set(commands.compile, "fnl/docstring", "compiles the expression into lua and prints the result.")
local function load_plugin_commands(plugins)
  for i = #(plugins or {}), 1, -1 do
    for name, f in pairs(plugins[i]) do
      local _86_ = name:match("^repl%-command%-(.*)")
      if (nil ~= _86_) then
        local cmd_name = _86_
        commands[cmd_name] = f
      else
      end
    end
  end
  return nil
end
local function run_command_loop(input, read, loop, env, on_values, on_error, scope, chars)
  local command_name = input:match(",([^%s/]+)")
  do
    local _88_ = commands[command_name]
    if (nil ~= _88_) then
      local command = _88_
      command(env, read, on_values, on_error, scope, chars)
    elseif true then
      local _ = _88_
      if ((command_name ~= "exit") and (command_name ~= "return")) then
        on_values({"Unknown command", command_name})
      else
      end
    else
    end
  end
  if ("exit" ~= command_name) then
    return loop((command_name == "return"))
  else
    return nil
  end
end
local function try_readline_21(opts, ok, readline)
  if ok then
    if readline.set_readline_name then
      readline.set_readline_name("fennel")
    else
    end
    readline.set_options({keeplines = 1000, histfile = ""})
    opts.readChunk = function(parser_state)
      local prompt
      if (0 < parser_state["stack-size"]) then
        prompt = ".. "
      else
        prompt = ">> "
      end
      local str = readline.readline(prompt)
      if str then
        return (str .. "\n")
      else
        return nil
      end
    end
    local completer0 = nil
    opts.registerCompleter = function(repl_completer)
      completer0 = repl_completer
      return nil
    end
    local function repl_completer(text, from, to)
      if completer0 then
        readline.set_completion_append_character("")
        return completer0(text:sub(from, to))
      else
        return {}
      end
    end
    readline.set_complete_function(repl_completer)
    return readline
  else
    return nil
  end
end
local function should_use_readline_3f(opts)
  return (("dumb" ~= os.getenv("TERM")) and not opts.readChunk and not opts.registerCompleter)
end
local function repl(_3foptions)
  local old_root_options = utils.root.options
  local _let_97_ = utils.copy(_3foptions)
  local _3ffennelrc = _let_97_["fennelrc"]
  local opts = _let_97_
  local _
  opts.fennelrc = nil
  _ = nil
  local readline = (should_use_readline_3f(opts) and try_readline_21(opts, pcall(require, "readline")))
  local _0
  if _3ffennelrc then
    _0 = _3ffennelrc()
  else
    _0 = nil
  end
  local env = specials["wrap-env"]((opts.env or rawget(_G, "_ENV") or _G))
  local callbacks = {readChunk = (opts.readChunk or default_read_chunk), onValues = (opts.onValues or default_on_values), onError = (opts.onError or default_on_error), pp = (opts.pp or view), env = env}
  local save_locals_3f = (opts.saveLocals ~= false)
  local byte_stream, clear_stream = nil, nil
  local function _99_(_241)
    return callbacks.readChunk(_241)
  end
  byte_stream, clear_stream = parser.granulate(_99_)
  local chars = {}
  local read, reset = nil, nil
  local function _100_(parser_state)
    local b = byte_stream(parser_state)
    if b then
      table.insert(chars, string.char(b))
    else
    end
    return b
  end
  read, reset = parser.parser(_100_)
  depth = (depth + 1)
  if opts.message then
    callbacks.onValues({opts.message})
  else
  end
  env.___repl___ = callbacks
  opts.env, opts.scope = env, compiler["make-scope"]()
  opts.useMetadata = (opts.useMetadata ~= false)
  if (opts.allowedGlobals == nil) then
    opts.allowedGlobals = specials["current-global-names"](env)
  else
  end
  if opts.registerCompleter then
    local function _105_()
      local _104_ = opts.scope
      local function _106_(...)
        return completer(env, _104_, ...)
      end
      return _106_
    end
    opts.registerCompleter(_105_())
  else
  end
  load_plugin_commands(opts.plugins)
  if save_locals_3f then
    local function newindex(t, k, v)
      if opts.scope.manglings[k] then
        return rawset(t, k, v)
      else
        return nil
      end
    end
    env.___replLocals___ = setmetatable({}, {__newindex = newindex})
  else
  end
  local function print_values(...)
    local vals = {...}
    local out = {}
    local pp = callbacks.pp
    env._, env.__ = vals[1], vals
    for i = 1, select("#", ...) do
      table.insert(out, pp(vals[i]))
    end
    return callbacks.onValues(out)
  end
  local function save_value(...)
    env.___replLocals___["*3"] = env.___replLocals___["*2"]
    env.___replLocals___["*2"] = env.___replLocals___["*1"]
    env.___replLocals___["*1"] = ...
    return ...
  end
  opts.scope.manglings["*1"], opts.scope.unmanglings._1 = "_1", "*1"
  opts.scope.manglings["*2"], opts.scope.unmanglings._2 = "_2", "*2"
  opts.scope.manglings["*3"], opts.scope.unmanglings._3 = "_3", "*3"
  local function loop(exit_next_3f)
    for k in pairs(chars) do
      chars[k] = nil
    end
    reset()
    local ok, parser_not_eof_3f, form = pcall(read)
    local src_string = table.concat(chars)
    local readline_not_eof_3f = (not readline or (src_string ~= "(null)"))
    local not_eof_3f = (readline_not_eof_3f and parser_not_eof_3f)
    if not ok then
      callbacks.onError("Parse", not_eof_3f)
      clear_stream()
      return loop()
    elseif command_3f(src_string) then
      return run_command_loop(src_string, read, loop, env, callbacks.onValues, callbacks.onError, opts.scope, chars)
    else
      if not_eof_3f then
        local function _110_(...)
          local _111_, _112_ = ...
          if ((_111_ == true) and (nil ~= _112_)) then
            local src = _112_
            local function _113_(...)
              local _114_, _115_ = ...
              if ((_114_ == true) and (nil ~= _115_)) then
                local chunk = _115_
                local function _116_()
                  return print_values(save_value(chunk()))
                end
                local function _117_(...)
                  return callbacks.onError("Runtime", ...)
                end
                return xpcall(_116_, _117_)
              elseif ((_114_ == false) and (nil ~= _115_)) then
                local msg = _115_
                clear_stream()
                return callbacks.onError("Compile", msg)
              else
                return nil
              end
            end
            local function _120_(...)
              local src0
              if save_locals_3f then
                src0 = splice_save_locals(env, src, opts.scope)
              else
                src0 = src
              end
              return pcall(specials["load-code"], src0, env)
            end
            return _113_(_120_(...))
          elseif ((_111_ == false) and (nil ~= _112_)) then
            local msg = _112_
            clear_stream()
            return callbacks.onError("Compile", msg)
          else
            return nil
          end
        end
        local function _122_()
          opts["source"] = src_string
          return opts
        end
        _110_(pcall(compiler.compile, form, _122_()))
        utils.root.options = old_root_options
        if exit_next_3f then
          return env.___replLocals___["*1"]
        else
          return loop()
        end
      else
        return nil
      end
    end
  end
  local value = loop()
  depth = (depth - 1)
  if readline then
    readline.save_history()
  else
  end
  return value
end
return repl
