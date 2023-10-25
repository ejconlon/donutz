local type_order = {["function"] = 5, boolean = 2, number = 1, string = 3, table = 4, thread = 7, userdata = 6}
local default_opts = {["detect-cycles?"] = true, ["empty-as-sequence?"] = false, ["escape-newlines?"] = false, ["line-length"] = 80, ["max-sparse-gap"] = 10, ["metamethod?"] = true, ["one-line?"] = false, ["prefer-colon?"] = false, ["utf8?"] = true, depth = 128}
local lua_pairs = pairs
local lua_ipairs = ipairs
local function pairs(t)
  local _1_0 = getmetatable(t)
  if ((_G.type(_1_0) == "table") and (nil ~= _1_0.__pairs)) then
    local p = _1_0.__pairs
    return p(t)
  else
    local _ = _1_0
    return lua_pairs(t)
  end
end
local function ipairs(t)
  local _3_0 = getmetatable(t)
  if ((_G.type(_3_0) == "table") and (nil ~= _3_0.__ipairs)) then
    local i = _3_0.__ipairs
    return i(t)
  else
    local _ = _3_0
    return lua_ipairs(t)
  end
end
local function length_2a(t)
  local _5_0 = getmetatable(t)
  if ((_G.type(_5_0) == "table") and (nil ~= _5_0.__len)) then
    local l = _5_0.__len
    return l(t)
  else
    local _ = _5_0
    return #t
  end
end
local function get_default(key)
  local _7_0 = default_opts[key]
  if (_7_0 == nil) then
    return error(("option '%s' doesn't have a default value, use the :after key to set it"):format(tostring(key)))
  elseif (nil ~= _7_0) then
    local v = _7_0
    return v
  end
end
local function getopt(options, key)
  local _9_0 = options[key]
  if ((_G.type(_9_0) == "table") and (nil ~= _9_0.once)) then
    local val_2a = _9_0.once
    return val_2a
  else
    local _3fval = _9_0
    return _3fval
  end
end
local function normalize_opts(options)
  local tbl_14_ = {}
  for k, v in pairs(options) do
    local k_15_, v_16_ = nil, nil
    local function _12_()
      local _11_0 = v
      if ((_G.type(_11_0) == "table") and (nil ~= _11_0.after)) then
        local val = _11_0.after
        return val
      else
        local function _13_()
          return v.once
        end
        if ((_G.type(_11_0) == "table") and _13_()) then
          return get_default(k)
        else
          local _ = _11_0
          return v
        end
      end
    end
    k_15_, v_16_ = k, _12_()
    if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
      tbl_14_[k_15_] = v_16_
    end
  end
  return tbl_14_
end
local function sort_keys(_16_0, _18_0)
  local _17_ = _16_0
  local a = _17_[1]
  local _19_ = _18_0
  local b = _19_[1]
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
    for _, _22_0 in ipairs(kv) do
      local _23_ = _22_0
      local k = _23_[1]
      if (gap < (k - i)) then
        gap = (k - i)
      end
      i = k
    end
  end
  return gap
end
local function fill_gaps(kv)
  local missing_indexes = {}
  local i = 0
  for _, _26_0 in ipairs(kv) do
    local _27_ = _26_0
    local j = _27_[1]
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
  end
  if (length_2a(kv) == 0) then
    return kv, "empty"
  else
    local function _31_()
      if assoc_3f then
        return "table"
      else
        return "seq"
      end
    end
    return kv, _31_()
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
  end
  return appearances
end
local function save_table(t, seen)
  local seen0 = (seen or {len = 0})
  local id = (seen0.len + 1)
  if not seen0[t] then
    seen0[t] = id
    seen0.len = id
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
  end
end
local function visible_cycle_3f(t, options)
  return (getopt(options, "detect-cycles?") and detect_cycle(t, {}) and save_table(t, options.seen) and (1 < (options.appearances[t] or 0)))
