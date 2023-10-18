local type_order = {number = 1, boolean = 2, string = 3, table = 4, ["function"] = 5, userdata = 6, thread = 7}
local default_opts = {["detect-cycles?"] = true, ["metamethod?"] = true, ["utf8?"] = true, ["line-length"] = 80, depth = 128, ["max-sparse-gap"] = 10, ["empty-as-sequence?"] = false, ["escape-newlines?"] = false, ["one-line?"] = false, ["prefer-colon?"] = false}
local lua_pairs = pairs
local lua_ipairs = ipairs
local function pairs(t)
  local _1_ = getmetatable(t)
  if ((_G.type(_1_) == "table") and (nil ~= (_1_).__pairs)) then
    local p = (_1_).__pairs
    return p(t)
  elseif true then
    local _ = _1_
    return lua_pairs(t)
  else
    return nil
  end
end
local function ipairs(t)
  local _3_ = getmetatable(t)
  if ((_G.type(_3_) == "table") and (nil ~= (_3_).__ipairs)) then
    local i = (_3_).__ipairs
    return i(t)
  elseif true then
    local _ = _3_
    return lua_ipairs(t)
  else
    return nil
  end
end
local function length_2a(t)
  local _5_ = getmetatable(t)
  if ((_G.type(_5_) == "table") and (nil ~= (_5_).__len)) then
    local l = (_5_).__len
    return l(t)
  elseif true then
    local _ = _5_
    return #t
  else
    return nil
  end
end
local function get_default(key)
  local _7_ = default_opts[key]
  if (_7_ == nil) then
    return error(("option '%s' doesn't have a default value, use the :after key to set it"):format(tostring(key)))
  elseif (nil ~= _7_) then
    local v = _7_
    return v
  else
    return nil
  end
end
local function getopt(options, key)
  local _9_ = options[key]
  if ((_G.type(_9_) == "table") and (nil ~= (_9_).once)) then
    local val_2a = (_9_).once
    return val_2a
  elseif true then
    local _3fval = _9_
    return _3fval
  else
    return nil
  end
end
local function normalize_opts(options)
  local tbl_14_auto = {}
  for k, v in pairs(options) do
    local k_15_auto, v_16_auto = nil, nil
    local function _12_()
      if ((_G.type(v) == "table") and (nil ~= v.after)) then
        local val = v.after
        return val
      else
        local function _11_()
          return v.once
        end
        if ((_G.type(v) == "table") and _11_()) then
          return get_default(k)
        elseif true then
          local _ = v
          return v
        else
          return nil
        end
      end
    end
    k_15_auto, v_16_auto = k, _12_()
    if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
      tbl_14_auto[k_15_auto] = v_16_auto
    else
    end
  end
  return tbl_14_auto
end
local function sort_keys(_14_, _16_)
  local _arg_15_ = _14_
  local a = _arg_15_[1]
  local _arg_17_ = _16_
  local b = _arg_17_[1]
  local ta = type(a)
  local tb = type(b)
  if ((ta == tb) and ((ta == "string") or (ta == "number"))) then
    return (a < b)
  else
    local dta = type_order[ta]
    local dtb = type_order[tb]
    if (dta and dtb) then
      return (dta < dtb)
    elseif dta then
      return true
    elseif dtb then
      return false
    else
      return (ta < tb)
    end
  end
end
local function max_index_gap(kv)
  local gap = 0
  if (0 < length_2a(kv)) then
    local i = 0
    for _, _20_ in ipairs(kv) do
      local _each_21_ = _20_
      local k = _each_21_[1]
      if (gap < (k - i)) then
        gap = (k - i)
      else
      end
      i = k
    end
  else
  end
  return gap
end
local function fill_gaps(kv)
  local missing_indexes = {}
  local i = 0
  for _, _24_ in ipairs(kv) do
    local _each_25_ = _24_
    local j = _each_25_[1]
    i = (i + 1)
    while (i < j) do
      table.insert(missing_indexes, i)
      i = (i + 1)
    end
  end
  for _, k in ipairs(missing_indexes) do
    table.insert(kv, k, {k})
  end
  return nil
