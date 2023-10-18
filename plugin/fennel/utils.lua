local view = require("fennel.view")
local version = "1.4.0-dev"
local function luajit_vm_3f()
  return ((nil ~= _G.jit) and (type(_G.jit) == "table") and (nil ~= _G.jit.on) and (nil ~= _G.jit.off) and (type(_G.jit.version_num) == "number"))
end
local function luajit_vm_version()
  local jit_os
  if (_G.jit.os == "OSX") then
    jit_os = "macOS"
  else
    jit_os = _G.jit.os
  end
  return (_G.jit.version .. " " .. jit_os .. "/" .. _G.jit.arch)
end
local function fengari_vm_3f()
  return ((nil ~= _G.fengari) and (type(_G.fengari) == "table") and (nil ~= _G.fengari.VERSION) and (type(_G.fengari.VERSION_NUM) == "number"))
end
local function fengari_vm_version()
  return (_G.fengari.RELEASE .. " (" .. _VERSION .. ")")
end
local function lua_vm_version()
  if luajit_vm_3f() then
    return luajit_vm_version()
  elseif fengari_vm_3f() then
    return fengari_vm_version()
  else
    return ("PUC " .. _VERSION)
  end
end
local function runtime_version(_3fas_table)
  if _3fas_table then
    return {fennel = version, lua = lua_vm_version()}
  else
    return ("Fennel " .. version .. " on " .. lua_vm_version())
  end
end
local function warn(message)
  if (_G.io and _G.io.stderr) then
    return (_G.io.stderr):write(("--WARNING: %s\n"):format(tostring(message)))
  else
    return nil
  end
end
local len
do
  local _5_, _6_ = pcall(require, "utf8")
  if ((_5_ == true) and (nil ~= _6_)) then
    local utf8 = _6_
    len = utf8.len
  elseif true then
    local _ = _5_
    len = string.len
  else
    len = nil
  end
end
local kv_order = {number = 1, boolean = 2, string = 3, table = 4}
local function kv_compare(a, b)
  local _8_, _9_ = type(a), type(b)
  if (((_8_ == "number") and (_9_ == "number")) or ((_8_ == "string") and (_9_ == "string"))) then
    return (a < b)
  else
    local function _10_()
      local a_t = _8_
      local b_t = _9_
      return (a_t ~= b_t)
    end
    if (((nil ~= _8_) and (nil ~= _9_)) and _10_()) then
      local a_t = _8_
      local b_t = _9_
      return ((kv_order[a_t] or 5) < (kv_order[b_t] or 5))
    elseif true then
      local _ = _8_
      return (tostring(a) < tostring(b))
    else
      return nil
    end
  end
end
local function add_stable_keys(succ, prev_key, src, _3fpred)
  local first = prev_key
  local last
  do
    local prev = prev_key
    for _, k in ipairs(src) do
      if ((prev == k) or (succ[k] ~= nil) or (_3fpred and not _3fpred(k))) then
        prev = prev
      else
        if (first == nil) then
          first = k
          prev = k
        elseif (prev ~= nil) then
          succ[prev] = k
          prev = k
        else
          prev = k
        end
      end
    end
    last = prev
  end
  return succ, last, first
end
local function stablepairs(t)
  local mt_keys
  do
    local t_14_ = getmetatable(t)
    if (nil ~= t_14_) then
      t_14_ = (t_14_).keys
    else
    end
    mt_keys = t_14_
  end
  local succ, prev, first_mt = nil, nil, nil
  local function _16_(_241)
    return t[_241]
  end
  succ, prev, first_mt = add_stable_keys({}, nil, (mt_keys or {}), _16_)
  local pairs_keys
  do
    local _17_
    do
      local tbl_17_auto = {}
      local i_18_auto = #tbl_17_auto
      for k in pairs(t) do
        local val_19_auto = k
        if (nil ~= val_19_auto) then
          i_18_auto = (i_18_auto + 1)
          do end (tbl_17_auto)[i_18_auto] = val_19_auto
        else
        end
      end
      _17_ = tbl_17_auto
    end
    table.sort(_17_, kv_compare)
    pairs_keys = _17_
  end
  local succ0, _, first_after_mt = add_stable_keys(succ, prev, pairs_keys)
  local first
  if (first_mt == nil) then
    first = first_after_mt
  else
    first = first_mt
  end
  local function stablenext(tbl, key)
    local _20_
    if (key == nil) then
      _20_ = first
    else
      _20_ = (succ0)[key]
    end
    if (nil ~= _20_) then
      local next_key = _20_
      local _22_ = tbl[next_key]
      if (_22_ ~= nil) then
        return next_key, _22_
      else
        return _22_
      end
    else
      return nil
    end
  end
  return stablenext, t, nil
