local utils = require("fennel.utils")
local parser = require("fennel.parser")
local friend = require("fennel.friend")
local unpack = (table.unpack or _G.unpack)
local scopes = {}
local function make_scope(_3fparent)
  local parent = (_3fparent or scopes.global)
  local _1_
  if parent then
    _1_ = ((parent.depth or 0) + 1)
  else
    _1_ = 0
  end
  return {includes = setmetatable({}, {__index = (parent and parent.includes)}), macros = setmetatable({}, {__index = (parent and parent.macros)}), manglings = setmetatable({}, {__index = (parent and parent.manglings)}), specials = setmetatable({}, {__index = (parent and parent.specials)}), symmeta = setmetatable({}, {__index = (parent and parent.symmeta)}), ["gensym-base"] = setmetatable({}, {__index = (parent and parent["gensym-base"])}), unmanglings = setmetatable({}, {__index = (parent and parent.unmanglings)}), gensyms = setmetatable({}, {__index = (parent and parent.gensyms)}), autogensyms = setmetatable({}, {__index = (parent and parent.autogensyms)}), vararg = (parent and parent.vararg), depth = _1_, hashfn = (parent and parent.hashfn), refedglobals = {}, parent = parent}
end
local function assert_msg(ast, msg)
  local ast_tbl
  if ("table" == type(ast)) then
    ast_tbl = ast
  else
    ast_tbl = {}
  end
  local m = getmetatable(ast)
  local filename = ((m and m.filename) or ast_tbl.filename or "unknown")
  local line = ((m and m.line) or ast_tbl.line or "?")
  local col = ((m and m.col) or ast_tbl.col or "?")
  local target = tostring((utils["sym?"](ast_tbl[1]) or ast_tbl[1] or "()"))
  return string.format("%s:%s:%s Compile error in '%s': %s", filename, line, col, target, msg)
end
local function assert_compile(condition, msg, ast, _3ffallback_ast)
  if not condition then
    local _let_4_ = (utils.root.options or {})
    local source = _let_4_["source"]
    local unfriendly = _let_4_["unfriendly"]
    local error_pinpoint = _let_4_["error-pinpoint"]
    local ast0
    if next(utils["ast-source"](ast)) then
      ast0 = ast
    else
      ast0 = (_3ffallback_ast or {})
    end
    if (nil == utils.hook("assert-compile", condition, msg, ast0, utils.root.reset)) then
      utils.root.reset()
      if unfriendly then
        error(assert_msg(ast0, msg), 0)
      else
        friend["assert-compile"](condition, msg, ast0, source, {["error-pinpoint"] = error_pinpoint})
      end
    else
    end
  else
  end
  return condition
end
scopes.global = make_scope()
scopes.global.vararg = true
scopes.compiler = make_scope(scopes.global)
scopes.macro = scopes.global
local serialize_subst = {["\7"] = "\\a", ["\8"] = "\\b", ["\9"] = "\\t", ["\n"] = "n", ["\11"] = "\\v", ["\12"] = "\\f"}
local function serialize_string(str)
  local function _9_(_241)
    return ("\\" .. _241:byte())
  end
  return string.gsub(string.gsub(string.format("%q", str), ".", serialize_subst), "[\128-\255]", _9_)
end
local function global_mangling(str)
  if utils["valid-lua-identifier?"](str) then
    return str
  else
    local function _10_(_241)
      return string.format("_%02x", _241:byte())
    end
    return ("__fnl_global__" .. str:gsub("[^%w]", _10_))
  end
end
local function global_unmangling(identifier)
  local _12_ = string.match(identifier, "^__fnl_global__(.*)$")
  if (nil ~= _12_) then
    local rest = _12_
    local _13_
    local function _14_(_241)
      return string.char(tonumber(_241:sub(2), 16))
    end
    _13_ = string.gsub(rest, "_[%da-f][%da-f]", _14_)
    return _13_
  elseif true then
    local _ = _12_
    return identifier
  else
    return nil
  end
end
local allowed_globals = nil
local function global_allowed_3f(name)
  return (not allowed_globals or utils["member?"](name, allowed_globals))
end
local function unique_mangling(original, mangling, scope, append)
  if scope.unmanglings[mangling] then
    return unique_mangling(original, (original .. append), scope, (append + 1))
  else
    return mangling
  end
end
local function local_mangling(str, scope, ast, _3ftemp_manglings)
  assert_compile(not utils["multi-sym?"](str), ("unexpected multi symbol " .. str), ast)
  local raw
  if ((utils["lua-keywords"])[str] or str:match("^%d")) then
    raw = ("_" .. str)
  else
    raw = str
  end
  local mangling
  local function _18_(_241)
    return string.format("_%02x", _241:byte())
  end
  mangling = string.gsub(string.gsub(raw, "-", "_"), "[^%w_]", _18_)
  local unique = unique_mangling(mangling, mangling, scope, 0)
  do end (scope.unmanglings)[unique] = ((scope["gensym-base"])[str] or str)
  do
    local manglings = (_3ftemp_manglings or scope.manglings)
    do end (manglings)[str] = unique
  end
  return unique
end
local function apply_manglings(scope, new_manglings, ast)
  for raw, mangled in pairs(new_manglings) do
    assert_compile(not scope.refedglobals[mangled], ("use of global " .. raw .. " is aliased by a local"), ast)
    do end (scope.manglings)[raw] = mangled
  end
  return nil