end
local function table_kv_pairs(t, options)
  local assoc_3f = false
  local kv = {}
  local insert = table.insert
  for k, v in pairs(t) do
    if ((type(k) ~= "number") or (k < 1)) then
      assoc_3f = true
    else
    end
    insert(kv, {k, v})
  end
  table.sort(kv, sort_keys)
  if not assoc_3f then
    if (options["max-sparse-gap"] < max_index_gap(kv)) then
      assoc_3f = true
    else
      fill_gaps(kv)
    end
  else
  end
  if (length_2a(kv) == 0) then
    return kv, "empty"
  else
    local function _29_()
      if assoc_3f then
        return "table"
      else
        return "seq"
      end
    end
    return kv, _29_()
  end
end
local function count_table_appearances(t, appearances)
  if (type(t) == "table") then
    if not appearances[t] then
      appearances[t] = 1
      for k, v in pairs(t) do
        count_table_appearances(k, appearances)
        count_table_appearances(v, appearances)
      end
    else
      appearances[t] = ((appearances[t] or 0) + 1)
    end
  else
  end
  return appearances
end
local function save_table(t, seen)
  local seen0 = (seen or {len = 0})
  local id = (seen0.len + 1)
  if not (seen0)[t] then
    seen0[t] = id
    seen0.len = id
  else
  end
  return seen0
end
local function detect_cycle(t, seen)
  if ("table" == type(t)) then
    seen[t] = true
    local res = nil
    for k, v in pairs(t) do
      if res then break end
      res = (seen[k] or detect_cycle(k, seen) or seen[v] or detect_cycle(v, seen))
    end
    return res
  else
    return nil
  end
end
local function visible_cycle_3f(t, options)
  return (getopt(options, "detect-cycles?") and detect_cycle(t, {}) and save_table(t, options.seen) and (1 < (options.appearances[t] or 0)))
end
local function table_indent(indent, id)
  local opener_length
  if id then
    opener_length = (length_2a(tostring(id)) + 2)
  else
    opener_length = 1
  end
  return (indent + opener_length)
end
local pp = nil
local function concat_table_lines(elements, options, multiline_3f, indent, table_type, prefix, last_comment_3f)
  local indent_str = ("\n" .. string.rep(" ", indent))
  local open
  local function _36_()
    if ("seq" == table_type) then
      return "["
    else
      return "{"
    end
  end
  open = ((prefix or "") .. _36_())
  local close
  if ("seq" == table_type) then
    close = "]"
  else
    close = "}"
  end
  local oneline = (open .. table.concat(elements, " ") .. close)
  if (not getopt(options, "one-line?") and (multiline_3f or (options["line-length"] < (indent + length_2a(oneline))) or last_comment_3f)) then
    local function _38_()
      if last_comment_3f then
        return indent_str
      else
        return ""
      end
    end
    return (open .. table.concat(elements, indent_str) .. _38_() .. close)
  else
    return oneline
  end
end
local function utf8_len(x)
  local n = 0
  for _ in string.gmatch(x, "[%z\1-\127\192-\247]") do
    n = (n + 1)
  end
  return n
end
local function comment_3f(x)
  if ("table" == type(x)) then
    local fst = x[1]
    return (("string" == type(fst)) and (nil ~= fst:find("^;")))
  else
    return false
  end