end
local function get_in(tbl, path, _3ffallback)
  assert(("table" == type(tbl)), "get-in expects path to be a table")
  if (0 == #path) then
    return _3ffallback
  else
    local _25_
    do
      local t = tbl
      for _, k in ipairs(path) do
        if (nil == t) then break end
        local _26_ = type(t)
        if (_26_ == "table") then
          t = t[k]
        else
          t = nil
        end
      end
      _25_ = t
    end
    if (nil ~= _25_) then
      local res = _25_
      return res
    elseif true then
      local _ = _25_
      return _3ffallback
    else
      return nil
    end
  end
end
local function map(t, f, _3fout)
  local out = (_3fout or {})
  local f0
  if (type(f) == "function") then
    f0 = f
  else
    local function _30_(_241)
      return (_241)[f]
    end
    f0 = _30_
  end
  for _, x in ipairs(t) do
    local _32_ = f0(x)
    if (nil ~= _32_) then
      local v = _32_
      table.insert(out, v)
    else
    end
  end
  return out
end
local function kvmap(t, f, _3fout)
  local out = (_3fout or {})
  local f0
  if (type(f) == "function") then
    f0 = f
  else
    local function _34_(_241)
      return (_241)[f]
    end
    f0 = _34_
  end
  for k, x in stablepairs(t) do
    local _36_, _37_ = f0(k, x)
    if ((nil ~= _36_) and (nil ~= _37_)) then
      local key = _36_
      local value = _37_
      out[key] = value
    elseif (nil ~= _36_) then
      local value = _36_
      table.insert(out, value)
    else
    end
  end
  return out
end
local function copy(from, _3fto)
  local tbl_14_auto = (_3fto or {})
  for k, v in pairs((from or {})) do
    local k_15_auto, v_16_auto = k, v
    if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
      tbl_14_auto[k_15_auto] = v_16_auto
    else
    end
  end
  return tbl_14_auto
end
local function member_3f(x, tbl, _3fn)
  local _40_ = tbl[(_3fn or 1)]
  if (_40_ == x) then
    return true
  elseif (_40_ == nil) then
    return nil
  elseif true then
    local _ = _40_
    return member_3f(x, tbl, ((_3fn or 1) + 1))
  else
    return nil
  end
end
local function maxn(tbl)
  local max = 0
  for k in pairs(tbl) do
    if ("number" == type(k)) then
      max = math.max(max, k)
    else
      max = max
    end
  end
  return max
end
local function every_3f(t, predicate)
  local result = true
  for _, item in ipairs(t) do
    if not result then break end
    result = predicate(item)
  end
  return result
end
local function allpairs(tbl)
  assert((type(tbl) == "table"), "allpairs expects a table")
  local t = tbl
  local seen = {}
  local function allpairs_next(_, state)
    local next_state, value = next(t, state)
    if seen[next_state] then
      return allpairs_next(nil, next_state)
    elseif next_state then
      seen[next_state] = true
      return next_state, value
    else
      local _43_ = getmetatable(t)
      if ((_G.type(_43_) == "table") and true) then
        local __index = (_43_).__index
        if ("table" == type(__index)) then
          t = __index
          return allpairs_next(t)
        else
          return nil
        end
      else
        return nil
      end
    end
  end
  return allpairs_next
end
local function deref(self)
  return self[1]
end
local nil_sym = nil
local function list__3estring(self, _3fview, _3foptions, _3findent)
  local safe = {}
  local view0
  if _3fview then
    local function _47_(_241)
      return _3fview(_241, _3foptions, _3findent)
    end
    view0 = _47_
  else
    view0 = view
  end
  local max = maxn(self)
  for i = 1, max do
    safe[i] = (((self[i] == nil) and nil_sym) or self[i])
  end
  return ("(" .. table.concat(map(safe, view0), " ", 1, max) .. ")")
end
local function comment_view(c)
  return c, true
end
local function sym_3d(a, b)
  return ((deref(a) == deref(b)) and (getmetatable(a) == getmetatable(b)))
end
local function sym_3c(a, b)
  return (a[1] < tostring(b))
end
local symbol_mt = {"SYMBOL", __fennelview = deref, __tostring = deref, __eq = sym_3d, __lt = sym_3c}
local expr_mt
local function _49_(x)
  return tostring(deref(x))
end
expr_mt = {"EXPR", __tostring = _49_}
local list_mt = {"LIST", __fennelview = list__3estring, __tostring = list__3estring}
local comment_mt = {"COMMENT", __fennelview = comment_view, __tostring = deref, __eq = sym_3d, __lt = sym_3c}
local sequence_marker = {"SEQUENCE"}
local varg_mt = {"VARARG", __fennelview = deref, __tostring = deref}
local getenv
local function _50_()
  return nil
end
getenv = ((os and os.getenv) or _50_)
local function debug_on_3f(flag)
  local level = (getenv("FENNEL_DEBUG") or "")
  return ((level == "all") or level:find(flag))
end
local function list(...)
  return setmetatable({...}, list_mt)
end
local function sym(str, _3fsource)
  local _51_
  do
    local tbl_14_auto = {str}
    for k, v in pairs((_3fsource or {})) do
      local k_15_auto, v_16_auto = nil, nil
      if (type(k) == "string") then
        k_15_auto, v_16_auto = k, v
      else
        k_15_auto, v_16_auto = nil
      end
      if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
        tbl_14_auto[k_15_auto] = v_16_auto
      else
      end
    end
    _51_ = tbl_14_auto
  end
  return setmetatable(_51_, symbol_mt)
end
nil_sym = sym("nil")
local function sequence(...)
  local function _54_(seq, view0, inspector, indent)
    local opts
    do
      inspector["empty-as-sequence?"] = {once = true, after = inspector["empty-as-sequence?"]}
      inspector["metamethod?"] = {after = inspector["metamethod?"], once = false}
      opts = inspector
    end
    return view0(seq, opts, indent)
  end
  return setmetatable({...}, {sequence = sequence_marker, __fennelview = _54_})
end
local function expr(strcode, etype)
  return setmetatable({strcode, type = etype}, expr_mt)
end
local function comment_2a(contents, _3fsource)
  local _let_55_ = (_3fsource or {})
  local filename = _let_55_["filename"]
  local line = _let_55_["line"]
  return setmetatable({contents, filename = filename, line = line}, comment_mt)
end
local function varg(_3fsource)
  local _56_
  do
    local tbl_14_auto = {"..."}
    for k, v in pairs((_3fsource or {})) do
      local k_15_auto, v_16_auto = nil, nil
      if (type(k) == "string") then
        k_15_auto, v_16_auto = k, v
      else
        k_15_auto, v_16_auto = nil
      end
      if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
        tbl_14_auto[k_15_auto] = v_16_auto
      else
      end
    end
    _56_ = tbl_14_auto
  end
  return setmetatable(_56_, varg_mt)
end
local function expr_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == expr_mt) and x)
end
local function varg_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == varg_mt) and x)
end
local function list_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == list_mt) and x)
end
local function sym_3f(x, _3fname)
  return ((type(x) == "table") and (getmetatable(x) == symbol_mt) and ((nil == _3fname) or (x[1] == _3fname)) and x)