end
local function table_indent(indent, id)
  local opener_length = nil
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
  local open = nil
  local function _38_()
    if ("seq" == table_type) then
      return "["
    else
      return "{"
    end
  end
  open = ((prefix or "") .. _38_())
  local close = nil
  if ("seq" == table_type) then
    close = "]"
  else
    close = "}"
  end
  local oneline = (open .. table.concat(elements, " ") .. close)
  if (not getopt(options, "one-line?") and (multiline_3f or (options["line-length"] < (indent + length_2a(oneline))) or last_comment_3f)) then
    local function _40_()
      if last_comment_3f then
        return indent_str
      else
        return ""
      end
    end
    return (open .. table.concat(elements, indent_str) .. _40_() .. close)
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
    local slength = nil
    if getopt(options, "utf8?") then
      slength = utf8_len
    else
      local function _43_(_241)
        return #_241
      end
      slength = _43_
    end
    local prefix = nil
    if visible_cycle_3f0 then
      prefix = ("@" .. id0)
    else
      prefix = ""
    end
    local items = nil
    do
      local options0 = normalize_opts(options)
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, _46_0 in ipairs(kv) do
        local _47_ = _46_0
        local k = _47_[1]
        local v = _47_[2]
        local val_19_ = nil
        do
          local k0 = pp(k, options0, (indent0 + 1), true)
          local v0 = pp(v, options0, (indent0 + slength(k0) + 1))
          multiline_3f = (multiline_3f or k0:find("\n") or v0:find("\n"))
          val_19_ = (k0 .. " " .. v0)
        end
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      items = tbl_17_
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
    local prefix = nil
    if visible_cycle_3f0 then
      prefix = ("@" .. id0)
    else
      prefix = ""
    end
    local last_comment_3f = comment_3f(t[#t])
    local items = nil
    do
      local options0 = normalize_opts(options)
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, _51_0 in ipairs(kv) do
        local _52_ = _51_0
        local _0 = _52_[1]
        local v = _52_[2]
        local val_19_ = nil
        do
          local v0 = pp(v, options0, indent0)
          multiline_3f = (multiline_3f or v0:find("\n") or v0:find("^;"))
          val_19_ = v0
        end
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      items = tbl_17_
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
    local oneline = nil
    local _56_
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, line in ipairs(lines) do
        local val_19_ = line:gsub("^%s+", "")
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      _56_ = tbl_17_
    end
    oneline = table.concat(_56_, " ")
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
    local _ = nil
    local function _61_(_241)
      return visible_cycle_3f(_241, options)
    end
    options["visible-cycle?"] = _61_
    _ = nil
    local lines, force_multi_line_3f = nil, nil
    do
      local options0 = normalize_opts(options)
      lines, force_multi_line_3f = metamethod(t, pp, options0, indent)
    end
    options["visible-cycle?"] = nil
    local _62_0 = type(lines)
    if (_62_0 == "string") then
      return lines
    elseif (_62_0 == "table") then
      return concat_lines(lines, options, indent, force_multi_line_3f)
    else
      local _0 = _62_0
      return error("__fennelview metamethod must return a table of lines")
    end
  end
end
local function pp_table(x, options, indent)
  options.level = (options.level + 1)
  local x0 = nil
  do
    local _65_0 = nil
    if getopt(options, "metamethod?") then
      local _66_0 = x
      if (nil ~= _66_0) then
        local _67_0 = getmetatable(_66_0)
        if (nil ~= _67_0) then
          _65_0 = _67_0.__fennelview
        else
          _65_0 = _67_0
        end
      else
        _65_0 = _66_0
      end
    else
    _65_0 = nil
    end
    if (nil ~= _65_0) then
      local metamethod = _65_0
      x0 = pp_metamethod(x, metamethod, options, indent)
    else
      local _ = _65_0
      local _71_0, _72_0 = table_kv_pairs(x, options)
      if (true and (_72_0 == "empty")) then
        local _0 = _71_0
        if getopt(options, "empty-as-sequence?") then
          x0 = "[]"
        else
          x0 = "{}"
        end
      elseif ((nil ~= _71_0) and (_72_0 == "table")) then
        local kv = _71_0
        x0 = pp_associative(x, kv, options, indent)
      elseif ((nil ~= _71_0) and (_72_0 == "seq")) then
        local kv = _71_0
        x0 = pp_sequence(x, kv, options, indent)
      else
      x0 = nil
      end
    end
  end
  options.level = (options.level - 1)
  return x0
end
local function number__3estring(n)
  local _76_0 = string.gsub(tostring(n), ",", ".")
  return _76_0
end
local function colon_string_3f(s)
  return s:find("^[-%w?^_!$%&*+./|<=>]+$")
end
local utf8_inits = {{["max-byte"] = 127, ["max-code"] = 127, ["min-byte"] = 0, ["min-code"] = 0, len = 1}, {["max-byte"] = 223, ["max-code"] = 2047, ["min-byte"] = 192, ["min-code"] = 128, len = 2}, {["max-byte"] = 239, ["max-code"] = 65535, ["min-byte"] = 224, ["min-code"] = 2048, len = 3}, {["max-byte"] = 247, ["max-code"] = 1114111, ["min-byte"] = 240, ["min-code"] = 65536, len = 4}}
local function default_byte_escape(byte, _options)
  return ("\\%03d"):format(byte)
end
local function utf8_escape(str, options)
  local function validate_utf8(str0, index)
    local inits = utf8_inits
    local byte = string.byte(str0, index)
    local init = nil
    do
      local ret = nil
      for _, init0 in ipairs(inits) do
        if ret then break end
        ret = (byte and (function(_77_,_78_,_79_) return (_77_ <= _78_) and (_78_ <= _79_) end)(init0["min-byte"],byte,init0["max-byte"]) and init0)
      end
      init = ret
    end
    local code = nil
    local function _80_()
      local code0 = nil
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
    code = (init and _80_())
    if (code and (function(_82_,_83_,_84_) return (_82_ <= _83_) and (_83_ <= _84_) end)(init["min-code"],code,init["max-code"]) and not ((55296 <= code) and (code <= 57343))) then
      return init.len
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
  local escs = nil
  local _88_
  if esc_newline_3f then
    _88_ = "\\n"
  else
    _88_ = "\n"
  end
  local function _90_(_241, _242)
    return byte_escape(_242:byte(), options)
  end
  escs = setmetatable({["\""] = "\\\"", ["\11"] = "\\v", ["\12"] = "\\f", ["\13"] = "\\r", ["\7"] = "\\a", ["\8"] = "\\b", ["\9"] = "\\t", ["\\"] = "\\\\", ["\n"] = _88_}, {__index = _90_})
  local str0 = ("\"" .. str:gsub("[%c\\\"]", escs) .. "\"")
  if getopt(options, "utf8?") then
    return utf8_escape(str0, options)
  else
    return str0
  end
end
local function make_options(t, options)
  local defaults = nil
  do
    local tbl_14_ = {}
    for k, v in pairs(default_opts) do
      local k_15_, v_16_ = k, v
      if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
        tbl_14_[k_15_] = v_16_
      end
    end
    defaults = tbl_14_
  end
  local overrides = {appearances = count_table_appearances(t, {}), level = 0, seen = {len = 0}}
  for k, v in pairs((options or {})) do
    defaults[k] = v
  end
  for k, v in pairs(overrides) do
    defaults[k] = v
  end
  return defaults
end
local function _93_(x, options, indent, colon_3f)
  local indent0 = (indent or 0)
  local options0 = (options or make_options(x))
  local x0 = nil
  if options0.preprocess then
    x0 = options0.preprocess(x, options0)
  else
    x0 = x
  end
  local tv = type(x0)
  local function _96_()
    local _95_0 = getmetatable(x0)
    if ((_G.type(_95_0) == "table") and true) then
      local __fennelview = _95_0.__fennelview
      return __fennelview
    end
  end
  if ((tv == "table") or ((tv == "userdata") and _96_())) then
    return pp_table(x0, options0, indent0)
  elseif (tv == "number") then
    return number__3estring(x0)
  else
    local function _98_()
      if (colon_3f ~= nil) then
        return colon_3f
      elseif ("function" == type(options0["prefer-colon?"])) then
        return options0["prefer-colon?"](x0)
      else
        return getopt(options0, "prefer-colon?")
      end
    end
    if ((tv == "string") and colon_string_3f(x0) and _98_()) then
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
pp = _93_
local function view(x, _3foptions)
  return pp(x, make_options(x, _3foptions), 0)
end
return view
