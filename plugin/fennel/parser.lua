local utils = require("fennel.utils")
local friend = require("fennel.friend")
local unpack = (table.unpack or _G.unpack)
local function granulate(getchunk)
  local c, index, done_3f = "", 1, false
  local function _1_(parser_state)
    if not done_3f then
      if (index <= #c) then
        local b = c:byte(index)
        index = (index + 1)
        return b
      else
        local _2_ = getchunk(parser_state)
        local function _3_()
          local char = _2_
          return (char ~= "")
        end
        if ((nil ~= _2_) and _3_()) then
          local char = _2_
          c = char
          index = 2
          return c:byte()
        elseif true then
          local _ = _2_
          done_3f = true
          return nil
        else
          return nil
        end
      end
    else
      return nil
    end
  end
  local function _7_()
    c = ""
    return nil
  end
  return _1_, _7_
end
local function string_stream(str, _3foptions)
  local str0 = str:gsub("^#!", ";;")
  if _3foptions then
    _3foptions.source = str0
  else
  end
  local index = 1
  local function _9_()
    local r = str0:byte(index)
    index = (index + 1)
    return r
  end
  return _9_
end
local delims = {[40] = 41, [41] = true, [91] = 93, [93] = true, [123] = 125, [125] = true}
local function sym_char_3f(b)
  local b0
  if ("number" == type(b)) then
    b0 = b
  else
    b0 = string.byte(b)
  end
  return ((32 < b0) and not delims[b0] and (b0 ~= 127) and (b0 ~= 34) and (b0 ~= 39) and (b0 ~= 126) and (b0 ~= 59) and (b0 ~= 44) and (b0 ~= 64) and (b0 ~= 96))
end
local prefixes = {[35] = "hashfn", [39] = "quote", [44] = "unquote", [96] = "quote"}
local function char_starter_3f(b)
  return (((1 < b) and (b < 127)) or ((192 < b) and (b < 247)))
end
local function parser_fn(getbyte, filename, _11_)
  local _arg_12_ = _11_
  local source = _arg_12_["source"]
  local unfriendly = _arg_12_["unfriendly"]
  local comments = _arg_12_["comments"]
  local options = _arg_12_
  local stack = {}
  local line, byteindex, col, prev_col, lastb = 1, 0, 0, 0, nil
  local function ungetb(ub)
    if char_starter_3f(ub) then
      col = (col - 1)
    else
    end
    if (ub == 10) then
      line, col = (line - 1), prev_col
    else
    end
    byteindex = (byteindex - 1)
    lastb = ub
    return nil
  end
  local function getb()
    local r = nil
    if lastb then
      r, lastb = lastb, nil
    else
      r = getbyte({["stack-size"] = #stack})
    end
    if r then
      byteindex = (byteindex + 1)
    else
    end
    if (r and char_starter_3f(r)) then
      col = (col + 1)
    else
    end
    if (r == 10) then
      line, col, prev_col = (line + 1), 0, col
    else
    end
    return r
  end
  local function whitespace_3f(b)
    local function _19_()
      local t_20_ = options.whitespace
      if (nil ~= t_20_) then
        t_20_ = (t_20_)[b]
      else
      end
      return t_20_
    end
    return ((b == 32) or ((9 <= b) and (b <= 13)) or _19_())
  end
  local function parse_error(msg, _3fcol_adjust)
    local col0 = (col + (_3fcol_adjust or -1))
    if (nil == utils["hook-opts"]("parse-error", options, msg, filename, (line or "?"), col0, source, utils.root.reset)) then
      utils.root.reset()
      if unfriendly then
        return error(string.format("%s:%s:%s Parse error: %s", filename, (line or "?"), col0, msg), 0)
      else
        return friend["parse-error"](msg, filename, (line or "?"), col0, source, options)
      end
    else
      return nil
    end
  end
  local function parse_stream()
    local whitespace_since_dispatch, done_3f, retval = true
    local function set_source_fields(source0)
      source0.byteend, source0.endcol, source0.endline = byteindex, (col - 1), line
      return nil
    end
    local function dispatch(v)
      local _24_ = stack[#stack]
      if (_24_ == nil) then
        retval, done_3f, whitespace_since_dispatch = v, true, false
        return nil
      elseif ((_G.type(_24_) == "table") and (nil ~= (_24_).prefix)) then
        local prefix = (_24_).prefix
        local source0
        do
          local _25_ = table.remove(stack)
          set_source_fields(_25_)
          source0 = _25_
        end
        local list = utils.list(utils.sym(prefix, source0), v)
        for k, v0 in pairs(source0) do
          list[k] = v0
        end
        return dispatch(list)
      elseif (nil ~= _24_) then
        local top = _24_
        whitespace_since_dispatch = false
        return table.insert(top, v)
      else
        return nil
      end
    end
    local function badend()
      local accum = utils.map(stack, "closer")
      local _27_
      if (#stack == 1) then
        _27_ = ""
      else
        _27_ = "s"
      end
      return parse_error(string.format("expected closing delimiter%s %s", _27_, string.char(unpack(accum))))
    end
    local function skip_whitespace(b)
      if (b and whitespace_3f(b)) then
        whitespace_since_dispatch = true
        return skip_whitespace(getb())
      elseif (not b and (0 < #stack)) then
        return badend()
      else
        return b
      end
    end
    local function parse_comment(b, contents)
      if (b and (10 ~= b)) then
        local function _30_()
          table.insert(contents, string.char(b))
          return contents
        end
        return parse_comment(getb(), _30_())
      elseif comments then
        ungetb(10)
        return dispatch(utils.comment(table.concat(contents), {line = line, filename = filename}))
      else
        return nil
      end
    end
    local function open_table(b)
      if not whitespace_since_dispatch then
        parse_error(("expected whitespace before opening delimiter " .. string.char(b)))
      else
      end
      return table.insert(stack, {bytestart = byteindex, closer = delims[b], filename = filename, line = line, col = (col - 1)})
    end
    local function close_list(list)
      return dispatch(setmetatable(list, getmetatable(utils.list())))
    end
    local function close_sequence(tbl)
      local mt = getmetatable(utils.sequence())
      for k, v in pairs(tbl) do
        if ("number" ~= type(k)) then
          mt[k] = v
          tbl[k] = nil
        else
        end
      end
      return dispatch(setmetatable(tbl, mt))
    end
    local function add_comment_at(comments0, index, node)
      local _34_ = (comments0)[index]
      if (nil ~= _34_) then
        local existing = _34_
        return table.insert(existing, node)
      elseif true then
        local _ = _34_
        comments0[index] = {node}
        return nil
      else
        return nil
      end
    end
    local function next_noncomment(tbl, i)
      if utils["comment?"](tbl[i]) then
        return next_noncomment(tbl, (i + 1))
      elseif utils["sym?"](tbl[i], ":") then
        return tostring(tbl[(i + 1)])
      else
        return tbl[i]
      end
    end
    local function extract_comments(tbl)
      local comments0 = {keys = {}, values = {}, last = {}}
      while utils["comment?"](tbl[#tbl]) do
        table.insert(comments0.last, 1, table.remove(tbl))
      end
      local last_key_3f = false
      for i, node in ipairs(tbl) do
        if not utils["comment?"](node) then
          last_key_3f = not last_key_3f
        elseif last_key_3f then
          add_comment_at(comments0.values, next_noncomment(tbl, i), node)
        else
          add_comment_at(comments0.keys, next_noncomment(tbl, i), node)
        end
      end
      for i = #tbl, 1, -1 do
        if utils["comment?"](tbl[i]) then
          table.remove(tbl, i)
        else
        end
      end
      return comments0
    end
    local function close_curly_table(tbl)
      local comments0 = extract_comments(tbl)
      local keys = {}
      local val = {}
      if ((#tbl % 2) ~= 0) then
        byteindex = (byteindex - 1)
        parse_error("expected even number of values in table literal")
      else
      end
      setmetatable(val, tbl)
      for i = 1, #tbl, 2 do
        if ((tostring(tbl[i]) == ":") and utils["sym?"](tbl[(i + 1)]) and utils["sym?"](tbl[i])) then
          tbl[i] = tostring(tbl[(i + 1)])
        else
        end
        val[tbl[i]] = tbl[(i + 1)]
        table.insert(keys, tbl[i])
      end
      tbl.comments = comments0
      tbl.keys = keys
      return dispatch(val)
    end
    local function close_table(b)
      local top = table.remove(stack)
      if (top == nil) then
        parse_error(("unexpected closing delimiter " .. string.char(b)))
      else
      end
      if (top.closer and (top.closer ~= b)) then
        parse_error(("mismatched closing delimiter " .. string.char(b) .. ", expected " .. string.char(top.closer)))
      else
      end
      set_source_fields(top)
      if (b == 41) then
        return close_list(top)
      elseif (b == 93) then
        return close_sequence(top)
      else
        return close_curly_table(top)
      end
    end
    local function parse_string_loop(chars, b, state)
      if b then
        table.insert(chars, string.char(b))
      else
      end
      local state0
      do
        local _45_ = {state, b}
        if ((_G.type(_45_) == "table") and ((_45_)[1] == "base") and ((_45_)[2] == 92)) then
          state0 = "backslash"
        elseif ((_G.type(_45_) == "table") and ((_45_)[1] == "base") and ((_45_)[2] == 34)) then
          state0 = "done"
        elseif ((_G.type(_45_) == "table") and ((_45_)[1] == "backslash") and ((_45_)[2] == 10)) then
          table.remove(chars, (#chars - 1))
          state0 = "base"
        elseif true then
          local _ = _45_
          state0 = "base"
        else
          state0 = nil
        end
      end
      if (b and (state0 ~= "done")) then
        return parse_string_loop(chars, getb(), state0)
      else
        return b
      end
    end
    local function escape_char(c)
      return ({[7] = "\\a", [8] = "\\b", [9] = "\\t", [10] = "\\n", [11] = "\\v", [12] = "\\f", [13] = "\\r"})[c:byte()]
    end
    local function parse_string()
      table.insert(stack, {closer = 34})
      local chars = {"\""}
      if not parse_string_loop(chars, getb(), "base") then
        badend()
      else
      end
      table.remove(stack)
      local raw = table.concat(chars)
      local formatted = raw:gsub("[\7-\13]", escape_char)
      local _49_ = (rawget(_G, "loadstring") or load)(("return " .. formatted))
      if (nil ~= _49_) then
        local load_fn = _49_
        return dispatch(load_fn())
      elseif (_49_ == nil) then
        return parse_error(("Invalid string: " .. raw))
      else
        return nil
      end
    end
    local function parse_prefix(b)
      table.insert(stack, {prefix = prefixes[b], filename = filename, line = line, bytestart = byteindex, col = (col - 1)})
      local nextb = getb()
      if (whitespace_3f(nextb) or (true == delims[nextb])) then
        if (b ~= 35) then
          parse_error("invalid whitespace after quoting prefix")
        else
        end
        table.remove(stack)
        dispatch(utils.sym("#"))
      else
      end
      return ungetb(nextb)
    end
    local function parse_sym_loop(chars, b)
      if (b and sym_char_3f(b)) then
        table.insert(chars, string.char(b))
        return parse_sym_loop(chars, getb())
      else
        if b then
          ungetb(b)
        else
        end
        return chars
      end
    end
    local function parse_number(rawstr)
      local number_with_stripped_underscores = (not rawstr:find("^_") and rawstr:gsub("_", ""))
      if rawstr:match("^%d") then
        dispatch((tonumber(number_with_stripped_underscores) or parse_error(("could not read number \"" .. rawstr .. "\""))))
        return true
      else
        local _55_ = tonumber(number_with_stripped_underscores)
        if (nil ~= _55_) then
          local x = _55_
          dispatch(x)
          return true
        elseif true then
          local _ = _55_
          return false
        else
          return nil
        end
      end
    end
    local function check_malformed_sym(rawstr)
      local function col_adjust(pat)
        return (rawstr:find(pat) - utils.len(rawstr) - 1)
      end
      if (rawstr:match("^~") and (rawstr ~= "~=")) then
        return parse_error("invalid character: ~")
      elseif rawstr:match("%.[0-9]") then
        return parse_error(("can't start multisym segment with a digit: " .. rawstr), col_adjust("%.[0-9]"))
      elseif (rawstr:match("[%.:][%.:]") and (rawstr ~= "..") and (rawstr ~= "$...")) then
        return parse_error(("malformed multisym: " .. rawstr), col_adjust("[%.:][%.:]"))
      elseif ((rawstr ~= ":") and rawstr:match(":$")) then
        return parse_error(("malformed multisym: " .. rawstr), col_adjust(":$"))
      elseif rawstr:match(":.+[%.:]") then
        return parse_error(("method must be last component of multisym: " .. rawstr), col_adjust(":.+[%.:]"))
      else
        return rawstr
      end
    end
    local function parse_sym(b)
      local source0 = {bytestart = byteindex, filename = filename, line = line, col = (col - 1)}
      local rawstr = table.concat(parse_sym_loop({string.char(b)}, getb()))
      set_source_fields(source0)
      if (rawstr == "true") then
        return dispatch(true)
      elseif (rawstr == "false") then
        return dispatch(false)
      elseif (rawstr == "...") then
        return dispatch(utils.varg(source0))
      elseif rawstr:match("^:.+$") then
        return dispatch(rawstr:sub(2))
      elseif not parse_number(rawstr) then
        return dispatch(utils.sym(check_malformed_sym(rawstr), source0))
      else
        return nil
      end
    end
    local function parse_loop(b)
      if not b then
      elseif (b == 59) then
        parse_comment(getb(), {";"})
      elseif (type(delims[b]) == "number") then
        open_table(b)
      elseif delims[b] then
        close_table(b)
      elseif (b == 34) then
        parse_string()
      elseif prefixes[b] then
        parse_prefix(b)
      elseif (sym_char_3f(b) or (b == string.byte("~"))) then
        parse_sym(b)
      elseif not utils["hook-opts"]("illegal-char", options, b, getb, ungetb, dispatch) then
        parse_error(("invalid character: " .. string.char(b)))
      else
      end
      if not b then
        return nil
      elseif done_3f then
        return true, retval
      else
        return parse_loop(skip_whitespace(getb()))
      end
    end
    return parse_loop(skip_whitespace(getb()))
  end
  local function _62_()
    stack, line, byteindex, col, lastb = {}, 1, 0, 0, nil
    return nil
  end
  return parse_stream, _62_
end
local function parser(stream_or_string, _3ffilename, _3foptions)
  local filename = (_3ffilename or "unknown")
  local options = (_3foptions or utils.root.options or {})
  assert(("string" == type(filename)), "expected filename as second argument to parser")
  if ("string" == type(stream_or_string)) then
    return parser_fn(string_stream(stream_or_string, options), filename, options)
  else
    return parser_fn(stream_or_string, filename, options)
  end
end
return {granulate = granulate, parser = parser, ["string-stream"] = string_stream, ["sym-char?"] = sym_char_3f}