end
local function sequence_3f(x)
  local mt = ((type(x) == "table") and getmetatable(x))
  return (mt and (mt.sequence == sequence_marker) and x)
end
local function comment_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == comment_mt) and x)
end
local function table_3f(x)
  return ((type(x) == "table") and not varg_3f(x) and (getmetatable(x) ~= list_mt) and (getmetatable(x) ~= symbol_mt) and not comment_3f(x) and x)
end
local function kv_table_3f(t)
  if table_3f(t) then
    local nxt, t0, k = pairs(t)
    local len0 = #t0
    local next_state
    if (0 == len0) then
      next_state = k
    else
      next_state = len0
    end
    return ((nil ~= nxt(t0, next_state)) and t0)
  else
    return nil
  end
end
local function string_3f(x)
  return (type(x) == "string")
end
local function multi_sym_3f(str)
  if sym_3f(str) then
    return multi_sym_3f(tostring(str))
  elseif (type(str) ~= "string") then
    return false
  else
    local function _61_()
      local parts = {}
      for part in str:gmatch("[^%.%:]+[%.%:]?") do
        local last_char = part:sub(( - 1))
        if (last_char == ":") then
          parts["multi-sym-method-call"] = true
        else
        end
        if ((last_char == ":") or (last_char == ".")) then
          parts[(#parts + 1)] = part:sub(1, ( - 2))
        else
          parts[(#parts + 1)] = part
        end
      end
      return ((0 < #parts) and parts)
    end
    return ((str:match("%.") or str:match(":")) and not str:match("%.%.") and (str:byte() ~= string.byte(".")) and (str:byte(( - 1)) ~= string.byte(".")) and _61_())
  end
end
local function quoted_3f(symbol)
  return symbol.quoted
end
local function idempotent_expr_3f(x)
  local t = type(x)
  return ((t == "string") or (t == "integer") or (t == "number") or (t == "boolean") or (sym_3f(x) and not multi_sym_3f(x)))
end
local function ast_source(ast)
  if (table_3f(ast) or sequence_3f(ast)) then
    return (getmetatable(ast) or {})
  elseif ("table" == type(ast)) then
    return ast
  else
    return {}
  end
end
local function walk_tree(root, f, _3fcustom_iterator)
  local function walk(iterfn, parent, idx, node)
    if f(idx, node, parent) then
      for k, v in iterfn(node) do
        walk(iterfn, node, k, v)
      end
      return nil
    else
      return nil
    end
  end
  walk((_3fcustom_iterator or pairs), nil, nil, root)
  return root
end
local lua_keywords = {["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true, ["goto"] = true}
local function valid_lua_identifier_3f(str)
  return (str:match("^[%a_][%w_]*$") and not lua_keywords[str])
end
local propagated_options = {"allowedGlobals", "indent", "correlate", "useMetadata", "env", "compiler-env", "compilerEnv"}
local function propagate_options(options, subopts)
  for _, name in ipairs(propagated_options) do
    subopts[name] = options[name]
  end
  return subopts
end
local root
local function _67_()
end
root = {chunk = nil, scope = nil, options = nil, reset = _67_}
root["set-reset"] = function(_68_)
  local _arg_69_ = _68_
  local chunk = _arg_69_["chunk"]
  local scope = _arg_69_["scope"]
  local options = _arg_69_["options"]
  local reset = _arg_69_["reset"]
  root.reset = function()
    root.chunk, root.scope, root.options, root.reset = chunk, scope, options, reset
    return nil
  end
  return root.reset
end
local warned = {}
local function check_plugin_version(_70_)
  local _arg_71_ = _70_
  local name = _arg_71_["name"]
  local versions = _arg_71_["versions"]
  local plugin = _arg_71_
  if (not member_3f(version:gsub("-dev", ""), (versions or {})) and not warned[plugin]) then
    warned[plugin] = true
    return warn(string.format("plugin %s does not support Fennel version %s", (name or "unknown"), version))
  else
    return nil
  end
end
local function hook_opts(event, _3foptions, ...)
  local plugins
  local function _73_(...)
    local t_74_ = _3foptions
    if (nil ~= t_74_) then
      t_74_ = (t_74_).plugins
    else
    end
    return t_74_
  end
  local function _76_(...)
    local t_77_ = root.options
    if (nil ~= t_77_) then
      t_77_ = (t_77_).plugins
    else
    end
    return t_77_
  end
  plugins = (_73_(...) or _76_(...))
  if plugins then
    local result = nil
    for _, plugin in ipairs(plugins) do
      if result then break end
      check_plugin_version(plugin)
      local _79_ = plugin[event]
      if (nil ~= _79_) then
        local f = _79_
        result = f(...)
      else
        result = nil
      end
    end
    return result
  else
    return nil
  end
end
local function hook(event, ...)
  return hook_opts(event, root.options, ...)
end
return {warn = warn, allpairs = allpairs, stablepairs = stablepairs, copy = copy, ["get-in"] = get_in, kvmap = kvmap, map = map, ["walk-tree"] = walk_tree, ["member?"] = member_3f, maxn = maxn, ["every?"] = every_3f, list = list, sequence = sequence, sym = sym, varg = varg, expr = expr, comment = comment_2a, ["comment?"] = comment_3f, ["expr?"] = expr_3f, ["list?"] = list_3f, ["multi-sym?"] = multi_sym_3f, ["sequence?"] = sequence_3f, ["sym?"] = sym_3f, ["table?"] = table_3f, ["kv-table?"] = kv_table_3f, ["varg?"] = varg_3f, ["quoted?"] = quoted_3f, ["string?"] = string_3f, ["idempotent-expr?"] = idempotent_expr_3f, ["valid-lua-identifier?"] = valid_lua_identifier_3f, ["lua-keywords"] = lua_keywords, hook = hook, ["hook-opts"] = hook_opts, ["propagate-options"] = propagate_options, root = root, ["debug-on?"] = debug_on_3f, ["ast-source"] = ast_source, version = version, ["runtime-version"] = runtime_version, len = len, path = table.concat({"./?.fnl", "./?/init.fnl", getenv("FENNEL_PATH")}, ";"), ["macro-path"] = table.concat({"./?.fnl", "./?/init-macros.fnl", "./?/init.fnl", getenv("FENNEL_MACRO_PATH")}, ";")}
