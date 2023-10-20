local utils = require("fennel.utils")
local view = require("fennel.view")
local parser = require("fennel.parser")
local compiler = require("fennel.compiler")
local unpack = (table.unpack or _G.unpack)
local SPECIALS = compiler.scopes.global.specials
local function wrap_env(env)
  local function _1_(_, key)
    if utils["string?"](key) then
      return env[compiler["global-unmangling"](key)]
    else
      return env[key]
    end
  end
  local function _3_(_, key, value)
    if utils["string?"](key) then
      env[compiler["global-unmangling"](key)] = value
      return nil
    else
      env[key] = value
      return nil
    end
  end
  local function _5_()
    local function putenv(k, v)
      local _6_
      if utils["string?"](k) then
        _6_ = compiler["global-unmangling"](k)
      else
        _6_ = k
      end
      return _6_, v
    end
    return next, utils.kvmap(env, putenv), nil
  end
  return setmetatable({}, {__index = _1_, __newindex = _3_, __pairs = _5_})
end
local function current_global_names(_3fenv)
  local mt
  do
    local _8_ = getmetatable(_3fenv)
    if ((_G.type(_8_) == "table") and (nil ~= (_8_).__pairs)) then
      local mtpairs = (_8_).__pairs
      local tbl_14_auto = {}
      for k, v in mtpairs(_3fenv) do
        local k_15_auto, v_16_auto = k, v
        if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
          tbl_14_auto[k_15_auto] = v_16_auto
        else
        end
      end
      mt = tbl_14_auto
    elseif (_8_ == nil) then
      mt = (_3fenv or _G)
    else
      mt = nil
    end
  end
  return (mt and utils.kvmap(mt, compiler["global-unmangling"]))
end
local function load_code(code, _3fenv, _3ffilename)
  local env = (_3fenv or rawget(_G, "_ENV") or _G)
  local _11_, _12_ = rawget(_G, "setfenv"), rawget(_G, "loadstring")
  if ((nil ~= _11_) and (nil ~= _12_)) then
    local setfenv = _11_
    local loadstring = _12_
    local f = assert(loadstring(code, _3ffilename))
    setfenv(f, env)
    return f
  elseif true then
    local _ = _11_
    return assert(load(code, _3ffilename, "t", env))
  else
    return nil
  end