end
local function pp_associative(t, kv, options, indent)
  local multiline_3f = false
  local id = options.seen[t]
  if (options.depth <= options.level) then
    return "{...}"
  elseif (id and getopt(options, "detect-cycles?")) then
    return ("@" .. id .. "{...}")
  else
    local visible_cycle_3f0 = visible_cycle_3f(t, options)
    local id0 = (visible_cycle_3f0 and options.seen[t])
    local indent0 = table_indent(indent, id0)
    local slength
    if getopt(options, "utf8?") then
      slength = utf8_len
    else
      local function _41_(_241)
        return #_241
      end
      slength = _41_
    end
    local prefix
    if visible_cycle_3f0 then
      prefix = ("@" .. id0)
    else
      prefix = ""
    end
    local items
    do
      local options0 = normalize_opts(options)
      local tbl_17_auto = {}
      local i_18_auto = #tbl_17_auto
      for _, _44_ in ipairs(kv) do
        local _each_45_ = _44_
        local k = _each_45_[1]
        local v = _each_45_[2]
        local val_19_auto
        do
          local k0 = pp(k, options0, (indent0 + 1), true)
          local v0 = pp(v, options0, (indent0 + slength(k0) + 1))
          multiline_3f = (multiline_3f or k0:find("\n") or v0:find("\n"))
          val_19_auto = (k0 .. " " .. v0)
        end
        if (nil ~= val_19_auto) then
          i_18_auto = (i_18_auto + 1)
          do end (tbl_17_auto)[i_18_auto] = val_19_auto
        else
        end
      end
      items = tbl_17_auto
    end
    return concat_table_lines(items, options, multiline_3f, indent0, "table", prefix, false)
  end
