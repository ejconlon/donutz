local function splice_save_locals(env, lua_source, scope)
  local saves
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for name in pairs(env.___replLocals___) do
      local val_19_auto = ("local %s = ___replLocals___['%s']"):format((scope.manglings[name] or name), name)
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
        val_19_auto = ("___replLocals___['%s'] = %s"):format(raw, name)
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
  local function _5_()
    if next(saves) then
      return (table.concat(saves, " ") .. gap)
    else
      return ""
    end
  end
  local function _8_()
    local _6_, _7_ = lua_source:match("^(.*)[\n ](return .*)$")
    if ((nil ~= _6_) and (nil ~= _7_)) then
      local body = _6_
      local _return = _7_
      return (body .. gap .. table.concat(binds, " ") .. gap .. _return)
    elseif true then
      local _ = _6_
      return lua_source
    else
      return nil
    end
  end
  return (_5_() .. _8_())
end
return splice_save_locals