end
local function doc_2a(tgt, name)
  if not tgt then
    return (name .. " not found")
  else
    local docstring = (((compiler.metadata):get(tgt, "fnl/docstring") or "#<undocumented>")):gsub("\n$", ""):gsub("\n", "\n  ")
    local mt = getmetatable(tgt)
    if ((type(tgt) == "function") or ((type(mt) == "table") and (type(mt.__call) == "function"))) then
      local arglist = table.concat(((compiler.metadata):get(tgt, "fnl/arglist") or {"#<unknown-arguments>"}), " ")
      local _14_
      if (0 < #arglist) then
        _14_ = " "
      else
        _14_ = ""
      end
      return string.format("(%s%s%s)\n  %s", name, _14_, arglist, docstring)
    else
      return string.format("%s\n  %s", name, docstring)
    end
  end
end
local function doc_special(name, arglist, docstring, body_form_3f)
  compiler.metadata[SPECIALS[name]] = {["fnl/arglist"] = arglist, ["fnl/docstring"] = docstring, ["fnl/body-form?"] = body_form_3f}
  return nil
end
local function compile_do(ast, scope, parent, _3fstart)
  local start = (_3fstart or 2)
  local len = #ast
  local sub_scope = compiler["make-scope"](scope)
  for i = start, len do
    compiler.compile1(ast[i], sub_scope, parent, {nval = 0})
  end
  return nil
end
SPECIALS["do"] = function(ast, scope, parent, opts, _3fstart, _3fchunk, _3fsub_scope, _3fpre_syms)
  local start = (_3fstart or 2)
  local sub_scope = (_3fsub_scope or compiler["make-scope"](scope))
  local chunk = (_3fchunk or {})
  local len = #ast
  local retexprs = {returned = true}
  local function compile_body(outer_target, outer_tail, outer_retexprs)
    if (len < start) then
      compiler.compile1(nil, sub_scope, chunk, {tail = outer_tail, target = outer_target})
    else
      for i = start, len do
        local subopts = {nval = (((i ~= len) and 0) or opts.nval), tail = (((i == len) and outer_tail) or nil), target = (((i == len) and outer_target) or nil)}
        local _ = utils["propagate-options"](opts, subopts)
        local subexprs = compiler.compile1(ast[i], sub_scope, chunk, subopts)
        if (i ~= len) then
          compiler["keep-side-effects"](subexprs, parent, nil, ast[i])
        else
        end
      end
    end
    compiler.emit(parent, chunk, ast)
    compiler.emit(parent, "end", ast)
    utils.hook("do", ast, sub_scope)
    return (outer_retexprs or retexprs)
  end
  if (opts.target or (opts.nval == 0) or opts.tail) then
    compiler.emit(parent, "do", ast)
    return compile_body(opts.target, opts.tail)
  elseif opts.nval then
    local syms = {}
    for i = 1, opts.nval do
      local s = ((_3fpre_syms and (_3fpre_syms)[i]) or compiler.gensym(scope))
      do end (syms)[i] = s
      retexprs[i] = utils.expr(s, "sym")
    end
    local outer_target = table.concat(syms, ", ")
    compiler.emit(parent, string.format("local %s", outer_target), ast)
    compiler.emit(parent, "do", ast)
    return compile_body(outer_target, opts.tail)
  else
    local fname = compiler.gensym(scope)
    local fargs
    if scope.vararg then
      fargs = "..."
    else
      fargs = ""
    end
    compiler.emit(parent, string.format("local function %s(%s)", fname, fargs), ast)
    return compile_body(nil, true, utils.expr((fname .. "(" .. fargs .. ")"), "statement"))
  end
end
doc_special("do", {"..."}, "Evaluate multiple forms; return last value.", true)
SPECIALS.values = function(ast, scope, parent)
  local len = #ast
  local exprs = {}
  for i = 2, len do
    local subexprs = compiler.compile1(ast[i], scope, parent, {nval = ((i ~= len) and 1)})
    table.insert(exprs, subexprs[1])
    if (i == len) then
      for j = 2, #subexprs do
        table.insert(exprs, subexprs[j])
      end
    else
    end
  end
  return exprs
end
doc_special("values", {"..."}, "Return multiple values from a function. Must be in tail position.")
local function __3estack(stack, tbl)
  for k, v in pairs(tbl) do
    table.insert(stack, k)
    table.insert(stack, v)
  end
  return stack
end
local function literal_3f(val)
  local res = true
  if utils["list?"](val) then
    res = false
  elseif utils["table?"](val) then
    local stack = __3estack({}, val)
    for _, elt in ipairs(stack) do
      if not res then break end
      if utils["list?"](elt) then
        res = false
      elseif utils["table?"](elt) then
        __3estack(stack, elt)
      else
      end
    end
  else
  end
  return res
end
local function compile_value(v)
  local opts = {nval = 1, tail = false}
  local scope = compiler["make-scope"]()
  local chunk = {}
  local _let_25_ = compiler.compile1(v, scope, chunk, opts)
  local _let_26_ = _let_25_[1]
  local v0 = _let_26_[1]
  return v0
end
local function insert_meta(meta, k, v)
  local view_opts = {["escape-newlines?"] = true, ["line-length"] = math.huge, ["one-line?"] = true}
  compiler.assert((type(k) == "string"), ("expected string keys in metadata table, got: %s"):format(view(k, view_opts)))
  compiler.assert(literal_3f(v), ("expected literal value in metadata table, got: %s %s"):format(view(k, view_opts), view(v, view_opts)))
  table.insert(meta, view(k))
  local function _27_()
    if ("string" == type(v)) then
      return view(v, view_opts)
    else
      return compile_value(v)
    end
  end
  table.insert(meta, _27_())
  return meta
end
local function insert_arglist(meta, arg_list)
  local view_opts = {["one-line?"] = true, ["escape-newlines?"] = true, ["line-length"] = math.huge}
  table.insert(meta, "\"fnl/arglist\"")
  local function _28_(_241)
    return view(view(_241, view_opts))
  end
  table.insert(meta, ("{" .. table.concat(utils.map(arg_list, _28_), ", ") .. "}"))
  return meta
end
local function set_fn_metadata(f_metadata, parent, fn_name)
  if utils.root.options.useMetadata then
    local meta_fields = {}
    for k, v in utils.stablepairs(f_metadata) do
      if (k == "fnl/arglist") then
        insert_arglist(meta_fields, v)
      else
        insert_meta(meta_fields, k, v)
      end
    end
    local meta_str = ("require(\"%s\").metadata"):format((utils.root.options.moduleName or "fennel"))
    return compiler.emit(parent, ("pcall(function() %s:setall(%s, %s) end)"):format(meta_str, fn_name, table.concat(meta_fields, ", ")))
  else
    return nil
  end
end
local function get_fn_name(ast, scope, fn_name, multi)
  if (fn_name and (fn_name[1] ~= "nil")) then
    local _31_
    if not multi then
      _31_ = compiler["declare-local"](fn_name, {}, scope, ast)
    else
      _31_ = (compiler["symbol-to-expression"](fn_name, scope))[1]
    end
    return _31_, not multi, 3
  else
    return nil, true, 2
  end
end
local function compile_named_fn(ast, f_scope, f_chunk, parent, index, fn_name, local_3f, arg_name_list, f_metadata)
  for i = (index + 1), #ast do
    compiler.compile1(ast[i], f_scope, f_chunk, {nval = (((i ~= #ast) and 0) or nil), tail = (i == #ast)})
  end
  local _34_
  if local_3f then
    _34_ = "local function %s(%s)"
  else
    _34_ = "%s = function(%s)"
  end
  compiler.emit(parent, string.format(_34_, fn_name, table.concat(arg_name_list, ", ")), ast)
  compiler.emit(parent, f_chunk, ast)
  compiler.emit(parent, "end", ast)
  set_fn_metadata(f_metadata, parent, fn_name)
  utils.hook("fn", ast, f_scope)
  return utils.expr(fn_name, "sym")
end
local function compile_anonymous_fn(ast, f_scope, f_chunk, parent, index, arg_name_list, f_metadata, scope)
  local fn_name = compiler.gensym(scope)
  return compile_named_fn(ast, f_scope, f_chunk, parent, index, fn_name, true, arg_name_list, f_metadata)
end
local function maybe_metadata(ast, pred, handler, mt, index)
  local index_2a = (index + 1)
  local index_2a_before_ast_end_3f = (index_2a < #ast)
  local expr = ast[index_2a]
  if (index_2a_before_ast_end_3f and pred(expr)) then
    return handler(mt, expr), index_2a
  else
    return mt, index
  end
end
local function get_function_metadata(ast, arg_list, index)
  local function _37_(_241, _242)
    local tbl_14_auto = _241
    for k, v in pairs(_242) do
      local k_15_auto, v_16_auto = k, v
      if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
        tbl_14_auto[k_15_auto] = v_16_auto
      else
      end
    end
    return tbl_14_auto
  end
  local function _39_(_241, _242)
    _241["fnl/docstring"] = _242
    return _241
  end
  return maybe_metadata(ast, utils["kv-table?"], _37_, maybe_metadata(ast, utils["string?"], _39_, {["fnl/arglist"] = arg_list}, index))
end
SPECIALS.fn = function(ast, scope, parent)
  local f_scope
  do
    local _40_ = compiler["make-scope"](scope)
    do end (_40_)["vararg"] = false
    f_scope = _40_
  end
  local f_chunk = {}
  local fn_sym = utils["sym?"](ast[2])
  local multi = (fn_sym and utils["multi-sym?"](fn_sym[1]))
  local fn_name, local_3f, index = get_fn_name(ast, scope, fn_sym, multi)
  local arg_list = compiler.assert(utils["table?"](ast[index]), "expected parameters table", ast)
  compiler.assert((not multi or not multi["multi-sym-method-call"]), ("unexpected multi symbol " .. tostring(fn_name)), fn_sym)
  local function destructure_arg(arg)
    local raw = utils.sym(compiler.gensym(scope))
    local declared = compiler["declare-local"](raw, {}, f_scope, ast)
    compiler.destructure(arg, raw, ast, f_scope, f_chunk, {declaration = true, nomulti = true, symtype = "arg"})
    return declared
  end
  local function destructure_amp(i)
    compiler.assert((i == (#arg_list - 1)), "expected rest argument before last parameter", arg_list[(i + 1)], arg_list)
    f_scope.vararg = true
    compiler.destructure(arg_list[#arg_list], {utils.varg()}, ast, f_scope, f_chunk, {declaration = true, nomulti = true, symtype = "arg"})
    return "..."
  end
  local function get_arg_name(arg, i)
    if f_scope.vararg then
      return nil
    elseif utils["varg?"](arg) then
      compiler.assert((arg == arg_list[#arg_list]), "expected vararg as last parameter", ast)
      f_scope.vararg = true
      return "..."
    elseif utils["sym?"](arg, "&") then
      return destructure_amp(i)
    elseif (utils["sym?"](arg) and (tostring(arg) ~= "nil") and not utils["multi-sym?"](tostring(arg))) then
      return compiler["declare-local"](arg, {}, f_scope, ast)
    elseif utils["table?"](arg) then
      return destructure_arg(arg)
    else
      return compiler.assert(false, ("expected symbol for function parameter: %s"):format(tostring(arg)), ast[index])
    end
  end
  local arg_name_list
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for i, a in ipairs(arg_list) do
      local val_19_auto = get_arg_name(a, i)
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    arg_name_list = tbl_17_auto
  end
  local f_metadata, index0 = get_function_metadata(ast, arg_list, index)
  if fn_name then
    return compile_named_fn(ast, f_scope, f_chunk, parent, index0, fn_name, local_3f, arg_name_list, f_metadata)
  else
    return compile_anonymous_fn(ast, f_scope, f_chunk, parent, index0, arg_name_list, f_metadata, scope)
  end
end
doc_special("fn", {"name?", "args", "docstring?", "..."}, "Function syntax. May optionally include a name and docstring or a metadata table.\nIf a name is provided, the function will be bound in the current scope.\nWhen called with the wrong number of args, excess args will be discarded\nand lacking args will be nil, use lambda for arity-checked functions.", true)
SPECIALS.lua = function(ast, _, parent)
  compiler.assert(((#ast == 2) or (#ast == 3)), "expected 1 or 2 arguments", ast)
  local _45_
  do
    local _44_ = utils["sym?"](ast[2])
    if (nil ~= _44_) then
      _45_ = tostring(_44_)
    else
      _45_ = _44_
    end
  end
  if ("nil" ~= _45_) then
    table.insert(parent, {ast = ast, leaf = tostring(ast[2])})
  else
  end
  local _49_
  do
    local _48_ = utils["sym?"](ast[3])
    if (nil ~= _48_) then
      _49_ = tostring(_48_)
    else
      _49_ = _48_
    end
  end
  if ("nil" ~= _49_) then
    return tostring(ast[3])
  else
    return nil
  end
end
local function dot(ast, scope, parent)
  compiler.assert((1 < #ast), "expected table argument", ast)
  local len = #ast
  local _let_52_ = compiler.compile1(ast[2], scope, parent, {nval = 1})
  local lhs = _let_52_[1]
  if (len == 2) then
    return tostring(lhs)
  else
    local indices = {}
    for i = 3, len do
      local index = ast[i]
      if (utils["string?"](index) and utils["valid-lua-identifier?"](index)) then
        table.insert(indices, ("." .. index))
      else
        local _let_53_ = compiler.compile1(index, scope, parent, {nval = 1})
        local index0 = _let_53_[1]
        table.insert(indices, ("[" .. tostring(index0) .. "]"))
      end
    end
    if (tostring(lhs):find("[{\"0-9]") or ("nil" == tostring(lhs))) then
      return ("(" .. tostring(lhs) .. ")" .. table.concat(indices))
    else
      return (tostring(lhs) .. table.concat(indices))
    end
  end
end
SPECIALS["."] = dot
doc_special(".", {"tbl", "key1", "..."}, "Look up key1 in tbl table. If more args are provided, do a nested lookup.")
SPECIALS.global = function(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {forceglobal = true, nomulti = true, symtype = "global"})
  return nil
end
doc_special("global", {"name", "val"}, "Set name as a global with val.")
SPECIALS.set = function(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {noundef = true, symtype = "set"})
  return nil
end
doc_special("set", {"name", "val"}, "Set a local variable to a new value. Only works on locals using var.")
local function set_forcibly_21_2a(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {forceset = true, symtype = "set"})
  return nil
end
SPECIALS["set-forcibly!"] = set_forcibly_21_2a
local function local_2a(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {declaration = true, nomulti = true, symtype = "local"})
  return nil
end
SPECIALS["local"] = local_2a
doc_special("local", {"name", "val"}, "Introduce new top-level immutable local.")
SPECIALS.var = function(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {declaration = true, isvar = true, nomulti = true, symtype = "var"})
  return nil
end
doc_special("var", {"name", "val"}, "Introduce new mutable local.")
local function kv_3f(t)
  local _57_
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for k in pairs(t) do
      local val_19_auto
      if ("number" ~= type(k)) then
        val_19_auto = k
      else
        val_19_auto = nil
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    _57_ = tbl_17_auto
  end
  return (_57_)[1]
end
SPECIALS.let = function(ast, scope, parent, opts)
  local bindings = ast[2]
  local pre_syms = {}
  compiler.assert((utils["table?"](bindings) and not kv_3f(bindings)), "expected binding sequence", bindings)
  compiler.assert(((#bindings % 2) == 0), "expected even number of name/value bindings", ast[2])
  compiler.assert((3 <= #ast), "expected body expression", ast[1])
  for _ = 1, (opts.nval or 0) do
    table.insert(pre_syms, compiler.gensym(scope))
  end
  local sub_scope = compiler["make-scope"](scope)
  local sub_chunk = {}
  for i = 1, #bindings, 2 do
    compiler.destructure(bindings[i], bindings[(i + 1)], ast, sub_scope, sub_chunk, {declaration = true, nomulti = true, symtype = "let"})
  end
  return SPECIALS["do"](ast, scope, parent, opts, 3, sub_chunk, sub_scope, pre_syms)
end
doc_special("let", {"[name1 val1 ... nameN valN]", "..."}, "Introduces a new scope in which a given set of local bindings are used.", true)
local function get_prev_line(parent)
  if ("table" == type(parent)) then
    return get_prev_line((parent.leaf or parent[#parent]))
  else
    return (parent or "")
  end
end
local function disambiguate_3f(rootstr, parent)
  local function _61_()
    local _62_ = get_prev_line(parent)
    if (nil ~= _62_) then
      local prev_line = _62_
      return prev_line:match("%)$")
    else
      return nil
    end
  end
  return (rootstr:match("^{") or rootstr:match("^%(") or _61_())
end
SPECIALS.tset = function(ast, scope, parent)
  compiler.assert((3 < #ast), "expected table, key, and value arguments", ast)
  local root = (compiler.compile1(ast[2], scope, parent, {nval = 1}))[1]
  local keys = {}
  for i = 3, (#ast - 1) do
    local _let_64_ = compiler.compile1(ast[i], scope, parent, {nval = 1})
    local key = _let_64_[1]
    table.insert(keys, tostring(key))
  end
  local value = (compiler.compile1(ast[#ast], scope, parent, {nval = 1}))[1]
  local rootstr = tostring(root)
  local fmtstr
  if disambiguate_3f(rootstr, parent) then
    fmtstr = "do end (%s)[%s] = %s"
  else
    fmtstr = "%s[%s] = %s"
  end
  return compiler.emit(parent, fmtstr:format(rootstr, table.concat(keys, "]["), tostring(value)), ast)
end
doc_special("tset", {"tbl", "key1", "...", "keyN", "val"}, "Set the value of a table field. Can take additional keys to set\nnested values, but all parents must contain an existing table.")
local function calculate_target(scope, opts)
  if not (opts.tail or opts.target or opts.nval) then
    return "iife", true, nil
  elseif (opts.nval and (opts.nval ~= 0) and not opts.target) then
    local accum = {}
    local target_exprs = {}
    for i = 1, opts.nval do
      local s = compiler.gensym(scope)
      do end (accum)[i] = s
      target_exprs[i] = utils.expr(s, "sym")
    end
    return "target", opts.tail, table.concat(accum, ", "), target_exprs
  else
    return "none", opts.tail, opts.target
  end
end
local function if_2a(ast, scope, parent, opts)
  compiler.assert((2 < #ast), "expected condition and body", ast)
  local do_scope = compiler["make-scope"](scope)
  local branches = {}
  local wrapper, inner_tail, inner_target, target_exprs = calculate_target(scope, opts)
  local body_opts = {nval = opts.nval, tail = inner_tail, target = inner_target}
  local function compile_body(i)
    local chunk = {}
    local cscope = compiler["make-scope"](do_scope)
    compiler["keep-side-effects"](compiler.compile1(ast[i], cscope, chunk, body_opts), chunk, nil, ast[i])
    return {chunk = chunk, scope = cscope}
  end
  if (1 == (#ast % 2)) then
    table.insert(ast, utils.sym("nil"))
  else
  end
  for i = 2, (#ast - 1), 2 do
    local condchunk = {}
    local res = compiler.compile1(ast[i], do_scope, condchunk, {nval = 1})
    local cond = res[1]
    local branch = compile_body((i + 1))
    branch.cond = cond
    branch.condchunk = condchunk
    branch.nested = ((i ~= 2) and (next(condchunk, nil) == nil))
    table.insert(branches, branch)
  end
  local else_branch = compile_body(#ast)
  local s = compiler.gensym(scope)
  local buffer = {}
  local last_buffer = buffer
  for i = 1, #branches do
    local branch = branches[i]
    local fstr
    if not branch.nested then
      fstr = "if %s then"
    else
      fstr = "elseif %s then"
    end
    local cond = tostring(branch.cond)
    local cond_line = fstr:format(cond)
    if branch.nested then
      compiler.emit(last_buffer, branch.condchunk, ast)
    else
      for _, v in ipairs(branch.condchunk) do
        compiler.emit(last_buffer, v, ast)
      end
    end
    compiler.emit(last_buffer, cond_line, ast)
    compiler.emit(last_buffer, branch.chunk, ast)
    if (i == #branches) then
      compiler.emit(last_buffer, "else", ast)
      compiler.emit(last_buffer, else_branch.chunk, ast)
      compiler.emit(last_buffer, "end", ast)
    elseif not (branches[(i + 1)]).nested then
      local next_buffer = {}
      compiler.emit(last_buffer, "else", ast)
      compiler.emit(last_buffer, next_buffer, ast)
      compiler.emit(last_buffer, "end", ast)
      last_buffer = next_buffer
    else
    end
  end
  if (wrapper == "iife") then
    local iifeargs = ((scope.vararg and "...") or "")
    compiler.emit(parent, ("local function %s(%s)"):format(tostring(s), iifeargs), ast)
    compiler.emit(parent, buffer, ast)
    compiler.emit(parent, "end", ast)
    return utils.expr(("%s(%s)"):format(tostring(s), iifeargs), "statement")
  elseif (wrapper == "none") then
    for i = 1, #buffer do
      compiler.emit(parent, buffer[i], ast)
    end
    return {returned = true}
  else
    compiler.emit(parent, ("local %s"):format(inner_target), ast)
    for i = 1, #buffer do
      compiler.emit(parent, buffer[i], ast)
    end
    return target_exprs
  end
end
SPECIALS["if"] = if_2a
doc_special("if", {"cond1", "body1", "...", "condN", "bodyN"}, "Conditional form.\nTakes any number of condition/body pairs and evaluates the first body where\nthe condition evaluates to truthy. Similar to cond in other lisps.")
local function remove_until_condition(bindings)
  local last_item = bindings[(#bindings - 1)]
  if ((utils["sym?"](last_item) and (tostring(last_item) == "&until")) or ("until" == last_item)) then
    table.remove(bindings, (#bindings - 1))
    return table.remove(bindings)
  else
    return nil
  end
end
local function compile_until(condition, scope, chunk)
  if condition then
    local _let_73_ = compiler.compile1(condition, scope, chunk, {nval = 1})
    local condition_lua = _let_73_[1]
    return compiler.emit(chunk, ("if %s then break end"):format(tostring(condition_lua)), utils.expr(condition, "expression"))
  else
    return nil
  end
end
SPECIALS.each = function(ast, scope, parent)
  compiler.assert((3 <= #ast), "expected body expression", ast[1])
  compiler.assert(utils["table?"](ast[2]), "expected binding table", ast)
  compiler.assert((2 <= #ast[2]), "expected binding and iterator", ast)
  local binding = setmetatable(utils.copy(ast[2]), getmetatable(ast[2]))
  local until_condition = remove_until_condition(binding)
  local iter = table.remove(binding, #binding)
  local destructures = {}
  local new_manglings = {}
  local sub_scope = compiler["make-scope"](scope)
  local function destructure_binding(v)
    compiler.assert(not utils["string?"](v), ("unexpected iterator clause " .. tostring(v)), binding)
    if utils["sym?"](v) then
      return compiler["declare-local"](v, {}, sub_scope, ast, new_manglings)
    else
      local raw = utils.sym(compiler.gensym(sub_scope))
      do end (destructures)[raw] = v
      return compiler["declare-local"](raw, {}, sub_scope, ast)
    end
  end
  local bind_vars = utils.map(binding, destructure_binding)
  local vals = compiler.compile1(iter, scope, parent)
  local val_names = utils.map(vals, tostring)
  local chunk = {}
  compiler.emit(parent, ("for %s in %s do"):format(table.concat(bind_vars, ", "), table.concat(val_names, ", ")), ast)
  for raw, args in utils.stablepairs(destructures) do
    compiler.destructure(args, raw, ast, sub_scope, chunk, {declaration = true, nomulti = true, symtype = "each"})
  end
  compiler["apply-manglings"](sub_scope, new_manglings, ast)
  compile_until(until_condition, sub_scope, chunk)
  compile_do(ast, sub_scope, chunk, 3)
  compiler.emit(parent, chunk, ast)
  return compiler.emit(parent, "end", ast)
end
doc_special("each", {"[key value (iterator)]", "..."}, "Runs the body once for each set of values provided by the given iterator.\nMost commonly used with ipairs for sequential tables or pairs for  undefined\norder, but can be used with any iterator.", true)
local function while_2a(ast, scope, parent)
  local len1 = #parent
  local condition = (compiler.compile1(ast[2], scope, parent, {nval = 1}))[1]
  local len2 = #parent
  local sub_chunk = {}
  if (len1 ~= len2) then
    for i = (len1 + 1), len2 do
      table.insert(sub_chunk, parent[i])
      do end (parent)[i] = nil
    end
    compiler.emit(parent, "while true do", ast)
    compiler.emit(sub_chunk, ("if not %s then break end"):format(condition[1]), ast)
  else
    compiler.emit(parent, ("while " .. tostring(condition) .. " do"), ast)
  end
  compile_do(ast, compiler["make-scope"](scope), sub_chunk, 3)
  compiler.emit(parent, sub_chunk, ast)
  return compiler.emit(parent, "end", ast)
end
SPECIALS["while"] = while_2a
doc_special("while", {"condition", "..."}, "The classic while loop. Evaluates body until a condition is non-truthy.", true)
local function for_2a(ast, scope, parent)
  compiler.assert(utils["table?"](ast[2]), "expected binding table", ast)
  local ranges = setmetatable(utils.copy(ast[2]), getmetatable(ast[2]))
  local until_condition = remove_until_condition(ranges)
  local binding_sym = table.remove(ranges, 1)
  local sub_scope = compiler["make-scope"](scope)
  local range_args = {}
  local chunk = {}
  compiler.assert(utils["sym?"](binding_sym), ("unable to bind %s %s"):format(type(binding_sym), tostring(binding_sym)), ast[2])
  compiler.assert((3 <= #ast), "expected body expression", ast[1])
  compiler.assert((#ranges <= 3), "unexpected arguments", ranges)
  compiler.assert((1 < #ranges), "expected range to include start and stop", ranges)
  for i = 1, math.min(#ranges, 3) do
    range_args[i] = tostring((compiler.compile1(ranges[i], scope, parent, {nval = 1}))[1])
  end
  compiler.emit(parent, ("for %s = %s do"):format(compiler["declare-local"](binding_sym, {}, sub_scope, ast), table.concat(range_args, ", ")), ast)
  compile_until(until_condition, sub_scope, chunk)
  compile_do(ast, sub_scope, chunk, 3)
  compiler.emit(parent, chunk, ast)
  return compiler.emit(parent, "end", ast)
end
SPECIALS["for"] = for_2a
doc_special("for", {"[index start stop step?]", "..."}, "Numeric loop construct.\nEvaluates body once for each value between start and stop (inclusive).", true)
local function native_method_call(ast, _scope, _parent, target, args)
  local _let_77_ = ast
  local _ = _let_77_[1]
  local _0 = _let_77_[2]
  local method_string = _let_77_[3]
  local call_string
  if ((target.type == "literal") or (target.type == "varg") or (target.type == "expression")) then
    call_string = "(%s):%s(%s)"
  else
    call_string = "%s:%s(%s)"
  end
  return utils.expr(string.format(call_string, tostring(target), method_string, table.concat(args, ", ")), "statement")
end
local function nonnative_method_call(ast, scope, parent, target, args)
  local method_string = tostring((compiler.compile1(ast[3], scope, parent, {nval = 1}))[1])
  local args0 = {tostring(target), unpack(args)}
  return utils.expr(string.format("%s[%s](%s)", tostring(target), method_string, table.concat(args0, ", ")), "statement")
end
local function double_eval_protected_method_call(ast, scope, parent, target, args)
  local method_string = tostring((compiler.compile1(ast[3], scope, parent, {nval = 1}))[1])
  local call = "(function(tgt, m, ...) return tgt[m](tgt, ...) end)(%s, %s)"
  table.insert(args, 1, method_string)
  return utils.expr(string.format(call, tostring(target), table.concat(args, ", ")), "statement")
end
local function method_call(ast, scope, parent)
  compiler.assert((2 < #ast), "expected at least 2 arguments", ast)
  local _let_79_ = compiler.compile1(ast[2], scope, parent, {nval = 1})
  local target = _let_79_[1]
  local args = {}
  for i = 4, #ast do
    local subexprs
    local _80_
    if (i ~= #ast) then
      _80_ = 1
    else
      _80_ = nil
    end
    subexprs = compiler.compile1(ast[i], scope, parent, {nval = _80_})
    utils.map(subexprs, tostring, args)
  end
  if (utils["string?"](ast[3]) and utils["valid-lua-identifier?"](ast[3])) then
    return native_method_call(ast, scope, parent, target, args)
  elseif (target.type == "sym") then
    return nonnative_method_call(ast, scope, parent, target, args)
  else
    return double_eval_protected_method_call(ast, scope, parent, target, args)
  end
end
SPECIALS[":"] = method_call
doc_special(":", {"tbl", "method-name", "..."}, "Call the named method on tbl with the provided args.\nMethod name doesn't have to be known at compile-time; if it is, use\n(tbl:method-name ...) instead.")
SPECIALS.comment = function(ast, _, parent)
  local c
  local _83_
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for i, elt in ipairs(ast) do
      local val_19_auto
      if (i ~= 1) then
        val_19_auto = view(ast[i], {["one-line?"] = true})
      else
        val_19_auto = nil
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    _83_ = tbl_17_auto
  end
  c = table.concat(_83_, " "):gsub("%]%]", "]\\]")
  return compiler.emit(parent, ("--[[ " .. c .. " ]]"), ast)
end
doc_special("comment", {"..."}, "Comment which will be emitted in Lua output.", true)
local function hashfn_max_used(f_scope, i, max)
  local max0
  if f_scope.symmeta[("$" .. i)].used then
    max0 = i
  else
    max0 = max
  end
  if (i < 9) then
    return hashfn_max_used(f_scope, (i + 1), max0)
  else
    return max0
  end
end
SPECIALS.hashfn = function(ast, scope, parent)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local f_scope
  do
    local _88_ = compiler["make-scope"](scope)
    do end (_88_)["vararg"] = false
    _88_["hashfn"] = true
    f_scope = _88_
  end
  local f_chunk = {}
  local name = compiler.gensym(scope)
  local symbol = utils.sym(name)
  local args = {}
  compiler["declare-local"](symbol, {}, scope, ast)
  for i = 1, 9 do
    args[i] = compiler["declare-local"](utils.sym(("$" .. i)), {}, f_scope, ast)
  end
  local function walker(idx, node, _3fparent_node)
    if utils["sym?"](node, "$...") then
      f_scope.vararg = true
      if _3fparent_node then
        _3fparent_node[idx] = utils.varg()
        return nil
      else
        return utils.varg()
      end
    else
      return ((utils["list?"](node) and (not _3fparent_node or not utils["sym?"](node[1], "hashfn"))) or utils["table?"](node))
    end
  end
  utils["walk-tree"](ast, walker)
  compiler.compile1(ast[2], f_scope, f_chunk, {tail = true})
  local max_used = hashfn_max_used(f_scope, 1, 0)
  if f_scope.vararg then
    compiler.assert((max_used == 0), "$ and $... in hashfn are mutually exclusive", ast)
  else
  end
  local arg_str
  if f_scope.vararg then
    arg_str = tostring(utils.varg())
  else
    arg_str = table.concat(args, ", ", 1, max_used)
  end
  compiler.emit(parent, string.format("local function %s(%s)", name, arg_str), ast)
  compiler.emit(parent, f_chunk, ast)
  compiler.emit(parent, "end", ast)
  return utils.expr(name, "sym")
end
doc_special("hashfn", {"..."}, "Function literal shorthand; args are either $... OR $1, $2, etc.")
local function maybe_short_circuit_protect(ast, i, name, _93_)
  local _arg_94_ = _93_
  local mac = _arg_94_["macros"]
  local call = (utils["list?"](ast) and tostring(ast[1]))
  if ((("or" == name) or ("and" == name)) and (1 < i) and (mac[call] or ("set" == call) or ("tset" == call) or ("global" == call))) then
    return utils.list(utils.sym("do"), ast)
  else
    return ast
  end
end
local function arithmetic_special(name, zero_arity, unary_prefix, ast, scope, parent)
  local len = #ast
  local operands = {}
  local padded_op = (" " .. name .. " ")
  for i = 2, len do
    local subast = maybe_short_circuit_protect(ast[i], i, name, scope)
    local subexprs = compiler.compile1(subast, scope, parent)
    if (i == len) then
      utils.map(subexprs, tostring, operands)
    else
      table.insert(operands, tostring(subexprs[1]))
    end
  end
  local _97_ = #operands
  if (_97_ == 0) then
    local _98_
    do
      compiler.assert(zero_arity, "Expected more than 0 arguments", ast)
      _98_ = zero_arity
    end
    return utils.expr(_98_, "literal")
  elseif (_97_ == 1) then
    if utils["varg?"](ast[2]) then
      return compiler.assert(false, "tried to use vararg with operator", ast)
    elseif unary_prefix then
      return ("(" .. unary_prefix .. padded_op .. operands[1] .. ")")
    else
      return operands[1]
    end
  elseif true then
    local _ = _97_
    return ("(" .. table.concat(operands, padded_op) .. ")")
  else
    return nil
  end
end
local function define_arithmetic_special(name, zero_arity, unary_prefix, _3flua_name)
  local _102_
  do
    local _101_ = (_3flua_name or name)
    local function _103_(...)
      return arithmetic_special(_101_, zero_arity, unary_prefix, ...)
    end
    _102_ = _103_
  end
  SPECIALS[name] = _102_
  return doc_special(name, {"a", "b", "..."}, "Arithmetic operator; works the same as Lua but accepts more arguments.")
end
define_arithmetic_special("+", "0")
define_arithmetic_special("..", "''")
define_arithmetic_special("^")
define_arithmetic_special("-", nil, "")
define_arithmetic_special("*", "1")
define_arithmetic_special("%")
define_arithmetic_special("/", nil, "1")
define_arithmetic_special("//", nil, "1")
SPECIALS["or"] = function(ast, scope, parent)
  return arithmetic_special("or", "false", nil, ast, scope, parent)
end
SPECIALS["and"] = function(ast, scope, parent)
  return arithmetic_special("and", "true", nil, ast, scope, parent)
end
doc_special("and", {"a", "b", "..."}, "Boolean operator; works the same as Lua but accepts more arguments.")
doc_special("or", {"a", "b", "..."}, "Boolean operator; works the same as Lua but accepts more arguments.")
local function bitop_special(native_name, lib_name, zero_arity, unary_prefix, ast, scope, parent)
  if (#ast == 1) then
    return compiler.assert(zero_arity, "Expected more than 0 arguments.", ast)
  else
    local len = #ast
    local operands = {}
    local padded_native_name = (" " .. native_name .. " ")
    local prefixed_lib_name = ("bit." .. lib_name)
    for i = 2, len do
      local subexprs
      local _104_
      if (i ~= len) then
        _104_ = 1
      else
        _104_ = nil
      end
      subexprs = compiler.compile1(ast[i], scope, parent, {nval = _104_})
      utils.map(subexprs, tostring, operands)
    end
    if (#operands == 1) then
      if utils.root.options.useBitLib then
        return (prefixed_lib_name .. "(" .. unary_prefix .. ", " .. operands[1] .. ")")
      else
        return ("(" .. unary_prefix .. padded_native_name .. operands[1] .. ")")
      end
    else
      if utils.root.options.useBitLib then
        return (prefixed_lib_name .. "(" .. table.concat(operands, ", ") .. ")")
      else
        return ("(" .. table.concat(operands, padded_native_name) .. ")")
      end
    end
  end
end
local function define_bitop_special(name, zero_arity, unary_prefix, native)
  local function _110_(...)
    return bitop_special(native, name, zero_arity, unary_prefix, ...)
  end
  SPECIALS[name] = _110_
  return nil
end
define_bitop_special("lshift", nil, "1", "<<")
define_bitop_special("rshift", nil, "1", ">>")
define_bitop_special("band", "0", "0", "&")
define_bitop_special("bor", "0", "0", "|")
define_bitop_special("bxor", "0", "0", "~")
doc_special("lshift", {"x", "n"}, "Bitwise logical left shift of x by n bits.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("rshift", {"x", "n"}, "Bitwise logical right shift of x by n bits.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("band", {"x1", "x2", "..."}, "Bitwise AND of any number of arguments.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("bor", {"x1", "x2", "..."}, "Bitwise OR of any number of arguments.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("bxor", {"x1", "x2", "..."}, "Bitwise XOR of any number of arguments.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
SPECIALS.bnot = function(ast, scope, parent)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local _let_111_ = compiler.compile1(ast[2], scope, parent, {nval = 1})
  local value = _let_111_[1]
  if utils.root.options.useBitLib then
    return ("bit.bnot(" .. tostring(value) .. ")")
  else
    return ("~(" .. tostring(value) .. ")")
  end
end
doc_special("bnot", {"x"}, "Bitwise negation; only works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("..", {"a", "b", "..."}, "String concatenation operator; works the same as Lua but accepts more arguments.")
local function native_comparator(op, _113_, scope, parent)
  local _arg_114_ = _113_
  local _ = _arg_114_[1]
  local lhs_ast = _arg_114_[2]
  local rhs_ast = _arg_114_[3]
  local _let_115_ = compiler.compile1(lhs_ast, scope, parent, {nval = 1})
  local lhs = _let_115_[1]
  local _let_116_ = compiler.compile1(rhs_ast, scope, parent, {nval = 1})
  local rhs = _let_116_[1]
  return string.format("(%s %s %s)", tostring(lhs), op, tostring(rhs))
end
local function idempotent_comparator(op, chain_op, ast, scope, parent)
  local vals
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for i = 2, #ast do
      local val_19_auto = tostring((compiler.compile1(ast[i], scope, parent, {nval = 1}))[1])
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    vals = tbl_17_auto
  end
  local comparisons
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for i = 1, (#vals - 1) do
      local val_19_auto = string.format("(%s %s %s)", vals[i], op, vals[(i + 1)])
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
    comparisons = tbl_17_auto
  end
  local chain = string.format(" %s ", (chain_op or "and"))
  return ("(" .. table.concat(comparisons, chain) .. ")")
end
local function double_eval_protected_comparator(op, chain_op, ast, scope, parent)
  local arglist = {}
  local comparisons = {}
  local vals = {}
  local chain = string.format(" %s ", (chain_op or "and"))
  for i = 2, #ast do
    table.insert(arglist, tostring(compiler.gensym(scope)))
    table.insert(vals, tostring((compiler.compile1(ast[i], scope, parent, {nval = 1}))[1]))
  end
  do
    local tbl_17_auto = comparisons
    local i_18_auto = #tbl_17_auto
    for i = 1, (#arglist - 1) do
      local val_19_auto = string.format("(%s %s %s)", arglist[i], op, arglist[(i + 1)])
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      else
      end
    end
  end
  return string.format("(function(%s) return %s end)(%s)", table.concat(arglist, ","), table.concat(comparisons, chain), table.concat(vals, ","))
end
local function define_comparator_special(name, _3flua_op, _3fchain_op)
  do
    local op = (_3flua_op or name)
    local function opfn(ast, scope, parent)
      compiler.assert((2 < #ast), "expected at least two arguments", ast)
      if (3 == #ast) then
        return native_comparator(op, ast, scope, parent)
      elseif utils["every?"]({unpack(ast, 2)}, utils["idempotent-expr?"]) then
        return idempotent_comparator(op, _3fchain_op, ast, scope, parent)
      else
        return double_eval_protected_comparator(op, _3fchain_op, ast, scope, parent)
      end
    end
    SPECIALS[name] = opfn
  end
  return doc_special(name, {"a", "b", "..."}, "Comparison operator; works the same as Lua but accepts more arguments.")
end
define_comparator_special(">")
define_comparator_special("<")
define_comparator_special(">=")
define_comparator_special("<=")
define_comparator_special("=", "==")
define_comparator_special("not=", "~=", "or")
local function define_unary_special(op, _3frealop)
  local function opfn(ast, scope, parent)
    compiler.assert((#ast == 2), "expected one argument", ast)
    local tail = compiler.compile1(ast[2], scope, parent, {nval = 1})
    return ((_3frealop or op) .. tostring(tail[1]))
  end
  SPECIALS[op] = opfn
  return nil
end
define_unary_special("not", "not ")
doc_special("not", {"x"}, "Logical operator; works the same as Lua.")
define_unary_special("length", "#")
doc_special("length", {"x"}, "Returns the length of a table or string.")
do end (SPECIALS)["~="] = SPECIALS["not="]
SPECIALS["#"] = SPECIALS.length
SPECIALS.quote = function(ast, scope, parent)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local runtime, this_scope = true, scope
  while this_scope do
    this_scope = this_scope.parent
    if (this_scope == compiler.scopes.compiler) then
      runtime = false
    else
    end
  end
  return compiler["do-quote"](ast[2], scope, parent, runtime)
end
doc_special("quote", {"x"}, "Quasiquote the following form. Only works in macro/compiler scope.")
local macro_loaded = {}
local function safe_getmetatable(tbl)
  local mt = getmetatable(tbl)
  assert((mt ~= getmetatable("")), "Illegal metatable access!")
  return mt
end
local safe_require = nil
local function safe_compiler_env()
  local _123_
  do
    local _122_ = rawget(_G, "utf8")
    if (nil ~= _122_) then
      _123_ = utils.copy(_122_)
    else
      _123_ = _122_
    end
  end
  return {table = utils.copy(table), math = utils.copy(math), string = utils.copy(string), pairs = utils.stablepairs, ipairs = ipairs, select = select, tostring = tostring, tonumber = tonumber, bit = rawget(_G, "bit"), pcall = pcall, xpcall = xpcall, next = next, print = print, type = type, assert = assert, error = error, setmetatable = setmetatable, getmetatable = safe_getmetatable, require = safe_require, rawlen = rawget(_G, "rawlen"), rawget = rawget, rawset = rawset, rawequal = rawequal, _VERSION = _VERSION, utf8 = _123_}
end
local function combined_mt_pairs(env)
  local combined = {}
  local _let_125_ = getmetatable(env)
  local __index = _let_125_["__index"]
  if ("table" == type(__index)) then
    for k, v in pairs(__index) do
      combined[k] = v
    end
  else
  end
  for k, v in next, env, nil do
    combined[k] = v
  end
  return next, combined, nil
end
local function make_compiler_env(ast, scope, parent, _3fopts)
  local provided
  do
    local _127_ = (_3fopts or utils.root.options)
    if ((_G.type(_127_) == "table") and ((_127_)["compiler-env"] == "strict")) then
      provided = safe_compiler_env()
    elseif ((_G.type(_127_) == "table") and (nil ~= (_127_).compilerEnv)) then
      local compilerEnv = (_127_).compilerEnv
      provided = compilerEnv
    elseif ((_G.type(_127_) == "table") and (nil ~= (_127_)["compiler-env"])) then
      local compiler_env = (_127_)["compiler-env"]
      provided = compiler_env
    elseif true then
      local _ = _127_
      provided = safe_compiler_env(false)
    else
      provided = nil
    end
  end
  local env
  local function _129_(base)
    return utils.sym(compiler.gensym((compiler.scopes.macro or scope), base))
  end
  local function _130_()
    return compiler.scopes.macro
  end
  local function _131_(symbol)
    compiler.assert(compiler.scopes.macro, "must call from macro", ast)
    return compiler.scopes.macro.manglings[tostring(symbol)]
  end
  local function _132_(form)
    compiler.assert(compiler.scopes.macro, "must call from macro", ast)
    return compiler.macroexpand(form, compiler.scopes.macro)
  end
  env = {_AST = ast, _CHUNK = parent, _IS_COMPILER = true, _SCOPE = scope, _SPECIALS = compiler.scopes.global.specials, _VARARG = utils.varg(), ["macro-loaded"] = macro_loaded, unpack = unpack, ["assert-compile"] = compiler.assert, view = view, version = utils.version, metadata = compiler.metadata, ["ast-source"] = utils["ast-source"], list = utils.list, ["list?"] = utils["list?"], ["table?"] = utils["table?"], sequence = utils.sequence, ["sequence?"] = utils["sequence?"], sym = utils.sym, ["sym?"] = utils["sym?"], ["multi-sym?"] = utils["multi-sym?"], comment = utils.comment, ["comment?"] = utils["comment?"], ["varg?"] = utils["varg?"], gensym = _129_, ["get-scope"] = _130_, ["in-scope?"] = _131_, macroexpand = _132_}
  env._G = env
  return setmetatable(env, {__index = provided, __newindex = provided, __pairs = combined_mt_pairs})
end
local function _134_(...)
  local tbl_17_auto = {}
  local i_18_auto = #tbl_17_auto
  for c in string.gmatch((package.config or ""), "([^\n]+)") do
    local val_19_auto = c
    if (nil ~= val_19_auto) then
      i_18_auto = (i_18_auto + 1)
      do end (tbl_17_auto)[i_18_auto] = val_19_auto
    else
    end
  end
  return tbl_17_auto
end
local _local_133_ = _134_(...)
local dirsep = _local_133_[1]
local pathsep = _local_133_[2]
local pathmark = _local_133_[3]
local pkg_config = {dirsep = (dirsep or "/"), pathmark = (pathmark or "?"), pathsep = (pathsep or ";")}
local function escapepat(str)
  return string.gsub(str, "[^%w]", "%%%1")
end
local function search_module(modulename, _3fpathstring)
  local pathsepesc = escapepat(pkg_config.pathsep)
  local pattern = ("([^%s]*)%s"):format(pathsepesc, pathsepesc)
  local no_dot_module = modulename:gsub("%.", pkg_config.dirsep)
  local fullpath = ((_3fpathstring or utils["fennel-module"].path) .. pkg_config.pathsep)
  local function try_path(path)
    local filename = path:gsub(escapepat(pkg_config.pathmark), no_dot_module)
    local filename2 = path:gsub(escapepat(pkg_config.pathmark), modulename)
    local _136_ = (io.open(filename) or io.open(filename2))
    if (nil ~= _136_) then
      local file = _136_
      file:close()
      return filename
    elseif true then
      local _ = _136_
      return nil, ("no file '" .. filename .. "'")
    else
      return nil
    end
  end
  local function find_in_path(start, _3ftried_paths)
    local _138_ = fullpath:match(pattern, start)
    if (nil ~= _138_) then
      local path = _138_
      local _139_, _140_ = try_path(path)
      if (nil ~= _139_) then
        local filename = _139_
        return filename
      elseif ((_139_ == nil) and (nil ~= _140_)) then
        local error = _140_
        local function _142_()
          local _141_ = (_3ftried_paths or {})
          table.insert(_141_, error)
          return _141_
        end
        return find_in_path((start + #path + 1), _142_())
      else
        return nil
      end
    elseif true then
      local _ = _138_
      local function _144_()
        local tried_paths = table.concat((_3ftried_paths or {}), "\n\9")
        if (_VERSION < "Lua 5.4") then
          return ("\n\9" .. tried_paths)
        else
          return tried_paths
        end
      end
      return nil, _144_()
    else
      return nil
    end
  end
  return find_in_path(1)
end
local function make_searcher(_3foptions)
  local function _147_(module_name)
    local opts = utils.copy(utils.root.options)
    for k, v in pairs((_3foptions or {})) do
      opts[k] = v
    end
    opts["module-name"] = module_name
    local _148_, _149_ = search_module(module_name)
    if (nil ~= _148_) then
      local filename = _148_
      local function _150_(...)
        return utils["fennel-module"].dofile(filename, opts, ...)
      end
      return _150_, filename
    elseif ((_148_ == nil) and (nil ~= _149_)) then
      local error = _149_
      return error
    else
      return nil
    end
  end
  return _147_
end
local function dofile_with_searcher(fennel_macro_searcher, filename, opts, ...)
  local searchers = (package.loaders or package.searchers or {})
  local _ = table.insert(searchers, 1, fennel_macro_searcher)
  local m = utils["fennel-module"].dofile(filename, opts, ...)
  table.remove(searchers, 1)
  return m
end
local function fennel_macro_searcher(module_name)
  local opts
  do
    local _152_ = utils.copy(utils.root.options)
    do end (_152_)["module-name"] = module_name
    _152_["env"] = "_COMPILER"
    _152_["requireAsInclude"] = false
    _152_["allowedGlobals"] = nil
    opts = _152_
  end
  local _153_ = search_module(module_name, utils["fennel-module"]["macro-path"])
  if (nil ~= _153_) then
    local filename = _153_
    local _154_
    if (opts["compiler-env"] == _G) then
      local function _155_(...)
        return dofile_with_searcher(fennel_macro_searcher, filename, opts, ...)
      end
      _154_ = _155_
    else
      local function _156_(...)
        return utils["fennel-module"].dofile(filename, opts, ...)
      end
      _154_ = _156_
    end
    return _154_, filename
  else
    return nil
  end
end
local function lua_macro_searcher(module_name)
  local _159_ = search_module(module_name, package.path)
  if (nil ~= _159_) then
    local filename = _159_
    local code
    do
      local f = io.open(filename)
      local function close_handlers_10_auto(ok_11_auto, ...)
        f:close()
        if ok_11_auto then
          return ...
        else
          return error(..., 0)
        end
      end
      local function _161_()
        return assert(f:read("*a"))
      end
      code = close_handlers_10_auto(_G.xpcall(_161_, (package.loaded.fennel or debug).traceback))
    end
    local chunk = load_code(code, make_compiler_env(), filename)
    return chunk, filename
  else
    return nil
  end
end
local macro_searchers = {fennel_macro_searcher, lua_macro_searcher}
local function search_macro_module(modname, n)
  local _163_ = macro_searchers[n]
  if (nil ~= _163_) then
    local f = _163_
    local _164_, _165_ = f(modname)
    if ((nil ~= _164_) and true) then
      local loader = _164_
      local _3ffilename = _165_
      return loader, _3ffilename
    elseif true then
      local _ = _164_
      return search_macro_module(modname, (n + 1))
    else
      return nil
    end
  else
    return nil
  end
end
local function sandbox_fennel_module(modname)
  if ((modname == "fennel.macros") or (package and package.loaded and ("table" == type(package.loaded[modname])) and (package.loaded[modname].metadata == compiler.metadata))) then
    return {metadata = compiler.metadata, view = view}
  else
    return nil
  end
end
local function _169_(modname)
  local function _170_()
    local loader, filename = search_macro_module(modname, 1)
    compiler.assert(loader, (modname .. " module not found."))
    do end (macro_loaded)[modname] = loader(modname, filename)
    return macro_loaded[modname]
  end
  return (macro_loaded[modname] or sandbox_fennel_module(modname) or _170_())
end
safe_require = _169_
local function add_macros(macros_2a, ast, scope)
  compiler.assert(utils["table?"](macros_2a), "expected macros to be table", ast)
  for k, v in pairs(macros_2a) do
    compiler.assert((type(v) == "function"), "expected each macro to be function", ast)
    compiler["check-binding-valid"](utils.sym(k), scope, ast, {["macro?"] = true})
    do end (scope.macros)[k] = v
  end
  return nil
end
local function resolve_module_name(_171_, _scope, _parent, opts)
  local _arg_172_ = _171_
  local filename = _arg_172_["filename"]
  local second = _arg_172_[2]
  local filename0 = (filename or (utils["table?"](second) and second.filename))
  local module_name = utils.root.options["module-name"]
  local modexpr = compiler.compile(second, opts)
  local modname_chunk = load_code(modexpr)
  return modname_chunk(module_name, filename0)
end
SPECIALS["require-macros"] = function(ast, scope, parent, _3freal_ast)
  compiler.assert((#ast == 2), "Expected one module name argument", (_3freal_ast or ast))
  local modname = resolve_module_name(ast, scope, parent, {})
  compiler.assert(utils["string?"](modname), "module name must compile to string", (_3freal_ast or ast))
  if not macro_loaded[modname] then
    local loader, filename = search_macro_module(modname, 1)
    compiler.assert(loader, (modname .. " module not found."), ast)
    do end (macro_loaded)[modname] = compiler.assert(utils["table?"](loader(modname, filename)), "expected macros to be table", (_3freal_ast or ast))
  else
  end
  if ("import-macros" == tostring(ast[1])) then
    return macro_loaded[modname]
  else
    return add_macros(macro_loaded[modname], ast, scope, parent)
  end
end
doc_special("require-macros", {"macro-module-name"}, "Load given module and use its contents as macro definitions in current scope.\nMacro module should return a table of macro functions with string keys.\nConsider using import-macros instead as it is more flexible.")
local function emit_included_fennel(src, path, opts, sub_chunk)
  local subscope = compiler["make-scope"](utils.root.scope.parent)
  local forms = {}
  if utils.root.options.requireAsInclude then
    subscope.specials.require = compiler["require-include"]
  else
  end
  for _, val in parser.parser(parser["string-stream"](src), path) do
    table.insert(forms, val)
  end
  for i = 1, #forms do
    local subopts
    if (i == #forms) then
      subopts = {tail = true}
    else
      subopts = {nval = 0}
    end
    utils["propagate-options"](opts, subopts)
    compiler.compile1(forms[i], subscope, sub_chunk, subopts)
  end
  return nil
end
local function include_path(ast, opts, path, mod, fennel_3f)
  utils.root.scope.includes[mod] = "fnl/loading"
  local src
  do
    local f = assert(io.open(path))
    local function close_handlers_10_auto(ok_11_auto, ...)
      f:close()
      if ok_11_auto then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _178_()
      return assert(f:read("*all")):gsub("[\13\n]*$", "")
    end
    src = close_handlers_10_auto(_G.xpcall(_178_, (package.loaded.fennel or debug).traceback))
  end
  local ret = utils.expr(("require(\"" .. mod .. "\")"), "statement")
  local target = ("package.preload[%q]"):format(mod)
  local preload_str = (target .. " = " .. target .. " or function(...)")
  local temp_chunk, sub_chunk = {}, {}
  compiler.emit(temp_chunk, preload_str, ast)
  compiler.emit(temp_chunk, sub_chunk)
  compiler.emit(temp_chunk, "end", ast)
  for _, v in ipairs(temp_chunk) do
    table.insert(utils.root.chunk, v)
  end
  if fennel_3f then
    emit_included_fennel(src, path, opts, sub_chunk)
  else
    compiler.emit(sub_chunk, src, ast)
  end
  utils.root.scope.includes[mod] = ret
  return ret
end
local function include_circular_fallback(mod, modexpr, fallback, ast)
  if (utils.root.scope.includes[mod] == "fnl/loading") then
    compiler.assert(fallback, "circular include detected", ast)
    return fallback(modexpr)
  else
    return nil
  end
end
SPECIALS.include = function(ast, scope, parent, opts)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local modexpr
  do
    local _181_, _182_ = pcall(resolve_module_name, ast, scope, parent, opts)
    if ((_181_ == true) and (nil ~= _182_)) then
      local modname = _182_
      modexpr = utils.expr(string.format("%q", modname), "literal")
    elseif true then
      local _ = _181_
      modexpr = (compiler.compile1(ast[2], scope, parent, {nval = 1}))[1]
    else
      modexpr = nil
    end
  end
  if ((modexpr.type ~= "literal") or ((modexpr[1]):byte() ~= 34)) then
    if opts.fallback then
      return opts.fallback(modexpr)
    else
      return compiler.assert(false, "module name must be string literal", ast)
    end
  else
    local mod = load_code(("return " .. modexpr[1]))()
    local oldmod = utils.root.options["module-name"]
    local _
    utils.root.options["module-name"] = mod
    _ = nil
    local res
    local function _185_()
      local _186_ = search_module(mod)
      if (nil ~= _186_) then
        local fennel_path = _186_
        return include_path(ast, opts, fennel_path, mod, true)
      elseif true then
        local _0 = _186_
        local lua_path = search_module(mod, package.path)
        if lua_path then
          return include_path(ast, opts, lua_path, mod, false)
        elseif opts.fallback then
          return opts.fallback(modexpr)
        else
          return compiler.assert(false, ("module not found " .. mod), ast)
        end
      else
        return nil
      end
    end
    res = ((utils["member?"](mod, (utils.root.options.skipInclude or {})) and opts.fallback(modexpr, true)) or include_circular_fallback(mod, modexpr, opts.fallback, ast) or utils.root.scope.includes[mod] or _185_())
    utils.root.options["module-name"] = oldmod
    return res
  end
end
doc_special("include", {"module-name-literal"}, "Like require but load the target module during compilation and embed it in the\nLua output. The module must be a string literal and resolvable at compile time.")
local function eval_compiler_2a(ast, scope, parent)
  local env = make_compiler_env(ast, scope, parent)
  local opts = utils.copy(utils.root.options)
  opts.scope = compiler["make-scope"](compiler.scopes.compiler)
  opts.allowedGlobals = current_global_names(env)
  return assert(load_code(compiler.compile(ast, opts), wrap_env(env)))(opts["module-name"], ast.filename)
end
SPECIALS.macros = function(ast, scope, parent)
  compiler.assert((#ast == 2), "Expected one table argument", ast)
  local macro_tbl = eval_compiler_2a(ast[2], scope, parent)
  compiler.assert(utils["table?"](macro_tbl), "Expected one table argument", ast)
  return add_macros(macro_tbl, ast, scope, parent)
end
doc_special("macros", {"{:macro-name-1 (fn [...] ...) ... :macro-name-N macro-body-N}"}, "Define all functions in the given table as macros local to the current scope.")
SPECIALS["eval-compiler"] = function(ast, scope, parent)
  local old_first = ast[1]
  ast[1] = utils.sym("do")
  local val = eval_compiler_2a(ast, scope, parent)
  do end (ast)[1] = old_first
  return val
end
doc_special("eval-compiler", {"..."}, "Evaluate the body at compile-time. Use the macro system instead if possible.", true)
SPECIALS.unquote = function(ast)
  return compiler.assert(false, "tried to use unquote outside quote", ast)
end
doc_special("unquote", {"..."}, "Evaluate the argument even if it's in a quoted form.")
return {doc = doc_2a, ["current-global-names"] = current_global_names, ["load-code"] = load_code, ["macro-loaded"] = macro_loaded, ["macro-searchers"] = macro_searchers, ["make-compiler-env"] = make_compiler_env, ["search-module"] = search_module, ["make-searcher"] = make_searcher, ["wrap-env"] = wrap_env}