end
local function pp_sequence(t, kv, options, indent)
  local multiline_3f = false
  local id = options.seen[t]
  if (options.depth <= options.level) then
    return "[...]"
  elseif (id and getopt(options, "detect-cycles?")) then
    return ("@" .. id .. "[...]")
  else
    local visible_cycle_3f0 = visible_cycle_3f(t, options)
    local id0 = (visible_cycle_3f0 and options.seen[t])
    local indent0 = table_indent(indent, id0)
    local prefix
    if visible_cycle_3f0 then
      prefix = ("@" .. id0)
    else
      prefix = ""
    end
    local last_comment_3f = comment_3f(t[#t])
    local items
    do
      local options0 = normalize_opts(options)
      local tbl_17_auto = {}
      local i_18_auto = #tbl_17_auto
      for _, _49_ in ipairs(kv) do
        local _each_50_ = _49_
        local _0 = _each_50_[1]
        local v = _each_50_[2]
        local val_19_auto
        do
          local v0 = pp(v, options0, indent0)
          multiline_3f = (multiline_3f or v0:find("\n") or v0:find("^;"))
          val_19_auto = v0
        end
        if (nil ~= val_19_auto) then
          i_18_auto = (i_18_auto + 1)
          do end (tbl_17_auto)[i_18_auto] = val_19_auto
        else
        end
      end
      items = tbl_17_auto
    end
    return concat_table_lines(items, options, multiline_3f, indent0, "seq", prefix, last_comment_3f)
  end
end
local function concat_lines(lines, options, indent, force_multi_line_3f)
  if (length_2a(lines) == 0) then
    if getopt(options, "empty-as-sequence?") then
      return "[]"
    else
      return "{}"
    end
  else
    local oneline
    local _54_
    do
      local tbl_17_auto = {}
      local i_18_auto = #tbl_17_auto
      for _, line in ipairs(lines) do
        local val_19_auto = line:gsub("^%s+", "")
        if (nil ~= val_19_auto) then
          i_18_auto = (i_18_auto + 1)
          do end (tbl_17_auto)[i_18_auto] = val_19_auto
        else
        end
      end
      _54_ = tbl_17_auto
    end
    oneline = table.concat(_54_, " ")
    if (not getopt(options, "one-line?") and (force_multi_line_3f or oneline:find("\n") or (options["line-length"] < (indent + length_2a(oneline))))) then
      return table.concat(lines, ("\n" .. string.rep(" ", indent)))
    else
      return oneline
    end
  end
end
local function pp_metamethod(t, metamethod, options, indent)
  if (options.depth <= options.level) then
    if getopt(options, "empty-as-sequence?") then
      return "[...]"
    else
      return "{...}"
    end
  else
    local _
    local function _59_(_241)
      return visible_cycle_3f(_241, options)
    end
    options["visible-cycle?"] = _59_
    _ = nil
    local lines, force_multi_line_3f = nil, nil
    do
      local options0 = normalize_opts(options)
      lines, force_multi_line_3f = metamethod(t, pp, options0, indent)
    end
    options["visible-cycle?"] = nil
    local _60_ = type(lines)
    if (_60_ == "string") then
      return lines
    elseif (_60_ == "table") then
      return concat_lines(lines, options, indent, force_multi_line_3f)
    elseif true then
      local _0 = _60_
      return error("__fennelview metamethod must return a table of lines")
    else
      return nil
    end
  end
end
local function pp_table(x, options, indent)
  options.level = (options.level + 1)
  local x0
  do
    local _63_
    if getopt(options, "metamethod?") then
      local _64_ = x
      if (nil ~= _64_) then
        local _65_ = getmetatable(_64_)
        if (nil ~= _65_) then
          _63_ = (_65_).__fennelview
        else
          _63_ = _65_
        end
      else
        _63_ = _64_
      end
    else
      _63_ = nil
    end
    if (nil ~= _63_) then
      local metamethod = _63_
      x0 = pp_metamethod(x, metamethod, options, indent)
    elseif true then
      local _ = _63_
      local _69_, _70_ = table_kv_pairs(x, options)
      if (true and (_70_ == "empty")) then
        local _0 = _69_
        if getopt(options, "empty-as-sequence?") then
          x0 = "[]"
        else
          x0 = "{}"
        end
      elseif ((nil ~= _69_) and (_70_ == "table")) then
        local kv = _69_
        x0 = pp_associative(x, kv, options, indent)
      elseif ((nil ~= _69_) and (_70_ == "seq")) then
        local kv = _69_
        x0 = pp_sequence(x, kv, options, indent)
      else
        x0 = nil
      end
    else
      x0 = nil
    end
  end
  options.level = (options.level - 1)
  return x0
end
local function number__3estring(n)
  local _74_ = string.gsub(tostring(n), ",", ".")
  return _74_
end
local function colon_string_3f(s)
  return s:find("^[-%w?^_!$%&*+./|<=>]+$")
end
local utf8_inits = {{["min-byte"] = 0, ["max-byte"] = 127, ["min-code"] = 0, ["max-code"] = 127, len = 1}, {["min-byte"] = 192, ["max-byte"] = 223, ["min-code"] = 128, ["max-code"] = 2047, len = 2}, {["min-byte"] = 224, ["max-byte"] = 239, ["min-code"] = 2048, ["max-code"] = 65535, len = 3}, {["min-byte"] = 240, ["max-byte"] = 247, ["min-code"] = 65536, ["max-code"] = 1114111, len = 4}}
local function default_byte_escape(byte, _options)
  return ("\\%03d"):format(byte)
end
local function utf8_escape(str, options)
  local function validate_utf8(str0, index)
    local inits = utf8_inits
    local byte = string.byte(str0, index)
    local init
    do
      local ret = nil
      for _, init0 in ipairs(inits) do
        if ret then break end
        ret = (byte and (function(_75_,_76_,_77_) return (_75_ <= _76_) and (_76_ <= _77_) end)(init0["min-byte"],byte,init0["max-byte"]) and init0)
      end
      init = ret
    end
    local code
    local function _78_()
      local code0
      if init then
        code0 = (byte - init["min-byte"])
      else
        code0 = nil
      end
      for i = (index + 1), (index + init.len + -1) do
        local byte0 = string.byte(str0, i)
        code0 = (byte0 and code0 and ((128 <= byte0) and (byte0 <= 191)) and ((code0 * 64) + (byte0 - 128)))
      end
      return code0
    end
    code = (init and _78_())
    if (code and (function(_80_,_81_,_82_) return (_80_ <= _81_) and (_81_ <= _82_) end)(init["min-code"],code,init["max-code"]) and not ((55296 <= code) and (code <= 57343))) then
      return init.len
    else
      return nil
    end
  end
  local index = 1
  local output = {}
  local byte_escape = (getopt(options, "byte-escape") or default_byte_escape)
  while (index <= #str) do
    local nexti = (string.find(str, "[\128-\255]", index) or (#str + 1))
    local len = validate_utf8(str, nexti)
    table.insert(output, string.sub(str, index, (nexti + (len or 0) + -1)))
    if (not len and (nexti <= #str)) then
      table.insert(output, byte_escape(str:byte(nexti), options))
    else
    end
    if len then
      index = (nexti + len)
    else
      index = (nexti + 1)
    end
  end
  return table.concat(output)
end
local function pp_string(str, options, indent)
  local len = length_2a(str)
  local esc_newline_3f = ((len < 2) or (getopt(options, "escape-newlines?") and (len < (options["line-length"] - indent))))
  local byte_escape = (getopt(options, "byte-escape") or default_byte_escape)
  local escs
  local _86_
  if esc_newline_3f then
    _86_ = "\\n"
  else
    _86_ = "\n"
  end
  local function _88_(_241, _242)
    return byte_escape(_242:byte(), options)
  end
  escs = setmetatable({["\7"] = "\\a", ["\8"] = "\\b", ["\12"] = "\\f", ["\11"] = "\\v", ["\13"] = "\\r", ["\9"] = "\\t", ["\\"] = "\\\\", ["\""] = "\\\"", ["\n"] = _86_}, {__index = _88_})
  local str0 = ("\"" .. str:gsub("[%c\\\"]", escs) .. "\"")
  if getopt(options, "utf8?") then
    return utf8_escape(str0, options)
  else
    return str0
  end
end
local function make_options(t, options)
  local defaults
  do
    local tbl_14_auto = {}
    for k, v in pairs(default_opts) do
      local k_15_auto, v_16_auto = k, v
      if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
        tbl_14_auto[k_15_auto] = v_16_auto
      else
      end
    end
    defaults = tbl_14_auto
  end
  local overrides = {level = 0, appearances = count_table_appearances(t, {}), seen = {len = 0}}
  for k, v in pairs((options or {})) do
    defaults[k] = v
  end
  for k, v in pairs(overrides) do
    defaults[k] = v
  end
  return defaults
end
local function _91_(x, options, indent, colon_3f)
  local indent0 = (indent or 0)
  local options0 = (options or make_options(x))
  local x0
  if options0.preprocess then
    x0 = options0.preprocess(x, options0)
  else
    x0 = x
  end
  local tv = type(x0)
  local function _93_()
    local _94_ = getmetatable(x0)
    if ((_G.type(_94_) == "table") and true) then
      local __fennelview = (_94_).__fennelview
      return __fennelview
    else
      return nil
    end
  end
  if ((tv == "table") or ((tv == "userdata") and _93_())) then
    return pp_table(x0, options0, indent0)
  elseif (tv == "number") then
    return number__3estring(x0)
  else
    local function _96_()
      if (colon_3f ~= nil) then
        return colon_3f
      elseif ("function" == type(options0["prefer-colon?"])) then
        return options0["prefer-colon?"](x0)
      else
        return getopt(options0, "prefer-colon?")
      end
    end
    if ((tv == "string") and colon_string_3f(x0) and _96_()) then
      return (":" .. x0)
    elseif (tv == "string") then
      return pp_string(x0, options0, indent0)
    elseif ((tv == "boolean") or (tv == "nil")) then
      return tostring(x0)
    else
      return ("#<" .. tostring(x0) .. ">")
    end
  end
end
pp = _91_
local function view(x, _3foptions)
  return pp(x, make_options(x, _3foptions), 0)
end
return view