end
local function combine_parts(parts, scope)
  local ret = (scope.manglings[parts[1]] or global_mangling(parts[1]))
  for i = 2, #parts do
    if utils["valid-lua-identifier?"](parts[i]) then
      if (parts["multi-sym-method-call"] and (i == #parts)) then
        ret = (ret .. ":" .. parts[i])
      else
        ret = (ret .. "." .. parts[i])
      end
    else
      ret = (ret .. "[" .. serialize_string(parts[i]) .. "]")
    end
  end
  return ret
end
local function next_append()
  utils.root.scope["gensym-append"] = ((utils.root.scope["gensym-append"] or 0) + 1)
  return ("_" .. utils.root.scope["gensym-append"] .. "_")
end
local function gensym(scope, _3fbase, _3fsuffix)
  local mangling = ((_3fbase or "") .. next_append() .. (_3fsuffix or ""))
  while scope.unmanglings[mangling] do
    mangling = ((_3fbase or "") .. next_append() .. (_3fsuffix or ""))
  end
  if (_3fbase and (0 < #_3fbase)) then
    scope["gensym-base"][mangling] = _3fbase
  else
  end
  scope.gensyms[mangling] = true
  return mangling
end
local function combine_auto_gensym(parts, first)
  parts[1] = first
  local last = table.remove(parts)
  local last2 = table.remove(parts)
  local last_joiner = ((parts["multi-sym-method-call"] and ":") or ".")
  table.insert(parts, (last2 .. last_joiner .. last))
  return table.concat(parts, ".")
end
local function autogensym(base, scope)
  local _22_ = utils["multi-sym?"](base)
  if (nil ~= _22_) then
    local parts = _22_
    return combine_auto_gensym(parts, autogensym(parts[1], scope))
  elseif true then
    local _ = _22_
    local function _23_()
      local mangling = gensym(scope, base:sub(1, ( - 2)), "auto")
      do end (scope.autogensyms)[base] = mangling
      return mangling
    end
    return (scope.autogensyms[base] or _23_())
  else
    return nil
  end
end
local function check_binding_valid(symbol, scope, ast, _3fopts)
  local name = tostring(symbol)
  local macro_3f
  do
    local t_25_ = _3fopts
    if (nil ~= t_25_) then
      t_25_ = (t_25_)["macro?"]
    else
    end
    macro_3f = t_25_
  end
  assert_compile(not name:find("&"), "invalid character: &", symbol)
  assert_compile(not name:find("^%."), "invalid character: .", symbol)
  assert_compile(not (scope.specials[name] or (not macro_3f and scope.macros[name])), ("local %s was overshadowed by a special form or macro"):format(name), ast)
  return assert_compile(not utils["quoted?"](symbol), string.format("macro tried to bind %s without gensym", name), symbol)
end
local function declare_local(symbol, meta, scope, ast, _3ftemp_manglings)
  check_binding_valid(symbol, scope, ast)
  local name = tostring(symbol)
  assert_compile(not utils["multi-sym?"](name), ("unexpected multi symbol " .. name), ast)
  do end (scope.symmeta)[name] = meta
  return local_mangling(name, scope, ast, _3ftemp_manglings)
end
local function hashfn_arg_name(name, multi_sym_parts, scope)
  if not scope.hashfn then
    return nil
  elseif (name == "$") then
    return "$1"
  elseif multi_sym_parts then
    if (multi_sym_parts and (multi_sym_parts[1] == "$")) then
      multi_sym_parts[1] = "$1"
    else
    end
    return table.concat(multi_sym_parts, ".")
  else
    return nil
  end
end
local function symbol_to_expression(symbol, scope, _3freference_3f)
  utils.hook("symbol-to-expression", symbol, scope, _3freference_3f)
  local name = symbol[1]
  local multi_sym_parts = utils["multi-sym?"](name)
  local name0 = (hashfn_arg_name(name, multi_sym_parts, scope) or name)
  local parts = (multi_sym_parts or {name0})
  local etype = (((1 < #parts) and "expression") or "sym")
  local local_3f = scope.manglings[parts[1]]
  if (local_3f and scope.symmeta[parts[1]]) then
    scope.symmeta[parts[1]]["used"] = true
  else
  end
  assert_compile(not scope.macros[parts[1]], "tried to reference a macro without calling it", symbol)
  assert_compile((not scope.specials[parts[1]] or ("require" == parts[1])), "tried to reference a special form without calling it", symbol)
  assert_compile((not _3freference_3f or local_3f or ("_ENV" == parts[1]) or global_allowed_3f(parts[1])), ("unknown identifier: " .. tostring(parts[1])), symbol)
  if (allowed_globals and not local_3f and scope.parent) then
    scope.parent.refedglobals[parts[1]] = true
  else
  end
  return utils.expr(combine_parts(parts, scope), etype)
end
local function emit(chunk, out, _3fast)
  if (type(out) == "table") then
    return table.insert(chunk, out)
  else
    return table.insert(chunk, {ast = _3fast, leaf = out})
  end
end
local function peephole(chunk)
  if chunk.leaf then
    return chunk
  elseif ((3 <= #chunk) and (chunk[(#chunk - 2)].leaf == "do") and not chunk[(#chunk - 1)].leaf and (chunk[#chunk].leaf == "end")) then
    local kid = peephole(chunk[(#chunk - 1)])
    local new_chunk = {ast = chunk.ast}
    for i = 1, (#chunk - 3) do
      table.insert(new_chunk, peephole(chunk[i]))
    end
    for i = 1, #kid do
      table.insert(new_chunk, kid[i])
    end
    return new_chunk
  else
    return utils.map(chunk, peephole)
  end
end
local function flatten_chunk_correlated(main_chunk, options)
  local function flatten(chunk, out, last_line, file)
    local last_line0 = last_line
    if chunk.leaf then
      out[last_line0] = ((out[last_line0] or "") .. " " .. chunk.leaf)
    else
      for _, subchunk in ipairs(chunk) do
        if (subchunk.leaf or (0 < #subchunk)) then
          local source = utils["ast-source"](subchunk.ast)
          if (file == source.filename) then
            last_line0 = math.max(last_line0, (source.line or 0))
          else
          end
          last_line0 = flatten(subchunk, out, last_line0, file)
        else
        end
      end
    end
    return last_line0
  end
  local out = {}
  local last = flatten(main_chunk, out, 1, options.filename)
  for i = 1, last do
    if (out[i] == nil) then
      out[i] = ""
    else
    end
  end
  return table.concat(out, "\n")
end
local function flatten_chunk(file_sourcemap, chunk, tab, depth)
  if chunk.leaf then
    local _let_37_ = utils["ast-source"](chunk.ast)
    local filename = _let_37_["filename"]
    local line = _let_37_["line"]
    table.insert(file_sourcemap, {filename, line})
    return chunk.leaf
  else
    local tab0
    if (tab == true) then
      tab0 = "  "
    elseif (tab == false) then
      tab0 = ""
    elseif (tab == tab) then
      tab0 = tab
    elseif (tab == nil) then
      tab0 = ""
    else
      tab0 = nil
    end
    local function parter(c)
      if (c.leaf or (0 < #c)) then
        local sub = flatten_chunk(file_sourcemap, c, tab0, (depth + 1))
        if (0 < depth) then
          return (tab0 .. sub:gsub("\n", ("\n" .. tab0)))
        else
          return sub
        end
      else
        return nil
      end
    end
    return table.concat(utils.map(chunk, parter), "\n")
  end
end
local sourcemap = {}
local function make_short_src(source)
  local source0 = source:gsub("\n", " ")
  if (#source0 <= 49) then
    return ("[fennel \"" .. source0 .. "\"]")
  else
    return ("[fennel \"" .. source0:sub(1, 46) .. "...\"]")
  end
end
local function flatten(chunk, options)
  local chunk0 = peephole(chunk)
  if options.correlate then
    return flatten_chunk_correlated(chunk0, options), {}
  else
    local file_sourcemap = {}
    local src = flatten_chunk(file_sourcemap, chunk0, options.indent, 0)
    file_sourcemap.short_src = (options.filename or make_short_src((options.source or src)))
    if options.filename then
      file_sourcemap.key = ("@" .. options.filename)
    else
      file_sourcemap.key = src
    end
    sourcemap[file_sourcemap.key] = file_sourcemap
    return src, file_sourcemap
  end
end
local function make_metadata()
  local function _45_(self, tgt, _3fkey)
    if self[tgt] then
      if (nil ~= _3fkey) then
        return self[tgt][_3fkey]
      else
        return self[tgt]
      end
    else
      return nil
    end
  end
  local function _48_(self, tgt, key, value)
    self[tgt] = (self[tgt] or {})
    do end (self[tgt])[key] = value
    return tgt
  end
  local function _49_(self, tgt, ...)
    local kv_len = select("#", ...)
    local kvs = {...}
    if ((kv_len % 2) ~= 0) then
      error("metadata:setall() expected even number of k/v pairs")
    else
    end
    self[tgt] = (self[tgt] or {})
    for i = 1, kv_len, 2 do
      self[tgt][kvs[i]] = kvs[(i + 1)]
    end
    return tgt
  end
  return setmetatable({}, {__index = {get = _45_, set = _48_, setall = _49_}, __mode = "k"})
end
local function exprs1(exprs)
  return table.concat(utils.map(exprs, tostring), ", ")
end
local function keep_side_effects(exprs, chunk, start, ast)
  local start0 = (start or 1)
  for j = start0, #exprs do
    local se = exprs[j]
    if ((se.type == "expression") and (se[1] ~= "nil")) then
      emit(chunk, string.format("do local _ = %s end", tostring(se)), ast)
    elseif (se.type == "statement") then
      local code = tostring(se)
      local disambiguated
      if (code:byte() == 40) then
        disambiguated = ("do end " .. code)
      else
        disambiguated = code
      end
      emit(chunk, disambiguated, ast)
    else
    end
  end
  return nil
end
local function handle_compile_opts(exprs, parent, opts, ast)
  if opts.nval then
    local n = opts.nval
    local len = #exprs
    if (n ~= len) then
      if (n < len) then
        keep_side_effects(exprs, parent, (n + 1), ast)
        for i = (n + 1), len do
          exprs[i] = nil
        end
      else
        for i = (#exprs + 1), n do
          exprs[i] = utils.expr("nil", "literal")
        end
      end
    else
    end
  else
  end
  if opts.tail then
    emit(parent, string.format("return %s", exprs1(exprs)), ast)
  else
  end
  if opts.target then
    local result = exprs1(exprs)
    local function _57_()
      if (result == "") then
        return "nil"
      else
        return result
      end
    end
    emit(parent, string.format("%s = %s", opts.target, _57_()), ast)
  else
  end
  if (opts.tail or opts.target) then
    return {returned = true}
  else
    exprs["returned"] = true
    return exprs
  end
end
local function find_macro(ast, scope)
  local macro_2a
  do
    local _60_ = utils["sym?"](ast[1])
    if (_60_ ~= nil) then
      local _61_ = tostring(_60_)
      if (_61_ ~= nil) then
        macro_2a = scope.macros[_61_]
      else
        macro_2a = _61_
      end
    else
      macro_2a = _60_
    end
  end
  local multi_sym_parts = utils["multi-sym?"](ast[1])
  if (not macro_2a and multi_sym_parts) then
    local nested_macro = utils["get-in"](scope.macros, multi_sym_parts)
    assert_compile((not scope.macros[multi_sym_parts[1]] or (type(nested_macro) == "function")), "macro not found in imported macro module", ast)
    return nested_macro
  else
    return macro_2a
  end
end
local function propagate_trace_info(_65_, _index, node)
  local _arg_66_ = _65_
  local filename = _arg_66_["filename"]
  local line = _arg_66_["line"]
  local bytestart = _arg_66_["bytestart"]
  local byteend = _arg_66_["byteend"]
  do
    local src = utils["ast-source"](node)
    if (("table" == type(node)) and (filename ~= src.filename)) then
      src.filename, src.line, src["from-macro?"] = filename, line, true
      src.bytestart, src.byteend = bytestart, byteend
    else
    end
  end
  return ("table" == type(node))
end
local function quote_literal_nils(index, node, parent)
  if (parent and utils["list?"](parent)) then
    for i = 1, utils.maxn(parent) do
      local _68_ = parent[i]
      if (_68_ == nil) then
        parent[i] = utils.sym("nil")
      else
      end
    end
  else
  end
  return index, node, parent
end
local function comp(f, g)
  local function _71_(...)
    return f(g(...))
  end
  return _71_
end
local function built_in_3f(m)
  local found_3f = false
  for _, f in pairs(scopes.global.macros) do
    if found_3f then break end
    found_3f = (f == m)
  end
  return found_3f
end
local function macroexpand_2a(ast, scope, _3fonce)
  local _72_
  if utils["list?"](ast) then
    _72_ = find_macro(ast, scope)
  else
    _72_ = nil
  end
  if (_72_ == false) then
    return ast
  elseif (nil ~= _72_) then
    local macro_2a = _72_
    local old_scope = scopes.macro
    local _
    scopes.macro = scope
    _ = nil
    local ok, transformed = nil, nil
    local function _74_()
      return macro_2a(unpack(ast, 2))
    end
    local function _75_()
      if built_in_3f(macro_2a) then
        return tostring
      else
        return debug.traceback
      end
    end
    ok, transformed = xpcall(_74_, _75_())
    local function _76_(...)
      return propagate_trace_info(ast, ...)
    end
    utils["walk-tree"](transformed, comp(_76_, quote_literal_nils))
    scopes.macro = old_scope
    assert_compile(ok, transformed, ast)
    if (_3fonce or not transformed) then
      return transformed
    else
      return macroexpand_2a(transformed, scope)
    end
  elseif true then
    local _ = _72_
    return ast
  else
    return nil
  end
end
local function compile_special(ast, scope, parent, opts, special)
  local exprs = (special(ast, scope, parent, opts) or utils.expr("nil", "literal"))
  local exprs0
  if ("table" ~= type(exprs)) then
    exprs0 = utils.expr(exprs, "expression")
  else
    exprs0 = exprs
  end
  local exprs2
  if utils["expr?"](exprs0) then
    exprs2 = {exprs0}
  else
    exprs2 = exprs0
  end
  if not exprs2.returned then
    return handle_compile_opts(exprs2, parent, opts, ast)
  elseif (opts.tail or opts.target) then
    return {returned = true}
  else
    return exprs2
  end
end
local function compile_function_call(ast, scope, parent, opts, compile1, len)
  local fargs = {}
  local fcallee = (compile1(ast[1], scope, parent, {nval = 1}))[1]
  assert_compile((utils["sym?"](ast[1]) or utils["list?"](ast[1]) or ("string" == type(ast[1]))), ("cannot call literal value " .. tostring(ast[1])), ast)
  for i = 2, len do
    local subexprs
    local _82_
    if (i ~= len) then
      _82_ = 1
    else
      _82_ = nil
    end
    subexprs = compile1(ast[i], scope, parent, {nval = _82_})
    table.insert(fargs, subexprs[1])
    if (i == len) then
      for j = 2, #subexprs do
        table.insert(fargs, subexprs[j])
      end
    else
      keep_side_effects(subexprs, parent, 2, ast[i])
    end
  end
  local pat
  if ("string" == type(ast[1])) then
    pat = "(%s)(%s)"
  else
    pat = "%s(%s)"
  end
  local call = string.format(pat, tostring(fcallee), exprs1(fargs))
  return handle_compile_opts({utils.expr(call, "statement")}, parent, opts, ast)
end
local function compile_call(ast, scope, parent, opts, compile1)
  utils.hook("call", ast, scope)
  local len = #ast
  local first = ast[1]
  local multi_sym_parts = utils["multi-sym?"](first)
  local special = (utils["sym?"](first) and scope.specials[tostring(first)])
  assert_compile((0 < len), "expected a function, macro, or special to call", ast)
  if special then
    return compile_special(ast, scope, parent, opts, special)
  elseif (multi_sym_parts and multi_sym_parts["multi-sym-method-call"]) then
    local table_with_method = table.concat({unpack(multi_sym_parts, 1, (#multi_sym_parts - 1))}, ".")
    local method_to_call = multi_sym_parts[#multi_sym_parts]
    local new_ast = utils.list(utils.sym(":", ast), utils.sym(table_with_method, ast), method_to_call, select(2, unpack(ast)))
    return compile1(new_ast, scope, parent, opts)
  else
    return compile_function_call(ast, scope, parent, opts, compile1, len)
  end
end
local function compile_varg(ast, scope, parent, opts)
  local _87_
  if scope.hashfn then
    _87_ = "use $... in hashfn"
  else
    _87_ = "unexpected vararg"
  end
  assert_compile(scope.vararg, _87_, ast)
  return handle_compile_opts({utils.expr("...", "varg")}, parent, opts, ast)
end
local function compile_sym(ast, scope, parent, opts)
  local multi_sym_parts = utils["multi-sym?"](ast)
  assert_compile(not (multi_sym_parts and multi_sym_parts["multi-sym-method-call"]), "multisym method calls may only be in call position", ast)
  local e
  if (ast[1] == "nil") then
    e = utils.expr("nil", "literal")
  else
    e = symbol_to_expression(ast, scope, true)
  end
  return handle_compile_opts({e}, parent, opts, ast)
end
local function serialize_number(n)
  local _90_ = string.gsub(tostring(n), ",", ".")
  return _90_
end
local function compile_scalar(ast, _scope, parent, opts)
  local serialize
  do
    local _91_ = type(ast)
    if (_91_ == "nil") then
      serialize = tostring
    elseif (_91_ == "boolean") then
      serialize = tostring
    elseif (_91_ == "string") then
      serialize = serialize_string
    elseif (_91_ == "number") then
      serialize = serialize_number
    else
      serialize = nil
    end
  end
  return handle_compile_opts({utils.expr(serialize(ast), "literal")}, parent, opts)
end
local function compile_table(ast, scope, parent, opts, compile1)
  local function escape_key(k)
    if ((type(k) == "string") and utils["valid-lua-identifier?"](k)) then
      return k
    else
      local _let_93_ = compile1(k, scope, parent, {nval = 1})
      local compiled = _let_93_[1]
      return ("[" .. tostring(compiled) .. "]")
    end
  end
  local keys = {}
  local buffer
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for i, elem in ipairs(ast) do
      local val_19_auto
      do
        local nval = ((nil ~= ast[(i + 1)]) and 1)
        do end (keys)[i] = true
        val_19_auto = exprs1(compile1(elem, scope, parent, {nval = nval}))
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    buffer = tbl_17_auto
  end
  do
    local tbl_17_auto = buffer
    local i_18_auto = #tbl_17_auto
    for k, v in utils.stablepairs(ast) do
      local val_19_auto
      if not keys[k] then
        local _let_96_ = compile1(ast[k], scope, parent, {nval = 1})
        local v0 = _let_96_[1]
        val_19_auto = string.format("%s = %s", escape_key(k), tostring(v0))
      else
        val_19_auto = nil
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
  end
  return handle_compile_opts({utils.expr(("{" .. table.concat(buffer, ", ") .. "}"), "expression")}, parent, opts, ast)
end
local function compile1(ast, scope, parent, _3fopts)
  local opts = (_3fopts or {})
  local ast0 = macroexpand_2a(ast, scope)
  if utils["list?"](ast0) then
    return compile_call(ast0, scope, parent, opts, compile1)
  elseif utils["varg?"](ast0) then
    return compile_varg(ast0, scope, parent, opts)
  elseif utils["sym?"](ast0) then
    return compile_sym(ast0, scope, parent, opts)
  elseif (type(ast0) == "table") then
    return compile_table(ast0, scope, parent, opts, compile1)
  elseif ((type(ast0) == "nil") or (type(ast0) == "boolean") or (type(ast0) == "number") or (type(ast0) == "string")) then
    return compile_scalar(ast0, scope, parent, opts)
  else
    return assert_compile(false, ("could not compile value of type " .. type(ast0)), ast0)
  end
end
local function destructure(to, from, ast, scope, parent, opts)
  local opts0 = (opts or {})
  local _let_100_ = opts0
  local isvar = _let_100_["isvar"]
  local declaration = _let_100_["declaration"]
  local forceglobal = _let_100_["forceglobal"]
  local forceset = _let_100_["forceset"]
  local symtype = _let_100_["symtype"]
  local symtype0 = ("_" .. (symtype or "dst"))
  local setter
  if declaration then
    setter = "local %s = %s"
  else
    setter = "%s = %s"
  end
  local new_manglings = {}
  local function getname(symbol, up1)
    local raw = symbol[1]
    assert_compile(not (opts0.nomulti and utils["multi-sym?"](raw)), ("unexpected multi symbol " .. raw), up1)
    if declaration then
      return declare_local(symbol, nil, scope, symbol, new_manglings)
    else
      local parts = (utils["multi-sym?"](raw) or {raw})
      local _let_102_ = parts
      local first = _let_102_[1]
      local meta = scope.symmeta[first]
      assert_compile(not raw:find(":"), "cannot set method sym", symbol)
      if ((#parts == 1) and not forceset) then
        assert_compile(not (forceglobal and meta), string.format("global %s conflicts with local", tostring(symbol)), symbol)
        assert_compile(not (meta and not meta.var), ("expected var " .. raw), symbol)
      else
      end
      assert_compile((meta or not opts0.noundef or (scope.hashfn and ("$" == first)) or global_allowed_3f(first)), ("expected local " .. first), symbol)
      if forceglobal then
        assert_compile(not scope.symmeta[scope.unmanglings[raw]], ("global " .. raw .. " conflicts with local"), symbol)
        do end (scope.manglings)[raw] = global_mangling(raw)
        do end (scope.unmanglings)[global_mangling(raw)] = raw
        if allowed_globals then
          table.insert(allowed_globals, raw)
        else
        end
      else
      end
      return symbol_to_expression(symbol, scope)[1]
    end
  end
  local function compile_top_target(lvalues)
    local inits
    local function _107_(_241)
      if scope.manglings[_241] then
        return _241
      else
        return "nil"
      end
    end
    inits = utils.map(lvalues, _107_)
    local init = table.concat(inits, ", ")
    local lvalue = table.concat(lvalues, ", ")
    local plast = parent[#parent]
    local plen = #parent
    local ret = compile1(from, scope, parent, {target = lvalue})
    if declaration then
      for pi = plen, #parent do
        if (parent[pi] == plast) then
          plen = pi
        else
        end
      end
      if ((#parent == (plen + 1)) and parent[#parent].leaf) then
        parent[#parent]["leaf"] = ("local " .. parent[#parent].leaf)
      elseif (init == "nil") then
        table.insert(parent, (plen + 1), {ast = ast, leaf = ("local " .. lvalue)})
      else
        table.insert(parent, (plen + 1), {ast = ast, leaf = ("local " .. lvalue .. " = " .. init)})
      end
    else
    end
    return ret
  end
  local function destructure_sym(left, rightexprs, up1, top_3f)
    local lname = getname(left, up1)
    check_binding_valid(left, scope, left)
    if top_3f then
      compile_top_target({lname})
    else
      emit(parent, setter:format(lname, exprs1(rightexprs)), left)
    end
    if declaration then
      scope.symmeta[tostring(left)] = {var = isvar}
      return nil
    else
      return nil
    end
  end
  local unpack_fn = "function (t, k, e)\n                        local mt = getmetatable(t)\n                        if 'table' == type(mt) and mt.__fennelrest then\n                          return mt.__fennelrest(t, k)\n                        elseif e then\n                          local rest = {}\n                          for k, v in pairs(t) do\n                            if not e[k] then rest[k] = v end\n                          end\n                          return rest\n                        else\n                          return {(table.unpack or unpack)(t, k)}\n                        end\n                      end"
  local function destructure_kv_rest(s, v, left, excluded_keys, destructure1)
    local exclude_str
    local _114_
    do
      local tbl_17_auto = {}
      local i_18_auto = #tbl_17_auto
      for _, k in ipairs(excluded_keys) do
        local val_19_auto = string.format("[%s] = true", serialize_string(k))
        if (nil ~= val_19_auto) then
          i_18_auto = (i_18_auto + 1)
          do end (tbl_17_auto)[i_18_auto] = val_19_auto
        else
        end
      end
      _114_ = tbl_17_auto
    end
    exclude_str = table.concat(_114_, ", ")
    local subexpr = utils.expr(string.format(string.gsub(("(" .. unpack_fn .. ")(%s, %s, {%s})"), "\n%s*", " "), s, tostring(v), exclude_str), "expression")
    return destructure1(v, {subexpr}, left)
  end
  local function destructure_rest(s, k, left, destructure1)
    local unpack_str = ("(" .. unpack_fn .. ")(%s, %s)")
    local formatted = string.format(string.gsub(unpack_str, "\n%s*", " "), s, k)
    local subexpr = utils.expr(formatted, "expression")
    assert_compile((utils["sequence?"](left) and (nil == left[(k + 2)])), "expected rest argument before last parameter", left)
    return destructure1(left[(k + 1)], {subexpr}, left)
  end
  local function destructure_table(left, rightexprs, top_3f, destructure1)
    local s = gensym(scope, symtype0)
    local right
    do
      local _116_
      if top_3f then
        _116_ = exprs1(compile1(from, scope, parent))
      else
        _116_ = exprs1(rightexprs)
      end
      if (_116_ == "") then
        right = "nil"
      elseif (nil ~= _116_) then
        local right0 = _116_
        right = right0
      else
        right = nil
      end
    end
    local excluded_keys = {}
    emit(parent, string.format("local %s = %s", s, right), left)
    for k, v in utils.stablepairs(left) do
      if not (("number" == type(k)) and tostring(left[(k - 1)]):find("^&")) then
        if (utils["sym?"](k) and (tostring(k) == "&")) then
          destructure_kv_rest(s, v, left, excluded_keys, destructure1)
        elseif (utils["sym?"](v) and (tostring(v) == "&")) then
          destructure_rest(s, k, left, destructure1)
        elseif (utils["sym?"](k) and (tostring(k) == "&as")) then
          destructure_sym(v, {utils.expr(tostring(s))}, left)
        elseif (utils["sequence?"](left) and (tostring(v) == "&as")) then
          local _, next_sym, trailing = select(k, unpack(left))
          assert_compile((nil == trailing), "expected &as argument before last parameter", left)
          destructure_sym(next_sym, {utils.expr(tostring(s))}, left)
        else
          local key
          if (type(k) == "string") then
            key = serialize_string(k)
          else
            key = k
          end
          local subexpr = utils.expr(string.format("%s[%s]", s, key), "expression")
          if (type(k) == "string") then
            table.insert(excluded_keys, k)
          else
          end
          destructure1(v, {subexpr}, left)
        end
      else
      end
    end
    return nil
  end
  local function destructure_values(left, up1, top_3f, destructure1)
    local left_names, tables = {}, {}
    for i, name in ipairs(left) do
      if utils["sym?"](name) then
        table.insert(left_names, getname(name, up1))
      else
        local symname = gensym(scope, symtype0)
        table.insert(left_names, symname)
        do end (tables)[i] = {name, utils.expr(symname, "sym")}
      end
    end
    assert_compile(left[1], "must provide at least one value", left)
    assert_compile(top_3f, "can't nest multi-value destructuring", left)
    compile_top_target(left_names)
    if declaration then
      for _, sym in ipairs(left) do
        if utils["sym?"](sym) then
          scope.symmeta[tostring(sym)] = {var = isvar}
        else
        end
      end
    else
    end
    for _, pair in utils.stablepairs(tables) do
      destructure1(pair[1], {pair[2]}, left)
    end
    return nil
  end
  local function destructure1(left, rightexprs, up1, top_3f)
    if (utils["sym?"](left) and (left[1] ~= "nil")) then
      destructure_sym(left, rightexprs, up1, top_3f)
    elseif utils["table?"](left) then
      destructure_table(left, rightexprs, top_3f, destructure1)
    elseif utils["list?"](left) then
      destructure_values(left, up1, top_3f, destructure1)
    else
      assert_compile(false, string.format("unable to bind %s %s", type(left), tostring(left)), (((type((up1)[2]) == "table") and (up1)[2]) or up1))
    end
    if top_3f then
      return {returned = true}
    else
      return nil
    end
  end
  local ret = destructure1(to, nil, ast, true)
  utils.hook("destructure", from, to, scope, opts0)
  apply_manglings(scope, new_manglings, ast)
  return ret
end
local function require_include(ast, scope, parent, opts)
  opts.fallback = function(e, no_warn)
    if (not no_warn and ("literal" == e.type)) then
      utils.warn(("include module not found, falling back to require: %s"):format(tostring(e)))
    else
    end
    return utils.expr(string.format("require(%s)", tostring(e)), "statement")
  end
  return scopes.global.specials.include(ast, scope, parent, opts)
end
local function opts_for_compile(options)
  local opts = utils.copy(options)
  opts.indent = (opts.indent or "  ")
  allowed_globals = opts.allowedGlobals
  return opts
end
local function compile_asts(asts, options)
  local old_globals = allowed_globals
  local opts = opts_for_compile(options)
  local scope = (opts.scope or make_scope(scopes.global))
  local chunk = {}
  if opts.requireAsInclude then
    scope.specials.require = require_include
  else
  end
  do end (function(tgt, m, ...) return tgt[m](tgt, ...) end)(utils.root, "set-reset")
  utils.root.chunk, utils.root.scope, utils.root.options = chunk, scope, opts
  for i = 1, #asts do
    local exprs = compile1(asts[i], scope, chunk, {nval = (((i < #asts) and 0) or nil), tail = (i == #asts)})
    keep_side_effects(exprs, chunk, nil, asts[i])
    if (i == #asts) then
      utils.hook("chunk", asts[i], scope)
    else
    end
  end
  allowed_globals = old_globals
  utils.root.reset()
  return flatten(chunk, opts)
end
local function compile_stream(stream, opts)
  local asts
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for _, ast in parser.parser(stream, opts.filename, opts) do
      local val_19_auto = ast
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    asts = tbl_17_auto
  end
  return compile_asts(asts, opts)
end
local function compile_string(str, _3fopts)
  return compile_stream(parser["string-stream"](str, (_3fopts or {})), (_3fopts or {}))
end
local function compile(ast, _3fopts)
  return compile_asts({ast}, _3fopts)
end
local function traceback_frame(info)
  if ((info.what == "C") and info.name) then
    return string.format("  [C]: in function '%s'", info.name)
  elseif (info.what == "C") then
    return "  [C]: in ?"
  else
    local remap = sourcemap[info.source]
    if (remap and remap[info.currentline]) then
      if ((remap[info.currentline][1] or "unknown") ~= "unknown") then
        info.short_src = sourcemap[("@" .. remap[info.currentline][1])].short_src
      else
        info.short_src = remap.short_src
      end
      info.currentline = (remap[info.currentline][2] or -1)
    else
    end
    if (info.what == "Lua") then
      local function _134_()
        if info.name then
          return ("'" .. info.name .. "'")
        else
          return "?"
        end
      end
      return string.format("  %s:%d: in function %s", info.short_src, info.currentline, _134_())
    elseif (info.short_src == "(tail call)") then
      return "  (tail call)"
    else
      return string.format("  %s:%d: in main chunk", info.short_src, info.currentline)
    end
  end
end
local function traceback(_3fmsg, _3fstart)
  local msg = tostring((_3fmsg or ""))
  if ((msg:find("^%g+:%d+:%d+ Compile error:.*") or msg:find("^%g+:%d+:%d+ Parse error:.*")) and not utils["debug-on?"]("trace")) then
    return msg
  else
    local lines = {}
    if (msg:find("^%g+:%d+:%d+ Compile error:") or msg:find("^%g+:%d+:%d+ Parse error:")) then
      table.insert(lines, msg)
    else
      local newmsg = msg:gsub("^[^:]*:%d+:%s+", "runtime error: ")
      table.insert(lines, newmsg)
    end
    table.insert(lines, "stack traceback:")
    local done_3f, level = false, (_3fstart or 2)
    while not done_3f do
      do
        local _138_ = debug.getinfo(level, "Sln")
        if (_138_ == nil) then
          done_3f = true
        elseif (nil ~= _138_) then
          local info = _138_
          table.insert(lines, traceback_frame(info))
        else
        end
      end
      level = (level + 1)
    end
    return table.concat(lines, "\n")
  end
end
local function entry_transform(fk, fv)
  local function _141_(k, v)
    if (type(k) == "number") then
      return k, fv(v)
    else
      return fk(k), fv(v)
    end
  end
  return _141_
end
local function mixed_concat(t, joiner)
  local seen = {}
  local ret, s = "", ""
  for k, v in ipairs(t) do
    table.insert(seen, k)
    ret = (ret .. s .. v)
    s = joiner
  end
  for k, v in utils.stablepairs(t) do
    if not seen[k] then
      ret = (ret .. s .. "[" .. k .. "]" .. "=" .. v)
      s = joiner
    else
    end
  end
  return ret
end
local function do_quote(form, scope, parent, runtime_3f)
  local function q(x)
    return do_quote(x, scope, parent, runtime_3f)
  end
  if utils["varg?"](form) then
    assert_compile(not runtime_3f, "quoted ... may only be used at compile time", form)
    return "_VARARG"
  elseif utils["sym?"](form) then
    local filename
    if form.filename then
      filename = string.format("%q", form.filename)
    else
      filename = "nil"
    end
    local symstr = tostring(form)
    assert_compile(not runtime_3f, "symbols may only be used at compile time", form)
    if (symstr:find("#$") or symstr:find("#[:.]")) then
      return string.format("sym('%s', {filename=%s, line=%s})", autogensym(symstr, scope), filename, (form.line or "nil"))
    else
      return string.format("sym('%s', {quoted=true, filename=%s, line=%s})", symstr, filename, (form.line or "nil"))
    end
  elseif (utils["list?"](form) and utils["sym?"](form[1]) and (tostring(form[1]) == "unquote")) then
    local payload = form[2]
    local res = unpack(compile1(payload, scope, parent))
    return res[1]
  elseif utils["list?"](form) then
    local mapped
    local function _146_()
      return nil
    end
    mapped = utils.kvmap(form, entry_transform(_146_, q))
    local filename
    if form.filename then
      filename = string.format("%q", form.filename)
    else
      filename = "nil"
    end
    assert_compile(not runtime_3f, "lists may only be used at compile time", form)
    return string.format(("setmetatable({filename=%s, line=%s, bytestart=%s, %s}" .. ", getmetatable(list()))"), filename, (form.line or "nil"), (form.bytestart or "nil"), mixed_concat(mapped, ", "))
  elseif utils["sequence?"](form) then
    local mapped = utils.kvmap(form, entry_transform(q, q))
    local source = getmetatable(form)
    local filename
    if source.filename then
      filename = string.format("%q", source.filename)
    else
      filename = "nil"
    end
    local _149_
    if source then
      _149_ = source.line
    else
      _149_ = "nil"
    end
    return string.format("setmetatable({%s}, {filename=%s, line=%s, sequence=%s})", mixed_concat(mapped, ", "), filename, _149_, "(getmetatable(sequence()))['sequence']")
  elseif (type(form) == "table") then
    local mapped = utils.kvmap(form, entry_transform(q, q))
    local source = getmetatable(form)
    local filename
    if source.filename then
      filename = string.format("%q", source.filename)
    else
      filename = "nil"
    end
    local function _152_()
      if source then
        return source.line
      else
        return "nil"
      end
    end
    return string.format("setmetatable({%s}, {filename=%s, line=%s})", mixed_concat(mapped, ", "), filename, _152_())
  elseif (type(form) == "string") then
    return serialize_string(form)
  else
    return tostring(form)
  end
end
return {compile = compile, compile1 = compile1, ["compile-stream"] = compile_stream, ["compile-string"] = compile_string, ["check-binding-valid"] = check_binding_valid, emit = emit, destructure = destructure, ["require-include"] = require_include, autogensym = autogensym, gensym = gensym, ["do-quote"] = do_quote, ["global-mangling"] = global_mangling, ["global-unmangling"] = global_unmangling, ["apply-manglings"] = apply_manglings, macroexpand = macroexpand_2a, ["declare-local"] = declare_local, ["make-scope"] = make_scope, ["keep-side-effects"] = keep_side_effects, ["symbol-to-expression"] = symbol_to_expression, assert = assert_compile, scopes = scopes, traceback = traceback, metadata = make_metadata(), sourcemap = sourcemap}
