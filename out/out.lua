CSharpLuaSingleFile = true

-- CoreSystemLib: Core.lua
do
--[[
Copyright 2017 YANG Huan (sy.yanghuan@gmail.com).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local setmetatable = setmetatable
local getmetatable = getmetatable
local type = type
local pairs  = pairs
local assert = assert
local table = table
local tremove = table.remove
local tconcat = table.concat
local floor = math.floor
local ceil = math.ceil
local error = error
local select = select
local xpcall = xpcall
local rawget = rawget
local rawset = rawset
local rawequal = rawequal
local tostring = tostring
local string = string
local sfind = string.find
local ssub = string.sub
local debug = debug
local next = next
local global = _G
local prevSystem = rawget(global, "System")

local emptyFn = function() end
local nilFn = function() return nil end
local falseFn = function() return false end
local trueFn = function() return true end
local identityFn = function(x) return x end
local lengthFn = function (t) return #t end
local zeroFn = function() return 0 end
local oneFn = function() return 1 end
local equals = function(x, y) return x == y end
local getCurrent = function(t) return t.current end
local assembly, metadatas
local System, Object, ValueType

local function new(cls, ...)
  local this = setmetatable({}, cls)
  return this, cls.__ctor__(this, ...)
end

local function throw(e, lv)
  if e == nil then e = System.NullReferenceException() end
  e:traceback(lv)
  error(e)
end

local function xpcallErr(e)
  if e == nil then
    e = System.Exception("script error")
    e:traceback()
  elseif type(e) == "string" then
    if sfind(e, "attempt to index") then
      e = System.NullReferenceException(e)
    elseif sfind(e, "attempt to divide by zero") then  
      e = System.DivideByZeroException(e)
    else
      e = System.Exception(e)
    end
    e:traceback()
  end
  return e
end

local function try(try, catch, finally)
  local ok, status, result = xpcall(try, xpcallErr)
  if not ok then
    if catch then
      if finally then
        ok, status, result = xpcall(catch, xpcallErr, status)
      else
        ok, status, result = true, catch(status)
      end
      if ok then
        if status == 1 then
          ok = false
          status = result
        end
      end
    end
  end
  if finally then
    finally()
  end
  if not ok then
    error(status)
  end
  return status, result
end

local function set(className, cls)
  local scope = global
  local starIndex = 1
  while true do
    local pos = sfind(className, "[%.+]", starIndex) or 0
    local name = ssub(className, starIndex, pos -1)
    if pos ~= 0 then
      local t = rawget(scope, name)
      if t == nil then
        if cls then
          t = {}
          rawset(scope, name, t)
        else
          return nil
        end
      end
      scope = t
      starIndex = pos + 1
    else
      if cls then
        assert(rawget(scope, name) == nil, className)
        rawset(scope, name, cls)
        return cls
      else
        return rawget(scope, name)
      end
    end
  end
end

local function multiKey(t, ...)
  local n, i, k = select("#", ...), 1
  while true do
    k = assert(select(i, ...))
    if i == n then
      break
    end
    local tk = t[k]
    if tk == nil then
      tk = {}
      t[k] = tk
    end
    t = tk
    i = i + 1
  end
  return t, k
end

local function genericName(name, ...)
  if name:byte(-2) == 95 then
    name = ssub(name, 1, -3)
  end
  local n = select("#", ...)
  local t = { name, "`", n, "[" }
  local count = 5
  local hascomma
  for i = 1, n do
    local cls = select(i, ...)
    if hascomma then
      t[count] = ","
      count = count + 1
    else
      hascomma = true
    end
    t[count] = cls.__name__
    count = count + 1
  end
  t[count] = "]"
  return tconcat(t)
end

local enumMetatable = { class = "E", default = zeroFn, __index = false, interface = false, __call = function (_, v) return v or 0 end }
enumMetatable.__index = enumMetatable

local interfaceMetatable = { class = "I", default = nilFn, __index = false }
interfaceMetatable.__index = interfaceMetatable

local ctorMetatable = { __call = function (ctor, ...) return ctor[1](...) end }

local function applyExtends(cls)
  local extends = cls.base
  if extends then
    if type(extends) == "function" then
      extends = extends(global, cls)
    end
    cls.base = nil
  end
  return extends
end

local function applyMetadata(cls)
  local metadata = cls.__metadata__
  if metadata then
    if metadatas then
      metadatas[#metadatas + 1] = function (global)
        cls.__metadata__ = metadata(global)
      end
    else
      cls.__metadata__ = metadata(global)
    end
  end
end

local function setBase(cls, kind)
  local ctor = cls.__ctor__
  if ctor and type(ctor) == "table" then
    setmetatable(ctor, ctorMetatable)
  end
  local extends = applyExtends(cls)
  applyMetadata(cls)

  cls.__index = cls 
  cls.__call = new
  
  if kind == "S" then
    if extends then
      cls.interface = extends
    end
    setmetatable(cls, ValueType)
  else
    if extends then
      local base = extends[1]
      if not base then error(cls.__name__ .. "'s base is nil") end
      if base.class == "I" then
        cls.interface = extends
        setmetatable(cls, Object)
      else
        setmetatable(cls, base)
        if #extends > 1 then
          tremove(extends, 1)
          cls.interface = extends
        end
      end
    else
      setmetatable(cls, Object)
    end
  end
end

local function staticCtorSetBase(cls)
  setmetatable(cls, nil)
  local t = cls[cls]
  for k, v in pairs(t) do
    cls[k] = v
  end
  cls[cls] = nil
  local kind = cls.class
  cls.class = nil
  setBase(cls, kind)
  cls:static()
  cls.static = nil
end

local staticCtorMetatable = {
  __index = function(cls, key)
    staticCtorSetBase(cls)
    return cls[key]
  end,
  __newindex = function(cls, key, value)
    staticCtorSetBase(cls)
    cls[key] = value
  end,
  __call = function(cls, ...)
    staticCtorSetBase(cls)
    return new(cls, ...)
  end
}

local function setHasStaticCtor(cls, kind)
  local name = cls.__name__
  cls.__name__ = nil
  local t = {}
  for k, v in pairs(cls) do
    t[k] = v
    cls[k] = nil
  end
  cls[cls] = t
  cls.__name__ = name
  cls.class = kind
  cls.__call = new
  cls.__index = cls
  setmetatable(cls, staticCtorMetatable)
end

local function defCore(name, kind, cls, generic)
  cls = cls or {}
  cls.__name__ = name
  cls.__assembly__ = assembly
  if not generic then
    set(name, cls)
  end
  if kind == "C" or kind == "S" then
    if cls.static == nil then
      setBase(cls, kind)
    else
      setHasStaticCtor(cls, kind)
    end
  elseif kind == "I" then
    local extends = applyExtends(cls)
    if extends then 
      cls.interface = extends 
    end
    applyMetadata(cls)
    setmetatable(cls, interfaceMetatable)
  elseif kind == "E" then
    applyMetadata(cls)
    setmetatable(cls, enumMetatable)
  else
    assert(false, kind)
  end
  return cls
end

local function def(name, kind, cls, generic)
  if type(cls) == "function" then
    local mt = {}
    local fn = function(_, ...)
      local gt, gk = multiKey(mt, ...)
      local t = gt[gk]
      if t == nil then
        local class, super  = cls(...)
        t = defCore(genericName(name, ...), kind, class or {}, true)
        if generic then
          setmetatable(t, super or generic)
        end
        gt[gk] = t
      end
      return t
    end

    local base = kind ~= "S" and Object or ValueType
    local caller = setmetatable({ __call = fn, __index = base }, base)
    if generic then
      generic.__index = generic
      generic.__call = new
    end
    return set(name, setmetatable(generic or {}, caller))
  else
    return defCore(name, kind, cls, generic)
  end
end

local function defCls(name, cls, generic)
  return def(name, "C", cls, generic)
end

local function defInf(name, cls)
  return def(name, "I", cls)
end

local function defStc(name, cls, generic)
  return def(name, "S", cls, generic)
end

local function defEnum(name, cls)
  return def(name, "E", cls)
end

local function defArray(name, cls, Array, MultiArray)
  Array.__index = Array
  MultiArray.__index =  MultiArray
  setmetatable(MultiArray, Array)

  local mt = {}
  local function create(Array, T)
    local ArrayT = mt[T]
    if ArrayT == nil then
      ArrayT = defCore(T.__name__ .. "[]", "C", cls(T), true)
      setmetatable(ArrayT, Array)
      mt[T] = ArrayT
    end
    return ArrayT
  end

  local mtMulti = {}
  local function createMulti(MultiArray, T, dimension)
    local gt, gk = multiKey(mtMulti, T, dimension)
    local ArrayT = gt[gk]
    if ArrayT == nil then
      local name = T.__name__ .. "[" .. (","):rep(dimension - 1) .. "]"
      ArrayT = defCore(name, "C", cls(T), true)
      setmetatable(ArrayT, MultiArray)
      gt[gk] = ArrayT
    end
    return ArrayT
  end

  return set(name, setmetatable(Array, {
    __index = Object,
    __call = function (Array, T, dimension)
      if not dimension then
        return create(Array, T)
      else
        return createMulti(MultiArray, T, dimension)
      end
    end
  }))
end

local function trunc(num)
  return num > 0 and floor(num) or ceil(num)
end

local function when(f, ...)
  local ok, r = pcall(f, ...)
  return ok and r
end

System = {
  emptyFn = emptyFn,
  falseFn = falseFn,
  trueFn = trueFn,
  identityFn = identityFn,
  lengthFn = lengthFn,
  zeroFn = zeroFn,
  oneFn = oneFn,
  equals = equals,
  getCurrent = getCurrent,
  try = try,
  when = when,
  throw = throw,
  getClass = set,
  multiKey = multiKey,
  define = defCls,
  defInf = defInf,
  defStc = defStc,
  defEnum = defEnum,
  defArray = defArray,
  enumMetatable = enumMetatable,
  trunc = trunc,
  global = global
}
if prevSystem then
  setmetatable(System, { __index = prevSystem })
end
global.System = System

local debugsetmetatable = debug and debug.setmetatable
System.debugsetmetatable = debugsetmetatable

local _, _, version = sfind(_VERSION, "^Lua (.*)$")
version = tonumber(version)
System.luaVersion = version

if version < 5.3 then
  local bnot, band, bor, xor, sl, sr
  local bit = rawget(global, "bit")
  if not bit then
    local ok, b = pcall(require, "bit")
    if ok then
      bit = b
    end
  end
  if bit then
    bnot, band, bor, xor, sl, sr = bit.bnot, bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
  else
    local function disable()
      throw(System.NotSupportedException("bit operation is not enabled."))
    end
    bnot, band, bor, xor, sl, sr  = disable, disable, disable, disable, disable, disable
  end

  System.bnot = bnot
  System.band = band
  System.bor = bor
  System.xor = xor
  System.sl = sl
  System.sr = sr

  function System.div(x, y) 
    if y == 0 then throw(System.DivideByZeroException(), 1) end
    return trunc(x / y)
  end

  function System.mod(x, y)
    if y == 0 then throw(System.DivideByZeroException(), 1) end
    local v = x % y
    if v ~= 0 and x * y < 0 then
      return v - y
    end
    return v
  end
  
  function System.modf(x, y)
    local v = x % y
    if v ~= 0 and x * y < 0 then
      return v - y
    end
    return v
  end

  function System.toUInt(v, max, mask, checked)
    if v >= 0 and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    return band(v, mask)
  end

  function System.ToUInt(v, max, mask, checked)
    v = trunc(v)
    if v >= 0 and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    if v < -2147483648 or v > 2147483647 then
      return 0
    end
    return band(v, mask)
  end

  local function toInt(v, mask, umask)
    v = band(v, mask)
    local uv = band(v, umask)
    if uv ~= v then
      v = xor(uv - 1, umask)
      if uv ~= 0 then
        v = -v
      end
    end
    return v
  end

  function System.toInt(v, min, max, mask, umask, checked)
    if v >= min and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    return toInt(v, mask, umask)
  end

  function System.ToInt(v, min, max, mask, umask, checked)
    v = trunc(v)
    if v >= min and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    if v < -2147483648 or v > 2147483647 then
      return 0
    end
    return toInt(v, mask, umask)
  end

  local function toUInt32(v)
    if v <= -2251799813685248 or v >= 2251799813685248 then  -- 2 ^ 51, Lua BitOp used 51 and 52
      throw(System.InvalidCastException()) 
    end
    v = band(v, 0xffffffff)
    local uv = band(v, 0x7fffffff)
    if uv ~= v then
      return uv + 0x80000000
    end
    return v
  end

  function System.toUInt32(v, checked)
    if v >= 0 and v <= 4294967295 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    return toUInt32(v)
  end

  function System.ToUInt32(v, checked)
    v = trunc(v)
    if v >= 0 and v <= 4294967295 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    return toUInt32(v)
  end

  function System.toInt32(v, checked)
    if v >= -2147483648 and v <= 2147483647 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    if v <= -2251799813685248 or v >= 2251799813685248 then  -- 2 ^ 51, Lua BitOp used 51 and 52
      throw(System.InvalidCastException()) 
    end
    return band(v, 0xffffffff)
  end

  function System.toInt64(v, checked) 
    if v >= -9223372036854775808 and v <= 9223372036854775807 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    throw(System.InvalidCastException()) -- 2 ^ 51, Lua BitOp used 51 and 52
  end

  function System.toUInt64(v, checked)
    if v >= 0 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    if v >= -2147483648 then
      return band(v, 0x7fffffff) + 0xffffffff80000000
    end
    throw(System.InvalidCastException()) 
  end

  function System.ToUInt64(v, checked)
    v = trunc(v)
    if v >= 0 and v <= 18446744073709551615 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    if v >= -2147483648 and v <= 2147483647 then
      v = band(v, 0xffffffff)
      local uv = band(v, 0x7fffffff)
      if uv ~= v then
        return uv + 0xffffffff80000000
      end
      return v
    end
    throw(System.InvalidCastException()) 
  end

  if table.pack == nil then
    table.pack = function(...)
      return { n = select("#", ...), ... }
    end
  end

  if table.unpack == nil then
    table.unpack = assert(unpack)
  end

  if table.move == nil then
    table.move = function(a1, f, e, t, a2)
      if a2 == nil then a2 = a1 end
      if t > f then
        t = e - f + t
        while e >= f do
          a2[t] = a1[e]
          t = t - 1
          e = e - 1
        end
      else
        while f <= e do
          a2[t] = a1[f]
          t = t + 1
          f = f + 1
        end
      end
    end
  end
else
  load[[
  local System = System
  local throw = System.throw
  local trunc = System.trunc
  
  function System.bnot(x) return ~x end 
  function System.band(x, y) return x & y end
  function System.bor(x, y) return x | y end
  function System.xor(x, y) return x ~ y end
  function System.sl(x, y) return x << y end
  function System.sr(x, y) return x >> y end
  function System.div(x, y) if x ~ y < 0 then return -(-x // y) end return x // y end

  function System.mod(x, y)
    local v = x % y
    if v ~= 0 and 1.0 * x * y < 0 then
      return v - y
    end
    return v
  end

  local function toUInt(v, max, mask, checked)  
    if v >= 0 and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 2) 
    end
    return v & mask
  end
  System.toUInt = toUInt

  function System.ToUInt(v, max, mask, checked)
    v = trunc(v)
    if v >= 0 and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 2) 
    end
    if v < -2147483648 or v > 2147483647 then
      return 0
    end
    return v & mask
  end
  
  local function toSingedInt(v, mask, umask)
    v = v & mask
    local uv = v & umask
    if uv ~= v then
      v = (uv - 1) ~ umask
      if uv ~= 0 then
        v = -v
      end
    end
    return v
  end
  
  local function toInt(v, min, max, mask, umask, checked)
    if v >= min and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 2) 
    end
    return toSingedInt(v, mask, umask)
  end
  System.toInt = toInt
  
  function System.ToInt(v, min, max, mask, umask, checked)
    v = trunc(v)
    if v >= min and v <= max then
      return v
    end
    if checked then
      throw(System.OverflowException(), 2) 
    end
    if v < -2147483648 or v > 2147483647 then
      return 0
    end
    return toSingedInt(v, mask, umask)
  end

  function System.toUInt32(v, checked)
    return toUInt(v, 4294967295, 0xffffffff, checked)
  end
  
  function System.ToUInt32(v, checked)
    v = trunc(v)
    if v >= 0 and v <= 4294967295 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    return v & 0xffffffff
  end
  
  function System.toInt32(v, checked)
    return toInt(v, -2147483648, 2147483647, 0xffffffff, 0x7fffffff, checked)
  end

  function System.toInt64(v, checked)
    return toInt(v, -9223372036854775808, 9223372036854775807, 0xffffffffffffffff, 0x7fffffffffffffff, checked)
  end

  function System.toUInt64(v, checked)
    if v >= 0 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    return (v & 0x7fffffffffffffff) + 0x8000000000000000
  end

  function System.ToUInt64(v, checked)
    v = trunc(v)
    if v >= 0 and v <= 18446744073709551615 then
      return v
    end
    if checked then
      throw(System.OverflowException(), 1) 
    end
    v = v & 0xffffffffffffffff
    local uv = v & 0x7fffffffffffffff
    if uv ~= v then
      return uv + 0x8000000000000000
    end
    return v
  end

  ]]()
end

local toUInt = System.toUInt
local toInt = System.toInt
local ToUInt = System.ToUInt
local ToInt = System.ToInt

function System.toByte(v, checked)
  return toUInt(v, 255, 0xff, checked)
end

function System.toSByte(v, checked)
  return toInt(v, -128, 127, 0xff, 0x7f, checked)
end

function System.toInt16(v, checked)
  return toInt(v, -32768, 32767, 0xffff, 0x7fff, checked)
end

function System.toUInt16(v, checked)
  return toUInt(v, 65535, 0xffff, checked)
end

function System.ToByte(v, checked)
  return ToUInt(v, 255, 0xff, checked)
end

function System.ToSByte(v, checked)
  return ToInt(v, -128, 127, 0xff, 0x7f, checked)
end

function System.ToInt16(v, checked)
  return ToInt(v, -32768, 32767, 0xffff, 0x7fff, checked)
end

function System.ToUInt16(v, checked)
  return ToUInt(v, 65535, 0xffff, checked)
end

function System.ToInt32(v, checked)
  v = trunc(v)
  if v >= -2147483648 and v <= 2147483647 then
    return v
  end
  if checked then
    throw(System.OverflowException(), 1) 
  end
  return -2147483648
end

function System.ToInt64(v, checked)
  v = trunc(v)
  if v >= -9223372036854775808 and v <= 9223372036854775807 then
    return v
  end
  if checked then
    throw(System.OverflowException(), 1) 
  end
  return -9223372036854775808
end

function System.ToSingle(v, checked)
  if v >= -3.40282347E+38 and v <= 3.40282347E+38 then
    return v
  end
  if checked then
    throw(System.OverflowException(), 1) 
  end
  if v > 0 then
    return 1 / 0 
  else
    return -1 / 0
  end
end

function System.using(t, f)
  local dispose = t and t.Dispose
  if dispose ~= nil then
    local ok, status, ret = xpcall(f, xpcallErr, t)   
    dispose(t)
    if not ok then
      error(status)
    end
    return status, ret
  else
    return f(t)    
  end
end

function System.usingX(f, ...)
  local ok, status, ret = xpcall(f, xpcallErr, ...)
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    if t ~= nil then
      local dispose = t.Dispose
      if dispose ~= nil then
        dispose(t)
      end
    end
  end
  if not ok then
    error(status)
  end
  return status, ret
end

function System.apply(t, f)
  f(t)
  return t
end

function System.default(T)
  return T:default()
end

function System.property(name, onlyget)
  local function g(this)
    return this[name]
  end
  if onlyget then
    return g
  end
  local function s(this, v)
    this[name] = v
  end
  return g, s
end

function System.new(cls, index, ...)
  local this = setmetatable({}, cls)
  return this, cls.__ctor__[index](this, ...)
end

function System.base(this)
  return getmetatable(getmetatable(this))
end

local equalsObj, compareObj, toString
if debugsetmetatable then
  equalsObj = function (x, y)
    if x == y then
      return true
    end
    if x == nil or y == nil then
      return false
    end
    local ix = x.EqualsObj
    if ix ~= nil then
      return ix(x, y)
    end
    local iy = y.EqualsObj
    if iy ~= nil then
      return iy(y, x)
    end
    return false
  end

  compareObj = function (a, b)
    if a == b then return 0 end
    if a == nil then return -1 end
    if b == nil then return 1 end
    local ia = a.CompareToObj
    if ia ~= nil then
      return ia(a, b)
    end
    local ib = b.CompareToObj
    if ib ~= nil then
      return -ib(b, a)
    end
    throw(System.ArgumentException("Argument_ImplementIComparable"))
  end

  toString = function (t)
    if t ~= nil then
      if t.ToString ~= nil then
        return t:ToString()
      else 
        return tostring(t)
      end
    else
      return nil
    end
  end

  debugsetmetatable(nil, {
    __concat = function(a, b)
      if a == nil then
        if b == nil then
          return ""
        else
          return b
        end
      else
        return a
      end
    end,
    __add = function (a, b)
      if a == nil then
        if b == nil or type(b) == "number" then
          return nil
        end
        return b
      end
      return nil
    end,
    __sub = nilFn,
    __mul = nilFn,
    __div = nilFn,
    __mod = nilFn,
    __unm = nilFn,
    __lt = falseFn,
    __le = falseFn,

    -- lua 5.3
    __idiv = nilFn,
    __band = nilFn,
    __bor = nilFn,
    __bxor = nilFn,
    __bnot = nilFn,
    __shl = nilFn,
    __shr = nilFn,
  })
else
  equalsObj = function (x, y)
    if x == y then
      return true
    end
    if x == nil or y == nil then
      return false
    end
    local t = type(x)
    if t == "table" then
      local ix = x.EqualsObj
      if ix ~= nil then
        return ix(x, y)
      end
    elseif t == "number" then
      return System.Number.EqualsObj(x, y)
    end
    t = type(y)
    if t == "table" then
      local iy = y.EqualsObj
      if iy ~= nil then
        return iy(y, x)
      end
    end
    return false
  end

  compareObj = function (a, b)
    if a == b then return 0 end
    if a == nil then return -1 end
    if b == nil then return 1 end
    local t = type(a)
    if t == "number" then
      return System.Number.CompareToObj(a, b)
    elseif t == "boolean" then
      return System.Boolean.CompareToObj(a, b)
    else
      local ia = a.CompareToObj
      if ia ~= nil then
        return ia(a, b)
      end
    end
    t = type(b)
    if t == "number" then
      return -System.Number.CompareToObj(b, a)
    elseif t == "boolean" then
      return -System.Boolean.CompareToObj(a, b)
    else
      local ib = b.CompareToObj
      if ib ~= nil then
        return -ib(b, a)
      end
    end
    throw(System.ArgumentException("Argument_ImplementIComparable"))
  end

  toString = function (obj)
    if obj == nil then return "" end
    local t = type(obj) 
    if t == "table" and obj.ToString ~= nil then
      return obj:ToString()
    elseif t == "boolean" then
      return obj and "True" or "False"
    elseif t == "function" then
      return "System.Delegate"
    end
    return tostring(obj)
  end
end


System.equalsObj = equalsObj
System.compareObj = compareObj
System.toString = toString

Object = defCls("System.Object", {
  __call = new,
  __ctor__ = emptyFn,
  default = nilFn,
  class = "C",
  EqualsObj = equals,
  ReferenceEquals = rawequal,
  GetHashCode = identityFn,
  EqualsStatic = equalsObj,
  GetType = false,
  ToString = function(this) return this.__name__ end
})
setmetatable(Object, { __call = new })

ValueType = defCls("System.ValueType", {
  class = "S",
  default = function(T) 
    return T()
  end,
  __clone__ = function(this)
    if type(this) == "table" then
      local cls = getmetatable(this)
      local t = {}
      for k, v in pairs(this) do
        if type(v) == "table" and v.class == "S" then
          t[k] = v:__clone__()
        else
          t[k] = v
        end
      end
      return setmetatable(t, cls)
    end
    return this
  end,
  __copy__ = function (this, obj)
    for k, v in pairs(obj) do
      if type(v) == "table" and v.class == "S" then
        this[k] = v:__clone__()
      else
        this[k] = v
      end
    end
    for k, v in pairs(this) do
      if v ~= nil and rawget(obj, k) == nil then
        this[k] = nil
      end
    end
  end,
  EqualsObj = function (this, obj)
    if getmetatable(this) ~= getmetatable(obj) then return false end
    for k, v in pairs(this) do
      if not equalsObj(v, obj[k]) then
        return false
      end
    end
    return true
  end,
  GetHashCode = function (this)
    throw(System.NotSupportedException(this.__name__ .. " User-defined struct not support GetHashCode"), 1)
  end
})

local AnonymousType
AnonymousType = defCls("System.AnonymousType", {
  EqualsObj = function (this, obj)
    if getmetatable(obj) ~= AnonymousType then return false end
    for k, v in pairs(this) do
      if not equalsObj(v, obj[k]) then
        return false
      end
    end
    return true
  end
})

local function anonymousTypeCreate(T, t)
  return setmetatable(t, T)
end

local anonymousTypeMetaTable = setmetatable({ __index = Object, __call = anonymousTypeCreate }, Object)
setmetatable(AnonymousType, anonymousTypeMetaTable)

local pack, unpack = table.pack, table.unpack

local function tupleDeconstruct(t) 
  return unpack(t, 1, t.n)
end

local function tupleEquals(t, other)
  for i = 1, t.n do
    if not equalsObj(t[i], other[i]) then
      return false
    end
  end
  return true
end

local function tupleEqualsObj(t, obj)
  if getmetatable(obj) ~= getmetatable(t) or t.n ~= obj.n then
    return false
  end
  return tupleEquals(t, obj)
end

local function tupleCompareTo(t, other)
  for i = 1, t.n do
    local v = compareObj(t[i], other[i])
    if v ~= 0 then
      return v
    end
  end
  return 0
end

local function tupleCompareToObj(t, obj)
  if obj == nil then return 1 end
  if getmetatable(obj) ~= getmetatable(t) or t.n ~= obj.n then
    throw(System.ArgumentException())
  end
  return tupleCompareTo(t, obj)
end

local function tupleToString(t)
  local a = { "(" }
  local count = 2
  for i = 1, t.n do
    if i ~= 1 then
      a[count] = ", "
      count = count + 1
    end
    local v = t[i]
    if v ~= nil then
      a[count] = v:ToString()
      count = count + 1
    end
  end
  a[count] = ")"
  return tconcat(a)
end

local function tupleLength(t)
  return t.n
end

local function tupleGet(t, index)
  if index < 0 or index >= t.n then
    throw(System.IndexOutOfRangeException())
  end
  return t[index + 1]
end

local function tupleGetRest(t)
  return t[8]
end

local function tupleCreate(T, ...)
  return setmetatable(pack(...), T)
end

local Tuple = defCls("System.Tuple", {
  Deconstruct = tupleDeconstruct,
  ToString = tupleToString,
  EqualsObj = tupleEqualsObj,
  CompareToObj = tupleCompareToObj,
  getLength = tupleLength,
  get = tupleGet,
  getRest = tupleGetRest
})
local tupleMetaTable = setmetatable({ __index  = Object, __call = tupleCreate }, Object)
setmetatable(Tuple, tupleMetaTable)

local ValueTuple = defStc("System.ValueTuple", {
  Deconstruct = tupleDeconstruct,
  ToString = tupleToString,
  __eq = tupleEquals,
  Equals = tupleEquals,
  EqualsObj = tupleEqualsObj,
  CompareTo = tupleCompareTo,
  CompareToObj = tupleCompareToObj,
  getLength = tupleLength,
  get = tupleGet,
  default = function ()
    throw(System.NotSupportedException("not support default(T) when T is ValueTuple"))
  end
})
local valueTupleMetaTable = setmetatable({ __index  = ValueType, __call = tupleCreate }, ValueType)
setmetatable(ValueTuple, valueTupleMetaTable)

local function recordEquals(t, other)
  if getmetatable(t) == getmetatable(other) then
    for k, v in pairs(t) do
      if not equalsObj(v, other[k]) then
        return false
      end
    end
    return true
  end
  return false
end

defCls("System.RecordType", {
  __eq = recordEquals,
  __clone__ = function (this)
    local cls = getmetatable(this)
    local t = {}
    for k, v in pairs(this) do
      t[k] = v
    end
    return setmetatable(t, cls)
  end,
  Equals = recordEquals,
  PrintMembers = function (this, builder)
    local p = pack(this.__members__())
    local n = p.n
    for i = 2, n do
      local k = p[i]
      local v = this[k]
      builder:Append(k)
      builder:Append(" = ")
      if v ~= nil then
        builder:Append(toString(v))
      end
      if i ~= n then
        builder:Append(", ")
      end
    end
  end,
  ToString = function (this)
    local p = pack(this.__members__())
    local n = p.n
    local t = { p[1], "{" }
    local count = 3
    for i = 2, n do
      local k = p[i]
      local v = this[k]
      t[count] = k
      t[count + 1] = "="
      if v ~= nil then
        if i ~= n then
          t[count + 2] = toString(v) .. ','
        else
          t[count + 2] = toString(v)
        end
      else
        if i ~= n then
          t[count + 2] = ','
        end
      end
      if v == nil and i == n then
        count = count + 2
      else
        count = count + 3
      end
    end
    t[count] = "}"
    return tconcat(t, ' ')
  end
})

local Attribute = defCls("System.Attribute")
defCls("System.FlagsAttribute", { base = { Attribute } })

local Nullable = { 
  default = nilFn,
  Value = function (this)
    if this == nil then
      throw(System.InvalidOperationException("Nullable object must have a value."))
    end
    return this
  end,
  EqualsObj = equalsObj,
  GetHashCode = function (this)
    if this == nil then
      return 0
    end
    if type(this) == "table" then
      return this:GetHashCode()
    end
    return this
  end,
  clone = function (t)
    if type(t) == "table" then
      return t:__clone__()
    end
    return t
  end
}

defStc("System.Nullable", function (T)
  return { 
    __genericT__ = T 
  }
end, Nullable)

function System.isNullable(T)
  return getmetatable(T) == Nullable
end

local Index = defStc("System.Index", {
  End = -0.0,
  Start = 0,
  IsFromEnd = function (this)
    return 1 / this < 0 
  end,
  GetOffset = function (this, length)
    if 1 / this < 0 then
      return length + this
    end
    return this
  end,
  ToString = function (this)
    return ((1 / this < 0) and '^' or '') .. this
  end
})
setmetatable(Index, { 
  __call = function (value, fromEnd)
    if value < 0 then
      throw(System.ArgumentOutOfRangeException("Non-negative number required."))
    end
    if fromEnd then
      if value == 0 then
        return -0.0
      end
      return -value
    end
    return value
  end
})

local function pointerAddress(p)
  local address = p[3]
  if address == nil then
    address = ssub(tostring(p), 7)
    p[3] = address
  end
  return address + p[2]
end

local Pointer
local function newPointer(t, i)
  return setmetatable({ t, i }, Pointer)
end

Pointer = {
  __index = false,
  get = function(this)
    local t, i = this[1], this[2]
    return t[i]
  end,
  set = function(this, value)
    local t, i = this[1], this[2]
    t[i] = value
  end,
  __add = function(this, count)
    return newPointer(this[1], this[2] + count)
  end,
  __sub = function(this, count)
    return newPointer(this[1], this[2] - count)
  end,
  __lt = function(t1, t2)
    return pointerAddress(t1) < pointerAddress(t2)
  end,
  __le = function(t1, t2)
    return pointerAddress(t1) <= pointerAddress(t2)
  end
}
Pointer.__index = Pointer

function System.stackalloc(t)
  return newPointer(t, 1)
end

local modules, imports = {}, {}
function System.import(f)
  imports[#imports + 1] = f
end

local namespace
local function defIn(kind, name, f)
  local namespaceName, isClass = namespace[1], namespace[2]
  if #namespaceName > 0 then
    name = namespaceName .. (isClass and "+" or ".") .. name
  end
  assert(modules[name] == nil, name)
  namespace[1], namespace[2] = name, kind == "C" or kind == "S"
  local t = f(assembly)
  namespace[1], namespace[2] = namespaceName, isClass
  modules[isClass and name:gsub("+", ".") or name] = function()
    return def(name, kind, t)
  end
end

namespace = {
  "",
  false,
  __index = false,
  class = function(name, f) defIn("C", name, f) end,
  struct = function(name, f) defIn("S", name, f) end,
  interface = function(name, f) defIn("I", name, f) end,
  enum = function(name, f) defIn("E", name, f) end,
  namespace = function(name, f)
    local namespaceName = namespace[1]
    name = namespaceName .. "." .. name
    namespace[1] = name
    f(namespace)
    namespace[1] = namespaceName
  end
}
namespace.__index = namespace

function System.namespace(name, f)
  if not assembly then assembly = setmetatable({}, namespace) end
  namespace[1] = name
  f(namespace)
  namespace[1], namespace[2] = "", false
end

function System.init(t)
  local path, files = t.path, t.files
  if files then
    path = (path and #path > 0) and (path .. '.') or ""
    for i = 1, #files do
      require(path .. files[i])
    end
  end

  metadatas = {}
  local types = t.types
  if types then
    local classes = {}
    for i = 1, #types do
      local name = types[i]
      local cls = assert(modules[name], name)()
      classes[i] = cls
    end
    assembly.classes = classes
  end

  for i = 1, #imports do
    imports[i](global)
  end

  local b, e = 1, #metadatas
  while true do
    for i = b, e do
      metadatas[i](global)
    end
    local len = #metadatas
    if len == e then
      break
    end
    b, e = e + 1, len
  end

  local main = t.Main
  if main then
    assembly.entryPoint = main
    System.entryAssembly = assembly
  end

  local attributes = t.assembly
  if attributes then
    if type(attributes) == "function" then
      attributes = attributes(global)
    end
    for k, v in pairs(attributes) do
      assembly[k] = v
    end
  end

  local current = assembly
  modules, imports, assembly, metadatas = {}, {}, nil, nil
  return current
end

System.config = rawget(global, "CSharpLuaSystemConfig") or {}
local isSingleFile = rawget(global, "CSharpLuaSingleFile")
if not isSingleFile then
  return function (config)
    if config then
      System.config = config 
    end
  end
end

end

-- CoreSystemLib: Interfaces.lua
do
local System = System
local defInf = System.defInf
local emptyFn = System.emptyFn

local IComparable = defInf("System.IComparable")
local IFormattable = defInf("System.IFormattable")
local IConvertible = defInf("System.IConvertible")
defInf("System.IFormatProvider")
defInf("System.ICloneable")

defInf("System.IComparable_1", emptyFn)
defInf("System.IEquatable_1", emptyFn)

defInf("System.IPromise")
defInf("System.IDisposable")

local IEnumerable = defInf("System.IEnumerable")
local IEnumerator = defInf("System.IEnumerator")

local ICollection = defInf("System.ICollection", {
  base = { IEnumerable }
})

defInf("System.IList", {
  base = { ICollection }
})

defInf("System.IDictionary", {
  base = { ICollection }
})

defInf("System.IEnumerator_1", function(T) 
  return {
    base = { IEnumerator }
  }
end)

local IEnumerable_1 = defInf("System.IEnumerable_1", function(T) 
  return {
    base = { IEnumerable }
  }
end)

local ICollection_1 = defInf("System.ICollection_1", function(T) 
  return { 
    base = { IEnumerable_1(T) } 
  }
end)

local IReadOnlyCollection_1 = defInf("System.IReadOnlyCollection_1", function (T)
  return { 
    base = { IEnumerable_1(T) } 
  }
end)

defInf("System.IReadOnlyList_1", function (T)
  return { 
    base = { IReadOnlyCollection_1(T) } 
  }
end)

defInf('System.IDictionary_2', function(TKey, TValue) 
  return {
    base = { ICollection_1(System.KeyValuePair(TKey, TValue)) }
  }
end)

defInf("System.IReadOnlyDictionary_2", function(TKey, TValue) 
  return {
    base = { IReadOnlyCollection_1(System.KeyValuePair(TKey, TValue)) }
  }
end)

defInf("System.IList_1", function(T) 
  return {
    base = { ICollection_1(T) }
  }
end)

defInf("System.ISet_1", function(T) 
  return {
    base = { ICollection_1(T) }
  }
end)

defInf("System.IComparer")
defInf("System.IComparer_1", emptyFn)
defInf("System.IEqualityComparer")
defInf("System.IEqualityComparer_1", emptyFn)

System.enumMetatable.interface = { IComparable, IFormattable, IConvertible }
end

-- CoreSystemLib: Exception.lua
do
local System = System
local define = System.define
local Object = System.Object

local tconcat = table.concat
local type = type
local debug = debug

local function getMessage(this)
  return this.message or ("Exception of type '%s' was thrown."):format(this.__name__)
end

local traceback = (debug and debug.traceback) or System.config.traceback or function () return "" end
System.traceback = traceback

local function toString(this)
  local t = { this.__name__ }
  local count = 2
  local message, innerException, stackTrace = getMessage(this), this.innerException, this.errorStack
  t[count] = ": "
  t[count + 1] = message
  count = count + 2
  if innerException then
    t[count] = "---> "
    t[count + 1] = innerException:ToString()
    count = count + 2
  end
  if stackTrace then
    t[count] = stackTrace
  end
  return tconcat(t)
end

local function ctorOfException(this, message, innerException)
  this.message = message
  this.innerException = innerException
end

local Exception = define("System.Exception", {
  __tostring = toString,
  __ctor__ = ctorOfException,
  ToString = toString,
  getMessage = getMessage,
  getInnerException = function(this) 
    return this.innerException
  end,
  getStackTrace = function(this) 
    return this.errorStack
  end,
  getData = function (this)
    local data = this.data
    if not data then
      data = System.Dictionary(Object, Object)()
      this.data = data
    end
    return data
  end,
  traceback = function(this, lv)
    this.errorStack = traceback("", lv and lv + 3 or 3)
  end
})

local SystemException = define("System.SystemException", {
  __tostring = toString,
  base = { Exception },
  __ctor__ = function (this, message, innerException)
    ctorOfException(this, message or "System error.", innerException)
  end
})

local ArgumentException = define("System.ArgumentException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, paramName, innerException)
    if type(paramName) == "table" then
      paramName, innerException = nil, paramName
    end
    ctorOfException(this, message or "Value does not fall within the expected range.", innerException)
    this.paramName = paramName
    if paramName and #paramName > 0 then
      this.message = this.message .. "\nParameter name: " .. paramName
    end
  end,
  getParamName = function(this) 
    return this.paramName
  end
})

define("System.ArgumentNullException", {
  __tostring = toString,
  base = { ArgumentException },
  __ctor__ = function(this, paramName, message, innerException) 
    ArgumentException.__ctor__(this, message or "Value cannot be null.", paramName, innerException)
  end
})

define("System.ArgumentOutOfRangeException", {
  __tostring = toString,
  base = { ArgumentException },
  __ctor__ = function(this, paramName, message, innerException, actualValue) 
    ArgumentException.__ctor__(this, message or "Specified argument was out of the range of valid values.", paramName, innerException)
    this.actualValue = actualValue
  end,
  getActualValue = function(this) 
    return this.actualValue
  end
})

define("System.IndexOutOfRangeException", {
   __tostring = toString,
   base = { SystemException },
   __ctor__ = function (this, message, innerException)
    ctorOfException(this, message or "Index was outside the bounds of the array.", innerException)
  end
})

define("System.CultureNotFoundException", {
  __tostring = toString,
  base = { ArgumentException },
  __ctor__ = function(this, paramName, invalidCultureName, message, innerException, invalidCultureId) 
    if not message then 
      message = "Culture is not supported."
      if paramName then
        message = message .. "\nParameter name = " .. paramName
      end
      if invalidCultureName then
        message = message .. "\n" .. invalidCultureName .. " is an invalid culture identifier."
      end
    end
    ArgumentException.__ctor__(this, message, paramName, innerException)
    this.invalidCultureName = invalidCultureName
    this.invalidCultureId = invalidCultureId
  end,
  getInvalidCultureName = function(this)
    return this.invalidCultureName
  end,
  getInvalidCultureId = function(this) 
    return this.invalidCultureId
  end
})

local KeyNotFoundException = define("System.Collections.Generic.KeyNotFoundException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "The given key was not present in the dictionary.", innerException)
  end
})
System.KeyNotFoundException = KeyNotFoundException

local ArithmeticException = define("System.ArithmeticException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Overflow or underflow in the arithmetic operation.", innerException)
  end
})

define("System.DivideByZeroException", {
  __tostring = toString,
  base = { ArithmeticException },
  __ctor__ = function(this, message, innerException) 
    ArithmeticException.__ctor__(this, message or "Attempted to divide by zero.", innerException)
  end
})

define("System.OverflowException", {
  __tostring = toString,
  base = { ArithmeticException },
  __ctor__ = function(this, message, innerException) 
    ArithmeticException.__ctor__(this, message or "Arithmetic operation resulted in an overflow.", innerException)
  end
})

define("System.FormatException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Invalid format.", innerException)
  end
})

define("System.InvalidCastException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Specified cast is not valid.", innerException)
  end
})

local InvalidOperationException = define("System.InvalidOperationException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Operation is not valid due to the current state of the object.", innerException)
  end
})

define("System.NotImplementedException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "The method or operation is not implemented.", innerException)
  end
})

define("System.NotSupportedException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Specified method is not supported.", innerException)
  end
})

define("System.NullReferenceException", {
  __tostring = toString,
  base = { SystemException },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Object reference not set to an instance of an object.", innerException)
  end
})

define("System.RankException", {
  __tostring = toString,
  base = { Exception },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Attempted to operate on an array with the incorrect number of dimensions.", innerException)
  end
})

define("System.TypeLoadException", {
  __tostring = toString,
  base = { Exception },
  __ctor__ = function(this, message, innerException) 
    ctorOfException(this, message or "Failed when load type.", innerException)
  end
})

define("System.ObjectDisposedException", {
  __tostring = toString,
  base = { InvalidOperationException },
  __ctor__ = function(this, objectName, message, innerException)
    ctorOfException(this, message or "Cannot access a disposed object.", innerException)
    this.objectName = objectName
    if objectName and #objectName > 0 then
      this.message = this.message .. "\nObject name: '" .. objectName .. "'."
    end
  end
})

local function toStringOfAggregateException(this)
  local t = { toString(this) }
  local count = 2
  for i = 0, this.innerExceptions:getCount() - 1 do
    t[count] = "\n---> (Inner Exception #"
    t[count + 1] = i
    t[count + 2] = ") "
    t[count + 3] = this.innerExceptions:get(i):ToString()
    t[count + 4] = "<---\n"
    count = count + 5
  end
  return tconcat(t)
end

define("System.AggregateException", {
  ToString = toStringOfAggregateException,
  __tostring = toStringOfAggregateException,
  base = { Exception },
  __ctor__ = function (this, message, innerExceptions)
    if type(message) == "table" then
      message, innerExceptions = nil, message
    end
    Exception.__ctor__(this, message or "One or more errors occurred.")
    local ReadOnlyCollection = System.ReadOnlyCollection(Exception)
    if innerExceptions then
      if System.is(innerExceptions, Exception) then
        local list = System.List(Exception)()
        list:Add(innerExceptions)
        this.innerExceptions = ReadOnlyCollection(list)
      else
        if not System.isArrayLike(innerExceptions) then
          innerExceptions = System.Array.toArray(innerExceptions)
        end
        this.innerExceptions = ReadOnlyCollection(innerExceptions)
      end
    else
      this.innerExceptions = ReadOnlyCollection(System.Array.Empty(Exception))
    end
  end,
  getInnerExceptions = function (this)
    return this.innerExceptions
  end
})

System.SwitchExpressionException = define("System.Runtime.CompilerServices", {
  __tostring = toString,
  base = { InvalidOperationException },
  __ctor__ = function(this, message, innerException)
    ctorOfException(this, message or "Non-exhaustive switch expression failed to match its input.", innerException)
  end
})
end

-- CoreSystemLib: Number.lua
do
local System = System
local throw = System.throw
local define = System.defStc
local equals = System.equals
local zeroFn = System.zeroFn
local identityFn = System.identityFn
local debugsetmetatable = System.debugsetmetatable

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1
local IConvertible = System.IConvertible
local IFormattable = System.IFormattable

local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException
local FormatException = System.FormatException
local OverflowException = System.OverflowException

local type = type
local tonumber = tonumber
local floor = math.floor
local setmetatable = setmetatable
local tostring = tostring

local function hexForamt(x, n)
  return n == "" and "%" .. x or "%0" .. n .. x
end

local function floatForamt(x, n)
  return n == "" and "%.f" or "%." .. n .. 'f'
end

local function integerFormat(x, n)
  return n == "" and "%d" or "%0" .. n .. 'd'
end

local function exponentialFormat(x, n)
  return n == "" and "%" .. x or "%." .. n .. x
end

local formats = {
  ['x'] = hexForamt,
  ['X'] = hexForamt,
  ['f'] = floatForamt,
  ['F'] = floatForamt,
  ['d'] = integerFormat,
  ['D'] = integerFormat,
  ['e'] = exponentialFormat,
  ['E'] = exponentialFormat
}

local function toStringWithFormat(this, format)
  if #format ~= 0 then
    local i, j, x, n = format:find("^%s*([xXdDfFeE])(%d?)%s*$")
    if i then
      local f = formats[x]
      if f then
        format = f(x, n)
      end
      return format:format(this)
    end
  end
  return tostring(this)
end

local function toString(this, format)
  if format then
    return toStringWithFormat(this, format)
  end
  return tostring(this)
end

local function compareInt(this, v)
  if this < v then return -1 end
  if this > v then return 1 end
  return 0
end

local function inherits(_, T)
  return { IComparable, IComparable_1(T), IEquatable_1(T), IConvertible, IFormattable }
end

local Int = define("System.Int", {
  base = inherits,
  default = zeroFn,
  CompareTo = compareInt,
  Equals = equals,
  ToString = toString,
  GetHashCode = identityFn,
  CompareToObj = function (this, v)
    if v == nil then return 1 end
    if type(v) ~= "number" then
      throw(ArgumentException("Arg_MustBeInt"))
    end
    return compareInt(this, v)
  end,
  EqualsObj = function (this, v)
    if type(v) ~= "number" then
      return false
    end
    return this == v
  end
})
Int.__call = zeroFn

local function parseInt(s, min, max)
  if s == nil then
    return nil, 1        
  end
  local v = tonumber(s)
  if v == nil or v ~= floor(v) then
    return nil, 2
  end
  if v < min or v > max then
    return nil, 3
  end
  return v
end

local function tryParseInt(s, min, max)
  local v = parseInt(s, min, max)
  if v then
    return true, v
  end
  return false, 0
end

local function parseIntWithException(s, min, max)
  local v, err = parseInt(s, min, max)
  if v then
    return v    
  end
  if err == 1 then
    throw(ArgumentNullException())
  elseif err == 2 then
    throw(FormatException())
  else
    throw(OverflowException())
  end
end

local SByte = define("System.SByte", {
  Parse = function (s)
    return parseIntWithException(s, -128, 127)
  end,
  TryParse = function (s)
    return tryParseInt(s, -128, 127)
  end
})
setmetatable(SByte, Int)

local Byte = define("System.Byte", {
  Parse = function (s)
    return parseIntWithException(s, 0, 255)
  end,
  TryParse = function (s)
    return tryParseInt(s, 0, 255)
  end
})
setmetatable(Byte, Int)

local Int16 = define("System.Int16", {
  Parse = function (s)
    return parseIntWithException(s, -32768, 32767)
  end,
  TryParse = function (s)
    return tryParseInt(s, -32768, 32767)
  end
})
setmetatable(Int16, Int)

local UInt16 = define("System.UInt16", {
  Parse = function (s)
    return parseIntWithException(s, 0, 65535)
  end,
  TryParse = function (s)
    return tryParseInt(s, 0, 65535)
  end
})
setmetatable(UInt16, Int)

local Int32 = define("System.Int32", {
  Parse = function (s)
    return parseIntWithException(s, -2147483648, 2147483647)
  end,
  TryParse = function (s)
    return tryParseInt(s, -2147483648, 2147483647)
  end
})
setmetatable(Int32, Int)

local UInt32 = define("System.UInt32", {
  Parse = function (s)
    return parseIntWithException(s, 0, 4294967295)
  end,
  TryParse = function (s)
    return tryParseInt(s, 0, 4294967295)
  end
})
setmetatable(UInt32, Int)

local Int64 = define("System.Int64", {
  Parse = function (s)
    return parseIntWithException(s, -9223372036854775808, 9223372036854775807)
  end,
  TryParse = function (s)
    return tryParseInt(s, -9223372036854775808, 9223372036854775807)
  end
})
setmetatable(Int64, Int)

local UInt64 = define("System.UInt64", {
  Parse = function (s)
    return parseIntWithException(s, 0, 18446744073709551615.0)
  end,
  TryParse = function (s)
    return tryParseInt(s, 0, 18446744073709551615.0)
  end
})
setmetatable(UInt64, Int)

local nan = 0 / 0
local posInf = 1 / 0
local negInf = - 1 / 0
local nanHashCode = {}

--http://lua-users.org/wiki/InfAndNanComparisons
local function isNaN(v)
  return v ~= v
end

local function compareDouble(this, v)
  if this < v then return -1 end
  if this > v then return 1 end
  if this == v then return 0 end
  if isNaN(this) then
    return isNaN(v) and 0 or -1
  else 
    return 1
  end
end

local function equalsDouble(this, v)
  if this == v then return true end
  return isNaN(this) and isNaN(v)
end

local function equalsObj(this, v)
  if type(v) ~= "number" then
    return false
  end
  return equalsDouble(this, v)
end

local function getHashCode(this)
  return isNaN(this) and nanHashCode or this
end

local Number = define("System.Number", {
  base = inherits,
  default = zeroFn,
  CompareTo = compareDouble,
  Equals = equalsDouble,
  ToString = toString,
  NaN = nan,
  IsNaN = isNaN,
  NegativeInfinity = negInf,
  PositiveInfinity = posInf,
  EqualsObj = equalsObj,
  GetHashCode = getHashCode,
  CompareToObj = function (this, v)
    if v == nil then return 1 end
    if type(v) ~= "number" then
      throw(ArgumentException("Arg_MustBeNumber"))
    end
    return compareDouble(this, v)
  end,
  IsFinite = function (v)
    return v ~= posInf and v ~= negInf and not isNaN(v)
  end,
  IsInfinity = function (v)
    return v == posInf or v == negInf
  end,
  IsNegativeInfinity = function (v)
    return v == negInf
  end,
  IsPositiveInfinity = function (v)
    return v == posInf
  end
})
Number.__call = zeroFn
if debugsetmetatable then
  debugsetmetatable(0, Number)
end

local function parseDouble(s)
  if s == nil then
    return nil, 1
  end
  local v = tonumber(s)
  if v == nil then
    return nil, 2
  end
  return v
end

local function parseDoubleWithException(s)
  local v, err = parseDouble(s)
  if v then
    return v    
  end
  if err == 1 then
    throw(ArgumentNullException())
  else
    throw(FormatException())
  end
end

local Single = define("System.Single", {
  Parse = function (s)
    local v = parseDoubleWithException(s)
    if v < -3.40282347E+38 or v > 3.40282347E+38 then
      throw(OverflowException())
    end
    return v
  end,
  TryParse = function (s)
    local v = parseDouble(s)
    if v and v >= -3.40282347E+38 and v < 3.40282347E+38 then
      return true, v
    end
    return false, 0
  end
})
setmetatable(Single, Number)

local Double = define("System.Double", {
  Parse = parseDoubleWithException,
  TryParse = function (s)
    local v = parseDouble(s)
    if v then
      return true, v
    end
    return false, 0
  end
})
setmetatable(Double, Number)

if not debugsetmetatable then
  local NullReferenceException = System.NullReferenceException
  local systemToString = System.toString

  function System.ObjectEqualsObj(this, obj)
    if this == nil then throw(NullReferenceException()) end
    local t = type(this)
    if t == "number" then
      return equalsObj(this, obj)
    elseif t == "table" then
      return this:EqualsObj(obj)
    end
    return this == obj
  end

  function System.ObjectGetHashCode(this)
    if this == nil then throw(NullReferenceException()) end
    local t = type(this)
    if t == "number" then
      return getHashCode(this)
    elseif t == "table" then
      return this:GetHashCode()
    end
    return this
  end

  function System.ObjectToString(this)
    if this == nil then throw(NullReferenceException()) end
    return systemToString(this)
  end

  function System.IComparableCompareTo(this, other)
    if this == nil then throw(NullReferenceException()) end
    local t = type(this)
    if t == "number" then
      return compareDouble(this, other)
    elseif t == "boolean" then
      return System.Boolean.CompareTo(this, other)
    end
    return this:CompareTo(other)
  end

  function System.IEquatableEquals(this, other)
    if this == nil then throw(NullReferenceException()) end
    local t = type(this)
    if t == "number" then
      return equalsDouble(this, other)
    elseif t == "boolean" then
      return System.Boolean.Equals(this, other)
    end
    return this:Equals(other)
  end

  function System.IFormattableToString(this, format, formatProvider)
    if this == nil then throw(NullReferenceException()) end
    local t = type(this)
    if t == "number" then
      return toString(this, format, formatProvider)
    end
    return this:ToString(format, formatProvider)
  end
end
end

-- CoreSystemLib: Char.lua
do
local System = System
local throw = System.throw
local Int = System.Int
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException

local setmetatable = setmetatable
local byte = string.byte

local isSeparatorTable = {
  [32] = true,
  [160] = true,
  [0x2028] = true,
  [0x2029] = true,
  [0x0020] = true,
  [0x00A0] = true,
  [0x1680] = true,
  [0x180E] = true,
  [0x202F] = true,
  [0x205F] = true,
  [0x3000] = true,
}

local isSymbolTable = {
  [36] = true,
  [43] = true,
  [60] = true, 
  [61] = true, 
  [62] = true, 
  [94] = true, 
  [96] = true,
  [124] = true,
  [126] = true,
  [172] = true, 
  [180] = true,
  [182] = true,
  [184] = true,
  [215] = true,
  [247] = true,
}

--https://msdn.microsoft.com/zh-cn/library/t809ektx(v=vs.110).aspx
local isWhiteSpace = {
  [0x0020] = true,
  [0x00A0] = true,
  [0x1680] = true,
  [0x202F] = true,
  [0x205F] = true,
  [0x3000] = true,
  [0x2028] = true,
  [0x2029] = true,
  [0x0085] = true,
}

local function get(s, index)
  if s == nil then throw(ArgumentNullException("s")) end
  local c = byte(s, index + 1)
  if not c then throw(ArgumentOutOfRangeException("index")) end
  return c
end

local function isDigit(c, index)
  if index then
    c = get(c, index)
  end
  return (c >= 48 and c <= 57)
end

-- https://msdn.microsoft.com/zh-cn/library/yyxz6h5w(v=vs.110).aspx
local function isLetter(c, index)    
  if index then
    c = get(c, index) 
  end
  if c < 128 then
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
  else  
    return (c >= 0x0400 and c <= 0x042F) 
      or (c >= 0x03AC and c <= 0x03CE) 
      or (c == 0x01C5 or c == 0x1FFC) 
      or (c >= 0x02B0 and c <= 0x02C1) 
      or (c >= 0x1D2C and c <= 0x1D61) 
      or (c >= 0x05D0 and c <= 0x05EA)
      or (c >= 0x0621 and c <= 0x063A)
      or (c >= 0x4E00 and c <= 0x9FC3) 
  end
end

local Char = System.defStc("System.Char", {
  ToString = string.char,
  CompareTo = Int.CompareTo,
  CompareToObj = Int.CompareToObj,
  Equals = Int.Equals,
  EqualsObj = Int.EqualsObj,
  GetHashCode = Int.GetHashCode,
  default = Int.default,
  IsControl = function (c, index)
    if index then
      c = get(c, index)
    end
    return (c >=0 and c <= 31) or (c >= 127 and c <= 159)
  end,
  IsDigit = isDigit,
  IsLetter = isLetter,
  IsLetterOrDigit = function (c, index)
    if index then
      c = get(c, index)
    end
    return isDigit(c) or isLetter(c)
  end,
  IsLower = function (c, index)
    if index then
      c = get(c, index)
    end
    return (c >= 97 and c <= 122) or (c >= 945 and c <= 969)
  end,
  IsNumber = function (c, index)
    if index then
      c = get(c, index)
    end
    return (c >= 48 and c <= 57) or c == 178 or c == 179 or c == 185 or c == 188 or c == 189 or c == 190
  end,
  IsPunctuation = function (c, index)
    if index then
      c = get(c, index)
    end
    if c < 256 then
      return (c >= 0x0021 and c <= 0x0023) 
        or (c >= 0x0025 and c <= 0x002A) 
        or (c >= 0x002C and c <= 0x002F) 
        or (c >= 0x003A and c <= 0x003B) 
        or (c >= 0x003F and c <= 0x0040)  
        or (c >= 0x005B and c <= 0x005D)
        or c == 0x5F or c == 0x7B or c == 0x007D or c == 0x00A1 or c == 0x00AB or c == 0x00AD or c == 0x00B7 or c == 0x00BB or c == 0x00BF
    end
    return false
  end,
  IsSeparator = function (c, index)
    if index then
      c = get(c, index)
    end
    return (c >= 0x2000 and c <= 0x200A) or isSeparatorTable[c] == true
  end,
  IsSymbol = function (c, index)
    if index then
      c = get(c, index)
    end
    if c < 256 then
      return (c >= 162 and c <= 169) or (c >= 174 and c <= 177) or isSymbolTable(c) == true
    end
    return false
  end,
  IsUpper = function (c, index)
    if index then
      c = get(c, index)
    end
    return (c >= 65 and c <= 90) or (c >= 913 and c <= 937)
  end,
  IsWhiteSpace = function (c, index)
    if index then
      c = get(c, index)
    end
    return (c >= 0x2000 and c <= 0x200A) or (c >= 0x0009 and c <= 0x000d) or isWhiteSpace[c] == true
  end,
  Parse = function (s)
    if s == nil then
      throw(System.ArgumentNullException())
    end
    if #s ~= 1 then
      throw(System.FormatException())
    end
    return s:byte()
  end,
  TryParse = function (s)
    if s == nil or #s ~= 1 then
      return false, 0
    end 
    return true, s:byte()
  end,
  ToLower = function (c)
    if (c >= 65 and c <= 90) or (c >= 913 and c <= 937) then
      return c + 32
    end
    return c
  end,
  ToUpper = function (c)
    if (c >= 97 and c <= 122) or (c >= 945 and c <= 969) then
      return c - 32
    end
    return c
  end,
  IsHighSurrogate = function (c, index) 
    if index then
      c = get(c, index)
    end
    return c >= 0xD800 and c <= 0xDBFF
  end,
  IsLowSurrogate = function (c, index) 
    if index then
      c = get(c, index)
    end
    return c >= 0xDC00 and c <= 0xDFFF
  end,
  IsSurrogate = function (c, index) 
    if index then
      c = get(c, index)
    end
    return c >= 0xD800 and c <= 0xDFFF
  end,
  base = function (_, T)
    return { System.IComparable, System.IComparable_1(T), System.IEquatable_1(T) }
  end
})

local ValueType = System.ValueType
local charMetaTable = setmetatable({ __index = ValueType, __call = Char.default }, ValueType)
setmetatable(Char, charMetaTable)
end

-- CoreSystemLib: String.lua
do
local System = System
local Char = System.Char
local throw = System.throw
local emptyFn = System.emptyFn
local lengthFn = System.lengthFn
local systemToString = System.toString
local debugsetmetatable = System.debugsetmetatable
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local FormatException = System.FormatException
local IndexOutOfRangeException = System.IndexOutOfRangeException

local string = string
local char = string.char
local rep = string.rep
local lower = string.lower
local upper = string.upper
local byte = string.byte
local sub = string.sub
local find = string.find
local gsub = string.gsub

local table = table
local tconcat = table.concat
local unpack = table.unpack
local getmetatable = getmetatable
local setmetatable = setmetatable
local select = select
local type = type
local String

local function toString(t, isch)
  if isch then return char(t) end
  return systemToString(t)
end

local function checkIndex(value, startIndex, count)
  if value == nil then throw(ArgumentNullException("value")) end
  local len = #value
  if not startIndex then
    startIndex, count = 0, len
  elseif not count then
    if startIndex < 0 or startIndex > len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    count = len - startIndex
  else
    if startIndex < 0 or startIndex > len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    if count < 0 or count > len - startIndex then
      throw(ArgumentOutOfRangeException("count"))
    end
  end
  return startIndex, count, len
end

local function ctor(String, value, startIndex, count)
  if type(value) == "number" then
    if startIndex <= 0 then throw(ArgumentOutOfRangeException("count")) end
    return rep(char(value), startIndex)
  end
  startIndex, count = checkIndex(value, startIndex, count)
  return char(unpack(value, startIndex + 1, startIndex + count))
end

local function get(this, index)
  local c = byte(this, index + 1)
  if not c then
    throw(IndexOutOfRangeException())
  end
  return c
end

local function compare(strA, strB, ignoreCase)
  if strA == nil then
    if strB == nil then
      return 0
    end
    return -1
  elseif strB == nil then
    return 1
  end

  if ignoreCase then
    strA, strB = lower(strA), lower(strB)
  end

  if strA < strB then return -1 end
  if strA > strB then return 1 end
  return 0
end

local function compareFull(...)
  local n = select("#", ...)
  if n == 2 then
    return compare(...)
  elseif n == 3 then
    local strA, strB, ignoreCase = ...
    if type(ignoreCase) == "number" then
      ignoreCase = ignoreCase % 2 ~= 0
    end
    return compare(strA, strB, ignoreCase)
  elseif n == 4 then
    local strA, strB, ignoreCase, options = ...
    if type(options) == "number" then
      ignoreCase = options == 1 or options == 268435456
    end
    return compare(strA, strB, ignoreCase)
  else
    local strA, indexA, strB, indexB, length, ignoreCase, options = ...
    if type(ignoreCase) == "number" then
      ignoreCase = ignoreCase % 2 ~= 0
    elseif type(options) == "number" then
      ignoreCase = options == 1 or options == 268435456
    end
    checkIndex(strA, indexA, length)
    checkIndex(strB, indexB, length)
    strA, strB = sub(strA, indexA + 1, indexA +  length), sub(strB, indexB + 1, indexB + length)
    return compare(strA, strB, ignoreCase) 
  end
end

local function concat(...)
  local t = {}
  local count = 1
  local len = select("#", ...)
  if len == 1 then
    local v = ...
    if System.isEnumerableLike(v) then
      local isch = v.__genericT__ == Char
      for _, v in System.each(v) do
        t[count] = toString(v, isch)
        count = count + 1
      end
    else
      return toString(v)
    end
  else
    for i = 1, len do
      local v = select(i, ...)
      t[count] = toString(v)
      count = count + 1
    end
  end
  return tconcat(t)
end

local function equals(this, value, comparisonType)
  if not comparisonType then
    return this == value
  end
  return compare(this, value, comparisonType % 2 ~= 0) == 0
end

local function throwFormatError()
  throw(FormatException("Input string was not in a correct format."))
end

local function formatBuild(format, len, select, ...)
  local t, count = {}, 1
  local i, j, s = 1
  while true do
    local startPos  = i
    while true do
      i, j, s = find(format, "([{}])", i)
      if not i then
        if count == 1 then
          return format
        end
        t[count] = sub(format, startPos)
        return table.concat(t)
      end
      local pos = i - 1
      i = i + 1
      local c = byte(format, i)
      if not c then throwFormatError() end
      if s == '{' then
        if c == 123 then
          i = i + 1
        else
          pos = i - 2
          if pos >= startPos then
            t[count] = sub(format, startPos, pos)
            count = count + 1
          end
          break
        end
      else
        if c == 125 then
          i = i + 1
        else
          throwFormatError()
        end
      end
      if pos >= startPos then
        t[count] = sub(format, startPos, pos)
        count = count + 1
      end
      t[count] = s
      count = count + 1
      startPos = i
    end
    i, j, s = find(format, "^(%d+)}", i)
    if not i then throwFormatError() end
    s = s + 1
    if s > len then throwFormatError() end
    s = select(s, ...)
    s = (s ~= nil and s ~= System.null) and toString(s)
    t[count] = s
    count = count + 1
    i = j + 1
  end
end

local function selectTable(i, t)
  return t[i]
end

local function format(format, ...)
  if format == nil then throw(ArgumentNullException()) end
  local len = select("#", ...)
  if len == 1 then
    local args = ...
    if System.isArrayLike(args) then
      return formatBuild(format, #args, selectTable, args)
    end
  end
  return formatBuild(format, len, select, ...)
end

local function isNullOrEmpty(value)
  return value == nil or #value == 0
end

local function isNullOrWhiteSpace(value)
  return value == nil or find(value, "^%s*$") ~= nil
end

local function joinEnumerable(separator, values)
  if values == nil then throw(ArgumentNullException("values")) end
  if type(separator) == "number" then
    separator = char(separator)
  end
  local isch = values.__genericT__ == Char
  local t = {}
  local len = 1
  for _, v in System.each(values) do
    if v ~= nil then
      t[len] = toString(v, isch)
      len = len + 1
    end
  end
  return tconcat(t, separator)
end

local function joinParams(separator, ...)
  if type(separator) == "number" then
    separator = char(separator)
  end
  local t = {}
  local len = 1
  local n = select("#", ...)
  if n == 1 then
    local values = ...
    if System.isArrayLike(values) then
      for i = 0, #values - 1 do
        local v = values:get(i)
        if v ~= nil then
          t[len] = toString(v)
          len = len + 1
        end
      end
      return tconcat(t, separator) 
    end
  end
  for i = 1, n do
    local v = select(i, ...)
    if v ~= nil then
      t[len] = toString(v)
      len = len + 1
    end
  end
  return tconcat(t, separator) 
end

local function join(separator, value, startIndex, count)
  if type(separator) == "number" then
    separator = char(separator)
  end
  local t = {}
  local len = 1
  if startIndex then  
    checkIndex(value, startIndex, count)
    for i = startIndex + 1, startIndex + count do
      local v = value[i]
      if v ~= System.null then
        t[len] = v
        len = len + 1
      end
    end
  else
    for _, v in System.each(value) do
      if v ~= nil then
        t[len] = v
        len = len + 1
      end
    end
  end
  return tconcat(t, separator)
end

local function compareToObj(this, v)
  if v == nil then return 1 end
  if type(v) ~= "string" then
    throw(ArgumentException("Arg_MustBeString"))
  end
  return compare(this, v)
end

local function escape(s)
  return gsub(s, "([%%%^%.])", "%%%1")
end

local function contains(this, value, comparisonType)
  if value == nil then throw(ArgumentNullException("value")) end
  if type(value) == "number" then
    value = char(value)
  end
  if comparisonType then
    local ignoreCase = comparisonType % 2 ~= 0
    if ignoreCase then
      this, value = lower(this), lower(value)
    end
  end 
  return find(this, escape(value)) ~= nil
end

local function copyTo(this, sourceIndex, destination, destinationIndex, count)
  if destination == nil then throw(ArgumentNullException("destination")) end
  if count < 0 then throw(ArgumentOutOfRangeException("count")) end
  local len = #this
  if sourceIndex < 0 or count > len - sourceIndex then throw(ArgumentOutOfRangeException("sourceIndex")) end
  if destinationIndex > #destination - count or destinationIndex < 0 then throw(ArgumentOutOfRangeException("destinationIndex")) end
  if count > 0 then
    destinationIndex = destinationIndex + 1
    for i = sourceIndex + 1, sourceIndex + count do
      destination[destinationIndex] = byte(this, i)
      destinationIndex = destinationIndex + 1
    end
  end
end

local function endsWith(this, suffix)
  return suffix == "" or sub(this, -#suffix) == suffix
end

local function equalsObj(this, v)
  if type(v) == "string" then
    return this == v
  end
  return false
end

local CharEnumerator = System.define("System.CharEnumerator", {
  base = { System.IEnumerator_1(System.Char), System.IDisposable, System.ICloneable },
  getCurrent = System.getCurrent,
  Dispose = emptyFn,
  MoveNext = function (this)
    local index, s = this.index, this.s
    if index <= #s then
      this.current = byte(s, index)
      this.index = index + 1
      return true
    end
    return false
  end
})

local function getEnumerator(this)
  return setmetatable({ s = this, index = 1 }, CharEnumerator)
end

local function getTypeCode()
  return 18
end

local function indexOf(this, value, startIndex, count, comparisonType)
  if value == nil then throw(ArgumentNullException("value")) end
  startIndex, count = checkIndex(this, startIndex, count)
  if type(value) == "number" then value = char(value) end
  local ignoreCase = comparisonType and comparisonType % 2 ~= 0
  if ignoreCase then
    this, value = lower(this), lower(value)
  end
  local i, j = find(this, escape(value), startIndex + 1)
  if i then
    local e = startIndex + count
    if j <= e then
      return i - 1
    end
    return - 1
  end
  return -1
end

local function indexOfAny(this, anyOf, startIndex, count)
  if anyOf == nil then throw(ArgumentNullException("chars")) end
  startIndex, count = checkIndex(this, startIndex, count)
  anyOf = "[" .. escape(char(unpack(anyOf))) .. "]"
  local i, j = find(this, anyOf, startIndex + 1)
  if i then
    local e = startIndex + count
    if j <= e then
      return i - 1
    end
    return - 1
  end
  return -1
end

local function insert(this, startIndex, value) 
  if value == nil then throw(ArgumentNullException("value")) end
  if startIndex < 0 or startIndex > #this then throw(ArgumentOutOfRangeException("startIndex")) end
  return sub(this, 1, startIndex) .. value .. sub(this, startIndex + 1)
end

local function chechLastIndexOf(value, startIndex, count)
  if value == nil then throw(ArgumentNullException("value")) end
  local len = #value
  if not startIndex then
    startIndex, count = len - 1, len
  elseif not count then
    count = len == 0 and 0 or (startIndex + 1)
  end
  if len == 0 then
    if startIndex ~= -1 and startIndex ~= 0 then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    if count ~= 0 then
      throw(ArgumentOutOfRangeException("count"))
    end
  end
  if startIndex < 0 or startIndex >= len then
    throw(ArgumentOutOfRangeException("startIndex"))
  end
  if count < 0 or startIndex - count + 1 < 0 then
    throw(ArgumentOutOfRangeException("count"))
  end
  return startIndex, count, len
end

local function lastIndexOf(this, value, startIndex, count, comparisonType)
  if value == nil then throw(ArgumentNullException("value")) end
  startIndex, count = chechLastIndexOf(this, startIndex, count)
  if type(value) == "number" then value = char(value) end
  local ignoreCase = comparisonType and comparisonType % 2 ~= 0
  if ignoreCase then
    this, value = lower(this), lower(value)
  end
  value = escape(value)
  local e = startIndex + 1
  local f = e - count + 1
  local index = -1  
  while true do
    local i, j = find(this, value, f)
    if not i or j > e then
      break
    end
    index = i - 1
    f = j + 1
  end
  return index
end

local function lastIndexOfAny(this, anyOf, startIndex, count)
  if anyOf == nil then throw(ArgumentNullException("chars")) end
  startIndex, count = chechLastIndexOf(this, startIndex, count)
  anyOf = "[" .. escape(char(unpack(anyOf))) .. "]"
  local f, e = startIndex - count + 1, startIndex + 1
  local index = -1
  while true do
    local i, j = find(this, anyOf, f)
    if not i or j > e then
      break
    end
    index = i - 1
    f = j + 1
  end
  return index
end

local function padLeft(this, totalWidth, paddingChar) 
  local len = #this;
  if len >= totalWidth then
    return this
  else
    paddingChar = paddingChar or 0x20
    return rep(char(paddingChar), totalWidth - len) .. this
  end
end

local function padRight(this, totalWidth, paddingChar) 
  local len = #this
  if len >= totalWidth then
    return this
  else
    paddingChar = paddingChar or 0x20
    return this .. rep(char(paddingChar), totalWidth - len)
  end
end

local function remove(this, startIndex, count) 
  startIndex, count = checkIndex(this, startIndex, count)
  return sub(this, 1, startIndex) .. sub(this, startIndex + 1 + count)
end

local function replace(this, a, b)
  if type(a) == "number" then
    a, b = char(a), char(b)
  end
  return gsub(this, escape(a), b)
end

local function findAny(s, strings, startIndex)
  local findBegin, findEnd
  for i = 1, #strings do
    local posBegin, posEnd = find(s, escape(strings[i]), startIndex)
    if posBegin then
      if not findBegin or posBegin < findBegin then
        findBegin, findEnd = posBegin, posEnd
      else
        break
      end
    end
  end
  return findBegin, findEnd
end

local function split(this, strings, count, options) 
  local t = {}
  local find = find
  if type(strings) == "table" then
    if #strings == 0 then
      return t
    end

    if type(strings[1]) == "string" then
      find = findAny
    else
      strings = char(unpack(strings))
      strings = escape(strings)
      strings = "[" .. strings .. "]"
    end
  elseif type(strings) == "string" then       
    strings = escape(strings)         
  else
    strings = char(strings)
    strings = escape(strings)
  end

  local len = 1
  local startIndex = 1
  while true do
    local posBegin, posEnd = find(this, strings, startIndex)
    posBegin = posBegin or 0
    local subStr = sub(this, startIndex, posBegin -1)
    if options ~= 1 or #subStr > 0 then
      t[len] = subStr
      len = len + 1
      if count then
        count = count -1
        if count == 0 then
          if posBegin ~= 0 then
            t[len - 1] = sub(this, startIndex)
          end
          break
        end
      end
    end
    if posBegin == 0 then
      break
    end 
    startIndex = posEnd + 1
  end   
  return System.arrayFromTable(t, String) 
end

local function startsWith(this, prefix)
  return sub(this, 1, #prefix) == prefix
end

local function substring(this, startIndex, count)
  startIndex, count = checkIndex(this, startIndex, count)
  return sub(this, startIndex + 1, startIndex + count)
end

local function toCharArray(str, startIndex, count)
  startIndex, count = checkIndex(str, startIndex, count)
  local t = {}
  local len = 1
  for i = startIndex + 1, startIndex + count do
    t[len] = byte(str, i)
    len = len + 1
  end
  return System.arrayFromTable(t, System.Char)
end

local function trim(this, chars, ...)
  if not chars then
    chars = "^%s*(.-)%s*$"
  else
    if type(chars) == "table" then
      chars = char(unpack(chars))
    else
      chars = char(chars, ...)
    end
    chars = escape(chars)
    chars = "^[" .. chars .. "]*(.-)[" .. chars .. "]*$"
  end
  return (gsub(this, chars, "%1"))
end

local function trimEnd(this, chars, ...)
  if not chars then
    chars = "(.-)%s*$"
  else
    if type(chars) == "table" then
      chars = char(unpack(chars))
    else
      chars = char(chars, ...)
    end
    chars = escape(chars)
    chars = "(.-)[" .. chars .. "]*$"
  end
  return (gsub(this, chars, "%1"))
end

local function trimStart(this, chars, ...)
  if not chars then
    chars = "^%s*(.-)"
  else
    if type(chars) == "table" then
      chars = char(unpack(chars))
    else
      chars = char(chars, ...)
    end
    chars = escape(chars)
    chars = "^[" .. chars .. "]*(.-)"
  end
  return (gsub(this, chars, "%1"))
end

local function inherits(_, T)
  return { System.IEnumerable_1(System.Char), System.IComparable, System.IComparable_1(T), System.IConvertible, System.IEquatable_1(T), System.ICloneable }
end

string.traceback = emptyFn  -- make throw(str) not fail
string.getLength = lengthFn
string.getCount = lengthFn
string.get = get
string.Compare = compareFull
string.CompareOrdinal = compareFull
string.Concat = concat
string.Copy = System.identityFn
string.Equals = equals
string.Format = format
string.IsNullOrEmpty = isNullOrEmpty
string.IsNullOrWhiteSpace = isNullOrWhiteSpace
string.JoinEnumerable = joinEnumerable
string.JoinParams = joinParams
string.Join = join
string.CompareTo = compare
string.CompareToObj = compareToObj
string.Contains = contains
string.CopyTo = copyTo
string.EndsWith = endsWith
string.EqualsObj = equalsObj
string.GetEnumerator = getEnumerator
string.GetTypeCode = getTypeCode
string.IndexOf = indexOf
string.IndexOfAny = indexOfAny
string.Insert = insert
string.LastIndexOf = lastIndexOf
string.LastIndexOfAny = lastIndexOfAny
string.PadLeft = padLeft
string.PadRight = padRight
string.Remove = remove
string.Replace = replace
string.Split = split
string.StartsWith = startsWith
string.Substring = substring
string.ToCharArray = toCharArray
string.ToLower = lower
string.ToLowerInvariant = lower
string.ToString = System.identityFn
string.ToUpper = upper
string.ToUpperInvariant = upper
string.Trim = trim
string.TrimEnd = trimEnd
string.TrimStart = trimStart

if debugsetmetatable then
  String = string
  String.__genericT__ = System.Char
  String.base = inherits
  System.define("System.String", String)

  debugsetmetatable("", String)
  local Object = System.Object
  local StringMetaTable = setmetatable({ __index = Object, __call = ctor }, Object)
  setmetatable(String, StringMetaTable)
else
  string.__call = ctor
  string.__index = string
  
  String = getmetatable("")
  String.__genericT__ = System.Char
  String.base = inherits
  System.define("System.String", String)
  String.__index = string
  setmetatable(String, string)
  setmetatable(string, System.Object)  
end
end

-- CoreSystemLib: Boolean.lua
do
local System = System
local throw = System.throw
local debugsetmetatable = System.debugsetmetatable
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException
local FormatException = System.FormatException

local type = type
local setmetatable = setmetatable

local function compareTo(this, v)
  if this == v then
    return 0
  elseif this == false then
    return -1     
  end
  return 1
end

local falseString = "False"
local trueString = "True"

local function parse(s)
  if s == nil then
    return nil, 1
  end
  local i, j, value = s:find("^[%s%c%z]*(%a+)[%s%c%z]*$")
  if value then
    s = value:lower()
    if s == "true" then
      return true
    elseif s == "false" then
      return false
    end
  end
  return nil, 2
end

local function toString(this)
  return this and trueString or falseString
end

local Boolean = System.defStc("System.Boolean", {
  default = System.falseFn,
  GetHashCode = System.identityFn,
  Equals = System.equals,
  CompareTo = compareTo,
  ToString = toString,
  FalseString = falseString,
  TrueString = trueString,
  CompareToObj = function (this, v)
    if v == nil then return 1 end
    if type(v) ~= "boolean" then
      throw(ArgumentException("Arg_MustBeBoolean"))
    end
    return compareTo(this, v)
  end,
  EqualsObj = function (this, v)
    if type(v) ~= "boolean" then
      return false
    end
    return this == v
  end,
  __concat = function (a, b)
    if type(a) == "boolean" then
      return toString(a) .. b
    else 
      return a .. toString(b)
    end
  end,
  __tostring = toString,
  Parse = function (s)
    local v, err = parse(s)
    if v == nil then
      if err == 1 then
        throw(ArgumentNullException()) 
      else
        throw(FormatException())
      end
    end
    return v
  end,
  TryParse = function (s)
    local v = parse(s)
    if v ~= nil then
      return true, v
    end
    return false, false
  end,
  base = function (_, T)
    return { System.IComparable, System.IConvertible, System.IComparable_1(T), System.IEquatable_1(T) }
  end
})
if debugsetmetatable then
  debugsetmetatable(false, Boolean)
end

local ValueType = System.ValueType
local boolMetaTable = setmetatable({ __index = ValueType, __call = Boolean.default }, ValueType)
setmetatable(Boolean, boolMetaTable)
end

-- CoreSystemLib: Delegate.lua
do
local System = System
local throw = System.throw
local Object = System.Object
local debugsetmetatable = System.debugsetmetatable
local ArgumentNullException = System.ArgumentNullException

local setmetatable = setmetatable
local assert = assert
local select = select
local type = type
local unpack = table.unpack
local tmove = table.move

local Delegate
local multicast

local function appendFn(t, count, f)
  if type(f) == "table" then
    for i = 1, #f do
      t[count] = f[i]
      count = count + 1
    end
  else
    t[count] = f
    count = count + 1
  end
  return count
end

local function combineImpl(fn1, fn2)    
  local t = setmetatable({}, multicast)
  local count = 1
  count = appendFn(t, count, fn1)
  appendFn(t, count, fn2)
  return t
end

local function combine(fn1, fn2)
  if fn1 ~= nil then
    if fn2 ~= nil then 
      return combineImpl(fn1, fn2) 
    end
    return fn1 
  end
  if fn2 ~= nil then return fn2 end
  return nil
end

local function equalsMulticast(fn1, fn2, start, count)
  for i = 1, count do
    if fn1[start + i] ~= fn2[i] then
      return false
    end
  end
  return true
end

local function delete(fn, count, deleteIndex, deleteCount)
  local t =  setmetatable({}, multicast)
  local len = 1
  for i = 1, deleteIndex - 1 do
    t[len] = fn[i]
    len = len + 1
  end
  for i = deleteIndex + deleteCount, count do
    t[len] = fn[i]
    len = len + 1
  end
  return t
end

local function removeImpl(fn1, fn2) 
  if type(fn2) ~= "table" then
    if type(fn1) ~= "table" then
      if fn1 == fn2 then
        return nil
      end
    else
      local count = #fn1
      for i = count, 1, -1 do
        if fn1[i] == fn2 then
          if count == 2 then
            return fn1[3 - i]
          else
            return delete(fn1, count, i, 1)
          end
        end
      end
    end
  elseif type(fn1) == "table" then
    local count1, count2 = #fn1, # fn2
    local diff = count1 - count2
    for i = diff + 1, 1, -1 do
      if equalsMulticast(fn1, fn2, i - 1, count2) then
        if diff == 0 then 
          return nil
        elseif diff == 1 then 
          return fn1[i ~= 1 and 1 or count1] 
        else
          return delete(fn1, count1, i, count2)
        end
      end
    end
  end
  return fn1
end

local function remove(fn1, fn2)
  if fn1 ~= nil then
    if fn2 ~= nil then
      return removeImpl(fn1, fn2)
    end
    return fn1
  end
  return nil
end

local multiKey = System.multiKey

local mt = {}
local function makeGenericTypes(...)
  local gt, gk = multiKey(mt, ...)
  local t = gt[gk]
  if t == nil then
    t = setmetatable({ ... }, Delegate)
    gt[gk] = t
  end
  return t
end

Delegate = System.define("System.Delegate", {
  __add = combine,
  __sub = remove,
  EqualsObj = System.equals,
  Combine = combine,
  Remove = remove,
  RemoveAll = function (source, value)
    local newDelegate
    repeat
      newDelegate = source
      source = remove(source, value)
    until newDelegate == source
    return newDelegate
  end,
  DynamicInvoke = function (this, ...)
    return this(...)
  end,
  GetType = function (this)
    return System.typeof(Delegate)
  end,
  GetInvocationList = function (this)
    local t
    if type(this) == "table" then
      t = {}
      tmove(this, 1, #this, 1, t)
    else
      t = { this }
    end
    return System.arrayFromTable(t, Delegate)
  end
})

local delegateMetaTable = setmetatable({ __index = Object, __call = makeGenericTypes }, Object)
setmetatable(Delegate, delegateMetaTable)
if debugsetmetatable then
  debugsetmetatable(System.emptyFn, Delegate)

  function System.event(name)
    local function a(this, v)
      this[name] = this[name] + v
    end
    local function r(this, v)
      this[name] = this[name] - v
    end
    return a, r
  end
else
  System.DelegateCombine = combine
  System.DelegateRemove = remove

  function System.event(name)
    local function a(this, v)
      this[name] = combine(this[name], v)
    end
    local function r(this, v)
      this[name] = remove(this[name], v)
    end
    return a, r
  end
end

multicast = setmetatable({
  __index = Delegate,
  __add = combine,
  __sub = remove,
  __call = function (t, ...)
    local result
    for i = 1, #t do
      result = t[i](...)
    end
    return result
  end,
  __eq = function (fn1, fn2)
    local len1, len2 = #fn1, #fn2
    if len1 ~= len2 then
      return false
    end
    for i = 1, len1 do
      if fn1[i] ~= fn2[i] then
        return false
      end
    end
    return true
  end
}, Delegate)

function System.fn(target, method)
  assert(method)
  if target == nil then throw(ArgumentNullException()) end
  local f = target[method]
  if f == nil then
    f = function (...)
      return method(target, ...)
    end
    target[method] = f
  end
  return f
end

local binds = setmetatable({}, { __mode = "k" })

function System.bind(f, n, ...)
  assert(f)
  local gt, gk = multiKey(binds, f, ...)
  local fn = gt[gk]
  if fn == nil then
    local args = { ... }
    fn = function (...)
      local len = select("#", ...)
      if len == n then
        return f(..., unpack(args))
      else
        assert(len > n)
        local t = { ... }
        for i = 1, #args do
          local j = args[i]
          if type(j) == "number" then
            j = select(n + j, ...)
            assert(j)
          end
          t[n + i] = j
        end
        return f(unpack(t, 1, n + #args))
      end
    end
    gt[gk] = fn
  end
  return fn
end

local function bind(f, create, ...)
  assert(f)
  local gt, gk = multiKey(binds, f, create)
  local fn = gt[gk]
  if fn == nil then
    fn = create(f, ...)
    gt[gk] = fn
  end
  return fn
end

local function create1(f, a)
  return function (...)
    return f(..., a)
  end
end

function System.bind1(f, a)
  return bind(f, create1, a)
end

local function create2(f, a, b)
  return function (...)
    return f(..., a, b)
  end
end

function System.bind2(f, a, b)
  return bind(f, create2, a, b)
end

local function create3(f, a, b, c)
  return function (...)
    return f(..., a, b, c)
  end
end

function System.bind3(f, a, b, c)
 return bind(f, create3, a, b, c)
end

local function create2_1(f)
  return function(x1, x2, T1, T2)
    return f(x1, x2, T2, T1)
  end
end

function System.bind2_1(f)
  return bind(f, create2_1) 
end

local function create0_2(f)
  return function(x1, x2, T1, T2)
    return f(x1, x2, T2)
  end
end

function System.bind0_2(f)
  return bind(f, create0_2) 
end

local EventArgs = System.define("System.EventArgs")
EventArgs.Empty = setmetatable({}, EventArgs)
end

-- CoreSystemLib: Enum.lua
do
local System = System
local throw = System.throw
local Int = System.Int
local Number = System.Number
local band = System.band
local bor = System.bor
local ArgumentNullException = System.ArgumentNullException
local ArgumentException = System.ArgumentException

local assert = assert
local pairs = pairs
local tostring = tostring
local type = type

local function toString(this, cls)
  if this == nil then return "" end
  if cls then
    for k, v in pairs(cls) do
      if v == this then
        return k
      end
    end
  end
  return tostring(this)
end

local function hasFlag(this, flag)
  if this == flag then
    return true
  end
  return band(this, flag) ~= 0
end

Number.EnumToString = toString
Number.HasFlag = hasFlag
System.EnumToString = toString
System.EnumHasFlag = hasFlag

local function tryParseEnum(enumType, value, ignoreCase)
  if enumType == nil then throw(ArgumentNullException("enumType")) end
  local cls = enumType[1] or enumType
  if cls.class ~= "E" then throw(ArgumentException("Arg_MustBeEnum")) end
  if value == nil then
    return
  end
  if ignoreCase then
    value = value:lower()
  end
  local i, j, s, r = 1
  while true do
    i, j, s = value:find("%s*(%a+)%s*", i)
    if not i then
      return
    end
    for k, v in pairs(cls) do
      if ignoreCase then
        k = k:lower()
      end
      if k == s then
        if not r then
          r = v
        else
          r = bor(r, v)
        end
        break
      end
    end
    i = value:find(',', j + 1)
    if not i then
      break
    end
    i = i + 1
  end
  return r
end

System.define("System.Enum", {
  CompareToObj = Int.CompareToObj,
  EqualsObj = Int.EqualsObj,
  default = Int.default,
  ToString = toString,
  HasFlag = hasFlag,
  GetName = function (enumType, value)
    if enumType == nil then throw(ArgumentNullException("enumType")) end
    if value == nil then throw(ArgumentNullException("value")) end
    if not enumType:getIsEnum() then throw(ArgumentException("Arg_MustBeEnum")) end
    for k, v in pairs(enumType[1]) do
      if v == value then
        return k
      end
    end
  end,
  GetNames = function (enumType)
    if enumType == nil then throw(ArgumentNullException("enumType")) end
    if not enumType:getIsEnum() then throw(ArgumentException("Arg_MustBeEnum")) end
    local t = {}
    local count = 1
    for k, v in pairs(enumType[1]) do
      if type(v) == "number" then
        t[count] = k
        count = count + 1
      end
    end
    return System.arrayFromTable(t, System.String)
  end,
  GetValues = function (enumType)
    if enumType == nil then throw(ArgumentNullException("enumType")) end
    if not enumType:getIsEnum() then throw(ArgumentException("Arg_MustBeEnum")) end
    local t = {}
    local count = 1
    for k, v in pairs(enumType[1]) do
      if type(v) == "number" then
        t[count] = v
        count = count + 1
      end
    end
    return System.arrayFromTable(t, System.Int32)
  end,
  IsDefined = function (enumType, value)
    if enumType == nil then throw(ArgumentNullException("enumType")) end
    if value == nil then throw(ArgumentNullException("value")) end
    if not enumType:getIsEnum() then throw(ArgumentException("Arg_MustBeEnum")) end
    local cls = enumType[1]
    local t = type(value)
    if t == "string" then
      return cls[value] ~= nil
    elseif t == "number" then
      for k, v in pairs(cls) do
        if v == value then
          return true
        end
      end
      return false
    end
    throw(System.InvalidOperationException())
  end,
  Parse = function (enumType, value, ignoreCase)
    local result = tryParseEnum(enumType, value, ignoreCase)
    if result == nil then
      throw(ArgumentException("Requested value '" .. value .. "' was not found."))
    end
    return result
  end,
  TryParse = function (type, value, ignoreCase)
    local result = tryParseEnum(type, value, ignoreCase)
    if result == nil then
      return false, 0
    end
    return true, result
  end
})
end

-- CoreSystemLib: TimeSpan.lua
do
local System = System
local throw = System.throw
local div = System.div
local trunc = System.trunc
local ArgumentException = System.ArgumentException
local OverflowException = System.OverflowException
local ArgumentNullException = System.ArgumentNullException
local FormatException = System.FormatException

local assert = assert
local getmetatable = getmetatable
local select = select
local sformat = string.format
local sfind = string.find
local tostring = tostring
local tonumber = tonumber
local floor = math.floor
local log10 = math.log10

local TimeSpan
local zero

local function compare(t1, t2)
  if t1.ticks > t2.ticks then return 1 end
  if t1.ticks < t2.ticks then return -1 end
  return 0
end

local function add(this, ts) 
  return TimeSpan(this.ticks + ts.ticks)
end

local function subtract(this, ts) 
  return TimeSpan(this.ticks - ts.ticks)
end

local function negate(this) 
  local ticks = this.ticks
  if ticks == -9223372036854775808 then
    throw(OverflowException("Overflow_NegateTwosCompNum"))
  end
  return TimeSpan(-ticks)
end

local function interval(value, scale)
  if value ~= value then 
    throw(ArgumentException("Arg_CannotBeNaN"))
  end
  local tmp = value * scale
  local millis = tmp + (value >=0 and 0.5 or -0.5)
  if millis > 922337203685477 or millis < -922337203685477 then
    throw(OverflowException("Overflow_TimeSpanTooLong"))
  end
  return TimeSpan(trunc(millis) * 10000)
end

local function getPart(this, i, j)
  local t = this.ticks
  local v = div(t, i) % j
  if v ~= 0 and t < 0 then
    return v - j
  end
  return v
end

local function parse(s)
  if s == nil then return nil, 1 end
  local i, j, k, sign, ch
  local day, hour, minute, second, milliseconds = 0, 0, 0, 0, 0
  i, j, sign, day = sfind(s, "^%s*([-]?)(%d+)")
  if not i then return end
  k = j + 1
  i, j, ch = sfind(s, "^([%.:])", k)
  if not i then 
    i, j = sfind(s, "^%s*$", k)
    if not i then return end
    k = -1
  else
    k = j + 1
    if ch == '.' then
      i, j, hour, minute = sfind(s, "^(%d+):(%d+)", k)
      if not i then return end
      k = j + 1
      i, j, second = sfind(s, "^:(%d+)", k)
      if not i then return end
    else
      i, j, hour = sfind(s, "^(%d+)", k)
      if not i then return end
      k = j + 1
      i, j, minute = sfind(s, "^:(%d+)", k)
      if not i then
        i, j = sfind(s, "^%s*$", k)
        if not i then
          return
        end
        day, hour, minute = 0, day, hour
        k = -1
      else
        k = j
        i, j, second = sfind(s, "^:(%d+)", k + 1)
        if not i then
          day, hour, minute, second = 0, day, hour, minute
          j = k
        end
      end
    end
  end
  if k ~= -1 then
    k = j + 1
    i, j, milliseconds = sfind(s, "^%.(%d+)%s*$", k)
    if not i then
      i, j = sfind(s, "^%s*$", k)
      if not i then return end
      milliseconds = 0
    else
      milliseconds = tonumber(milliseconds)
      local n = floor(log10(milliseconds) + 1)
      if n > 3 then
        if n > 7 then return end
        milliseconds = milliseconds / (10 ^ (n - 3))
      end
    end
  end
  if sign == '-' then
    day, hour, minute, second, milliseconds = -day, -hour, -minute, -second, -milliseconds
  end
  return TimeSpan(day, hour, minute, second, milliseconds)
end

TimeSpan = System.defStc("System.TimeSpan", {
  ticks = 0,
  __ctor__ = function (this, ...)
    local ticks
    local length = select("#", ...)
    if length == 0 then
    elseif length == 1 then
      ticks = ...
    elseif length == 3 then
      local hours, minutes, seconds = ...
      ticks = (((hours * 60 + minutes) * 60) + seconds) * 10000000
    elseif length == 4 then
      local days, hours, minutes, seconds = ...
      ticks = ((((days * 24 + hours) * 60 + minutes) * 60) + seconds) * 10000000
    elseif length == 5 then
      local days, hours, minutes, seconds, milliseconds = ...
      ticks = (((((days * 24 + hours) * 60 + minutes) * 60) + seconds) * 1000 + milliseconds) * 10000
    else 
      assert(ticks)
    end
    this.ticks = ticks
  end,
  Compare = compare,
  CompareTo = compare,
  CompareToObj = function (this, t)
    if t == nil then return 1 end
    if getmetatable(t) ~= TimeSpan then
      throw(ArgumentException("Arg_MustBeTimeSpan"))
    end
    compare(this, t)
  end,
  Equals = function (t1, t2)
    return t1.ticks == t2.ticks
  end,
  EqualsObj = function(this, t)
    if getmetatable(t) == TimeSpan then
      return this.ticks == t.ticks
    end
    return false
  end,
  GetHashCode = function (this)
    return this.ticks
  end,
  getTicks = function (this) 
    return this.ticks
  end,
  getDays = function (this) 
    return div(this.ticks, 864000000000)
  end,
  getHours = function(this)
    return getPart(this, 36000000000, 24)
  end,
  getMinutes = function (this)
    return getPart(this, 600000000, 60)
  end,
  getSeconds = function (this)
    return getPart(this, 10000000, 60)
  end,
  getMilliseconds = function (this)
    return getPart(this, 10000, 1000)
  end,
  getTotalDays = function (this) 
    return this.ticks / 864000000000
  end,
  getTotalHours = function (this) 
    return this.ticks / 36000000000
  end,
  getTotalMilliseconds = function (this) 
    return this.ticks / 10000
  end,
  getTotalMinutes = function (this) 
    return this.ticks / 600000000
  end,
  getTotalSeconds = function (this) 
    return this.ticks / 10000000
  end,
  Add = add,
  Subtract = subtract,
  Duration = function (this) 
    local ticks = this.ticks
    if ticks == -9223372036854775808 then
      throw(OverflowException("Overflow_Duration"))
    end
    return TimeSpan(ticks >= 0 and ticks or - ticks)
  end,
  Negate = negate,
  ToString = function (this) 
    local day, milliseconds = this:getDays(), this.ticks % 10000000
    local daysStr = day == 0 and "" or (day .. ".")
    local millisecondsStr = milliseconds == 0 and "" or (".%07d"):format(milliseconds)
    return sformat("%s%02d:%02d:%02d%s", daysStr, this:getHours(), this:getMinutes(), this:getSeconds(), millisecondsStr)
  end,
  Parse = function (s)
    local v, err = parse(s)
    if v then
      return v
    end
    if err == 1 then
      throw(ArgumentNullException())
    else
      throw(FormatException())
    end
  end,
  TryParse = function (s)
    local v = parse(s)
    if v then
      return true, v
    end
    return false, zero
  end,
  __add = add,
  __sub = subtract,
  __unm = negate,
  __eq = function (t1, t2)
    return t1.ticks == t2.ticks
  end,
  __lt = function (t1, t2)
    return t1.ticks < t2.ticks
  end,
  __le = function (t1, t2)
    return t1.ticks <= t2.ticks
  end,
  FromDays = function (value) 
    return interval(value, 864e5)
  end,
  FromHours = function (value) 
    return interval(value, 36e5)
  end,
  FromMilliseconds = function (value) 
    return interval(value, 1)
  end,
  FromMinutes = function (value) 
    return interval(value, 6e4)
  end,
  FromSeconds = function (value) 
    return interval(value, 1000)
  end,
  FromTicks = function (value) 
    return TimeSpan(value)
  end,
  base = function (_, T)
    return { System.IComparable, System.IComparable_1(T), System.IEquatable_1(T) }
  end,
  default = function ()
    return zero
  end,
  Zero = false,
  MaxValue = false,
  MinValue = false
})

zero = TimeSpan(0)
TimeSpan.Zero = zero
TimeSpan.MaxValue = TimeSpan(9223372036854775807)
TimeSpan.MinValue = TimeSpan(-9223372036854775808)
end

-- CoreSystemLib: DateTime.lua
do
local System = System
local throw = System.throw
local div = System.div
local trunc = System.trunc

local TimeSpan = System.TimeSpan
local compare = TimeSpan.Compare
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException
local FormatException = System.FormatException

local assert = assert
local getmetatable = getmetatable
local select = select
local sformat = string.format
local sfind = string.find
local os = {}
local ostime = GetTime
local osdifftime = difftime
local osdate = date
local tonumber = tonumber
local math = math
local floor = math.floor
local log10 = math.log10
local modf = math.modf

--http://referencesource.microsoft.com/#mscorlib/system/datetime.cs
local DateTime
local minValue

local daysToMonth365 = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365 }
local daysToMonth366 = { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366 }

local function isLeapYear(year) 
  if year < 1 or year > 9999 then 
    throw(ArgumentOutOfRangeException("year", "ArgumentOutOfRange_Year"))
  end
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function dateToTicks(year, month, day) 
  if year >= 1 and year <= 9999 and month >= 1 and month <= 12 then
    local days = isLeapYear(year) and daysToMonth366 or daysToMonth365
    if day >= 1 and day <= days[month + 1] - days[month] then
      local y = year - 1
      local n = y * 365 + div(y, 4) - div(y, 100) + div(y, 400) + days[month] + day - 1
      return n * 864000000000
    end
  end
end

local function timeToTicks(hour, minute, second)
  if hour >= 0 and hour < 24 and minute >= 0 and minute < 60 and second >=0 and second < 60 then 
    return (((hour * 60 + minute) * 60) + second) * 10000000
  end
  throw(ArgumentOutOfRangeException("ArgumentOutOfRange_BadHourMinuteSecond"))
end

local function checkTicks(ticks)
  if ticks < 0 or ticks > 3155378975999999999 then
    throw(ArgumentOutOfRangeException("ticks", "ArgumentOutOfRange_DateTimeBadTicks"))
  end
end

local function checkKind(kind) 
  if kind and (kind < 0 or kind > 2) then
    throw(ArgumentOutOfRangeException("kind"))
  end
end

local function addTicks(this, value)
  return DateTime(this.ticks + value, this.kind)
end

local function addTimeSpan(this, ts)
  return addTicks(this, ts.ticks)
end

local function add(this, value, scale)
  local millis = trunc(value * scale + (value >= 0 and 0.5 or -0.5))
  return addTicks(this, millis * 10000)
end

local function subtract(this, v) 
  if getmetatable(v) == DateTime then
    return TimeSpan(this.ticks - v.ticks)
  end
  return DateTime(this.ticks - v.ticks, this.kind) 
end

local function getDataPart(ticks, part)
  local n = div(ticks, 864000000000)
  local y400 = div(n, 146097)
  n = n - y400 * 146097
  local y100 = div(n, 36524)
  if y100 == 4 then y100 = 3 end
  n = n - y100 * 36524
  local y4 = div(n, 1461)
  n = n - y4 * 1461;
  local y1 = div(n, 365)
  if y1 == 4 then y1 = 3 end
  if part == 0 then
    return y400 * 400 + y100 * 100 + y4 * 4 + y1 + 1
  end
  n = n - y1 * 365
  if part == 1 then return n + 1 end
  local leapYear = y1 == 3 and (y4 ~= 24 or y100 == 3)
  local days = leapYear and daysToMonth366 or daysToMonth365
  local m = div(n, 32) + 1
  while n >= days[m + 1] do m = m + 1 end
  if part == 2 then return m end
  return n - days[m] + 1
end

local function getDatePart(ticks)
  local year, month, day
  local n = div(ticks, 864000000000)
  local y400 = div(n, 146097)
  n = n - y400 * 146097
  local y100 = div(n, 36524)
  if y100 == 4 then y100 = 3 end
  n = n - y100 * 36524
  local y4 = div(n, 1461)
  n = n - y4 * 1461
  local y1 = div(n, 365)
  if y1 == 4 then y1 = 3 end
  year = y400 * 400 + y100 * 100 + y4 * 4 + y1 + 1
  n = n - y1 * 365
  local leapYear = y1 == 3 and (y4 ~= 24 or y100 == 3)
  local days = leapYear and daysToMonth366 or daysToMonth365
  local m = div(n, 32) + 1
  while n >= days[m + 1] do m = m + 1 end
  month = m
  day = n - days[m] + 1
  return year, month, day
end

local function daysInMonth(year, month)
  if month < 1 or month > 12 then
    throw(ArgumentOutOfRangeException("month"))
  end
  local days = isLeapYear(year) and daysToMonth366 or daysToMonth365
  return days[month + 1] - days[month]
end

local function addMonths(this, months)
  if months < -120000 or months > 12000 then
    throw(ArgumentOutOfRangeException("months"))
  end
  local ticks = this.ticks
  local y, m, d = getDatePart(ticks)
  local i = m - 1 + months
  if i >= 0 then
    m = i % 12 + 1
    y = y + div(i, 12)
  else
    m = 12 + (i + 1) % -12
    y = y + div(i - 11, 12)
  end
  if y < 1 or y > 9999 then
    throw(ArgumentOutOfRangeException("months")) 
  end
  local days = daysInMonth(y, m)
  if d > days then d = days end
  return DateTime(dateToTicks(y, m, d) + ticks % 864000000000, this.kind)
end

local function getTimeZone()
  local date = osdate("*t")
  local dst = date.isdst
  local now = ostime(date)
  return osdifftime(now, ostime(osdate("!*t", now))) * 10000000, dst and 3600 * 10000000 or 0 
end

local timeZoneTicks, dstTicks = getTimeZone()

local time = System.config.time or ostime
System.time = time
System.currentTimeMillis = function () return trunc(time() * 1000) end

local function now()
  local seconds = time()
  local ticks = seconds * 10000000 + timeZoneTicks + dstTicks + 621355968000000000
  return DateTime(ticks, 2)
end

local function parse(s)
  if s == nil then
    return nil, 1
  end
  local i, j, year, month, day, hour, minute, second, milliseconds
  i, j, year, month, day = sfind(s, "^%s*(%d+)%s*/%s*(%d+)%s*/%s*(%d+)%s*")
  if i == nil then
    return nil, 2
  else
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
  end
  if j < #s then
    i, j, hour, minute = sfind(s, "^(%d+)%s*:%s*(%d+)", j + 1)
    if i == nil then
      return nil, 2
    else
      hour, minute = tonumber(hour), tonumber(minute)
    end
    local next = j + 1
    i, j, second = sfind(s, "^:%s*(%d+)", next)
    if i == nil then
      if sfind(s, "^%s*$", next) == nil then
        return nil, 2
      else
        second = 0
        milliseconds = 0
      end
    else
      second = tonumber(second)
      next = j + 1
      i, j, milliseconds = sfind(s, "^%.(%d+)%s*$", next)
      if i == nil then
        if sfind(s, "^%s*$", next) == nil then
          return nil, 2
        else
          milliseconds = 0
        end
      else
        milliseconds = tonumber(milliseconds)
        local n = floor(log10(milliseconds) + 1)
        if n > 3 then
          if n <= 7 then
            milliseconds = milliseconds / (10 ^ (n - 3))
          else
            local ticks = milliseconds / (10 ^ (n - 7))
            local _, decimal = modf(ticks)
            if decimal > 0.5 then
              ticks = ticks + 1
            end
            milliseconds = floor(ticks) / 10000
          end
        end
      end
    end
  end
  if hour == nil then
    return DateTime(year, month, day)
  end
  return DateTime(year, month, day, hour, minute, second, milliseconds)
end

DateTime = System.defStc("System.DateTime", {
  ticks = 0,
  kind = 0,
  Compare = compare,
  CompareTo = compare,
  CompareToObj = function (this, t)
    if t == nil then return 1 end
    if getmetatable(t) ~= DateTime then
      throw(ArgumentException("Arg_MustBeDateTime"))
    end
    return compare(this, t)
  end,
  Equals = function (t1, t2)
    return t1.ticks == t2.ticks
  end,
  EqualsObj = function (this, t)
    if getmetatable(t) == DateTime then
      return this.ticks == t.ticks
    end
    return false
  end,
  GetHashCode = function (this)
    return this.ticks
  end,
  IsLeapYear = isLeapYear,
  __ctor__ = function (this, ...)
    local len = select("#", ...)
    if len == 0 then
    elseif len == 1 then
      local ticks = ...
      checkTicks(ticks)
      this.ticks = ticks
    elseif len == 2 then
      local ticks, kind = ...
      checkTicks(ticks)
      checkKind(kind)
      this.ticks = ticks
      this.kind = kind
    elseif len == 3 then
      this.ticks = dateToTicks(...)
    elseif len == 6 then
      local year, month, day, hour, minute, second = ...
      this.ticks = dateToTicks(year, month, day) + timeToTicks(hour, minute, second)
    elseif len == 7 then
      local year, month, day, hour, minute, second, millisecond = ...
      this.ticks = dateToTicks(year, month, day) + timeToTicks(hour, minute, second) + millisecond * 10000
    elseif len == 8 then
      local year, month, day, hour, minute, second, millisecond, kind = ...
      checkKind(kind)
      this.ticks = dateToTicks(year, month, day) + timeToTicks(hour, minute, second) + millisecond * 10000
      this.kind = kind
    else
      assert(false)
    end
  end,
  AddTicks = addTicks,
  Add = addTimeSpan,
  AddDays = function (this, days)
    return add(this, days, 86400000)
  end,
  AddHours = function (this, hours)
    return add(this, hours, 3600000)
  end,
  AddMinutes = function (this, minutes) 
    return add(this, minutes, 60000);
  end,
  AddSeconds = function (this, seconds)
    return add(this, seconds, 1000)
  end,
  AddMilliseconds = function (this, milliseconds)
    return add(this, milliseconds, 1)
  end,
  DaysInMonth = daysInMonth,
  AddMonths = addMonths,
  AddYears = function (this, years)
    if years < - 10000 or years > 10000 then
      throw(ArgumentOutOfRangeException("years")) 
    end
    return addMonths(this, years * 12)
  end,
  SpecifyKind = function (this, kind)
    return DateTime(this.ticks, kind)
  end,
  Subtract = subtract,
  getDay = function (this)
    return getDataPart(this.ticks, 3)
  end,
  getDate = function (this)
    local ticks = this.ticks
    return DateTime(ticks - ticks % 864000000000, this.kind)
  end,
  getDayOfWeek = function (this)
    return (div(this.ticks, 864000000000) + 1) % 7
  end,
  getDayOfYear = function (this)
    return getDataPart(this.ticks, 1)
  end,
  getKind = function (this)
    return this.kind
  end,
  getHour = TimeSpan.getHours,
  getMinute = TimeSpan.getMinutes,
  getSecond = TimeSpan.getSeconds,
  getMillisecond = TimeSpan.getMilliseconds,
  getMonth = function (this)
    return getDataPart(this.ticks, 2)
  end,
  getYear = function (this)
    return getDataPart(this.ticks, 0)
  end,
  getTimeOfDay = function (this)
    return TimeSpan(this.ticks % 864000000000)
  end,
  getTicks = function (this)
    return this.ticks
  end,
  BaseUtcOffset = TimeSpan(timeZoneTicks),
  getUtcNow = function ()
    local seconds = time()
    local ticks = seconds * 10000000 + 621355968000000000
    return DateTime(ticks, 1)
  end,
  getNow = now,
  getToday = function ()
    return now():getDate()
  end,
  ToLocalTime = function (this)
    if this.kind == 2 then 
      return this
    end
    local ticks = this.ticks + timeZoneTicks + dstTicks
    return DateTime(ticks, 2)
  end,
  ToUniversalTime = function (this)
    if this.kind == 1 then
      return this
    end
    local ticks = this.ticks - timeZoneTicks - dstTicks
    return DateTime(ticks, 1)
  end,
  IsDaylightSavingTime = function(this)
    return this.kind == 2 and dstTicks > 0
  end,
  ToString = function (this)
    local year, month, day = getDatePart(this.ticks)
    return sformat("%d/%d/%d %02d:%02d:%02d", year, month, day, this:getHour(), this:getMinute(), this:getSecond())
  end,
  Parse = function (s)
    local v, err = parse(s)
    if v then
      return v
    end
    if err == 1 then
      throw(ArgumentNullException())
    else
      throw(FormatException())
    end
  end,
  TryParse = function(s)
    local v = parse(s)
    if v then
      return true, v
    end
    return false, minValue
  end,
  __add = addTimeSpan,
  __sub = subtract,
  __eq = TimeSpan.__eq,
  __lt = TimeSpan.__lt,
  __le = TimeSpan.__le,
  base =  function(_, T)
    return { System.IComparable, System.IComparable_1(T), System.IConvertible, System.IEquatable_1(T), System.IFormattable }
  end,
  default = function ()
    return minValue
  end,
  MinValue = false,
  MaxValue = false
})

minValue = DateTime(0)
DateTime.MinValue = minValue
DateTime.MaxValue = DateTime(3155378975999999999)
end

-- CoreSystemLib: Collections/EqualityComparer.lua
do
local System = System
local define = System.define
local throw = System.throw
local equalsObj = System.equalsObj
local compareObj = System.compareObj
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException

local type = type

local EqualityComparer
EqualityComparer = define("System.EqualityComparer", function (T)
  local equals
  local Equals = T.Equals
  if Equals then
    if T.class == 'S' then
      equals = Equals 
    else
      equals = function (x, y) 
        return x:Equals(y) 
      end 
    end
  else
    equals = equalsObj
  end
  local function getHashCode(x)
    if type(x) == "table" then
      return x:GetHashCode()
    end
    return x
  end
  local defaultComparer
  return {
    __genericT__ = T,
    base = { System.IEqualityComparer_1(T), System.IEqualityComparer }, 
    getDefault = function ()
      local comparer = defaultComparer 
      if comparer == nil then
        comparer = EqualityComparer(T)()
        defaultComparer = comparer
      end
      return comparer
    end,
    EqualsOf = function (this, x, y)
      if x ~= nil then
        if y ~= nil then return equals(x, y) end
        return false
      end                 
      if y ~= nil then return false end
      return true
    end,
    GetHashCodeOf = function (this, obj)
      if obj == nil then return 0 end
      return getHashCode(obj)
    end,
    GetHashCodeObjOf = function (this, obj)
      if obj == nil then return 0 end
      if System.is(obj, T) then return getHashCode(obj) end
      throw(ArgumentException("Type of argument is not compatible with the generic comparer."))
      return false
    end,
    EqualsObjOf = function (this, x, y)
      if x == y then return true end
      if x == nil or y == nil then return false end
      local is = System.is
      if is(x, T) and is(y, T) then return equals(x, y) end
      throw(ArgumentException("Type of argument is not compatible with the generic comparer."))
      return false
    end
  }
end)

local function compare(this, a, b)
  return compareObj(a, b)
end

define("System.Comparer", (function ()
  local Comparer
  Comparer = {
    base = { System.IComparer },
    static = function (this)
      local default = Comparer()
      this.Default = default
      this.DefaultInvariant = default
    end,
    Compare = compare
  }
  return Comparer
end)())

local Comparer, ComparisonComparer

ComparisonComparer = define("System.ComparisonComparer", function (T)
  return {
    base = { Comparer(T) },
    __ctor__ = function (this, comparison)
      this.comparison = comparison
    end,
    Compare = function (this, x, y)
      return this.comparison(x, y)
    end
  }
end)

Comparer = define("System.Comparer_1", function (T)
  local Compare
  local compareTo = T.CompareTo
  if compareTo then
    if T.class ~= 'S' then
      compareTo = function (x, y)
        return x:CompareTo(y)
      end
    end
    Compare = function (this, x, y)
      if x ~= nil then
        if y ~= nil then 
          return compareTo(x, y) 
        end
        return 1
      end                 
      if y ~= nil then return -1 end
      return 0
    end
  else
    Compare = compare
  end

  local defaultComparer
  local function getDefault()
    local comparer = defaultComparer 
    if comparer == nil then
      comparer = Comparer(T)()
      defaultComparer = comparer
    end
    return comparer
  end

  local function Create(comparison)
    if comparison == nil then throw(ArgumentNullException("comparison")) end
    return ComparisonComparer(T)(comparison)
  end

  return {
    __genericT__ = T,
    base = { System.IComparer_1(T), System.IComparer }, 
    getDefault = getDefault,
    getDefaultInvariant = getDefault,
    Compare = Compare,
    Create = Create
  }
end)
end

-- CoreSystemLib: Array.lua
do
local System = System
local define = System.define
local throw = System.throw
local div = System.div
local trueFn = System.trueFn
local falseFn = System.falseFn
local lengthFn = System.lengthFn

local InvalidOperationException = System.InvalidOperationException
local NullReferenceException = System.NullReferenceException
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local IndexOutOfRangeException = System.IndexOutOfRangeException
local NotSupportedException = System.NotSupportedException
local EqualityComparer = System.EqualityComparer
local Comparer_1 = System.Comparer_1
local IEnumerator_1 = System.IEnumerator_1

local assert = assert
local select = select
local getmetatable = getmetatable
local setmetatable = setmetatable
local type = type
local table = table
local tinsert = table.insert
local tremove = table.remove
local tmove = table.move
local tsort = table.sort
local pack = table.pack
local unpack = table.unpack
local error = error
local coroutine = coroutine
local ccreate = coroutine.create
local cresume = coroutine.resume
local cyield = coroutine.yield

local null = {}
local arrayEnumerator
local arrayFromTable

local versions = setmetatable({}, { __mode = "k" })
System.versions = versions

local function throwFailedVersion()
  throw(InvalidOperationException("Collection was modified; enumeration operation may not execute."))
end

local function checkIndex(t, index) 
  if index < 0 or index >= #t then
    throw(ArgumentOutOfRangeException("index"))
  end
end

local function checkIndexAndCount(t, index, count)
  if t == nil then throw(ArgumentNullException("array")) end
  if index < 0 or count < 0 or index + count > #t then
    throw(ArgumentOutOfRangeException("index or count"))
  end
end

local function wrap(v)
  if v == nil then 
    return null 
  end
  return v
end

local function unWrap(v)
  if v == null then 
    return nil 
  end
  return v
end

local function ipairs(t)
  local version = versions[t]
  return function (t, i)
    if version ~= versions[t] then
      throwFailedVersion()
    end
    local v = t[i]
    if v ~= nil then
      if v == null then
        v = nil
      end
      return i + 1, v
    end
  end, t, 1
end

local function eachFn(en)
  if en:MoveNext() then
    return true, en:getCurrent()
  end
  return nil
end

local function each(t)
  if t == nil then throw(NullReferenceException(), 1) end
  local getEnumerator = t.GetEnumerator
  if getEnumerator == arrayEnumerator 
    or getEnumerator == nil or not getEnumerator then
    return ipairs(t)
  end
  local en = getEnumerator(t)
  return eachFn, en
end

function System.isArrayLike(t)
  return type(t) == "table" and t.GetEnumerator == arrayEnumerator
end

function System.isEnumerableLike(t)
  return type(t) == "table" and t.GetEnumerator ~= nil
end

function System.toLuaTable(array)
  local t = {}
  for i = 1, #array do
    local item = array[i]
    if item ~= null then
      t[i] = item
    end
  end   
  return t
end

System.null = null
System.Void = null
System.each = each
System.ipairs = ipairs
System.throwFailedVersion = throwFailedVersion

System.wrap = wrap
System.unWrap = unWrap
System.checkIndex = checkIndex
System.checkIndexAndCount = checkIndexAndCount

local Array
local emptys = {}

local function get(t, index)
  local v = t[index + 1]
  if v == nil then
    throw(ArgumentOutOfRangeException("index"))
  end
  if v ~= null then 
    return v
  end
  return nil
end

local function set(t, index, v)
  index = index + 1
  if t[index] == nil then
    throw(ArgumentOutOfRangeException("index"))
  end
  t[index] = v == nil and null or v
  versions[t] = (versions[t] or 0) + 1
end

local function add(t, v)
  local n = #t
  t[n + 1] = v == nil and null or v
  versions[t] = (versions[t] or 0) + 1
  return n
end

local function addRange(t, collection)
  if collection == nil then throw(ArgumentNullException("collection")) end
  local count = #t + 1
  if collection.GetEnumerator == arrayEnumerator then
    tmove(collection, 1, #collection, count, t)
  else
    for _, v in each(collection) do
      t[count] = v == nil and null or v
      count = count + 1
    end
  end
  versions[t] = (versions[t] or 0) + 1
end

local function unset()
  throw(NotSupportedException("Collection is read-only."))
end

local function fill(t, f, e, v)
  while f <= e do
    t[f] = v
    f = f + 1
  end
end

local function buildArray(T, len, t)
  if t == nil then 
    t = {}
    if len > 0 then
      local genericT = T.__genericT__
      local default = genericT:default()
      if default == nil then
        fill(t, 1, len, null)
      elseif type(default) ~= "table" then
        fill(t, 1, len, default)
      else
        for i = 1, len do
          t[i] = genericT:default()
        end
      end
    end
  else
    if len > 0 then
      local default = T.__genericT__:default()
      if default == nil then
        for i = 1, len do
          if t[i] == nil then
            t[i] = null
          end
        end
      end
    end
  end
  return setmetatable(t, T)
end

local function indexOf(t, v, startIndex, count)
  if t == nil then throw(ArgumentNullException("array")) end
  local len = #t
  if not startIndex then
    startIndex, count = 0, len
  elseif not count then
    if startIndex < 0 or startIndex > len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    count = len - startIndex
  else
    if startIndex < 0 or startIndex > len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    if count < 0 or count > len - startIndex then
      throw(ArgumentOutOfRangeException("count"))
    end
  end
  local comparer = EqualityComparer(t.__genericT__).getDefault()
  local equals = comparer.EqualsOf
  for i = startIndex + 1, startIndex + count do
    local item = t[i]
    if item == null then item = nil end
    if equals(comparer, item, v) then
      return i - 1
    end
  end
  return -1
end

local function findIndex(t, startIndex, count, match)
  if t == nil then throw(ArgumentNullException("array")) end
  local len = #t
  if not count then
    startIndex, count, match = 0, len, startIndex
  elseif not match then
    if startIndex < 0 or startIndex > len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    count, match = len - startIndex, count
  else
    if startIndex < 0 or startIndex > len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    if count < 0 or count > len - startIndex then
      throw(ArgumentOutOfRangeException("count"))
    end
  end
  if match == nil then throw(ArgumentNullException("match")) end
  local endIndex = startIndex + count
  for i = startIndex + 1, endIndex  do
    local item = t[i]
    if item == null then item = nil end
    if match(item) then
      return i - 1
    end
  end
  return -1
end

local function copy(sourceArray, sourceIndex, destinationArray, destinationIndex, length, reliable)
  if not reliable then
    checkIndexAndCount(sourceArray, sourceIndex, length)
    checkIndexAndCount(destinationArray, destinationIndex, length)
  end
  tmove(sourceArray, sourceIndex + 1, sourceIndex + length, destinationIndex + 1, destinationArray)
end

local function removeRange(t, index, count)
  local n = #t
  if count < 0 or index > n - count then
    throw(ArgumentOutOfRangeException("index or count"))
  end
  if count > 0 then
    if index + count < n then
      tmove(t, index + count + 1, n, index + 1)
    end
    fill(t, n - count + 1, n, nil)
    versions[t] = (versions[t] or 0) + 1
  end
end

local function findAll(t, match)
  if t == nil then throw(ArgumentNullException("array")) end
  if match == nil then throw(ArgumentNullException("match")) end
  local list = {}
  local count = 1
  for i = 1, #t do
    local item = t[i]
    if (item == null and match(nil)) or match(item) then
      list[count] = item
      count = count + 1
    end
  end
  return list
end

local function getComp(t, comparer)
  local compare
  if comparer then
    if type(comparer) == "function" then
      compare = comparer
    else
      local Compare = comparer.Compare
      if Compare then
        compare = function (x, y) return Compare(comparer, x, y) end
      else
        compare = comparer
      end
    end
  else
    comparer = Comparer_1(t.__genericT__).getDefault()
    local Compare = comparer.Compare
    compare = function (x, y) return Compare(comparer, x, y) end
  end
  return function(x, y) 
    if x == null then x = nil end
    if y == null then y = nil end
    return compare(x, y) < 0
  end
end

local function sort(t, comparer)
  if #t > 1 then
    tsort(t, getComp(t, comparer))
    versions[t] = (versions[t] or 0) + 1
  end
end

local ArrayEnumerator = define("System.ArrayEnumerator", function (T)
  return {
    base = { IEnumerator_1(T) }
  }
end, {
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  Reset = function (this)
    this.index = 1
    this.current = nil
  end,
  MoveNext = function (this)
    local t = this.list
    if this.version ~= versions[t] then
      throwFailedVersion()
    end
    local index = this.index
    local v = t[index]
    if v ~= nil then
      if v == null then
        this.current = nil
      else
        this.current = v
      end
      this.index = index + 1
      return true
    end
    this.current = nil
    return false
  end
})

arrayEnumerator = function (t, T)
  if not T then T = t.__genericT__ end
  return setmetatable({ list = t, index = 1, version = versions[t], currnet = T:default() }, ArrayEnumerator(T))
end

local ArrayReverseEnumerator = define("System.ArrayReverseEnumerator", function (T)
  return {
    base = { IEnumerator_1(T) }
  }
end, {
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  Reset = function (this)
    this.index = #this.list
    this.current = nil
  end,
  MoveNext = function (this)
    local t = this.list
    if this.version ~= versions[t] then
      throwFailedVersion()
    end
    local index = this.index
    local v = t[index]
    if v ~= nil then
      if v == null then
        this.current = nil
      else
        this.current = v
      end
      this.index = index - 1
      return true
    end
    this.current = nil
    return false
  end
})

local function reverseEnumerator(t)
  local T = t.__genericT__
  return setmetatable({ list = t, index = #t, version = versions[t], currnet = T:default() }, ArrayReverseEnumerator(T))
end

local function checkArrayIndex(index1, index2)
  if index2 then
    throw(ArgumentException("Indices length does not match the array rank."))
  elseif type(index1) == "table" then
    if #index1 ~= 1 then
      throw(ArgumentException("Indices length does not match the array rank."))
    else
      index1 = index1[1]
    end
  end
  return index1
end

Array = {
  version = 0,
  new = buildArray,
  set = set,
  get = get,
  ctorList = function (t, ...)
    local len = select("#", ...)
    if len == 0 then return end
    local collection = ...
    if type(collection) == "number" then return end
    addRange(t, collection)
  end,
  add = add,
  addObj = function (this, item)
    if not System.is(item, this.__genericT__) then
      throw(ArgumentException())
    end
    return add(this, item)
  end,
  addRange = addRange,
  AsReadOnly = function (t)
    return System.ReadOnlyCollection(t.__genericT__)(t)
  end,
  clear = function (t)
    local size = #t
    if size > 0 then
      for i = 1, size do
        t[i] = nil
      end
      versions[t] = (versions[t] or 0) + 1
    end
  end,
  findAll = function (t, match)
    return setmetatable(findAll(t, match), System.List(t.__genericT__))
  end,
  first = function (t)
    if #t == 0 then throw(InvalidOperationException()) end
    local v = t[1]
    if v ~= null then
      return v
    end
    return nil
  end,
  insert = function (t, index, v)
    if index < 0 or index > #t then
      throw(ArgumentOutOfRangeException("index"))
    end
    tinsert(t, index + 1, v == nil and null or v)
    versions[t] = (versions[t] or 0) + 1
  end,
  insertRange = function (t, index, collection) 
    if collection == nil then throw(ArgumentNullException("collection")) end
    local len = #t
    if index < 0 or index > len then
      throw(ArgumentOutOfRangeException("index"))
    end
    if t.GetEnumerator == arrayEnumerator then
      local count = #collection
      if count > 0 then
        if index < len then
          tmove(t, index + 1, len, index + 1 + count, t)
        end
        if t == collection then
          tmove(t, 1, index, index + 1, t)
          tmove(t, index + 1 + count, count * 2, index * 2 + 1, t)
        else
          tmove(collection, 1, count, index + 1, t)
        end
      end
    else
      for _, v in each(collection) do
        index = index + 1
        tinsert(t, index, v == nil and null or v)
      end
    end
    versions[t] = (versions[t] or 0) + 1
  end,
  last = function (t)
    local n = #t
    if n == 0 then throw(InvalidOperationException()) end
    local v = t[n]
    if v ~= null then
      return v
    end
    return nil
  end,
  popFirst = function (t)
    if #t == 0 then throw(InvalidOperationException()) end
    local v = t[1]
    tremove(t, 1)
    versions[t] = (versions[t] or 0) + 1
    if v ~= null then
      return v
    end
    return nil
  end,
  popLast = function (t)
    local n = #t
    if n == 0 then throw(InvalidOperationException()) end
    local v = t[n]
    t[n] = nil
    if v ~= null then
      return v
    end
    return nil
  end,
  removeRange = removeRange,
  remove = function (t, v)
    local index = indexOf(t, v)
    if index >= 0 then
      tremove(t, index + 1)
      versions[t] = (versions[t] or 0) + 1
      return true
    end
    return false
  end,
  removeAll = function (t, match)
    if match == nil then throw(ArgumentNullException("match")) end
    local size = #t
    local freeIndex = 1
    while freeIndex <= size do
      local item = t[freeIndex]
      if item == null then  item = nil end
      if match(item) then
        break
      end
      freeIndex = freeIndex + 1 
    end
    if freeIndex > size then return 0 end
  
    local current = freeIndex + 1
    while current <= size do 
      while current <= size do
        local item = t[current]
        if item == null then item = nil end
        if not match(item) then
          break
        end
        current = current + 1 
      end
      if current <= size then
        t[freeIndex] = t[current]
        freeIndex = freeIndex + 1
        current = current + 1
      end
    end
    freeIndex = freeIndex -1
    local count = size - freeIndex
    removeRange(t, freeIndex, count)
    return count
  end,
  removeAt = function (t, index)
    local v = tremove(t, index + 1)
    if v == nil then
      throw(ArgumentOutOfRangeException("index"))
    end
    versions[t] = (versions[t] or 0) + 1
  end,
  getRange = function (t, index, count)
    if count < 0 or index > #t - count then
      throw(ArgumentOutOfRangeException("index or count"))
    end
    local list = {}
    tmove(t, index + 1, index + count, 1, list)
    return setmetatable(list, System.List(t.__genericT__))
  end,
  reverseEnumerator = reverseEnumerator,
  getCount = lengthFn,
  getSyncRoot = System.identityFn,
  getLongLength = lengthFn,
  getLength = lengthFn,
  getIsSynchronized = falseFn,
  getIsReadOnly = falseFn,
  getIsFixedSize = trueFn,
  getRank = System.oneFn,
  Add = unset,
  Clear = unset,
  Insert = unset,
  Remove = unset,
  RemoveAt = unset,
  BinarySearch = function (t, ...)
    if t == nil then throw(ArgumentNullException("array")) end
    local len = #t
    local index, count, v, comparer
    local n = select("#", ...)
    if n == 1 or n == 2 then
      index, count, v, comparer = 0, len, ...
    else
      index, count, v, comparer = ...
    end
    checkIndexAndCount(t, index, count)
    local compare
    if comparer == nil then
      comparer = Comparer_1(t.__genericT__).getDefault()
      compare = comparer.Compare 
    else
      compare = comparer.Compare
    end
    local lo = index
    local hi = index + count - 1
    while lo <= hi do
      local i = lo + div(hi - lo, 2)
      local item = t[i + 1]
      if item == null then item = nil end
      local order = compare(comparer, item, v);
      if order == 0 then return i end
      if order < 0 then
        lo = i + 1
      else
        hi = i - 1
      end
    end
    return -1
  end,
  ClearArray = function (t, index, length)
    if t == nil then throw(ArgumentNullException("array")) end
    if index < 0 or length < 0 or index + length > #t then
      throw(IndexOutOfRangeException())
    end
    local default = t.__genericT__:default()
    if default == nil then default = null end
    fill(t, index + 1, index + length, default)
  end,
  Contains = function (t, v)
    return indexOf(t, v) ~= -1
  end,
  Copy = function (t, ...)
    local len = select("#", ...)     
    if len == 2 then
      local array, length = ...
      copy(t, 0, array, 0, length)
    else 
      copy(t, ...)
    end
  end,
  CreateInstance = function (elementType, length)
    return buildArray(Array(elementType[1]), length)
  end,
  Empty = function (T)
    local t = emptys[T]
    if t == nil then
      t = Array(T)()
      emptys[T] = t
    end
    return t
  end,
  Exists = function (t, match)
    return findIndex(t, match) ~= -1
  end,
  Fill = function (t, value, startIndex, count)
    if t == nil then throw(ArgumentNullException("array")) end
    local len = #t
    if not startIndex then
      startIndex, count = 0, len
    else
      if startIndex < 0 or startIndex > len then
        throw(ArgumentOutOfRangeException("startIndex"))
      end
      if count < 0 or count > len - startIndex then
        throw(ArgumentOutOfRangeException("count"))
      end
    end
    fill(t, startIndex + 1, startIndex + count, value)
  end,
  Find = function (t, match)
    if t == nil then throw(ArgumentNullException("array")) end
    if match == nil then throw(ArgumentNullException("match")) end
    for i = 1, #t do
      local item = t[i]
      if item == null then item = nil end
      if match(item) then
        return item
      end
    end
    return t.__genericT__:default()
  end,
  FindAll = function (t, match)
    return setmetatable(findAll(t, match), Array(t.__genericT__))
  end,
  FindIndex = findIndex,
  FindLast = function (t, match)
    if t == nil then throw(ArgumentNullException("array")) end
    if match == nil then throw(ArgumentNullException("match")) end
    for i = #t, 1, -1 do
      local item = t[i]
      if item == null then item = nil end
      if match(item) then
        return item
      end
    end
    return t.__genericT__:default()
  end,
  FindLastIndex = function (t, startIndex, count, match)
    if t == nil then throw(ArgumentNullException("array")) end
    local len = #t
    if not count then
      startIndex, count, match = len - 1, len, startIndex
    elseif not match then
      count, match = startIndex + 1, count
    end
    if match == nil then throw(ArgumentNullException("match")) end
    if count < 0 or startIndex - count + 1 < 0 then
      throw(ArgumentOutOfRangeException("count"))
    end
    local endIndex = startIndex - count + 1
    for i = startIndex + 1, endIndex + 1, -1 do
      local item = t[i]
      if item == null then
        item = nil
      end
      if match(item) then
        return i - 1
      end
    end
    return -1
  end,
  ForEach = function (t, action)
    if action == nil then throw(ArgumentNullException("action")) end
    for i = 1, #t do
      local item = t[i]
      if item == null then item = nil end
      action(item)
    end
  end,
  IndexOf = indexOf,
  LastIndexOf = function (t, value, startIndex, count)
    if t == nil then throw(ArgumentNullException("array")) end
    local len = #t
    if not startIndex then
      startIndex, count = len - 1, len
    elseif not count then
      count = len == 0 and 0 or (startIndex + 1)
    end
    if len == 0 then
      if startIndex ~= -1 and startIndex ~= 0 then
        throw(ArgumentOutOfRangeException("startIndex"))
      end
      if count ~= 0 then
        throw(ArgumentOutOfRangeException("count"))
      end
    end
    if startIndex < 0 or startIndex >= len then
      throw(ArgumentOutOfRangeException("startIndex"))
    end
    if count < 0 or startIndex - count + 1 < 0 then
      throw(ArgumentOutOfRangeException("count"))
    end
    local comparer = EqualityComparer(t.__genericT__).getDefault()
    local equals = comparer.EqualsOf
    local endIndex = startIndex - count + 1
    for i = startIndex + 1, endIndex + 1, -1 do
      local item = t[i]
      if item == null then item = nil end
      if equals(comparer, item, value) then
        return i - 1
      end
    end
    return -1
  end,
  Resize = function (t, newSize, T)
    if newSize < 0 then throw(ArgumentOutOfRangeException("newSize")) end
    if t == nil then
      return buildArray(Array(T), newSize)
    end
    local len = #t
    if len > newSize then
      fill(t, newSize + 1, len, nil)
    elseif len < newSize then
      local default = t.__genericT__:default()
      if default == nil then default = null end
      fill(t, len + 1, newSize, default)
    end
    return t
  end,
  Reverse = function (t, index, count)
    if not index then
      index = 0
      count = #t
    else
      if count < 0 or index > #t - count then
        throw(ArgumentOutOfRangeException("index or count"))
      end
    end
    local i, j = index + 1, index + count
    while i <= j do
      t[i], t[j] = t[j], t[i]
      i = i + 1
      j = j - 1
    end
    versions[t] = (versions[t] or 0) + 1
  end,
  Sort = function (t, ...)
    if t == nil then throw(ArgumentNullException("array")) end
    local len = select("#", ...)
    if len == 0 then
      sort(t)
    elseif len == 1 then
      local comparer = ...
      sort(t, comparer)
    else
      local index, count, comparer = ...
      if count > 1 then
        local comp = getComp(t, comparer)
        if index == 0 and count == #t then
          tsort(t, comp)
        else
          checkIndexAndCount(t, index, count)
          local arr = {}
          tmove(t, index + 1, index + count, 1, arr)
          tsort(arr, comp)
          tmove(arr, 1, count, index + 1, t)
        end
        versions[t] = (versions[t] or 0) + 1
      end
    end
  end,
  toArray = function (t)
    local array = {}    
    if t.GetEnumerator == arrayEnumerator then
      tmove(t, 1, #t, 1, array)
    else
      local count = 1
      for _, v in each(t) do
        array[count] = v == nil and null or v
        count = count + 1
      end
    end
    return arrayFromTable(array, t.__genericT__)
  end,
  TrueForAll = function (t, match)
    if t == nil then throw(ArgumentNullException("array")) end
    if match == nil then throw(ArgumentNullException("match")) end
    for i = 1, #t do
      local item = t[i]
      if item == null then item = nil end
      if not match(item) then
        return false
      end
    end
    return true
  end,
  Clone = function (this)
    local t = setmetatable({}, getmetatable(this))
    tmove(this, 1, #this, 1, t)
    return t
  end,
  CopyTo = function (this, array, index)
    local n = #this
    checkIndexAndCount(array, index, n)
    local T = this.__genericT__
    if T.class == "S" then
      local default = T:default()
      if type(default) == "table" then
        for i = 1, n do
          array[i + index] = this[i]:__clone__()
        end
        return
      end
    end
    tmove(this, 1, n, index + 1, array)
  end,
  GetEnumerator = arrayEnumerator,
  GetLength = function (this, dimension)
    if dimension ~= 0 then throw(IndexOutOfRangeException()) end
    return #this
  end,
  GetLowerBound = function (this, dimension)
    if dimension ~= 0 then throw(IndexOutOfRangeException()) end
    return 0
  end,
  GetUpperBound = function (this, dimension)
    if dimension ~= 0 then throw(IndexOutOfRangeException()) end
    return #this - 1
  end,
  GetValue = function (this, index1, index2)
    if index1 == nil then throw(ArgumentNullException("indices")) end
    return get(this, checkArrayIndex(index1, index2))
  end,
  SetValue = function (this, value, index1, index2)
    if index1 == nil then throw(ArgumentNullException("indices")) end
    set(this, checkArrayIndex(index1, index2), System.castWithNullable(this.__genericT__, value))
  end,
  Clone = function (this)
    local array = {}
    tmove(this, 1, #this, 1, array)
    return arrayFromTable(array, this.__genericT__)
  end
}

function Array.__call(T, ...)
  return buildArray(T, select("#", ...), { ... })
end

function System.arrayFromList(t)
  return setmetatable(t, Array(t.__genericT__))
end

arrayFromTable = function (t, T, readOnly)
  assert(T)
  local array = setmetatable(t, Array(T))
  if readOnly then
    array.set = unset
  end
  return array
end

System.arrayFromTable = arrayFromTable

local function getIndex(t, ...)
  local rank = t.__rank__
  local id = 0
  local len = #rank
  for i = 1, len do
    id = id * rank[i] + select(i, ...)
  end
  return id, len
end

local function checkMultiArrayIndex(t, index1, ...)
  if index1 == nil then throw(ArgumentNullException("indices")) end
  local rank = t.__rank__
  local len = #rank
  if type(index1) == "table" then
    if #index1 ~= len then
      throw(ArgumentException("Indices length does not match the array rank."))
    end
    local id = 0
    for i = 1, len do
      id = id * rank[i] + index1[i]
    end
    return id
  elseif len ~= select("#", ...) + 1 then
    throw(ArgumentException("Indices length does not match the array rank."))
  end
  return getIndex(t, index1, ...)
end

local MultiArray = { 
  set = function (this, ...)
    local index, len = getIndex(this, ...)
    set(this, index, select(len + 1, ...))
  end,
  get = function (this, ...)
    local index = getIndex(this, ...)
    return get(this, index)
  end,
  getRank = function (this)
    return #this.__rank__
  end,
  GetLength = function (this, dimension)
    local rank = this.__rank__
    if dimension < 0 or dimension >= #rank then throw(IndexOutOfRangeException()) end
    return rank[dimension + 1]
  end,
  GetLowerBound = function (this, dimension)
    local rank = this.__rank__
    if dimension < 0 or dimension >= #rank then throw(IndexOutOfRangeException()) end
    return 0
  end,
  GetUpperBound = function (this, dimension)
    local rank = this.__rank__
    if dimension < 0 or dimension >= #rank then throw(IndexOutOfRangeException()) end
    return rank[dimension + 1] - 1
  end,
  GetValue = function (this, ...)
    return get(this, checkMultiArrayIndex(this, ...))
  end,
  SetValue = function (this, value, ...)
    set(this, checkMultiArrayIndex(this, ...), System.castWithNullable(this.__genericT__, value))
  end,
  Clone = function (this)
    local array = { __rank__ = this.__rank__ }
    tmove(this, 1, #this, 1, array)
    return arrayFromTable(array, this.__genericT__)
  end
}

function MultiArray.__call(T, rank, t)
  local len = 1
  for i = 1, #rank do
    len = len * rank[i]
  end
  t = buildArray(T, len, t)
  t.__rank__ = rank
  return t
end

System.defArray("System.Array", function(T) 
  return { 
    base = { System.ICloneable, System.IList_1(T), System.IReadOnlyList_1(T), System.IList }, 
    __genericT__ = T
  }
end, Array, MultiArray)

local cpool = {}
local function createCoroutine(f)
  local c = tremove(cpool)
  if c == nil then
    c = ccreate(function (...)
      f(...)
      while true do
        f = nil
        cpool[#cpool + 1] = c
        f = cyield(cpool)
        f(cyield())
      end
    end)
  else
    cresume(c, f)
  end
  return c
end

System.ccreate = createCoroutine
System.cpool = cpool
System.cresume = cresume
System.yield = cyield

local YieldEnumerable
YieldEnumerable = define("System.YieldEnumerable", function (T)
  return {
    base = { System.IEnumerable_1(T), System.IEnumerator_1(T), System.IDisposable },
    __genericT__ = T
  }
end, {
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  GetEnumerator = function (this)
    return setmetatable({ f = this.f, args = this.args }, YieldEnumerable(this.__genericT__))
  end,
  MoveNext = function (this)
    local c = this.c
    if c == false then
      return false
    end
  
    local ok, v
    if c == nil then
      c = createCoroutine(this.f)
      this.c = c
      local args = this.args
      ok, v = cresume(c, unpack(args, 1, args.n))
      this.args = nil
    else
      ok, v = cresume(c)
    end
  
    if ok then
      if v == cpool then
        this.c = false
        this.current = nil
        return false
      else
        this.current = v
        return true
      end
    else
      error(v)
    end
  end
})

local function yieldIEnumerable(f, T, ...)
  return setmetatable({ f = f, args = pack(...) }, YieldEnumerable(T))
end

System.yieldIEnumerable = yieldIEnumerable
System.yieldIEnumerator = yieldIEnumerable

local ReadOnlyCollection = {
  __ctor__ = function (this, list)
    if not list then throw(ArgumentNullException("list")) end
    this.list = list
  end,
  getCount = function (this)
    return #this.list
  end,
  get = function (this, index)
    return this.list:get(index)
  end,
  Contains = function (this, value)
    return this.list:Contains(value)
  end,
  GetEnumerator = function (this)
    return this.list:GetEnumerator()
  end,
  CopyTo = function (this, array, index)
    this.list:CopyTo(array, index)
  end,
  IndexOf = function (this, value)
    return this.list:IndexOf(value)
  end,
  getIsSynchronized = falseFn,
  getIsReadOnly = trueFn,
  getIsFixedSize = trueFn,
}

define("System.ReadOnlyCollection", function (T)
  return { 
    base = { System.IList_1(T), System.IList, System.IReadOnlyList_1(T) }, 
    __genericT__ = T
  }
end, ReadOnlyCollection)
end

-- CoreSystemLib: Type.lua
do
local System = System
local throw = System.throw
local Object = System.Object
local Boolean = System.Boolean
local Delegate = System.Delegate
local getClass = System.getClass
local arrayFromTable = System.arrayFromTable

local InvalidCastException = System.InvalidCastException
local ArgumentNullException = System.ArgumentNullException
local MissingMethodException = System.MissingMethodException
local TypeLoadException = System.TypeLoadException
local NullReferenceException = System.NullReferenceException

local Char = System.Char
local SByte = System.SByte
local Byte = System.Byte
local Int16 = System.Int16
local UInt16 = System.UInt16
local Int32 = System.Int32
local UInt32 = System.UInt32
local Int64 = System.Int64
local UInt64 = System.UInt64
local Single = System.Single
local Double = System.Double
local Int = System.Int
local Number = System.Number
local ValueType = System.ValueType

local assert = assert
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local select = select
local unpack = table.unpack
local floor = math.floor

local Type, typeof

local function isGenericName(name)
  return name:byte(#name) == 93
end

local function getBaseType(this)
  local baseType = this.baseType
  if baseType == nil then
    local baseCls = getmetatable(this[1])
    if baseCls ~= nil then
      baseType = typeof(baseCls)
      this.baseType = baseType
    end
  end
  return baseType
end

local function isSubclassOf(this, c)
  local p = this
  if p == c then
    return false
  end
  while p ~= nil do
    if p == c then
      return true
    end
    p = getmetatable(p)
  end
  return false
end

local function getIsInterface(this)
  return this[1].class == "I"
end

local function fillInterfaces(t, cls, set)
  local base = getmetatable(cls)
  if base then
    fillInterfaces(t, base, set)
  end
  local interface = cls.interface
  if interface then
    for i = 1, #interface do
      local it = interface[i]
      if not set[it] then
        t[#t + 1] = typeof(it)
        set[it] = true
      end
      fillInterfaces(t, it, set)
    end
  end
end

local function getInterfaces(this)
  local t = this.interfaces
  if t == nil then
    t = arrayFromTable({}, Type, true)
    fillInterfaces(t, this[1], {})
    this.interfaces = t
  end
  return t
end

local function implementInterface(this, ifaceType)
  local t = this
  while t ~= nil do
    local interfaces = getInterfaces(this)
    if interfaces ~= nil then
      for i = 1, #interfaces do
        local it = interfaces[i]
        if it == ifaceType or implementInterface(it, ifaceType) then
          return true
        end
      end
    end
    t = getBaseType(t)
  end
  return false
end

local function isAssignableFrom(this, c)
  if c == nil then 
    return false 
  end
  if this == c then 
    return true
  end
  local left, right = this[1], c[1]
  if left == Object then
    return true
  end

  if isSubclassOf(right, left) then
    return true
  end

  if left.class == "I" then
    return implementInterface(c, this)
  end

  return false
end

local function isGenericTypeDefinition(this)
  return not rawget(this[1], "__name__")
end

Type = System.define("System.Type", {
  Equals = System.equals,
  getIsGenericType = function (this)
    return isGenericName(this[1].__name__)
  end,
  getContainsGenericParameters = function (this)
    return isGenericName(this[1].__name__)
  end,
  getIsGenericTypeDefinition = isGenericTypeDefinition,
  GetGenericTypeDefinition = function (this)
    if isGenericTypeDefinition(this) then
      return this
    end
    local name = this[1].__name__
    local i = name:find('`')
    if i then
      local genericTypeName = name:sub(1, i - 1)
      return typeof(System.getClass(genericTypeName))
    end
    throw(System.InvalidOperationException())
  end,
  MakeGenericType = function (this, ...)
    local args = { ... }
    for i = 1, #args do
      args[i] = args[i][1]
    end
    return typeof(this[1](unpack(args)))
  end,
  getIsEnum = function (this)
    return this[1].class == "E"
  end,
  getIsClass = function (this)
    return this[1].class == "C"
  end,
  getIsValueType = function (this)
    return this[1].class == "S" 
  end,
  getName = function (this)
    local name = this.name
    if name == nil then
      local clsName = this[1].__name__
      local pattern = isGenericName(clsName) and "^.*()%.(.*)%[.+%]$" or "^.*()%.(.*)$"
      name = clsName:gsub(pattern, "%2")
      this.name = name
    end
    return name
  end,
  getFullName = function (this)
    return this[1].__name__
  end,
  getNamespace = function (this)
    local namespace = this.namespace
    if namespace == nil then
      local clsName = this[1].__name__
      local pattern = isGenericName(clsName) and "^(.*)()%..*%[.+%]$" or "^(.*)()%..*$"
      namespace = clsName:gsub(pattern, "%1")
      this.namespace = namespace
    end
    return namespace
  end,
  getBaseType = function (this)
    local cls = this[1]
    if cls.class ~= "I" and cls ~= Object then
      while true do
        local base = getmetatable(cls)
        if not base then
          break
        end
        if base.__index == base then
          return typeof(base)
        end
        cls = base
      end
    end
    return nil
  end,
  IsSubclassOf = function (this, c)
    return isSubclassOf(this[1], c[1])
  end,
  getIsInterface = getIsInterface,
  GetInterfaces = getInterfaces,
  IsAssignableFrom = isAssignableFrom,
  IsInstanceOfType = function (this, obj)
    if obj == nil then
      return false 
    end
    return isAssignableFrom(this, obj:GetType())
  end,
  ToString = function (this)
    return this[1].__name__
  end,
  GetTypeFrom = function (typeName, throwOnError, ignoreCase)
    if typeName == nil then
      throw(ArgumentNullException("typeName"))
    end
    if #typeName == 0 then
      if throwOnError then
        throw(TypeLoadException("Arg_TypeLoadNullStr"))
      end
      return nil
    end
    assert(not ignoreCase, "ignoreCase is not support")
    local cls = getClass(typeName)
    if cls ~= nil then
      return typeof(cls)
    end
    if throwOnError then
      throw(TypeLoadException(typeName .. ": failed to load."))
    end
    return nil
  end
})

local NumberType = {
  __index = Type,
  __eq = function (a, b)
    local c1, c2 = a[1], b[1]
    if c1 == c2 then
      return true
    end
    if c1 == Number or c2 == Number then
      return true
    end
    return false
  end
}

local function newNumberType(c)
  return setmetatable({ c }, NumberType)
end

local types = {
  [Char] = newNumberType(Char),
  [SByte] = newNumberType(SByte),
  [Byte] = newNumberType(Byte),
  [Int16] = newNumberType(Int16),
  [UInt16] = newNumberType(UInt16),
  [Int32] = newNumberType(Int32),
  [UInt32] = newNumberType(UInt32),
  [Int64] = newNumberType(Int64),
  [UInt64] = newNumberType(UInt64),
  [Single] = newNumberType(Single),
  [Double] = newNumberType(Double),
  [Int] = newNumberType(Int),
  [Number] = newNumberType(Number),
}

local customTypeof = System.config.customTypeof

function typeof(cls)
  assert(cls)
  local t = types[cls]
  if t == nil then
    if customTypeof then
      t = customTypeof(cls)
      if t then
        types[cls] = t
        return t
      end
    end
    t = setmetatable({ cls }, Type)
    types[cls] = t
  end
  return t
end

local function getType(obj)
  return typeof(getmetatable(obj))
end

System.typeof = typeof
System.Object.GetType = getType

local function addCheckInterface(set, cls)
  local interface = cls.interface
  if interface then
    for i = 1, #interface do
      local it = interface[i]
      set[it] = true
      addCheckInterface(set, it)
    end
  end
end

local function getCheckSet(cls)
  local set = {}
  local p = cls
  repeat
    set[p] = true
    addCheckInterface(set, p)
    p = getmetatable(p)
  until not p
  return set
end

local customTypeCheck = System.config.customTypeCheck

local checks = setmetatable({}, {
  __index = function (checks, cls)
    if customTypeCheck then
      local f, add = customTypeCheck(cls)
      if f then
        if add then
          checks[cls] = f
        end
        return f
      end
    end

    local set = getCheckSet(cls)
    local function check(obj, T)
      return set[T] == true
    end
    checks[cls] = check
    return check
  end
})

checks[Number] = function (obj, T)
  local set = getCheckSet(Number)
  local numbers = {
    [Char] = function (obj) return type(obj) == "number" and obj >= 0 and obj <= 65535 and floor(obj) == obj end,
    [SByte] = function (obj) return type(obj) == "number" and obj >= -128 and obj <= 127 and floor(obj) == obj end,
    [Byte] = function (obj) return type(obj) == "number" and obj >= 0 and obj <= 255 and floor(obj) == obj end,
    [Int16] = function (obj) return type(obj) == "number" and obj >= -32768 and obj <= 32767 and floor(obj) == obj end,
    [UInt16] = function (obj) return type(obj) == "number" and obj >= 0 and obj <= 32767 and floor(obj) == obj end,
    [Int32] = function (obj) return type(obj) == "number" and obj >= -2147483648 and obj <= 2147483647 and floor(obj) == obj end,
    [UInt32] = function (obj) return type(obj) == "number" and obj >= 0 and obj <= 4294967295 and floor(obj) == obj end,
    [Int64] = function (obj) return type(obj) == "number" and obj >= -9223372036854775808 and obj <= 9223372036854775807 and floor(obj) == obj end,
    [UInt64] = function (obj) return type(obj) == "number" and obj >= 0 and obj <= 18446744073709551615 and floor(obj) == obj end,
    [Single] = function (obj) return type(obj) == "number" and obj >= -3.40282347E+38 and obj <= 3.40282347E+38 end,
    [Double] = function (obj) return type(obj) == "number" end
  }
  local function check(obj, T)
    local number = numbers[T]
    if number then
      return number(obj)
    end
    return set[T] == true
  end
  checks[Number] = check
  return check(obj, T)
end

local is, getName

if System.debugsetmetatable then
  is = function (obj, T)
    return checks[getmetatable(obj)](obj, T)
  end

  getName = function (obj)
    return obj.__name__
  end

  System.getClassFromObj = getmetatable
else
  local function getClassFromObj(obj)
    local t = type(obj)
    if t == "number" then
      return Number
    elseif t == "boolean" then
      return Boolean
    elseif t == "function" then
      return Delegate
    end
    return getmetatable(obj)
  end

  function System.ObjectGetType(this)
    if this == nil then throw(NullReferenceException()) end
    return typeof(getClassFromObj(this))
  end

  is = function (obj, T)
    local base = getClassFromObj(obj)
    if base then
      return checks[base](obj, T)
    end
    return false
  end

  getName = function (obj)
    return getClassFromObj(obj).__name__
  end

  System.getClassFromObj = getClassFromObj
end

System.is = is

function System.as(obj, cls)
  if obj ~= nil and is(obj, cls) then
    return obj
  end
  return nil
end

local function cast(cls, obj, nullable)
  if obj ~= nil then
    if is(obj, cls) then
      return obj
    end
    throw(InvalidCastException(("Unable to cast object of type '%s' to type '%s'."):format(getName(obj), cls.__name__)), 1)
  else
    if cls.class ~= "S" or nullable then
      return nil
    end
    throw(NullReferenceException(), 1)
  end
end

System.cast = cast

function System.castWithNullable(cls, obj)
  if System.isNullable(cls) then
    return cast(cls.__genericT__, obj, true)
  end
  return cast(cls, obj)
end
end

-- CoreSystemLib: Collections/List.lua
do
local System = System
local falseFn = System.falseFn
local lengthFn = System.lengthFn
local Array = System.Array

local List = {
  __ctor__ = Array.ctorList,
  getCapacity = lengthFn,
  getCount = lengthFn,
  getIsFixedSize = falseFn,
  getIsReadOnly = falseFn,
  get = Array.get,
  set = Array.set,
  Add = Array.add,
  AddObj = Array.addObj,
  AddRange = Array.addRange,
  AsReadOnly = Array.AsReadOnly,
  BinarySearch = Array.BinarySearch,
  Clear = Array.clear,
  Contains = Array.Contains,
  CopyTo = Array.CopyTo,
  Exists = Array.Exists,
  Find = Array.Find,
  FindAll = Array.findAll,
  FindIndex = Array.FindIndex,
  FindLast = Array.FindLast,
  FindLastIndex = Array.FindLastIndex,
  ForEach = Array.ForEach,
  GetEnumerator = Array.GetEnumerator,
  GetRange = Array.getRange,
  IndexOf = Array.IndexOf,
  Insert = Array.insert,
  InsertRange = Array.insertRange,
  LastIndexOf = Array.LastIndexOf,
  Remove = Array.remove,
  RemoveAll = Array.removeAll,
  RemoveAt = Array.removeAt,
  RemoveRange = Array.removeRange,
  Reverse = Array.Reverse,
  Sort = Array.Sort,
  TrimExcess = System.emptyFn,
  ToArray = Array.toArray,
  TrueForAll = Array.TrueForAll
}

function System.listFromTable(t, T)
  return setmetatable(t, List(T))
end

local ListFn = System.define("System.Collections.Generic.List", function(T) 
  return { 
    base = { System.IList_1(T), System.IReadOnlyList_1(T), System.IList }, 
    __genericT__ = T,
  }
end, List)

System.List = ListFn
System.ArrayList = ListFn(System.Object)
end

-- CoreSystemLib: Collections/Dictionary.lua
do
local System = System
local define = System.define
local throw = System.throw
local null = System.null
local falseFn = System.falseFn
local each = System.each
local lengthFn = System.lengthFn
local versions = System.versions
local Array = System.Array
local checkIndexAndCount = System.checkIndexAndCount
local throwFailedVersion = System.throwFailedVersion
local ArgumentNullException = System.ArgumentNullException
local ArgumentException = System.ArgumentException
local KeyNotFoundException = System.KeyNotFoundException
local EqualityComparer = System.EqualityComparer
local NotSupportedException = System.NotSupportedException

local assert = assert
local pairs = pairs
local next = next
local select = select
local getmetatable = getmetatable
local setmetatable = setmetatable
local tconcat = table.concat
local tremove = table.remove
local type = type

local counts = setmetatable({}, { __mode = "k" })
System.counts = counts

local function getCount(this)
  local t = counts[this]
  if t then
    return t[1]
  end
  return 0
end

local function pairsFn(t, i)
  local count =  counts[t]
  if count then
    if count[2] ~= count[3] then
      throwFailedVersion()
    end
  end
  local k, v = next(t, i)
  if v == null then
    return k
  end
  return k, v
end

function System.pairs(t)
  local count = counts[t]
  if count then
    count[3] = count[2]
  end
  return pairsFn, t
end

local KeyValuePairFn
local KeyValuePair = {
  __ctor__ = function (this, ...)
    if select("#", ...) == 0 then
      this.Key, this.Value = this.__genericTKey__:default(), this.__genericTValue__:default()
    else
      this.Key, this.Value = ...
    end
  end,
  Create = function (key, value, TKey, TValue)
    return setmetatable({ Key = key, Value = value }, KeyValuePairFn(TKey, TValue))
  end,
  Deconstruct = function (this)
    return this.Key, this.Value
  end,
  ToString = function (this)
    local t = { "[" }
    local count = 2
    local k, v = this.Key, this.Value
    if k ~= nil then
      t[count] = k:ToString()
      count = count + 1
    end
    t[count] = ", "
    count = count + 1
    if v ~= nil then
      t[count] = v:ToString()
      count = count + 1
    end
    t[count] = "]"
    return tconcat(t)
  end
}

KeyValuePairFn = System.defStc("System.Collections.Generic.KeyValuePair", function(TKey, TValue)
  local cls = {
    __genericTKey__ = TKey,
    __genericTValue__ = TValue,
  }
  return cls
end, KeyValuePair)
System.KeyValuePair = KeyValuePairFn

local function isKeyValuePair(t)
  return getmetatable(getmetatable(t)) == KeyValuePair
end

local DictionaryEnumerator = define("System.Collections.Generic.DictionaryEnumerator", {
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  MoveNext = function (this)
    local t, kind = this.dict, this.kind
    local count = counts[t]
    if this.version ~= (count and count[2] or 0) then
      throwFailedVersion()
    end
    local k, v = next(t, this.index)
    if k ~= nil then
      if kind then
        kind.Key = k
        if v == null then v = nil end
        kind.Value = v
      elseif kind == false then
        if v == null then v = nil end
        this.current = v
      else
        this.current = k
      end
      this.index = k
      return true
    else
      if kind then
        kind.Key, kind.Value = kind.__genericTKey__:default(), kind.__genericTValue__:default()
      elseif kind == false then
        this.current = t.__genericTValue__:default()
      else
        this.current = t.__genericTKey__:default()
      end
      return false
    end
  end
})

local function dictionaryEnumerator(t, kind)
  local current
  if not kind then
    local TKey, TValue = t.__genericTKey__, t.__genericTValue__
    kind = setmetatable({ Key = TKey:default(), Value = TValue:default() }, t.__genericT__)
    current = kind
  elseif kind == 1 then
    local TKey = t.__genericTKey__
    current = TKey:default()
    kind = nil
  else
    local TValue = t.__genericTValue__
    current = TValue:default()
    kind = false
  end
  local count = counts[t]
  local en = {
    dict = t,
    version = count and count[2] or 0,
    kind = kind,
    current = current
  }
  return setmetatable(en, DictionaryEnumerator)
end

local DictionaryCollection = define("System.Collections.Generic.DictionaryCollection", function (T)
    return {
      base = { System.ICollection_1(T), System.IReadOnlyCollection_1(T), System.ICollection },
      __genericT__ = T
    }
  end, {
  __ctor__ = function (this, dict, kind)
    this.dict = dict
    this.kind = kind
  end,
  getCount = function (this)
    return getCount(this.dict)
  end,
  GetEnumerator = function (this)
    return dictionaryEnumerator(this.dict, this.kind)
  end
})

local function add(this, key, value)
  if key == nil then throw(ArgumentNullException("key")) end
  if this[key] ~= nil then throw(ArgumentException("key already exists")) end
  this[key] = value == nil and null or value
  local t = counts[this]
  if t then
    t[1] = t[1] + 1
    t[2] = t[2] + 1
  else
    counts[this] = { 1, 1 }
  end
end

local function remove(this, key)
  if key == nil then throw(ArgumentNullException("key")) end
  if this[key] ~= nil then
    this[key] = nil
    local t = counts[this]
    t[1] = t[1] - 1
    t[2] = t[2] + 1
    return true
  end
  return false
end

local function buildFromDictionary(this, dictionary)
  if dictionary == nil then throw(ArgumentNullException("dictionary")) end
  local count = 0
  for k, v in pairs(dictionary) do
    this[k] = v
    count = count + 1
  end
  counts[this] = { count, 0 }
end

local ArrayDictionaryFn
local function buildHasComparer(this, ...)
   local Dictionary = ArrayDictionaryFn(this.__genericTKey__, this.__genericTValue__)
   Dictionary.__ctor__(this, ...)
   return setmetatable(this, Dictionary)
end

local Dictionary = {
  getIsFixedSize = falseFn,
  getIsReadOnly = falseFn,
  __ctor__ = function (this, ...) 
    local n = select("#", ...)
    if n == 0 then
    elseif n == 1 then
      local comparer = ...
      if comparer == nil or type(comparer) == "number" then  
      else
        local equals = comparer.EqualsOf
        if equals == nil then
          buildFromDictionary(this, comparer)
        else
          buildHasComparer(this, ...)
        end
      end
    else
      local dictionary, comparer = ...
      if comparer ~= nil then 
        buildHasComparer(this, ...)
      end
      if type(dictionary) ~= "number" then 
        buildFromDictionary(this, dictionary)
      end
    end
  end,
  AddKeyValue = add,
  Add = function (this, ...)
    local k, v
    if select("#", ...) == 1 then
      local pair = ... 
      k, v = pair.Key, pair.Value
    else
      k, v = ...
    end
    add(this, k ,v)
  end,
  Clear = function (this)
    for k, v in pairs(this) do
      this[k] = nil
    end
    counts[this] = nil
  end,
  ContainsKey = function (this, key)
    if key == nil then throw(ArgumentNullException("key")) end
    return this[key] ~= nil 
  end,
  ContainsValue = function (this, value)
    if value == nil then
      for _, v in pairs(this) do
        if v == null then
          return true
        end
      end
    else
      local comparer = EqualityComparer(this.__genericTValue__).getDefault()
      local equals = comparer.EqualsOf
        for _, v in pairs(this) do
          if v ~= null then
            if equals(comparer, value, v ) then
              return true
            end
          end
      end
    end
    return false
  end,
  Contains = function (this, pair)
    local key = pair.Key
    if key == nil then throw(ArgumentNullException("key")) end
    local value = this[key]
    if value ~= nil then
      if value == null then value = nil end
      local comparer = EqualityComparer(this.__genericTValue__).getDefault()
      if comparer:EqualsOf(value, pair.Value) then
        return true
      end
    end
    return false
  end,
  CopyTo = function (this, array, index)
    local count = getCount(this)
    checkIndexAndCount(array, index, count)
    if count > 0 then
      local KeyValuePair = this.__genericT__
      index = index + 1
      for k, v in pairs(this) do
        if v == null then v = nil end
        array[index] = setmetatable({ Key = k, Value = v }, KeyValuePair)
        index = index + 1
      end
    end
  end,
  RemoveKey = remove,
  Remove = function (this, key)
    if isKeyValuePair(key) then
      local k, v = key.Key, key.Value
      if k == nil then throw(ArgumentNullException("key")) end
      local value = this[k]
      if value ~= nil then
        if value == null then value = nil end
        local comparer = EqualityComparer(this.__genericTValue__).getDefault()
        if comparer:EqualsOf(value, v) then
          remove(this, k)
          return true
        end
      end
      return false
    end
    return remove(this, key)
  end,
  TryGetValue = function (this, key)
    if key == nil then throw(ArgumentNullException("key")) end
    local value = this[key]
    if value == nil then
      return false, this.__genericTValue__:default()
    end
    if value == null then return true end
    return true, value
  end,
  getComparer = function (this)
    return EqualityComparer(this.__genericTKey__).getDefault()
  end,
  getCount = getCount,
  get = function (this, key)
    if key == nil then throw(ArgumentNullException("key")) end
    local value = this[key]
    if value == nil then throw(KeyNotFoundException()) end
    if value ~= null then
      return value
    end
    return nil
  end,
  set = function (this, key, value)
    if key == nil then throw(ArgumentNullException("key")) end
    local t = counts[this]
    if t then
      if this[key] == nil then
        t[1] = t[1] + 1
      end
      t[2] = t[2] + 1
    else
      counts[this] = { 1, 1 }
    end
    this[key] = value == nil and null or value
  end,
  GetEnumerator = dictionaryEnumerator,
  getKeys = function (this)
    return DictionaryCollection(this.__genericTKey__)(this, 1)
  end,
  getValues = function (this)
    return DictionaryCollection(this.__genericTValue__)(this, 2)
  end
}

local ArrayDictionaryEnumerator = define("System.Collections.Generic.ArrayDictionaryEnumerator", function (T)
  return {
    base = { System.IEnumerator_1(T) }
  }
end, {
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  MoveNext = function (this)
    local t = this.list
    if this.version ~= versions[t] then
      throwFailedVersion()
    end
    local index = this.index
    local pair = t[index]
    if pair ~= nil then
      if t.kind then
        this.current = pair.Value
      else
        this.current = pair.Key
      end
      this.index = index + 1
      return true
    end
    this.current = nil
    return false
  end
})

local arrayDictionaryEnumerator = function (t, kind, T)
  return setmetatable({ list = t, kind = kind, index = 1, version = versions[t], currnet = T:default() }, ArrayDictionaryEnumerator(T))
end

local ArrayDictionaryCollection = define("System.Collections.Generic.ArrayDictionaryCollection", function (T)
  return {
    base = { System.ICollection_1(T), System.IReadOnlyCollection_1(T), System.ICollection },
    __genericT__ = T
  }
  end, {
  __ctor__ = function (this, dict, kind)
    this.dict = dict
    this.kind = kind
  end,
  getCount = function (this)
    return getCount(this.dict)
  end,
  GetEnumerator = function (this)
    return arrayDictionaryEnumerator(this.dict, this.kind, this.__genericT__)
  end
})

local ArrayDictionary = (function ()
  local function buildFromDictionary(this, dictionary)
    if dictionary == nil then throw(ArgumentNullException("dictionary")) end
    local count = 1
    local KeyValuePair = this.__genericT__
    for _, pair in each(dictionary) do
      local k, v = pair.Key, pair.Value
      if type(k) == "table" and k.class == 'S' then
        k = k:__clone__()
      end
      this[count] = setmetatable({ Key = k, Value = v }, KeyValuePair)
      count = count + 1
    end
  end 
  
  local function add(this, key, value, set)
    if key == nil then throw(ArgumentNullException("key")) end
    local len = #this
    if len > 0 then
      local comparer = this.comparer
      local equals = comparer.EqualsOf
      for i = 1, len do
        if equals(comparer, this[i].Key, key) then
          if set then
            this[i].Value = value
            return
          else
            throw(ArgumentException("key already exists"))
          end
        end
      end
    end
    this[len + 1] = setmetatable({ Key = key, Value = value }, this.__genericT__)
    versions[this] = (versions[this] or 0) + 1
  end
  
  local function remove(this, key)
    if key == nil then throw(ArgumentNullException("key")) end
    local len = #this
    if len > 0 then
      local comparer = this.comparer
      local equals = comparer.EqualsOf
      for i = 1, len do
        if equals(comparer, this[i].Key, key) then
          tremove(this, i)
          versions[this] = (versions[this] or 0) + 1
          return true
        end
      end
    end
    return false
  end
 
  return {
    getIsFixedSize = falseFn,
    getIsReadOnly = falseFn,
    __ctor__ = function (this, ...)
      local Comparer
      local n = select("#", ...)
      if n == 0 then
      elseif n == 1 then
        local comparer = ...
        if comparer == nil or type(comparer) == "number" then  
        else
          local equals = comparer.EqualsOf
          if equals == nil then
            buildFromDictionary(this, comparer)
          else
            Comparer = comparer
          end
        end
      else
        local dictionary, comparer = ...
        if type(dictionary) ~= "number" then 
           buildFromDictionary(this, dictionary)
        end
        Comparer = comparer
      end
      this.comparer = Comparer or EqualityComparer(this.__genericTKey__).getDefault()
    end,
    AddKeyValue = add,
    Add = function (this, ...)
      local k, v
      if select("#", ...) == 1 then
        local pair = ... 
        k, v = pair.Key, pair.Value
      else
        k, v = ...
      end
      add(this, k ,v)
    end,
    Clear = Array.clear,
    ContainsKey = function (this, key)
      if key == nil then throw(ArgumentNullException("key")) end
      local len = #this
      if len > 0 then
        local comparer = this.comparer
        local equals = comparer.EqualsOf
        for i = 1, len do
          if equals(comparer, this[i].Key, key) then
            return true
          end
        end
      end
      return false
    end,
    ContainsValue = function (this, value)
      local len = #this
      if len > 0 then
        local comparer = EqualityComparer(this.__genericTValue__).getDefault()
        local equals = comparer.EqualsOf
        for i = 1, #this do
          if equals(comparer, value, this[i].Value) then
            return true
          end
        end
      end
      return false
    end,
    Contains = function (this, pair)
      local key = pair.Key
      if key == nil then throw(ArgumentNullException("key")) end
      local len = #this
      if len > 0 then
        local comparer = this.comparer
        local equals = comparer.EqualsOf
        for i = 1, len do
          local t = this[i]
          if equals(comparer, t.Key, key) then
            local comparer = EqualityComparer(this.__genericTValue__).getDefault()
            if comparer:EqualsOf(t.Value, pair.Value) then
              return true
            end 
          end
        end
      end
      return false
    end,
    CopyTo = function (this, array, index)
      local count = #this
      checkIndexAndCount(array, index, count)
      if count > 0 then
        local KeyValuePair = this.__genericT__
        index = index + 1
        for i = 1, count do
          local t = this[i]
          array[index] = setmetatable({ Key = t.Key:__clone__(), Value = t.Value }, KeyValuePair)
          index = index + 1
        end
      end
    end,
    RemoveKey = remove,
    Remove = function (this, key)
      if isKeyValuePair(key) then
        local len = #this
        local k, v = key.Key, key.Value
        for i = 1, #this do
          local pair = this[i]
          if pair.Key:EqualsObj(k) then
            local comparer = EqualityComparer(this.__genericTValue__).getDefault()
            if comparer:EqualsOf(pair.Value, v) then
              tremove(this, i)
              return true
            end
          end
        end
      end
      return false
    end,
    TryGetValue = function (this, key)
      if key == nil then throw(ArgumentNullException("key")) end
      local len = #this
      if len > 0 then
        local comparer = this.comparer
        local equals = comparer.EqualsOf
        for i = 1, len do
          local pair = this[i]
          if equals(comparer, pair.Key, key) then
            return true, pair.Value
          end
        end
      end
      return false, this.__genericTValue__:default()
    end,
    getComparer = function (this)
      return this.comparer
    end,
    getCount = lengthFn,
    get = function (this, key)
      if key == nil then throw(ArgumentNullException("key")) end
      local len = #this
      if len > 0 then
        local comparer = this.comparer
        local equals = comparer.EqualsOf
        for i = 1, len do
          local pair = this[i]
          if equals(comparer, pair.Key, key) then
            return pair.Value
          end
        end
      end
      throw(KeyNotFoundException())
    end,
    set = function (this, key, value)
      add(this, key, value, true)
    end,
    GetEnumerator = Array.GetEnumerator,
    getKeys = function (this)
      return ArrayDictionaryCollection(this.__genericTKey__)(this)
    end,
    getValues = function (this)
      return ArrayDictionaryCollection(this.__genericTValue__)(this, true)
    end
  }
end)()

ArrayDictionaryFn = define("System.Collections.Generic.ArrayDictionary", function(TKey, TValue) 
  return { 
    base = { System.IDictionary_2(TKey, TValue), System.IDictionary, System.IReadOnlyDictionary_2(TKey, TValue) },
    __genericT__ = KeyValuePairFn(TKey, TValue),
    __genericTKey__ = TKey,
    __genericTValue__ = TValue,
  }
end, ArrayDictionary)

function System.dictionaryFromTable(t, TKey, TValue)
  return setmetatable(t, Dictionary(TKey, TValue))
end

function System.isDictLike(t)
  return type(t) == "table" and t.GetEnumerator == dictionaryEnumerator
end

local DictionaryFn = define("System.Collections.Generic.Dictionary", function(TKey, TValue)
  local array, len
  if TKey.class == 'S' and type(TKey:default()) == "table" then
    array = ArrayDictionary
  else
    len = getCount
  end
  return { 
    base = { System.IDictionary_2(TKey, TValue), System.IDictionary, System.IReadOnlyDictionary_2(TKey, TValue) },
    __genericT__ = KeyValuePairFn(TKey, TValue),
    __genericTKey__ = TKey,
    __genericTValue__ = TValue,
    __len = len
  }, array
end, Dictionary)

System.Dictionary = DictionaryFn

local Object = System.Object
System.Hashtable = DictionaryFn(Object, Object)
end

-- CoreSystemLib: Collections/Queue.lua
do
local System = System
local Array = System.Array

local function tryDequeue(this)
  if #this == 0 then
    return false
  end
  return true, this:Dequeue()
end

local Queue = {
  __ctor__ = Array.ctorList,
  getCount = Array.getLength,
  Clear = Array.clear,
  Contains = Array.Contains,
  CopyTo = Array.CopyTo,
  Dequeue = Array.popFirst,
  Enqueue = Array.add,
  GetEnumerator = Array.GetEnumerator,
  Peek = Array.first,
  ToArray = Array.toArray,
  TrimExcess = System.emptyFn,
  TryDequeue = tryDequeue
}

function System.queueFromTable(t, T)
  return setmetatable(t, Queue(T))
end

local QueueFn = System.define("System.Collections.Generic.Queue", function(T) 
  return {
    base = { System.IEnumerable_1(T), System.ICollection },
    __genericT__ = T,
  }
end, Queue)

System.Queue = QueueFn
System.queue = QueueFn(System.Object)
end

-- CoreSystemLib: Collections/Stack.lua
do
local System = System
local Array = System.Array

local Stack = {
  __ctor__ = Array.ctorList,
  getCount = Array.getLength,
  Clear = Array.clear,
  Contains = Array.Contains,
  GetEnumerator = Array.reverseEnumerator,
  Push = Array.add,
  Peek = Array.last,
  Pop = Array.popLast,
  ToArray = Array.toArray,
  TrimExcess = System.emptyFn
}

function System.stackFromTable(t, T)
  return setmetatable(t, Stack(T))
end

local StackFn = System.define("System.Collections.Generic.Stack", function(T) 
  return {
    base = { System.IEnumerable_1(T), System.ICollection },
    __genericT__ = T,
  }
end, Stack)

System.Stack = StackFn
System.stack = StackFn(System.Object)
end

-- CoreSystemLib: Collections/HashSet.lua
do
local System = System
local throw = System.throw
local each = System.each
local Dictionary = System.Dictionary
local wrap = System.wrap
local unWrap = System.unWrap
local getEnumerator = Dictionary.GetEnumerator 
local ArgumentNullException = System.ArgumentNullException

local assert = assert
local pairs = pairs
local select = select

local counts = System.counts

local function build(this, collection, comparer)
  if comparer ~= nil then
    assert(false)
  end
  if collection == nil then
    throw(ArgumentNullException("collection"))
  end
  this:UnionWith(collection)
end

local function checkUniqueAndUnfoundElements(this, other, returnIfUnfound)
  if #this == 0 then
    local numElementsInOther = 0
    for _, item in each(other) do
      numElementsInOther = numElementsInOther + 1
      break
    end
    return 0, numElementsInOther
  end
  local set, uniqueCount, unfoundCount = {}, 0, 0
  for _, item in each(other) do
    item = wrap(item)
      if this[item] ~= nil then
        if set[item] == nil then
          set[item] = true
          uniqueCount = uniqueCount + 1
        end
      else
      unfoundCount = unfoundCount + 1
      if returnIfUnfound then
        break
      end
    end
  end
  return uniqueCount, unfoundCount
end

local HashSet = {
  __ctor__ = function (this, ...)
    local len = select("#", ...)
    if len == 0 then
    elseif len == 1 then
      local collection = ...
      if collection == nil then return end
      if collection.getEnumerator ~= nil then
        build(this, collection, nil)
      else
        assert(true)
      end
    else 
      build(this, ...)
    end
  end,
  Clear = Dictionary.Clear,
  getCount = Dictionary.getCount,
  getIsReadOnly = System.falseFn,
  Contains = function (this, item)
    item = wrap(item)
    return this[item] ~= nil
  end,
  Remove = function (this, item)
    item = wrap(item)
    if this[item] then
      this[item] = nil
      local t = counts[this]
      t[1] = t[1] - 1
      t[2] = t[2] + 1
      return true
    end
    return false
  end,
  GetEnumerator = function (this)
    return getEnumerator(this, 1)
  end,
  Add = function (this, v)
    v = wrap(v)
    if this[v] == nil then
      this[v] = true
      local t = counts[this]
      if t then
        t[1] = t[1] + 1
        t[2] = t[2] + 1
      else
        counts[this] = { 1, 1 }
      end
      return true
    end
    return false
  end,
  UnionWith = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    local count = 0
    for _, v in each(collection) do
      v = wrap(v)
      if this[v] == nil then
        this[v] = true
        count = count + 1
      end
    end
    if count > 0 then
      local t = counts[this]
      if t then
        t[1] = t[1] + count
        t[2] = t[2] + 1
      else
        counts[this] = { count, 1 }  
      end
    end
  end,
  IntersectWith = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    local set = {}
    for _, v in each(other) do
      v = wrap(v)
      if this[v] ~= nil then
        set[v] = true
      end
    end
    local count = 0
    for v, _ in pairs(this) do
      if set[v] == nil then
        this[v] = nil
        count = count + 1
      end
    end
    if count > 0 then
      local t = counts[this]
      t[1] = t[1] - count
      t[2] = t[2] + 1
    end
  end,
  ExceptWith = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    if other == this then
      this:Clear()
      return
    end
    local count = 0
    for _, v in each(other) do
      v = wrap(v)
      if this[v] ~= nil then
        this[v] = nil
        count = count + 1
      end
    end
    if count > 0 then
      local t = counts[this]
      t[1] = t[1] - count
      t[2] = t[2] + 1
    end
  end,
  SymmetricExceptWith = function (this, other)
    if other == nil then throw(ArgumentNullException("other")) end
    if other == this then
      this:Clear()
      return
    end
    local set = {}
    local count = 0
    local changed = false
    for _, v in each(other) do
      v = wrap(v)
      if this[v] == nil then
        this[v] = true
        count = count + 1
        changed = true
        set[v] = true
      elseif set[v] == nil then 
        this[v] = nil
        count = count - 1
        changed = true
      end
    end
    if changed then
      local t = counts[this]
      if t then
        t[1] = t[1] + count
        t[2] = t[2] + 1
      else
        counts[this] = { count, 1 }
      end
    end
  end,
  IsSubsetOf = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    local count = #this
    if count == 0 then
      return true
    end
    local uniqueCount, unfoundCount = checkUniqueAndUnfoundElements(this, other, false)
    return uniqueCount == count and unfoundCount >= 0
  end,
  IsProperSubsetOf = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    local uniqueCount, unfoundCount = checkUniqueAndUnfoundElements(this, other, false)
    return uniqueCount == #this and unfoundCount > 0
  end,
  IsSupersetOf = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    for _, element in each(other) do
      element = wrap(element)
      if this[element] == nil then
        return false
      end
    end
    return true
  end,
  IsProperSupersetOf = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    local count = #this
    if count == 0 then
      return false
    end
    local uniqueCount, unfoundCount = checkUniqueAndUnfoundElements(this, other, true)
    return uniqueCount < count and unfoundCount == 0
  end,
  Overlaps = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    if #this == 0 then
      return false
    end
    for _, element in each(other) do
      element = wrap(element)
      if this[element] ~= nil then
        return true
      end
    end
    return false
  end,
  SetEquals = function (this, other)
    if other == nil then
      throw(ArgumentNullException("other"))
    end
    local uniqueCount, unfoundCount = checkUniqueAndUnfoundElements(this, other, true)
    return uniqueCount == #this and unfoundCount == 0
  end,
  RemoveWhere = function (this, match)
    if match == nil then
      throw(ArgumentNullException("match"))
    end
    local numRemoved = 0
    for v, _ in pairs(this) do
      if match(unWrap(v)) then
        this[v] = nil
        numRemoved = numRemoved + 1
      end
    end
    if numRemoved > 0 then
      local t = counts[this]
      t[1] = t[1] - numRemoved
      t[2] = t[2] + 1
    end
    return numRemoved
  end,
  TrimExcess = System.emptyFn
}

function System.hashSetFromTable(t, T)
  return setmetatable(t, HashSet(T))
end

System.HashSet = System.define("System.Collections.Generic.HashSet", function(T) 
  return { 
    base = { System.ICollection_1(T), System.ISet_1(T) }, 
    __genericT__ = T,
    __genericTKey__ = T,
    __len = HashSet.getCount
  }
end, HashSet)
end

-- CoreSystemLib: Collections/LinkedList.lua
do
local System = System
local define = System.define
local throw = System.throw
local each = System.each
local checkIndexAndCount = System.checkIndexAndCount
local ArgumentNullException = System.ArgumentNullException
local InvalidOperationException = System.InvalidOperationException
local EqualityComparer = System.EqualityComparer

local setmetatable = setmetatable
local select = select

local LinkedListNode = define("System.Collections.Generic.LinkedListNode", {
  __ctor__ = function (this, value)
    this.Value = value
  end,
  getNext = function (this)
    local next = this.next
    if next == nil or next == this.List.head then
      return nil
    end
    return next
  end,
  getPrevious = function (this)
    local prev = this.prev
    if prev == nil or this == this.List.head then
      return nil
    end
    return prev
  end
})
System.LinkedListNode = LinkedListNode

local function newLinkedListNode(list, value)
  return setmetatable({ List = assert(list), Value = value }, LinkedListNode)
end

local function vaildateNewNode(this, node)
  if node == nil then
    throw(ArgumentNullException("node"))
  end
  if node.List ~= nil then
    throw(InvalidOperationException("ExternalLinkedListNode"))
  end
end

local function vaildateNode(this, node)
  if node == nil then
    throw(ArgumentNullException("node"))
  end
  if node.List ~= this then
    throw(InvalidOperationException("ExternalLinkedListNode"))
  end
end

local function insertNodeBefore(this, node, newNode)
  newNode.next = node
  newNode.prev = node.prev
  node.prev.next = newNode
  node.prev = newNode
  this.Count = this.Count + 1
  this.version = this.version + 1
end

local function insertNodeToEmptyList(this, newNode)
  newNode.next = newNode
  newNode.prev = newNode
  this.head = newNode
  this.Count = this.Count + 1
  this.version = this.version + 1
end

local function invalidate(this)
  this.List = nil
  this.next = nil
  this.prev = nil
end

local function remvoeNode(this, node)
  if node.next == node then
    this.head = nil
  else
    node.next.prev = node.prev
    node.prev.next = node.next
    if this.head == node then
      this.head = node.next
    end
  end
  invalidate(node)
  this.Count = this.Count - 1
  this.version = this.version + 1
end

local LinkedListEnumerator = { 
  __index = false,
  getCurrent = System.getCurrent, 
  Dispose = System.emptyFn,
  MoveNext = function (this)
    local list = this.list
    local node = this.node
    if this.version ~= list.version then
      System.throwFailedVersion()
    end
    if node == nil then
      return false
    end
    this.current = node.Value
    node = node.next
    if node == list.head then
      node = nil
    end
    this.node = node
    return true
  end
}
LinkedListEnumerator.__index = LinkedListEnumerator

local LinkedList = { 
  Count = 0, 
  version = 0,
  __ctor__ = function (this, ...)
    local len = select("#", ...)
    if len == 1 then
      local collection = ...
      if collection == nil then
        throw(ArgumentNullException("collection"))
      end
      for _, item in each(collection) do
        this:AddLast(item)
      end
    end
  end,
  getCount = function (this)
    return this.Count
  end,
  getFirst = function(this)    
    return this.head
  end,
  getLast = function (this)
    local head = this.head
    return head ~= nil and head.prev or nil
  end,
  AddAfterNode = function (this, node, newNode)
    vaildateNode(this, node)
    vaildateNewNode(this, newNode)
    insertNodeBefore(this, node.next, newNode)
    newNode.List = this
  end,
  AddAfter = function (this, node, value)    
    vaildateNode(this, node)
    local result = newLinkedListNode(node.List, value)
    insertNodeBefore(this, node.next, result)
    return result
  end,
  AddBeforeNode = function (this, node, newNode)
    vaildateNode(this, node)
    vaildateNewNode(this, newNode)
    insertNodeBefore(this, node, newNode)
    newNode.List = this
    if node == this.head then
      this.head = newNode
    end
  end,
  AddBefore = function (this, node, value)
    vaildateNode(this, node)
    local result = newLinkedListNode(node.List, value)
    insertNodeBefore(this, node, result)
    if node == this.head then
      this.head = result
    end
    return result
  end,
  AddFirstNode = function (this, node)
	  vaildateNewNode(this, node)
    if this.head == nil then
      insertNodeToEmptyList(this, node)
    else
      insertNodeBefore(this, this.head, node)
      this.head = node
    end
    node.List = this
  end,
  AddFirst = function (this, value)
    local result = newLinkedListNode(this, value)
    if this.head == nil then
      insertNodeToEmptyList(this, result)
    else
      insertNodeBefore(this, this.head, result)
      this.head = result
    end
    return result
  end,
  AddLastNode = function (this, node)
    vaildateNewNode(this, node)
    if this.head == nil then
      insertNodeToEmptyList(this, node)
    else
      insertNodeBefore(this, this.head, node)
    end
    node.List = this
  end,
  AddLast = function (this, value)
    local result = newLinkedListNode(this, value)
    if this.head == nil then
      insertNodeToEmptyList(this, result)
    else
      insertNodeBefore(this, this.head, result)
    end
    return result
  end,
  Clear = function (this)
    local current = this.head
    while current ~= nil do
      local temp = current
      current = current.next
      invalidate(temp)
    end
    this.head = nil
    this.Count = 0
    this.version = this.version + 1
  end,
  Contains = function (this, value)
    return this:Find(value) ~= nil
  end,
  CopyTo = function (this, array, index)
    checkIndexAndCount(array, index, this.Count)
    local head = this.head
    local node = head
    if node then
      index = index + 1
      repeat
        local value = node.Value
        if value == nil then value = System.null end
        array[index] = value
        index = index + 1
        node = node.next
      until node == head
    end
  end,
  Find = function (this, value)     
    local head = this.head
    local node = head
    local comparer = EqualityComparer(this.__genericT__).getDefault()
    local equals = comparer.EqualsOf
    if node ~= nil then
      if value ~= nil then
        repeat
          if equals(comparer, node.Value, value) then
            return node
          end
          node = node.next
        until node == head
      else
        repeat 
          if node.Value == nil then
            return node
          end
          node = node.next
        until node == head
      end
    end
    return nil
  end,
  FindLast = function (this, value)
    local head = this.head
    if head == nil then return nil end
    local last = head.prev
    local node = last
    local comparer = EqualityComparer(this.__genericT__).getDefault()
    local equals = comparer.EqualsOf
    if node ~= nil then
      if value ~= nil then
        repeat
          if equals(comparer, node.Value, value) then
            return node
          end
          node = node.prev
        until node == last
      else
        repeat 
          if node.Value == nil then
            return node
          end
          node = node.prev
         until node == last
      end
    end
    return nil
  end,
  RemoveNode = function (this, node)
    vaildateNode(this, node)
    remvoeNode(this, node)
  end,
  Remove = function (this, node)
    node = this:Find(node)
    if node ~= nil then
      remvoeNode(this, node)
    end
    return false
  end,
  RemoveFirst = function (this)
    local head = this.head
    if head == nil then
      throw(InvalidOperationException("LinkedListEmpty"))
    end
    remvoeNode(this, head)
  end,
  RemoveLast = function (this)
    local head = this.head
    if head == nil then
      throw(InvalidOperationException("LinkedListEmpty"))
    end
    remvoeNode(this, head.prev)
  end,
  GetEnumerator = function (this)
    return setmetatable({ list = this, version = this.version, node = this.head }, LinkedListEnumerator)
  end
}

function System.linkedListFromTable(t, T)
  return setmetatable(t, LinkedList(T))
end

System.LinkedList = define("System.Collections.Generic.LinkedList", function(T) 
  return { 
  base = { System.ICollection_1(T), System.ICollection }, 
  __genericT__ = T,
  __len = LinkedList.getCount
  }
end, LinkedList)
end

-- CoreSystemLib: Collections/Linq.lua
do
local System = System
local define = System.define
local throw = System.throw
local each = System.each
local identityFn = System.identityFn
local wrap = System.wrap
local unWrap = System.unWrap
local is = System.is
local cast = System.cast
local Int32 = System.Int32
local isArrayLike = System.isArrayLike
local isDictLike = System.isDictLike
local Array = System.Array
local arrayEnumerator = Array.GetEnumerator

local NullReferenceException = System.NullReferenceException
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local InvalidOperationException = System.InvalidOperationException
local EqualityComparer = System.EqualityComparer
local Comparer_1 = System.Comparer_1
local Empty = System.Array.Empty

local IEnumerable_1 = System.IEnumerable_1
local IEnumerable = System.IEnumerable
local IEnumerator_1 = System.IEnumerator_1
local IEnumerator = System.IEnumerator

local assert = assert
local getmetatable = getmetatable
local setmetatable = setmetatable
local select = select
local pairs = pairs
local tsort = table.sort

local InternalEnumerable = define("System.Linq.InternalEnumerable", function(T) 
  return {
    base = { IEnumerable_1(T) }
  }
end)

local function createEnumerable(T, GetEnumerator)
  assert(T)
  return setmetatable({ __genericT__ = T, GetEnumerator = GetEnumerator }, InternalEnumerable(T))
end

local InternalEnumerator = define("System.Linq.InternalEnumerator", function(T) 
  return {
    base = { IEnumerator_1(T) }
  }
end)

local function createEnumerator(T, source, tryGetNext, init)
  assert(T)
  local state = 1
  local current
  local en
  return setmetatable({
    MoveNext = function()
      if state == 1 then
        state = 2
        if source then
          en = source:GetEnumerator() 
        end
        if init then
          init(en) 
        end
      end
      if state == 2 then
        local ok, v = tryGetNext(en)
        if ok then
          current = v
          return true
        elseif en then
          local dispose = en.Dispose
          if dispose then
            dispose(en)
          end    
        end
       end
       return false
    end,
    getCurrent = function()
      return current
    end
  }, InternalEnumerator(T))
end

local Enumerable = {}
define("System.Linq.Enumerable", Enumerable)

function Enumerable.Where(source, predicate)
  if source == nil then throw(ArgumentNullException("source")) end
  if predicate == nil then throw(ArgumentNullException("predicate")) end
  local T = source.__genericT__
  return createEnumerable(T, function() 
    local index = -1
    return createEnumerator(T, source, function(en)
      while en:MoveNext() do
        local current = en:getCurrent()
        index = index + 1
        if predicate(current, index) then
          return true, current
        end
      end 
      return false
    end)
  end)
end

function Enumerable.Select(source, selector, T)
  if source == nil then throw(ArgumentNullException("source")) end
  if selector == nil then throw(ArgumentNullException("selector")) end
  return createEnumerable(T, function()
    local index = -1
    return createEnumerator(T, source, function(en) 
      if en:MoveNext() then
        index = index + 1
        return true, selector(en:getCurrent(), index)
      end
      return false
    end)
  end)
end

local function selectMany(source, collectionSelector, resultSelector, T)
  if source == nil then throw(ArgumentNullException("source")) end
  if collectionSelector == nil then throw(ArgumentNullException("collectionSelector")) end
  if resultSelector == nil then throw(ArgumentNullException("resultSelector")) end
  return createEnumerable(T, function() 
    local element, midEn
    local index = -1
    return createEnumerator(T, source, function(en) 
      while true do
        if midEn and midEn:MoveNext() then
          return true, resultSelector(element, midEn:getCurrent())
        else
          if not en:MoveNext() then return false end
          index = index + 1
          local current = en:getCurrent()
          midEn = collectionSelector(current, index):GetEnumerator()
          if midEn == nil then
            throw(NullReferenceException())
          end
          element = current
        end  
      end
    end)
  end)
end

local function identityFnOfSelectMany(s, x)
  return x
end

function Enumerable.SelectMany(source, ...)
  local len = select("#", ...)
  if len == 2 then
    local collectionSelector, T = ...
    return selectMany(source, collectionSelector, identityFnOfSelectMany, T)
  else
    return selectMany(source, ...)
  end
end

function Enumerable.Take(source, count)
  if source == nil then throw(ArgumentNullException("source")) end
  local T = source.__genericT__
  return createEnumerable(T, function()
    return createEnumerator(T, source, function(en)
      if count > 0 then
        if en:MoveNext() then
          count = count - 1
          return true, en:getCurrent()
        end
      end
      return false
    end)
  end)
end

function Enumerable.TakeWhile(source, predicate)
  if source == nil then throw(ArgumentNullException("source")) end
  if predicate == nil then throw(ArgumentNullException("predicate")) end
  local T = source.__genericT__
  return createEnumerable(T, function()
    local index = -1
    return createEnumerator(T, source, function(en)
      if en:MoveNext() then
        local current = en:getCurrent()
        index = index + 1
        if not predicate(current, index) then
          return false
        end
        return true, current
      end
      return false
    end)
  end)
end

function Enumerable.Skip(source, count)
  if source == nil then throw(ArgumentNullException("source")) end
  local T = source.__genericT__
  return createEnumerable(T, function()
    return createEnumerator(T, source, function(en)
      while count > 0 and en:MoveNext() do count = count - 1 end
      if count <= 0 then
        if en:MoveNext() then
          return true, en:getCurrent() 
        end
      end
      return false
    end)
  end)
end

function Enumerable.SkipWhile(source, predicate)
  if source == nil then throw(ArgumentNullException("source")) end
  if predicate == nil then throw(ArgumentNullException("predicate")) end
  local T = source.__genericT__
  return createEnumerable(T, function()
    local index = -1
    local isSkipEnd = false
    return createEnumerator(T, source, function(en)
      while not isSkipEnd do
        if en:MoveNext() then
          local current = en:getCurrent()
          index = index + 1
          if not predicate(current, index) then
            isSkipEnd = true
            return true, current
          end     
        else 
          return false
        end
      end
      if en:MoveNext() then
        return true, en:getCurrent()
      end
      return false
    end)
  end)
end

local IGrouping = System.defInf("System.Linq.IGrouping_2", function (TKey, TElement)
  return {
    base = { IEnumerable_1(TElement) } 
  }
end)

local Grouping = define("System.Linq.Grouping", function (TKey, TElement)
  return {
    __genericT__ = TElement,
    base = { IGrouping(TKey, TElement) },
    GetEnumerator = arrayEnumerator,
    getKey = function (this)
      return this.key
    end,
    getCount = function (this)
      return #this
    end
  }
end)

local function getGrouping(this, key)
  local hashCode = this.comparer:GetHashCodeOf(key)
  local groupIndex = this.indexs[hashCode]
  return this.groups[groupIndex]
end

local Lookup = {
  __ctor__ = function (this, comparer)
    this.comparer = comparer or EqualityComparer(this.__genericTKey__).getDefault()
    this.groups = {}
    this.indexs = {}
  end,
  get = function (this, key)
    local grouping = getGrouping(this, key)
    if grouping ~= nil then return grouping end 
    return Empty(this.__genericTElement__)
  end,
  GetCount = function (this)
    return #this.groups
  end,
  Contains = function (this, key)
    return getGrouping(this, key) ~= nil
  end,
  GetEnumerator = function (this)
    return arrayEnumerator(this.groups, IGrouping)
  end
}

local LookupFn = define("System.Linq.Lookup", function(TKey, TElement)
  local cls = {
    __genericTKey__ = TKey,
    __genericTElement__ = TElement,
  }
  return cls
end, Lookup)

local function addToLookup(this, key, value)
  local hashCode = this.comparer:GetHashCodeOf(key)
  local groupIndex = this.indexs[hashCode]
  local group
  if groupIndex == nil then
	  groupIndex = #this.groups + 1
	  this.indexs[hashCode] = groupIndex
	  group = setmetatable({ key = key }, Grouping(this.__genericTKey__, this.__genericTElement__))
	  this.groups[groupIndex] = group
  else
	  group = this.groups[groupIndex]
	  assert(group)
  end
  group[#group + 1] = wrap(value)
end

local function createLookup(source, keySelector, elementSelector, comparer, TKey, TElement)
  local lookup = LookupFn(TKey, TElement)(comparer)
  for _, item in each(source) do
    addToLookup(lookup, keySelector(item), elementSelector(item))
  end
  return lookup
end

local function createLookupForJoin(source, keySelector, comparer, TKey, TElement)
  local lookup = LookupFn(TKey, TElement)(comparer)
  for _, item in each(source) do
    local key = keySelector(item)
    if key ~= nil then
      addToLookup(lookup, key, item)
    end
  end
  return lookup
end

function Enumerable.Join(outer, inner, outerKeySelector, innerKeySelector, resultSelector, comparer, TKey, TResult)
  if outer == nil then throw(ArgumentNullException("outer")) end
  if inner == nil then throw(ArgumentNullException("inner")) end
  if outerKeySelector == nil then throw(ArgumentNullException("outerKeySelector")) end
  if innerKeySelector == nil then throw(ArgumentNullException("innerKeySelector")) end
  if resultSelector == nil then throw(ArgumentNullException("resultSelector")) end
  local lookup = createLookupForJoin(inner, innerKeySelector, comparer, TKey, inner.__genericT__)
  return createEnumerable(TResult, function ()
    local item, grouping, index
    return createEnumerator(TResult, outer, function (en)
      while true do
        if grouping ~= nil then
          index = index + 1
          if index < #grouping then
            return true, resultSelector(item, unWrap(grouping[index + 1]))
          end
        end
        if not en:MoveNext() then return false end
        local current = en:getCurrent()
        item = current
        grouping = getGrouping(lookup, outerKeySelector(current))
        index = -1
      end
    end)
  end)
end

function Enumerable.GroupJoin(outer, inner, outerKeySelector, innerKeySelector, resultSelector, comparer, TKey, TResult)
  if outer == nil then throw(ArgumentNullException("outer")) end
  if inner == nil then throw(ArgumentNullException("inner")) end
  if outerKeySelector == nil then throw(ArgumentNullException("outerKeySelector")) end
  if innerKeySelector == nil then throw(ArgumentNullException("innerKeySelector")) end
  if resultSelector == nil then throw(ArgumentNullException("resultSelector")) end
  local lookup = createLookupForJoin(inner, innerKeySelector, comparer, TKey, inner.__genericT__)
  return createEnumerable(TResult, function ()
    return createEnumerator(TResult, outer, function (en)
      if en:MoveNext() then
        local item = en:getCurrent()
        return true, resultSelector(item, lookup:get(outerKeySelector(item)))
      end
      return false
    end)
  end)
end

local function ordered(source, compare)
  local T = source.__genericT__
  local orderedEnumerable = createEnumerable(T, function()
    local t = {}
    local index = 0
    return createEnumerator(T, source, function() 
      index = index + 1
      local v = t[index]
      if v ~= nil then
        return true, unWrap(v)
      end
      return false
    end, 
    function() 
      local count = 1
      if isDictLike(source) then
        for k, v in pairs(source) do
          t[count] = setmetatable({ Key = k, Value = v }, T)
          count = count + 1
        end
      else
        for _, v in each(source) do
          t[count] = wrap(v)
          count = count + 1
        end
      end
      if count > 1 then
        tsort(t, function(x, y)
          return compare(unWrap(x), unWrap(y)) < 0 
        end)
      end
    end)
  end)
  orderedEnumerable.source = source
  orderedEnumerable.compare = compare
  return orderedEnumerable
end

local function orderBy(source, keySelector, comparer, TKey, descending)
  if source == nil then throw(ArgumentNullException("source")) end
  if keySelector == nil then throw(ArgumentNullException("keySelector")) end
  if comparer == nil then comparer = Comparer_1(TKey).getDefault() end 
  local keys = {}
  local function getKey(t) 
    local k = keys[t]
    if k == nil then
      k = keySelector(t)
      keys[t] = k
    end
    return k
  end
  local c = comparer.Compare
  local compare
  if descending then
    compare = function(x, y)
      return -c(comparer, getKey(x), getKey(y))
    end
  else
    compare = function(x, y)
      return c(comparer, getKey(x), getKey(y))
    end
  end
  return ordered(source, compare)
end

function Enumerable.OrderBy(source, keySelector, comparer, TKey)
  return orderBy(source, keySelector, comparer, TKey, false)
end

function Enumerable.OrderByDescending(source, keySelector, comparer, TKey)
  return orderBy(source, keySelector, comparer, TKey, true)
end

local function thenBy(source, keySelector, comparer, TKey, descending)
  if source == nil then throw(ArgumentNullException("source")) end
  if keySelector == nil then throw(ArgumentNullException("keySelector")) end
  if comparer == nil then comparer = Comparer_1(TKey).getDefault() end
  local keys = {}
  local function getKey(t) 
    local k = keys[t]
    if k == nil then
      k = keySelector(t)
      keys[t] = k
    end
    return k
  end
  local c = comparer.Compare
  local compare
  local parentSource, parentCompare = source.source, source.compare
  if descending then
    compare = function(x, y)
      local v = parentCompare(x, y)
      if v ~= 0 then
        return v
      else
        return -c(comparer, getKey(x), getKey(y))
      end
    end
  else
    compare = function(x, y)
      local v = parentCompare(x, y)
      if v ~= 0 then
        return v
      else
        return c(comparer, getKey(x), getKey(y))
      end
    end
  end
  return ordered(parentSource, compare)
end

function Enumerable.ThenBy(source, keySelector, comparer, TKey)
  return thenBy(source, keySelector, comparer, TKey, false)
end

function Enumerable.ThenByDescending(source, keySelector, comparer, TKey)
  return thenBy(source, keySelector, comparer, TKey, true)
end

local function groupBy(source, keySelector, elementSelector, comparer, TKey, TElement)
  if source == nil then throw(ArgumentNullException("source")) end
  if keySelector == nil then throw(ArgumentNullException("keySelector")) end
  if elementSelector == nil then throw(ArgumentNullException("elementSelector")) end
  return createEnumerable(IGrouping, function()
    return createLookup(source, keySelector, elementSelector, comparer, TKey, TElement):GetEnumerator()
  end)
end

function Enumerable.GroupBy(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 2 then
    local keySelector, TKey = ...
    return groupBy(source, keySelector, identityFn, nil, TKey, source.__genericT__)
  elseif len == 3 then
    local keySelector, comparer, TKey = ...
    return groupBy(source, keySelector, identityFn, comparer, TKey, source.__genericT__)
  elseif len == 4 then
    local keySelector, elementSelector, TKey, TElement = ...
    return groupBy(source, keySelector, elementSelector, nil, TKey, TElement)
  else
    return groupBy(source, ...)
  end
end

local function groupBySelect(source, keySelector, elementSelector, resultSelector, comparer, TKey, TElement, TResult)
  if source == nil then throw(ArgumentNullException("source")) end
  if keySelector == nil then throw(ArgumentNullException("keySelector")) end
  if elementSelector == nil then throw(ArgumentNullException("elementSelector")) end
  if resultSelector == nil then throw(ArgumentNullException("resultSelector")) end
  return createEnumerable(TResult, function()
    local lookup = createLookup(source, keySelector, elementSelector, comparer, TKey, TElement)
    return createEnumerator(TResult, lookup, function(en)
      if en:MoveNext() then
        local current = en:getCurrent()
        return resultSelector(current.key, current)
      end
      return false
    end)
  end)
end

function Enumerable.GroupBySelect(source, ...)
  local len = select("#", ...)
  if len == 4 then
    local keySelector, resultSelector, TKey, TResult = ...
    return groupBySelect(source, keySelector, identityFn, resultSelector, nil, TKey, source.__genericT__, TResult)
  elseif len == 5 then
    local keySelector, resultSelector, comparer, TKey, TResult = ...
    return groupBySelect(source, keySelector, identityFn, resultSelector, comparer, TKey, source.__genericT__, TResult)
  elseif len == 6 then
    local keySelector, elementSelector, resultSelector, TKey, TElement, TResult = ...
    return groupBySelect(source, keySelector, elementSelector, resultSelector, nil, TKey, TElement, TResult)
  else
    return groupBySelect(source, ...)
  end
end

function Enumerable.Concat(first, second)
  if first == nil then throw(ArgumentNullException("first")) end
  if second == nil then throw(ArgumentNullException("second")) end
  local T = first.__genericT__
  return createEnumerable(T, function()
    local secondEn
    return createEnumerator(T, first, function(en)
      if secondEn == nil then
        if en:MoveNext() then
          return true, en:getCurrent()
        end
        secondEn = second:GetEnumerator()
      end
      if secondEn:MoveNext() then
        return true, secondEn:getCurrent()
      end
      return false
    end)
  end)
end

function Enumerable.Zip(first, second, resultSelector, TResult) 
  if first == nil then throw(ArgumentNullException("first")) end
  if second == nil then throw(ArgumentNullException("second")) end
  if resultSelector == nil then throw(ArgumentNullException("resultSelector")) end
  return createEnumerable(TResult, function()
    local e2
    return createEnumerator(TResult, first, function(e1)
      if e1:MoveNext() and e2:MoveNext() then
          return true, resultSelector(e1:getCurrent(), e2:getCurrent())
      end
    end, 
    function()
      e2 = second:GetEnumerator()
    end)
  end)
end

local function addToSet(set, v, getHashCode, comparer)
  local hashCode = getHashCode(comparer, v)
  if set[hashCode] == nil then
    set[hashCode] = true
    return true
  end
  return false
end

local function removeFromSet(set, v, getHashCode, comparer)
  local hashCode = getHashCode(comparer, v)
  if set[hashCode] ~= nil then
    set[hashCode] = nil
    return true
  end
  return false
end

local function getComparer(source, comparer)
  return comparer or EqualityComparer(source.__genericT__).getDefault()
end

function Enumerable.Distinct(source, comparer)
  if source == nil then throw(ArgumentNullException("source")) end
  local T = source.__genericT__
  return createEnumerable(T, function()
    local set = {}
    comparer = getComparer(source, comparer)
    local getHashCode = comparer.GetHashCodeOf
    return createEnumerator(T, source, function(en)
      while en:MoveNext() do
        local current = en:getCurrent()
        if addToSet(set, current, getHashCode, comparer) then
          return true, current  
        end
      end
      return false
    end)
  end)
end

function Enumerable.Union(first, second, comparer)
  if first == nil then throw(ArgumentNullException("first")) end
  if second == nil then throw(ArgumentNullException("second")) end
  local T = first.__genericT__
  return createEnumerable(T, function()
    local set = {}
    comparer = getComparer(first, comparer)
    local getHashCode = comparer.GetHashCodeOf
    local secondEn
    return createEnumerator(T, first, function(en)
      if secondEn == nil then
        while en:MoveNext() do
          local current = en:getCurrent()
          if addToSet(set, current, getHashCode, comparer) then
            return true, current  
          end
        end
        secondEn = second:GetEnumerator()
      end
      while secondEn:MoveNext() do
        local current = secondEn:getCurrent()
        if addToSet(set, current, getHashCode, comparer) then
          return true, current  
        end
      end
      return false
    end)
  end)
end

function Enumerable.Intersect(first, second, comparer)
  if first == nil then throw(ArgumentNullException("first")) end
  if second == nil then throw(ArgumentNullException("second")) end
  local T = first.__genericT__
  return createEnumerable(T, function()
    local set = {}
    comparer = getComparer(first, comparer)
    local getHashCode = comparer.GetHashCodeOf
    return createEnumerator(T, first, function(en)
      while en:MoveNext() do
        local current = en:getCurrent()
        if removeFromSet(set, current, getHashCode, comparer) then
          return true, current
        end
      end
      return false
    end,
    function()
      for _, v in each(second) do
        addToSet(set, v, getHashCode, comparer)
      end
    end)
  end) 
end

function Enumerable.Except(first, second, comparer)
  if first == nil then throw(ArgumentNullException("first")) end
  if second == nil then throw(ArgumentNullException("second")) end
  local T = first.__genericT__
  return createEnumerable(T, function()
    local set = {}
    comparer = getComparer(first, comparer)
    local getHashCode = comparer.GetHashCodeOf
    return createEnumerator(T, first, function(en) 
      while en:MoveNext() do
        local current = en:getCurrent()
        if addToSet(set, current, getHashCode, comparer) then
          return true, current  
        end
      end
      return false
    end,
    function()
      for _, v in each(second) do
        addToSet(set, v, getHashCode, comparer)
      end
    end)
  end)
end

function Enumerable.Reverse(source)
  if source == nil then throw(ArgumentNullException("source")) end
  local T = source.__genericT__
  return createEnumerable(T, function()
    local t = {}    
    local index
    return createEnumerator(T, nil, function() 
      if index > 1 then
        index = index - 1
        return true, t[index]
      end
      return false
    end,
    function()
      local count = 1
      for _, v in each(source) do
        t[count] = v
        count = count + 1
      end  
      index = count
    end)
  end)
end

function Enumerable.SequenceEqual(first, second, comparer)
  if first == nil then throw(ArgumentNullException("first")) end
  if second == nil then throw(ArgumentNullException("second")) end
  comparer = getComparer(first, comparer)
  local equals = comparer.EqualsOf
  local e1 = first:GetEnumerator()
  local e2 = second:GetEnumerator()
  while e1:MoveNext() do
    if not(e2:MoveNext() and equals(comparer, e1:getCurrent(), e2:getCurrent())) then
      return false
    end
  end
  if e2:MoveNext() then
    return false
  end
  return true
end

Enumerable.ToArray = Array.toArray

function Enumerable.ToList(source)
  return System.List(source.__genericT__)(source)
end

local function toDictionary(source, keySelector, elementSelector, comparer, TKey, TValue)
  if source == nil then throw(ArgumentNullException("source")) end
  if keySelector == nil then throw(ArgumentNullException("keySelector")) end
  if elementSelector == nil then throw(ArgumentNullException("elementSelector")) end
  local dict = System.Dictionary(TKey, TValue)(comparer)
  for _, v in each(source) do
    dict:Add(keySelector(v), elementSelector(v))
  end
  return dict
end

function Enumerable.ToDictionary(source, ...)
  local len = select("#", ...)
  if len == 2 then
    local keySelector, TKey = ...
    return toDictionary(source, keySelector, identityFn, nil, TKey, source.__genericT__)
  elseif len == 3 then
    local keySelector, comparer, TKey = ...
    return toDictionary(source, keySelector, identityFn, comparer, TKey, source.__genericT__)
  elseif len == 4 then
    local keySelector, elementSelector, TKey, TElement = ...
    return toDictionary(source, keySelector, elementSelector, nil, TKey, TElement)
  else
    return toDictionary(source, ...)
  end
end

local function toLookup(source, keySelector, elementSelector, comparer, TKey, TElement )
  if source == nil then throw(ArgumentNullException("source")) end
  if keySelector == nil then throw(ArgumentNullException("keySelector")) end
  if elementSelector == nil then throw(ArgumentNullException("elementSelector")) end
  return createLookup(source, keySelector, elementSelector, comparer, TKey, TElement)
end

function Enumerable.ToLookup(source, ...)
  local len = select("#", ...)
  if len == 2 then
    local keySelector, TKey = ...
    return toLookup(source, keySelector, identityFn, nil, TKey, source.__genericT__)
  elseif len == 3 then
    local keySelector, comparer, TKey = ...
    return toLookup(source, keySelector, identityFn, comparer, TKey, source.__genericT__)
  elseif len == 4 then
    local keySelector, elementSelector, TKey, TElement = ...
    return toLookup(source, keySelector, elementSelector, nil, TKey, TElement)
  else
    return toLookup(source, ...)
  end
end

function Enumerable.DefaultIfEmpty(source)
  if source == nil then throw(ArgumentNullException("source")) end
  local T = source.__genericT__
  local state 
  return createEnumerable(T, function()
    return createEnumerator(T, source, function(en)
      if not state then
        if en:MoveNext() then
          state = 1
          return true, en:getCurrent()
        end
        state = 2
        return true, T:default()
      elseif state == 1 then
        if en:MoveNext() then
          return true, en:getCurrent()
        end
      end
      return false
    end)
  end)
end

function Enumerable.OfType(source, T)
  if source == nil then throw(ArgumentNullException("source")) end
  return createEnumerable(T, function()
    return createEnumerator(T, source, function(en) 
      while en:MoveNext() do
        local current = en:getCurrent()
        if is(current, T) then
          return true, current
        end
      end
      return false
    end)
  end)
end

function Enumerable.Cast(source, T)
  if source == nil then throw(ArgumentNullException("source")) end
  if is(source, IEnumerable_1(T)) then return source end
  return createEnumerable(T, function()
    return createEnumerator(T, source, function(en) 
      if en:MoveNext() then
        return true, cast(T, en:getCurrent())
      end
      return false
    end)
  end)
end

local function first(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 0 then
    if isArrayLike(source) then
      local count = #source
      if count > 0 then
        return true, unWrap(source[1])
      end
    else
      local en = source:GetEnumerator()
      if en:MoveNext() then 
        return true, en:getCurrent()
      end
    end
    return false, 0
  else
    local predicate = ...
    if predicate == nil then throw(ArgumentNullException("predicate")) end
    for _, v in each(source) do
      if predicate(v) then 
        return true, v
      end
    end
    return false, 1
  end
end

function Enumerable.First(source, ...)
  local ok, result = first(source, ...)
  if ok then return result end
  if result == 0 then
    throw(InvalidOperationException("NoElements"))
  end
  throw(InvalidOperationException("NoMatch"))
end

function Enumerable.FirstOrDefault(source, ...)
  local ok, result = first(source, ...)
  return ok and result or source.__genericT__:default()
end

local function last(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 0 then
    if isArrayLike(source) then
      local count = #source
      if count > 0 then
        return true, unWrap(source[count])
      end
    else
      local en = source:GetEnumerator()
      if en:MoveNext() then 
        local result
        repeat
          result = en:getCurrent()
        until not en:MoveNext()
        return true, result
      end
    end
    return false, 0
  else
    local predicate = ...
    if predicate == nil then throw(ArgumentNullException("predicate")) end
    local result, found
    for _, v in each(source) do
      if predicate(v) then
        result = v
        found = true
      end
    end    
    if found then return true, result end
    return false, 1
  end
end

function Enumerable.Last(source, ...)
  local ok, result = last(source, ...)
  if ok then return result end
  if result == 0 then
    throw(InvalidOperationException("NoElements"))
  end
  throw(InvalidOperationException("NoMatch"))
end

function Enumerable.LastOrDefault(source, ...)
  local ok, result = last(source, ...)
  return ok and result or source.__genericT__:default()
end

local function single(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 0 then
    if isArrayLike(source) then
      local count = #source
      if count == 0 then
        return false, 0
      elseif count == 1 then
        return true, unWrap(source[1])
      end
    else
      local en = source:GetEnumerator()
      if not en:MoveNext() then return false, 0 end
      local result = en:getCurrent()
      if not en:MoveNext() then
        return true, result
      end
    end
    return false, 1
  else
    local predicate = ...
    if predicate == nil then throw(ArgumentNullException("predicate")) end
    local result, found
    for _, v in each(source) do
      if predicate(v) then
        result = v
        if found then
          return false, 1
        end
        found = true
      end
    end
    if foun then return true, result end    
    return false, 0    
  end
end

function Enumerable.Single(source, ...)
  local ok, result = single(source, ...)
  if ok then return result end
  if result == 0 then
    throw(InvalidOperationException("NoElements"))
  end
  throw(InvalidOperationException("MoreThanOneMatch"))
end

function Enumerable.SingleOrDefault(source, ...)
  local ok, result = single(source, ...)
  return ok and result or source.__genericT__:default()
end

local function elementAt(source, index)
  if source == nil then throw(ArgumentNullException("source")) end
  if index >= 0 then
    if isArrayLike(source) then
      local count = #source
      if index < count then
        return true, unWrap(source[index + 1])
      end
    else
      local en = source:GetEnumerator()
      while true do
        if not en:MoveNext() then break end
        if index == 0 then return true, en:getCurrent() end
        index = index - 1
      end
    end
  end
  return false
end

function Enumerable.ElementAt(source, index)
  local ok, result = elementAt(source, index)
  if ok then return result end
  throw(ArgumentOutOfRangeException("index"))
end

function Enumerable.ElementAtOrDefault(source, index)
  local ok, result = elementAt(source, index)
  return ok and result or source.__genericT__:default()
end

function Enumerable.Range(start, count)
  if count < 0 then throw(ArgumentOutOfRangeException("count")) end
  return createEnumerable(Int32, function()
    local index = -1
    return createEnumerator(Int32, nil, function()
      index = index + 1
      if index < count then
        return true, start + index  
      end
      return false
    end)
  end)
end

function Enumerable.Repeat(element, count, T)
  if count < 0 then throw(ArgumentOutOfRangeException("count")) end
  return createEnumerable(T, function()
    local index = -1
    return createEnumerator(T, nil, function()
      index = index + 1
      if index < count then
        return true, element  
      end
      return false
    end)
  end)
end

function Enumerable.Any(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 0 then
    local en = source:GetEnumerator()
    return en:MoveNext()
  else
    local predicate = ...
    if predicate == nil then throw(ArgumentNullException("predicate")) end
    for _, v in each(source) do
      if predicate(v) then
        return true
      end
    end
    return false
  end
end

function Enumerable.All(source, predicate)
  if source == nil then throw(ArgumentNullException("source")) end
  if predicate == nil then throw(ArgumentNullException("predicate")) end
  for _, v in each(source) do
    if not predicate(v) then
      return false
    end
  end
  return true
end

function Enumerable.Count(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 0 then
    if isArrayLike(source) then
      return #source
    end
    local count = 0
    local en = source:GetEnumerator()
    while en:MoveNext() do 
      count = count + 1 
    end
    return count
  else
    local predicate = ...
    if predicate == nil then throw(ArgumentNullException("predicate")) end
    local count = 0
    for _, v in each(source) do
      if predicate(v) then
        count = count + 1
      end
    end
    return count
  end
end

function Enumerable.Contains(source, value, comparer)
  if source == nil then throw(ArgumentNullException("source")) end
  comparer = getComparer(source, comparer)
  local equals = comparer.EqualsOf
  for _, v in each(source) do
    if equals(comparer, v, value) then
      return true
    end
  end
  return false
end

function Enumerable.Aggregate(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...);
  if len == 1 then
    local func = ...
    if func == nil then throw(ArgumentNullException("func")) end
    local e = source:GetEnumerator()
    if not e:MoveNext() then throw(InvalidOperationException("NoElements")) end
    local result = e:getCurrent()
    while e:MoveNext() do
      result = func(result, e:getCurrent())
    end
    return result
  elseif len == 2 then
    local seed, func = ...
    if func == nil then throw(ArgumentNullException("func")) end
    local result = seed
    for _, element in each(source) do
      result = func(result, element)
    end
    return result
  else 
    local seed, func, resultSelector = ...
    if func == nil then throw(ArgumentNullException("func")) end
    if resultSelector == nil then throw(ArgumentNullException("resultSelector")) end
    local result = seed
    for _, element in each(source) do
      result = func(result, element)
    end
    return resultSelector(result)
  end
end

function Enumerable.Sum(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  if len == 0 then
    local sum = 0
    for _, v in each(source) do
      sum = sum + v
    end
    return sum
  else
    local selector = ...
    if selector == nil then throw(ArgumentNullException("selector")) end
    local sum = 0
    for _, v in each(source) do
      sum = sum + selector(v)
    end
    return sum
  end
end

local function minOrMax(compareFn, source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local len = select("#", ...)
  local selector, T 
  if len == 0 then
    selector, T = identityFn, source.__genericT__
  else
    selector, T = ...
    if selector == nil then throw(ArgumentNullException("selector")) end
  end
  local comparer = Comparer_1(T).getDefault()
  local compare = comparer.Compare
  local value = T:default()
  if value == nil then
    for _, x in each(source) do
      x = selector(x)
      if x ~= nil and (value == nil or compareFn(compare, comparer, x, value)) then
        value = x
      end 
    end
    return value
  else
    local hasValue = false
    for _, x in each(source) do
      x = selector(x)
      if hasValue then
        if compareFn(compare, comparer, x, value) then
          value = x
        end
      else
        value = x
        hasValue = true
      end
    end
    if hasValue then return value end
    throw(InvalidOperationException("NoElements"))
  end
end

local function minFn(compare, comparer, x, y)
  return compare(comparer, x, y) < 0
end

function Enumerable.Min(source, ...)
  return minOrMax(minFn, source, ...)
end

local function maxFn(compare, comparer, x, y)
  return compare(comparer, x, y) > 0
end

function Enumerable.Max(source, ...)
  return minOrMax(maxFn, source, ...)
end

function Enumerable.Average(source, ...)
  if source == nil then throw(ArgumentNullException("source")) end
  local sum, count = 0, 0
  local len = select("#", ...)
  if len == 0 then
    for _, v in each(source) do
      sum = sum + v
      count = count + 1
    end
  else
    local selector = ...
    if selector == nil then throw(ArgumentNullException("selector")) end
    for _, v in each(source) do
      sum = sum + selector(v)
      count = count + 1
    end
  end
  if count > 0 then
    return sum / count
  end
  throw(InvalidOperationException("NoElements"))
end
end

-- CoreSystemLib: Convert.lua
do
local System = System
local throw = System.throw
local cast = System.cast
local as = System.as
local trunc = System.trunc
local define = System.define
local identityFn = System.identityFn
local IConvertible = System.IConvertible
local systemToString = System.toString

local OverflowException = System.OverflowException
local FormatException = System.FormatException
local ArgumentException = System.ArgumentException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local ArgumentNullException = System.ArgumentNullException
local InvalidCastException = System.InvalidCastException

local SByte = System.SByte
local Byte = System.Byte
local Int16 = System.Int16
local UInt16 = System.UInt16
local Int32 = System.Int32
local UInt32 = System.UInt32
local Int64 = System.Int64
local UInt64 = System.UInt64
local Single = System.Single
local Double = System.Double
local Boolean = System.Boolean
local Char = System.Char
local DateTime = System.DateTime
local String = System.String
local Object = System.Object

local ParseSByte = SByte.Parse
local ParseByte = Byte.Parse
local ParseInt16 = Int16.Parse
local ParseUInt16 = UInt16.Parse
local ParseInt32 = Int32.Parse
local ParseUInt32 = UInt32.Parse
local ParseInt64 = Int64.Parse
local ParseUInt64 = UInt64.Parse

local ParseSingle = Single.Parse
local ParseDouble = Double.Parse
local ParseBoolean = Boolean.Parse

local type = type
local string = string
local sbyte = string.byte
local math = math
local floor = math.floor
local tconcat = table.concat
local getmetatable = getmetatable
local tonumber = tonumber

local function toBoolean(value)
  if value == nil then return false end
  local typename = type(value)
  if typename == "number" then
    return value ~= 0
  elseif typename == "string" then
    return ParseBoolean(value)  
  elseif typename == "boolean" then
    return value
  else
    return cast(IConvertible, value):ToBoolean()   
  end
end

local function toChar(value)
  if value == nil then return 0 end
  local typename = type(value)
  if typename == "number" then
    if value ~= floor(value) or value > 9223372036854775807 or value < -9223372036854775808 then
      throw(InvalidCastException("InvalidCast_FromTo_Char"))
    end
    if value < 0 or value > 65535 then 
      throw(OverflowException("Overflow_Char")) 
    end
    return value
  elseif typename == "string" then
    if #value ~= 1 then
      throw(FormatException("Format_NeedSingleChar"))
    end
    return sbyte(value)
  else
    return cast(IConvertible, value):ToChar()
  end
end

local function parseBits(s, p, n)
  local i, j, v = s:find(p)
  if not i then
    throw(FormatException())
  end
  v = tonumber(v)
  for i = j + 1, #s do
    local ch = sbyte(s, i)
    local b = ch - 48
    if b < 0 or b >= n then
      if not s:find("^%s*$", i) then
        throw(FormatException())
      end
      break
    end
    v = v * n + b
  end
  return v
end

local function parseNumberFromBase(value, fromBase, min, max)
  if fromBase == 2 then
    value = parseBits(value, "^%s*([01])", fromBase)
  elseif fromBase == 8 then
    value = parseBits(value, "^%s*([0-7])", fromBase)
  elseif fromBase == 16 then
    local _, _, v = value:find("^%s*(%w+)%s*$")
    if not v then
      throw(ArgumentException("String cannot contain a minus sign if the base is not 10."))
    end
    local ch = sbyte(v, 2)
    if ch == 120 or ch == 88 then
    else
      v = "0x" .. v
    end
    value = tonumber(v)
    if value == nil then
      throw(FormatException())
    end
  else
    throw(ArgumentException("fromBase")) 
  end
  if max == 127 and value <= 255 then
    return System.toSByte(value)
  end
  if max == 32767 and value <= 65535 then
    return System.toInt16(value)
  end
  if max == 2147483647 and value <= 4294967295 then
    return System.toInt32(value)
  end
  if value < min or value > max then
    throw(OverflowException())
  end
  return value
end

local function toNumber(value, min, max, parse, objectTo, sign)
  if value == nil then return 0 end
  local typename = type(value)
  if typename == "number" then
    if sign == false then
      value = System.ToSingle(value * 1.0)
    elseif sign == true then
      value = value * 1.0
    else
      local i = value
      value = trunc(value)
      if value ~= i then
        local dif = i - value
        if value >= 0 then
          if dif > 0.5 or (dif == 0.5 and value % 2 ~= 0) then
            value = value + 1  
          end
        else
          if dif < -0.5 or (dif == -0.5 and value % 2 ~= 0) then
            value = value - 1  
          end
        end
      end
      if value < min or value > max then
        throw(OverflowException())
      end
    end
    return value
  elseif typename == "string" then
    if sign and sign ~= 10 and type(sign) == "number" then
      return parseNumberFromBase(value, sign, min, max)
    end
    return parse(value) 
  elseif typename == "boolean" then
    return value and 1 or 0
  else
    return objectTo(value)
  end
end

local function objectToSByte(value)
  return cast(IConvertible, value):ToSByte()
end

local function toSByte(value, fromBase)
  return toNumber(value, -128, 127, ParseSByte, objectToSByte, fromBase)
end

local function objectToByte(value)
  return cast(IConvertible, value):ToByte()
end

local function toByte(value, fromBase)
  return toNumber(value, 0, 255, ParseByte, objectToByte, fromBase) 
end

local function objectToInt16(value)
  return cast(IConvertible, value):ToInt16()
end

local function toInt16(value, fromBase)
  return toNumber(value, -32768, 32767, ParseInt16, objectToInt16, fromBase) 
end

local function objectToUInt16(value)
  return cast(IConvertible, value):ToUInt16()
end

local function toUInt16(value, fromBase)
  return toNumber(value, 0, 65535, ParseUInt16, objectToUInt16, fromBase) 
end

local function objectToInt32(value)
  return cast(IConvertible, value):ToInt32()
end

local function toInt32(value, fromBase)
  return toNumber(value, -2147483648, 2147483647, ParseInt32, objectToInt32, fromBase) 
end

local function objectToUInt32(value)
  return cast(IConvertible, value):ToUInt32()
end

local function toUInt32(value, fromBase)
  return toNumber(value, 0, 4294967295, ParseUInt32, objectToUInt32, fromBase) 
end

local function objectToInt64(value)
  return cast(IConvertible, value):ToInt64()
end

local function toInt64(value, fromBase)
  return toNumber(value, -9223372036854775808, 9223372036854775807, ParseInt64, objectToInt64, fromBase) 
end

local function objectToUInt64(value)
  return cast(IConvertible, value):ToUInt64()
end

local function toUInt64(value, fromBase)
  return toNumber(value, 0, 18446744073709551615.0, ParseUInt64, objectToUInt64, fromBase) 
end

local function objectToSingle(value)
  return cast(IConvertible, value):ToSingle()
end

local function toSingle(value)
  return toNumber(value, nil, nil, ParseSingle, objectToSingle, false) 
end

local function objectToDouble(value)
  return cast(IConvertible, value):ToDouble()
end

local function toDouble(value)
  return toNumber(value, nil, nil, ParseDouble, objectToDouble, true) 
end

local function toDateTime(value)
  if value == nil then return DateTime.MinValue end
  if getmetatable(value) == DateTime then return value end
  if type(value) == "string" then return DateTime.Parse(value) end
  return cast(IConvertible, value):ToDateTime()
end

local function toBaseType(ic, targetType)
  local cls = targetType[1]
  if cls == Boolean then return ic:ToBoolean() end
  if cls == Char then return ic:ToChar() end
  if cls == SByte then return ic:ToSByte() end
  if cls == Byte then return ic:ToByte() end
  if cls == Int16 then return ic:ToInt16() end
  if cls == UInt16 then return ic:ToUInt16() end
  if cls == Int32 then return ic:ToInt32() end
  if cls == UInt32 then return ic:ToUInt32() end
  if cls == Int64 then return ic:ToInt64() end
  if cls == UInt64 then return ic:ToUInt64() end
  if cls == Single then return ic:ToSingle() end
  if cls == Double then return ic:ToDouble() end
  if cls == DateTime then return ic:ToDateTime() end
  if cls == String then return ic:ToString() end
  if cls == Object then return value end
end

local function defaultToType(value, targetType)
  if targetType == nil then throw(ArgumentNullException("targetType")) end
  if value:GetType() == targetType then return value end
  local v = toBaseType(value, targetType)
  if v ~= nil then
    return v
  end
  throw(InvalidCastException())
end

local function changeType(value, conversionType)
  if conversionType == nil then
    throw(ArgumentNullException("conversionType"))
  end
  if value == nil then
    if conversionType:getIsValueType() then
      throw(InvalidCastException("InvalidCast_CannotCastNullToValueType"))
    end
    return nil
  end
  local ic = as(value, IConvertible)
  if ic == nil then
    if value:GetType() == conversionType then
      return value
    end
    throw(InvalidCastException("InvalidCast_IConvertible"))
  end
  local v = toBaseType(ic, conversionType)
  if v ~= nil then
    return v
  end
  return ic.ToType(conversionType)
end

local function toBits(num, bits)
  -- returns a table of bits, most significant first.
  bits = bits or math.max(1, select(2, math.frexp(num)))
  local t = {} -- will contain the bits        
  for b = bits, 1, -1 do
    local i =  num % 2
    t[b] = i
    num = System.div(num - i, 2)
  end
  if bits == 64 and t[1] == 0 then
    return tconcat(t, nil, 2, bits)
  end
  return tconcat(t)
end

local function toString(value, toBaseOrProvider, cast)
  if value == nil then
    return ""
  end
  if toBaseOrProvider then
    if type(toBaseOrProvider) == "number" then
      if toBaseOrProvider ~= 10 then
        if cast and value < 0 then
          value = cast(value)
        end
      end
      if toBaseOrProvider == 2 then
        return toBits(value)
      elseif toBaseOrProvider == 8 then
        return ("%o"):format(value)
      elseif toBaseOrProvider == 10 then
        return value .. ""
      elseif toBaseOrProvider == 16 then
        return ("%x"):format(value)
      else
        throw(ArgumentException())
      end
    end
  end
  return systemToString(value)
end

define("System.Convert", {
  ToBoolean = toBoolean,
  ToChar = toChar,
  ToSByte = toSByte,
  ToByte = toByte,
  ToInt16 = toInt16,
  ToUInt16 = toUInt16,
  ToInt32 = toInt32,
  ToUInt32 = toUInt32,
  ToInt64 = toInt64,
  ToUInt64 = toUInt64,
  ToSingle = toSingle,
  ToDouble = toDouble,
  ToDateTime = toDateTime,
  ChangeType = changeType,
  ToString = toString,
  ToStringFromChar = string.char
})

String.ToBoolean = toBoolean
String.ToChar = toChar
String.ToSByte = toSByte
String.ToByte = toByte
String.ToInt16 = toInt16
String.ToUInt16 = toUInt16
String.ToInt32 = toInt32
String.ToUInt32 = toUInt32
String.ToInt64 = toInt64
String.ToUInt64 = toUInt64
String.ToSingle = identityFn
String.ToDouble = toDouble
String.ToDateTime = toDateTime
String.ToType = defaultToType

local function throwInvalidCastException()
  throw(InvalidCastException())
end

local Number = System.Number
Number.ToBoolean = toBoolean
Number.ToChar = toChar
Number.ToSByte = toSByte
Number.ToByte = toByte
Number.ToInt16 = toInt16
Number.ToUInt16 = toUInt16
Number.ToInt32 = toInt32
Number.ToUInt32 = toUInt32
Number.ToInt64 = toInt64
Number.ToUInt64 = toUInt64
Number.ToSingle = toSingle
Number.ToDouble = toDouble
Number.ToDateTime = throwInvalidCastException
Number.ToType = defaultToType

Boolean.ToBoolean = identityFn
Boolean.ToChar = throwInvalidCastException
Boolean.ToSByte = toSByte
Boolean.ToByte = toByte
Boolean.ToInt16 = toInt16
Boolean.ToUInt16 = toUInt16
Boolean.ToInt32 = toInt32
Boolean.ToUInt32 = toUInt32
Boolean.ToInt64 = toInt64
Boolean.ToUInt64 = toUInt64
Boolean.ToSingle = toSingle
Boolean.ToDouble = toDouble
Boolean.ToDateTime = throwInvalidCastException
Boolean.ToType = defaultToType

DateTime.ToBoolean = throwInvalidCastException
DateTime.ToChar = throwInvalidCastException
DateTime.ToSByte = throwInvalidCastException
DateTime.ToByte = throwInvalidCastException
DateTime.ToInt16 = throwInvalidCastException
DateTime.ToUInt16 = throwInvalidCastException
DateTime.ToInt32 = throwInvalidCastException
DateTime.ToUInt32 = throwInvalidCastException
DateTime.ToInt64 = throwInvalidCastException
DateTime.ToUInt64 = throwInvalidCastException
DateTime.ToSingle = throwInvalidCastException
DateTime.ToDouble = throwInvalidCastException
DateTime.ToDateTime = identityFn
DateTime.ToType = defaultToType


-- BitConverter
local band = System.band
local bor = System.bor
local sl = System.sl
local sr = System.sr
local div = System.div
local global = System.global
local systemToInt16 = System.toInt16
local systemToInt32 = System.toInt32
local systemToUInt64 = System.toUInt64
local arrayFromTable = System.arrayFromTable
local NotSupportedException = System.NotSupportedException

local assert = assert
local rawget = rawget
local unpack = table.unpack
local schar = string.char

-- https://github.com/ToxicFrog/vstruct/blob/master/io/endianness.lua#L30
local isLittleEndian = true
if rawget(global, "jit") then
  if require("ffi").abi("be") then
    isLittleEndian = false
  end
else 
  local dump = string.dump
  if dump and sbyte(dump(System.emptyFn, 7)) == 0x00 then
    isLittleEndian = false
  end
end

local function bytes(t)
  return arrayFromTable(t, Byte)    
end

local function checkIndex(value, startIndex, count)
  if value == nil then throw(ArgumentNullException("value")) end
  local len = #value
  if startIndex < 0 or startIndex >= len then
    throw(ArgumentOutOfRangeException("startIndex"))
  end
  if startIndex > len - count then
    throw(ArgumentException())
  end
end

local spack, sunpack, getBytesFromInt64, toInt64
if System.luaVersion < 5.3 then
  local struct = rawget(global, "struct")
  if struct then
    spack, sunpack = struct.pack, struct.upack
  end
  if not spack then
    spack = function ()
      throw(NotSupportedException("not found struct"), 1) 
    end
    sunpack = spack
  end

  getBytesFromInt64 = function (value)
    if value <= -2147483647 or value >= 2147483647 then
      local s = spack("i8", value)
      return bytes({
        sbyte(s, 1),
        sbyte(s, 2),
        sbyte(s, 3),
        sbyte(s, 4),
        sbyte(s, 5),
        sbyte(s, 6),
        sbyte(s, 7),
        sbyte(s, 8)
      })
    end
    return bytes({
      band(value, 0xff),
      band(sr(value, 8), 0xff),
      band(sr(value, 16), 0xff),
      band(sr(value, 24), 0xff),
      0,
      0,
      0,
      0
    })
  end

  toInt64 = function (value, startIndex)
    checkIndex(value, startIndex, 8)
    if value <= -2147483647 or value >= 2147483647 then
      throw(System.NotSupportedException()) 
    end
    if isLittleEndian then
      local i = value[startIndex + 1]
      i = bor(i, sl(value[startIndex + 2], 8))
      i = bor(i, sl(value[startIndex + 3], 16))
      i = bor(i, sl(value[startIndex + 4], 24))
      return i
    else
      local i = value[startIndex + 8]
      i = bor(i, sl(value[startIndex + 7], 8))
      i = bor(i, sl(value[startIndex + 6], 16))
      i = bor(i, sl(value[startIndex + 5], 24))
      return i
    end
  end
else
  spack, sunpack = string.pack, string.unpack
  getBytesFromInt64 = function (value)
    return bytes({
      band(value, 0xff),
      band(sr(value, 8), 0xff),
      band(sr(value, 16), 0xff),
      band(sr(value, 24), 0xff),
      band(sr(value, 32), 0xff),
      band(sr(value, 40), 0xff),
      band(sr(value, 48), 0xff),
      band(sr(value, 56), 0xff)
    })
  end

  toInt64 = function (value, startIndex)
    checkIndex(value, startIndex, 8)
    if isLittleEndian then
      local i = value[startIndex + 1]
      i = bor(i, sl(value[startIndex + 2], 8))
      i = bor(i, sl(value[startIndex + 3], 16))
      i = bor(i, sl(value[startIndex + 4], 24))
      i = bor(i, sl(value[startIndex + 5], 32))
      i = bor(i, sl(value[startIndex + 6], 40))
      i = bor(i, sl(value[startIndex + 7], 48))
      i = bor(i, sl(value[startIndex + 8], 56))
      return i
    else
      local i = value[startIndex + 8]
      i = bor(i, sl(value[startIndex + 7], 8))
      i = bor(i, sl(value[startIndex + 6], 16))
      i = bor(i, sl(value[startIndex + 5], 24))
      i = bor(i, sl(value[startIndex + 4], 32))
      i = bor(i, sl(value[startIndex + 3], 40))
      i = bor(i, sl(value[startIndex + 2], 48))
      i = bor(i, sl(value[startIndex + 1], 56))
      return i
    end
  end
end

local function getBytesFromBoolean(value)
  return bytes({ value and 1 or 0 })
end

local function getBytesFromInt16(value)
  return bytes({
    band(value, 0xff),
    band(sr(value, 8), 0xff),
  })
end

local function getBytesFromInt32(value)
  return bytes({
    band(value, 0xff),
    band(sr(value, 8), 0xff),
    band(sr(value, 16), 0xff),
    band(sr(value, 24), 0xff)
  })
end

local function getBytesFromFloat(value)
  local s = spack("f", value)
  return bytes({
    sbyte(s, 1),
    sbyte(s, 2),
    sbyte(s, 3),
    sbyte(s, 4)
  })
end

local function getBytesFromDouble(value)
  local s = spack("d", value)
  return bytes({
    sbyte(s, 1),
    sbyte(s, 2),
    sbyte(s, 3),
    sbyte(s, 4),
    sbyte(s, 5),
    sbyte(s, 6),
    sbyte(s, 7),
    sbyte(s, 8)
  })
end

local function toBoolean(value, startIndex)
  checkIndex(value, startIndex, 1)
  return value[startIndex + 1] ~= 0 and true or false
end

local function toUInt16(value, startIndex)
  checkIndex(value, startIndex, 2)
  if isLittleEndian then
    value = bor(value[startIndex + 1], sl(value[startIndex + 2], 8))
  else
    value = bor(sl(value[startIndex + 1], 8), value[startIndex + 2])
  end
  return value
end

local function toInt16(value, startIndex)
  value = toUInt16(value, startIndex)
  return systemToInt16(value)
end

local function toUInt32(value, startIndex)
  checkIndex(value, startIndex, 4)
  local i
  if isLittleEndian then
    i = value[startIndex + 1]
    i = bor(i, sl(value[startIndex + 2], 8))
    i = bor(i, sl(value[startIndex + 3], 16))
    i = bor(i, sl(value[startIndex + 4], 24))
  else
    local i = value[startIndex + 4]
    i = bor(i, sl(value[startIndex + 3], 8))
    i = bor(i, sl(value[startIndex + 2], 16))
    i = bor(i, sl(value[startIndex + 1], 24))
  end
  return i
end

local function toInt32(value, startIndex)
  value = toUInt32(value, startIndex)
  return systemToInt32(value)
end

local function toUInt64(value, startIndex)
  value = toInt64(value, startIndex)
  return systemToUInt64(value)
end

local function toSingle(value, startIndex)
  checkIndex(value, startIndex, 4)
  return sunpack("f", schar(unpack(value, startIndex + 1)))
end

local function toDouble(value, startIndex)
  checkIndex(value, startIndex, 8)
  return sunpack("d", schar(unpack(value, startIndex + 1)))
end

local function getHexValue(i)
  assert(i >= 0 and i < 16, "i is out of range.")
  if i < 10 then
    return i + 48
  end
  return i - 10 + 65
end

local function toString(value, startIndex, length)
  if value == nil then throw(ArgumentNullException("value")) end
  local len = #value
  if not startIndex then
    startIndex, length = 0, #value
  elseif not length then
    length = len - startIndex
  end
  if startIndex < 0 or (startIndex >= len and startIndex > 0) then
    throw(ArgumentOutOfRangeException("startIndex"))
  end
  if length < 0 then
    throw(ArgumentOutOfRangeException("length"))
  end
  if startIndex + length > len then
    throw(ArgumentException())
  end
  if length == 0 then
    return ""
  end
  local t = {}
  local len = 1
  for i = startIndex + 1, startIndex + length  do
    local b = value[i]
    t[len] = getHexValue(div(b, 16))
    t[len + 1] = getHexValue(b % 16)
    t[len + 2] = 45
    len = len + 3
  end
  return schar(unpack(t, 1, len - 2))
end

local function doubleToInt64Bits(value)
  assert(isLittleEndian, "This method is implemented assuming little endian with an ambiguous spec.")
  local s = spack("d", value)
  return (sunpack("i8", s))
end

local function int64BitsToDouble(value)
  assert(isLittleEndian, "This method is implemented assuming little endian with an ambiguous spec.")
  local s = spack("i8", value)
  return (sunpack("d", s))
end

define("System.BitConverter", {
  IsLittleEndian = isLittleEndian,
  GetBytesFromBoolean = getBytesFromBoolean,
  GetBytesFromInt16 = getBytesFromInt16,
  GetBytesFromInt32 = getBytesFromInt32,
  GetBytesFromInt64 = getBytesFromInt64,
  GetBytesFromFloat = getBytesFromFloat,
  GetBytesFromDouble = getBytesFromDouble,
  ToBoolean = toBoolean,
  ToChar = toUInt16,
  ToInt16 = toInt16,
  ToUInt16 = toUInt16,
  ToInt32 = toInt32,
  ToUInt32 = toUInt32,
  ToInt64 = toInt64,
  ToUInt64 = toUInt64,
  ToSingle = toSingle,
  ToDouble = toDouble,
  ToString = toString,
  DoubleToInt64Bits = doubleToInt64Bits,
  Int64BitsToDouble = int64BitsToDouble
})
end

-- CoreSystemLib: Math.lua
do
local System = System
local trunc = System.trunc

local math = math
local floor = math.floor
local min = math.min
local max = math.max
local abs = math.abs

local function bigMul(a, b)
  return a * b
end

local function divRem(a, b)
  local remainder = a % b
  return (a - remainder) / b, remainder
end

local function round(value, digits, mode)
  local mult = 10 ^ (digits or 0)
  local i = value * mult
  if mode == 1 then
    value = trunc(i + (value >= 0 and 0.5 or -0.5))
  else
    value = trunc(i)
    if value ~= i then
      local dif = i - value
      if value >= 0 then
        if dif > 0.5 or (dif == 0.5 and value % 2 ~= 0) then
          value = value + 1  
        end
      else
        if dif < -0.5 or (dif == -0.5 and value % 2 ~= 0) then
          value = value - 1  
        end
      end
    end
  end
  return value / mult
end

local function sign(v)
  return v == 0 and 0 or (v > 0 and 1 or -1) 
end

local function IEEERemainder(x, y)
  if x ~= x then
    return x
  end
  if y ~= y then
    return y
  end
  local regularMod = System.mod(x, y)
  if regularMod ~= regularMod then
    return regularMod
  end
  if regularMod == 0 and x < 0 then
    return -0.0
  end
  local alternativeResult = regularMod - abs(y) * sign(x)
  local i, j = abs(alternativeResult), abs(regularMod)
  if i == j then
    local divisionResult = x / y
    local roundedResult = round(divisionResult)
    if abs(roundedResult) > abs(divisionResult) then
      return alternativeResult
    else
      return regularMod
    end
  end
  if i < j then
    return alternativeResult
  else
    return regularMod
  end
end

local function clamp(a, b, c)
  return min(max(a, b), c)
end

local function truncate(d)
  return trunc(d) * 1.0
end

local exp = math.exp
local cosh = math.cosh or function(x) return (exp(x) + exp(-x)) / 2.0 end
local pow = math.pow or function(x, y) return x ^ y end
local sinh = math.sinh or function(x) return (exp(x) - exp(-x)) / 2.0 end
local tanh = math.tanh or function(x) return sinh(x) / cosh(x) end

local Math = math
Math.Abs = abs
Math.Acos = math.acos
Math.Asin = math.asin
Math.Atan = math.atan
Math.Atan2 = math.atan2 or math.atan
Math.BigMul = bigMul
Math.Ceiling = math.ceil
Math.Clamp = clamp
Math.Cos = math.cos
Math.Cosh = cosh
Math.DivRem = divRem
Math.Exp = exp
Math.Floor = math.floor
Math.IEEERemainder = IEEERemainder
Math.Log = math.log
Math.Log10 = math.log10
Math.Max = math.max
Math.Min = math.min
Math.Pow = pow
Math.Round = round
Math.Sign = sign
Math.Sin = math.sin
Math.Sinh = sinh
Math.Sqrt = math.sqrt
Math.Tan = math.tan
Math.Tanh = tanh
Math.Truncate = truncate

System.define("System.Math", Math)
end

-- CoreSystemLib: Random.lua
do
-- Compiled from https://github.com/dotnet/corefx/blob/master/src/Common/src/CoreLib/System/Random.cs
-- Generated by CSharp.lua Compiler
-- Licensed to the .NET Foundation under one or more agreements.
-- The .NET Foundation licenses this file to you under the MIT license.
-- See the LICENSE file in the project root for more information.
local System = System
local ArrayInt32 = System.Array(System.Int32)
System.define("System.Random", (function ()
  local Sample, InternalSample, GenerateSeed, Next, GetSampleForLargeRange, NextDouble, 
  NextBytes, internal, __ctor__, rnd
  internal = function (this)
    this._seedArray = ArrayInt32:new(56)
  end
  __ctor__ = function (this, Seed)
    if not Seed then Seed = GenerateSeed() end
    internal(this)
    local ii = 0
    local mj, mk

    --Initialize our Seed array.
    local subtraction = (Seed == -2147483648 --[[Int32.MinValue]]) and 2147483647 --[[Int32.MaxValue]] or math.Abs(Seed)
    mj = 161803398 --[[Random.MSEED]] - subtraction
    this._seedArray:set(55, mj)
    mk = 1
    for i = 1, 54 do
      --Apparently the range [1..55] is special (Knuth) and so we're wasting the 0'th position.
      ii = ii + 21
      if ii >= 55 then
        ii = ii - 55
      end
      this._seedArray:set(ii, mk)
      mk = mj - mk
      if mk < 0 then
        mk = mk + 2147483647 --[[Random.MBIG]]
      end
      mj = this._seedArray:get(ii)
    end
    for k = 1, 4 do
      for i = 1, 55 do
        local n = i + 30
        if n >= 55 then
          n = n - 55
        end
        local v =  this._seedArray:get(i) - this._seedArray:get(1 + n)
        this._seedArray:set(i, System.toInt32(v))
        if this._seedArray:get(i) < 0 then
          this._seedArray:set(i, this._seedArray:get(i) + 2147483647 --[[Random.MBIG]])
        end
      end
    end
    this._inext = 0
    this._inextp = 21
    Seed = 1
  end
  Sample = function (this)
    --Including this division at the end gives us significantly improved
    --random number distribution.
    return (InternalSample(this) * (4.6566128752457969E-10 --[[1.0 / MBIG]]))
  end
  InternalSample = function (this)
    local retVal
    local locINext = this._inext
    local locINextp = this._inextp

    locINext = locINext + 1
    if locINext >= 56 then
      locINext = 1
    end
    locINextp = locINextp + 1
    if locINextp >= 56 then
      locINextp = 1
    end

    retVal = this._seedArray:get(locINext) - this._seedArray:get(locINextp)

    if retVal == 2147483647 --[[Random.MBIG]] then
      retVal = retVal - 1
    end
    if retVal < 0 then
      retVal = retVal + 2147483647 --[[Random.MBIG]]
    end

    this._seedArray:set(locINext, retVal)

    this._inext = locINext
    this._inextp = locINextp

    return retVal
  end
  GenerateSeed = function ()
    if not rnd then
      --math.randomseed(GetTime())
      rnd = math.random
    end
    return rnd(0, 2147483647)
  end
  Next = function (this, minValue, maxValue)
    if not minValue then
      return InternalSample(this)
    end

    if not maxValue then
      maxValue = minValue
      if maxValue < 0 then
        System.throw(System.ArgumentOutOfRangeException("maxValue" --[[nameof(maxValue)]], "'maxValue' must be greater than zero."))
      end
      return System.ToInt32((Sample(this) * maxValue))
    end

    if minValue > maxValue then
      System.throw(System.ArgumentOutOfRangeException("minValue" --[[nameof(minValue)]], "'minValue' cannot be greater than maxValue."))
    end
    local range = maxValue - minValue
    if range <= 2147483647 --[[Int32.MaxValue]] then
      return (System.ToInt32((Sample(this) * range)) + minValue)
    else
      return System.toInt32((System.ToInt64((GetSampleForLargeRange(this) * range)) + minValue))
    end
  end
  GetSampleForLargeRange = function (this)
    -- The distribution of double value returned by Sample 
    -- is not distributed well enough for a large range.
    -- If we use Sample for a range [int.MinValue..int.MaxValue)
    -- We will end up getting even numbers only.

    local result = InternalSample(this)
    -- Note we can't use addition here. The distribution will be bad if we do that.
    local negative = (InternalSample(this) % 2 == 0) and true or false
    -- decide the sign based on second sample
    if negative then
      result = - result
    end
    local d = result
    d = d + (2147483646 --[[int.MaxValue - 1]])
    -- get a number in range [0 .. 2 * Int32MaxValue - 1)
    d = d / (4294967293 --[[2 * (uint)int.MaxValue - 1]])
    return d
  end
  NextDouble = function (this)
    return Sample(this)
  end
  NextBytes = function (this, buffer)
    if buffer == nil then
      System.throw(System.ArgumentNullException("buffer" --[[nameof(buffer)]]))
    end
    do
      local i = 0
      while i < #buffer do
        buffer:set(i, System.toByte(InternalSample(this)))
        i = i + 1
      end
    end
  end
  return {
    _inext = 0,
    _inextp = 0,
    Sample = Sample,
    Next = Next,
    NextDouble = NextDouble,
    NextBytes = NextBytes,
    __ctor__ = __ctor__
  }
end)())

end

-- CoreSystemLib: Text/StringBuilder.lua
do
local System = System
local throw = System.throw
local clear = System.Array.clear
local toString = System.toString
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local IndexOutOfRangeException = System.IndexOutOfRangeException

local table = table
local tconcat = table.concat
local schar = string.char
local ssub = string.sub
local sbyte = string.byte
local type = type
local select = select

local function build(this, value, startIndex, length)
  value = value:Substring(startIndex, length)
  local len = #value
  if len > 0 then
    this[#this + 1] = value
    this.Length = len
  end
end

local function getItemIndex(this, index)
  for i = 1, #this do
    local s = this[i]
    local len = #s
    local begin = index
    index = index - len
    if index < 0 then
      begin = begin + 1
      local ch = sbyte(s, begin)
      if not ch then
        break
      end
      return i, s, begin, ch
    end
  end
end

local function getLength(this)
  return this.Length
end

local StringBuilder = System.define("System.Text.StringBuilder", { 
  Length = 0,
  ToString = tconcat,
  __tostring = tconcat,
  __ctor__ = function (this, ...)
    local len = select("#", ...)
    if len == 0 then
    elseif len == 1 or len == 2 then
      local value = ...
      if type(value) == "string" then
        build(this, value, 0, #value)
      else
        build(this, "", 0, 0)
      end
    else 
      local value, startIndex, length = ...
      build(this, value, startIndex, length)
    end
  end,
  get = function (this, index)
    local _, _, _, ch = getItemIndex(this, index)
    if not _ then
      throw(IndexOutOfRangeException())
    end
    return ch
  end,
  set = function (this, index, value)
    local i, s, j = getItemIndex(this, index)
    if not i then
      throw(ArgumentOutOfRangeException("index"))
    end
    this[i] = ssub(s, 1, j - 1) .. schar(value) .. ssub(s, j + 1)
  end,
  setCapacity = function (this, value)
    if value < this.Length then
      throw(ArgumentOutOfRangeException())
    end
  end,
  getCapacity = getLength,
  getMaxCapacity = getLength,
  getLength = getLength,
  setLength = function (this, value) 
    if value < 0 then throw(ArgumentOutOfRangeException("value")) end
    if value == 0 then
      this:Clear()
      return
    end
    local delta = value - this.Length
    if delta > 0 then
      this:AppendCharRepeat(0, delta)
    else
      local length, remain = #this, value
      for i = 1, length do
        local s = this[i]
        local len = #s
        if len >= remain then
          if len ~= remain then
            s = ssub(s, 0, remain)
            this[i] = s
          end
          for j = i + 1, length do
            this[j] = nil
          end
          break
        end
        remain = remain - len
      end
      this.Length = this.Length + delta
    end  
  end,
  Append = function (this, value, startIndex, count)
    if not startIndex then
      if value ~= nil then
        value = toString(value)
        if value ~= nil then
          this[#this + 1] = value
          this.Length =  this.Length + #value
        end
      end
    else
      if value == nil then
        throw(ArgumentNullException("value"))
      end
      value = value:Substring(startIndex, count)
      this[#this + 1] = value
      this.Length =  this.Length + #value
    end
    return this
  end,
  AppendChar = function (this, v) 
    v = schar(v)
    this[#this + 1] = v
    this.Length = this.Length + 1
    return this
  end,
  AppendCharRepeat = function (this, v, repeatCount)
    if repeatCount < 0 then throw(ArgumentOutOfRangeException("repeatCount")) end
    if repeatCount == 0 then return this end
    v = schar(v)
    local count = #this + 1
    for i = 1, repeatCount do
      this[count] = v
      count = count + 1
    end
    this.Length = this.Length + repeatCount
    return this
  end,
  AppendFormat = function (this, format, ...)
    local value = format:Format(...)
    this[#this + 1] = value
    this.Length = this.Length + #value
    return this
  end,
  AppendLine = function (this, value)
    local count = 1
    local len = #this + 1
    if value ~= nil then
      this[len] = value
      len = len + 1
      count = count + #value
    end
    this[len] = "\n"
    this.Length = this.Length + count
    return this
  end,
  Clear = function (this)
    clear(this)
    this.Length = 0
    return this
  end,
  Insert = function (this, index, value)
    local length = this.Length
    if value ~= nil then
      if index == length then
        this:Append(value)
      else
        value = toString(value)
        if value ~= nil then
          local i, s, j = getItemIndex(this, index)
          if not i then
            throw(ArgumentOutOfRangeException("index"))
          end
          this[i] = ssub(s, 1, j - 1) .. value .. ssub(s, j)
          this.Length = length + #value
        end
      end
    end
  end
})
System.StringBuilder = StringBuilder
end

-- CoreSystemLib: Console.lua
do
local System = System
local toString = System.toString

local print = print
local select = select
local string = string
local byte = string.byte
local char = string.char
local Format = string.Format

local function getWriteValue(v, ...)
  if select("#", ...) ~= 0 then
    return Format(v, ...)
  end
  return toString(v)
end

local Console = System.define("System.Console", {
  WriteLine = function (v, ...)
    print(getWriteValue(v, ...))     
  end,
  WriteLineChar = function (v)
    print(char(v))     
  end
})

local io = io
if io then
  local stdin = io.stdin
  local stdout = io.stdout
  local read = stdin.read
  local write = stdout.write

  function Console.Read()
    local ch = read(stdin, 1)
    return byte(ch)
  end

  function Console.ReadLine()
     return read(stdin)
  end

  function Console.Write(v, ...)
    write(stdout, getWriteValue(v, ...))
  end

  function Console.WriteChar(v)
     write(stdout, char(v))
  end
end
end

-- CoreSystemLib: IO/File.lua
do
local io = io
if io then

local System = System
local define = System.define
local throw = System.throw
local each = System.each

local open = io.open
local remove = os.remove

local IOException = define("System.IO.IOException", {
  __tostring = System.Exception.ToString,
  base = { System.Exception },
  __ctor__ = function(this, message, innerException) 
    System.Exception.__ctor__(this, message or "I/O error occurred.", innerException)
  end,
})

local function openFile(path, mode)
  local f, err = open(path, mode)
  if f == nil then
    throw(IOException(err))
  end
  return f
end

local function readAll(path, mode)
  local f = openFile(path, mode)
  local bytes = f:read("*all")
  f:close()
  return bytes
end

local function writeAll(path, contents, mode)
  local f = openFile(path, mode)
  f:write(contents)
  f:close()
end

define("System.IO.File", {
  ReadAllBytes = function (path)
    return readAll(path, "rb")
  end,
  ReadAllText = function (path)
    return readAll(path, "r")
  end,
  ReadAllLines = function (path)
    local t = {}
    local count = 1
    for line in io.lines(path) do
      t[count] = line
      count = count + 1
    end
    return System.arrayFromTable(t, System.String)
  end,  
  WriteAllBytes = function (path, contents)
    writeAll(path, contents, "wb")
  end,
  WriteAllText = function (path, contents)
    writeAll(path, contents, "w")
  end,
  WriteAllLines = function (path, contents)
    local f = openFile(path, "w")
    for _, line in each(contents) do
      if line == nil then
        f:write("\n")
      else
        f:write(line, "\n")
      end
    end
    f:close()
  end,
  Exists = function (path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
  end,
  Delete = function (path)
    local ok, err = remove(path)
    if not ok then
      throw(IOException(err))
    end
  end
})

end
end

-- CoreSystemLib: Reflection/Assembly.lua
do
local System = System
local define = System.define
local throw = System.throw
local div = System.div
local Type = System.Type
local typeof = System.typeof
local getClass = System.getClass
local is = System.is
local band = System.band
local arrayFromTable = System.arrayFromTable
local toLuaTable = System.toLuaTable

local Exception = System.Exception
local NotSupportedException = System.NotSupportedException
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException

local assert = assert
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local rawget = rawget
local type = type
local unpack = table.unpack
local select = select
local floor = math.floor

local TargetException = define("System.Reflection.TargetException", {
  __tostring = Exception.ToString,
  base = { Exception }
})

local TargetParameterCountException = define("System.Reflection.TargetParameterCountException", {
  __tostring = Exception.ToString,
  base = { Exception },
  __ctor__ = function(this, message, innerException) 
    Exception.__ctor__(this, message or "Parameter count mismatch.", innerException)
  end,
})

local AmbiguousMatchException = define("System.Reflection.AmbiguousMatchException", {
  __tostring = Exception.ToString,
  base = { System.SystemException },
  __ctor__ = function(this, message, innerException) 
    Exception.__ctor__(this, message or "Ambiguous match found.", innerException)
  end,
})

local MissingMethodException = define("System.MissingMethodException", {
  __tostring = Exception.ToString,
  base = { Exception },
  __ctor__ = function(this, message, innerException) 
    Exception.__ctor__(this, message or "Specified method could not be found.", innerException)
  end
})

local function throwNoMatadata(sign)
  throw(NotSupportedException("not found metadata for " .. sign), 1)
end

local function eq(left, right)
  return left[1] == right[1] and left.name == right.name
end

local function getName(this)
  return this.name
end

local function isAccessibility(memberInfo, kind)
  local metadata = memberInfo.metadata
  if not metadata then
    throwNoMatadata(memberInfo.c.__name__ .. "." .. memberInfo.name)
  end
  return band(metadata[2], 0x7) == kind
end

local MemberInfo = define("System.Reflection.MemberInfo", {
  getName = getName,
  EqualsObj = function (this, obj)
    if getmetatable(this) ~= getmetatable(obj) then
      return false
    end
    return eq(this, obj)
  end,
  getMemberType = function (this)
    return this.memberType
  end,
  getDeclaringType = function (this)
    return typeof(this.c)
  end,
  getIsStatic = function (this)
    local metadata = this.metadata
    if not metadata then
      throwNoMatadata(this.c.__name__ .. "." .. this.name)
    end
    return band(metadata[2], 0x8) == 1
  end,
  getIsPrivate = function (this)
    return isAccessibility(this, 1)
  end,
  getIsFamilyAndAssembly = function (this)
    return isAccessibility(this, 2)
  end,
  getIsFamily = function (this)
    return isAccessibility(this, 3)
  end,
  getIsAssembly = function (this)
    return isAccessibility(this, 4)
  end,
  getIsFamilyOrAssembly = function (this)
    return isAccessibility(this, 5)
  end,
  getIsPublic = function (this)
    return isAccessibility(this, 6)
  end
})

local function getFieldOrPropertyType(this)
  local metadata = this.metadata
  if not metadata then
    throwNoMatadata(this.c.__name__ .. "." .. this.name)
  end
  return typeof(metadata[3])
end

local function checkObj(obj, cls)
  if not is(obj, cls) then
    throw(ArgumentException("Object does not match target type.", "obj"), 1)
  end
end

local function checkTarget(cls, obj, metadata)
  if band(metadata[2], 0x8) == 0 then
    if obj == nil then
      throw(TargetException())
    end
    checkObj(obj, cls)
  else
    return true
  end
end

local function checkValue(value, valueClass)
  if value == nil then
    if valueClass.class == "S" then
      value = valueClass:default()
    end
  else
    checkObj(value, valueClass)
  end
  return value
end

local function getOrSetField(this, obj, isSet, value)
  local cls, metadata = this.c, this.metadata
  if metadata then
    if checkTarget(cls, obj, metadata) then
      obj = cls
    end
    local name = metadata[4]
    if type(name) ~= "string" then
      name = this.name
    end
    if isSet then
      obj[name] = checkValue(value, metadata[3])
    else
      return obj[name]
    end
  else
    if obj ~= nil then
      checkObj(obj, cls)
    else
      obj = cls
    end
    if isSet then
      obj[this.name] = value
    else
      return obj[this.name]
    end
  end
end

local function isMetadataDefined(metadata, index, attributeType)
  attributeType = attributeType[1]
  for i = index, #metadata do
    if is(metadata[i], attributeType) then
      return true
    end
  end
  return false
end

local function fillMetadataCustomAttributes(t, metadata, index, attributeType)
  local count = #t + 1
  if attributeType then
    attributeType = attributeType[1]
    for i = index, #metadata do
      if is(metadata[i], attributeType) then
        t[count] = metadata[i]
        count = count + 1
      end
    end
  else
    for i = index, #metadata do
      t[count] = metadata[i]
      count = count + 1
    end
  end
end

local FieldInfo = define("System.Reflection.FieldInfo", {
  __eq = eq,
  base = { MemberInfo },
  memberType = 4,
  getFieldType = getFieldOrPropertyType,
  GetValue = getOrSetField,
  SetValue = function (this, obj, value)
    getOrSetField(this, obj, true, value)
  end,
  IsDefined = function (this, attributeType)
    if attributeType == nil then throw(ArgumentNullException()) end
    local metadata = this.metadata
    if metadata then
      return isMetadataDefined(metadata, 4, attributeType)
    end
    return false
  end,
  GetCustomAttributes = function (this, attributeType, inherit)
    if type(attributeType) == "boolean" then
      attributeType, inherit = nil, attributeType
    else
      if attributeType == nil then throw(ArgumentNullException()) end
    end
    local t = {}
    local metadata = this.metadata
    if metadata then
      local index = 4
      if type(metadata[index]) == "string" then
        index = 5
      end
      fillMetadataCustomAttributes(t, metadata, index, attributeType)
    end
    return arrayFromTable(t, System.Attribute) 
  end
})

local function getOrSetProperty(this, obj, isSet, value)
  local cls, metadata = this.c, this.metadata
  if metadata then
    local isStatic
    if checkTarget(cls, obj, metadata) then
      obj = cls
      isStatic = true
    end
    if isSet then
      value = checkValue(value, metadata[3])
    end
    local kind = band(metadata[2], 0x300)
    if kind == 0 then
      local name = metadata[4]
      if type(name) ~= "string" then
        name = this.name
      end
      if isSet then
        obj[name] = value
      else
        return obj[name]
      end
    else
      local index
      if kind == 0x100 then
        index = isSet and 5 or 4      
      elseif kind == 0x200 then
        if isSet then
          throw(ArgumentException("Property Set method was not found."))
        end
        index = 4
      else
        if not isSet then
          throw(ArgumentException("Property Get method was not found."))
        end  
        index = 4
      end
      local fn = metadata[index]
      if type(fn) == "table" then
        fn = fn[1]
      end
      if isSet then
        if isStatic then
          fn(value)
        else
          fn(obj, value)
        end  
      else
        return fn(obj)
      end
    end
  else
    local isStatic
    if obj ~= nil then
      checkObj(obj, cls)
    else
      obj = cls
      isStatic = true
    end
    if this.isField then
      if isSet then
        obj[this.name] = value
      else
        return obj[this.name]
      end
    else
      if isSet then
        local fn = obj["set" .. this.name]
        if fn == nil then
          throw(ArgumentException("Property Set method not found."))
        end
        if isStatic then
          fn(value)
        else
          fn(obj, value)
        end
      else
        local fn = obj["get" .. this.name]
        if fn == nil then
          throw(ArgumentException("Property Get method not found."))
        end
        return fn(obj)
      end
    end
  end
end

local function getPropertyAttributesIndex(metadata)
  local kind = band(metadata[2], 0x300)
  local index
  if kind == 0 then
    index = 4
  elseif kind == 0x100 then
    index = 6
  else
    index = 5
  end
  return index
end

local PropertyInfo = define("System.Reflection.PropertyInfo", {
  __eq = eq,
  base = { MemberInfo },
  memberType = 16,
  getPropertyType = getFieldOrPropertyType,
  GetValue = getOrSetProperty,
  SetValue = function (this, obj, value)
    getOrSetProperty(this, obj, true, value)
  end,
  IsDefined = function (this, attributeType)
    if attributeType == nil then throw(ArgumentNullException()) end
    local metadata = this.metadata
    if metadata then
      local index = getPropertyAttributesIndex(metadata)
      return isMetadataDefined(metadata, index, attributeType)
    end
    return false
  end,
  GetCustomAttributes = function (this, attributeType, inherit)
    if type(attributeType) == "boolean" then
      attributeType, inherit = nil, attributeType
    else
      if attributeType == nil then throw(ArgumentNullException()) end
    end
    local t = {}
    local metadata = this.metadata
    if metadata then
      local index = getPropertyAttributesIndex(metadata)
      fillMetadataCustomAttributes(t, metadata, index, attributeType)
    end
    return arrayFromTable(t, System.Attribute) 
  end
})

local function hasPublicFlag(flags)
  return band(flags, 0x7) == 6
end

local function getMethodParameterCount(flags)
  local count = band(flags, 0xFF00)
  if count ~= 0 then
    count = count / 256
  end
  return floor(count)
end

local function getMethodAttributesIndex(metadata)
  local flags = metadata[2]
  local index
  local typeParametersCount = band(flags, 0xFF0000)
  if typeParametersCount == 0 then
    local parameterCount = getMethodParameterCount(flags)
    if band(flags, 0x80) == 0 then
      index = 4 + parameterCount
    else
      index = 5 + parameterCount
    end
  else
    index = 5
  end
  return index
end

local MethodInfo = define("System.Reflection.MethodInfo", {
  __eq = eq,
  base = { MemberInfo },
  memberType = 8,
  getReturnType = function (this)
    local metadata = this.metadata
    if not metadata then
      throwNoMatadata(this.c.__name__ .. "." .. this.name)
    end
    local flags = metadata[2]
    if band(flags, 0x80) == 0 then
      return Type.Void
    end
    if band(flags, 0xC00) > 0 then
      assert(false, "not implement for generic method")
    end
    local parameterCount = getMethodParameterCount(flags)
    return typeof(metadata[4 + parameterCount])
  end,
  Invoke = function (this, obj, parameters)
    local cls, metadata = this.c, this.metadata
    if metadata then
      local isStatic
      if checkTarget(cls, obj, metadata) then
        isStatic = true
      end
      local t = {}
      local parameterCount = getMethodParameterCount(metadata[2])
      if parameterCount == 0 then
        if parameters ~= nil and #parameters > 0 then
          throw(TargetParameterCountException())
        end
      else
        if parameters == nil and #parameters ~= parameterCount then
          throw(TargetParameterCountException())
        end
        for i = 4, 3 + parameterCount do
          local j = #t
          local paramValue, mtData = parameters:get(j), metadata[i]
          if mtData ~= nil then
            paramValue = checkValue(paramValue, mtData)
          end
          t[j + 1] = paramValue
        end
      end
      local f = metadata[3]
      if isStatic then
        if t then
          return f(unpack(t, 1, parameterCount))
        else
          return f()
        end
      else
        if t then
          return f(obj, unpack(t, 1, parameterCount))
        else
          return f(obj)
        end
      end
    else
      local f = assert(this.f)
      if obj ~= nil then
        checkObj(obj, cls)
        if parameters ~= nil then
          local t = toLuaTable(parameters)
          return f(obj, unpack(t, 1, #parameters))
        else
          return f(obj)
        end
      else
        if parameters ~= nil then
          local t = toLuaTable(parameters)
          return f(unpack(t, 1, #parameters))
        else
          return f()
        end
      end
    end
  end,
  IsDefined = function (this, attributeType, inherit)
    if attributeType == nil then throw(ArgumentNullException()) end
    local metadata = this.metadata
    if metadata then
      local index = getMethodAttributesIndex(metadata)
      return isMetadataDefined(metadata, index, attributeType)
    end
    return false
  end,
  GetCustomAttributes = function (this, attributeType, inherit)
    if type(attributeType) == "boolean" then
      attributeType, inherit = nil, attributeType
    else
      if attributeType == nil then throw(ArgumentNullException()) end
    end
    local t = {}
    local metadata = this.metadata
    if metadata then
      local index = getMethodAttributesIndex(metadata)
      fillMetadataCustomAttributes(t, metadata, index, attributeType)
    end
    return arrayFromTable(t, System.Attribute)
  end
})

local function buildFieldInfo(cls, name, metadata)
  return setmetatable({ c = cls, name = name, metadata = metadata }, FieldInfo)
end

local function buildPropertyInfo(cls, name, metadata, isField)
  return setmetatable({ c = cls, name = name, metadata = metadata, isField = isField }, PropertyInfo)
end

local function buildMethodInfo(cls, name, metadata, f)
  return setmetatable({ c = cls, name = name, metadata = metadata, f = f }, MethodInfo)
end

-- https://en.cppreference.com/w/cpp/algorithm/lower_bound
local function lowerBound(t, first, last, value, comp)
  local count = last - first
  local it, step
  while count > 0 do
    it = first
    step = div(count, 2)
    it = it + step
    if comp(t[it], value) then
      it = it + 1
      first = it
      count = count - (step + 1)
    else
      count = step
    end
  end
  return first
end

local function metadataItemCompByName(item, name)
  return item[1] < name
end

local function binarySearchByName(metadata, name)
  local last = #metadata + 1
  local index = lowerBound(metadata, 1, last, name, metadataItemCompByName)
  if index ~= last then
    return metadata[index], index
  end
  return nil
end

function Type.GetField(this, name)
  if name == nil then throw(ArgumentNullException()) end
  local cls = this[1]
  local metadata = cls.__metadata__
  if metadata then
    local fields = metadata.fields
    if fields then
      local field = binarySearchByName(fields, name)
      if field then
        return buildFieldInfo(cls, name, field)
      end
      return nil
    end
  end
  if type(cls[name]) ~= "function" then
    return buildFieldInfo(cls, name)
  end
end

function Type.GetFields(this)
  local t = {}
  local cls = this[1]
  local count = 1
  repeat
    local metadata = rawget(cls, "__metadata__")
    if metadata then
      local fields = metadata.fields
      if fields then
        for i = 1, #fields do
          local field = fields[i]
          if hasPublicFlag(field[2]) then
            t[count] = buildFieldInfo(cls, field[1], field)
            count = count + 1
          end
        end
      else
        metadata = nil
      end
    end
    if not metadata then
      for k, v in pairs(cls) do
        if type(v) ~= "function" then
          t[count] = buildFieldInfo(cls, k)
          count = count + 1
        end
      end
    end
    cls = getmetatable(cls)
  until cls == nil 
  return arrayFromTable(t, FieldInfo)
end

function Type.GetProperty(this, name)
  if name == nil then throw(ArgumentNullException()) end
  local cls = this[1]
  local metadata = cls.__metadata__
  if metadata then
    local properties = metadata.properties
    if properties then
      local property = binarySearchByName(properties, name)
      if property then
        return buildPropertyInfo(cls, name, property)
      end
      return nil
    end
  end
  if cls["get" .. name] or cls["set" .. name] then
    return buildPropertyInfo(cls, name)
  else
    return buildPropertyInfo(cls, name, nil, true)
  end
end

function Type.GetProperties(this)
  local t = {}
  local cls = this[1]
  local count = 1
  repeat
    local metadata = rawget(cls, "__metadata__")
    if metadata then
      local properties = metadata.properties
      if properties then
        for i = 1, #properties do
          local property = properties[i]
          if hasPublicFlag(property[2]) then
            t[count] = buildPropertyInfo(cls, property[1], property)
            count = count + 1
          end
        end
      end
    end
    cls = getmetatable(cls)
  until cls == nil 
  return arrayFromTable(t, PropertyInfo)
end

function Type.GetMethod(this, name)
  if name == nil then throw(ArgumentNullException()) end
  local cls = this[1]
  local metadata = cls.__metadata__
  if metadata then
    local methods = metadata.methods
    if methods then
      local item, index = binarySearchByName(methods, name)
      if item then
        local next = methods[index + 1]
        if next and next[1] == name then
          throw(AmbiguousMatchException())
        end
        return buildMethodInfo(cls, name, item)
      end
      return nil
    end
  end
  local f = cls[name]
  if type(f) == "function" then
    return buildMethodInfo(cls, name, nil, f)
  end
end

function Type.GetMethods(this)
  local t = {}
  local cls = this[1]
  local count = 1
  repeat
    local metadata = rawget(cls, "__metadata__")
    if metadata then
      local methods = metadata.methods
      if methods then
        for i = 1, #methods do
          local method = methods[i]
          if hasPublicFlag(method[2]) then
            t[count] = buildMethodInfo(cls, method[1], method)
            count = count + 1
          end
        end
      else
        metadata = nil
      end
    end
    if not metadata then
      for k, v in pairs(cls) do
        if type(v) == "function" then
          t[count] = buildMethodInfo(cls, k, nil, v)
          count = count + 1
        end
      end
    end
    cls = getmetatable(cls)
  until cls == nil 
  return arrayFromTable(t, MethodInfo)
end

function Type.GetMembers(this)
  local t = arrayFromTable({}, MemberInfo)
  t:addRange(this:GetFields())
  t:addRange(this:GetProperties())
  t:addRange(this:GetMethods())
  return t
end

function Type.IsDefined(this, attributeType, inherit)
  if attributeType == nil then throw(ArgumentNullException()) end
  local cls = this[1]
  if not inherit then
    local metadata = rawget(cls, "__metadata__")
    if metadata then
      local class  = metadata.class
      if class then
        return isMetadataDefined(class, 2, attributeType)
      end
    end
    return false
  else
    repeat
      local metadata = rawget(cls, "__metadata__")
      if metadata then
        local class  = metadata.class
        if class then
          if isMetadataDefined(class, 2, attributeType) then
            return true
          end
        end
      end
      cls = getmetatable(cls)
    until cls == nil
    return false
  end
end

function Type.GetCustomAttributes(this, attributeType, inherit)
  if type(attributeType) == "boolean" then
    attributeType, inherit = nil, attributeType
  else
    if attributeType == nil then throw(ArgumentNullException()) end
  end
  local cls = this[1]
  local t = {}
  if not inherit then
    local metadata = rawget(cls, "__metadata__")
    if metadata then
      local class  = metadata.class
      if class then
        fillMetadataCustomAttributes(t, class, 2, attributeType)
      end
    end
  else
    repeat
      local metadata = rawget(cls, "__metadata__")
      if metadata then
        local class  = metadata.class
        if class then
          fillMetadataCustomAttributes(t, class, 2, attributeType)
        end
      end
      cls = getmetatable(cls)
    until cls == nil
  end
  return arrayFromTable(t, System.Attribute)
end

local Assembly, coreSystemAssembly
local function getAssembly(t)
  local assembly = t[1].__assembly__
  if assembly then
    return setmetatable(assembly, Assembly)
  end
  return coreSystemAssembly
end

local function getAssemblyName(this)
  local name = this.name or "CSharpLua.CoreLib"
  return name .. ", Version=1.0.0.0, Culture=neutral, PublicKeyToken=null"
end

Assembly = define("System.Reflection.Assembly", {
  GetName = getAssemblyName,
  getFullName = getAssemblyName,
  GetAssembly = getAssembly,
  GetTypeFrom = Type.GetTypeFrom,
  GetEntryAssembly = function ()
    local entryAssembly = System.entryAssembly
    if entryAssembly then
      return setmetatable(entryAssembly, Assembly)
    end
    return nil
  end,
  getEntryPoint = function (this)
    local entryPoint = this.entryPoint
    if entryPoint ~= nil then
      local _, _, t, name = entryPoint:find("(.*)%.(.*)")
      local cls = getClass(t)
      local f = assert(cls[name])
      return buildMethodInfo(cls, name, nil, f)
    end
    return nil
  end,
  GetExportedTypes = function (this)
    if this.exportedTypes then
      return this.exportedTypes
    end
    local t = {}
    local classes = this.classes
    if classes then
      for i = 1, #classes do
        t[i] = typeof(classes[i])
      end
    end
    local array = arrayFromTable(t, Type, true)
    this.exportedTypes = array
    return array
  end
})
coreSystemAssembly = Assembly()

function System.GetExecutingAssembly(assembly)
	return setmetatable(assembly, Assembly)
end

Type.getAssembly = getAssembly

function Type.getAssemblyQualifiedName(this)
  return this:getName() .. ', ' .. getName(assembly)
end

function Type.getAttributes(this)
  local cls = this[1]
  local metadata = rawget(cls, "__metadata__")
  if metadata then
    metadata = metadata.class
    if metadata then
      return metadata[1]
    end
  end
  throwNoMatadata(cls.__name__)
end

function Type.GetGenericArguments(this)
  local t = {}
  local count = 1

  local cls = this[1]
  local metadata = rawget(cls, "__metadata__")
  if metadata then
    metadata = metadata.class
    if metadata then
      local flags = metadata[1]
      local typeParameterCount = band(flags, 0xFF00)
      if typeParameterCount ~= 0 then
        typeParameterCount = typeParameterCount / 256
        for i = 2, 1 + typeParameterCount do
          t[count] = typeof(metadata[i])
          count = count + 1
        end
      end
      return arrayFromTable(t, Type)
    end
  end

  local name = cls.__name__ 
  local i = name:find("%[")
  if i then
    while true do
      i = i + 1
      local j = name:find(",", i) or -1
      local clsName = name:sub(i, j - 1)
      t[count] = typeof(System.getClass(clsName))
      count = count + 1
      if j == -1 then
        break
      end
    end
  end
  return arrayFromTable(t, Type)
end

local Attribute = System.Attribute

function Attribute.GetCustomAttribute(element, attributeType, inherit)
  return element:GetCustomAttribute(attributeType, inherit)
end

function Attribute.GetCustomAttributes(element, attributeType, inherit)
  return element:GetCustomAttributes(attributeType, inherit)
end

function Attribute.IsDefined(element, attributeType, inherit)
	return element:IsDefined(attributeType, inherit)
end

local function createInstance(T, nonPublic)
  local metadata = rawget(T, "__metadata__")
  if metadata then
    local methods = metadata.methods
    if methods then
      local ctorMetadata = methods[1]
      if ctorMetadata[1] == ".ctor" then
        local flags = ctorMetadata[2]
        if nonPublic or hasPublicFlag(flags) then
          local parameterCount = getMethodParameterCount(flags)
          if parameterCount == 0 then
            return T()
          end
        end
        throw(MissingMethodException())
      end
    end
  end
  return T()
end

local function isCtorMatch(method, n, f, ...)
  local flags = method[2]
  if hasPublicFlag(flags) then
    local parameterCount = getMethodParameterCount(flags)
    if parameterCount == n then
      for j = 4, 3 + parameterCount do
        local p = f(j - 3, ...)
        if not is(p, method[j]) then
          return false
        end
      end
      return true
    end
  end
  return false
end

local function findMatchCtor(T, n, f, ...)
  local metadata = rawget(T, "__metadata__")
  if metadata then
    local hasCtor
    local methods = metadata.methods
    for i = 1, #methods do
      local method = methods[i]
      if method[1] == ".ctor" then
        if isCtorMatch(method, n, f, ...) then
          return i
        end
        hasCtor = true
      else
        break
      end
    end
    if hasCtor then
      throw(MissingMethodException())
    end
  end
end

define("System.Activator", {
  CreateInstance = function (type, ...)
    if type == nil then throw(ArgumentNullException("type")) end
    if getmetatable(type) ~= Type then
      return createInstance(type)
    end
    local T, n = type[1], select("#", ...)
    if n == 0 then
      return createInstance(T)
    elseif n == 1 then
      local args = ...
      if System.isArrayLike(args) then
        n = #args
        if n == 0 then
          return createInstance(T)
        end
        local i = findMatchCtor(T, n, function (i, args) return args:get(i - 1) end, args)
        if i and i ~= 1 then
          return System.new(T, i, unpack(args, 1, n))
        end
        return T(unpack(args, 1, n))
      end
    end
    local i = findMatchCtor(T, n, select, ...)
    if i and i ~= 1 then
      return System.new(T, i, ...)
    end
    return T(...)
  end,
  CreateInstance1 = function (type, nonPublic)
    if type == nil then throw(ArgumentNullException("type")) end
    return createInstance(type[1], nonPublic)
  end
})
end

-- CoreSystemLib: Threading/Timer.lua
do
local System = System
local define = System.define
local throw = System.throw
local currentTimeMillis = System.currentTimeMillis
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException  = System.ArgumentOutOfRangeException
local NotImplementedException = System.NotImplementedException
local ObjectDisposedException = System.ObjectDisposedException

local type = type

local config = System.config
local setTimeout = config.setTimeout
local clearTimeout = config.clearTimeout

if setTimeout and clearTimeout then
	System.post = function (fn) 
		setTimeout(fn, 0) 
	end
else
	System.post = function (fn)
		fn()
	end
	local function notset()
		throw(NotImplementedException("System.config.setTimeout or clearTimeout is not registered."))
	end
  setTimeout = notset
  clearTimeout = notset
end

local maxExpiration = 9223372036854775807  --[[Int64.MaxValue]]
local LinkedListEvent =  System.LinkedList(System.Object) 
local TimeoutQueue = define("System.TimeoutQueue", (function ()
  local getNextId, Insert, Add, AddRepeating, AddRepeating1, getNextExpiration, Erase, RunLoop, 
  getCount, Contains, IsNext, __ctor__
  __ctor__ = function (this)
    this.ids_ = {}
    this.events_ = LinkedListEvent()
  end
  getNextId = function (this)
    local default = this.nextId_
    this.nextId_ = default + 1
    return default
  end
  Insert = function (this, e)
    this.ids_[e.Id] = e
    local next = this.events_:getFirst()
    while next ~= nil and next.Value.Expiration <= e.Expiration do
      next = next:getNext()
    end
    if next ~= nil then
      e.LinkNode = this.events_:AddBefore(next, e)
    else
      e.LinkNode = this.events_:AddLast(e)
    end
  end
  Add = function (this, now, delay, callback)
    return AddRepeating1(this, now, delay, 0, callback)
  end
  AddRepeating = function (this, now, interval, callback)
    return AddRepeating1(this, now, interval, interval, callback)
  end
  AddRepeating1 = function (this, now, delay, interval, callback)
    local id = getNextId(this)
    Insert(this, {
      Id = id,
      Expiration = now + delay,
      RepeatInterval = interval,
      Callback = callback
    })
    return id
  end
  getNextExpiration = function (this)
    return this.events_.Count > 0 and this.events_:getFirst().Value.Expiration or maxExpiration
  end
  Erase = function (this, id)
    local e = this.ids_[id]
    if e then
      this.ids_[id] = nil
      this.events_:RemoveNode(e.LinkNode)
      return true
    end
    return false
  end
  RunLoop = function (this, now)
    while true do
      local nextExp = getNextExpiration(this)
      if nextExp <= now then
        local e = this.events_:getFirst().Value
        Erase(this, e.Id)
        if e.RepeatInterval > 0 then
          e.Expiration = now + e.RepeatInterval
          Insert(this, e)
        end
        e.Callback(e.Id, now)
      else
        return nextExp
      end
    end
  end
  getCount = function (this)
    return this.events_.Count
  end
  Contains = function (this, id)
    return this.ids_[id] ~= nil
  end
	IsNext = function (this, id)
		local first = this.events_:getFirst()
		local nextId = first and first.Value.Id
		return nextId == id
	end
  return {
    MaxExpiration = maxExpiration,
    nextId_ = 1,
    Add = Add,
    AddRepeating = AddRepeating,
    AddRepeating1 = AddRepeating1,
    getNextExpiration = getNextExpiration,
    Erase = Erase,
    RunLoop = RunLoop,
    getCount = getCount,
    Contains = Contains,
    __ctor__ = __ctor__,
		IsNext = IsNext
  }
end)())

local timerQueue = TimeoutQueue()
local driverTimer

local function runTimerQueue()
  local now = currentTimeMillis()
  local nextExpiration = timerQueue:RunLoop(now)
  if nextExpiration ~= maxExpiration then
    driverTimer = setTimeout(runTimerQueue, nextExpiration - now)
  else
    driverTimer = nil
  end
end

local function addTimer(fn, dueTime, period)
  local now = currentTimeMillis()
  local id = timerQueue:AddRepeating1(now, dueTime, period or 0, fn)
  if timerQueue:IsNext(id) then
    if driverTimer then
      clearTimeout(driverTimer)
    end
    driverTimer = setTimeout(runTimerQueue, dueTime)
  end
  return id
end

local function removeTimer(id)
  local isNext = timerQueue:IsNext(id)
	timerQueue:Erase(id)
	if isNext then
		clearTimeout(driverTimer)
		local delay = timerQueue:getNextExpiration() - currentTimeMillis()
		driverTimer = setTimeout(runTimerQueue, delay)
	end
end

System.addTimer = addTimer
System.removeTimer = removeTimer

local function close(this)
  local id = this.id
  if id then
    removeTimer(id)
  end
end

local function change(this, dueTime, period)
  if type(dueTime) == "table" then
    dueTime = dueTime:getTotalMilliseconds()
    period = period:getTotalMilliseconds()
  end
  if dueTime < -1 or dueTime > 0xfffffffe then
    throw(ArgumentOutOfRangeException("dueTime"))
  end
  if period < -1 or period > 0xfffffffe then
    throw(ArgumentOutOfRangeException("period"))
  end
  if this.id == -1 then throw(ObjectDisposedException()) end
  close(this)
  if dueTime ~= -1 then
    this.id = addTimer(this.callback, dueTime, period)
  end
  return true
end

System.Timer = define("System.Threading.Timer", {
  __ctor__ =  function (this, callback, state,  dueTime, period)
    if callback == nil then throw(ArgumentNullException("callback")) end
    this.callback = function () callback(state) end
    change(this, dueTime, period)
  end,
  Change = change,
  Dispose = function (this)
    close(this)
    this.id = -1
  end,
  __gc = close
})
end

-- CoreSystemLib: Threading/Thread.lua
do
local System = System
local define = System.define
local throw = System.throw
local trunc = System.trunc
local post = System.post
local addTimer = System.addTimer
local Exception = System.Exception
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local NotSupportedException = System.NotSupportedException

local assert = assert
local type = type
local setmetatable = setmetatable
local coroutine = coroutine
local ccreate = coroutine.create
local cresume = coroutine.resume
local cstatus = coroutine.status
local cyield = coroutine.yield

local mainThread

local ThreadStateException = define("System.Threading.ThreadStateException", {
  __tostring = Exception.ToString,
  base = { Exception },

  __ctor__ = function(this, message, innerException)
     Exception.__ctor__(this, message or "Thread is running or terminated; it cannot restart.", innerException)
  end
})

local ThreadAbortException = define("System.Threading.ThreadAbortException", {
  __tostring = Exception.ToString,
  base = { Exception },
  __ctor__ = function(this, message, innerException)
    Exception.__ctor__(this, message or "Thread aborted.", innerException)
end
})

local nextThreadId = 1
local currentThread

local function getThreadId()
  local id = nextThreadId
  nextThreadId = nextThreadId + 1
  return id
end

local function checkTimeout(timeout)
  if type(timeout) == "table" then
    timeout = trunc(timeout:getTotalMilliseconds())
  end
  if timeout < -1 or timeout > 2147483647 then
    throw(ArgumentOutOfRangeException("timeout"))
  end
  return timeout
end

local function resume(t, obj)
  local prevThread = currentThread
  currentThread = t
  local co = assert(t.co)
  local ok, v = cresume(co, obj)
  currentThread = prevThread
  if ok then
    if type(v) == "function" then
      v()
    elseif cstatus(co) == "dead" then
      local joinThread = t.joinThread
      if joinThread then
        resume(joinThread, true)
      end
      t.co = false
    end
  else
    t.co = false
    print("Warning: Thread.run" , v)
  end
end

local function run(t, obj)
  post(function ()
    resume(t, obj)
  end)
end

local Thread =  define("System.Threading.Thread", {
  IsBackground = false,
  IsThreadPoolThread = false,
  Priority = 2,
  ApartmentState = 2,
  Abort = function ()
    throw(ThreadAbortException())
  end,
  getCurrentThread = function ()
    return currentThread
  end,
  __ctor__ = function (this, start)
	  if start == nil then throw(ArgumentNullException("start")) end
    this.start = start
  end,
  getIsAlive = function (this)
    local co = this.co
    return co and cstatus(co) ~= "dead"
  end,
  ManagedThreadId = function (this)
	  local id = this.id
    if not id then
      id = getThreadId()
      this.id = id
    end
    return id
  end,
  Sleep = function (timeout)
    local current = currentThread
    if current == mainThread then
      throw(NotSupportedException("mainThread not support"))
    end
    timeout = checkTimeout(timeout)
    local f
    if timeout ~= -1 then
      f = function ()
        addTimer(function () 
          resume(current) 
        end, timeout)
      end
    end
    cyield(f)
  end,
  Yield = function ()
    local current = currentThread
    if current == mainThread then
      return false
    end
    cyield(function ()
      run(current)
    end)
    return true
  end,
  Join = function (this, timeout)
    if currentThread == mainThread then
      throw(NotSupportedException("mainThread not support"))
    end
    if this.joinThread then
      throw(ThreadStateException())
    end
    this.joinThread = currentThread  
    if timeout == nil then
      cyield()
    else
      timeout = checkTimeout(timeout)
      local f
      if timeout ~= -1 then
        f = function ()
          addTimer(function ()
            resume(currentThread, false)
          end, timeout)
        end
      end
      return cyield(f)
    end
  end,
  Start = function (this, parameter)
    if this.co ~= nil then throw(ThreadStateException()) end
    local co = ccreate(this.start)
    this.co = co
    this.start = nil
    run(this, parameter)
  end,
  waitTask = function (taskContinueActions)
    if currentThread == mainThread then
      throw(NotSupportedException("mainThread not support"))
    end
    taskContinueActions[#taskContinueActions + 1] = function ()
      resume(currentThread)
    end
    cyield()
  end,
})

mainThread = setmetatable({ id = getThreadId() }, Thread)
currentThread = mainThread

System.ThreadStateException = ThreadStateException
System.ThreadAbortException = ThreadAbortException
System.Thread = Thread
end

-- CoreSystemLib: Threading/Task.lua
do
local System = System
local define = System.define
local defStc = System.defStc
local throw = System.throw
local try = System.try
local trunc = System.trunc
local Void = System.Void
local post = System.post
local addTimer = System.addTimer
local removeTimer = System.removeTimer
local waitTask = System.Thread.waitTask
local arrayFromTable = System.arrayFromTable
local Exception = System.Exception
local NullReferenceException = System.NullReferenceException
local NotImplementedException = System.NotImplementedException
local ArgumentException = System.ArgumentException
local ArgumentNullException = System.ArgumentNullException
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local InvalidOperationException = System.InvalidOperationException
local AggregateException = System.AggregateException
local ObjectDisposedException = System.ObjectDisposedException

local ccreate = System.ccreate
local cpool = System.cpool
local cresume = System.cresume
local cyield = System.yield

local type = type
local table = table
local select = select
local assert = assert
local getmetatable = getmetatable
local setmetatable = setmetatable
local tremove = table.remove
local pack = table.pack
local unpack = table.unpack
local error = error

local TaskCanceledException = define("System.Threading.Tasks.TaskCanceledException", {
  __tostring = Exception.ToString,
  base = { Exception },
  __ctor__ = function (this, task)
    this.task = task  
    Exception.__ctor__(this, "A task was canceled.")
  end,
  getTask = function(this) 
    return this.task
  end
})
System.TaskCanceledException = TaskCanceledException

local TaskStatusCreated = 0
local TaskStatusWaitingForActivation = 1
local TaskStatusWaitingToRun = 2
local TaskStatusRunning = 3
local TaskStatusWaitingForChildrenToComplete = 4
local TaskStatusRanToCompletion = 5
local TaskStatusCanceled = 6
local TaskStatusFaulted = 7

System.TaskStatus = System.defEnum("System.Threading.Tasks.TaskStatus", {
  Created = TaskStatusCreated,
  WaitingForActivation = TaskStatusWaitingForActivation,
  WaitingToRun = TaskStatusWaitingToRun,
  Running = TaskStatusRunning,
  WaitingForChildrenToComplete = TaskStatusWaitingForChildrenToComplete,
  RanToCompletion = TaskStatusRanToCompletion,
  Canceled = TaskStatusCanceled,
  Faulted = TaskStatusFaulted,
})

local UnobservedTaskExceptionEventArgs = define("System.Threading.Tasks.UnobservedTaskExceptionEventArgs", {
  __ctor__ = function (this, exception)
    this.exception = exception
  end,
  SetObserved = function (this)
    this.observed = true
  end,
  getObserved = function (this)
    if this.observed then
      return true
    end
    return false
  end,
  getException = function (this)
    return this.exception
  end
})
System.UnobservedTaskExceptionEventArgs = UnobservedTaskExceptionEventArgs

local unobservedTaskException
local function publishUnobservedTaskException(sender, ueea)
  local handler = unobservedTaskException
  if handler then
    handler(sender, ueea)
  end
end

local TaskScheduler = define("System.Threading.Tasks.TaskScheduler", {
  addUnobservedTaskException = function (value)
    unobservedTaskException = unobservedTaskException + value
  end,
  removeUnobservedTaskException = function (value)
    unobservedTaskException = unobservedTaskException - value
  end
})
System.TaskScheduler = TaskScheduler

local TaskExceptionHolder = {
  __index = false,
  __gc = function (this)
    if not this.isHandled then
      local e = this.exception
      if e then
        local ueea = UnobservedTaskExceptionEventArgs(e)
        publishUnobservedTaskException(this.task, ueea)
        if not ueea.observed then
          print("Warning: TaskExceptionHolder" , e)
        end
      end
    end
  end
}
TaskExceptionHolder.__index = TaskExceptionHolder

local function newTaskExceptionHolder(task, exception) 
  return setmetatable({ task = task, exception = exception }, TaskExceptionHolder)
end

local function getException(task, await)
  local holder = task.data
  if not holder.isHandled then
    holder.isHandled = true
  end
  local e = holder.exception
  if await then
    return e
  end
  return AggregateException(e)
end

local Task
local nextTaskId = 1
local currentTask
local completedTask

local function getNewId()
  local id = nextTaskId
  nextTaskId = nextTaskId + 1
  return id
end

local function getId(this)
  local id = this.id
  if id == nil then
    id = getNewId()
    this.id = id
  end
  return id 
end

local function isCompleted(this)
  local status = this.status
  return status == TaskStatusRanToCompletion or status == TaskStatusFaulted or status == TaskStatusCanceled
end

local function newTask(status, data)
  return setmetatable({ status = status, data = data }, Task)
end

local function fromResult(result)
  return newTask(TaskStatusRanToCompletion, result)
end

local function fromCanceled(cancellationToken)
  if cancellationToken and cancellationToken:getIsCancellationRequested() then 
    throw(ArgumentOutOfRangeException("cancellationToken"))
  end
  return newTask(TaskStatusCanceled, cancellationToken)
end

local function fromException(exception)
  local data = newTaskExceptionHolder(false, exception)
  local t = newTask(TaskStatusFaulted, data) 
  data.task = t
  return t
end

local function getCompletedTask()
  local t = completedTask
  if t == nil then
    t = fromResult()
    completedTask = t
  end
  return t
end

local function trySetComplete(this, status, data)
  if isCompleted(this) then
    return false
  end

  this.status = status
  this.data = data

  local continueActions = this.continueActions
  if continueActions then
    for i = 1, #continueActions do
      continueActions[i](this)
    end
    this.continueActions = nil
  end
  return true
end

local function trySetResult(this, result)
  return trySetComplete(this, TaskStatusRanToCompletion, result)
end

local function trySetException(this, exception)
  if this.data == Void then
    throw(exception)
  end
  return trySetComplete(this, TaskStatusFaulted, newTaskExceptionHolder(this, exception))
end

local function trySetCanceled(this, cancellationToken)
  return trySetComplete(this, TaskStatusCanceled, cancellationToken)
end

local function newWaitingTask(isVoid)
  return newTask(TaskStatusWaitingForActivation, isVoid and Void)
end

local function getContinueActions(task) 
  local continueActions = task.continueActions
  if continueActions == nil then
    continueActions = {}
    task.continueActions = continueActions
  end
  return continueActions
end

local function addContinueAction(task, f)
  local continueActions = getContinueActions(task)
  continueActions[#continueActions + 1] = assert(f)
end

local function checkTasks(...)
  local tasks
  local n = select("#", ...)
  if n == 1 then
    local args = ...
    if args == nil then throw(ArgumentNullException("tasks")) end
    if System.isArrayLike(args) then
      tasks = args
    elseif System.isEnumerableLike(args) then
      tasks = System.Array.toArray(args)
    end
  end
  if not tasks then
    tasks = System.Array(Task)(...)
  end
  for i = 1, #tasks do
    if tasks[i] == System.null then
      throw(ArgumentNullException())
    end
  end
  return tasks
end

local function getDelay(delay)
  if type(delay) == "table" then
    delay = trunc(delay:getTotalMilliseconds())
    if delay < -1 or delay > 2147483647 then
      throw(ArgumentOutOfRangeException("delay"))
    end
  elseif delay < -1 then
    throw(ArgumentOutOfRangeException("millisecondsDelay"))  
  end
  return delay
end

local waitToken = {}
local function getResult(this, await)
  local status = this.status
  if status == TaskStatusRanToCompletion then
    return this.data
  elseif status == TaskStatusFaulted then
    throw(getException(this, await))
  elseif status == TaskStatusCanceled then
    local e = TaskCanceledException(this)
    if not await then e = AggregateException(e) end
    throw(e)
  end
  return waitToken
end

local function getAwaitResult(task)
  local status = task.status
  local ok, v
  if status == TaskStatusRanToCompletion then
    ok, v = true, task.data
  elseif status == TaskStatusFaulted then
    ok, v = false, getException(task, true)
  elseif status == TaskStatusCanceled then
    ok, v = false, TaskCanceledException(task)
  else
    assert(false)
  end
  return ok, v
end

local factory = {
  StartNew = function (_, f, state)
    local t = newWaitingTask()
    post(function ()
      try(function ()
        assert(trySetResult(t, f(state)))
      end, function (e)
        assert(trySetException(t, e))
      end)
    end)
    return t
  end
}

Task = define("System.Threading.Tasks.Task", {
  Dispose = System.emptyFn,
  __ctor__ = function (this, action, state)
    if action == nil then throw(ArgumentNullException("action")) end
    this.status = TaskStatusCreated
    this.data = function ()
      return action(state)
    end
  end,
  getId = getId,
  getCurrentId = function ()
    local t = currentTask
    if t then
      return getId(t)
    end
  end,
  getFactory = function ()
    return factory
  end,
  getStatus = function (this)
    return this.status
  end,
  getException = function (this)
    if this.status == TaskStatusFaulted then
      return getException(this)
    end
    return nil
  end,
  getResult = function (this)
    local result = getResult(this)
    if result == waitToken then
      waitTask(getContinueActions(this))
      result = getResult(this)
      assert(result ~= waitToken)
    end
    return result
  end,
  getIsCompleted = isCompleted,
  getIsCanceled = function (this)
    return this.status == TaskStatusCanceled
  end,
  getIsFaulted = function (this)
    return this.status == TaskStatusFaulted
  end,
  FromResult = fromResult,
  FromCanceled = fromCanceled,
  FromException = fromException,
  getCompletedTask = getCompletedTask,
  Delay = function (delay, cancellationToken)
    delay = getDelay(delay)

    if cancellationToken and cancellationToken:getIsCancellationRequested() then
      return fromCanceled(cancellationToken)
    elseif delay == 0 then
      return getCompletedTask()
    end

    local t = newWaitingTask()
    local timerId, registration  

    if cancellationToken and cancellationToken:getCanBeCanceled() then
      registration = cancellationToken:Register(function ()
        local success = trySetCanceled(t, cancellationToken)
        if success and timerId then
          removeTimer(timerId)
        end
      end)
    end

    if delay ~= -1 then
      timerId = addTimer(function ()
        local success = trySetResult(t)
        if success and registration then
          registration:Dispose()
        end
      end, delay)
    end

    return t
  end,
  Run = function (f, cancellationToken)
    local t = Task(f) 
    t:Start()
    return t
  end,
  WhenAll = function (T, ...)
    local tasks = checkTasks(...)
    local count = #tasks
    if count == 0 then
      return getCompletedTask()
    end
    local result, exceptions, cancelled = {}, {}
    local t = newWaitingTask()
    local function f(task)
      local status = task.status
      if status == TaskStatusRanToCompletion then
        result[#result + 1] = task.data
      elseif status == TaskStatusFaulted then
        local exception = getException(task, true)
        exceptions[#exceptions + 1] = exception
      elseif status == TaskStatusCanceled then
        cancelled = true
      end
      count = count - 1
      if count == 0 then
        if #exceptions > 0 then
          trySetException(t, arrayFromTable(exceptions, Exception))
        elseif cancelled then
          trySetCanceled(t)
        else
          if T then
            trySetResult(t, arrayFromTable(result, T))
          end
            trySetResult(t)
        end
      end
    end
    for i = 1, count do
      local task = tasks[i]
      if isCompleted(task) then
        post(function ()
          f(task)
        end)
      else
        addContinueAction(task, f)
      end
    end
    return t
  end,
  WhenAny = function (...)
    local tasks = checkTasks(...)
    local count = #tasks
    if count == 0 then
      throw(ArgumentException())
    end
    local t = newWaitingTask()
    local function f(task)
      local status = task.status
      if status == TaskStatusRanToCompletion then
        trySetResult(t, task)
      elseif status == TaskStatusFaulted then
        trySetException(t, getException(task))
      elseif status == TaskStatusCanceled then
        trySetCanceled(t)
      end
    end
    for i = 1, count do
      local task = tasks[i]
      if isCompleted(task) then
        post(function ()
          f(task)
        end)
      else
        addContinueAction(task, f)
      end
    end
    return t
  end,
  ContinueWith = function (this, continuationAction)
    if continuationAction == nil then throw(ArgumentNullException("continuationAction")) end
    local t = newWaitingTask()
    local function f(task)
      try(function ()
        t.status = TaskStatusRunning
        assert(trySetResult(t, continuationAction(task)))
      end, function (e)
        assert(trySetException(t, e))
      end)
    end
    if isCompleted(this) then
      post(function ()
        f(this)
      end)
    else
      addContinueAction(this, f)
    end
    return t
  end,
  Start = function (this)
    if this.status ~= TaskStatusCreated then throw(InvalidOperationException("Task was already started.")) end
    this.status = TaskStatusWaitingToRun
    post(function ()
      try(function ()
        this.status = TaskStatusRunning
        assert(trySetResult(this, this.data()))
      end, function (e)
        assert(trySetException(this, e))
      end)
    end)
  end,
  Wait = function (this)
    waitTask(getContinueActions(this))
  end,
  Await = function (this, t)
    local a = t:GetAwaiter()
    if a:getIsCompleted() then
      return a:GetResult()
    end
    a:OnCompleted(function ()
      local ok, v
      try(function ()
        ok, v = true, a:GetResult()
      end, function (e)
        ok, v = false, e
      end)
      ok, v = cresume(this.c, ok, v)
      if not ok then
        assert(trySetException(this, v))
      end
    end)
    local ok, v = cyield()
    if ok then
      return v
    else
      error(v)
    end
  end,
  await = function (this, task)
    if getmetatable(task) ~= Task then
      return this:Await(task)
    end

    local result = getResult(task, true)
    if result ~= waitToken then
      return result
    end
    addContinueAction(task, function (task)
      local ok, v = getAwaitResult(task)
      ok, v = cresume(this.c, ok, v)
      if not ok then
        assert(trySetException(this, v))
      end
    end)
    local ok, v = cyield()
    if ok then
      return v
    else
      error(v)
    end
  end
})
System.Task = Task

local TaskT_TransitionToFinal_AlreadyCompleted = "An attempt was made to transition a task to a final state when it had already completed."
local TaskCompletionSource = define("System.Threading.Tasks.TaskCompletionSource", {
  __ctor__ = function (this)
    this.task = newWaitingTask()
  end,
  getTask = function (this)
    return this.task
  end,
  SetCanceled = function (this)
    if not trySetCanceled(this.task) then
      throw(InvalidOperationException(TaskT_TransitionToFinal_AlreadyCompleted))
    end
  end,
  SetException = function (this, exception)
    if exception == nil then throw(ArgumentNullException("exception")) end
    if not trySetException(this.task, exception) then
      throw(InvalidOperationException(TaskT_TransitionToFinal_AlreadyCompleted))
    end
  end,
  SetResult = function (this, result)
    if not trySetResult(this.task, result) then
      throw(InvalidOperationException(TaskT_TransitionToFinal_AlreadyCompleted))
    end
  end,
  TrySetCanceled = trySetCanceled,
  TrySetException = trySetException,
  TrySetResult = trySetResult
})
System.TaskCompletionSource = TaskCompletionSource

local CancellationTokenRegistration = defStc("System.Threading.CancellationTokenRegistration", (function ()
  local function unregister(this)
    local token = this.token
    if token then
      local f = this.f
      if f then
        this.f = nil
        return token.source:unRegister(f)
      end
    end
    return false
  end
  return {
    base =  function(_, T)
      return { System.IDisposable, System.IEquatable_1(T) }
    end,
    __ctor__ = function (this, token, f)
      if not token then
        return
      end
      this.token = token
      this.f = f
    end,
    getToken = function (this)
      return this.token
    end,
    Equals = System.equals,
    Unregister = unregister,
    Dispose = unregister
  }
end)())
System.CancellationTokenRegistration = CancellationTokenRegistration

local OperationCanceledException = define("System.OperationCanceledException", {
  __tostring = Exception.ToString,
  base = { System.SystemException },
  __ctor__ = function (this, message, innerException, token)
    Exception.__ctor__(this, message or "The operation was canceled.", innerException)
    this.tokne = token
  end,
  getCancellationToken = function (this)
    return this.token
  end
})

local canceledSource
local CancellationToken 
CancellationToken = defStc("System.Threading.CancellationToken", {
  __ctor__ = function (this, canceled)
    if canceled == nil then
      return
    end
    if canceled == true then
      this.source = canceledSource
    elseif canceled then
      this.source = canceled
    end
  end,
  getCanBeCanceled = function (this)
    return this.source ~= nil
  end,
  getIsCancellationRequested = function (this)
    local source = this.source
    if source then
      return source:getIsCancellationRequested()
    end
    return false
  end,
  getNone = function ()
    return CancellationToken()
  end,
  Equals = System.equals,
  Register = function (this, callback, state)
    local source = this.source
    if source then
      if not source:getIsCancellationRequested() then
        local function f()
          callback(state)
        end
        this.source:register(f)
        return CancellationTokenRegistration(this, f)
      end
      callback(state)
    end
    return CancellationTokenRegistration()
  end,
  ThrowIfCancellationRequested = function (this)
    if this:getIsCancellationRequested() then
      throw(OperationCanceledException())
    end
  end
})
System.CancellationToken = CancellationToken

local CancellationTokenSource 
CancellationTokenSource = define("System.Threading.CancellationTokenSource", (function ()
  local function clean(this)
    local timerId = this.timerId
    if timerId then
      removeTimer(timerId)
    end
    local links = this.links
    if links then
      for i = 1, #links do
        links[i]:Dispose()
      end
    end
  end
  return  {
    state = 0,
    base = { System.IDisposable },
    __ctor__  = function (this, delay)
      if delay then
        delay = getDelay(delay)
        if delay == 0 then
          this.state = 1
        else
          this.timerId = addTimer(function ()
            this.Cancel()
          end, delay)
        end
      end
    end,
    Cancel = function (this, throwOnFirstException)
      if this.disposed then throw(ObjectDisposedException()) end
      if this.state == 1  then
        return
      end
      clean(this)
      this.state = 1
      local actions = this.continueActions
      if actions then
        local t = {}
        for i = 1, #actions do
          try(function ()
            actions[i]()          
          end, function (e)
            if throwOnFirstException then
              throw(e)
            end
            t[#t + 1] = e
          end)
        end
        if #t > 0 then
          throw(AggregateException(arrayFromTable(t, Exception)))
        end
      end
    end,
    CancelAfter = function (this, delay)
      if this.disposed then throw(ObjectDisposedException()) end
      delay = getDelay(delay)
      if this.state == 1  then
        return
      end
      local timerId = this.timerId
      if timerId then
        removeTimer(timerId)
      end
      this.timerId = addTimer(function ()
        this:Cancel()
      end, delay)
    end,
    Dispose = function (this)
      if this.disposed then
        return
      end
      clean(this)
      this.disposed = true
    end,
    getIsCancellationRequested = function (this)
      return this.state == 1
    end,
    getToken = function (this)
      local t = this.token
      if not t then
        t = CancellationToken(this)
        this.token = t
      end
      return t
    end,
    register = addContinueAction,
    unRegister = function (this, f)
      local actions = this.continueActions
      if actions then
        for i = 1, #actions do
          if actions[i] == f then
            tremove(actions, i)
            return true
          end
        end
      end
      return false
    end,
    CreateLinkedTokenSource = function (...)
      local cts, links, count = CancellationTokenSource(), {}, 1
      cts.links = links
      local n = select("#", ...)
      if n == 1 then
        local args = ...
        if System.isArrayLike(args) then
          for i = 1, #args do
            links[count] = args[i]:Register(cts.Cancel, cts)
            count = count + 1 
          end
          return cts
        end
      end
      for i = 1, n do
        local token = select(i, ...)
        links[count] = token:Register(cts.Cancel, cts)
        count = count + 1 
      end
      return cts
    end
  }
end)())
System.CancellationTokenSource = CancellationTokenSource
canceledSource = setmetatable({ state = 1 }, CancellationTokenSource)

local function taskCoroutineCreate(t, f)
  local c = ccreate(function (...)
    local r = f(t, ...)
    assert(trySetResult(t, r))
  end)
  t.c = c
  return c
end

function System.async(f, void, ...)
  local t = newWaitingTask(void)
  local c = taskCoroutineCreate(t, f)
  local ok, v = cresume(c, ...)
  if not ok then
    assert(trySetException(t, v))
  end
  return t
end

local IAsyncDisposable = System.defInf("System.IAsyncDisposable")
local IAsyncEnumerable = System.defInf("System.Collections.Generic.IAsyncEnumerable", System.emptyFn)
local IAsyncEnumerator = System.defInf("System.Collections.Generic.IAsyncEnumerator", System.emptyFn)

System.IAsyncEnumerable_1 =  IAsyncEnumerable
System.IAsyncEnumerator_1 = IAsyncEnumerator

local yieldAsync 
local function checkYieldAsync(this, ok, v, current)
  if ok then
    if v == yieldAsync then
      this.e.current = current
      assert(trySetResult(this.t, true))
    elseif v == cpool then
      this.c = nil
      this.e.current = nil
      assert(trySetResult(this.t, false))
    end
  else
    assert(trySetException(this.t, v))
  end
end
yieldAsync = {
  __index = false,
  await = function (this, task)
    local result = getResult(task, true)
    if result ~= waitToken then
      return result
    end
    addContinueAction(task, function (task)
      local current
      local ok, v = getAwaitResult(task)
      ok, v, current = cresume(this.c, ok, v)
      checkYieldAsync(this, ok, v, current)
    end)
    local ok, v = cyield()
    if ok then
      return v
    else
      error(v)
    end
  end,
  yield = function (this, v)
    cyield(yieldAsync, v)
  end
}
yieldAsync.__index = yieldAsync

local YieldAsyncEnumerable
YieldAsyncEnumerable = define("System.YieldAsyncEnumerable", function (T)
   return {
    base = { IAsyncEnumerable(T), IAsyncEnumerator(T), IAsyncDisposable },
    __genericT__ = T
  }
end, {
  getCurrent = System.getCurrent, 
  GetAsyncEnumerator = function (this)
    return setmetatable({ f = this.f, args = this.args }, YieldAsyncEnumerable(this.__genericT__))
  end,
  DisposeAsync = function (this)
    return getCompletedTask()
  end,
  MoveNextAsync = function (this)
    local a = this.a
    if a and a.c == nil then
      return fromResult(false)
    end

    local t = newWaitingTask()
    local ok, v, current
    if a == nil then
      local c = ccreate(this.f)
      a = setmetatable({ t = t, c = c, e = this }, yieldAsync)
      this.a = a
      local args = this.args
      ok, v, current = cresume(c, a, unpack(args, 1, args.n))
      this.args = nil
    else
      a.t = t
      ok, v, current = cresume(a.c)
    end
    checkYieldAsync(a, ok, v, current)
    return t
  end
})

local function yieldIAsyncEnumerable(f, T, ...)
  return setmetatable({ f = f, args = pack(...) }, YieldAsyncEnumerable(T))
end

System.yieldIAsyncEnumerable = yieldIAsyncEnumerable
System.yieldIAsyncEnumerator = yieldIAsyncEnumerable

local function eachFn(en, async)
  if async:await(en:MoveNextAsync()) then
    return async, en:getCurrent()
  end
  return nil
end

local function each(async, t)
  if t == nil then throw(NullReferenceException(), 1) end
  local en = t:GetAsyncEnumerator()
  return eachFn, en, async
end

System.asynceach = each
end

-- CoreSystemLib: Utilities.lua
do
local System = System
local throw = System.throw
local define = System.define
local trunc = System.trunc
local sl = System.sl
local bor = System.bor
local TimeSpan = System.TimeSpan
local ArgumentNullException = System.ArgumentNullException

local select = select
local type = type
local os = {}
local clock = GetTime
local tostring = tostring
local collectgarbage = collectgarbage

define("System.Environment", {
  Exit = function() end,
  getStackTrace = System.traceback,
  getTickCount = function ()
    return System.currentTimeMillis() % 2147483648
  end
})

define("System.GC", {
  Collect = function ()
    collectgarbage("collect")
  end,
  GetTotalMemory = function (forceFullCollection)
    if forceFullCollection then 
      collectgarbage("collect")
    end
    return collectgarbage("count") * 1024
  end
})

local Lazy = {
  created = false,
  __ctor__ = function (this, ...)
    local n = select("#", ...)
    if n == 0 then
    elseif n == 1 then
      local valueFactory = ...
      if valueFactory == nil then
        throw(ArgumentNullException("valueFactory"))
      elseif type(valueFactory) ~= "boolean" then
        this.valueFactory = valueFactory
      end
    elseif n == 2 then
      local valueFactory = ...
      if valueFactory == nil then
        throw(ArgumentNullException("valueFactory"))
      end
      this.valueFactory = valueFactory
    end
  end,
  getIsValueCreated = function (this)
    return this.created
  end,
  getValue = function (this)
    if not this.created then
      local valueFactory = this.valueFactory
      if valueFactory then
        this.value = valueFactory()
        this.valueFactory = nil
      else
        this.value = this.__genericT__()
      end
      this.created = true
    end
    return this.value
  end,
  ToString = function (this)
    if this.created then
      return this.value:ToString()
    end
    return "Value is not created."
  end
}

define("System.Lazy", function (T)
  return { 
    __genericT__ = T 
  }
end, Lazy)

local ticker, frequency
local time = System.config.time
if time then
  ticker = time
  frequency = 10000
else
  ticker = clock
  frequency = 1000
end

local function getRawElapsedSeconds(this)
  local timeElapsed = this.elapsed
  if this.running then
    local currentTimeStamp = ticker()
    local elapsedUntilNow  = currentTimeStamp - this.startTimeStamp
    timeElapsed = timeElapsed + elapsedUntilNow
  end
  return timeElapsed
end

local Stopwatch
Stopwatch = define("System.Diagnostics.Stopwatch", {
  elapsed = 0,
  running = false,
  IsHighResolution = false,
  Frequency = frequency,
  StartNew = function ()
    local t = Stopwatch()
    t:Start()
    return t
  end,
  GetTimestamp = function ()
    return trunc(ticker() * frequency)
  end,
  Start = function (this)
    if not this.running then
      this.startTimeStamp = ticker()
      this.running = true
    end
  end,
  Stop = function (this)
    if this.running then
      local endTimeStamp = ticker()
      local elapsedThisPeriod = endTimeStamp - this.startTimeStamp
      local elapsed = this.elapsed + elapsedThisPeriod
      this.running = false
      if elapsed < 0 then
        -- os.clock may be return negative value
        elapsed = 0
      end
      this.elapsed = elapsed
    end
  end,
  Reset = function (this)
    this.elapsed = 0
    this.running = false
    this.startTimeStamp = 0
  end,
  Restart = function (this)
    this.elapsed = 0
    this.startTimeStamp = ticker()
    this.running = true
  end,
  getIsRunning = function (this)
    return this.running
  end,
  getElapsed = function (this)
    return TimeSpan(trunc(getRawElapsedSeconds(this) * 1e7))
  end,
  getElapsedMilliseconds = function (this)
    return trunc(getRawElapsedSeconds(this) * 1000)
  end,
  getElapsedTicks = function (this)
    return trunc(getRawElapsedSeconds(this) * frequency)
  end
})
System.Stopwatch = Stopwatch

local weaks = setmetatable({}, { __mode = "kv" })

local function setWeakTarget(this, target)
  weaks[this] = target
end

define("System.WeakReference", {
  trackResurrection = false,
  SetTarget = setWeakTarget,
  setTarget = setWeakTarget,
  __ctor__ = function (this, target, trackResurrection)
    if trackResurrection then
      this.trackResurrection = trackResurrection
    end
    weaks[this] = target
  end,
  TryGetTarget = function (this)
    local target = weaks[this]
    return target ~= nil, target
  end,
  getIsAlive = function (this)
    return weaks[this] ~= nil
  end,
  getTrackResurrection = function (this)
    return this.trackResurrection
  end,
  getTarget = function (this)
    return weaks[this]
  end
})

define("System.Guid", {})
define("System.ArraySegment", {})
end

-- CoreSystemLib: Globalization/Globalization.lua
do
local System = System
local emptyFn = System.emptyFn
local define = System.define

define("System.Globalization.NumberFormatInfo", {
  getInvariantInfo = emptyFn,
  getCurrentInfo = emptyFn,
})

define("System.Globalization.CultureInfo", {
  getInvariantCulture = emptyFn,
})

define("System.Globalization.DateTimeFormatInfo", {
  getInvariantInfo = emptyFn,
})
end

-- CoreSystemLib: Numerics/HashCodeHelper.lua
do
local System = System
local bitLShift = System.sl
local bitNot = System.bnot

local HashCodeHelper = {}

function HashCodeHelper.CombineHashCodes(h1, h2)
  return (bitLShift(h1, 5) + h1) * bitNot(h2)
end

System.define("System.Numerics.HashCodeHelper", HashCodeHelper)
end

-- CoreSystemLib: Numerics/Complex.lua
do
-- Compiled from https://github.com/dotnet/corefx/blob/master/src/System.Runtime.Numerics/src/System/Numerics/Complex.cs
-- Generated by CSharp.lua Compiler
-- Licensed to the .NET Foundation under one or more agreements.
-- The .NET Foundation licenses this file to you under the MIT license.
-- See the LICENSE file in the project root for more information.
local System = System

local assert = assert
local type = type
local math = math

-- <summary>
-- A complex number z is a number of the form z = x + yi, where x and y
-- are real numbers, and i is the imaginary unit, with the property i2= -1.
-- </summary>
System.define("System.Numerics.Complex", (function ()
  local Zero, One, ImaginaryOne, NaN, Infinity, s_sqrtRescaleThreshold, s_asinOverflowThreshold, s_log2, 
  getReal, getImaginary, getMagnitude, getPhase, FromPolarCoordinates, Negate, Add, Subtract, 
  Multiply, Divide, Abs, Hypot, Log1P, Conjugate, Reciprocal, op_Equality, EqualsObj, Equals, 
  GetHashCode, ToString, Sin, Sinh, Asin, Cos, Cosh, Acos, 
  Tan, Tanh, Atan, Asin_Internal, IsFinite, IsInfinity, IsNaN, Log, 
  Log10, Exp, Sqrt, Pow, Pow1, Scale, ToComplex, 
  class, static, __ctor__
  static = function (this)
    Zero = class(0.0, 0.0)
    this.Zero = Zero
    One = class(1.0, 0.0)
    this.One = One
    ImaginaryOne = class(0.0, 1.0)
    this.ImaginaryOne = ImaginaryOne
    NaN = class(System.Double.NaN, System.Double.NaN)
    this.NaN = NaN
    Infinity = class(System.Double.PositiveInfinity, System.Double.PositiveInfinity)
    this.Infinity = Infinity
    s_sqrtRescaleThreshold = 1.79769313486232E+308 --[[Double.MaxValue]] / (math.Sqrt(2.0) + 1.0)
    s_asinOverflowThreshold = math.Sqrt(1.79769313486232E+308 --[[Double.MaxValue]]) / 2.0
    s_log2 = math.Log(2.0)
  end
  __ctor__ = function (this, real, imaginary)
    if real == nil then
      return
    end
    this.m_real = real
    this.m_imaginary = imaginary
  end
  getReal = function (this)
    return this.m_real
  end
  getImaginary = function (this)
    return this.m_imaginary
  end
  getMagnitude = function (this)
    return Abs(this)
  end
  getPhase = function (this)
    return math.Atan2(this.m_imaginary, this.m_real)
  end
  FromPolarCoordinates = function (magnitude, phase)
    return class(magnitude * math.Cos(phase), magnitude * math.Sin(phase))
  end
  Negate = function (value)
    return class(- value.m_real, - value.m_imaginary)
  end
  Add = function (left, right)
    if type(left) == "number" then
      return class(left + right.m_real, right.m_imaginary)
    elseif type(right) == "number" then
      return class(left.m_real + right, left.m_imaginary)
    else
      return class(left.m_real + right.m_real, left.m_imaginary + right.m_imaginary)
    end
  end
  Subtract = function (left, right)
    if type(left) == "number" then
      return class(left - right.m_real, - right.m_imaginary)
    elseif type(right) == "number" then
      return class(left.m_real - right, left.m_imaginary)
    else
      return class(left.m_real - right.m_real, left.m_imaginary - right.m_imaginary)
    end
  end
  Multiply = function (left, right)
    if type(left) == "number" then
      if not System.Double.IsFinite(right.m_real) then
        if not System.Double.IsFinite(right.m_imaginary) then
          return class(System.Double.NaN, System.Double.NaN)
        end

        return class(left * right.m_real, System.Double.NaN)
      end

      if not System.Double.IsFinite(right.m_imaginary) then
        return class(System.Double.NaN, left * right.m_imaginary)
      end

      return class(left * right.m_real, left * right.m_imaginary)
    elseif type(right) == "number" then
      if not System.Double.IsFinite(left.m_real) then
        if not System.Double.IsFinite(left.m_imaginary) then
          return class(System.Double.NaN, System.Double.NaN)
        end

        return class(left.m_real * right, System.Double.NaN)
      end

      if not System.Double.IsFinite(left.m_imaginary) then
        return class(System.Double.NaN, left.m_imaginary * right)
      end

      return class(left.m_real * right, left.m_imaginary * right)
    else
      -- Multiplication:  (a + bi)(c + di) = (ac -bd) + (bc + ad)i
      local result_realpart = (left.m_real * right.m_real) - (left.m_imaginary * right.m_imaginary)
      local result_imaginarypart = (left.m_imaginary * right.m_real) + (left.m_real * right.m_imaginary)
      return class(result_realpart, result_imaginarypart)
    end
  end
  Divide = function (left, right)
    if type(left) == "number" then
      -- Division : Smith's formula.
      local a = left
      local c = right.m_real
      local d = right.m_imaginary

      -- Computing c * c + d * d will overflow even in cases where the actual result of the division does not overflow.
      if math.Abs(d) < math.Abs(c) then
        local doc = d / c
        return class(a / (c + d * doc), (- a * doc) / (c + d * doc))
      else
        local cod = c / d
        return class(a * cod / (d + c * cod), - a / (d + c * cod))
      end
    elseif type(right) == "number" then
      -- IEEE prohibit optimizations which are value changing
      -- so we make sure that behaviour for the simplified version exactly match
      -- full version.
      if right == 0 then
        return class(System.Double.NaN, System.Double.NaN)
      end

      if not System.Double.IsFinite(left.m_real) then
        if not System.Double.IsFinite(left.m_imaginary) then
          return class(System.Double.NaN, System.Double.NaN)
        end

        return class(left.m_real / right, System.Double.NaN)
      end

      if not System.Double.IsFinite(left.m_imaginary) then
        return class(System.Double.NaN, left.m_imaginary / right)
      end

      -- Here the actual optimized version of code.
      return class(left.m_real / right, left.m_imaginary / right)
    else
      -- Division : Smith's formula.
      local a = left.m_real
      local b = left.m_imaginary
      local c = right.m_real
      local d = right.m_imaginary

      -- Computing c * c + d * d will overflow even in cases where the actual result of the division does not overflow.
      if math.Abs(d) < math.Abs(c) then
        local doc = d / c
        return class((a + b * doc) / (c + d * doc), (b - a * doc) / (c + d * doc))
      else
        local cod = c / d
        return class((b + a * cod) / (d + c * cod), (- a + b * cod) / (d + c * cod))
      end
    end
  end
  Abs = function (value)
    return Hypot(value.m_real, value.m_imaginary)
  end
  Hypot = function (a, b)
    -- Using
    --   sqrt(a^2 + b^2) = |a| * sqrt(1 + (b/a)^2)
    -- we can factor out the larger component to dodge overflow even when a * a would overflow.

    a = math.Abs(a)
    b = math.Abs(b)

    local small, large
    if a < b then
      small = a
      large = b
    else
      small = b
      large = a
    end

    if small == 0.0 then
      return large
    elseif System.Double.IsPositiveInfinity(large) and not System.Double.IsNaN(small) then
      -- The NaN test is necessary so we don't return +inf when small=NaN and large=+inf.
      -- NaN in any other place returns NaN without any special handling.
      return (System.Double.PositiveInfinity)
    else
      local ratio = small / large
      return (large * math.Sqrt(1.0 + ratio * ratio))
    end
  end
  Log1P = function (x)
    -- Compute log(1 + x) without loss of accuracy when x is small.

    -- Our only use case so far is for positive values, so this isn't coded to handle negative values.
    assert((x >= 0.0) or System.Double.IsNaN(x))

    local xp1 = 1.0 + x
    if xp1 == 1.0 then
      return x
    elseif x < 0.75 then
      -- This is accurate to within 5 ulp with any floating-point system that uses a guard digit,
      -- as proven in Theorem 4 of "What Every Computer Scientist Should Know About Floating-Point
      -- Arithmetic" (https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html)
      return x * math.Log(xp1) / (xp1 - 1.0)
    else
      return math.Log(xp1)
    end
  end
  Conjugate = function (value)
    -- Conjugate of a Complex number: the conjugate of x+i*y is x-i*y
    return class(value.m_real, - value.m_imaginary)
  end
  Reciprocal = function (value)
    -- Reciprocal of a Complex number : the reciprocal of x+i*y is 1/(x+i*y)
    if value.m_real == 0 and value.m_imaginary == 0 then
      return Zero
    end
    return One / value
  end
  op_Equality = function (left, right)
    return left.m_real == right.m_real and left.m_imaginary == right.m_imaginary
  end
  EqualsObj = function (this, obj)
    if not (System.is(obj, class)) then
      return false
    end
    return Equals(this, System.cast(class, obj))
  end
  Equals = function (this, value)
    return this.m_real:Equals(value.m_real) and this.m_imaginary:Equals(value.m_imaginary)
  end
  GetHashCode = function (this)
    local n1 = 99999997
    local realHash = System.mod(this.m_real:GetHashCode(), n1)
    local imaginaryHash = this.m_imaginary:GetHashCode()
    local finalHash = System.xor(realHash, imaginaryHash)
    return finalHash
  end
  ToString = function (this)
    return ("(%s, %s)"):format(this.m_real, this.m_imaginary)
  end
  Sin = function (value)
    -- We need both sinh and cosh of imaginary part. To avoid multiple calls to Math.Exp with the same value,
    -- we compute them both here from a single call to Math.Exp.
    local p = math.Exp(value.m_imaginary)
    local q = 1.0 / p
    local sinh = (p - q) * 0.5
    local cosh = (p + q) * 0.5
    return class(math.Sin(value.m_real) * cosh, math.Cos(value.m_real) * sinh)
    -- There is a known limitation with this algorithm: inputs that cause sinh and cosh to overflow, but for
    -- which sin or cos are small enough that sin * cosh or cos * sinh are still representable, nonetheless
    -- produce overflow. For example, Sin((0.01, 711.0)) should produce (~3.0E306, PositiveInfinity), but
    -- instead produces (PositiveInfinity, PositiveInfinity). 
  end
  Sinh = function (value)
    -- Use sinh(z) = -i sin(iz) to compute via sin(z).
    local sin = Sin(class(- value.m_imaginary, value.m_real))
    return class(sin.m_imaginary, - sin.m_real)
  end
  Asin = function (value)
    local b, bPrime, v
    b, bPrime, v = Asin_Internal(math.Abs(getReal(value)), math.Abs(getImaginary(value)))

    local u
    if bPrime < 0.0 then
      u = math.Asin(b)
    else
      u = math.Atan(bPrime)
    end

    if getReal(value) < 0.0 then
      u = - u
    end
    if getImaginary(value) < 0.0 then
      v = - v
    end

    return class(u, v)
  end
  Cos = function (value)
    local p = math.Exp(value.m_imaginary)
    local q = 1.0 / p
    local sinh = (p - q) * 0.5
    local cosh = (p + q) * 0.5
    return class(math.Cos(value.m_real) * cosh, - math.Sin(value.m_real) * sinh)
  end
  Cosh = function (value)
    -- Use cosh(z) = cos(iz) to compute via cos(z).
    return Cos(class(- value.m_imaginary, value.m_real))
  end
  Acos = function (value)
    local b, bPrime, v
    b, bPrime, v = Asin_Internal(math.Abs(getReal(value)), math.Abs(getImaginary(value)))

    local u
    if bPrime < 0.0 then
      u = math.Acos(b)
    else
      u = math.Atan(1.0 / bPrime)
    end

    if getReal(value) < 0.0 then
      u = 3.14159265358979 --[[Math.PI]] - u
    end
    if getImaginary(value) > 0.0 then
      v = - v
    end

    return class(u, v)
  end
  Tan = function (value)
    -- tan z = sin z / cos z, but to avoid unnecessary repeated trig computations, use
    --   tan z = (sin(2x) + i sinh(2y)) / (cos(2x) + cosh(2y))
    -- (see Abramowitz & Stegun 4.3.57 or derive by hand), and compute trig functions here.

    -- This approach does not work for |y| > ~355, because sinh(2y) and cosh(2y) overflow,
    -- even though their ratio does not. In that case, divide through by cosh to get:
    --   tan z = (sin(2x) / cosh(2y) + i \tanh(2y)) / (1 + cos(2x) / cosh(2y))
    -- which correctly computes the (tiny) real part and the (normal-sized) imaginary part.

    local x2 = 2.0 * value.m_real
    local y2 = 2.0 * value.m_imaginary
    local p = math.Exp(y2)
    local q = 1.0 / p
    local cosh = (p + q) * 0.5
    if math.Abs(value.m_imaginary) <= 4.0 then
      local sinh = (p - q) * 0.5
      local D = math.Cos(x2) + cosh
      return class(math.Sin(x2) / D, sinh / D)
    else
      local D = 1.0 + math.Cos(x2) / cosh
      return class(math.Sin(x2) / cosh / D, math.Tanh(y2) / D)
    end
  end
  Tanh = function (value)
    -- Use tanh(z) = -i tan(iz) to compute via tan(z).
    local tan = Tan(class(- value.m_imaginary, value.m_real))
    return class(tan.m_imaginary, - tan.m_real)
  end
  Atan = function (value)
    local two = class(2.0, 0.0)
    return (ImaginaryOne / two) * (Log(One - (ImaginaryOne * value)) - Log(One + ImaginaryOne * value))
  end
  Asin_Internal = function (x, y, b, bPrime, v)
    -- This method for the inverse complex sine (and cosine) is described in Hull, Fairgrieve,
    -- and Tang, "Implementing the Complex Arcsine and Arccosine Functions Using Exception Handling",
    -- ACM Transactions on Mathematical Software (1997)
    -- (https://www.researchgate.net/profile/Ping_Tang3/publication/220493330_Implementing_the_Complex_Arcsine_and_Arccosine_Functions_Using_Exception_Handling/links/55b244b208ae9289a085245d.pdf)

    -- First, the basics: start with sin(w) = (e^{iw} - e^{-iw}) / (2i) = z. Here z is the input
    -- and w is the output. To solve for w, define t = e^{i w} and multiply through by t to
    -- get the quadratic equation t^2 - 2 i z t - 1 = 0. The solution is t = i z + sqrt(1 - z^2), so
    --   w = arcsin(z) = - i log( i z + sqrt(1 - z^2) )
    -- Decompose z = x + i y, multiply out i z + sqrt(1 - z^2), use log(s) = |s| + i arg(s), and do a
    -- bunch of algebra to get the components of w = arcsin(z) = u + i v
    --   u = arcsin(beta)  v = sign(y) log(alpha + sqrt(alpha^2 - 1))
    -- where
    --   alpha = (rho + sigma) / 2      beta = (rho - sigma) / 2
    --   rho = sqrt((x + 1)^2 + y^2)    sigma = sqrt((x - 1)^2 + y^2)
    -- These formulas appear in DLMF section 4.23. (http://dlmf.nist.gov/4.23), along with the analogous
    --   arccos(w) = arccos(beta) - i sign(y) log(alpha + sqrt(alpha^2 - 1))
    -- So alpha and beta together give us arcsin(w) and arccos(w).

    -- As written, alpha is not susceptible to cancelation errors, but beta is. To avoid cancelation, note
    --   beta = (rho^2 - sigma^2) / (rho + sigma) / 2 = (2 x) / (rho + sigma) = x / alpha
    -- which is not subject to cancelation. Note alpha >= 1 and |beta| <= 1.

    -- For alpha ~ 1, the argument of the log is near unity, so we compute (alpha - 1) instead,
    -- write the argument as 1 + (alpha - 1) + sqrt((alpha - 1)(alpha + 1)), and use the log1p function
    -- to compute the log without loss of accuracy.
    -- For beta ~ 1, arccos does not accurately resolve small angles, so we compute the tangent of the angle
    -- instead.
    -- Hull, Fairgrieve, and Tang derive formulas for (alpha - 1) and beta' = tan(u) that do not suffer
    -- from cancelation in these cases.

    -- For simplicity, we assume all positive inputs and return all positive outputs. The caller should
    -- assign signs appropriate to the desired cut conventions. We return v directly since its magnitude
    -- is the same for both arcsin and arccos. Instead of u, we usually return beta and sometimes beta'.
    -- If beta' is not computed, it is set to -1; if it is computed, it should be used instead of beta
    -- to determine u. Compute u = arcsin(beta) or u = arctan(beta') for arcsin, u = arccos(beta)
    -- or arctan(1/beta') for arccos.

    assert((x >= 0.0) or System.Double.IsNaN(x))
    assert((y >= 0.0) or System.Double.IsNaN(y))

    -- For x or y large enough to overflow alpha^2, we can simplify our formulas and avoid overflow.
    if (x > s_asinOverflowThreshold) or (y > s_asinOverflowThreshold) then
      b = - 1.0
      bPrime = x / y

      local small, big
      if x < y then
        small = x
        big = y
      else
        small = y
        big = x
      end
      local ratio = small / big
      v = s_log2 + math.Log(big) + 0.5 * Log1P(ratio * ratio)
    else
      local r = Hypot((x + 1.0), y)
      local s = Hypot((x - 1.0), y)

      local a = (r + s) * 0.5
      b = x / a

      if b > 0.75 then
        if x <= 1.0 then
          local amx = (y * y / (r + (x + 1.0)) + (s + (1.0 - x))) * 0.5
          bPrime = x / math.Sqrt((a + x) * amx)
        else
          -- In this case, amx ~ y^2. Since we take the square root of amx, we should
          -- pull y out from under the square root so we don't lose its contribution
          -- when y^2 underflows.
          local t = (1.0 / (r + (x + 1.0)) + 1.0 / (s + (x - 1.0))) * 0.5
          bPrime = x / y / math.Sqrt((a + x) * t)
        end
      else
        bPrime = - 1.0
      end

      if a < 1.5 then
        if x < 1.0 then
          -- This is another case where our expression is proportional to y^2 and
          -- we take its square root, so again we pull out a factor of y from
          -- under the square root.
          local t = (1.0 / (r + (x + 1.0)) + 1.0 / (s + (1.0 - x))) * 0.5
          local am1 = y * y * t
          v = Log1P(am1 + y * math.Sqrt(t * (a + 1.0)))
        else
          local am1 = (y * y / (r + (x + 1.0)) + (s + (x - 1.0))) * 0.5
          v = Log1P(am1 + math.Sqrt(am1 * (a + 1.0)))
        end
      else
        -- Because of the test above, we can be sure that a * a will not overflow.
        v = math.Log(a + math.Sqrt((a - 1.0) * (a + 1.0)))
      end
    end
    return b, bPrime, v
  end
  IsFinite = function (value)
    return System.Double.IsFinite(value.m_real) and System.Double.IsFinite(value.m_imaginary)
  end
  IsInfinity = function (value)
    return System.Double.IsInfinity(value.m_real) or System.Double.IsInfinity(value.m_imaginary)
  end
  IsNaN = function (value)
    return not IsInfinity(value) and not IsFinite(value)
  end
  Log = function (value, baseValue)
    if baseValue ~= nil then
      return (Log(value) / Log(ToComplex(baseValue))) 
    end
    return class(math.Log(Abs(value)), math.Atan2(value.m_imaginary, value.m_real))
  end
  Log10 = function (value)
    local tempLog = Log(value)
    return Scale(tempLog, 0.43429448190325 --[[Complex.InverseOfLog10]])
  end
  Exp = function (value)
    local expReal = math.Exp(value.m_real)
    local cosImaginary = expReal * math.Cos(value.m_imaginary)
    local sinImaginary = expReal * math.Sin(value.m_imaginary)
    return class(cosImaginary, sinImaginary)
  end
  Sqrt = function (value)
    local m_real = value.m_real
    local m_imaginary = value.m_imaginary
    if m_imaginary == 0.0 then
      -- Handle the trivial case quickly.
      if m_real < 0.0 then
        return class(0.0, math.Sqrt(- m_real))
      else
        return class(math.Sqrt(m_real), 0.0)
      end
    else
      -- One way to compute Sqrt(z) is just to call Pow(z, 0.5), which coverts to polar coordinates
      -- (sqrt + atan), halves the phase, and reconverts to cartesian coordinates (cos + sin).
      -- Not only is this more expensive than necessary, it also fails to preserve certain expected
      -- symmetries, such as that the square root of a pure negative is a pure imaginary, and that the
      -- square root of a pure imaginary has exactly equal real and imaginary parts. This all goes
      -- back to the fact that Math.PI is not stored with infinite precision, so taking half of Math.PI
      -- does not land us on an argument with cosine exactly equal to zero.

      -- To find a fast and symmetry-respecting formula for complex square root,
      -- note x + i y = \sqrt{a + i b} implies x^2 + 2 i x y - y^2 = a + i b,
      -- so x^2 - y^2 = a and 2 x y = b. Cross-substitute and use the quadratic formula to obtain
      --   x = \sqrt{\frac{\sqrt{a^2 + b^2} + a}{2}}  y = \pm \sqrt{\frac{\sqrt{a^2 + b^2} - a}{2}}
      -- There is just one complication: depending on the sign on a, either x or y suffers from
      -- cancelation when |b| << |a|. We can get aroud this by noting that our formulas imply
      -- x^2 y^2 = b^2 / 4, so |x| |y| = |b| / 2. So after computing the one that doesn't suffer
      -- from cancelation, we can compute the other with just a division. This is basically just
      -- the right way to evaluate the quadratic formula without cancelation.

      -- All this reduces our total cost to two sqrts and a few flops, and it respects the desired
      -- symmetries. Much better than atan + cos + sin!

      -- The signs are a matter of choice of branch cut, which is traditionally taken so x > 0 and sign(y) = sign(b).

      -- If the components are too large, Hypot will overflow, even though the subsequent sqrt would
      -- make the result representable. To avoid this, we re-scale (by exact powers of 2 for accuracy)
      -- when we encounter very large components to avoid intermediate infinities.
      local rescale = false
      if (math.Abs(m_real) >= s_sqrtRescaleThreshold) or (math.Abs(m_imaginary) >= s_sqrtRescaleThreshold) then
        if System.Double.IsInfinity(m_imaginary) and not System.Double.IsNaN(m_real) then
          -- We need to handle infinite imaginary parts specially because otherwise
          -- our formulas below produce inf/inf = NaN. The NaN test is necessary
          -- so that we return NaN rather than (+inf,inf) for (NaN,inf).
          return (class(System.Double.PositiveInfinity, m_imaginary))
        else
          m_real = m_real * 0.25
          m_imaginary = m_imaginary * 0.25
          rescale = true
        end
      end

      -- This is the core of the algorithm. Everything else is special case handling.
      local x, y
      if m_real >= 0.0 then
        x = math.Sqrt((Hypot(m_real, m_imaginary) + m_real) * 0.5)
        y = m_imaginary / (2.0 * x)
      else
        y = math.Sqrt((Hypot(m_real, m_imaginary) - m_real) * 0.5)
        if m_imaginary < 0.0 then
          y = - y
        end
        x = m_imaginary / (2.0 * y)
      end

      if rescale then
        x = x * 2.0
        y = y * 2.0
      end

      return class(x, y)
    end
  end
  Pow = function (value, power)
    if power == Zero then
      return One
    end

    if value == Zero then
      return Zero
    end

    local valueReal = value.m_real
    local valueImaginary = value.m_imaginary
    local powerReal = power.m_real
    local powerImaginary = power.m_imaginary

    local rho = Abs(value)
    local theta = math.Atan2(valueImaginary, valueReal)
    local newRho = powerReal * theta + powerImaginary * math.Log(rho)

    local t = math.Pow(rho, powerReal) * math.Pow(2.71828182845905 --[[Math.E]], - powerImaginary * theta)

    return class(t * math.Cos(newRho), t * math.Sin(newRho))
  end
  Pow1 = function (value, power)
    return Pow(value, class(power, 0))
  end
  Scale = function (value, factor)
    local realResult = factor * value.m_real
    local imaginaryResuilt = factor * value.m_imaginary
    return class(realResult, imaginaryResuilt)
  end
  ToComplex = function (value)
    return class(value, 0.0)
  end
  class = {
    base = function (out, T)
      return {
        System.IEquatable_1(T),
        System.IFormattable
      }
    end,
    m_real = 0,
    m_imaginary = 0,
    getReal = getReal,
    getImaginary = getImaginary,
    getMagnitude = getMagnitude,
    getPhase = getPhase,
    FromPolarCoordinates = FromPolarCoordinates,
    Negate = Negate,
    Add = Add,
    Subtract = Subtract,
    Multiply = Multiply,
    Divide = Divide,
    Abs = Abs,
    Conjugate = Conjugate,
    Reciprocal = Reciprocal,
    EqualsObj = EqualsObj,
    Equals = Equals,
    GetHashCode = GetHashCode,
    ToString = ToString,
    Sin = Sin,
    Sinh = Sinh,
    Asin = Asin,
    Cos = Cos,
    Cosh = Cosh,
    Acos = Acos,
    Tan = Tan,
    Tanh = Tanh,
    Atan = Atan,
    IsFinite = IsFinite,
    IsInfinity = IsInfinity,
    IsNaN = IsNaN,
    Log = Log,
    Log10 = Log10,
    Exp = Exp,
    Sqrt = Sqrt,
    Pow = Pow,
    Pow1 = Pow1,
    ToComplex = ToComplex,
    static = static,
    __ctor__ = __ctor__,
    __add = Add,
    __sub = Subtract,
    __mul = Multiply,
    __div = Divide,
    __unm = Negate,
    __eq = op_Equality
  }
  return class
end)())

end

-- CoreSystemLib: Numerics/Matrix3x2.lua
do
local System = System
local SystemNumerics = System.Numerics

local tan = math.tan
local cos = math.cos
local sin = math.sin
local abs = math.abs

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Matrix3x2 = {}

Matrix3x2.__ctor__ = function(this, m11, m12, m21, m22, m31, m32)
    this.M11 = m11 or 0
    this.M12 = m12 or 0
    this.M21 = m21 or 0
    this.M22 = m22 or 0
    this.M31 = m31 or 0
    this.M32 = m32 or 0
    local mt = getmetatable(this)
    mt.__unm = Matrix3x2.op_UnaryNegation
    setmetatable(this, mt)
end

Matrix3x2.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T) }
end

Matrix3x2.getIdentity = function ()
    return new(Matrix3x2, 1, 0, 0, 1, 0, 0)
end

Matrix3x2.getIsIdentity = function (this)
    return this.M11 == 1 and this.M22 == 1 and this.M12 == 0 and this.M21 == 0 and this.M31 == 0 and this.M32 == 0
end

Matrix3x2.getTranslation = function (this)
    return SystemNumerics.Vector2(this.M31, this.M32)
end

Matrix3x2.setTranslation = function (this, value)
    this.M31 = value.X
    this.M32 = value.Y
end

Matrix3x2.CreateTranslation = function (position, yPosition)
    if yPosition == nil then
        -- Vector2
        local result = new(Matrix3x2)

        result.M11 = 1.0
        result.M12 = 0.0
        result.M21 = 0.0
        result.M22 = 1.0

        result.M31 = position.X
        result.M32 = position.Y

        return result:__clone__()
    else
        -- singles
        local result = new(Matrix3x2)

        result.M11 = 1.0
        result.M12 = 0.0
        result.M21 = 0.0
        result.M22 = 1.0
  
        result.M31 = position
        result.M32 = yPosition
  
        return result:__clone__()
    end
end

Matrix3x2.CreateScale = function(val1, val2, val3)
    if val3 == nil then
        if val2 == nil then
            if val1.X == nil then
                -- CreateScale(Single)
                local result = new(Matrix3x2)

                result.M11 = val1
                result.M12 = 0.0
                result.M21 = 0.0
                result.M22 = val1
                result.M31 = 0.0
                result.M32 = 0.0
          
                return result:__clone__()
            else
                -- CreateScale(Vector2)
                local result = new(Matrix3x2)

                result.M11 = val1.X
                result.M12 = 0.0
                result.M21 = 0.0
                result.M22 = val1.Y
                result.M31 = 0.0
                result.M32 = 0.0

                return result:__clone__()
            end
        else
            if val2.X == nil then
                -- CreateScale(Single, Single)
                local result = new(Matrix3x2)

                result.M11 = val1
                result.M12 = 0.0
                result.M21 = 0.0
                result.M22 = val2
                result.M31 = 0.0
                result.M32 = 0.0

                return result:__clone__()
            else
                if val1.X == nil then
                    -- CreateScale(Single, Vector2)
                    local result = new(Matrix3x2)

                    local tx = val2.X * (1 - val1)
                    local ty = val2.Y * (1 - val1)

                    result.M11 = val1
                    result.M12 = 0.0
                    result.M21 = 0.0
                    result.M22 = val1
                    result.M31 = tx
                    result.M32 = ty

                    return result:__clone__()
                else
                    -- CreateScale(Vector2, Vector2)
                    local result = new(Matrix3x2)

                    local tx = val2.X * (1 - val1.X)
                    local ty = val2.Y * (1 - val1.Y)

                    result.M11 = val1.X
                    result.M12 = 0.0
                    result.M21 = 0.0
                    result.M22 = val1.Y
                    result.M31 = tx
                    result.M32 = ty

                    return result:__clone__()
                end
            end
        end
    else
        -- CreateScale(Single, Single, Vector2)
        local result = new(Matrix3x2)

        local tx = val3.X * (1 - val1)
        local ty = val3.Y * (1 - val2)

        result.M11 = val1
        result.M12 = 0.0
        result.M21 = 0.0
        result.M22 = val2
        result.M31 = tx
        result.M32 = ty

        return result:__clone__()
    end
end

Matrix3x2.CreateSkew = function (radiansX, radiansY, centerPoint)
    if centerPoint == nil then

        local result = new(Matrix3x2)

        local xTan = System.ToSingle(tan(radiansX))
        local yTan = System.ToSingle(tan(radiansY))

        result.M11 = 1.0
        result.M12 = yTan
        result.M21 = xTan
        result.M22 = 1.0
        result.M31 = 0.0
        result.M32 = 0.0

        return result:__clone__()
    else
        local result = new(Matrix3x2)

        local xTan = System.ToSingle(tan(radiansX))
        local yTan = System.ToSingle(tan(radiansY))

        local tx = - centerPoint.Y * xTan
        local ty = - centerPoint.X * yTan

        result.M11 = 1.0
        result.M12 = yTan
        result.M21 = xTan
        result.M22 = 1.0
        result.M31 = tx
        result.M32 = ty

        return result:__clone__()
    end
end

Matrix3x2.CreateRotation = function (radians, centerPoint)
    if centerPoint == nil then

        local result = new(Matrix3x2)

        radians = System.ToSingle(math.IEEERemainder(radians, 6.28318530717959 --[[Math.PI * 2]]))

        local c, s

        -- 0.1% of a degree

        if radians > - 1.745329E-05 --[[epsilon]] and radians < 1.745329E-05 --[[epsilon]] then
            -- Exact case for zero rotation.
            c = 1
            s = 0
        elseif radians > 1.57077887350062 --[[Math.PI / 2 - epsilon]] and radians < 1.57081378008917 --[[Math.PI / 2 + epsilon]] then
            -- Exact case for 90 degree rotation.
            c = 0
            s = 1
        elseif radians < -3.14157520029552 --[[-Math.PI + epsilon]] or radians > 3.14157520029552 --[[Math.PI - epsilon]] then
            -- Exact case for 180 degree rotation.
            c = - 1
            s = 0
        elseif radians > -1.57081378008917 --[[-Math.PI / 2 - epsilon]] and radians < -1.57077887350062 --[[-Math.PI / 2 + epsilon]] then
            -- Exact case for 270 degree rotation.
            c = 0
            s = - 1
        else
            -- Arbitrary rotation.
            c = System.ToSingle(cos(radians))
            s = System.ToSingle(sin(radians))
        end

        -- [  c  s ]
        -- [ -s  c ]
        -- [  0  0 ]
        result.M11 = c
        result.M12 = s
        result.M21 = - s
        result.M22 = c
        result.M31 = 0.0
        result.M32 = 0.0

        return result:__clone__()
    else
        local result = new(Matrix3x2)

        radians = System.ToSingle(math.IEEERemainder(radians, 6.28318530717959 --[[Math.PI * 2]]))
  
        local c, s
  
        -- 0.1% of a degree
  
        if radians > - 1.745329E-05 --[[epsilon]] and radians < 1.745329E-05 --[[epsilon]] then
          -- Exact case for zero rotation.
          c = 1
          s = 0
        elseif radians > 1.57077887350062 --[[Math.PI / 2 - epsilon]] and radians < 1.57081378008917 --[[Math.PI / 2 + epsilon]] then
          -- Exact case for 90 degree rotation.
          c = 0
          s = 1
        elseif radians < -3.14157520029552 --[[-Math.PI + epsilon]] or radians > 3.14157520029552 --[[Math.PI - epsilon]] then
          -- Exact case for 180 degree rotation.
          c = - 1
          s = 0
        elseif radians > -1.57081378008917 --[[-Math.PI / 2 - epsilon]] and radians < -1.57077887350062 --[[-Math.PI / 2 + epsilon]] then
          -- Exact case for 270 degree rotation.
          c = 0
          s = - 1
        else
          -- Arbitrary rotation.
          c = System.ToSingle(cos(radians))
          s = System.ToSingle(sin(radians))
        end
  
        local x = centerPoint.X * (1 - c) + centerPoint.Y * s
        local y = centerPoint.Y * (1 - c) - centerPoint.X * s
  
        -- [  c  s ]
        -- [ -s  c ]
        -- [  x  y ]
        result.M11 = c
        result.M12 = s
        result.M21 = - s
        result.M22 = c
        result.M31 = x
        result.M32 = y
  
        return result:__clone__()
    end
end

Matrix3x2.GetDeterminant = function (this)
    -- There isn't actually any such thing as a determinant for a non-square matrix,
    -- but this 3x2 type is really just an optimization of a 3x3 where we happen to
    -- know the rightmost column is always (0, 0, 1). So we expand to 3x3 format:
    --
    --  [ M11, M12, 0 ]
    --  [ M21, M22, 0 ]
    --  [ M31, M32, 1 ]
    --
    -- Sum the diagonal products:
    --  (M11 * M22 * 1) + (M12 * 0 * M31) + (0 * M21 * M32)
    --
    -- Subtract the opposite diagonal products:
    --  (M31 * M22 * 0) + (M32 * 0 * M11) + (1 * M21 * M12)
    --
    -- Collapse out the constants and oh look, this is just a 2x2 determinant!

    return (this.M11 * this.M22) - (this.M21 * this.M12)
end

Matrix3x2.Invert = function (matrix, result)
    local det = (matrix.M11 * matrix.M22) - (matrix.M21 * matrix.M12)

    if result == nil then
        result = new(Matrix3x2)
    end

    if abs(det) < 1.401298E-45 --[[Single.Epsilon]] then
      result = new(Matrix3x2, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN)
      return false, result
    end

    local invDet = 1.0 / det

    result.M11 = matrix.M22 * invDet
    result.M12 = - matrix.M12 * invDet
    result.M21 = - matrix.M21 * invDet
    result.M22 = matrix.M11 * invDet
    result.M31 = (matrix.M21 * matrix.M32 - matrix.M31 * matrix.M22) * invDet
    result.M32 = (matrix.M31 * matrix.M12 - matrix.M11 * matrix.M32) * invDet

    return true, result
end

Matrix3x2.Lerp = function (matrix1, matrix2, amount)
    local result = new(Matrix3x2)

    -- First row
    result.M11 = matrix1.M11 + (matrix2.M11 - matrix1.M11) * amount
    result.M12 = matrix1.M12 + (matrix2.M12 - matrix1.M12) * amount

    -- Second row
    result.M21 = matrix1.M21 + (matrix2.M21 - matrix1.M21) * amount
    result.M22 = matrix1.M22 + (matrix2.M22 - matrix1.M22) * amount

    -- Third row
    result.M31 = matrix1.M31 + (matrix2.M31 - matrix1.M31) * amount
    result.M32 = matrix1.M32 + (matrix2.M32 - matrix1.M32) * amount

    return result:__clone__()
end

Matrix3x2.Negate = function (value)
    local result = new(Matrix3x2)

    result.M11 = - value.M11
    result.M12 = - value.M12
    result.M21 = - value.M21
    result.M22 = - value.M22
    result.M31 = - value.M31
    result.M32 = - value.M32

    return result:__clone__()
end

Matrix3x2.Add = function (value1, value2)
    local result = new(Matrix3x2)

    result.M11 = value1.M11 + value2.M11
    result.M12 = value1.M12 + value2.M12
    result.M21 = value1.M21 + value2.M21
    result.M22 = value1.M22 + value2.M22
    result.M31 = value1.M31 + value2.M31
    result.M32 = value1.M32 + value2.M32

    return result:__clone__()
end

Matrix3x2.Subtract = function (value1, value2)
    local result = new(Matrix3x2)

    result.M11 = value1.M11 - value2.M11
    result.M12 = value1.M12 - value2.M12
    result.M21 = value1.M21 - value2.M21
    result.M22 = value1.M22 - value2.M22
    result.M31 = value1.M31 - value2.M31
    result.M32 = value1.M32 - value2.M32

    return result:__clone__()
end

Matrix3x2.Multiply = function (value1, value2)
    if value2.M11 == nil then
        -- scalar
        local result = new(Matrix3x2)

        result.M11 = value1.M11 * value2
        result.M12 = value1.M12 * value2
        result.M21 = value1.M21 * value2
        result.M22 = value1.M22 * value2
        result.M31 = value1.M31 * value2
        result.M32 = value1.M32 * value2

        return result:__clone__()
    else
        -- matrix
        local result = new(Matrix3x2)

        -- First row
        result.M11 = value1.M11 * value2.M11 + value1.M12 * value2.M21
        result.M12 = value1.M11 * value2.M12 + value1.M12 * value2.M22

        -- Second row
        result.M21 = value1.M21 * value2.M11 + value1.M22 * value2.M21
        result.M22 = value1.M21 * value2.M12 + value1.M22 * value2.M22

        -- Third row
        result.M31 = value1.M31 * value2.M11 + value1.M32 * value2.M21 + value2.M31
        result.M32 = value1.M31 * value2.M12 + value1.M32 * value2.M22 + value2.M32

        return result:__clone__()
    end
end

Matrix3x2.op_UnaryNegation = function (value)
    local m = new(Matrix3x2)

    m.M11 = - value.M11
    m.M12 = - value.M12
    m.M21 = - value.M21
    m.M22 = - value.M22
    m.M31 = - value.M31
    m.M32 = - value.M32

    return m:__clone__()
end

Matrix3x2.op_Addition = function (value1, value2)
    local m = new(Matrix3x2)

    m.M11 = value1.M11 + value2.M11
    m.M12 = value1.M12 + value2.M12
    m.M21 = value1.M21 + value2.M21
    m.M22 = value1.M22 + value2.M22
    m.M31 = value1.M31 + value2.M31
    m.M32 = value1.M32 + value2.M32

    return m:__clone__()
end

Matrix3x2.op_Subtraction = function (value1, value2)
    local m = new(Matrix3x2)

    m.M11 = value1.M11 - value2.M11
    m.M12 = value1.M12 - value2.M12
    m.M21 = value1.M21 - value2.M21
    m.M22 = value1.M22 - value2.M22
    m.M31 = value1.M31 - value2.M31
    m.M32 = value1.M32 - value2.M32

    return m:__clone__()
end

Matrix3x2.op_Multiply = function (value1, value2)
    if value2.M11 == nil then
        -- scalar
        local result = new(Matrix3x2)

        result.M11 = value1.M11 * value2
        result.M12 = value1.M12 * value2
        result.M21 = value1.M21 * value2
        result.M22 = value1.M22 * value2
        result.M31 = value1.M31 * value2
        result.M32 = value1.M32 * value2

        return result:__clone__()
    else
        -- matrix
        local result = new(Matrix3x2)

        -- First row
        result.M11 = value1.M11 * value2.M11 + value1.M12 * value2.M21
        result.M12 = value1.M11 * value2.M12 + value1.M12 * value2.M22

        -- Second row
        result.M21 = value1.M21 * value2.M11 + value1.M22 * value2.M21
        result.M22 = value1.M21 * value2.M12 + value1.M22 * value2.M22

        -- Third row
        result.M31 = value1.M31 * value2.M11 + value1.M32 * value2.M21 + value2.M31
        result.M32 = value1.M31 * value2.M12 + value1.M32 * value2.M22 + value2.M32

        return result:__clone__()
    end
end

Matrix3x2.op_Equality = function (value1, value2)
    return (value1.M11 == value2.M11 and value1.M22 == value2.M22 and value1.M12 == value2.M12 and value1.M21 == value2.M21 and value1.M31 == value2.M31 and value1.M32 == value2.M32)
end

Matrix3x2.op_Inequality = function (value1, value2)
    return (value1.M11 ~= value2.M11 or value1.M12 ~= value2.M12 or value1.M21 ~= value2.M21 or value1.M22 ~= value2.M22 or value1.M31 ~= value2.M31 or value1.M32 ~= value2.M32)
end

Matrix3x2.Equals = function (this, other)
    if System.is(other, Matrix3x2) then
        return (this.M11 == other.M11 and this.M22 == other.M22 and this.M12 == other.M12 and this.M21 == other.M21 and this.M31 == other.M31 and this.M32 == other.M32)
    end
    return false
end

Matrix3x2.ToString = function (this)
    local sb = System.StringBuilder()
    sb:Append("{ ")
    sb:Append("{")
    sb:Append("M11: ")
    sb:Append(this.M11:ToString())
    sb:Append(" M12: ")
    sb:Append(this.M12:ToString())
    sb:Append("} ")
    sb:Append("{")
    sb:Append("M21: ")
    sb:Append(this.M21:ToString())
    sb:Append(" M22: ")
    sb:Append(this.M22:ToString())
    sb:Append("} ")
    sb:Append("{")
    sb:Append("M31: ")
    sb:Append(this.M31:ToString())
    sb:Append(" M32: ")
    sb:Append(this.M32:ToString())
    sb:Append("} ")
    sb:Append("}")
    return sb:ToString()
end

Matrix3x2.GetHashCode = function (this)
    return this.M11:GetHashCode() + this.M12:GetHashCode() + this.M21:GetHashCode() + this.M22:GetHashCode() + this.M31:GetHashCode() + this.M32:GetHashCode()
end

System.defStc("System.Numerics.Matrix3x2", Matrix3x2)
end

-- CoreSystemLib: Numerics/Matrix4x4.lua
do
local System = System
local SystemNumerics = System.Numerics

local sqrt = math.sqrt
local abs = math.abs
local tan = math.tan
local cos = math.cos
local sin = math.sin

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Matrix4x4 = {}

Matrix4x4.__ctor__ = function (this, m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44)
    if m11 == nil then
        this.M11 = 0
        this.M12 = 0
        this.M13 = 0
        this.M14 = 0

        this.M21 = 0
        this.M22 = 0
        this.M23 = 0
        this.M24 = 0

        this.M31 = 0
        this.M32 = 0
        this.M33 = 0
        this.M34 = 0

        this.M41 = 0
        this.M42 = 0
        this.M43 = 0
        this.M44 = 0
    elseif m11.M11 == nil then
        -- from singles
        this.M11 = m11 or 0
        this.M12 = m12 or 0
        this.M13 = m13 or 0
        this.M14 = m14 or 0

        this.M21 = m21 or 0
        this.M22 = m22 or 0
        this.M23 = m23 or 0
        this.M24 = m24 or 0

        this.M31 = m31 or 0
        this.M32 = m32 or 0
        this.M33 = m33 or 0
        this.M34 = m34 or 0

        this.M41 = m41 or 0
        this.M42 = m42 or 0
        this.M43 = m43 or 0
        this.M44 = m44 or 0
    else
        -- from matrix
        this.M11 = m11.M11
        this.M12 = m11.M12
        this.M13 = 0
        this.M14 = 0
        this.M21 = m11.M21
        this.M22 = m11.M22
        this.M23 = 0
        this.M24 = 0
        this.M31 = 0
        this.M32 = 0
        this.M33 = 1
        this.M34 = 0
        this.M41 = m11.M31
        this.M42 = m11.M32
        this.M43 = 0
        this.M44 = 1
    end 
    local mt = getmetatable(this)
    mt.__unm = Matrix4x4.op_UnaryNegation
    setmetatable(this, mt)   
  end

Matrix4x4.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T) }
end

Matrix4x4.getIdentity = function ()
    return new(Matrix4x4, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
end

Matrix4x4.getIsIdentity = function (this)
    return this.M11 == 1 and this.M22 == 1 and this.M33 == 1 and this.M44 == 1 and this.M12 == 0 and this.M13 == 0 and this.M14 == 0 and this.M21 == 0 and this.M23 == 0 and this.M24 == 0 and this.M31 == 0 and this.M32 == 0 and this.M34 == 0 and this.M41 == 0 and this.M42 == 0 and this.M43 == 0
end

Matrix4x4.getTranslation = function (this)
    return SystemNumerics.Vector3(this.M41, this.M42, this.M43)
end
  
Matrix4x4.setTranslation = function (this, value)
    this.M41 = value.X
    this.M42 = value.Y
    this.M43 = value.Z
end

Matrix4x4.CreateBillboard = function (objectPosition, cameraPosition, cameraUpVector, cameraForwardVector)

    local zaxis = SystemNumerics.Vector3(objectPosition.X - cameraPosition.X, objectPosition.Y - cameraPosition.Y, objectPosition.Z - cameraPosition.Z)

    local norm = zaxis:LengthSquared()

    if norm < 0.0001 --[[epsilon]] then
      zaxis = - cameraForwardVector
    else
      zaxis = SystemNumerics.Vector3.Multiply(zaxis, 1.0 / System.ToSingle(sqrt(norm)))
    end

    local xaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(cameraUpVector, zaxis))

    local yaxis = SystemNumerics.Vector3.Cross(zaxis, xaxis)

    local result = new(Matrix4x4)

    result.M11 = xaxis.X
    result.M12 = xaxis.Y
    result.M13 = xaxis.Z
    result.M14 = 0.0
    result.M21 = yaxis.X
    result.M22 = yaxis.Y
    result.M23 = yaxis.Z
    result.M24 = 0.0
    result.M31 = zaxis.X
    result.M32 = zaxis.Y
    result.M33 = zaxis.Z
    result.M34 = 0.0

    result.M41 = objectPosition.X
    result.M42 = objectPosition.Y
    result.M43 = objectPosition.Z
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateConstrainedBillboard = function (objectPosition, cameraPosition, rotateAxis, cameraForwardVector, objectForwardVector)
    -- 0.1 degrees

    -- Treat the case when object and camera positions are too close.
    local faceDir = SystemNumerics.Vector3(objectPosition.X - cameraPosition.X, objectPosition.Y - cameraPosition.Y, objectPosition.Z - cameraPosition.Z)

    local norm = faceDir:LengthSquared()

    if norm < 0.0001 --[[epsilon]] then
      faceDir = - cameraForwardVector
    else
      faceDir = SystemNumerics.Vector3.Multiply(faceDir, (1.0 / System.ToSingle(sqrt(norm))))
    end

    local yaxis = rotateAxis:__clone__()
    local xaxis
    local zaxis

    -- Treat the case when angle between faceDir and rotateAxis is too close to 0.
    local dot = SystemNumerics.Vector3.Dot(rotateAxis, faceDir)

    if abs(dot) > 0.9982547 --[[minAngle]] then
      zaxis = objectForwardVector:__clone__()

      -- Make sure passed values are useful for compute.
      dot = SystemNumerics.Vector3.Dot(rotateAxis, zaxis)

      if abs(dot) > 0.9982547 --[[minAngle]] then
        zaxis = (abs(rotateAxis.Z) > 0.9982547 --[[minAngle]]) and SystemNumerics.Vector3(1, 0, 0) or SystemNumerics.Vector3(0, 0, - 1)
      end

      xaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(rotateAxis, zaxis))
      zaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(xaxis, rotateAxis))
    else
      xaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(rotateAxis, faceDir))
      zaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(xaxis, yaxis))
    end

    local result = new(Matrix4x4)

    result.M11 = xaxis.X
    result.M12 = xaxis.Y
    result.M13 = xaxis.Z
    result.M14 = 0.0
    result.M21 = yaxis.X
    result.M22 = yaxis.Y
    result.M23 = yaxis.Z
    result.M24 = 0.0
    result.M31 = zaxis.X
    result.M32 = zaxis.Y
    result.M33 = zaxis.Z
    result.M34 = 0.0

    result.M41 = objectPosition.X
    result.M42 = objectPosition.Y
    result.M43 = objectPosition.Z
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateTranslation = function (position, yPosition, zPosition)
    local result = new(Matrix4x4)

    result.M11 = 1.0
    result.M12 = 0.0
    result.M13 = 0.0
    result.M14 = 0.0
    result.M21 = 0.0
    result.M22 = 1.0
    result.M23 = 0.0
    result.M24 = 0.0
    result.M31 = 0.0
    result.M32 = 0.0
    result.M33 = 1.0
    result.M34 = 0.0

    if yPosition ~= nil then
        position = SystemNumerics.Vector3(position, yPosition, zPosition)
    end

    result.M41 = position.X
    result.M42 = position.Y
    result.M43 = position.Z
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateScale = function(val1, val2, val3, val4)
    if val4 == nil then
        if val3 == nil then
            if val2 == nil then
                if val1.X == nil then
                    -- CreateScale(Single)
                    local result = new(Matrix4x4)

                    result.M11 = val1
                    result.M12 = 0.0
                    result.M13 = 0.0
                    result.M14 = 0.0
                    result.M21 = 0.0
                    result.M22 = val1
                    result.M23 = 0.0
                    result.M24 = 0.0
                    result.M31 = 0.0
                    result.M32 = 0.0
                    result.M33 = val1
                    result.M34 = 0.0
                    result.M41 = 0.0
                    result.M42 = 0.0
                    result.M43 = 0.0
                    result.M44 = 1.0

                    return result:__clone__()
                else
                    -- CreateScale(Vector3)
                    local result = new(Matrix4x4)

                    result.M11 = val1.X
                    result.M12 = 0.0
                    result.M13 = 0.0
                    result.M14 = 0.0
                    result.M21 = 0.0
                    result.M22 = val1.Y
                    result.M23 = 0.0
                    result.M24 = 0.0
                    result.M31 = 0.0
                    result.M32 = 0.0
                    result.M33 = val1.Z
                    result.M34 = 0.0
                    result.M41 = 0.0
                    result.M42 = 0.0
                    result.M43 = 0.0
                    result.M44 = 1.0

                    return result:__clone__()
                end
            else
                if val1.X == nil then
                    -- CreateScale(Single, Vector3)
                    local result = new(Matrix4x4)

                    local tx = val2.X * (1 - val1)
                    local ty = val2.Y * (1 - val1)
                    local tz = val2.Z * (1 - val1)

                    result.M11 = val1
                    result.M12 = 0.0
                    result.M13 = 0.0
                    result.M14 = 0.0
                    result.M21 = 0.0
                    result.M22 = val1
                    result.M23 = 0.0
                    result.M24 = 0.0
                    result.M31 = 0.0
                    result.M32 = 0.0
                    result.M33 = val1
                    result.M34 = 0.0
                    result.M41 = tx
                    result.M42 = ty
                    result.M43 = tz
                    result.M44 = 1.0

                    return result:__clone__()
                else
                    -- CreateScale(Vector3, Vector3)
                    local result = new(Matrix4x4)

                    local tx = val2.X * (1 - val1.X)
                    local ty = val2.Y * (1 - val1.Y)
                    local tz = val2.Z * (1 - val1.Z)

                    result.M11 = val1.X
                    result.M12 = 0.0
                    result.M13 = 0.0
                    result.M14 = 0.0
                    result.M21 = 0.0
                    result.M22 = val1.Y
                    result.M23 = 0.0
                    result.M24 = 0.0
                    result.M31 = 0.0
                    result.M32 = 0.0
                    result.M33 = val1.Z
                    result.M34 = 0.0
                    result.M41 = tx
                    result.M42 = ty
                    result.M43 = tz
                    result.M44 = 1.0

                    return result:__clone__()
                end
            end
        else
            -- CreateScale(Single, Single, Single)
            local result = new(Matrix4x4)

            result.M11 = val1
            result.M12 = 0.0
            result.M13 = 0.0
            result.M14 = 0.0
            result.M21 = 0.0
            result.M22 = val2
            result.M23 = 0.0
            result.M24 = 0.0
            result.M31 = 0.0
            result.M32 = 0.0
            result.M33 = val3
            result.M34 = 0.0
            result.M41 = 0.0
            result.M42 = 0.0
            result.M43 = 0.0
            result.M44 = 1.0

            return result:__clone__()
        end
    else
        -- CreateScale(Single, Single, Single, Vector3)
        local result = new(Matrix4x4)

        local tx = val4.X * (1 - val1)
        local ty = val4.Y * (1 - val2)
        local tz = val4.Z * (1 - val3)

        result.M11 = val1
        result.M12 = 0.0
        result.M13 = 0.0
        result.M14 = 0.0
        result.M21 = 0.0
        result.M22 = val2
        result.M23 = 0.0
        result.M24 = 0.0
        result.M31 = 0.0
        result.M32 = 0.0
        result.M33 = val3
        result.M34 = 0.0
        result.M41 = tx
        result.M42 = ty
        result.M43 = tz
        result.M44 = 1.0

        return result:__clone__()
    end
end

Matrix4x4.CreateRotationX = function (radians, centerPoint)

    if centerPoint == nil then
        local result = new(Matrix4x4)

        local c = System.ToSingle(cos(radians))
        local s = System.ToSingle(sin(radians))
    
        -- [  1  0  0  0 ]
        -- [  0  c  s  0 ]
        -- [  0 -s  c  0 ]
        -- [  0  0  0  1 ]
        result.M11 = 1.0
        result.M12 = 0.0
        result.M13 = 0.0
        result.M14 = 0.0
        result.M21 = 0.0
        result.M22 = c
        result.M23 = s
        result.M24 = 0.0
        result.M31 = 0.0
        result.M32 = - s
        result.M33 = c
        result.M34 = 0.0
        result.M41 = 0.0
        result.M42 = 0.0
        result.M43 = 0.0
        result.M44 = 1.0
    
        return result:__clone__()
    else
        local result = new(Matrix4x4)

        local c = System.ToSingle(cos(radians))
        local s = System.ToSingle(sin(radians))
  
        local y = centerPoint.Y * (1 - c) + centerPoint.Z * s
        local z = centerPoint.Z * (1 - c) - centerPoint.Y * s
  
        -- [  1  0  0  0 ]
        -- [  0  c  s  0 ]
        -- [  0 -s  c  0 ]
        -- [  0  y  z  1 ]
        result.M11 = 1.0
        result.M12 = 0.0
        result.M13 = 0.0
        result.M14 = 0.0
        result.M21 = 0.0
        result.M22 = c
        result.M23 = s
        result.M24 = 0.0
        result.M31 = 0.0
        result.M32 = - s
        result.M33 = c
        result.M34 = 0.0
        result.M41 = 0.0
        result.M42 = y
        result.M43 = z
        result.M44 = 1.0
  
        return result:__clone__()
    end    
end

Matrix4x4.CreateRotationY = function(radians, centerPoint)
    if centerPoint == nil then
        local result = new(Matrix4x4)

        local c = System.ToSingle(cos(radians))
        local s = System.ToSingle(sin(radians))
  
        -- [  c  0 -s  0 ]
        -- [  0  1  0  0 ]
        -- [  s  0  c  0 ]
        -- [  0  0  0  1 ]
        result.M11 = c
        result.M12 = 0.0
        result.M13 = - s
        result.M14 = 0.0
        result.M21 = 0.0
        result.M22 = 1.0
        result.M23 = 0.0
        result.M24 = 0.0
        result.M31 = s
        result.M32 = 0.0
        result.M33 = c
        result.M34 = 0.0
        result.M41 = 0.0
        result.M42 = 0.0
        result.M43 = 0.0
        result.M44 = 1.0
  
        return result:__clone__()
    else
        local result = new(Matrix4x4)

        local c = System.ToSingle(cos(radians))
        local s = System.ToSingle(sin(radians))

        local x = centerPoint.X * (1 - c) - centerPoint.Z * s
        local z = centerPoint.Z * (1 - c) + centerPoint.X * s

         -- [  c  0 -s  0 ]
         -- [  0  1  0  0 ]
         -- [  s  0  c  0 ]
         -- [  x  0  z  1 ]
        result.M11 = c
        result.M12 = 0.0
        result.M13 = - s
        result.M14 = 0.0
        result.M21 = 0.0
        result.M22 = 1.0
        result.M23 = 0.0
        result.M24 = 0.0
        result.M31 = s
        result.M32 = 0.0
        result.M33 = c
        result.M34 = 0.0
        result.M41 = x
        result.M42 = 0.0
        result.M43 = z
        result.M44 = 1.0

        return result:__clone__()
    end
end

Matrix4x4.CreateRotationZ = function(radians, centerPoint)
    if centerPoint == nil then
        local result = new(Matrix4x4)

        local c = System.ToSingle(cos(radians))
        local s = System.ToSingle(sin(radians))
  
        -- [  c  s  0  0 ]
        -- [ -s  c  0  0 ]
        -- [  0  0  1  0 ]
        -- [  0  0  0  1 ]
        result.M11 = c
        result.M12 = s
        result.M13 = 0.0
        result.M14 = 0.0
        result.M21 = - s
        result.M22 = c
        result.M23 = 0.0
        result.M24 = 0.0
        result.M31 = 0.0
        result.M32 = 0.0
        result.M33 = 1.0
        result.M34 = 0.0
        result.M41 = 0.0
        result.M42 = 0.0
        result.M43 = 0.0
        result.M44 = 1.0
  
        return result:__clone__()
    else
        local result = new(Matrix4x4)

        local c = System.ToSingle(cos(radians))
        local s = System.ToSingle(sin(radians))
  
        local x = centerPoint.X * (1 - c) + centerPoint.Y * s
        local y = centerPoint.Y * (1 - c) - centerPoint.X * s
  
        -- [  c  s  0  0 ]
        -- [ -s  c  0  0 ]
        -- [  0  0  1  0 ]
        -- [  x  y  0  1 ]
        result.M11 = c
        result.M12 = s
        result.M13 = 0.0
        result.M14 = 0.0
        result.M21 = - s
        result.M22 = c
        result.M23 = 0.0
        result.M24 = 0.0
        result.M31 = 0.0
        result.M32 = 0.0
        result.M33 = 1.0
        result.M34 = 0.0
        result.M41 = x
        result.M42 = y
        result.M43 = 0.0
        result.M44 = 1.0
  
        return result:__clone__()
    end
end

Matrix4x4.CreateFromAxisAngle = function (axis, angle)
    -- a: angle
    -- x, y, z: unit vector for axis.
    --
    -- Rotation matrix M can compute by using below equation.
    --
    --        T               T
    --  M = uu + (cos a)( I-uu ) + (sin a)S
    --
    -- Where:
    --
    --  u = ( x, y, z )
    --
    --      [  0 -z  y ]
    --  S = [  z  0 -x ]
    --      [ -y  x  0 ]
    --
    --      [ 1 0 0 ]
    --  I = [ 0 1 0 ]
    --      [ 0 0 1 ]
    --
    --
    --     [  xx+cosa*(1-xx)   yx-cosa*yx-sina*z zx-cosa*xz+sina*y ]
    -- M = [ xy-cosa*yx+sina*z    yy+cosa(1-yy)  yz-cosa*yz-sina*x ]
    --     [ zx-cosa*zx-sina*y zy-cosa*zy+sina*x   zz+cosa*(1-zz)  ]
    --
    local x = axis.X local y = axis.Y local z = axis.Z
    local sa = System.ToSingle(sin(angle)) local ca = System.ToSingle(cos(angle))
    local xx = x * x local yy = y * y local zz = z * z
    local xy = x * y local xz = x * z local yz = y * z

    local result = new(Matrix4x4)

    result.M11 = xx + ca * (1.0 - xx)
    result.M12 = xy - ca * xy + sa * z
    result.M13 = xz - ca * xz - sa * y
    result.M14 = 0.0
    result.M21 = xy - ca * xy - sa * z
    result.M22 = yy + ca * (1.0 - yy)
    result.M23 = yz - ca * yz + sa * x
    result.M24 = 0.0
    result.M31 = xz - ca * xz + sa * y
    result.M32 = yz - ca * yz - sa * x
    result.M33 = zz + ca * (1.0 - zz)
    result.M34 = 0.0
    result.M41 = 0.0
    result.M42 = 0.0
    result.M43 = 0.0
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreatePerspectiveFieldOfView = function (fieldOfView, aspectRatio, nearPlaneDistance, farPlaneDistance)
    if fieldOfView <= 0.0 or fieldOfView >= 3.14159265358979 --[[Math.PI]] then
      System.throw(System.ArgumentOutOfRangeException("fieldOfView"))
    end

    if nearPlaneDistance <= 0.0 then
      System.throw(System.ArgumentOutOfRangeException("nearPlaneDistance"))
    end

    if farPlaneDistance <= 0.0 then
      System.throw(System.ArgumentOutOfRangeException("farPlaneDistance"))
    end

    if nearPlaneDistance >= farPlaneDistance then
      System.throw(System.ArgumentOutOfRangeException("nearPlaneDistance"))
    end

    local yScale = 1.0 / System.ToSingle(tan(fieldOfView * 0.5))
    local xScale = yScale / aspectRatio

    local result = new(Matrix4x4)

    result.M11 = xScale
    result.M14 = 0.0 result.M13 = result.M14 result.M12 = result.M13

    result.M22 = yScale
    result.M24 = 0.0 result.M23 = result.M24 result.M21 = result.M23

    result.M32 = 0.0 result.M31 = result.M32
    result.M33 = farPlaneDistance / (nearPlaneDistance - farPlaneDistance)
    result.M34 = - 1.0

    result.M44 = 0.0 result.M42 = result.M44 result.M41 = result.M42
    result.M43 = nearPlaneDistance * farPlaneDistance / (nearPlaneDistance - farPlaneDistance)

    return result:__clone__()
end

Matrix4x4.CreatePerspective = function (width, height, nearPlaneDistance, farPlaneDistance)
    if nearPlaneDistance <= 0.0 then
      System.throw(System.ArgumentOutOfRangeException("nearPlaneDistance"))
    end
    if farPlaneDistance <= 0.0 then
      System.throw(System.ArgumentOutOfRangeException("farPlaneDistance"))
    end
    if nearPlaneDistance >= farPlaneDistance then
      System.throw(System.ArgumentOutOfRangeException("nearPlaneDistance"))
    end
    local result = new(Matrix4x4)

    result.M11 = 2.0 * nearPlaneDistance / width
    result.M14 = 0.0 result.M13 = result.M14 result.M12 = result.M13

    result.M22 = 2.0 * nearPlaneDistance / height
    result.M24 = 0.0 result.M23 = result.M24 result.M21 = result.M23

    result.M33 = farPlaneDistance / (nearPlaneDistance - farPlaneDistance)
    result.M32 = 0.0 result.M31 = result.M32
    result.M34 = - 1.0

    result.M44 = 0.0 result.M42 = result.M44 result.M41 = result.M42
    result.M43 = nearPlaneDistance * farPlaneDistance / (nearPlaneDistance - farPlaneDistance)

    return result:__clone__()
end

Matrix4x4.CreatePerspectiveOffCenter = function (left, right, bottom, top, nearPlaneDistance, farPlaneDistance)
    if nearPlaneDistance <= 0.0 then
      System.throw(System.ArgumentOutOfRangeException("nearPlaneDistance"))
    end

    if farPlaneDistance <= 0.0 then
      System.throw(System.ArgumentOutOfRangeException("farPlaneDistance"))
    end

    if nearPlaneDistance >= farPlaneDistance then
      System.throw(System.ArgumentOutOfRangeException("nearPlaneDistance"))
    end

    local result = new(Matrix4x4)

    result.M11 = 2.0 * nearPlaneDistance / (right - left)
    result.M14 = 0.0 result.M13 = result.M14 result.M12 = result.M13

    result.M22 = 2.0 * nearPlaneDistance / (top - bottom)
    result.M24 = 0.0 result.M23 = result.M24 result.M21 = result.M23

    result.M31 = (left + right) / (right - left)
    result.M32 = (top + bottom) / (top - bottom)
    result.M33 = farPlaneDistance / (nearPlaneDistance - farPlaneDistance)
    result.M34 = - 1.0

    result.M43 = nearPlaneDistance * farPlaneDistance / (nearPlaneDistance - farPlaneDistance)
    result.M44 = 0.0 result.M42 = result.M44 result.M41 = result.M42

    return result:__clone__()
end

Matrix4x4.CreateOrthographic = function (width, height, zNearPlane, zFarPlane)
    local result = new(Matrix4x4)

    result.M11 = 2.0 / width
    result.M14 = 0.0 result.M13 = result.M14 result.M12 = result.M13

    result.M22 = 2.0 / height
    result.M24 = 0.0 result.M23 = result.M24 result.M21 = result.M23

    result.M33 = 1.0 / (zNearPlane - zFarPlane)
    result.M34 = 0.0 result.M32 = result.M34 result.M31 = result.M32

    result.M42 = 0.0 result.M41 = result.M42
    result.M43 = zNearPlane / (zNearPlane - zFarPlane)
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateOrthographicOffCenter = function (left, right, bottom, top, zNearPlane, zFarPlane)
    local result = new(Matrix4x4)

    result.M11 = 2.0 / (right - left)
    result.M14 = 0.0 result.M13 = result.M14 result.M12 = result.M13

    result.M22 = 2.0 / (top - bottom)
    result.M24 = 0.0 result.M23 = result.M24 result.M21 = result.M23

    result.M33 = 1.0 / (zNearPlane - zFarPlane)
    result.M34 = 0.0 result.M32 = result.M34 result.M31 = result.M32

    result.M41 = (left + right) / (left - right)
    result.M42 = (top + bottom) / (bottom - top)
    result.M43 = zNearPlane / (zNearPlane - zFarPlane)
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateLookAt = function (cameraPosition, cameraTarget, cameraUpVector)
    local zaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.op_Subtraction(cameraPosition, cameraTarget))
    local xaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(cameraUpVector, zaxis))
    local yaxis = SystemNumerics.Vector3.Cross(zaxis, xaxis)

    local result = new(Matrix4x4)

    result.M11 = xaxis.X
    result.M12 = yaxis.X
    result.M13 = zaxis.X
    result.M14 = 0.0
    result.M21 = xaxis.Y
    result.M22 = yaxis.Y
    result.M23 = zaxis.Y
    result.M24 = 0.0
    result.M31 = xaxis.Z
    result.M32 = yaxis.Z
    result.M33 = zaxis.Z
    result.M34 = 0.0
    result.M41 = - SystemNumerics.Vector3.Dot(xaxis, cameraPosition)
    result.M42 = - SystemNumerics.Vector3.Dot(yaxis, cameraPosition)
    result.M43 = - SystemNumerics.Vector3.Dot(zaxis, cameraPosition)
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateWorld = function (position, forward, up)
    local zaxis = SystemNumerics.Vector3.Normalize(- forward)
    local xaxis = SystemNumerics.Vector3.Normalize(SystemNumerics.Vector3.Cross(up, zaxis))
    local yaxis = SystemNumerics.Vector3.Cross(zaxis, xaxis)

    local result = new(Matrix4x4)

    result.M11 = xaxis.X
    result.M12 = xaxis.Y
    result.M13 = xaxis.Z
    result.M14 = 0.0
    result.M21 = yaxis.X
    result.M22 = yaxis.Y
    result.M23 = yaxis.Z
    result.M24 = 0.0
    result.M31 = zaxis.X
    result.M32 = zaxis.Y
    result.M33 = zaxis.Z
    result.M34 = 0.0
    result.M41 = position.X
    result.M42 = position.Y
    result.M43 = position.Z
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateFromQuaternion = function (quaternion)
    local result = new(Matrix4x4)

    local xx = quaternion.X * quaternion.X
    local yy = quaternion.Y * quaternion.Y
    local zz = quaternion.Z * quaternion.Z

    local xy = quaternion.X * quaternion.Y
    local wz = quaternion.Z * quaternion.W
    local xz = quaternion.Z * quaternion.X
    local wy = quaternion.Y * quaternion.W
    local yz = quaternion.Y * quaternion.Z
    local wx = quaternion.X * quaternion.W

    result.M11 = 1.0 - 2.0 * (yy + zz)
    result.M12 = 2.0 * (xy + wz)
    result.M13 = 2.0 * (xz - wy)
    result.M14 = 0.0
    result.M21 = 2.0 * (xy - wz)
    result.M22 = 1.0 - 2.0 * (zz + xx)
    result.M23 = 2.0 * (yz + wx)
    result.M24 = 0.0
    result.M31 = 2.0 * (xz + wy)
    result.M32 = 2.0 * (yz - wx)
    result.M33 = 1.0 - 2.0 * (yy + xx)
    result.M34 = 0.0
    result.M41 = 0.0
    result.M42 = 0.0
    result.M43 = 0.0
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.CreateFromYawPitchRoll = function (yaw, pitch, roll)
    local q = SystemNumerics.Quaternion.CreateFromYawPitchRoll(yaw, pitch, roll)

    return Matrix4x4.CreateFromQuaternion(q:__clone__())
end

Matrix4x4.CreateShadow = function (lightDirection, plane)
    local p = SystemNumerics.Plane.Normalize(plane)

    local dot = p.Normal.X * lightDirection.X + p.Normal.Y * lightDirection.Y + p.Normal.Z * lightDirection.Z
    local a = - p.Normal.X
    local b = - p.Normal.Y
    local c = - p.Normal.Z
    local d = - p.D

    local result = new(Matrix4x4)

    result.M11 = a * lightDirection.X + dot
    result.M21 = b * lightDirection.X
    result.M31 = c * lightDirection.X
    result.M41 = d * lightDirection.X

    result.M12 = a * lightDirection.Y
    result.M22 = b * lightDirection.Y + dot
    result.M32 = c * lightDirection.Y
    result.M42 = d * lightDirection.Y

    result.M13 = a * lightDirection.Z
    result.M23 = b * lightDirection.Z
    result.M33 = c * lightDirection.Z + dot
    result.M43 = d * lightDirection.Z

    result.M14 = 0.0
    result.M24 = 0.0
    result.M34 = 0.0
    result.M44 = dot

    return result:__clone__()
end

Matrix4x4.CreateReflection = function (value)
    value = SystemNumerics.Plane.Normalize(value)

    local a = value.Normal.X
    local b = value.Normal.Y
    local c = value.Normal.Z

    local fa = - 2.0 * a
    local fb = - 2.0 * b
    local fc = - 2.0 * c

    local result = new(Matrix4x4)

    result.M11 = fa * a + 1.0
    result.M12 = fb * a
    result.M13 = fc * a
    result.M14 = 0.0

    result.M21 = fa * b
    result.M22 = fb * b + 1.0
    result.M23 = fc * b
    result.M24 = 0.0

    result.M31 = fa * c
    result.M32 = fb * c
    result.M33 = fc * c + 1.0
    result.M34 = 0.0

    result.M41 = fa * value.D
    result.M42 = fb * value.D
    result.M43 = fc * value.D
    result.M44 = 1.0

    return result:__clone__()
end

Matrix4x4.GetDeterminant = function (this)
    -- | a b c d |     | f g h |     | e g h |     | e f h |     | e f g |
    -- | e f g h | = a | j k l | - b | i k l | + c | i j l | - d | i j k |
    -- | i j k l |     | n o p |     | m o p |     | m n p |     | m n o |
    -- | m n o p |
    --
    --   | f g h |
    -- a | j k l | = a ( f ( kp - lo ) - g ( jp - ln ) + h ( jo - kn ) )
    --   | n o p |
    --
    --   | e g h |     
    -- b | i k l | = b ( e ( kp - lo ) - g ( ip - lm ) + h ( io - km ) )
    --   | m o p |     
    --
    --   | e f h |
    -- c | i j l | = c ( e ( jp - ln ) - f ( ip - lm ) + h ( in - jm ) )
    --   | m n p |
    --
    --   | e f g |
    -- d | i j k | = d ( e ( jo - kn ) - f ( io - km ) + g ( in - jm ) )
    --   | m n o |
    --
    -- Cost of operation
    -- 17 adds and 28 muls.
    --
    -- add: 6 + 8 + 3 = 17
    -- mul: 12 + 16 = 28

    local a = this.M11 local b = this.M12 local c = this.M13 local d = this.M14
    local e = this.M21 local f = this.M22 local g = this.M23 local h = this.M24
    local i = this.M31 local j = this.M32 local k = this.M33 local l = this.M34
    local m = this.M41 local n = this.M42 local o = this.M43 local p = this.M44

    local kp_lo = k * p - l * o
    local jp_ln = j * p - l * n
    local jo_kn = j * o - k * n
    local ip_lm = i * p - l * m
    local io_km = i * o - k * m
    local in_jm = i * n - j * m

    return a * (f * kp_lo - g * jp_ln + h * jo_kn) - b * (e * kp_lo - g * ip_lm + h * io_km) + c * (e * jp_ln - f * ip_lm + h * in_jm) - d * (e * jo_kn - f * io_km + g * in_jm)
end

Matrix4x4.Invert = function (matrix, result)
    --                                       -1
    -- If you have matrix M, inverse Matrix M   can compute
    --
    --     -1       1      
    --    M   = --------- A
    --            det(M)
    --
    -- A is adjugate (adjoint) of M, where,
    --
    --      T
    -- A = C
    --
    -- C is Cofactor matrix of M, where,
    --           i + j
    -- C   = (-1)      * det(M  )
    --  ij                    ij
    --
    --     [ a b c d ]
    -- M = [ e f g h ]
    --     [ i j k l ]
    --     [ m n o p ]
    --
    -- First Row
    --           2 | f g h |
    -- C   = (-1)  | j k l | = + ( f ( kp - lo ) - g ( jp - ln ) + h ( jo - kn ) )
    --  11         | n o p |
    --
    --           3 | e g h |
    -- C   = (-1)  | i k l | = - ( e ( kp - lo ) - g ( ip - lm ) + h ( io - km ) )
    --  12         | m o p |
    --
    --           4 | e f h |
    -- C   = (-1)  | i j l | = + ( e ( jp - ln ) - f ( ip - lm ) + h ( in - jm ) )
    --  13         | m n p |
    --
    --           5 | e f g |
    -- C   = (-1)  | i j k | = - ( e ( jo - kn ) - f ( io - km ) + g ( in - jm ) )
    --  14         | m n o |
    --
    -- Second Row
    --           3 | b c d |
    -- C   = (-1)  | j k l | = - ( b ( kp - lo ) - c ( jp - ln ) + d ( jo - kn ) )
    --  21         | n o p |
    --
    --           4 | a c d |
    -- C   = (-1)  | i k l | = + ( a ( kp - lo ) - c ( ip - lm ) + d ( io - km ) )
    --  22         | m o p |
    --
    --           5 | a b d |
    -- C   = (-1)  | i j l | = - ( a ( jp - ln ) - b ( ip - lm ) + d ( in - jm ) )
    --  23         | m n p |
    --
    --           6 | a b c |
    -- C   = (-1)  | i j k | = + ( a ( jo - kn ) - b ( io - km ) + c ( in - jm ) )
    --  24         | m n o |
    --
    -- Third Row
    --           4 | b c d |
    -- C   = (-1)  | f g h | = + ( b ( gp - ho ) - c ( fp - hn ) + d ( fo - gn ) )
    --  31         | n o p |
    --
    --           5 | a c d |
    -- C   = (-1)  | e g h | = - ( a ( gp - ho ) - c ( ep - hm ) + d ( eo - gm ) )
    --  32         | m o p |
    --
    --           6 | a b d |
    -- C   = (-1)  | e f h | = + ( a ( fp - hn ) - b ( ep - hm ) + d ( en - fm ) )
    --  33         | m n p |
    --
    --           7 | a b c |
    -- C   = (-1)  | e f g | = - ( a ( fo - gn ) - b ( eo - gm ) + c ( en - fm ) )
    --  34         | m n o |
    --
    -- Fourth Row
    --           5 | b c d |
    -- C   = (-1)  | f g h | = - ( b ( gl - hk ) - c ( fl - hj ) + d ( fk - gj ) )
    --  41         | j k l |
    --
    --           6 | a c d |
    -- C   = (-1)  | e g h | = + ( a ( gl - hk ) - c ( el - hi ) + d ( ek - gi ) )
    --  42         | i k l |
    --
    --           7 | a b d |
    -- C   = (-1)  | e f h | = - ( a ( fl - hj ) - b ( el - hi ) + d ( ej - fi ) )
    --  43         | i j l |
    --
    --           8 | a b c |
    -- C   = (-1)  | e f g | = + ( a ( fk - gj ) - b ( ek - gi ) + c ( ej - fi ) )
    --  44         | i j k |
    --
    -- Cost of operation
    -- 53 adds, 104 muls, and 1 div.
    local a = matrix.M11 local b = matrix.M12 local c = matrix.M13 local d = matrix.M14
    local e = matrix.M21 local f = matrix.M22 local g = matrix.M23 local h = matrix.M24
    local i = matrix.M31 local j = matrix.M32 local k = matrix.M33 local l = matrix.M34
    local m = matrix.M41 local n = matrix.M42 local o = matrix.M43 local p = matrix.M44

    local kp_lo = k * p - l * o
    local jp_ln = j * p - l * n
    local jo_kn = j * o - k * n
    local ip_lm = i * p - l * m
    local io_km = i * o - k * m
    local in_jm = i * n - j * m

    local a11 = (f * kp_lo - g * jp_ln + h * jo_kn)
    local a12 = - (e * kp_lo - g * ip_lm + h * io_km)
    local a13 = (e * jp_ln - f * ip_lm + h * in_jm)
    local a14 = - (e * jo_kn - f * io_km + g * in_jm)

    local det = a * a11 + b * a12 + c * a13 + d * a14

    if abs(det) < 1.401298E-45 --[[Single.Epsilon]] then
      result = new(Matrix4x4, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN, System.Single.NaN)
      return false, result
    end

    local invDet = 1.0 / det

    if result == nil then
        result = new(Matrix4x4)
    end

    result.M11 = a11 * invDet
    result.M21 = a12 * invDet
    result.M31 = a13 * invDet
    result.M41 = a14 * invDet

    result.M12 = - (b * kp_lo - c * jp_ln + d * jo_kn) * invDet
    result.M22 = (a * kp_lo - c * ip_lm + d * io_km) * invDet
    result.M32 = - (a * jp_ln - b * ip_lm + d * in_jm) * invDet
    result.M42 = (a * jo_kn - b * io_km + c * in_jm) * invDet

    local gp_ho = g * p - h * o
    local fp_hn = f * p - h * n
    local fo_gn = f * o - g * n
    local ep_hm = e * p - h * m
    local eo_gm = e * o - g * m
    local en_fm = e * n - f * m

    result.M13 = (b * gp_ho - c * fp_hn + d * fo_gn) * invDet
    result.M23 = - (a * gp_ho - c * ep_hm + d * eo_gm) * invDet
    result.M33 = (a * fp_hn - b * ep_hm + d * en_fm) * invDet
    result.M43 = - (a * fo_gn - b * eo_gm + c * en_fm) * invDet

    local gl_hk = g * l - h * k
    local fl_hj = f * l - h * j
    local fk_gj = f * k - g * j
    local el_hi = e * l - h * i
    local ek_gi = e * k - g * i
    local ej_fi = e * j - f * i

    result.M14 = - (b * gl_hk - c * fl_hj + d * fk_gj) * invDet
    result.M24 = (a * gl_hk - c * el_hi + d * ek_gi) * invDet
    result.M34 = - (a * fl_hj - b * el_hi + d * ej_fi) * invDet
    result.M44 = (a * fk_gj - b * ek_gi + c * ej_fi) * invDet

    return true, result
end

Matrix4x4.Transform = function (value, rotation)
    -- Compute rotation matrix.
    local x2 = rotation.X + rotation.X
    local y2 = rotation.Y + rotation.Y
    local z2 = rotation.Z + rotation.Z

    local wx2 = rotation.W * x2
    local wy2 = rotation.W * y2
    local wz2 = rotation.W * z2
    local xx2 = rotation.X * x2
    local xy2 = rotation.X * y2
    local xz2 = rotation.X * z2
    local yy2 = rotation.Y * y2
    local yz2 = rotation.Y * z2
    local zz2 = rotation.Z * z2

    local q11 = 1.0 - yy2 - zz2
    local q21 = xy2 - wz2
    local q31 = xz2 + wy2

    local q12 = xy2 + wz2
    local q22 = 1.0 - xx2 - zz2
    local q32 = yz2 - wx2

    local q13 = xz2 - wy2
    local q23 = yz2 + wx2
    local q33 = 1.0 - xx2 - yy2

    local result = new(Matrix4x4)

    -- First row
    result.M11 = value.M11 * q11 + value.M12 * q21 + value.M13 * q31
    result.M12 = value.M11 * q12 + value.M12 * q22 + value.M13 * q32
    result.M13 = value.M11 * q13 + value.M12 * q23 + value.M13 * q33
    result.M14 = value.M14

    -- Second row
    result.M21 = value.M21 * q11 + value.M22 * q21 + value.M23 * q31
    result.M22 = value.M21 * q12 + value.M22 * q22 + value.M23 * q32
    result.M23 = value.M21 * q13 + value.M22 * q23 + value.M23 * q33
    result.M24 = value.M24

    -- Third row
    result.M31 = value.M31 * q11 + value.M32 * q21 + value.M33 * q31
    result.M32 = value.M31 * q12 + value.M32 * q22 + value.M33 * q32
    result.M33 = value.M31 * q13 + value.M32 * q23 + value.M33 * q33
    result.M34 = value.M34

    -- Fourth row
    result.M41 = value.M41 * q11 + value.M42 * q21 + value.M43 * q31
    result.M42 = value.M41 * q12 + value.M42 * q22 + value.M43 * q32
    result.M43 = value.M41 * q13 + value.M42 * q23 + value.M43 * q33
    result.M44 = value.M44

    return result:__clone__()
end

Matrix4x4.Transpose = function (matrix)
    local result = new(Matrix4x4)

    result.M11 = matrix.M11
    result.M12 = matrix.M21
    result.M13 = matrix.M31
    result.M14 = matrix.M41
    result.M21 = matrix.M12
    result.M22 = matrix.M22
    result.M23 = matrix.M32
    result.M24 = matrix.M42
    result.M31 = matrix.M13
    result.M32 = matrix.M23
    result.M33 = matrix.M33
    result.M34 = matrix.M43
    result.M41 = matrix.M14
    result.M42 = matrix.M24
    result.M43 = matrix.M34
    result.M44 = matrix.M44

    return result:__clone__()
end

Matrix4x4.Lerp = function (matrix1, matrix2, amount)
    local result = new(Matrix4x4)

    -- First row
    result.M11 = matrix1.M11 + (matrix2.M11 - matrix1.M11) * amount
    result.M12 = matrix1.M12 + (matrix2.M12 - matrix1.M12) * amount
    result.M13 = matrix1.M13 + (matrix2.M13 - matrix1.M13) * amount
    result.M14 = matrix1.M14 + (matrix2.M14 - matrix1.M14) * amount

    -- Second row
    result.M21 = matrix1.M21 + (matrix2.M21 - matrix1.M21) * amount
    result.M22 = matrix1.M22 + (matrix2.M22 - matrix1.M22) * amount
    result.M23 = matrix1.M23 + (matrix2.M23 - matrix1.M23) * amount
    result.M24 = matrix1.M24 + (matrix2.M24 - matrix1.M24) * amount

    -- Third row
    result.M31 = matrix1.M31 + (matrix2.M31 - matrix1.M31) * amount
    result.M32 = matrix1.M32 + (matrix2.M32 - matrix1.M32) * amount
    result.M33 = matrix1.M33 + (matrix2.M33 - matrix1.M33) * amount
    result.M34 = matrix1.M34 + (matrix2.M34 - matrix1.M34) * amount

    -- Fourth row
    result.M41 = matrix1.M41 + (matrix2.M41 - matrix1.M41) * amount
    result.M42 = matrix1.M42 + (matrix2.M42 - matrix1.M42) * amount
    result.M43 = matrix1.M43 + (matrix2.M43 - matrix1.M43) * amount
    result.M44 = matrix1.M44 + (matrix2.M44 - matrix1.M44) * amount

    return result:__clone__()
end

Matrix4x4.Negate = function (value)
    local result = new(Matrix4x4)

    result.M11 = - value.M11
    result.M12 = - value.M12
    result.M13 = - value.M13
    result.M14 = - value.M14
    result.M21 = - value.M21
    result.M22 = - value.M22
    result.M23 = - value.M23
    result.M24 = - value.M24
    result.M31 = - value.M31
    result.M32 = - value.M32
    result.M33 = - value.M33
    result.M34 = - value.M34
    result.M41 = - value.M41
    result.M42 = - value.M42
    result.M43 = - value.M43
    result.M44 = - value.M44

    return result:__clone__()
end

Matrix4x4.Add = function (value1, value2)
    local result = new(Matrix4x4)

    result.M11 = value1.M11 + value2.M11
    result.M12 = value1.M12 + value2.M12
    result.M13 = value1.M13 + value2.M13
    result.M14 = value1.M14 + value2.M14
    result.M21 = value1.M21 + value2.M21
    result.M22 = value1.M22 + value2.M22
    result.M23 = value1.M23 + value2.M23
    result.M24 = value1.M24 + value2.M24
    result.M31 = value1.M31 + value2.M31
    result.M32 = value1.M32 + value2.M32
    result.M33 = value1.M33 + value2.M33
    result.M34 = value1.M34 + value2.M34
    result.M41 = value1.M41 + value2.M41
    result.M42 = value1.M42 + value2.M42
    result.M43 = value1.M43 + value2.M43
    result.M44 = value1.M44 + value2.M44

    return result:__clone__()
end

Matrix4x4.Subtract = function (value1, value2)
    local result = new(Matrix4x4)

    result.M11 = value1.M11 - value2.M11
    result.M12 = value1.M12 - value2.M12
    result.M13 = value1.M13 - value2.M13
    result.M14 = value1.M14 - value2.M14
    result.M21 = value1.M21 - value2.M21
    result.M22 = value1.M22 - value2.M22
    result.M23 = value1.M23 - value2.M23
    result.M24 = value1.M24 - value2.M24
    result.M31 = value1.M31 - value2.M31
    result.M32 = value1.M32 - value2.M32
    result.M33 = value1.M33 - value2.M33
    result.M34 = value1.M34 - value2.M34
    result.M41 = value1.M41 - value2.M41
    result.M42 = value1.M42 - value2.M42
    result.M43 = value1.M43 - value2.M43
    result.M44 = value1.M44 - value2.M44

    return result:__clone__()
end

Matrix4x4.Multiply = function(value1, value2)
    if value2.M11 == nil then
        -- scalar
        local result = new(Matrix4x4)

        result.M11 = value1.M11 * value2
        result.M12 = value1.M12 * value2
        result.M13 = value1.M13 * value2
        result.M14 = value1.M14 * value2
        result.M21 = value1.M21 * value2
        result.M22 = value1.M22 * value2
        result.M23 = value1.M23 * value2
        result.M24 = value1.M24 * value2
        result.M31 = value1.M31 * value2
        result.M32 = value1.M32 * value2
        result.M33 = value1.M33 * value2
        result.M34 = value1.M34 * value2
        result.M41 = value1.M41 * value2
        result.M42 = value1.M42 * value2
        result.M43 = value1.M43 * value2
        result.M44 = value1.M44 * value2

        return result:__clone__()
    else
        -- matrix
        local result = new(Matrix4x4)

        -- First row
        result.M11 = value1.M11 * value2.M11 + value1.M12 * value2.M21 + value1.M13 * value2.M31 + value1.M14 * value2.M41
        result.M12 = value1.M11 * value2.M12 + value1.M12 * value2.M22 + value1.M13 * value2.M32 + value1.M14 * value2.M42
        result.M13 = value1.M11 * value2.M13 + value1.M12 * value2.M23 + value1.M13 * value2.M33 + value1.M14 * value2.M43
        result.M14 = value1.M11 * value2.M14 + value1.M12 * value2.M24 + value1.M13 * value2.M34 + value1.M14 * value2.M44

        -- Second row
        result.M21 = value1.M21 * value2.M11 + value1.M22 * value2.M21 + value1.M23 * value2.M31 + value1.M24 * value2.M41
        result.M22 = value1.M21 * value2.M12 + value1.M22 * value2.M22 + value1.M23 * value2.M32 + value1.M24 * value2.M42
        result.M23 = value1.M21 * value2.M13 + value1.M22 * value2.M23 + value1.M23 * value2.M33 + value1.M24 * value2.M43
        result.M24 = value1.M21 * value2.M14 + value1.M22 * value2.M24 + value1.M23 * value2.M34 + value1.M24 * value2.M44

        -- Third row
        result.M31 = value1.M31 * value2.M11 + value1.M32 * value2.M21 + value1.M33 * value2.M31 + value1.M34 * value2.M41
        result.M32 = value1.M31 * value2.M12 + value1.M32 * value2.M22 + value1.M33 * value2.M32 + value1.M34 * value2.M42
        result.M33 = value1.M31 * value2.M13 + value1.M32 * value2.M23 + value1.M33 * value2.M33 + value1.M34 * value2.M43
        result.M34 = value1.M31 * value2.M14 + value1.M32 * value2.M24 + value1.M33 * value2.M34 + value1.M34 * value2.M44

        -- Fourth row
        result.M41 = value1.M41 * value2.M11 + value1.M42 * value2.M21 + value1.M43 * value2.M31 + value1.M44 * value2.M41
        result.M42 = value1.M41 * value2.M12 + value1.M42 * value2.M22 + value1.M43 * value2.M32 + value1.M44 * value2.M42
        result.M43 = value1.M41 * value2.M13 + value1.M42 * value2.M23 + value1.M43 * value2.M33 + value1.M44 * value2.M43
        result.M44 = value1.M41 * value2.M14 + value1.M42 * value2.M24 + value1.M43 * value2.M34 + value1.M44 * value2.M44

        return result:__clone__()
    end
end

Matrix4x4.op_UnaryNegation = function (value)
    local m = new(Matrix4x4)

    m.M11 = - value.M11
    m.M12 = - value.M12
    m.M13 = - value.M13
    m.M14 = - value.M14
    m.M21 = - value.M21
    m.M22 = - value.M22
    m.M23 = - value.M23
    m.M24 = - value.M24
    m.M31 = - value.M31
    m.M32 = - value.M32
    m.M33 = - value.M33
    m.M34 = - value.M34
    m.M41 = - value.M41
    m.M42 = - value.M42
    m.M43 = - value.M43
    m.M44 = - value.M44

    return m:__clone__()
end

Matrix4x4.op_Addition = function (value1, value2)
    local m = new(Matrix4x4)

    m.M11 = value1.M11 + value2.M11
    m.M12 = value1.M12 + value2.M12
    m.M13 = value1.M13 + value2.M13
    m.M14 = value1.M14 + value2.M14
    m.M21 = value1.M21 + value2.M21
    m.M22 = value1.M22 + value2.M22
    m.M23 = value1.M23 + value2.M23
    m.M24 = value1.M24 + value2.M24
    m.M31 = value1.M31 + value2.M31
    m.M32 = value1.M32 + value2.M32
    m.M33 = value1.M33 + value2.M33
    m.M34 = value1.M34 + value2.M34
    m.M41 = value1.M41 + value2.M41
    m.M42 = value1.M42 + value2.M42
    m.M43 = value1.M43 + value2.M43
    m.M44 = value1.M44 + value2.M44

    return m:__clone__()
end

Matrix4x4.op_Subtraction = function (value1, value2)
    local m = new(Matrix4x4)

    m.M11 = value1.M11 - value2.M11
    m.M12 = value1.M12 - value2.M12
    m.M13 = value1.M13 - value2.M13
    m.M14 = value1.M14 - value2.M14
    m.M21 = value1.M21 - value2.M21
    m.M22 = value1.M22 - value2.M22
    m.M23 = value1.M23 - value2.M23
    m.M24 = value1.M24 - value2.M24
    m.M31 = value1.M31 - value2.M31
    m.M32 = value1.M32 - value2.M32
    m.M33 = value1.M33 - value2.M33
    m.M34 = value1.M34 - value2.M34
    m.M41 = value1.M41 - value2.M41
    m.M42 = value1.M42 - value2.M42
    m.M43 = value1.M43 - value2.M43
    m.M44 = value1.M44 - value2.M44

    return m:__clone__()
end

Matrix4x4.op_Multiply = function(value1, value2)
    if value2.M11 == nil then
        -- scalar
        local result = new(Matrix4x4)

        result.M11 = value1.M11 * value2
        result.M12 = value1.M12 * value2
        result.M13 = value1.M13 * value2
        result.M14 = value1.M14 * value2
        result.M21 = value1.M21 * value2
        result.M22 = value1.M22 * value2
        result.M23 = value1.M23 * value2
        result.M24 = value1.M24 * value2
        result.M31 = value1.M31 * value2
        result.M32 = value1.M32 * value2
        result.M33 = value1.M33 * value2
        result.M34 = value1.M34 * value2
        result.M41 = value1.M41 * value2
        result.M42 = value1.M42 * value2
        result.M43 = value1.M43 * value2
        result.M44 = value1.M44 * value2

        return result:__clone__()
    else
        -- matrix
        local result = new(Matrix4x4)

        -- First row
        result.M11 = value1.M11 * value2.M11 + value1.M12 * value2.M21 + value1.M13 * value2.M31 + value1.M14 * value2.M41
        result.M12 = value1.M11 * value2.M12 + value1.M12 * value2.M22 + value1.M13 * value2.M32 + value1.M14 * value2.M42
        result.M13 = value1.M11 * value2.M13 + value1.M12 * value2.M23 + value1.M13 * value2.M33 + value1.M14 * value2.M43
        result.M14 = value1.M11 * value2.M14 + value1.M12 * value2.M24 + value1.M13 * value2.M34 + value1.M14 * value2.M44

        -- Second row
        result.M21 = value1.M21 * value2.M11 + value1.M22 * value2.M21 + value1.M23 * value2.M31 + value1.M24 * value2.M41
        result.M22 = value1.M21 * value2.M12 + value1.M22 * value2.M22 + value1.M23 * value2.M32 + value1.M24 * value2.M42
        result.M23 = value1.M21 * value2.M13 + value1.M22 * value2.M23 + value1.M23 * value2.M33 + value1.M24 * value2.M43
        result.M24 = value1.M21 * value2.M14 + value1.M22 * value2.M24 + value1.M23 * value2.M34 + value1.M24 * value2.M44

        -- Third row
        result.M31 = value1.M31 * value2.M11 + value1.M32 * value2.M21 + value1.M33 * value2.M31 + value1.M34 * value2.M41
        result.M32 = value1.M31 * value2.M12 + value1.M32 * value2.M22 + value1.M33 * value2.M32 + value1.M34 * value2.M42
        result.M33 = value1.M31 * value2.M13 + value1.M32 * value2.M23 + value1.M33 * value2.M33 + value1.M34 * value2.M43
        result.M34 = value1.M31 * value2.M14 + value1.M32 * value2.M24 + value1.M33 * value2.M34 + value1.M34 * value2.M44

        -- Fourth row
        result.M41 = value1.M41 * value2.M11 + value1.M42 * value2.M21 + value1.M43 * value2.M31 + value1.M44 * value2.M41
        result.M42 = value1.M41 * value2.M12 + value1.M42 * value2.M22 + value1.M43 * value2.M32 + value1.M44 * value2.M42
        result.M43 = value1.M41 * value2.M13 + value1.M42 * value2.M23 + value1.M43 * value2.M33 + value1.M44 * value2.M43
        result.M44 = value1.M41 * value2.M14 + value1.M42 * value2.M24 + value1.M43 * value2.M34 + value1.M44 * value2.M44

        return result:__clone__()
    end
end

Matrix4x4.op_Equality = function (value1, value2)
    return (value1.M11 == value2.M11 and value1.M22 == value2.M22 and value1.M33 == value2.M33 and value1.M44 == value2.M44 and value1.M12 == value2.M12 and value1.M13 == value2.M13 and value1.M14 == value2.M14 and value1.M21 == value2.M21 and value1.M23 == value2.M23 and value1.M24 == value2.M24 and value1.M31 == value2.M31 and value1.M32 == value2.M32 and value1.M34 == value2.M34 and value1.M41 == value2.M41 and value1.M42 == value2.M42 and value1.M43 == value2.M43)
end

Matrix4x4.op_Inequality = function (value1, value2)
    return (value1.M11 ~= value2.M11 or value1.M12 ~= value2.M12 or value1.M13 ~= value2.M13 or value1.M14 ~= value2.M14 or value1.M21 ~= value2.M21 or value1.M22 ~= value2.M22 or value1.M23 ~= value2.M23 or value1.M24 ~= value2.M24 or value1.M31 ~= value2.M31 or value1.M32 ~= value2.M32 or value1.M33 ~= value2.M33 or value1.M34 ~= value2.M34 or value1.M41 ~= value2.M41 or value1.M42 ~= value2.M42 or value1.M43 ~= value2.M43 or value1.M44 ~= value2.M44)
end

Matrix4x4.Equals = function (this, other)
    if System.is(other, Matrix4x4) then
        return (this.M11 == other.M11 and this.M22 == other.M22 and this.M33 == other.M33 and this.M44 == other.M44 and this.M12 == other.M12 and this.M13 == other.M13 and this.M14 == other.M14 and this.M21 == other.M21 and this.M23 == other.M23 and this.M24 == other.M24 and this.M31 == other.M31 and this.M32 == other.M32 and this.M34 == other.M34 and this.M41 == other.M41 and this.M42 == other.M42 and this.M43 == other.M43)
    end
    return false
end

Matrix4x4.ToString = function (this)
    local sb = System.StringBuilder()
    sb:Append("{ ")
    sb:Append("{")
    sb:Append("M11: ")
    sb:Append(this.M11:ToString())
    sb:Append(" M12: ")
    sb:Append(this.M12:ToString())
    sb:Append(" M13: ")
    sb:Append(this.M13:ToString())
    sb:Append(" M14: ")
    sb:Append(this.M14:ToString())
    sb:Append("} ")
    sb:Append("{")
    sb:Append("M21: ")
    sb:Append(this.M21:ToString())
    sb:Append(" M22: ")
    sb:Append(this.M22:ToString())
    sb:Append(" M23: ")
    sb:Append(this.M23:ToString())
    sb:Append(" M24: ")
    sb:Append(this.M24:ToString())
    sb:Append("} ")
    sb:Append("{")
    sb:Append("M31: ")
    sb:Append(this.M31:ToString())
    sb:Append(" M32: ")
    sb:Append(this.M32:ToString())
    sb:Append(" M33: ")
    sb:Append(this.M33:ToString())
    sb:Append(" M34: ")
    sb:Append(this.M34:ToString())
    sb:Append("} ")
    sb:Append("{")
    sb:Append("M41: ")
    sb:Append(this.M41:ToString())
    sb:Append(" M42: ")
    sb:Append(this.M42:ToString())
    sb:Append(" M43: ")
    sb:Append(this.M43:ToString())
    sb:Append(" M44: ")
    sb:Append(this.M44:ToString())
    sb:Append("} ")
    sb:Append("}")
    return sb:ToString()
end

Matrix4x4.GetHashCode = function (this)
    return this.M11:GetHashCode() + this.M12:GetHashCode() + this.M13:GetHashCode() + this.M14:GetHashCode() + this.M21:GetHashCode() + this.M22:GetHashCode() + this.M23:GetHashCode() + this.M24:GetHashCode() + this.M31:GetHashCode() + this.M32:GetHashCode() + this.M33:GetHashCode() + this.M34:GetHashCode() + this.M41:GetHashCode() + this.M42:GetHashCode() + this.M43:GetHashCode() + this.M44:GetHashCode()
end

-- https://math.stackexchange.com/questions/237369/given-this-transformation-matrix-how-do-i-decompose-it-into-translation-rotati
-- It appears that this function is not complete, as it appears by the comments
-- Improvement is welcome
Matrix4x4.Decompose = function(matrix, scale, rotation, translation)
    -- throw(NotImplementedException("Matrix4x4.Decompose is not yet implemented"))

    -- Extract Translation
    translation = SystemNumerics.Vector3(matrix.M41, matrix.M42, matrix.M43)

    -- Zero Translation
    matrix.M41 = 0
    matrix.M42 = 0
    matrix.M43 = 0

    -- Extract scales

    local sx = SystemNumerics.Vector3(matrix.M11, matrix.M12, matrix.M13):Length()
    local sy = SystemNumerics.Vector3(matrix.M21, matrix.M22, matrix.M23):Length()
    local sz = SystemNumerics.Vector3(matrix.M31, matrix.M32, matrix.M33):Length()

    scale = SystemNumerics.Vector3(sx, sy, sz)

    -- divide by scale

    local matTemp = matrix:__clone__()

    matTemp.M11 = matTemp.M11 / sx
    matTemp.M12 = matTemp.M12 / sx
    matTemp.M13 = matTemp.M13 / sx

    matTemp.M21 = matTemp.M21 / sy
    matTemp.M22 = matTemp.M22 / sy
    matTemp.M23 = matTemp.M23 / sy

    matTemp.M31 = matTemp.M31 / sz
    matTemp.M32 = matTemp.M32 / sz
    matTemp.M33 = matTemp.M33/ sz

    rotation = SystemNumerics.Quaternion.CreateFromRotationMatrix(matTemp)

    return true, scale, rotation, translation
end

System.defStc("System.Numerics.Matrix4x4", Matrix4x4)
end

-- CoreSystemLib: Numerics/Plane.lua
do
local System = System
local SystemNumerics = System.Numerics

local sqrt = math.sqrt
local abs = math.abs

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Plane = {}

Plane.__ctor__ = function(this, val1, val2, val3, val4)
    if val4 == nil then
        if val2 == nil then
            -- Plane(Vector4)
            this.Normal = SystemNumerics.Vector3(val1.X, val1.Y, val1.Z)
            this.D = val1.W
        else
            -- Plane(Vector3, Single)
            this.Normal = val1:__clone__()
            this.D = val2
        end
    else
        -- Plane(Single, Single, Single, Single)
        this.Normal = SystemNumerics.Vector3(val1, val2, val3)
        this.D = val4
    end
end

Plane.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T) }
end

Plane.CreateFromVertices = function (point1, point2, point3)
    local ax = point2.X - point1.X
    local ay = point2.Y - point1.Y
    local az = point2.Z - point1.Z

    local bx = point3.X - point1.X
    local by = point3.Y - point1.Y
    local bz = point3.Z - point1.Z

    -- N=Cross(a,b)
    local nx = ay * bz - az * by
    local ny = az * bx - ax * bz
    local nz = ax * by - ay * bx

    -- Normalize(N)
    local ls = nx * nx + ny * ny + nz * nz
    local invNorm = 1.0 / System.ToSingle(sqrt(ls))

    local normal = SystemNumerics.Vector3(nx * invNorm, ny * invNorm, nz * invNorm)

    return new(Plane, normal:__clone__(), - (normal.X * point1.X + normal.Y * point1.Y + normal.Z * point1.Z))
end

Plane.Normalize = function (value)
    -- smallest such that 1.0+FLT_EPSILON != 1.0
    local f = value.Normal.X * value.Normal.X + value.Normal.Y * value.Normal.Y + value.Normal.Z * value.Normal.Z

    if abs(f - 1.0) < 1.192093E-07 --[[FLT_EPSILON]] then
        return value:__clone__()
        -- It already normalized, so we don't need to further process.
    end

    local fInv = 1.0 / System.ToSingle(sqrt(f))

    return new(Plane, value.Normal.X * fInv, value.Normal.Y * fInv, value.Normal.Z * fInv, value.D * fInv)
  end

Plane.Transform = function (plane, matrix)
    if matrix.X == nil then
        -- matrix
        local m
        local default
        default, m = SystemNumerics.Matrix4x4.Invert(matrix)

        local x = plane.Normal.X local y = plane.Normal.Y local z = plane.Normal.Z local w = plane.D

        return new(Plane, x * m.M11 + y * m.M12 + z * m.M13 + w * m.M14, x * m.M21 + y * m.M22 + z * m.M23 + w * m.M24, x * m.M31 + y * m.M32 + z * m.M33 + w * m.M34, x * m.M41 + y * m.M42 + z * m.M43 + w * m.M44)
    else
        -- quaternion
        local x2 = matrix.X + matrix.X
        local y2 = matrix.Y + matrix.Y
        local z2 = matrix.Z + matrix.Z
  
        local wx2 = matrix.W * x2
        local wy2 = matrix.W * y2
        local wz2 = matrix.W * z2
        local xx2 = matrix.X * x2
        local xy2 = matrix.X * y2
        local xz2 = matrix.X * z2
        local yy2 = matrix.Y * y2
        local yz2 = matrix.Y * z2
        local zz2 = matrix.Z * z2
  
        local m11 = 1.0 - yy2 - zz2
        local m21 = xy2 - wz2
        local m31 = xz2 + wy2
  
        local m12 = xy2 + wz2
        local m22 = 1.0 - xx2 - zz2
        local m32 = yz2 - wx2
  
        local m13 = xz2 - wy2
        local m23 = yz2 + wx2
        local m33 = 1.0 - xx2 - yy2
  
        local x = plane.Normal.X local y = plane.Normal.Y local z = plane.Normal.Z
  
        return new(Plane, x * m11 + y * m21 + z * m31, x * m12 + y * m22 + z * m32, x * m13 + y * m23 + z * m33, plane.D)  
    end
end

Plane.Dot = function (plane, value)
    return plane.Normal.X * value.X + plane.Normal.Y * value.Y + plane.Normal.Z * value.Z + plane.D * value.W
end

Plane.DotCoordinate = function (plane, value)
    return plane.Normal.X * value.X + plane.Normal.Y * value.Y + plane.Normal.Z * value.Z + plane.D
end

Plane.DotNormal = function (plane, value)
    return plane.Normal.X * value.X + plane.Normal.Y * value.Y + plane.Normal.Z * value.Z
end

Plane.op_Equality = function (value1, value2)
    return (value1.Normal.X == value2.Normal.X and value1.Normal.Y == value2.Normal.Y and value1.Normal.Z == value2.Normal.Z and value1.D == value2.D)
end

Plane.op_Inequality = function (value1, value2)
    return (value1.Normal.X ~= value2.Normal.X or value1.Normal.Y ~= value2.Normal.Y or value1.Normal.Z ~= value2.Normal.Z or value1.D ~= value2.D)
end

Plane.Equals = function (this, obj)
    if System.is(obj, Plane) then
        return (this.Normal.X == obj.Normal.X and this.Normal.Y == obj.Normal.Y and this.Normal.Z == obj.Normal.Z and this.D == obj.D)
    end
    return false
end

Plane.ToString = function (this)
    local sb = System.StringBuilder()
    sb:Append("{")
    sb:Append("Normal: ")
    sb:Append(this.Normal:ToString())
    sb:Append(" D: ")
    sb:Append(this.D:ToString())
    sb:Append("}")
    return sb:ToString()
end

Plane.GetHashCode = function (this)
    return this.Normal:GetHashCode() + this.D:GetHashCode()
end

System.defStc("System.Numerics.Plane", Plane)
end

-- CoreSystemLib: Numerics/Quaternion.lua
do
local System = System
local SystemNumerics = System.Numerics

local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local acos = math.acos

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Quaternion = {}

Quaternion.__ctor__ = function(this, x, y, z, w)
    if x == nil then
        this.X = 0
        this.Y = 0
        this.Z = 0
        this.W = 0
    elseif z == nil then
        -- Quaternion(Vector3, Single)
        this.X = x.X or 0
        this.Y = x.Y or 0
        this.Z = x.Z or 0
        this.W = z or 0
    else
        -- Quaternion(Single, Single, Single, Single)
        this.X = x or 0
        this.Y = y or 0
        this.Z = z or 0
        this.W = w or 0
    end
    local mt = getmetatable(this)
    mt.__unm = Quaternion.op_UnaryNegation
    setmetatable(this, mt)
end

Quaternion.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T) }
end

Quaternion.getIdentity = function ()
    return new(Quaternion, 0, 0, 0, 1)
end

Quaternion.getIsIdentity = function (this)
    return this.X == 0 and this.Y == 0 and this.Z == 0 and this.W == 1
end

Quaternion.Length = function (this)
    local ls = this.X * this.X + this.Y * this.Y + this.Z * this.Z + this.W * this.W

    return System.ToSingle(sqrt(ls))
end

Quaternion.LengthSquared = function (this)
    return this.X * this.X + this.Y * this.Y + this.Z * this.Z + this.W * this.W
end

Quaternion.Normalize = function (value)
    local ls = value.X * value.X + value.Y * value.Y + value.Z * value.Z + value.W * value.W
    local invNorm = 1.0 / System.ToSingle(sqrt(ls))

    return new(Quaternion, value.X * invNorm, value.Y * invNorm, value.Z * invNorm, value.W * invNorm)
end

Quaternion.Conjugate = function (value)
    return new(Quaternion, - value.X, - value.Y, - value.Z, value.W)
end

Quaternion.Inverse = function (value)
    --  -1   (       a              -v       )
    -- q   = ( -------------   ------------- )
    --       (  a^2 + |v|^2  ,  a^2 + |v|^2  )

    local ls = value.X * value.X + value.Y * value.Y + value.Z * value.Z + value.W * value.W
    local invNorm = 1.0 / ls

    return new(Quaternion, - value.X * invNorm, - value.Y * invNorm, - value.Z * invNorm, value.W * invNorm)
end

Quaternion.CreateFromAxisAngle = function (axis, angle)
    local halfAngle = angle * 0.5
    local s = System.ToSingle(sin(halfAngle))
    local c = System.ToSingle(cos(halfAngle))

    return new(Quaternion, axis.X * s, axis.Y * s, axis.Z * s, c)
end

Quaternion.CreateFromYawPitchRoll = function (yaw, pitch, roll)
    --  Roll first, about axis the object is facing, then
    --  pitch upward, then yaw to face into the new heading
    local sr, cr, sp, cp, sy, cy

    local halfRoll = roll * 0.5
    sr = System.ToSingle(sin(halfRoll))
    cr = System.ToSingle(cos(halfRoll))

    local halfPitch = pitch * 0.5
    sp = System.ToSingle(sin(halfPitch))
    cp = System.ToSingle(cos(halfPitch))

    local halfYaw = yaw * 0.5
    sy = System.ToSingle(sin(halfYaw))
    cy = System.ToSingle(cos(halfYaw))

    return new(Quaternion, cy * sp * cr + sy * cp * sr, sy * cp * cr - cy * sp * sr, cy * cp * sr - sy * sp * cr, cy * cp * cr + sy * sp * sr)
end

Quaternion.CreateFromRotationMatrix = function (matrix)
    local trace = matrix.M11 + matrix.M22 + matrix.M33

    local q = new(Quaternion)

    if trace > 0.0 then
      local s = System.ToSingle(sqrt(trace + 1.0))
      q.W = s * 0.5
      s = 0.5 / s
      q.X = (matrix.M23 - matrix.M32) * s
      q.Y = (matrix.M31 - matrix.M13) * s
      q.Z = (matrix.M12 - matrix.M21) * s
    else
      if matrix.M11 >= matrix.M22 and matrix.M11 >= matrix.M33 then
        local s = System.ToSingle(sqrt(1.0 + matrix.M11 - matrix.M22 - matrix.M33))
        local invS = 0.5 / s
        q.X = 0.5 * s
        q.Y = (matrix.M12 + matrix.M21) * invS
        q.Z = (matrix.M13 + matrix.M31) * invS
        q.W = (matrix.M23 - matrix.M32) * invS
      elseif matrix.M22 > matrix.M33 then
        local s = System.ToSingle(sqrt(1.0 + matrix.M22 - matrix.M11 - matrix.M33))
        local invS = 0.5 / s
        q.X = (matrix.M21 + matrix.M12) * invS
        q.Y = 0.5 * s
        q.Z = (matrix.M32 + matrix.M23) * invS
        q.W = (matrix.M31 - matrix.M13) * invS
      else
        local s = System.ToSingle(sqrt(1.0 + matrix.M33 - matrix.M11 - matrix.M22))
        local invS = 0.5 / s
        q.X = (matrix.M31 + matrix.M13) * invS
        q.Y = (matrix.M32 + matrix.M23) * invS
        q.Z = 0.5 * s
        q.W = (matrix.M12 - matrix.M21) * invS
      end
    end

    return q:__clone__()
end

Quaternion.Dot = function (quaternion1, quaternion2)
    return quaternion1.X * quaternion2.X + quaternion1.Y * quaternion2.Y + quaternion1.Z * quaternion2.Z + quaternion1.W * quaternion2.W
end

Quaternion.Slerp = function (quaternion1, quaternion2, amount)
    local t = amount

    local cosOmega = quaternion1.X * quaternion2.X + quaternion1.Y * quaternion2.Y + quaternion1.Z * quaternion2.Z + quaternion1.W * quaternion2.W

    local flip = false

    if cosOmega < 0.0 then
      flip = true
      cosOmega = - cosOmega
    end

    local s1, s2

    if cosOmega > (0.999999 --[[1.0f - epsilon]]) then
      -- Too close, do straight linear interpolation.
      s1 = 1.0 - t
      s2 = (flip) and - t or t
    else
      local omega = System.ToSingle(acos(cosOmega))
      local invSinOmega = System.ToSingle((1 / sin(omega)))

      s1 = System.ToSingle(sin((1.0 - t) * omega)) * invSinOmega
      s2 = (flip) and System.ToSingle(- sin(t * omega)) * invSinOmega or System.ToSingle(sin(t * omega)) * invSinOmega
    end

    return new(Quaternion, s1 * quaternion1.X + s2 * quaternion2.X, s1 * quaternion1.Y + s2 * quaternion2.Y, s1 * quaternion1.Z + s2 * quaternion2.Z, s1 * quaternion1.W + s2 * quaternion2.W)
end

Quaternion.Lerp = function (quaternion1, quaternion2, amount)
    local t = amount
    local t1 = 1.0 - t

    local r = new(Quaternion)

    local dot = quaternion1.X * quaternion2.X + quaternion1.Y * quaternion2.Y + quaternion1.Z * quaternion2.Z + quaternion1.W * quaternion2.W

    if dot >= 0.0 then
      r.X = t1 * quaternion1.X + t * quaternion2.X
      r.Y = t1 * quaternion1.Y + t * quaternion2.Y
      r.Z = t1 * quaternion1.Z + t * quaternion2.Z
      r.W = t1 * quaternion1.W + t * quaternion2.W
    else
      r.X = t1 * quaternion1.X - t * quaternion2.X
      r.Y = t1 * quaternion1.Y - t * quaternion2.Y
      r.Z = t1 * quaternion1.Z - t * quaternion2.Z
      r.W = t1 * quaternion1.W - t * quaternion2.W
    end

    -- Normalize it.
    local ls = r.X * r.X + r.Y * r.Y + r.Z * r.Z + r.W * r.W
    local invNorm = 1.0 / System.ToSingle(sqrt(ls))

    r.X = r.X * invNorm
    r.Y = r.Y * invNorm
    r.Z = r.Z * invNorm
    r.W = r.W * invNorm

    return r:__clone__()
end

Quaternion.Concatenate = function (value1, value2)

    -- Concatenate rotation is actually q2 * q1 instead of q1 * q2.
    -- So that's why value2 goes q1 and value1 goes q2.
    local q1x = value2.X
    local q1y = value2.Y
    local q1z = value2.Z
    local q1w = value2.W

    local q2x = value1.X
    local q2y = value1.Y
    local q2z = value1.Z
    local q2w = value1.W

    -- cross(av, bv)
    local cx = q1y * q2z - q1z * q2y
    local cy = q1z * q2x - q1x * q2z
    local cz = q1x * q2y - q1y * q2x

    local dot = q1x * q2x + q1y * q2y + q1z * q2z

    return new(Quaternion, q1x * q2w + q2x * q1w + cx, q1y * q2w + q2y * q1w + cy, q1z * q2w + q2z * q1w + cz, q1w * q2w - dot)
end

Quaternion.Negate = function (value)
    return new(Quaternion, - value.X, - value.Y, - value.Z, - value.W)
end

Quaternion.Add = function (value1, value2)
    return new(Quaternion, value1.X + value2.X, value1.Y + value2.Y, value1.Z + value2.Z, value1.W + value2.W)
end

Quaternion.Subtract = function (value1, value2)
    return new(Quaternion, value1.X - value2.X, value1.Y - value2.Y, value1.Z - value2.Z, value1.W - value2.W)
end

Quaternion.Multiply = function (value1, value2)
    if value2.X == nil then
        -- scalar
        return new(Quaternion, value1.X * value2, value1.Y * value2, value1.Z * value2, value1.W * value2)
    else
        -- quaternion
        local q1x = value1.X
        local q1y = value1.Y
        local q1z = value1.Z
        local q1w = value1.W

        local q2x = value2.X
        local q2y = value2.Y
        local q2z = value2.Z
        local q2w = value2.W

        -- cross(av, bv)
        local cx = q1y * q2z - q1z * q2y
        local cy = q1z * q2x - q1x * q2z
        local cz = q1x * q2y - q1y * q2x

        local dot = q1x * q2x + q1y * q2y + q1z * q2z

        return new(Quaternion, q1x * q2w + q2x * q1w + cx, q1y * q2w + q2y * q1w + cy, q1z * q2w + q2z * q1w + cz, q1w * q2w - dot)
    end    
end

Quaternion.Divide = function (value1, value2)

    local q1x = value1.X
    local q1y = value1.Y
    local q1z = value1.Z
    local q1w = value1.W

    ---------------------------------------
    -- Inverse part.
    local ls = value2.X * value2.X + value2.Y * value2.Y + value2.Z * value2.Z + value2.W * value2.W
    local invNorm = 1.0 / ls

    local q2x = - value2.X * invNorm
    local q2y = - value2.Y * invNorm
    local q2z = - value2.Z * invNorm
    local q2w = value2.W * invNorm

    ---------------------------------------
    -- Multiply part.

    -- cross(av, bv)
    local cx = q1y * q2z - q1z * q2y
    local cy = q1z * q2x - q1x * q2z
    local cz = q1x * q2y - q1y * q2x

    local dot = q1x * q2x + q1y * q2y + q1z * q2z

    return new(Quaternion, q1x * q2w + q2x * q1w + cx, q1y * q2w + q2y * q1w + cy, q1z * q2w + q2z * q1w + cz, q1w * q2w - dot)
end

Quaternion.op_UnaryNegation = function (value)
    return new(Quaternion, - value.X, - value.Y, - value.Z, - value.W)
end

Quaternion.op_Addition = function (value1, value2)
    return new(Quaternion, value1.X + value2.X, value1.Y + value2.Y, value1.Z + value2.Z, value1.W + value2.W)
end

Quaternion.op_Subtraction = function (value1, value2)
    return new(Quaternion, value1.X - value2.X, value1.Y - value2.Y, value1.Z - value2.Z, value1.W - value2.W)
end

Quaternion.op_Multiply = function (value1, value2)
    if value2.X == nil then
        -- scalar
        return new(Quaternion, value1.X * value2, value1.Y * value2, value1.Z * value2, value1.W * value2)
    else
        -- quaternion
        local q1x = value1.X
        local q1y = value1.Y
        local q1z = value1.Z
        local q1w = value1.W

        local q2x = value2.X
        local q2y = value2.Y
        local q2z = value2.Z
        local q2w = value2.W

        -- cross(av, bv)
        local cx = q1y * q2z - q1z * q2y
        local cy = q1z * q2x - q1x * q2z
        local cz = q1x * q2y - q1y * q2x

        local dot = q1x * q2x + q1y * q2y + q1z * q2z

        return new(Quaternion, q1x * q2w + q2x * q1w + cx, q1y * q2w + q2y * q1w + cy, q1z * q2w + q2z * q1w + cz, q1w * q2w - dot)
    end    
end

Quaternion.op_Division = function (value1, value2)

    local q1x = value1.X
    local q1y = value1.Y
    local q1z = value1.Z
    local q1w = value1.W

    ---------------------------------------
    -- Inverse part.
    local ls = value2.X * value2.X + value2.Y * value2.Y + value2.Z * value2.Z + value2.W * value2.W
    local invNorm = 1.0 / ls

    local q2x = - value2.X * invNorm
    local q2y = - value2.Y * invNorm
    local q2z = - value2.Z * invNorm
    local q2w = value2.W * invNorm

    ---------------------------------------
    -- Multiply part.

    -- cross(av, bv)
    local cx = q1y * q2z - q1z * q2y
    local cy = q1z * q2x - q1x * q2z
    local cz = q1x * q2y - q1y * q2x

    local dot = q1x * q2x + q1y * q2y + q1z * q2z

    return new(Quaternion, q1x * q2w + q2x * q1w + cx, q1y * q2w + q2y * q1w + cy, q1z * q2w + q2z * q1w + cz, q1w * q2w - dot)
end

Quaternion.op_Equality = function (value1, value2)
    return (value1.X == value2.X and value1.Y == value2.Y and value1.Z == value2.Z and value1.W == value2.W)
end

Quaternion.op_Inequality = function (value1, value2)
    return (value1.X ~= value2.X or value1.Y ~= value2.Y or value1.Z ~= value2.Z or value1.W ~= value2.W)
end

Quaternion.Equals = function (this, obj)
    if System.is(obj, Quaternion) then
        return (this.X == obj.X and this.Y == obj.Y and this.Z == obj.Z and this.W == obj.W)
    end
    return false
end

Quaternion.ToString = function (this)
    local sb = System.StringBuilder()
    sb:Append("{")
    sb:Append("X: ")
    sb:Append(this.X:ToString())
    sb:Append(" Y: ")
    sb:Append(this.Y:ToString())
    sb:Append(" Z: ")
    sb:Append(this.Z:ToString())
    sb:Append(" W: ")
    sb:Append(this.W:ToString())
    sb:Append("}")
    return sb:ToString()
end

Quaternion.GetHashCode = function (this)
    return this.X:GetHashCode() + this.Y:GetHashCode() + this.Z:GetHashCode() + this.W:GetHashCode()
end

System.defStc("System.Numerics.Quaternion", Quaternion)
end

-- CoreSystemLib: Numerics/Vector2.lua
do
local System = System
local SystemNumerics = System.Numerics

local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1
local IFormattable = System.IFormattable

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Vector2 = {}

Vector2.__ctor__ = function(this, X, Y)
    if Y == nil then
        this.X = X or 0
        this.Y = X or 0
    else
        this.X = X or 0
        this.Y = Y or 0
    end
    local mt = getmetatable(this)
    mt.__unm = Vector2.op_UnaryNegation
    setmetatable(this, mt)
end

Vector2.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T), IFormattable }
end

Vector2.getZero = function ()
    return new(Vector2, 0, 0, 0)
end
Vector2.getOne = function ()
    return new(Vector2, 1.0, 1.0)
end
Vector2.getUnitX = function ()
    return new(Vector2, 1.0, 0.0)
end
Vector2.getUnitY = function ()
    return new(Vector2, 0.0, 1.0)
end

Vector2.CopyTo = function(this, array, index)
    if index == nil then
        index = 0
    end

    if array == nil then
        System.throw(System.NullReferenceException())
    end

    if index < 0 or index >= #array then
        System.throw(System.ArgumentOutOfRangeException())
    end
    if (#array - index) < 2 then
        System.throw(System.ArgumentException())
    end

    array:set(index, this.X)
    array:set(index + 1, this.Y)
end

Vector2.Equals = function (this, other)
    if not (System.is(other, Vector2)) then
        return false
    end
    other = System.cast(Vector2, other)
    return this.X == other.X and this.Y == other.Y
end

Vector2.Dot = function (value1, value2)
    return value1.X * value2.X + value1.Y * value2.Y
end

Vector2.Min = function (value1, value2)
    return new(Vector2, (value1.X < value2.X) and value1.X or value2.X, (value1.Y < value2.Y) and value1.Y or value2.Y)
end

Vector2.Max = function (value1, value2)
    return new(Vector2, (value1.X > value2.X) and value1.X or value2.X, (value1.Y > value2.Y) and value1.Y or value2.Y)
end

Vector2.Abs = function (value)
    return new(Vector2, abs(value.X), abs(value.Y))
end

Vector2.SquareRoot = function (value)
    return new(Vector2, System.ToSingle(sqrt(value.X)), System.ToSingle(sqrt(value.Y)))
end

Vector2.op_Addition = function (left, right)
    return new(Vector2, left.X + right.X, left.Y + right.Y)
end

Vector2.Add = function (left, right)
    return Vector2.op_Addition(left, right)
end

Vector2.op_Subtraction = function (left, right)
    return new(Vector2, left.X - right.X, left.Y - right.Y)
end

Vector2.Subtract = function (left, right)
    return Vector2.op_Subtraction(left, right)
end

Vector2.op_Multiply = function (left, right)
    if type(left) == "number" then
        left = new(Vector2, left)
    end

    if type(right) == "number" then
        right = new(Vector2, right)
    end

    return new(Vector2, left.X * right.X, left.Y * right.Y)
end

Vector2.Multiply = function (left, right)
    return Vector2.op_Multiply(left, right)
end

Vector2.op_Division = function (left, right)
    if type(right) == "number" then
        return Vector2.op_Multiply(left, 1.0 / right)
    end
    return new(Vector2, left.X / right.X, left.Y / right.Y)
end

Vector2.Divide = function (left, right)
    return Vector2.op_Division(left, right)
end

Vector2.op_UnaryNegation = function (value)
    return Vector2.op_Subtraction(Vector2.getZero(), value)
end

Vector2.Negate = function (value)
    return - value
end

Vector2.op_Equality = function (left, right)
    return (left.X == right.X and left.Y == right.Y )
end

Vector2.op_Inequality = function (left, right)
    return (left.X ~= right.X or left.Y ~= right.Y)
end

Vector2.GetHashCode = function (this)
    local hash = this.X:GetHashCode()
    hash = SystemNumerics.HashCodeHelper.CombineHashCodes(hash, this.Y:GetHashCode())
    return hash
end

Vector2.ToString = function (this)
    local sb = System.StringBuilder()
    local separator = 44 --[[',']]
    sb:AppendChar(60 --[['<']])
    sb:Append(this.X:ToString())
    sb:AppendChar(separator)
    sb:AppendChar(32 --[[' ']])
    sb:Append(this.Y:ToString())
    sb:AppendChar(62 --[['>']])
    return sb:ToString()
end

Vector2.Length = function (this)
    local ls = this.X * this.X + this.Y * this.Y
    return System.ToSingle(sqrt(ls))
end

Vector2.LengthSquared = function (this)
    return this.X * this.X + this.Y * this.Y
end

Vector2.Distance = function (value1, value2)
    local dx = value1.X - value2.X
    local dy = value1.Y - value2.Y

    local ls = dx * dx + dy * dy

    return System.ToSingle(sqrt(ls))
end

Vector2.DistanceSquared = function (value1, value2)
    local dx = value1.X - value2.X
    local dy = value1.Y - value2.Y

    return dx * dx + dy * dy
end

Vector2.Normalize = function (value)
    local ls = value.X * value.X + value.Y * value.Y
    local invNorm = 1.0 / System.ToSingle(sqrt(ls))

    return new(Vector2, value.X * invNorm, value.Y * invNorm)
end

Vector2.Reflect = function (vector, normal)
    local dot = vector.X * normal.X + vector.Y * normal.Y

    return new(Vector2, vector.X - 2.0 * dot * normal.X, vector.Y - 2.0 * dot * normal.Y)
end

Vector2.Clamp = function (value1, min, max)
    -- This compare order is very important!!!
    -- We must follow HLSL behavior in the case user specified min value is bigger than max value.
    local x = value1.X
    x = (x > max.X) and max.X or x
    x = (x < min.X) and min.X or x

    local y = value1.Y
    y = (y > max.Y) and max.Y or y
    y = (y < min.Y) and min.Y or y

    return new(Vector2, x, y)
end

Vector2.Lerp = function (value1, value2, amount)
    return new(Vector2, value1.X + (value2.X - value1.X) * amount, value1.Y + (value2.Y - value1.Y) * amount)
end

Vector2.Transform = function (position, matrix)
    if matrix.M41 == nil then
        -- 3x2 matrix
        return new(Vector2, position.X * matrix.M11 + position.Y * matrix.M21 + matrix.M31, 
                            position.X * matrix.M12 + position.Y * matrix.M22 + matrix.M32
                            )
    elseif matrix.X == nil then
        -- 4x4 matrix
        return new(Vector2, position.X * matrix.M11 + position.Y * matrix.M21 + matrix.M41, 
                            position.X * matrix.M12 + position.Y * matrix.M22 + matrix.M42
                            )
    else 
        -- Quaternion
        local x2 = matrix.X + matrix.X
        local y2 = matrix.Y + matrix.Y
        local z2 = matrix.Z + matrix.Z

        local wz2 = matrix.W * z2
        local xx2 = matrix.X * x2
        local xy2 = matrix.X * y2
        local yy2 = matrix.Y * y2
        local zz2 = matrix.Z * z2

        return new(Vector2, position.X * (1.0 - yy2 - zz2) + position.Y * (xy2 - wz2),
                            position.X * (xy2 + wz2) + position.Y * (1.0 - xx2 - zz2)
                                )    
    end
end

Vector2.TransformNormal = function (normal, matrix)
    if matrix.M41 == nil then
        -- 3.2 matirx
        return new(Vector2, normal.X * matrix.M11 + normal.Y * matrix.M21, 
                            normal.X * matrix.M12 + normal.Y * matrix.M22
                                )
    else
        -- 4x4 matrix
        return new(Vector2, normal.X * matrix.M11 + normal.Y * matrix.M21, 
                            normal.X * matrix.M12 + normal.Y * matrix.M22
                                )
    end
 end

System.defStc("System.Numerics.Vector2", Vector2)
end

-- CoreSystemLib: Numerics/Vector3.lua
do
local System = System
local SystemNumerics = System.Numerics

local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1
local IFormattable = System.IFormattable

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Vector3 = {}

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3?view=netframework-4.7.2#constructors
Vector3.__ctor__ = function(this, X, Y, Z)
    if Z == nil then
        -- 1 var constructor
        if Y == nil then
            this.X = X or 0
            this.Y = X or 0
            this.Z = X or 0
        -- 2 var constructor
        else
            this.X = X.X
            this.Y = X.Y
            this.Z = Y or 0
        end
    -- 3 var constructor
    else
        this.X = X or 0
        this.Y = Y or 0
        this.Z = Z or 0
    end
    local mt = getmetatable(this)
    mt.__unm = Vector3.op_UnaryNegation
    setmetatable(this, mt)
end

Vector3.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T), IFormattable }
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3?view=netframework-4.7.2#properties
Vector3.getOne = function() return new(Vector3, 1.0, 1.0, 1.0) end
Vector3.getZero = function() return new(Vector3, 0, 0, 0) end
Vector3.getUnitX = function() return new(Vector3, 1.0, 0.0, 0.0) end
Vector3.getUnitY = function() return new(Vector3, 0.0, 1.0, 0.0) end
Vector3.getUnitZ = function() return new(Vector3, 0.0, 0.0, 1.0) end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.copyto?view=netframework-4.7.2#System_Numerics_Vector3_CopyTo_System_Single___
Vector3.CopyTo = function(this, array, index)
    if index == nil then
        index = 0
    end

    if array == nil then
        System.throw(System.NullReferenceException())
    end

    if index < 0 or index >= #array then
        System.throw(System.ArgumentOutOfRangeException())
    end
    if (#array - index) < 3 then
        System.throw(System.ArgumentException())
    end

    array:set(index, this.X)
    array:set(index + 1, this.Y)
    array:set(index + 2, this.Z)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.equals?view=netframework-4.7.2#System_Numerics_Vector3_Equals_System_Object_
Vector3.Equals = function(this, other)
    if not (System.is(other, Vector3)) then
        return false
    end
    other = System.cast(Vector3, other)
    return this.X == other.X and this.Y == other.Y and this.Z == other.Z
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.dot?view=netframework-4.7.2#System_Numerics_Vector3_Dot_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Dot = function(vector1, vector2)
    return vector1.X * vector2.X + vector1.Y * vector2.Y + vector1.Z * vector2.Z
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.min?view=netframework-4.7.2#System_Numerics_Vector3_Min_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Min = function(value1, value2)
    return new(Vector3, (value1.X < value2.X) and value1.X or value2.X, (value1.Y < value2.Y) and value1.Y or value2.Y, (value1.Z < value2.Z) and value1.Z or value2.Z)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.max?view=netframework-4.7.2#System_Numerics_Vector3_Max_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Max = function(value1, value2)
    return new(Vector3, (value1.X > value2.X) and value1.X or value2.X, (value1.Y > value2.Y) and value1.Y or value2.Y, (value1.Z > value2.Z) and value1.Z or value2.Z)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.abs?view=netframework-4.7.2#System_Numerics_Vector3_Abs_System_Numerics_Vector3_
Vector3.Abs = function(value)
    return new(Vector3, abs(value.X), abs(value.Y), abs(value.Z))
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.squareroot?view=netframework-4.7.2#System_Numerics_Vector3_SquareRoot_System_Numerics_Vector3_
Vector3.SquareRoot = function(value)
    return new(Vector3, System.ToSingle(sqrt(value.X)), System.ToSingle(sqrt(value.Y)), System.ToSingle(sqrt(value.Z)))
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.add?view=netframework-4.7.2#System_Numerics_Vector3_Add_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.op_Addition = function(left, right)
    return new(Vector3, left.X + right.X, left.Y + right.Y, left.Z + right.Z)
end

Vector3.Add = function(left, right)
    return Vector3.op_Addition(left, right)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.subtract?view=netframework-4.7.2#System_Numerics_Vector3_Subtract_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.op_Subtraction = function(left, right)
    return new(Vector3, left.X - right.X, left.Y - right.Y, left.Z - right.Z)
end

Vector3.Subtract = function(left, right)
    return Vector3.op_Subtraction(left, right)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.multiply?view=netframework-4.7.2#System_Numerics_Vector3_Multiply_System_Single_System_Numerics_Vector3_
Vector3.op_Multiply = function(left, right)
    if type(left) == "number" then
        left = new(Vector3, left)
    end

    if type(right) == "number" then
        right = new(Vector3, right)
    end
    return new(Vector3, left.X * right.X, left.Y * right.Y, left.Z * right.Z)
end

Vector3.Multiply = function(left, right)
    return Vector3.op_Multiply(left, right)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.divide?view=netframework-4.7.2#System_Numerics_Vector3_Divide_System_Numerics_Vector3_System_Single_
Vector3.op_Division = function(left, right)
    if type(right) == "number" then
        return Vector3.op_Multiply(left, 1.0 / right)
    end
    return new(Vector3, left.X / right.X, left.Y / right.Y, left.Z / right.Z)
end

Vector3.Divide = function(left, right)
    return Vector3.op_Division(left, right)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.negate?view=netframework-4.7.2#System_Numerics_Vector3_Negate_System_Numerics_Vector3_
Vector3.op_UnaryNegation = function(value)
    return Vector3.op_Subtraction(Vector3.getZero(), value)
end

Vector3.Negate = function(value)
    return - value
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.equals?view=netframework-4.7.2#System_Numerics_Vector3_Equals_System_Numerics_Vector3_
Vector3.op_Equality = function(left, right)
    return (left.X == right.X and left.Y == right.Y and left.Z == right.Z)
end

Vector3.op_Inequality = function(left, right)
    return (left.X ~= right.X or left.Y ~= right.Y or left.Z ~= right.Z)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.gethashcode?view=netframework-4.7.2#System_Numerics_Vector3_GetHashCode
Vector3.GetHashCode = function(this)
    local hash = this.X:GetHashCode()
    hash = SystemNumerics.HashCodeHelper.CombineHashCodes(hash, this.Y:GetHashCode())
    hash = SystemNumerics.HashCodeHelper.CombineHashCodes(hash, this.Z:GetHashCode())
    return hash
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.tostring?view=netframework-4.7.2#System_Numerics_Vector3_ToString
Vector3.ToString = function(this)
    local sb = System.StringBuilder()
    local separator = 44 --[[',']]
    sb:AppendChar(60 --[['<']])
    sb:Append((this.X):ToString())
    sb:AppendChar(separator)
    sb:AppendChar(32 --[[' ']])
    sb:Append((this.Y):ToString())
    sb:AppendChar(separator)
    sb:AppendChar(32 --[[' ']])
    sb:Append((this.Z):ToString())
    sb:AppendChar(62 --[['>']])
    return sb:ToString()
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.length?view=netframework-4.7.2#System_Numerics_Vector3_Length
Vector3.Length = function(this)
    local ls = this.X * this.X + this.Y * this.Y + this.Z * this.Z
    return System.ToSingle(sqrt(ls))
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.lengthsquared?view=netframework-4.7.2#System_Numerics_Vector3_LengthSquared
Vector3.LengthSquared = function(this)
    return this.X * this.X + this.Y * this.Y + this.Z * this.Z
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.distance?view=netframework-4.7.2#System_Numerics_Vector3_Distance_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Distance = function(value1, value2)
    local dx = value1.X - value2.X
    local dy = value1.Y - value2.Y
    local dz = value1.Z - value2.Z

    local ls = dx * dx + dy * dy + dz * dz

    return System.ToSingle(sqrt(ls))
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.distancesquared?view=netframework-4.7.2#System_Numerics_Vector3_DistanceSquared_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.DistanceSquared = function(value1, value2)
    local dx = value1.X - value2.X
    local dy = value1.Y - value2.Y
    local dz = value1.Z - value2.Z

    return dx * dx + dy * dy + dz * dz
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.normalize?view=netframework-4.7.2#System_Numerics_Vector3_Normalize_System_Numerics_Vector3_
Vector3.Normalize = function(value)
    local ls = value.X * value.X + value.Y * value.Y + value.Z * value.Z
    local length = System.ToSingle(sqrt(ls))
    return new(Vector3, value.X / length, value.Y / length, value.Z / length)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.cross?view=netframework-4.7.2#System_Numerics_Vector3_Cross_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Cross = function(vector1, vector2)
    return new(Vector3, vector1.Y * vector2.Z - vector1.Z * vector2.Y, vector1.Z * vector2.X - vector1.X * vector2.Z, vector1.X * vector2.Y - vector1.Y * vector2.X)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.reflect?view=netframework-4.7.2#System_Numerics_Vector3_Reflect_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Reflect = function(vector, normal)
    local dot = vector.X * normal.X + vector.Y * normal.Y + vector.Z * normal.Z
    local tempX = normal.X * dot * 2
    local tempY = normal.Y * dot * 2
    local tempZ = normal.Z * dot * 2
    return new(Vector3, vector.X - tempX, vector.Y - tempY, vector.Z - tempZ)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.clamp?view=netframework-4.7.2#System_Numerics_Vector3_Clamp_System_Numerics_Vector3_System_Numerics_Vector3_System_Numerics_Vector3_
Vector3.Clamp = function(value1, min, max)
    local x = value1.X
    x = (x > max.X) and max.X or x
    x = (x < min.X) and min.X or x

    local y = value1.Y
    y = (y > max.Y) and max.Y or y
    y = (y < min.Y) and min.Y or y

    local z = value1.Z
    z = (z > max.Z) and max.Z or z
    z = (z < min.Z) and min.Z or z

    return new(Vector3, x, y, z)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.lerp?view=netframework-4.7.2#System_Numerics_Vector3_Lerp_System_Numerics_Vector3_System_Numerics_Vector3_System_Single_
Vector3.Lerp = function(value1, value2, amount)
    return new(Vector3, value1.X + (value2.X - value1.X) * amount, value1.Y + (value2.Y - value1.Y) * amount, value1.Z + (value2.Z - value1.Z) * amount)
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.transform?view=netframework-4.7.2#System_Numerics_Vector3_Transform_System_Numerics_Vector3_System_Numerics_Matrix4x4_
-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.transform?view=netframework-4.7.2#System_Numerics_Vector3_Transform_System_Numerics_Vector3_System_Numerics_Quaternion_
Vector3.Transform = function(position, matrix)
    if matrix.X then
        -- quaternion
        local x2 = matrix.X + matrix.X
        local y2 = matrix.Y + matrix.Y
        local z2 = matrix.Z + matrix.Z
  
        local wx2 = matrix.W * x2
        local wy2 = matrix.W * y2
        local wz2 = matrix.W * z2
        local xx2 = matrix.X * x2
        local xy2 = matrix.X * y2
        local xz2 = matrix.X * z2
        local yy2 = matrix.Y * y2
        local yz2 = matrix.Y * z2
        local zz2 = matrix.Z * z2
  
        return new(Vector3, position.X * (1.0 - yy2 - zz2) + position.Y * (xy2 - wz2) + position.Z * (xz2 + wy2), 
                            position.X * (xy2 + wz2) + position.Y * (1.0 - xx2 - zz2) + position.Z * (yz2 - wx2), 
                            position.X * (xz2 - wy2) + position.Y * (yz2 + wx2) + position.Z * (1.0 - xx2 - yy2)
                        )
    else
        -- 4x4 matrix
        return new(Vector3, position.X * matrix.M11 + position.Y * matrix.M21 + position.Z * matrix.M31 + matrix.M41, 
                            position.X * matrix.M12 + position.Y * matrix.M22 + position.Z * matrix.M32 + matrix.M42, 
                            position.X * matrix.M13 + position.Y * matrix.M23 + position.Z * matrix.M33 + matrix.M43
                        ) 
    end 
end

-- https://docs.microsoft.com/en-us/dotnet/api/system.numerics.vector3.transformnormal?view=netframework-4.7.2#System_Numerics_Vector3_TransformNormal_System_Numerics_Vector3_System_Numerics_Matrix4x4_
Vector3.TransformNormal = function(normal, matrix)
    return new(Vector3, normal.X * matrix.M11 + normal.Y * matrix.M21 + normal.Z * matrix.M31,
                        normal.X * matrix.M12 + normal.Y * matrix.M22 + normal.Z * matrix.M32, 
                        normal.X * matrix.M13 + normal.Y * matrix.M23 + normal.Z * matrix.M33
                    )
end

System.defStc("System.Numerics.Vector3", Vector3)

end

-- CoreSystemLib: Numerics/Vector4.lua
do
local System = System
local SystemNumerics = System.Numerics

local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt

local IComparable = System.IComparable
local IComparable_1 = System.IComparable_1
local IEquatable_1 = System.IEquatable_1
local IFormattable = System.IFormattable

local new = function (cls, ...)
    local this = setmetatable({}, cls)
    return this, cls.__ctor__(this, ...)
end

local Vector4 = {}

Vector4.__ctor__ = function(this, X, Y, Z, W)
    if W == nil then
        if Z == nil then
            -- 1 var constructor
            if Y == nil then
                this.X = X or 0
                this.Y = X or 0
                this.Z = X or 0
                this.W = X or 0
            else
            -- 2 var constructor
                this.X = X.X
                this.Y = X.Y
                this.Z = X.Z
                this.W = Y or 0
            end
        else
        -- 3 var constructor
        this.X = X.X
        this.Y = X.Y
        this.Z = Y or 0
        this.W = Z or 0
        end
    else
    -- 4 var constructor
        this.X = X or 0
        this.Y = Y or 0
        this.Z = Z or 0
        this.W = W or 0
    end
    local mt = getmetatable(this)
    mt.__unm = Vector4.op_UnaryNegation
    setmetatable(this, mt)
end

Vector4.base = function (_, T)
    return { IComparable, IComparable_1(T), IEquatable_1(T), IFormattable }
end

Vector4.getOne = function() return new(Vector4, 1.0, 1.0, 1.0, 1.0) end
Vector4.getZero = function() return new(Vector4, 0, 0, 0, 0) end
Vector4.getUnitX = function() return new(Vector4, 1.0, 0.0, 0.0, 0.0) end
Vector4.getUnitY = function() return new(Vector4, 0.0, 1.0, 0.0, 0.0) end
Vector4.getUnitZ = function() return new(Vector4, 0.0, 0.0, 1.0, 0.0) end
Vector4.getUnitW = function() return new(Vector4, 0.0, 0.0, 0.0, 1.0) end

Vector4.CopyTo = function(this, array, index)
    if index == nil then
        index = 0
    end

    if array == nil then
        System.throw(System.NullReferenceException())
    end

    if index < 0 or index >= #array then
        System.throw(System.ArgumentOutOfRangeException())
    end
    if (#array - index) < 4 then
        System.throw(System.ArgumentException())
    end

    array:set(index, this.X)
    array:set(index + 1, this.Y)
    array:set(index + 2, this.Z)
    array:set(index + 3, this.W)
end

Vector4.Equals = function(this, other)
    if not (System.is(other, Vector4)) then
        return false
    end
    other = System.cast(Vector4, other)
    return this.X == other.X and this.Y == other.Y and this.Z == other.Z and this.W == other.W
end

Vector4.Dot = function(vector1, vector2)
    return vector1.X * vector2.X + vector1.Y * vector2.Y + vector1.Z * vector2.Z + vector1.W * vector2.W
end

Vector4.Min = function(value1, value2)
    return new(Vector4, (value1.X < value2.X) and value1.X or value2.X, (value1.Y < value2.Y) and value1.Y or value2.Y, (value1.Z < value2.Z) and value1.Z or value2.Z, (value1.W < value2.W) and value1.W or value2.W)
end

Vector4.Max = function(value1, value2)
    return new(Vector4, (value1.X > value2.X) and value1.X or value2.X, (value1.Y > value2.Y) and value1.Y or value2.Y, (value1.Z > value2.Z) and value1.Z or value2.Z, (value1.W > value2.W) and value1.W or value2.W)
end

Vector4.Abs = function(value)
    return new(Vector4, abs(value.X), abs(value.Y), abs(value.Z), abs(value.W))
end

Vector4.SquareRoot = function(value)
    return new(Vector4, System.ToSingle(sqrt(value.X)), System.ToSingle(sqrt(value.Y)), System.ToSingle(sqrt(value.Z)), System.ToSingle(sqrt(value.W)))
end

Vector4.op_Addition = function(left, right)
    return new(Vector4, left.X + right.X, left.Y + right.Y, left.Z + right.Z, left.W + right.W)
end

Vector4.Add = function(left, right)
    return Vector4.op_Addition(left, right)
end

Vector4.op_Subtraction = function(left, right)
    return new(Vector4, left.X - right.X, left.Y - right.Y, left.Z - right.Z, left.W - right.W)
end

Vector4.Subtract = function(left, right)
    return Vector4.op_Subtraction(left, right)
end

Vector4.op_Multiply = function(left, right)
    if type(left) == "number" then
        left = new(Vector4, left)
    end

    if type(right) == "number" then
        right = new(Vector4, right)
    end
    return new(Vector4, left.X * right.X, left.Y * right.Y, left.Z * right.Z, left.W * right.W)
end

Vector4.Multiply = function(left, right)
    return Vector4.op_Multiply(left, right)
end

Vector4.op_Division = function(left, right)
    if type(right) == "number" then
        return Vector4.op_Multiply(left, 1.0 / right)
    end
    return new(Vector4, left.X / right.X, left.Y / right.Y, left.Z / right.Z, left.W / right.W)
end

Vector4.Divide = function(left, right)
    return Vector4.op_Division(left, right)
end

Vector4.op_UnaryNegation = function(value)
    return Vector4.op_Subtraction(Vector4.getZero(), value)
end

Vector4.Negate = function(value)
    return - value
end

Vector4.op_Equality = function(left, right)
    return left.X == right.X and left.Y == right.Y and left.Z == right.Z and left.W == right.W
end

Vector4.op_Inequality = function(left, right)
    return not (Vector4.op_Equality(left, right))
end

Vector4.GetHashCode = function(this)
    local hash = this.X:GetHashCode()
    hash = SystemNumerics.HashCodeHelper.CombineHashCodes(hash, this.Y:GetHashCode())
    hash = SystemNumerics.HashCodeHelper.CombineHashCodes(hash, this.Z:GetHashCode())
    hash = SystemNumerics.HashCodeHelper.CombineHashCodes(hash, this.W:GetHashCode())
      
    return hash
end

Vector4.ToString = function(this)
    local sb = System.StringBuilder()
    local separator = 44 --[[',']]
    sb:AppendChar(60 --[['<']])
    sb:Append((this.X):ToString())
    sb:AppendChar(separator)
    sb:AppendChar(32 --[[' ']])
    sb:Append((this.Y):ToString())
    sb:AppendChar(separator)
    sb:AppendChar(32 --[[' ']])
    sb:Append((this.Z):ToString())
    sb:AppendChar(separator)
    sb:AppendChar(32 --[[' ']])
    sb:Append((this.W):ToString())
    sb:AppendChar(62 --[['>']])
    return sb:ToString()
end

Vector4.Length = function(this)
    local ls = this.X * this.X + this.Y * this.Y + this.Z * this.Z + this.W * this.W
    return System.ToSingle(sqrt(ls))
end

Vector4.LengthSquared = function(this)
    return this.X * this.X + this.Y * this.Y + this.Z * this.Z + this.W * this.W
end

Vector4.Distance = function(value1, value2)
    local dx = value1.X - value2.X
    local dy = value1.Y - value2.Y
    local dz = value1.Z - value2.Z
    local dw = value1.W - value2.W

    local ls = dx * dx + dy * dy + dz * dz + dw * dw

    return System.ToSingle(sqrt(ls))
end

Vector4.DistanceSquared = function(value1, value2)
    local dx = value1.X - value2.X
    local dy = value1.Y - value2.Y
    local dz = value1.Z - value2.Z
    local dw = value1.W - value2.W

    return dx * dx + dy * dy + dz * dz + dw * dw
end

Vector4.Normalize = function(vector)
    local ls = vector.X * vector.X + vector.Y * vector.Y + vector.Z * vector.Z + vector.W * vector.W
    local invNorm = 1.0 / System.ToSingle(sqrt(ls))

    return new(Vector4, vector.X * invNorm, vector.Y * invNorm, vector.Z * invNorm, vector.W * invNorm)
end

Vector4.Clamp = function(value1, min, max)
    local x = value1.X
    x = (x > max.X) and max.X or x
    x = (x < min.X) and min.X or x

    local y = value1.Y
    y = (y > max.Y) and max.Y or y
    y = (y < min.Y) and min.Y or y

    local z = value1.Z
    z = (z > max.Z) and max.Z or z
    z = (z < min.Z) and min.Z or z

    local w = value1.W
    w = (w > max.W) and max.W or w
    w = (w < min.W) and min.W or w

    return new(Vector4, x, y, z, w)
end

Vector4.Lerp = function(value1, value2, amount)
    return new(Vector4, value1.X + (value2.X - value1.X) * amount, value1.Y + (value2.Y - value1.Y) * amount, value1.Z + (value2.Z - value1.Z) * amount, value1.W + (value2.W - value1.W) * amount)
end

Vector4.Transform = function(position, matrix)
    if matrix.X == nil then
        -- 4x4 matrix
        if matrix.W == nil then
            if matrix.Z == nil then
                -- vector2
                return new(Vector4, position.X * matrix.M11 + position.Y * matrix.M21 + matrix.M41, 
                                    position.X * matrix.M12 + position.Y * matrix.M22 + matrix.M42,
                                    position.X * matrix.M13 + position.Y * matrix.M23 + matrix.M43, 
                                    position.X * matrix.M14 + position.Y * matrix.M24 + matrix.M44
                                )
            else
                -- vector3
                return new(Vector4, position.X * matrix.M11 + position.Y * matrix.M21 + position.Z * matrix.M31 + matrix.M41, 
                                    position.X * matrix.M12 + position.Y * matrix.M22 + position.Z * matrix.M32 + matrix.M42, 
                                    position.X * matrix.M13 + position.Y * matrix.M23 + position.Z * matrix.M33 + matrix.M43, 
                                    position.X * matrix.M14 + position.Y * matrix.M24 + position.Z * matrix.M34 + matrix.M44
                                )
            end
        else
            -- vector4
            return new(Vector4, position.X * matrix.M11 + position.Y * matrix.M21 + position.Z * matrix.M31 + position.W * matrix.M41, 
                                position.X * matrix.M12 + position.Y * matrix.M22 + position.Z * matrix.M32 + position.W * matrix.M42,
                                position.X * matrix.M13 + position.Y * matrix.M23 + position.Z * matrix.M33 + position.W * matrix.M43, 
                                position.X * matrix.M14 + position.Y * matrix.M24 + position.Z * matrix.M34 + position.W * matrix.M44
                            )
        end
    else
        -- quaternion
        if matrix.W == nil then
            if matrix.Z == nil then
                -- vector2
                local x2 = matrix.X + matrix.X
                local y2 = matrix.Y + matrix.Y
                local z2 = matrix.Z + matrix.Z

                local wx2 = matrix.W * x2
                local wy2 = matrix.W * y2
                local wz2 = matrix.W * z2
                local xx2 = matrix.X * x2
                local xy2 = matrix.X * y2
                local xz2 = matrix.X * z2
                local yy2 = matrix.Y * y2
                local yz2 = matrix.Y * z2
                local zz2 = matrix.Z * z2

                return new(Vector4, position.X * (1.0 - yy2 - zz2) + position.Y * (xy2 - wz2), 
                                    position.X * (xy2 + wz2) + position.Y * (1.0 - xx2 - zz2), 
                                    position.X * (xz2 - wy2) + position.Y * (yz2 + wx2), 
                                    1.0
                                )
            else
                -- vector3
                local x2 = matrix.X + matrix.X
                local y2 = matrix.Y + matrix.Y
                local z2 = matrix.Z + matrix.Z

                local wx2 = matrix.W * x2
                local wy2 = matrix.W * y2
                local wz2 = matrix.W * z2
                local xx2 = matrix.X * x2
                local xy2 = matrix.X * y2
                local xz2 = matrix.X * z2
                local yy2 = matrix.Y * y2
                local yz2 = matrix.Y * z2
                local zz2 = matrix.Z * z2

                return new(Vector4, position.X * (1.0 - yy2 - zz2) + position.Y * (xy2 - wz2) + position.Z * (xz2 + wy2), 
                                    position.X * (xy2 + wz2) + position.Y * (1.0 - xx2 - zz2) + position.Z * (yz2 - wx2), 
                                    position.X * (xz2 - wy2) + position.Y * (yz2 + wx2) + position.Z * (1.0 - xx2 - yy2), 
                                    1.0
                                )
            end
        else
            -- vector4
            local x2 = matrix.X + matrix.X
            local y2 = matrix.Y + matrix.Y
            local z2 = matrix.Z + matrix.Z

            local wx2 = matrix.W * x2
            local wy2 = matrix.W * y2
            local wz2 = matrix.W * z2
            local xx2 = matrix.X * x2
            local xy2 = matrix.X * y2
            local xz2 = matrix.X * z2
            local yy2 = matrix.Y * y2
            local yz2 = matrix.Y * z2
            local zz2 = matrix.Z * z2

            return new(Vector4, position.X * (1.0 - yy2 - zz2) + position.Y * (xy2 - wz2) + position.Z * (xz2 + wy2), 
                                position.X * (xy2 + wz2) + position.Y * (1.0 - xx2 - zz2) + position.Z * (yz2 - wx2), 
                                position.X * (xz2 - wy2) + position.Y * (yz2 + wx2) + position.Z * (1.0 - xx2 - yy2), 
                                position.W
                            )
        end
    end
end

System.defStc("System.Numerics.Vector4", Vector4)

end

-- Generated by CSharp.lua Compiler
do
local System = System
local Linq = System.Linq.Enumerable
local SystemNumerics = System.Numerics
local WrapperAPI
local WrapperDatabase
local WrapperHelpers
local WrapperWoW
local ListVector3
System.import(function (out)
  WrapperAPI = Wrapper.API
  WrapperDatabase = Wrapper.Database
  WrapperHelpers = Wrapper.Helpers
  WrapperWoW = Wrapper.WoW
  ListVector3 = System.List(WrapperWoW.Vector3)
end)
System.namespace("Wrapper", function (namespace)
  namespace.class("BotBase", function (namespace)
    local Pulse
    Pulse = function (this)
    end
    return {
      Pulse = Pulse
    }
  end)


  namespace.class("DataLoggerBase", function (namespace)
    local Pulse, HandleMapClicks, HandleHunterLogic, GetNextCastLocation, Spiral, class, __ctor__
    namespace.class("DataLoggerBaseUI", function (namespace)
      return {}
    end)
    __ctor__ = function (this)
      this.LastHandledTime = GetTime()
      this.CastTimeStamp = GetTime()
      this.ManualScanLocations = ListVector3()
    end
    Pulse = function (this)
      local _StdUI
      local IsHunter = (select(2,__LB__.UnitTagHandler(UnitClass, "player")) == "HUNTER")

      if class.UIData == nil then
        _StdUI = LibStub("StdUi"):NewInstance()

        --#region UIConfigData
        --[[
                   
                          local BroBotBlueSolid = {r=0.12156862745, g=0.21176470588, b=0.41176470588, a=1}
                          local BroBotBlueAlpha = {r=0.12156862745, g=0.21176470588, b=0.41176470588, a=0.8}


                          _StdUI.config = {
                               font        = {
                                  -- family    = font,
                                   size      = 12,
                                   titleSize = 18,
                                   effect    = 'NONE',
                                   strata    = 'OVERLAY',
                                   color     = {
                                       normal   = { r = 1, g = 1, b = 1, a = 1 },
                                       disabled = { r = 0.55, g = 0.55, b = 0.55, a = 1 },
                                       header   = { r = 1, g = 1, b = 1, a = 1 },
                                   },

                               },

                               backdrop = {
                                   texture        = "Interface\\Buttons\\WHITE8X8",
                                   panel          = BroBotBlueAlpha,
                                   slider         = BroBotBlueAlpha,

                                   highlight      = { r = 0.0, g = 0.0, b = 0.5, a = 0.5 },
                                   button         = BroBotBlueSolid,
                                   buttonDisabled = { r = 0.15, g = 0.15, b = 0.15, a = 1 },

                                   border         = { r = 1, g = 1, b = 1, a = 0.25 },
                                   borderDisabled = { r = 0.00, g = 0.00, b = 0.50, a = 1 }
                               },

                               progressBar = {
                                   color = { r = 0, g = 0.9, b = 1, a = 0.5 },
                               },

                               highlight   = {
                                   color = BroBotBlueSolid,
                                   blank = { r = 0, g = 0, b = 0, a = 0 }
                               },

                               dialog      = {
                                   width  = 400,
                                   height = 100,
                                   button = {
                                       width  = 100,
                                       height = 20,
                                       margin = 5
                                   }
                               },

                               tooltip     = {
                                   padding = 10
                               }
                           };

                   
                   ]]
        --#endregion

        class.UIData = class.DataLoggerBaseUI()
        class.UIData.MainUIFrame = _StdUI:Window(_G["UIParent"], 500, IsHunter and 600 or 400, "BroBot Data Logger")
        class.UIData.MainUIFrame:SetPoint("CENTER", 0, 0)
        class.UIData.MainUIFrame:Show()

        class.UIData.EnabledCheckBox = _StdUI:Checkbox(class.UIData.MainUIFrame, "Enable Recording", 150, 25)
        _StdUI:GlueTop(class.UIData.EnabledCheckBox, class.UIData.MainUIFrame, - 140, - 50, "TOP")

        class.UIData.RecordNPCS = _StdUI:Checkbox(class.UIData.MainUIFrame, "Record NPCS", 150, 25)
        _StdUI:GlueTop(class.UIData.RecordNPCS, class.UIData.MainUIFrame, - 140, - 80, "TOP")

        class.UIData.RecordGameObjects = _StdUI:Checkbox(class.UIData.MainUIFrame, "Record GameObjects", 150, 25)
        _StdUI:GlueTop(class.UIData.RecordGameObjects, class.UIData.MainUIFrame, - 140, - 110, "TOP")

        class.UIData.RangeEditBox = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "175")
        class.UIData.RangeEditBox:SetValue(175)

        _StdUI:GlueTop(class.UIData.RangeEditBox, class.UIData.MainUIFrame, - 140, - 160, "TOP")
        local label = _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.RangeEditBox, "Local Scan Range (200 max)", "TOP")

        class.UIData.NeedsSaveText = _StdUI:Label(class.UIData.MainUIFrame, "Needs To Save: " .. System.toString(WrapperDatabase.WoWDatabase.getHasDirtyMaps()), 12, nil, 150, 25)
        _StdUI:GlueTop(class.UIData.NeedsSaveText, class.UIData.MainUIFrame, - 140, - 190, "TOP")

        class.UIData.MapIdText = _StdUI:Label(class.UIData.MainUIFrame, "MapId: " ..  __LB__.GetMapId(), 12, nil, 150, 25)
        class.UIData.NumberOfHerbsText = _StdUI:Label(class.UIData.MainUIFrame, "Herb Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllHerbLocations(), 12, nil, 150, 25)
        class.UIData.NumberOrOresText = _StdUI:Label(class.UIData.MainUIFrame, "Ore Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllOreLocations(), 12, nil, 150, 25)
        class.UIData.NumberOfVendorsText = _StdUI:Label(class.UIData.MainUIFrame, "Vendors: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Vendors, 12, nil, 150, 25)
        class.UIData.NumberOfRepairText = _StdUI:Label(class.UIData.MainUIFrame, "Repair: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Repair, 12, nil, 150, 25)
        class.UIData.NumberOfFlightMasters = _StdUI:Label(class.UIData.MainUIFrame, "FlightMasters: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).FlightMaster, 12, nil, 150, 25)
        class.UIData.NumberOfInnKeepers = _StdUI:Label(class.UIData.MainUIFrame, "InnKeepers: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).InnKeepers, 12, nil, 150, 25)
        class.UIData.NumberOfMailBoxes = _StdUI:Label(class.UIData.MainUIFrame, "MailBoxes: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).MailBoxes, 12, nil, 150, 25)


        class.UIData.ScanCurrentArea = _StdUI:HighlightButton(class.UIData.MainUIFrame, 150, 25, "Scan Current Area")
        class.UIData.ScanCurrentArea:SetScript("OnClick", function ()
          for _, unit in System.each(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
            return x.Value.ObjectType == 5 --[[EObjectType.Unit]]
          end)) do
            WrapperDatabase.WoWDatabase.InsertNpcIfRequired(System.as(unit.Value, WrapperWoW.WoWUnit))
          end

          for _, unit in System.each(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
            return x.Value.ObjectType == 8 --[[EObjectType.GameObject]]
          end)) do
            WrapperDatabase.WoWDatabase.InsertNodeIfRequired(unit.Value)
          end
        end, System.Delegate)

        _StdUI:GlueTop(class.UIData.ScanCurrentArea, class.UIData.MainUIFrame, - 140, - 230, "TOP")



        if IsHunter then
          class.UIData.HunterScanMode = _StdUI:Checkbox(class.UIData.MainUIFrame, "Hunter Scan Mode", 150, 25)
          _StdUI:GlueTop(class.UIData.HunterScanMode, class.UIData.MainUIFrame, - 140, - 260, "TOP")

          class.UIData.HunterGridRangeEntry = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "175")
          class.UIData.HunterGridRangeEntry:SetValue(175)
          _StdUI:GlueTop(class.UIData.HunterGridRangeEntry, class.UIData.MainUIFrame, - 140, - 310, "TOP")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.HunterGridRangeEntry, "Scan Grid Size (175 is good)", "TOP")

          class.UIData.HunterScanGridHeightOffsetEntry = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "0")
          class.UIData.HunterScanGridHeightOffsetEntry:SetValue(0)
          _StdUI:GlueTop(class.UIData.HunterScanGridHeightOffsetEntry, class.UIData.MainUIFrame, - 140, - 360, "TOP")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.HunterScanGridHeightOffsetEntry, "Hunter Scan Height Offset", "TOP")

          class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset = _StdUI:NumericBox(class.UIData.MainUIFrame, 150, 25, "7500")
          class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset:SetValue(7500)
          _StdUI:GlueTop(class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset, class.UIData.MainUIFrame, - 140, - 400, "TOP")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset, "Hunter Scan Max Horizontal Range", "TOP")


          class.UIData.NumberOfManualScanNodes = _StdUI:Label(class.UIData.MainUIFrame, "Manual Scan Nodes Count: " .. #this.ManualScanLocations, 12, nil, 150, 25)
          _StdUI:GlueTop(class.UIData.NumberOfManualScanNodes, class.UIData.MainUIFrame, - 140, - 430, "TOP")


          class.UIData.ResetManualScanNodes = _StdUI:HighlightButton(class.UIData.MainUIFrame, 150, 25, "Reset Manual Scan Nodes")
          class.UIData.ResetManualScanNodes:SetScript("OnClick", function ()
            this.ManualScanLocations:Clear()
          end, System.Delegate)

          _StdUI:GlueTop(class.UIData.ResetManualScanNodes, class.UIData.MainUIFrame, - 140, - 460, "TOP")



          class.UIData.ProfileNameBox = _StdUI:EditBox(class.UIData.MainUIFrame, 150, 25, "")
          _StdUI:AddLabel(class.UIData.MainUIFrame, class.UIData.ProfileNameBox, "Profile Name", "TOP")
          _StdUI:GlueTop(class.UIData.ProfileNameBox, class.UIData.MainUIFrame, - 140, - 490, "TOP")

          local DataBaseProfileFolder = System.toString( __LB__.GetBaseDirectory()) .. "\\BroBot\\Database\\Profiles\\"
          if not  __LB__.DirectoryExists(DataBaseProfileFolder) then
             __LB__.CreateDirectory(DataBaseProfileFolder)
          end


          class.UIData.ProfileSaveButton = _StdUI:HighlightButton(class.UIData.MainUIFrame, 150, 25, "Save Profile")
          class.UIData.ProfileSaveButton:SetScript("OnClick", function ()
             __LB__.WriteFile(System.toString(DataBaseProfileFolder) .. System.toString(class.UIData.ProfileNameBox:GetValue(System.String)) .. ".json", LibJSON.Serialize(this.ManualScanLocations), false)
          end, System.Delegate)

          _StdUI:GlueTop(class.UIData.ProfileSaveButton, class.UIData.MainUIFrame, - 140, - 520, "TOP")



          class.UIData.ProfileLoadButton = _StdUI:HighlightButton(class.UIData.MainUIFrame, 150, 25, "Load Profile")
          class.UIData.ProfileLoadButton:SetScript("OnClick", function ()
            if not  __LB__.FileExists(System.toString(DataBaseProfileFolder) .. System.toString(class.UIData.ProfileNameBox:GetValue(System.String)) .. ".json") then
              System.Console.WriteLine("Dont be a retard. file is missing")
              return
            end

            local TempList = LibJSON.Deserialize( __LB__.ReadFile(System.toString(DataBaseProfileFolder) .. System.toString(class.UIData.ProfileNameBox:GetValue(System.String)) .. ".json"))


            this.ManualScanLocations:Clear()

            for _, point in System.each(TempList) do
              this.ManualScanLocations:Add(WrapperWoW.Vector3(point.X, point.Y, point.Z))
            end

            System.Console.WriteLine("Restored: " .. #this.ManualScanLocations .. " points")
          end, System.Delegate)

          _StdUI:GlueTop(class.UIData.ProfileLoadButton, class.UIData.MainUIFrame, - 140, - 550, "TOP")
        end

        _StdUI:GlueTop(class.UIData.MapIdText, class.UIData.MainUIFrame, 75, - 50, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfHerbsText, class.UIData.MainUIFrame, 75, - 80, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOrOresText, class.UIData.MainUIFrame, 75, - 110, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfVendorsText, class.UIData.MainUIFrame, 75, - 140, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfRepairText, class.UIData.MainUIFrame, 75, - 170, "TOP")

        _StdUI:GlueTop(class.UIData.NumberOfFlightMasters, class.UIData.MainUIFrame, 75, - 200, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfInnKeepers, class.UIData.MainUIFrame, 75, - 230, "TOP")
        _StdUI:GlueTop(class.UIData.NumberOfMailBoxes, class.UIData.MainUIFrame, 75, - 260, "TOP")



        C_Timer.NewTicker(0.25, function ()
          if not IsHunter then
            return
          end

          class.UIData.NumberOfManualScanNodes:SetText("Manual Scan Nodes Count: " .. #this.ManualScanLocations)

          if class.UIData.HunterScanMode ~= nil and class.UIData.HunterScanMode:GetValue(System.Boolean) then
            HandleHunterLogic(this)
          end
        end)

        C_Timer.NewTicker(2, function ()
          local colorstring = WrapperDatabase.WoWDatabase.getHasDirtyMaps() and "|cFFFF0000" or "|cFF00FF00"
          class.UIData.NeedsSaveText:SetText("Needs To Save: " .. System.toString(colorstring) .. System.toString(WrapperDatabase.WoWDatabase.getHasDirtyMaps()))
          class.UIData.MapIdText:SetText("MapId: " ..  __LB__.GetMapId())
          class.UIData.NumberOfHerbsText:SetText("Herb Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllHerbLocations())
          class.UIData.NumberOrOresText:SetText("Ore Nodes: " .. #WrapperDatabase.WoWDatabase.GetAllOreLocations())
          class.UIData.NumberOfVendorsText:SetText("Vendors: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Vendors)
          class.UIData.NumberOfRepairText:SetText("Repair: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Repair)
          class.UIData.NumberOfFlightMasters:SetText("FlightMasters: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).FlightMaster)
          class.UIData.NumberOfMailBoxes:SetText("MailBoxes: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).MailBoxes)
          class.UIData.NumberOfInnKeepers:SetText("InnKeepers: " .. #WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).InnKeepers)
        end)

        C_Timer.NewTicker(0, function ()
          HandleMapClicks(this)
        end)


        WrapperWoW.ObjectManager.getInstance().OnNewUnit = System.DelegateCombine(WrapperWoW.ObjectManager.getInstance().OnNewUnit, function (Unit)
          if class.UIData.EnabledCheckBox:GetValue(System.Boolean) and class.UIData.RecordNPCS:GetValue(System.Boolean) then
            WrapperDatabase.WoWDatabase.InsertNpcIfRequired(Unit)
          end
        end)

        WrapperWoW.ObjectManager.getInstance().OnNewGameObject = System.DelegateCombine(WrapperWoW.ObjectManager.getInstance().OnNewGameObject, function (GameObject)
          if class.UIData.EnabledCheckBox:GetValue(System.Boolean) and class.UIData.RecordGameObjects:GetValue(System.Boolean) then
            WrapperDatabase.WoWDatabase.InsertNodeIfRequired(GameObject)
          end
        end)
      end


      System.base(this).Pulse(this)
    end
    HandleMapClicks = function (this)
      local X = 0
      local Y = 0
      local WasClicked = false
      if WorldMapFrame:IsVisible() and IsControlKeyDown() and IsMouseButtonDown("LeftButton") then
          local x, y = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
          local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(WorldMapFrame: GetMapID(), CreateVector2D(x, y))
          local WX, WY = worldPosition:GetXY()
          --print(WX.."/"..WY)
          WasClicked = true;
          X = WX;
          Y = WY;
      end

      if WasClicked and GetTime() - this.LastHandledTime > 1 then
        this.LastHandledTime = GetTime()
        local HitPos = WrapperAPI.LuaBox.getInstance():RaycastPosition(X, Y, 10000, X, Y, - 10000, 1048849 --[[(int)LuaBox.ERaycastFlags.Collision]])
        if not (HitPos ~= nil) then
          System.Console.WriteLine("Unable to add accurate scan point at: " .. X .. " / " .. Y .. " because Raycast failed to hit anything doing something crazy")
          local StartHeight = WrapperWoW.ObjectManager.getInstance().Player.Position.Z

          for i = StartHeight - 2000, StartHeight + 2000 - 500, 500 do
            System.Console.WriteLine("adding rough scan point at: " .. X .. " / " .. Y .. " / " .. i)
            this.ManualScanLocations:Add(WrapperWoW.Vector3(X, Y, i))
          end
        else
          System.Console.WriteLine("adding manual scan point at: " .. X .. " / " .. Y .. " / " .. System.Nullable.Value(HitPos).Z)
          this.ManualScanLocations:Add(System.Nullable.Value(HitPos))
        end
      end
    end
    HandleHunterLogic = function (this)
      this.HunterScanGridRange = System.Int32.Parse(class.UIData.HunterGridRangeEntry:GetValue(System.String))
      this.HunterScanGridHeightOffset = System.Int32.Parse(class.UIData.HunterScanGridHeightOffsetEntry:GetValue(System.String))
      this.HunterScanGridMaxHorizontalRange = System.Int32.Parse(class.UIData.HunterScanGridMaxHorizontalRangeBeforeReset:GetValue(System.String))
      System.Console.WriteLine("Handling Hunter Logics")

      if not WrapperWoW.ObjectManager.getInstance().Player:getIsChanneling() and not WrapperWoW.ObjectManager.getInstance().Player:getIsCasting() then
        if not IsUsableSpell("Eagle Eye") then
          System.Console.WriteLine("Wants To Cast Eagle Eye but IsUsableSpell is false")
          return
        end

        if not  __LB__.IsAoEPending() then
          __LB__.UnitTagHandler(CastSpellByName, "Eagle Eye", nil)
          System.Console.WriteLine("Casting Eagle Eye")
          return
        end

        this.CastIndex = this.CastIndex + 1

        local CastLocation = GetNextCastLocation(this)


        if #this.ManualScanLocations == 0 then
          if WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, CastLocation:__clone__()) > this.HunterScanGridMaxHorizontalRange then
            System.Console.WriteLine("Reached Max Range - Reset And Move Up")
            this.CastIndex = 1
            class.UIData.HunterScanGridHeightOffsetEntry:SetValue(this.HunterScanGridMaxHorizontalRange + 175)
            return
          end
        end


        __LB__.ClickPosition(CastLocation.X, CastLocation.Y, CastLocation.Z, false)
        System.Console.WriteLine("Clicking At Cast Location")
        this.CastTimeStamp = GetTime()
      else
        if GetTime() - this.CastTimeStamp > 10 then
          System.Console.WriteLine("Have been chilling a bit. Recast")
          MoveForwardStart()
          MoveForwardStop()
          return
        else
          System.Console.WriteLine("Waiting " .. 10 - (GetTime() - this.CastTimeStamp) .. " more seconds for shit to load")
        end
      end
    end
    GetNextCastLocation = function (this)
      if #this.ManualScanLocations == 0 then
        local SpiralOffset = Spiral(this, this.CastIndex)
        SpiralOffset = SystemNumerics.Vector2.Multiply(SpiralOffset, this.HunterScanGridRange)

        return WrapperWoW.Vector3(WrapperWoW.ObjectManager.getInstance().Player.Position.X + SpiralOffset.X, WrapperWoW.ObjectManager.getInstance().Player.Position.Y + SpiralOffset.Y, WrapperWoW.ObjectManager.getInstance().Player.Position.Z + this.HunterScanGridHeightOffset)
      else
        if #this.ManualScanLocations <= this.CastIndex then
          this.CastIndex = 0
          System.Console.WriteLine("Completed Map Scan. Reset")
        end

        return this.ManualScanLocations:get(this.CastIndex)
      end
    end
    Spiral = function (this, n)
      local k = System.ToSingle(math.Ceiling((math.Sqrt(n) - 1) / 2))
      local t = 2 * k + 1
      local m = System.ToSingle(math.Pow(t, 2))
      t = t - 1

      if n >= m - t then
        return SystemNumerics.Vector2(k - (m - n), - k)
      else
        m = m - t
      end
      if n >= m - t then
        return SystemNumerics.Vector2(- k, - k + (m - n))
      else
        m = m - t
      end
      if n >= m - t then
        return SystemNumerics.Vector2(- k + (m - n), k)
      else
        return SystemNumerics.Vector2(k, k - (m - n - t))
      end
    end
    class = {
      base = function (out)
        return {
          out.Wrapper.BotBase
        }
      end,
      Pulse = Pulse,
      CastIndex = 1,
      HunterScanGridRange = 175,
      HunterScanGridHeightOffset = 0,
      HunterScanGridMaxHorizontalRange = 7500,
      __ctor__ = __ctor__
    }
    return class
  end)




  namespace.class("PVPBotBase", function (namespace)
    local Pulse, RunQueueLogic, RunBattleGroundLogic, Rotation, __ctor__
    __ctor__ = function (this)
      this.LastDestination = System.default(WrapperWoW.Vector3)
      this.SmartTarget = WrapperHelpers.SmartTargetPVP()
      this.SmartMove = WrapperHelpers.SmartMovePVP()
    end
    Pulse = function (this)
      if WrapperWoW.ObjectManager.getInstance().Player == nil or not (__LB__.Navigator ~= nil) then
        System.Console.WriteLine("Waiting on Player to spawn in ObjectManager")
        return
      end


      if IsInInstance() then
        RunBattleGroundLogic(this)
      else
        RunQueueLogic(this)
      end

      System.base(this).Pulse(this)
    end
    RunQueueLogic = function (this)
      if GetBattlefieldStatus(1) ~= "queued" then
        JoinBattlefield(32, true, false)
      end

      if GetBattlefieldStatus(1) == "confirm" then
        AcceptBattlefieldPort(1, 1)
        StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY")
      end

      if GetItemCount("Crate of Battlefield Goods") > 1 then
        UseItemByName("Crate of Battlefield Goods")
      end
    end
    RunBattleGroundLogic = function (this)
      -- Console.WriteLine("In Battleground");

      this.SmartMove:Pulse()
      this.SmartTarget:Pulse()

      local BestMoveScored = this.SmartMove:GetBestUnit()
      local BestTargetScored = this.SmartTarget:GetBestUnit()

      local BestMove = BestMoveScored.Player
      local BestTarget = BestTargetScored



      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") then
        if not __LB__.UnitTagHandler(UnitIsGhost, "player") then
          RepopMe()
        end

        __LB__.Navigator.Stop()
        return
      end


      if BestTarget ~= nil then
        --Console.WriteLine("BestTarget: " + BestTarget.Name);
        if WrapperWoW.ObjectManager.getInstance().Player.TargetGUID ~= BestTarget.TargetGUID then
          BestTarget:Target()
          RunMacroText("/startattack")
        end

        if (WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, BestTarget.Position) > 25 or not BestTarget.LineOfSight) and not (WrapperWoW.ObjectManager.getInstance().Player:getIsCasting() or WrapperWoW.ObjectManager.getInstance().Player:getIsChanneling()) then
          __LB__.Navigator.AllowMounting(false)
          __LB__.Navigator.MoveTo(BestTarget.Position.X, BestTarget.Position.Y, BestTarget.Position.Z, 1, 15)
          return
        else
          __LB__.Navigator.Stop()
        end

        ----Rotation?!
      end


      if BestMove ~= nil then
        if WrapperWoW.Vector3.op_Equality(this.LastDestination, nil) or WrapperWoW.Vector3.Distance(BestMove.Position, this.LastDestination:__clone__()) > 25 then
          if BestMove.GUID ~= this.LastMoveGUID then
            if math.Abs(BestMoveScored.Score - this.LastMoveScore) < 250 then
              --Dont update task lets not just spam around in the middle.
            end
          else
            -- Same Target Keep Going
            this.LastMoveScore = BestMoveScored.Score
            this.LastMoveGUID = BestMove.GUID
            this.LastDestination = BestMove.Position:__clone__()
          end
        else
          -- We need to do something to start.
          this.LastMoveScore = BestMoveScored.Score
          this.LastMoveGUID = BestMove.GUID
          this.LastDestination = BestMove.Position:__clone__()
        end

        if WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, this.LastDestination:__clone__()) > 15 then
          __LB__.Navigator.AllowMounting(WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, this.LastDestination:__clone__()) > 40)
          __LB__.Navigator.MoveTo(this.LastDestination.X, this.LastDestination.Y, this.LastDestination.Z, 1, 1)
        else
          __LB__.Navigator.Stop()
        end
      end
    end
    Rotation = function (this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.BotBase
        }
      end,
      HasBGStart = false,
      MinScoreJumpToSwap = 100,
      LastMoveScore = 0,
      LastMoveGUID = "",
      Pulse = Pulse,
      __ctor__ = __ctor__
    }
  end)

  namespace.class("CameraFaceTarget", function (namespace)
    local Pulse
    Pulse = function (this)
      local CurrentFacing, CurrentPitch
      CurrentFacing, CurrentPitch =  __LB__.GetCameraAngles()

      System.base(this).Pulse(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.BotBase
        }
      end,
      Pulse = Pulse
    }
  end)
end)

end
do
local System = System
local Wrapper
local WrapperAPI
local WrapperNativeBehaviors
local WrapperUI
local WrapperWoW
System.import(function (out)
  Wrapper = out.Wrapper
  WrapperAPI = Wrapper.API
  WrapperNativeBehaviors = Wrapper.NativeBehaviors
  WrapperUI = Wrapper.UI
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper", function (namespace)
  namespace.class("Program", function (namespace)
    local Base, ThrowWowErrors, Main, static
    static = function (this)
      Base = Wrapper.DataLoggerBase()
    end
    ThrowWowErrors = false
    Main = function (args)
      __LB__.LoadScript("NavigatorNightly")
      __LB__.LoadScript("AntiAFK")
      __LB__.LoadScript("LibDrawNightly")
      Wrapper.StdUI.Init()
      WrapperAPI.LibJson.Init()

      System.Console.WriteLine("Pulsed OM")
      WrapperWoW.ObjectManager.getInstance():Pulse()

      System.Console.WriteLine("Pulsed OM Complete")
      C_Timer.NewTicker(0.1, function ()
        if not ThrowWowErrors then
          System.try(function ()
            WrapperWoW.ObjectManager.getInstance():Pulse()
            Base:Pulse()
            --Console.WriteLine("New Ticker");
          end, function (default)
            local E = default
            System.Console.WriteLine("Exception in mainBot Thread: " .. System.toString(E:getMessage()) .. " StackTrace: " .. System.toString(debugstack()))
            WrapperUI.NativeErrorLoggerUI.getInstance():AddErrorMessage(E:getMessage(), debugstack())
          end)
        else
          WrapperWoW.ObjectManager.getInstance():Pulse()
          Base:Pulse()
        end
      end)




      C_Timer.After(2.5, function ()
        if _G["BroBot"] == nil then
          System.Console.WriteLine("Wont load brobot cc's brobot disabled")
          return
        end

        --Console.WriteLine("Attempting to Register C# CC");
        --BroBotAPI.registerFighter("CHunter", new HunterCCTest());
        --Console.WriteLine("Has Registered Fighter");


        System.Console.WriteLine("Attempting to Register Native Behavior")
        --BroBotAPI.registerBehavior("BroBotBehavior", new BroBotBehavior());
        registerBehavior(WrapperNativeBehaviors.NativeGrind(), "NativeGrind")
        System.Console.WriteLine("Registered Native Behaviors")
      end)
    end
    return {
      Main = Main,
      static = static
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.API", function (namespace)
  namespace.class("LibJson", function (namespace)
    local Init
    Init = function ()
      LibJSON = {}
      if not LibJSON then
          return
      end
      LibJSON.NULL = LibJSON.NULL or newproxy()
      local NULL = LibJSON.NULL
      --- Return a proxy object that will serialize to null.
      -- @usage LibJSON.Serialize(LibJSON.Null()) == "null"
      -- @usage LibJSON.Serialize({1, LibJSON.Null(), 3}) == "[1,null,3]"
      -- @return a proxy object
      function LibJSON.Null()
          return NULL
      end
      local serialize
      --- Serialize an object to LibJSON
      -- This will error if a function, userdata, or thread is passed in.
      -- This will also error if a non-UTF-8 string is passed in.
      -- @param value a serialized JSON object
      -- @usage LibJSON.Serialize(1234) == "1234"
      -- @usage LibJSON.Serialize(1234e50) == "1.234e+53"
      -- @usage LibJSON.Serialize("Hello, friend") == '"Hello, friend"'
      -- @usage LibJSON.Serialize({ 1, 2, 3 }) == "[1,2,3]"
      -- @usage LibJSON.Serialize({ one = 1, two = 2 }) == '{"one":1,"two":2}'
      -- @usage LibJSON.Serialize("\195\156berfantastisch") == '"\u00DCberfantastisch"'
      -- @usage LibJSON.Serialize(nil) == 'null'
      -- @usage LibJSON.Serialize(true) == 'true'
      -- @usage LibJSON.Serialize() == 'false'
      -- @usage LibJSON.Serialize({[4] = "Hello"}) == '[null,null,null,"Hello"]'
      -- @return a string with the serialized data in it
      function LibJSON.Serialize(value)
          local buffer = {}
          serialize(value, buffer)
          return table.concat(buffer)
      end
      local deserialize, skipWhitespace
      function LibJSON.Deserialize(value)
          local result, position = deserialize(value, 1)
          position = skipWhitespace(value, position)
          if position <= value:len() then
              error(("Unused trailing characters: %q"):format(value))
          end
          return result
      end
      do
                      local serializers = { }
          --serialize a value, appending to the given buffer
          function serialize(value, buffer)
              if value == NULL then
                  -- NULL is special, for embedding nils into lists
                  value = nil
              end
              if type(value) == "function" then
                  return --we just skip functions
             end
              local serializer = serializers[type(value)]
              if not serializer then
                  error(("Serializing of type %s is unsupported"):format(type(value)))
              end
              serializer(value, buffer)
          end
          local backslashed_bytes = {
                      [('"'):byte()] = '\\"',
              [('\\'):byte()] = '\\\\',
              [('/'):byte()] = '\\/',
              [('\b'):byte()] = '\\b',
              [('\f'):byte()] = '\\f',
              [('\n'):byte()] = '\\n',
              [('\r'):byte()] = '\\r',
              [('\t'):byte()] = '\\t',
      	}
                  function serializers:string(buffer)
              buffer[#buffer+1] = '"'
              local i = 1
              local length = #self
              while i <= length do
                          local byte = self:byte(i)
                  i = i + 1
                  if backslashed_bytes[byte] then
                      -- one of the standard backslashed characters
                      buffer[#buffer+1] = backslashed_bytes[byte]
                  elseif byte < 32 then
                      -- control character, not visible normally
                      buffer[#buffer+1] = "\\u00"
                      buffer[#buffer+1] = ("%02X"):format(byte)
                  elseif byte < 128 then
                      -- normal character
                      buffer[#buffer+1] = string.char(byte)
                  elseif byte < 194 or byte > 244 then
                      error("String is not proper UTF-8: %q"):format(self)
                  elseif byte < 224 then
                      -- unicode fun, this handles U + 0080 to U + 07FF
                      -- see http://en.wikipedia.org/wiki/UTF-8
                      local byte1, byte2 = self:byte(i), byte
                      i = i + 1
                      local nibble1 = byte1 % 16
                      local nibble2 = ((byte1 - nibble1) % 64) / 16 + (byte2 % 4) * 4
                      local nibble3 = math.floor(byte2 / 4) % 8
                      buffer[#buffer+1] = "\\u"
                      buffer[#buffer+1] = ("%04X"):format(nibble1 + nibble2 * 16 + nibble3 * 256)
                  elseif byte < 240 then
                      -- even more unicode fun, handles U + 0800 to U + FFFF
                      local byte1, byte2, byte3 = self:byte(i + 1), self: byte(i), byte
                      i = i + 2
                      local nibble1 = byte1 % 16
                      local nibble2 = ((byte1 - nibble1) % 64) / 16 + (byte2 % 4) * 4
                      local nibble3 = math.floor(byte2 / 4) % 16
                      local nibble4 = byte3 % 16
                      buffer[#buffer+1] = "\\u"
                      buffer[#buffer+1] = ("%04X"):format(nibble1 + nibble2 * 16 + nibble3 * 256 + nibble4 * 1024)
                  else
                      error("Cannot serialize unicode greater than U+FFFF: %q"):format(self)
                  end
              end
              buffer[#buffer+1] = '"'
          end
          function serializers: number(buffer)
              -- lua's and LibJSON's numbers are the same
              buffer[#buffer+1] = tostring(self)
          end
          function serializers: boolean(buffer)
              -- lua's and LibJSON's booleans are the same
              buffer[#buffer+1] = tostring(self)
          end
          -- see if the table provided is a list, if so, return the list's length
          -- This does handle lists with embedded nils, e.g. { 1, nil, 3}
                  --This could theoretically be an issue if you pass in {[10000]= "Hello"}
                  local function isList(list)
              local length = 0
              for k, v in pairs(list) do
                          if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                      return false
                  end
                  if length < k then
                      length = k
                  end
              end
              return length
          end
          function serializers: table(buffer)
              local listLength = isList(self)
              if listLength then
                  buffer[#buffer+1] = "["
                  for i = 1, listLength do
                          if i > 1 then
                              buffer[#buffer+1] = ","
                      end
                          serialize(self[i], buffer)
                      end
                      buffer[#buffer+1] = "]"
              else
                              buffer[#buffer+1] = "{"
                  local first = true
                  for k, v in pairs(self) do
                          if first then
                              first = false
                          else
                              buffer[#buffer+1] = ","
                      end
                          -- we're going to just coerce all keys to string
                          serialize(tostring(k), buffer)
                          buffer[#buffer+1] = ":"
                      serialize(v, buffer)
                      end
                      buffer[#buffer+1] = "}"
              end
              end
              serializers['nil'] = function(self, buffer)
                  buffer[#buffer+1] = "null"
          end
          end
      do
                      local solidus = ("/"):byte()
          local reverseSolidus = ("\\"):byte()
          local asterix = ("*"):byte()
          local openBrace = ("{"):byte()
          local closeBrace = ("}"):byte()
          local openBracket = ("["):byte()
          local closeBracket = ("]"):byte()
          local comma = (","):byte()
          local colon = (":"):byte()
          local doubleQuote = ('"'):byte()
          local minus = ("-"):byte()
          local plus = ("+"):byte()
          local letterT = ("t"):byte()
          local letterF = ("f"):byte()
          local letterN = ("n"):byte()
          local letterU = ("u"):byte()
          local digit0 = ("0"):byte()
          local digit1 = ("1"):byte()
          local digit9 = ("9"):byte()
          local fullStop = ("."):byte()
          local letterE = ("e"):byte()
          local letterUpperE = ("E"):byte()
          local whitespace = {
              [(" "):byte()] = true,
              [("\t"):byte()] = true,
              [("\r"):byte()] = true,
              [("\n"):byte()] = true,
          }
              local newlines = {
              [("\r"):byte ()] = true,
              [("\n"):byte ()] = true,
          }
          local numbers = { }
      	for i = 0, 9 do
      	    numbers[i + ('0'):byte()] = i
          end
          local escapes = {
              [('"'):byte()] = ('"'):byte (),
      		[('\\'):byte()] = ('\\'):byte (),
      		[('/'):byte()] = ('/'):byte (),
      		[('b'):byte()] = ('\b'):byte (),
      		[('f'):byte()] = ('\f'):byte (),
      		[('n'):byte()] = ('\n'):byte (),
      		[('r'):byte()] = ('\r'):byte (),
      		[('t'):byte()] = ('\t'):byte (),
      	}
      --this jumps the position ahead to past the first newline
          local function skipCommentSingleLine(value, position)
              local byte
              repeat
                  byte = value:byte(position)
                  position = position + 1
              until not byte or newlines[byte]
      return skipWhitespace(value, position)
          end
          local function skipCommentBlock(value, position)
              local lastByte, byte
              repeat
                  lastByte, byte = byte, value:byte(position)
                  position = position + 1
                  if lastByte == solidus and byte == asterix then
                      error(("Invalid comment found: %q"):format(value))
                  end
              until not byte or (lastByte == asterix and byte == solidus)
              if not byte then
                  --ran out of text before finishing the comment
                  error(("Invalid comment found: %q"):format(value))
              end
              return skipWhitespace(value, position)
          end
          local function skipComment(value, position)
              assert(value: byte(position) == solidus)
              local byte = value:byte(position + 1)
              if byte == solidus then
                  -- // text until newline
                  return skipCommentSingleLine(value, position + 2)
              elseif byte == asterix then
                  return skipCommentBlock(value, position + 2)
              else
          --can't have a random slash hanging around
                  error(("Invalid comment found: %q"):format(value))
              end
          end
      	-- skip all whitespace and comments
          function skipWhitespace(value, position)
              local byte = value:byte(position)
              if whitespace[byte] then
                  return skipWhitespace(value, position + 1)
              end
              if byte == solidus then
                  return skipComment(value, position)
              end
              return position
          end
          local tmp = {}
          --read in a string
         local function readString(value, position)
              assert(value: byte(position) == doubleQuote)
              position = position + 1
              for k in pairs(tmp) do
              --this is in case there was an error while figuring the string last time
                  tmp[k] = nil
              end
              while true do
              local byte = value:byte(position)
                  position = position + 1
                  if not byte then
                      error(("String ended early: %q"):format(value))
                  elseif byte == doubleQuote then
                      -- end of the string
                      break
                  elseif byte == reverseSolidus then
                      byte = value:byte(position)
                      position = position + 1
                      if not byte then
                          error(("String ended early: %q"):format(value))
                      elseif byte == letterU then
                          -- unicode fun
                          -- see http://en.wikipedia.org/wiki/UTF-8
                          local hexDigits = value:sub(position, position + 3)
                          if hexDigits:len() ~= 4 then
                              error(("String ended early: %q"):format(value))
                          end
                          position = position + 4
                          local codepoint = tonumber(hexDigits, 16)
                          if not codepoint then
                              error(("Invalid string found: %q"):format(value))
                          end
                          if codepoint < 0x0080 then
                              tmp[#tmp+1] = string.char(codepoint)
                          elseif codepoint < 0x0800 then
                              tmp[#tmp+1] = string.char(math.floor(codepoint / 0x0040) + 0xC0)
                              tmp[#tmp+1] = string.char((codepoint % 0x0040) + 0x80)
                          else
          tmp[#tmp+1] = string.char(math.floor(codepoint / 0x1000) + 0xE0)
                              tmp[#tmp+1] = string.char(math.floor((codepoint % 0x1000) / 0x0040) + 0x80)
                              tmp[#tmp+1] = string.char((codepoint % 0x0040) + 0x80)
                          end
                      else
          tmp[#tmp+1] = string.char(escapes[byte] or byte)
                      end
                  else
          tmp[#tmp+1] = string.char(byte)
                  end
      end
      local result = table.concat(tmp)
              for k in pairs(tmp) do
              tmp[k] = nil
              end
              return result, position
          end
          -- read in a number
          local function readNumber(value, position)
              local start = position
              local byte = value:byte(position)
              position = position + 1
              if byte == minus then
                  byte = value:byte(position)
                  position = position + 1
              end
              local number = numbers[byte]
      if not number then
                  error(("Number ended early: %q"):format(value))
              end
              if number ~= 0 then
                  while true do
              byte = value:byte(position)
                      position = position + 1
                      local digit = numbers[byte]
                      if not digit then
                          break
                      end
                  end
              else
                  byte = value:byte(position)
                  position = position + 1
              end
              if byte == fullStop then
                  local first = true
                  local exponent = 0
                  while true do
                      byte = value:byte(position)
                      position = position + 1
                      if not numbers[byte] then
                          if first then
                              error(("Number ended early: %q"):format(value))
                          end
                          break
                      end
                      first = false
                  end
              end
              if byte == letterE or byte == letterUpperE then
                  byte = value:byte(position)
                  position = position + 1
                  if byte == plus then
                      -- nothing to do
                  elseif byte == minus then
                      -- also nothing to do
                  else
                      position = position - 1
                  end
                  byte = value:byte(position)
                  position = position + 1
                  if not numbers[byte] then
                      error(("Invalid number: %q"):format(value))
                  end
                  repeat
                      byte = value:byte(position)
                      position = position + 1
                  until not numbers[byte]
              else
          position = position - 1
              end
              -- we 're gonna use number because it's typically faster and more accurate than adding and multiplying ourselves
              local number = tonumber(value:sub(start, position - 1))
              assert(number)
              return number, position
          end
          -- read in true
          local function readTrue(value, position)
              local string = value:sub(position, position + 3)
              if string ~= "true" then
                  error(("Error reading true: %q"):format(value))
              end
              return true, position + 4
          end
          -- read in false
          local function readFalse(value, position)
              local string = value:sub(position, position + 4)
              if string ~= "false" then
                  error(("Error reading false: %q"):format(value))
              end
              return false, position + 5
          end
          -- read in null(becomes nil)
          local function readNull(value, position)
              local string = value:sub(position, position + 3)
              if string ~= "null" then
                  error(("Error reading null: %q"):format(value))
              end
              return nil, position + 4
          end
          -- read in a list
          local function readList(value, position)
              assert(value: byte(position) == openBracket)
              position = position + 1
              if value:byte(position) == closeBracket then
                  return { }, position + 1
              end
              local list = {}
              --track list position rather than #list+1 because of embedded nulls
              local listPosition = 1
              while true do
                  -- when the great division comes, there will be no pain, no 
                  -- suffering, for we shall be the mother and father to a million
                  -- civilizations
                  local atom
                  atom, position = deserialize(value, position)
                  list[listPosition] = atom
                  listPosition = listPosition + 1
                  position = skipWhitespace(value, position)
                  local byte = value:byte(position)
                  position = position + 1
                  if byte == closeBracket then
                      return list, position
                  elseif not byte then
                      error(("Invalid list: %q, ended early"):format(value))
                  elseif byte ~= comma then
                      error(("Invalid list: %q, because of %q"):format(value, string.char(byte)))
                  end
              end
          end
          -- read in a dictionary
          local function readDictionary(value, position)
              assert(value: byte(position) == openBrace)
              position = position + 1
              if value:byte(position) == closeBrace then
                  return { }, position + 1
              end
              local dictionary = {}
              while true do
              --get the key first
                  local key
                  key, position = deserialize(value, position)
                  if type(key) ~= "string" then
                      error(("Found non-string dictionary key: %s"):format(tostring(key)))
                  end
                  position = skipWhitespace(value, position)
                  local byte = value:byte(position)
                  position = position + 1
                  if not byte then
                      error(("Invalid dictionary: %q, ended early"):format(value))
                  elseif byte ~= colon then
                      error(("Invalid dictionary: %q, because of %q"):format(value, string.char(byte)))
                  end
                  position = skipWhitespace(value, position)
                  -- now the value
                  local val
                  val, position = deserialize(value, position)
                  dictionary[key] = val
                  position = skipWhitespace(value, position)
                  local byte = value:byte(position)
                  position = position + 1
                  if byte == closeBrace then
                      return dictionary, position
                  elseif not byte then
                      error(("Invalid dictionary: %q, ended early"):format(value))
                  elseif byte ~= comma then
                      error(("Invalid dictionary: %q, because of %q"):format(value, string.char(byte)))
                  end
              end
          end
          -- deserialize the object for the given value at the given position
          function deserialize(value, position)
              position = skipWhitespace(value, position)
              local nextByte = value:byte(position)
              if not nextByte then
                  error(("Premature end: %q"):format(value))
              end
              if nextByte == openBrace then
                  return readDictionary(value, position)
              elseif nextByte == openBracket then
                  return readList(value, position)
              elseif nextByte == doubleQuote then
                  return readString(value, position)
              elseif nextByte == solidus then
                  position = skipComment(value, position)
                  return deserialize(value, position)
              elseif nextByte == minus or numbers[nextByte] then
                  return readNumber(value, position)
              elseif nextByte == letterT then
                  return readTrue(value, position)
              elseif nextByte == letterF then
                  return readFalse(value, position)
              elseif nextByte == letterN then
                  return readNull(value, position)
              else
          error(("Invalid input: %q"):format(value))
              end
          end
      end
      char_to_hex = function(c)
        return string.format("%%%02X", string.byte(c))
      end
      function url_encode(url)
        if url == nil then
          return
        end
        url = url:gsub("\n", "\r\n")
        url = url:gsub("([^%w ])", char_to_hex)
        url = url:gsub(" ", "+")
        return url
      end
      hex_to_char = function(x)
        return string.char(tonumber(x, 16))
      end
      url_decode = function(url)
        if url == nil then
          return
        end
        url = url:gsub("+", " ")
        url = url:gsub("%%(%x%x)", hex_to_char)
        return url
      end
    end
    return {
      Init = Init
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.API", function (namespace)
  namespace.class("LibStub", function (namespace)
    return {}
  end)
end)

end
do
local System = System
local WrapperAPI
local WrapperWoW
System.import(function (out)
  WrapperAPI = Wrapper.API
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.API", function (namespace)
  namespace.class("LuaBox", function (namespace)
    local _instance, getInstance, ObjectPositionVector3, RaycastPosition, class, __ctor__
    namespace.enum("EClientTypes", function ()
      return {
        Classic = 1,
        Retail = 0,
        __metadata__ = function (out)
          return {
            fields = {
              { "Classic", 0xE, System.Int32 },
              { "Retail", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("EGameObjectTypes", function ()
      return {
        AreaDamage = 12,
        AuraGenerator = 30,
        BarberChair = 32,
        Binder = 4,
        Button = 1,
        Camera = 13,
        CapturePoint = 42,
        Chair = 7,
        ChallengeModeReward = 51,
        Chest = 3,
        ClientCreature = 40,
        ClientItem = 41,
        ControlZone = 29,
        DestructibleBuilding = 33,
        Door = 0,
        DuelArbiter = 16,
        DungeonDifficulty = 31,
        FishingHole = 25,
        FishingNode = 17,
        FlagDrop = 26,
        FlagStand = 24,
        GarrisonBuilding = 38,
        GarrisonMonument = 44,
        GarrisonMonumentPlaque = 46,
        GarrisonPlot = 39,
        GarrisonShipment = 45,
        GatheringNode = 50,
        Generic = 5,
        Goober = 10,
        GuardPost = 21,
        GuildBank = 34,
        Invalid = 1,
        ItemForge = 47,
        KeystoneReceptacle = 49,
        Mailbox = 19,
        MapObject = 14,
        MapObjTransport = 15,
        MeetingStone = 23,
        MiniGame = 27,
        Multi = 52,
        NewFlag = 36,
        NewFlagDrop = 37,
        PhaseableMo = 43,
        PvpReward = 55,
        QuestGiver = 2,
        Ritual = 18,
        SiegeableMo = 54,
        SiegeableMulti = 53,
        SpellCaster = 22,
        SpellFocus = 8,
        Text = 9,
        Transport = 11,
        Trap = 6,
        TrapDoor = 35,
        UiLink = 48,
        __metadata__ = function (out)
          return {
            fields = {
              { "AreaDamage", 0xE, System.Int32 },
              { "AuraGenerator", 0xE, System.Int32 },
              { "BarberChair", 0xE, System.Int32 },
              { "Binder", 0xE, System.Int32 },
              { "Button", 0xE, System.Int32 },
              { "Camera", 0xE, System.Int32 },
              { "CapturePoint", 0xE, System.Int32 },
              { "Chair", 0xE, System.Int32 },
              { "ChallengeModeReward", 0xE, System.Int32 },
              { "Chest", 0xE, System.Int32 },
              { "ClientCreature", 0xE, System.Int32 },
              { "ClientItem", 0xE, System.Int32 },
              { "ControlZone", 0xE, System.Int32 },
              { "DestructibleBuilding", 0xE, System.Int32 },
              { "Door", 0xE, System.Int32 },
              { "DuelArbiter", 0xE, System.Int32 },
              { "DungeonDifficulty", 0xE, System.Int32 },
              { "FishingHole", 0xE, System.Int32 },
              { "FishingNode", 0xE, System.Int32 },
              { "FlagDrop", 0xE, System.Int32 },
              { "FlagStand", 0xE, System.Int32 },
              { "GarrisonBuilding", 0xE, System.Int32 },
              { "GarrisonMonument", 0xE, System.Int32 },
              { "GarrisonMonumentPlaque", 0xE, System.Int32 },
              { "GarrisonPlot", 0xE, System.Int32 },
              { "GarrisonShipment", 0xE, System.Int32 },
              { "GatheringNode", 0xE, System.Int32 },
              { "Generic", 0xE, System.Int32 },
              { "Goober", 0xE, System.Int32 },
              { "GuardPost", 0xE, System.Int32 },
              { "GuildBank", 0xE, System.Int32 },
              { "Invalid", 0xE, System.Int32 },
              { "ItemForge", 0xE, System.Int32 },
              { "KeystoneReceptacle", 0xE, System.Int32 },
              { "Mailbox", 0xE, System.Int32 },
              { "MapObject", 0xE, System.Int32 },
              { "MapObjTransport", 0xE, System.Int32 },
              { "MeetingStone", 0xE, System.Int32 },
              { "MiniGame", 0xE, System.Int32 },
              { "Multi", 0xE, System.Int32 },
              { "NewFlag", 0xE, System.Int32 },
              { "NewFlagDrop", 0xE, System.Int32 },
              { "PhaseableMo", 0xE, System.Int32 },
              { "PvpReward", 0xE, System.Int32 },
              { "QuestGiver", 0xE, System.Int32 },
              { "Ritual", 0xE, System.Int32 },
              { "SiegeableMo", 0xE, System.Int32 },
              { "SiegeableMulti", 0xE, System.Int32 },
              { "SpellCaster", 0xE, System.Int32 },
              { "SpellFocus", 0xE, System.Int32 },
              { "Text", 0xE, System.Int32 },
              { "Transport", 0xE, System.Int32 },
              { "Trap", 0xE, System.Int32 },
              { "TrapDoor", 0xE, System.Int32 },
              { "UiLink", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("ELockTypes", function ()
      return {
        AncientMana = 30,
        Archaelogy = 22,
        ArmTrap = 9,
        Blasting = 16,
        CalcifiedElvenGems = 7,
        CataclysmHerbalism = 35,
        CataclysmMining = 43,
        ClassicHerbalism = 32,
        ClassicMining = 40,
        Close = 8,
        DisarmTrap = 4,
        DraenorHerbalism = 37,
        DraenorMining = 45,
        Fishing = 19,
        Gahzridian = 15,
        Herbalism = 2,
        Inscription = 20,
        KulTiranHerbalien = 39,
        KulTiranMining = 47,
        LegionHerbalism = 38,
        LegionMining = 46,
        LockPicking = 1,
        LumberMill = 28,
        Mining = 3,
        NorthrendHerbalism = 34,
        NorthrendMining = 42,
        Open = 5,
        OpenAttacking = 14,
        OpenFromVehicle = 21,
        OpenKneeling = 13,
        OpenTinkering = 12,
        OutlandHerbalism = 33,
        OutlandMining = 41,
        PandariaHerbalism = 36,
        PandariaMining = 44,
        PvpClose = 18,
        PvpOpen = 17,
        PvpOpenFast = 23,
        QuickClose = 11,
        QuickOpen = 10,
        Skinning = 29,
        Skinning2 = 48,
        Treasure = 6,
        WarBoard = 31,
        __metadata__ = function (out)
          return {
            fields = {
              { "AncientMana", 0xE, System.Int32 },
              { "Archaelogy", 0xE, System.Int32 },
              { "ArmTrap", 0xE, System.Int32 },
              { "Blasting", 0xE, System.Int32 },
              { "CalcifiedElvenGems", 0xE, System.Int32 },
              { "CataclysmHerbalism", 0xE, System.Int32 },
              { "CataclysmMining", 0xE, System.Int32 },
              { "ClassicHerbalism", 0xE, System.Int32 },
              { "ClassicMining", 0xE, System.Int32 },
              { "Close", 0xE, System.Int32 },
              { "DisarmTrap", 0xE, System.Int32 },
              { "DraenorHerbalism", 0xE, System.Int32 },
              { "DraenorMining", 0xE, System.Int32 },
              { "Fishing", 0xE, System.Int32 },
              { "Gahzridian", 0xE, System.Int32 },
              { "Herbalism", 0xE, System.Int32 },
              { "Inscription", 0xE, System.Int32 },
              { "KulTiranHerbalien", 0xE, System.Int32 },
              { "KulTiranMining", 0xE, System.Int32 },
              { "LegionHerbalism", 0xE, System.Int32 },
              { "LegionMining", 0xE, System.Int32 },
              { "LockPicking", 0xE, System.Int32 },
              { "LumberMill", 0xE, System.Int32 },
              { "Mining", 0xE, System.Int32 },
              { "NorthrendHerbalism", 0xE, System.Int32 },
              { "NorthrendMining", 0xE, System.Int32 },
              { "Open", 0xE, System.Int32 },
              { "OpenAttacking", 0xE, System.Int32 },
              { "OpenFromVehicle", 0xE, System.Int32 },
              { "OpenKneeling", 0xE, System.Int32 },
              { "OpenTinkering", 0xE, System.Int32 },
              { "OutlandHerbalism", 0xE, System.Int32 },
              { "OutlandMining", 0xE, System.Int32 },
              { "PandariaHerbalism", 0xE, System.Int32 },
              { "PandariaMining", 0xE, System.Int32 },
              { "PvpClose", 0xE, System.Int32 },
              { "PvpOpen", 0xE, System.Int32 },
              { "PvpOpenFast", 0xE, System.Int32 },
              { "QuickClose", 0xE, System.Int32 },
              { "QuickOpen", 0xE, System.Int32 },
              { "Skinning", 0xE, System.Int32 },
              { "Skinning2", 0xE, System.Int32 },
              { "Treasure", 0xE, System.Int32 },
              { "WarBoard", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("EMovementFlags", function ()
      return {
        Ascending = 2097152,
        Backward = 2,
        CanFly = 8388608,
        Descending = 4194304,
        Falling = 2048,
        FallingFar = 4096,
        Flying = 16777216,
        Forward = 1,
        Immobilized = 1024,
        PitchDown = 128,
        PitchUp = 64,
        StrafeLeft = 4,
        StrafeRight = 8,
        Swimming = 1048576,
        TurnLeft = 16,
        TurnRight = 32,
        Walking = 256,
        __metadata__ = function (out)
          return {
            fields = {
              { "Ascending", 0xE, System.Int32 },
              { "Backward", 0xE, System.Int32 },
              { "CanFly", 0xE, System.Int32 },
              { "Descending", 0xE, System.Int32 },
              { "Falling", 0xE, System.Int32 },
              { "FallingFar", 0xE, System.Int32 },
              { "Flying", 0xE, System.Int32 },
              { "Forward", 0xE, System.Int32 },
              { "Immobilized", 0xE, System.Int32 },
              { "PitchDown", 0xE, System.Int32 },
              { "PitchUp", 0xE, System.Int32 },
              { "StrafeLeft", 0xE, System.Int32 },
              { "StrafeRight", 0xE, System.Int32 },
              { "Swimming", 0xE, System.Int32 },
              { "TurnLeft", 0xE, System.Int32 },
              { "TurnRight", 0xE, System.Int32 },
              { "Walking", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("ENpcFlags", function ()
      return {
        ArtifactPowerRespec = 134217728,
        Auctioneer = 2097152,
        Banker = 131072,
        BattleMaster = 1048576,
        BlackMarket = 2147483648,
        Gossip = 1,
        GuildBanker = 8388608,
        Innkeeper = 65536,
        Mailbox = 67108864,
        PlayerVehicle = 33554432,
        QuestGiver = 2,
        Repair = 4096,
        SpellClick = 16777216,
        SpiritGuide = 32768,
        StableMaster = 4194304,
        Trainer = 16,
        TrainerClass = 32,
        TrainerProfession = 64,
        Transmogrifier = 268435456,
        VaultKeeper = 536870912,
        Vendor = 128,
        VendorAmmo = 256,
        VendorFood = 512,
        VendorPoison = 1024,
        VendorReagent = 2048,
        WildBattlePet = 1073741824,
        FlightMaster = 8192,
        __metadata__ = function (out)
          return {
            fields = {
              { "ArtifactPowerRespec", 0xE, System.UInt32 },
              { "Auctioneer", 0xE, System.UInt32 },
              { "Banker", 0xE, System.UInt32 },
              { "BattleMaster", 0xE, System.UInt32 },
              { "BlackMarket", 0xE, System.UInt32 },
              { "FlightMaster", 0xE, System.UInt32 },
              { "Gossip", 0xE, System.UInt32 },
              { "GuildBanker", 0xE, System.UInt32 },
              { "Innkeeper", 0xE, System.UInt32 },
              { "Mailbox", 0xE, System.UInt32 },
              { "PlayerVehicle", 0xE, System.UInt32 },
              { "QuestGiver", 0xE, System.UInt32 },
              { "Repair", 0xE, System.UInt32 },
              { "SpellClick", 0xE, System.UInt32 },
              { "SpiritGuide", 0xE, System.UInt32 },
              { "StableMaster", 0xE, System.UInt32 },
              { "Trainer", 0xE, System.UInt32 },
              { "TrainerClass", 0xE, System.UInt32 },
              { "TrainerProfession", 0xE, System.UInt32 },
              { "Transmogrifier", 0xE, System.UInt32 },
              { "VaultKeeper", 0xE, System.UInt32 },
              { "Vendor", 0xE, System.UInt32 },
              { "VendorAmmo", 0xE, System.UInt32 },
              { "VendorFood", 0xE, System.UInt32 },
              { "VendorPoison", 0xE, System.UInt32 },
              { "VendorReagent", 0xE, System.UInt32 },
              { "WildBattlePet", 0xE, System.UInt32 }
            }
          }
        end
      }
    end)
    namespace.enum("ERaycastFlags", function ()
      return {
        Collision = 1048849,
        Cull = 524288,
        DoodadCollision = 1,
        DoodadRender = 2,
        EntityCollision = 1048576,
        EntityRender = 2097152,
        LineOfSight = 1048592,
        LiquidAll = 131072,
        LiquidWaterWalkable = 65536,
        Terrain = 256,
        WmoCollision = 16,
        WmoIgnoreDoodad = 8192,
        WmoNoCamCollision = 64,
        WmoRender = 32,
        __metadata__ = function (out)
          return {
            fields = {
              { "Collision", 0xE, System.Int32 },
              { "Cull", 0xE, System.Int32 },
              { "DoodadCollision", 0xE, System.Int32 },
              { "DoodadRender", 0xE, System.Int32 },
              { "EntityCollision", 0xE, System.Int32 },
              { "EntityRender", 0xE, System.Int32 },
              { "LineOfSight", 0xE, System.Int32 },
              { "LiquidAll", 0xE, System.Int32 },
              { "LiquidWaterWalkable", 0xE, System.Int32 },
              { "Terrain", 0xE, System.Int32 },
              { "WmoCollision", 0xE, System.Int32 },
              { "WmoIgnoreDoodad", 0xE, System.Int32 },
              { "WmoNoCamCollision", 0xE, System.Int32 },
              { "WmoRender", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("EUnitDynamicFlags", function ()
      return {
        Invisible = 1,
        Phased = 2,
        Lootable = 4,
        Tracked = 8,
        Tapped = 16,
        SpecialInfo = 32,
        Dead = 64,
        ReferAFriendLinked = 128,
        __metadata__ = function (out)
          return {
            fields = {
              { "Dead", 0xE, System.Int32 },
              { "Invisible", 0xE, System.Int32 },
              { "Lootable", 0xE, System.Int32 },
              { "Phased", 0xE, System.Int32 },
              { "ReferAFriendLinked", 0xE, System.Int32 },
              { "SpecialInfo", 0xE, System.Int32 },
              { "Tapped", 0xE, System.Int32 },
              { "Tracked", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("EUnitFlags", function ()
      return {
        CannotSwim = 16384,
        Confused = 4194304,
        Disarmed = 2097152,
        Fleeing = 8388608,
        ImmuneToNpc = 512,
        ImmuneToPc = 256,
        InCombat = 524288,
        Looting = 1024,
        Mount = 134217728,
        NonAttackable = 2,
        NotAttackable1 = 128,
        NotSelectable = 33554432,
        Pacified = 131072,
        PetInCombat = 2048,
        PlayerControlled = 16777216,
        Preparation = 32,
        PvpAttackable = 8,
        RemoveClientControl = 4,
        Rename = 16,
        ServerController = 1,
        Sheath = 1073741824,
        Silenced = 8192,
        Skinnable = 67108864,
        Stunned = 262144,
        TaxiFlight = 1048576,
        __metadata__ = function (out)
          return {
            fields = {
              { "CannotSwim", 0xE, System.Int32 },
              { "Confused", 0xE, System.Int32 },
              { "Disarmed", 0xE, System.Int32 },
              { "Fleeing", 0xE, System.Int32 },
              { "ImmuneToNpc", 0xE, System.Int32 },
              { "ImmuneToPc", 0xE, System.Int32 },
              { "InCombat", 0xE, System.Int32 },
              { "Looting", 0xE, System.Int32 },
              { "Mount", 0xE, System.Int32 },
              { "NonAttackable", 0xE, System.Int32 },
              { "NotAttackable1", 0xE, System.Int32 },
              { "NotSelectable", 0xE, System.Int32 },
              { "Pacified", 0xE, System.Int32 },
              { "PetInCombat", 0xE, System.Int32 },
              { "PlayerControlled", 0xE, System.Int32 },
              { "Preparation", 0xE, System.Int32 },
              { "PvpAttackable", 0xE, System.Int32 },
              { "RemoveClientControl", 0xE, System.Int32 },
              { "Rename", 0xE, System.Int32 },
              { "ServerController", 0xE, System.Int32 },
              { "Sheath", 0xE, System.Int32 },
              { "Silenced", 0xE, System.Int32 },
              { "Skinnable", 0xE, System.Int32 },
              { "Stunned", 0xE, System.Int32 },
              { "TaxiFlight", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("EUnitFlags2", function ()
      return {
        AllowChangingTalents = 512,
        AllowCheatSpells = 262144,
        AllowEnemyInteract = 16384,
        ComprehendLang = 8,
        DisablePredStats = 256,
        DisableTurn = 32768,
        DisarmOffhand = 128,
        DisarmRanged = 1024,
        FeignDeath = 1,
        ForceMovement = 64,
        IgnoreReputation = 4,
        InstantAppearModel = 3,
        MirrorImage = 16,
        NoActions = 8388608,
        PlayDeathAnim = 131072,
        PreventSpellClick = 8192,
        RegeneratePower = 2048,
        RestrictPartyInteraction = 4096,
        __metadata__ = function (out)
          return {
            fields = {
              { "AllowChangingTalents", 0xE, System.Int32 },
              { "AllowCheatSpells", 0xE, System.Int32 },
              { "AllowEnemyInteract", 0xE, System.Int32 },
              { "ComprehendLang", 0xE, System.Int32 },
              { "DisablePredStats", 0xE, System.Int32 },
              { "DisableTurn", 0xE, System.Int32 },
              { "DisarmOffhand", 0xE, System.Int32 },
              { "DisarmRanged", 0xE, System.Int32 },
              { "FeignDeath", 0xE, System.Int32 },
              { "ForceMovement", 0xE, System.Int32 },
              { "IgnoreReputation", 0xE, System.Int32 },
              { "InstantAppearModel", 0xE, System.Int32 },
              { "MirrorImage", 0xE, System.Int32 },
              { "NoActions", 0xE, System.Int32 },
              { "PlayDeathAnim", 0xE, System.Int32 },
              { "PreventSpellClick", 0xE, System.Int32 },
              { "RegeneratePower", 0xE, System.Int32 },
              { "RestrictPartyInteraction", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.enum("EObjectType", function ()
      return {
        Object = 0,
        Item = 1,
        Container = 2,
        AzeriteEmpoweredItem = 3,
        AzeriteItem = 4,
        Unit = 5,
        Player = 6,
        ActivePlayer = 7,
        GameObject = 8,
        DynamicObject = 9,
        Corpse = 10,
        AreaTrigger = 11,
        SceneObject = 12,
        ConversationData = 13,
        __metadata__ = function (out)
          return {
            fields = {
              { "ActivePlayer", 0xE, System.Int32 },
              { "AreaTrigger", 0xE, System.Int32 },
              { "AzeriteEmpoweredItem", 0xE, System.Int32 },
              { "AzeriteItem", 0xE, System.Int32 },
              { "Container", 0xE, System.Int32 },
              { "ConversationData", 0xE, System.Int32 },
              { "Corpse", 0xE, System.Int32 },
              { "DynamicObject", 0xE, System.Int32 },
              { "GameObject", 0xE, System.Int32 },
              { "Item", 0xE, System.Int32 },
              { "Object", 0xE, System.Int32 },
              { "Player", 0xE, System.Int32 },
              { "SceneObject", 0xE, System.Int32 },
              { "Unit", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    __ctor__ = function (this)
      this.Navigator = WrapperAPI.Navigator()
    end
    getInstance = function ()
      if _instance == nil then
        _instance = class()
        _instance.Navigator = WrapperAPI.Navigator()
      end
      return _instance
    end
    ObjectPositionVector3 = function (this, GUIDorUnitID)
      local x, y, z
      x, y, z = __LB__.ObjectPosition(GUIDorUnitID)
      return WrapperWoW.Vector3(x, y, z)
    end
    RaycastPosition = function (this, x, y, z, a, b, c, Flags)
      local _x = 0
      local _y = 0
      local _z = 0
      _x,_y,_z = __LB__.Raycast(x, y, z, a, b, c, Flags);
      if _x == nil then
        return nil
      end                   

      return WrapperWoW.Vector3(_x, _y, _z)
    end
    class = {
      getInstance = getInstance,
      ObjectPositionVector3 = ObjectPositionVector3,
      RaycastPosition = RaycastPosition,
      __ctor__ = __ctor__
    }
    return class
  end)

  namespace.class("UnitAura", function (namespace)
    return {
      Active = false,
      AuraId = 0,
      Cancelable = false,
      CanStealOrPurge = false,
      Count = 0,
      Duration = 0,
      Expiration = 0,
      Harmful = false,
      Passive = false,
      Id = 0
    }
  end)


  namespace.class("Navigator", function (namespace)
    return {}
  end)
end)

end
do
local System = System
System.namespace("Wrapper", function (namespace)
  namespace.class("StdUI", function (namespace)
    local IsInjected, Init
    namespace.class("StdUiFrame", function (namespace)
      return {
        base = function (out)
          return {
            out.Wrapper.API.WoWFrame
          }
        end
      }
    end)
    namespace.class("StdUiNumericInputFrame", function (namespace)
      return {
        base = function (out)
          return {
            out.Wrapper.StdUI.StdUiInputFrame
          }
        end
      }
    end)
    namespace.class("StdUiInputFrame", function (namespace)
      return {
        base = function (out)
          return {
            out.Wrapper.StdUI.StdUiFrame
          }
        end
      }
    end)
    namespace.class("StdUiCheckBox", function (namespace)
      return {
        base = function (out)
          return {
            out.Wrapper.StdUI.StdUiInputFrame
          }
        end
      }
    end)
    namespace.class("StdUiLabel", function (namespace)
      return {
        base = function (out)
          return {
            out.Wrapper.StdUI.StdUiFrame
          }
        end
      }
    end)
    namespace.class("StdUiButton", function (namespace)
      return {
        base = function (out)
          return {
            out.Wrapper.StdUI.StdUiFrame
          }
        end
      }
    end)
    IsInjected = false
    Init = function ()
      if not IsInjected then
        System.Console.WriteLine("Injecting StdUI")
        --LibStub is a simple versioning stub meant for use in Libraries.http://www.wowace.com/wiki/LibStub for more info
        --LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
        local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2-- NEVER MAKE THIS AN SVN REVISION! IT NEEDS TO BE USABLE IN ALL REPOS!
        local LibStub = _G[LIBSTUB_MAJOR]
        if not LibStub or LibStub.minor < LIBSTUB_MINOR then
         LibStub = LibStub or { libs = { }, minors = { } }
        		 _G[LIBSTUB_MAJOR] = LibStub
         LibStub.minor = LIBSTUB_MINOR
         function LibStub:NewLibrary(major, minor)
        	 assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
        	 minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")
        	 local oldminor = self.minors[major]
        	 if oldminor and oldminor >= minor then return nil end
        	 self.minors[major], self.libs[major] = minor, self.libs[major] or { }
        		 return self.libs[major], oldminor
        	 end
         function LibStub:GetLibrary(major, silent)
        	 if not self.libs[major] and not silent then
        		 error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
        	 end
        	 return self.libs[major], self.minors[major]
         end
         function LibStub: IterateLibraries() return pairs(self.libs) end
          setmetatable(LibStub, { __call = LibStub.GetLibrary })
        end
        					local function a(...)
                          local b, c = "StdUi", 5
                          local d = LibStub:NewLibrary(b, c)
                          if not d then
                              return
                          end
                          local e = tinsert
                          d.moduleVersions = {}
                          if not StdUiInstances then
                              StdUiInstances = {d}
                          else
                              e(StdUiInstances, d)
                          end
                          function d:NewInstance()
                              local f = CopyTable(self)
                              f:ResetConfig()
                              e(StdUiInstances, f)
                              return f
                          end
                          function d:RegisterModule(g, h)
                              self.moduleVersions[g] = h
                          end
                          function d:UpgradeNeeded(g, h)
                              if not self.moduleVersions[g] then
                                  return true
                              end
                              return self.moduleVersions[g] < h
                          end
                          function d:RegisterWidget(i, j)
                              if not self[i] then
                                  self[i] = j
                                  return true
                              end
                              return false
                          end
                          function d:InitWidget(k)
                              k.isWidget = true
                              function k:GetChildrenWidgets()
                                  local l = {k:GetChildren()}
                                  local m = {}
                                  for n = 1, #l do
                                      local o = l[n]
                                      if o.isWidget then
                                          e(m, o)
                                      end
                                  end
                                  return m
                              end
                          end
                          function d:SetObjSize(p, q, r)
                              if q then
                                  p:SetWidth(q)
                              end
                              if r then
                                  p:SetHeight(r)
                              end
                          end
                          function d:SetTextColor(s, t)
                              t = t or "normal"
                              if s.SetTextColor then
                                  local u = self.config.font.color[t]
                                  s:SetTextColor(u.r, u.g, u.b, u.a)
                              end
                          end
                          d.SetHighlightBorder = function(self)
                              if self.target then
                                  self = self.target
                              end
                              if self.isDisabled then
                                  return
                              end
                              local v = self.stdUi.config.highlight.color
                              if not self.origBackdropBorderColor then
                                  self.origBackdropBorderColor = {self:GetBackdropBorderColor()}
                              end
                              self:SetBackdropBorderColor(v.r, v.g, v.b, 1)
                          end
                          d.ResetHighlightBorder = function(self)
                              if self.target then
                                  self = self.target
                              end
                              if self.isDisabled then
                                  return
                              end
                              local v = self.origBackdropBorderColor
                              if v then
                                  self:SetBackdropBorderColor(unpack(v))
                              end
                          end
                          function d:HookHoverBorder(w)
                              if not w.SetBackdrop then
                                  Mixin(w, BackdropTemplateMixin)
                              end
                              w:HookScript("OnEnter", self.SetHighlightBorder)
                              w:HookScript("OnLeave", self.ResetHighlightBorder)
                          end
                          function d:ApplyBackdrop(x, type, y, z)
                              local A = x.config or self.config
                              local B = {bgFile = A.backdrop.texture, edgeFile = A.backdrop.texture, edgeSize = 1}
                              if z then
                                  B.insets = z
                              end
                              if not x.SetBackdrop then
                                  Mixin(x, BackdropTemplateMixin)
                              end
                              x:SetBackdrop(B)
                              type = type or "button"
                              y = y or "border"
                              if A.backdrop[type] then
                                  x:SetBackdropColor(A.backdrop[type].r, A.backdrop[type].g, A.backdrop[type].b, A.backdrop[type].a)
                              end
                              if A.backdrop[y] then
                                  x:SetBackdropBorderColor(A.backdrop[y].r, A.backdrop[y].g, A.backdrop[y].b, A.backdrop[y].a)
                              end
                          end
                          function d:ClearBackdrop(x)
                              if not x.SetBackdrop then
                                  Mixin(x, BackdropTemplateMixin)
                              end
                              x:SetBackdrop(nil)
                          end
                          function d:ApplyDisabledBackdrop(x, C)
                              if x.target then
                                  x = x.target
                              end
                              if C then
                                  self:ApplyBackdrop(x, "button", "border")
                                  self:SetTextColor(x, "normal")
                                  if x.label then
                                      self:SetTextColor(x.label, "normal")
                                  end
                                  if x.text then
                                      self:SetTextColor(x.text, "normal")
                                  end
                                  x.isDisabled = false
                              else
                                  self:ApplyBackdrop(x, "buttonDisabled", "borderDisabled")
                                  self:SetTextColor(x, "disabled")
                                  if x.label then
                                      self:SetTextColor(x.label, "disabled")
                                  end
                                  if x.text then
                                      self:SetTextColor(x.text, "disabled")
                                  end
                                  x.isDisabled = true
                              end
                          end
                          function d:HookDisabledBackdrop(x)
                              local D = self
                              hooksecurefunc(
                                  x,
                                  "Disable",
                                  function(self)
                                      D:ApplyDisabledBackdrop(self, false)
                                  end
                              )
                              hooksecurefunc(
                                  x,
                                  "Enable",
                                  function(self)
                                      D:ApplyDisabledBackdrop(self, true)
                                  end
                              )
                          end
                          function d:StripTextures(x)
                              for n = 1, x:GetNumRegions() do
                                  local E = select(n, x:GetRegions())
                                  if E and E:GetObjectType() == "Texture" then
                                      E:SetTexture(nil)
                                  end
                              end
                          end
                          function d:MakeDraggable(x, F)
                              x:SetMovable(true)
                              x:EnableMouse(true)
                              x:RegisterForDrag("LeftButton")
                              x:SetScript("OnDragStart", x.StartMoving)
                              x:SetScript("OnDragStop", x.StopMovingOrSizing)
                              if F then
                                  F:EnableMouse(true)
                                  F:SetMovable(true)
                                  F:RegisterForDrag("LeftButton")
                                  F:SetScript(
                                      "OnDragStart",
                                      function(self)
                                          x.StartMoving(x)
                                      end
                                  )
                                  F:SetScript(
                                      "OnDragStop",
                                      function(self)
                                          x.StopMovingOrSizing(x)
                                      end
                                  )
                              end
                          end
                          function d:MakeResizable(x, G)
                              local H = {
                                  ["TOP"] = 0,
                                  ["TOPRIGHT"] = 1.5708,
                                  ["RIGHT"] = 0,
                                  ["BOTTOMRIGHT"] = 0,
                                  ["BOTTOM"] = 0,
                                  ["BOTTOMLEFT"] = -1.5708,
                                  ["LEFT"] = 0,
                                  ["TOPLEFT"] = 3.1416
                              }
                              G = string.upper(G)
                              if not H[G] then
                                  return false
                              end
                              x:SetResizable(true)
                              local I = CreateFrame("Button", nil, x)
                              I:SetPoint(G, x, G)
                              if G == "TOP" or G == "BOTTOM" then
                                  I:SetHeight(self.config.resizeHandle.height)
                                  I:SetPoint("LEFT", x, "LEFT", self.config.resizeHandle.width, 0)
                                  I:SetPoint("RIGHT", x, "RIGHT", self.config.resizeHandle.width * -1, 0)
                              elseif G == "LEFT" or G == "RIGHT" then
                                  I:SetWidth(self.config.resizeHandle.width)
                                  I:SetPoint("TOP", x, "TOP", 0, self.config.resizeHandle.height * -1)
                                  I:SetPoint("BOTTOM", x, "BOTTOM", 0, self.config.resizeHandle.height)
                              else
                                  I:SetNormalTexture(self.config.resizeHandle.texture.normal)
                                  I:SetHighlightTexture(self.config.resizeHandle.texture.highlight)
                                  I:SetPushedTexture(self.config.resizeHandle.texture.pushed)
                                  I:SetSize(self.config.resizeHandle.width, self.config.resizeHandle.height)
                                  I:GetNormalTexture():SetRotation(H[G])
                                  I:GetHighlightTexture():SetRotation(H[G])
                                  I:GetPushedTexture():SetRotation(H[G])
                              end
                              I:SetScript(
                                  "OnMouseDown",
                                  function(self, J)
                                      if J == "LeftButton" then
                                          x:StartSizing(G)
                                          x:SetUserPlaced(true)
                                      end
                                  end
                              )
                              I:SetScript(
                                  "OnMouseUp",
                                  function(self, J)
                                      if J == "LeftButton" then
                                          x:StopMovingOrSizing()
                                      end
                                  end
                              )
                          end
                      end
                      local function K(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Config", 4
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local IsAddOnLoaded = IsAddOnLoaded
                          d.config = {}
                          function d:ResetConfig()
                              local L, M = GameFontNormal:GetFont()
                              local N, O = GameFontNormalLarge:GetFont()
                              self.config = {
                                  font = {
                                      family = L,
                                      size = M,
                                      titleSize = O,
                                      effect = "NONE",
                                      strata = "OVERLAY",
                                      color = {
                                          normal = {r = 1, g = 1, b = 1, a = 1},
                                          disabled = {r = 0.55, g = 0.55, b = 0.55, a = 1},
                                          header = {r = 1, g = 0.9, b = 0, a = 1}
                                      }
                                  },
                                  backdrop = {
                                      texture = "Interface\\Buttons\\WHITE8X8",
                                      panel = {r = 0.0588, g = 0.0588, b = 0, a = 0.8},
                                      slider = {r = 0.15, g = 0.15, b = 0.15, a = 1},
                                      highlight = {r = 0.40, g = 0.40, b = 0, a = 0.5},
                                      button = {r = 0.20, g = 0.20, b = 0.20, a = 1},
                                      buttonDisabled = {r = 0.15, g = 0.15, b = 0.15, a = 1},
                                      border = {r = 0.00, g = 0.00, b = 0.00, a = 1},
                                      borderDisabled = {r = 0.40, g = 0.40, b = 0.40, a = 1}
                                  },
                                  progressBar = {color = {r = 1, g = 0.9, b = 0, a = 0.5}},
                                  highlight = {color = {r = 1, g = 0.9, b = 0, a = 0.4}, blank = {r = 0, g = 0, b = 0, a = 0}},
                                  dialog = {width = 400, height = 100, button = {width = 100, height = 20, margin = 5}},
                                  tooltip = {padding = 10},
                                  resizeHandle = {
                                      width = 10,
                                      height = 10,
                                      texture = {
                                          normal = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
                                          highlight = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
                                          pushed = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
                                      }
                                  }
                              }
                              if IsAddOnLoaded("ElvUI") then
                                  local P = ElvUI[1].media.backdropfadecolor
                                  self.config.backdrop.panel = {r = P[1], g = P[2], b = P[3], a = P[4]}
                              end
                          end
                          d:ResetConfig()
                          function d:SetDefaultFont(L, Q, R, S)
                              self.config.font.family = L
                              self.config.font.size = Q
                              self.config.font.effect = R
                              self.config.font.strata = S
                          end
                          d:RegisterModule(g, h)
                      end
                      local function T(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Position", 2
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local U = "CENTER"
                          local V = "TOP"
                          local W = "BOTTOM"
                          local X = "LEFT"
                          local Y = "RIGHT"
                          local Z = "TOPLEFT"
                          local _ = "TOPRIGHT"
                          local a0 = "BOTTOMLEFT"
                          local a1 = "BOTTOMRIGHT"
                          d.Anchors = {
                              Center = U,
                              Top = V,
                              Bottom = W,
                              Left = X,
                              Right = Y,
                              TopLeft = Z,
                              TopRight = _,
                              BottomLeft = a0,
                              BottomRight = a1
                          }
                          function d:GlueBelow(w, a2, a3, a4, a5)
                              if a5 == X then
                                  w:SetPoint(Z, a2, a0, a3, a4)
                              elseif a5 == Y then
                                  w:SetPoint(_, a2, a1, a3, a4)
                              else
                                  w:SetPoint(V, a2, W, a3, a4)
                              end
                          end
                          function d:GlueAbove(w, a2, a3, a4, a5)
                              if a5 == X then
                                  w:SetPoint(a0, a2, Z, a3, a4)
                              elseif a5 == Y then
                                  w:SetPoint(a1, a2, _, a3, a4)
                              else
                                  w:SetPoint(W, a2, V, a3, a4)
                              end
                          end
                          function d:GlueTop(w, a2, a3, a4, a5)
                              if a5 == X then
                                  w:SetPoint(Z, a2, Z, a3, a4)
                              elseif a5 == Y then
                                  w:SetPoint(_, a2, _, a3, a4)
                              else
                                  w:SetPoint(V, a2, V, a3, a4)
                              end
                          end
                          function d:GlueBottom(w, a2, a3, a4, a5)
                              if a5 == X then
                                  w:SetPoint(a0, a2, a0, a3, a4)
                              elseif a5 == Y then
                                  w:SetPoint(a1, a2, a1, a3, a4)
                              else
                                  w:SetPoint(W, a2, W, a3, a4)
                              end
                          end
                          function d:GlueRight(w, a2, a3, a4, a6)
                              if a6 then
                                  w:SetPoint(Y, a2, Y, a3, a4)
                              else
                                  w:SetPoint(X, a2, Y, a3, a4)
                              end
                          end
                          function d:GlueLeft(w, a2, a3, a4, a6)
                              if a6 then
                                  w:SetPoint(X, a2, X, a3, a4)
                              else
                                  w:SetPoint(Y, a2, X, a3, a4)
                              end
                          end
                          function d:GlueAfter(w, a2, a7, a8, a9, aa)
                              if a7 and a8 then
                                  w:SetPoint(Z, a2, _, a7, a8)
                              end
                              if a9 and aa then
                                  w:SetPoint(a0, a2, a1, a9, aa)
                              end
                          end
                          function d:GlueBefore(w, a2, a7, a8, a9, aa)
                              if a7 and a8 then
                                  w:SetPoint(_, a2, Z, a7, a8)
                              end
                              if a9 and aa then
                                  w:SetPoint(a1, a2, a0, a9, aa)
                              end
                          end
                          function d:GlueAcross(w, a2, ab, ac, ad, ae)
                              w:SetPoint(Z, a2, Z, ab, ac)
                              w:SetPoint(a1, a2, a1, ad, ae)
                          end
                          function d:GlueOpposite(w, a2, a3, a4, I)
                              if I == "TOP" then
                                  w:SetPoint("BOTTOM", a2, I, a3, a4)
                              elseif I == "BOTTOM" then
                                  w:SetPoint("TOP", a2, I, a3, a4)
                              elseif I == "LEFT" then
                                  w:SetPoint("RIGHT", a2, I, a3, a4)
                              elseif I == "RIGHT" then
                                  w:SetPoint("LEFT", a2, I, a3, a4)
                              elseif I == "TOPLEFT" then
                                  w:SetPoint("BOTTOMRIGHT", a2, I, a3, a4)
                              elseif I == "TOPRIGHT" then
                                  w:SetPoint("BOTTOMLEFT", a2, I, a3, a4)
                              elseif I == "BOTTOMLEFT" then
                                  w:SetPoint("TOPRIGHT", a2, I, a3, a4)
                              elseif I == "BOTTOMRIGHT" then
                                  w:SetPoint("TOPLEFT", a2, I, a3, a4)
                              else
                                  w:SetPoint("CENTER", a2, I, a3, a4)
                              end
                          end
                          d:RegisterModule(g, h)
                      end
                      local function af(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Util", 10
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local ag = table.getn
                          local e = tinsert
                          local ah = table.sort
                          function d:MarkAsValid(x, ai)
                              if not x.SetBackdrop then
                                  Mixin(x, BackdropTemplateMixin)
                              end
                              if not ai then
                                  x:SetBackdropBorderColor(1, 0, 0, 1)
                                  x.origBackdropBorderColor = {x:GetBackdropBorderColor()}
                              else
                                  x:SetBackdropBorderColor(
                                      self.config.backdrop.border.r,
                                      self.config.backdrop.border.g,
                                      self.config.backdrop.border.b,
                                      self.config.backdrop.border.a
                                  )
                                  x.origBackdropBorderColor = {x:GetBackdropBorderColor()}
                              end
                          end
                          d.Util = {
                              editBoxValidator = function(self)
                                  self.value = self:GetText()
                                  self.stdUi:MarkAsValid(self, true)
                                  return true
                              end,
                              moneyBoxValidator = function(self)
                                  local aj = self:GetText()
                                  aj = aj:trim()
                                  local ak, al, am, an, ao = d.Util.parseMoney(aj)
                                  if not ao or ak == 0 then
                                      self.stdUi:MarkAsValid(self, false)
                                      return false
                                  end
                                  self:SetText(d.Util.formatMoney(ak))
                                  self.value = ak
                                  self.stdUi:MarkAsValid(self, true)
                                  return true
                              end,
                              moneyBoxValidatorExC = function(self)
                                  local aj = self:GetText()
                                  aj = aj:trim()
                                  local ak, al, am, an, ao = d.Util.parseMoney(aj)
                                  if not ao or ak == 0 or an and tonumber(an) > 0 then
                                      self.stdUi:MarkAsValid(self, false)
                                      return false
                                  end
                                  self:SetText(d.Util.formatMoney(ak, true))
                                  self.value = ak
                                  self.stdUi:MarkAsValid(self, true)
                                  return true
                              end,
                              numericBoxValidator = function(self)
                                  local aj = self:GetText()
                                  aj = aj:trim()
                                  local ap = tonumber(aj)
                                  if ap == nil then
                                      self.stdUi:MarkAsValid(self, false)
                                      return false
                                  end
                                  if self.maxValue and self.maxValue < ap then
                                      self.stdUi:MarkAsValid(self, false)
                                      return false
                                  end
                                  if self.minValue and self.minValue > ap then
                                      self.stdUi:MarkAsValid(self, false)
                                      return false
                                  end
                                  self.value = ap
                                  self.stdUi:MarkAsValid(self, true)
                                  return true
                              end,
                              spellValidator = function(self)
                                  local aj = self:GetText()
                                  aj = aj:trim()
                                  local i, N, aq, N, N, N, ar = GetSpellInfo(aj)
                                  if not i then
                                      self.stdUi:MarkAsValid(self, false)
                                      return false
                                  end
                                  self:SetText(i)
                                  self.value = ar
                                  self.icon:SetTexture(aq)
                                  self.stdUi:MarkAsValid(self, true)
                                  return true
                              end,
                              parseMoney = function(aj)
                                  aj = d.Util.stripColors(aj)
                                  local ak = 0
                                  local as, N, an = string.find(aj, "(%d+)c$")
                                  if as then
                                      aj = string.gsub(aj, "(%d+)c$", "")
                                      aj = aj:trim()
                                      ak = tonumber(an)
                                  end
                                  local at, N, am = string.find(aj, "(%d+)s$")
                                  if at then
                                      aj = string.gsub(aj, "(%d+)s$", "")
                                      aj = aj:trim()
                                      ak = ak + tonumber(am) * 100
                                  end
                                  local au, N, al = string.find(aj, "(%d+)g$")
                                  if au then
                                      aj = string.gsub(aj, "(%d+)g$", "")
                                      aj = aj:trim()
                                      ak = ak + tonumber(al) * 100 * 100
                                  end
                                  local av = tonumber(aj:len())
                                  local ao = aj:len() == 0 and ak > 0
                                  return ak, al, am, an, ao
                              end,
                              formatMoney = function(aw, ax)
                                  if type(aw) ~= "number" then
                                      return aw
                                  end
                                  aw = tonumber(aw)
                                  local ay = "|cfffff209"
                                  local az = "|cff7b7b7a"
                                  local aA = "|cffac7248"
                                  local al = floor(aw / COPPER_PER_GOLD)
                                  local am = floor((aw - al * COPPER_PER_GOLD) / COPPER_PER_SILVER)
                                  local an = floor(aw % COPPER_PER_SILVER)
                                  local aB = ""
                                  if al > 0 then
                                      aB = format("%s%i%s ", ay, al, "|rg")
                                  end
                                  if al > 0 or am > 0 then
                                      aB = format("%s%s%02i%s ", aB, az, am, "|rs")
                                  end
                                  if not ax then
                                      aB = format("%s%s%02i%s ", aB, aA, an, "|rc")
                                  end
                                  return aB:trim()
                              end,
                              stripColors = function(aj)
                                  aj = string.gsub(aj, "|c%x%x%x%x%x%x%x%x", "")
                                  aj = string.gsub(aj, "|r", "")
                                  return aj
                              end,
                              WrapTextInColor = function(aj, aC, aD, aE, aF)
                                  local aG =
                                      string.format(
                                      "%02x%02x%02x%02x",
                                      Clamp(aF * 255, 0, 255),
                                      Clamp(aC * 255, 0, 255),
                                      Clamp(aD * 255, 0, 255),
                                      Clamp(aE * 255, 0, 255)
                                  )
                                  return WrapTextInColorCode(aj, aG)
                              end,
                              tableCount = function(aH)
                                  local aI = #aH
                                  if aI == 0 then
                                      for N in pairs(aH) do
                                          aI = aI + 1
                                      end
                                  end
                                  return aI
                              end,
                              tableMerge = function(aJ, aK)
                                  local m = {}
                                  for aL, aM in pairs(aJ) do
                                      if type(aM) == "table" then
                                          if aK[aL] then
                                              m[aL] = d.Util.tableMerge(aM, aK[aL])
                                          else
                                              m[aL] = aM
                                          end
                                      else
                                          m[aL] = aK[aL] or aJ[aL]
                                      end
                                  end
                                  for aL, aM in pairs(aK) do
                                      if not m[aL] then
                                          m[aL] = aM
                                      end
                                  end
                                  return m
                              end,
                              stringSplit = function(aN, aO, aP)
                                  return {strsplit(aN, aO, aP)}
                              end,
                              __genOrderedIndex = function(aQ)
                                  local aR = {}
                                  for aS in pairs(aQ) do
                                      e(aR, aS)
                                  end
                                  ah(
                                      aR,
                                      function(aF, aE)
                                          if not aQ[aF].order or not aQ[aE].order then
                                              return aF < aE
                                          end
                                          return aQ[aF].order < aQ[aE].order
                                      end
                                  )
                                  return aR
                              end,
                              orderedNext = function(aQ, aT)
                                  local aS
                                  if aT == nil then
                                      aQ.__orderedIndex = d.Util.__genOrderedIndex(aQ)
                                      aS = aQ.__orderedIndex[1]
                                  else
                                      for n = 1, ag(aQ.__orderedIndex) do
                                          if aQ.__orderedIndex[n] == aT then
                                              aS = aQ.__orderedIndex[n + 1]
                                          end
                                      end
                                  end
                                  if aS then
                                      return aS, aQ[aS]
                                  end
                                  aQ.__orderedIndex = nil
                                  return
                              end,
                              orderedPairs = function(aQ)
                                  return d.Util.orderedNext, aQ, nil
                              end,
                              roundPrecision = function(ap, aU)
                                  local aV = 10 ^ (aU or 0)
                                  return math.floor(ap * aV + 0.5) / aV
                              end
                          }
                          d:RegisterModule(g, h)
                      end
                      local function aW(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Layout", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local e = tinsert
                          local aX = tremove
                          local pairs = pairs
                          local aY = math.max
                          local aZ = math.floor
                          local a_ = {gutter = 10, columns = 12, padding = {top = 0, right = 10, left = 10, bottom = 10}}
                          local b0 = {margin = {top = 0, right = 0, bottom = 15, left = 0}}
                          local b1 = {margin = {top = 0, right = 0, bottom = 0, left = 0}}
                          local b2 = {AddElement = function(self, x, A)
                                  if not x.layoutConfig then
                                      x.layoutConfig = d.Util.tableMerge(b1, A or {})
                                  elseif A then
                                      x.layoutConfig = d.Util.tableMerge(x.layoutConfig, A or {})
                                  end
                                  e(self.elements, x)
                              end, AddElements = function(self, ...)
                                  local aC = {...}
                                  local b3 = aX(aC, #aC)
                                  if b3.column == "even" then
                                      b3.column = aZ(self.parent.layout.columns / #aC)
                                  end
                                  for n = 1, #aC do
                                      self:AddElement(aC[n], d.Util.tableMerge(b1, b3))
                                  end
                              end, GetColumnsTaken = function(self)
                                  local b4 = 0
                                  local b5 = self.parent.layout
                                  for n = 1, #self.elements do
                                      local b6 = self.elements[n].layoutConfig
                                      local b7 = b6.column or b5.columns
                                      b4 = b4 + b7
                                  end
                                  return b4
                              end, DrawRow = function(self, b8, b9)
                                  b9 = b9 or 0
                                  local b5 = self.parent.layout
                                  local aD = b5.gutter
                                  local ba = self.config.margin
                                  local bb = 0
                                  local b4 = 0
                                  local a3 = aD + b5.padding.left + ba.left
                                  b8 = b8 - ba.left - ba.right
                                  for n = 1, #self.elements do
                                      local x = self.elements[n]
                                      x:ClearAllPoints()
                                      local b6 = x.layoutConfig
                                      local bc = b6.margin
                                      if b6.fullSize then
                                          d:GlueAcross(x, self.parent, b5.padding.left, -b5.padding.top, -b5.padding.right, b5.padding.bottom)
                                          if x.DoLayout then
                                              x:DoLayout()
                                          end
                                          bb = aY(bb, x:GetHeight() + bc.bottom + bc.top + ba.top + ba.bottom)
                                          return bb
                                      end
                                      local b7 = b6.column or b5.columns
                                      local bd = b8 / (b5.columns / b7) - 2 * aD
                                      x:SetWidth(bd)
                                      if b4 + b7 > self.parent.layout.columns then
                                          print("Element will not fit row capacity: " .. b5.columns)
                                          return bb
                                      end
                                      x:SetPoint("TOPLEFT", self.parent, "TOPLEFT", a3, b9 - bc.top - ba.top)
                                      if b6.fullHeight then
                                          x:SetPoint("BOTTOMLEFT", self.parent, "BOTTOMLEFT", a3, bc.bottom + ba.bottom)
                                      end
                                      a3 = a3 + bd + 2 * aD
                                      if x.DoLayout then
                                          x:DoLayout()
                                      end
                                      bb = aY(bb, x:GetHeight() + bc.bottom + bc.top + ba.top + ba.bottom)
                                      b4 = b4 + b7
                                  end
                                  return bb
                              end}
                          function d:EasyLayoutRow(be, A)
                              local bf = {parent = be, config = self.Util.tableMerge(b0, A or {}), elements = {}}
                              for aL, aM in pairs(b2) do
                                  bf[aL] = aM
                              end
                              return bf
                          end
                          local bg = {AddRow = function(self, A)
                                  if not self.rows then
                                      self.rows = {}
                                  end
                                  local bf = self.stdUi:EasyLayoutRow(self, A)
                                  e(self.rows, bf)
                                  return bf
                              end, DoLayout = function(self)
                                  local b5 = self.layout
                                  local q = self:GetWidth() - b5.padding.left - b5.padding.right
                                  local a4 = -b5.padding.top
                                  for n = 1, #self.rows do
                                      local bf = self.rows[n]
                                      a4 = a4 - bf:DrawRow(q, a4)
                                  end
                              end}
                          function d:EasyLayout(be, A)
                              be.stdUi = self
                              be.layout = self.Util.tableMerge(a_, A or {})
                              for aL, aM in pairs(bg) do
                                  be[aL] = aM
                              end
                          end
                          d:RegisterModule(g, h)
                      end
                      local function bh(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Grid", 4
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          function d:ObjectList(be, bi, bj, bk, bl, bm, bn, bo, bp)
                              local D = self
                              bn = bn or 1
                              bo = bo or -1
                              bm = bm or 0
                              if not bi then
                                  bi = {}
                              end
                              for n = 1, #bi do
                                  bi[n]:Hide()
                              end
                              local bb = -bo
                              local n = 1
                              for aS, ap in pairs(bl) do
                                  local bq = bi[n]
                                  if not bq then
                                      if type(bj) == "string" then
                                          bi[n] = D[bj](D, be)
                                      else
                                          bi[n] = bj(be, ap, n, aS)
                                      end
                                      bq = bi[n]
                                  end
                                  bk(be, bq, ap, n, aS)
                                  bq:Show()
                                  bb = bb + bq:GetHeight()
                                  if n == 1 then
                                      D:GlueTop(bq, be, bn, bo, "LEFT")
                                  else
                                      D:GlueBelow(bq, bi[n - 1], 0, -bm)
                                      bb = bb + bm
                                  end
                                  if bp and bp(n, bb, bq:GetHeight()) then
                                      break
                                  end
                                  n = n + 1
                              end
                              return bi, bb
                          end
                          function d:ObjectGrid(be, br, bj, bk, bl, bs, bt, bn, bo)
                              bn = bn or 1
                              bo = bo or -1
                              bs = bs or 0
                              bt = bt or 0
                              if not br then
                                  br = {}
                              end
                              for a4 = 1, #br do
                                  for a3 = 1, #br[a4] do
                                      br[a4][a3]:Hide()
                                  end
                              end
                              for bu = 1, #bl do
                                  local bf = bl[bu]
                                  for bv = 1, #bf do
                                      if not br[bu] then
                                          br[bu] = {}
                                      end
                                      local bq = br[bu][bv]
                                      if not bq then
                                          if type(bj) == "string" then
                                              bq = self[bj](self, be)
                                          else
                                              bq = bj(be, bl[bu][bv], bu, bv)
                                          end
                                          br[bu][bv] = bq
                                      end
                                      bk(be, bq, bl[bu][bv], bu, bv)
                                      bq:Show()
                                      if bu == 1 and bv == 1 then
                                          self:GlueTop(bq, be, bn, bo, "LEFT")
                                      else
                                          if bv == 1 then
                                              self:GlueBelow(bq, br[bu - 1][bv], 0, -bt, "LEFT")
                                          else
                                              self:GlueRight(bq, br[bu][bv - 1], bs, 0)
                                          end
                                      end
                                  end
                              end
                          end
                          d:RegisterModule(g, h)
                      end
                      local function bw(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Builder", 6
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local bx = d.Util
                          local function by(bz, aS, ap)
                              if aS:find(".") then
                                  local bA = d.Util.stringSplit(".", aS)
                                  local bB = bz
                                  for n, bC in pairs(bA) do
                                      if n == #bA then
                                          bB[bC] = ap
                                          return
                                      end
                                      bB = bB[bC]
                                  end
                              else
                                  bz[aS] = ap
                              end
                          end
                          local function bD(bz, aS)
                              if aS:find(".") then
                                  local bA = d.Util.stringSplit(".", aS)
                                  local bB = bz
                                  for n, bC in pairs(bA) do
                                      if n == #bA then
                                          return bB[bC]
                                      end
                                      bB = bB[bC]
                                  end
                              else
                                  return bz[aS]
                              end
                          end
                          function d:BuildElement(x, bf, bE, bF, bz)
                              local bG
                              local bH = function(bI, ap)
                                  by(bI.dbReference, bI.dataKey, ap)
                                  if bI.onChange then
                                      bI:onChange(ap)
                                  end
                              end
                              local bJ = false
                              if bE.type == "checkbox" then
                                  bG = self:Checkbox(x, bE.label)
                              elseif bE.type == "editBox" then
                                  bG = self:EditBox(x, nil, 20)
                              elseif bE.type == "multiLineBox" then
                                  bG = self:MultiLineBox(x, 300, 20)
                              elseif bE.type == "dropdown" then
                                  bG = self:Dropdown(x, 300, 20, bE.options or {}, nil, bE.multi or nil, bE.assoc or false)
                              elseif bE.type == "autocomplete" then
                                  bG = self:Autocomplete(x, 300, 20, "")
                                  if bE.validator then
                                      bG.validator = bE.validator
                                  end
                                  if bE.transformer then
                                      bG.transformer = bE.transformer
                                  end
                                  if bE.buttonCreate then
                                      bG.buttonCreate = bE.buttonCreate
                                  end
                                  if bE.buttonUpdate then
                                      bG.buttonUpdate = bE.buttonUpdate
                                  end
                                  if bE.items then
                                      bG:SetItems(bE.items)
                                  end
                              elseif bE.type == "slider" or bE.type == "sliderWithBox" then
                                  bG = self:SliderWithBox(x, nil, 32, 0, bE.min or 0, bE.max or 2)
                                  if bE.precision then
                                      bG:SetPrecision(bE.precision)
                                  end
                              elseif bE.type == "color" then
                                  bG = self:ColorInput(x, bE.label, 100, 20, bE.color)
                              elseif bE.type == "button" then
                                  bG = self:Button(x, nil, 20, bE.text or "")
                                  if bE.onClick then
                                      bG:SetScript("OnClick", bE.onClick)
                                  end
                              elseif bE.type == "header" then
                                  bG = self:Header(x, bE.label)
                              elseif bE.type == "label" then
                                  bG = self:Label(x, bE.label)
                              elseif bE.type == "texture" then
                                  bG = self:Texture(x, bE.width or 24, bE.height or 24, bE.texture)
                              elseif bE.type == "panel" then
                                  bG = self:Panel(x, 300, 20)
                              elseif bE.type == "scroll" then
                                  bG = self:ScrollFrame(x, 300, 20, type(bE.scrollChild) == "table" and bE.scrollChild or nil)
                                  if type(bE.scrollChild) == "function" then
                                      bE.scrollChild(bG)
                                  end
                              elseif bE.type == "fauxScroll" then
                                  bG =
                                      self:FauxScrollFrame(
                                      x,
                                      300,
                                      20,
                                      bE.displayCount or 5,
                                      bE.lineHeight or 22,
                                      type(bE.scrollChild) == "table" and bE.scrollChild or nil
                                  )
                                  if type(bE.scrollChild) == "function" then
                                      bE.scrollChild(bG)
                                  end
                              elseif bE.type == "tab" then
                                  bG = self:TabPanel(x, 300, 20, bE.tabs or {}, bE.vertical or false, bE.buttonWidth, bE.buttonHeight)
                              elseif bE.type == "custom" then
                                  bG = bE.createFunction(x, bf, bE, bF, bz)
                              end
                              if not bG then
                                  print("Could not build element with type: ", bE.type)
                              end
                              if bE.init then
                                  bE.init(bG)
                              end
                              bG.dbReference = bz
                              bG.dataKey = bF
                              if bE.onChange then
                                  bG.onChange = bE.onChange
                              end
                              if bG.hasLabel then
                                  bJ = true
                              end
                              local bK = bE.type ~= "checkbox" and bE.type ~= "header" and bE.type ~= "label" and bE.type ~= "color"
                              if bE.label and bK then
                                  self:AddLabel(x, bG, bE.label)
                                  bJ = true
                              end
                              if bE.initialValue then
                                  if bG.SetChecked then
                                      bG:SetChecked(bE.initialValue)
                                  elseif bG.SetColor then
                                      bG:SetColor(bE.initialValue)
                                  elseif bG.SetValue then
                                      bG:SetValue(bE.initialValue)
                                  end
                              end
                              if bE.onValueChanged then
                                  bG.OnValueChanged = bE.onValueChanged
                              elseif bz then
                                  local bL = bD(bz, bF)
                                  if bE.type == "checkbox" then
                                      bG:SetChecked(bL)
                                  elseif bG.SetColor then
                                      bG:SetColor(bL)
                                  elseif bG.SetValue then
                                      bG:SetValue(bL)
                                  end
                                  bG.OnValueChanged = bH
                              end
                              if bE.children then
                                  self:BuildWindow(bG, bE.children)
                                  self:EasyLayout(bG, {padding = {top = 10}})
                                  bG:SetScript(
                                      "OnShow",
                                      function(bM)
                                          bM:DoLayout()
                                      end
                                  )
                              end
                              bf:AddElement(
                                  bG,
                                  {
                                      column = bE.column or 12,
                                      fullSize = bE.fullSize or false,
                                      fullHeight = bE.fullHeight or false,
                                      margin = bE.layoutMargins or {top = bJ and 20 or 0}
                                  }
                              )
                              return bG
                          end
                          function d:BuildRow(x, bE, bz)
                              local bf = x:AddRow()
                              for aS, bG in bx.orderedPairs(bE) do
                                  local bF = bG.key or aS or nil
                                  local bI = self:BuildElement(x, bf, bG, bF, bz)
                                  if bG then
                                      if not x.elements then
                                          x.elements = {}
                                      end
                                      x.elements[aS] = bI
                                  end
                              end
                          end
                          function d:BuildWindow(x, bE)
                              local bz = bE.database or nil
                              assert(bE.rows, "Rows are required in order to build table")
                              local bN = bE.rows
                              self:EasyLayout(x, bE.layoutConfig)
                              for N, bf in bx.orderedPairs(bN) do
                                  self:BuildRow(x, bf, bz)
                              end
                              x:DoLayout()
                          end
                          d:RegisterModule(g, h)
                      end
                      local function bO(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Basic", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          function d:Frame(be, q, r, bP)
                              local x = CreateFrame("Frame", nil, be, bP)
                              self:InitWidget(x)
                              self:SetObjSize(x, q, r)
                              return x
                          end
                          function d:Panel(be, q, r, bP)
                              local x = self:Frame(be, q, r, bP)
                              self:ApplyBackdrop(x, "panel")
                              return x
                          end
                          function d:PanelWithLabel(be, q, r, bP, aj)
                              local x = self:Panel(be, q, r, bP)
                              x.label = self:Header(x, aj)
                              x.label:SetAllPoints()
                              x.label:SetJustifyH("MIDDLE")
                              return x
                          end
                          function d:PanelWithTitle(be, q, r, aj)
                              local x = self:Panel(be, q, r)
                              x.titlePanel = self:PanelWithLabel(x, 100, 20, nil, aj)
                              x.titlePanel:SetPoint("TOP", 0, -10)
                              x.titlePanel:SetPoint("LEFT", 30, 0)
                              x.titlePanel:SetPoint("RIGHT", -30, 0)
                              x.titlePanel:SetBackdrop(nil)
                              return x
                          end
                          function d:Texture(be, q, r, bQ)
                              local bR = be:CreateTexture(nil, "ARTWORK")
                              self:SetObjSize(bR, q, r)
                              if bQ then
                                  bR:SetTexture(bQ)
                              end
                              return bR
                          end
                          function d:ArrowTexture(be, G)
                              local bQ = self:Texture(be, 16, 8, "Interface\\Buttons\\Arrow-Up-Down")
                              if G == "UP" then
                                  bQ:SetTexCoord(0, 1, 0.5, 1)
                              else
                                  bQ:SetTexCoord(0, 1, 1, 0.5)
                              end
                              return bQ
                          end
                          d:RegisterModule(g, h)
                      end
                      local function bS(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Window", 5
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          function d:Window(be, q, r, bT)
                              be = be or UIParent
                              local x = self:PanelWithTitle(be, q, r, bT)
                              x:SetClampedToScreen(true)
                              x.titlePanel.isWidget = false
                              self:MakeDraggable(x)
                              local bU = self:Button(x, 16, 16, "X")
                              bU.text:SetFontSize(12)
                              bU.isWidget = false
                              self:GlueTop(bU, x, -10, -10, "RIGHT")
                              bU:SetScript(
                                  "OnClick",
                                  function(self)
                                      self:GetParent():Hide()
                                  end
                              )
                              x.closeBtn = bU
                              function x:SetWindowTitle(aQ)
                                  self.titlePanel.label:SetText(aQ)
                              end
                              function x:MakeResizable(G)
                                  d:MakeResizable(x, G)
                                  return x
                              end
                              return x
                          end
                          d.dialogs = {}
                          function d:Dialog(bT, bV, bW)
                              local bX
                              if bW and self.dialogs[bW] then
                                  bX = self.dialogs[bW]
                              else
                                  bX = self:Window(nil, self.config.dialog.width, self.config.dialog.height, bT)
                                  bX:SetPoint("CENTER")
                                  bX:SetFrameStrata("DIALOG")
                              end
                              if bX.messageLabel then
                                  bX.messageLabel:SetText(bV)
                              else
                                  bX.messageLabel = self:Label(bX, bV)
                                  bX.messageLabel:SetJustifyH("MIDDLE")
                                  self:GlueAcross(bX.messageLabel, bX, 5, -10, -5, 5)
                              end
                              bX:Show()
                              if bW then
                                  self.dialogs[bW] = bX
                              end
                              return bX
                          end
                          function d:Confirm(bT, bV, bY, bW)
                              local bX = self:Dialog(bT, bV, bW)
                              if bY and not bX.buttons then
                                  bX.buttons = {}
                                  local bZ = self.Util.tableCount(bY)
                                  local b_ = self.config.dialog.button.margin
                                  local c0 = self.config.dialog.button.width
                                  local c1 = self.config.dialog.button.height
                                  local c2 = bZ * c0 + (bZ - 1) * b_
                                  local c3 = math.floor((self.config.dialog.width - c2) / 2)
                                  local n = 0
                                  for aL, c4 in pairs(bY) do
                                      local c5 = self:Button(bX, c0, c1, c4.text)
                                      c5.window = bX
                                      self:GlueBottom(c5, bX, c3 + n * (c0 + b_), 10, "LEFT")
                                      if c4.onClick then
                                          c5:SetScript("OnClick", c4.onClick)
                                      end
                                      bX.buttons[aL] = c5
                                      n = n + 1
                                  end
                                  bX.messageLabel:ClearAllPoints()
                                  self:GlueAcross(bX.messageLabel, bX, 5, -10, -5, 5 + c1 + 5)
                              end
                              return bX
                          end
                          d:RegisterModule(g, h)
                      end
                      local function c6(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Button", 6
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local c7 = {
                              UP = {0.45312500, 0.64062500, 0.01562500, 0.20312500},
                              DOWN = {0.45312500, 0.64062500, 0.20312500, 0.01562500},
                              LEFT = {0.23437500, 0.42187500, 0.01562500, 0.20312500},
                              RIGHT = {0.42187500, 0.23437500, 0.01562500, 0.20312500},
                              DELETE = {0.01562500, 0.20312500, 0.01562500, 0.20312500}
                          }
                          local c8 = {SetIconDisabled = function(self, bQ, c9, ca)
                                  self.iconDisabled = self.stdUi:Texture(self, c9, ca, bQ)
                                  self.iconDisabled:SetDesaturated(true)
                                  self.iconDisabled:SetPoint("CENTER", 0, 0)
                                  self:SetDisabledTexture(self.iconDisabled)
                              end, SetIcon = function(self, bQ, c9, ca, cb)
                                  self.icon = self.stdUi:Texture(self, c9, ca, bQ)
                                  self.icon:SetPoint("CENTER", 0, 0)
                                  self:SetNormalTexture(self.icon)
                                  if cb then
                                      self:SetIconDisabled(bQ, c9, ca)
                                  end
                              end}
                          function d:SquareButton(be, q, r, aq)
                              local J = CreateFrame("Button", nil, be)
                              J.stdUi = self
                              self:InitWidget(J)
                              self:SetObjSize(J, q, r)
                              self:ApplyBackdrop(J)
                              self:HookDisabledBackdrop(J)
                              self:HookHoverBorder(J)
                              for aL, aM in pairs(c8) do
                                  J[aL] = aM
                              end
                              local cc = c7[aq]
                              if cc then
                                  J:SetIcon("Interface\\Buttons\\SquareButtonTextures", 16, 16, true)
                                  J.icon:SetTexCoord(cc[1], cc[2], cc[3], cc[4])
                                  J.iconDisabled:SetTexCoord(cc[1], cc[2], cc[3], cc[4])
                              end
                              return J
                          end
                          function d:ButtonLabel(be, aj)
                              local cd = self:Label(be, aj)
                              cd:SetJustifyH("CENTER")
                              self:GlueAcross(cd, be, 2, -2, -2, 2)
                              be:SetFontString(cd)
                              return cd
                          end
                          function d:HighlightButtonTexture(J)
                              local ce = self:Texture(J, nil, nil, nil)
                              ce:SetColorTexture(
                                  self.config.highlight.color.r,
                                  self.config.highlight.color.g,
                                  self.config.highlight.color.b,
                                  self.config.highlight.color.a
                              )
                              ce:SetAllPoints()
                              return ce
                          end
                          function d:HighlightButton(be, q, r, aj, cf)
                              local J = CreateFrame("Button", nil, be, cf)
                              self:InitWidget(J)
                              self:SetObjSize(J, q, r)
                              J.text = self:ButtonLabel(J, aj)
                              function J:SetFontSize(cg)
                                  self.text:SetFontSize(cg)
                              end
                              local ce = self:HighlightButtonTexture(J)
                              ce:SetBlendMode("ADD")
                              J:SetHighlightTexture(ce)
                              J.highlightTexture = ce
                              return J
                          end
                          function d:Button(be, q, r, aj, cf)
                              local J = self:HighlightButton(be, q, r, aj, cf)
                              J.stdUi = self
                              J:SetHighlightTexture(nil)
                              self:ApplyBackdrop(J)
                              self:HookDisabledBackdrop(J)
                              self:HookHoverBorder(J)
                              return J
                          end
                          function d:ButtonAutoWidth(J, bm)
                              bm = bm or 5
                              J:SetWidth(J.text:GetStringWidth() + bm * 2)
                          end
                          d:RegisterModule(g, h)
                      end
                      local function ch(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "EditBox", 9
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local pairs = pairs
                          local strlen = strlen
                          local ci = {SetFontSize = function(self, cg)
                                  self:SetFont(self:GetFont(), cg, self.stdUi.config.font.effect)
                              end}
                          local cj = {OnEscapePressed = function(self)
                                  self:ClearFocus()
                              end}
                          function d:SimpleEditBox(be, q, r, aj)
                              local ck = CreateFrame("EditBox", nil, be)
                              ck.stdUi = self
                              self:InitWidget(ck)
                              ck:SetTextInsets(3, 3, 3, 3)
                              ck:SetFontObject(ChatFontNormal)
                              ck:SetAutoFocus(false)
                              for aL, aM in pairs(ci) do
                                  ck[aL] = aM
                              end
                              for aL, aM in pairs(cj) do
                                  ck:SetScript(aL, aM)
                              end
                              if aj then
                                  ck:SetText(aj)
                              end
                              self:HookDisabledBackdrop(ck)
                              self:HookHoverBorder(ck)
                              self:ApplyBackdrop(ck)
                              self:SetObjSize(ck, q, r)
                              return ck
                          end
                          local cl = function(self)
                              if strlen(self:GetText()) > 0 then
                                  self.placeholder.icon:Hide()
                                  self.placeholder.label:Hide()
                              else
                                  self.placeholder.icon:Show()
                                  self.placeholder.label:Show()
                              end
                          end
                          function d:ApplyPlaceholder(k, cm, aq, cn)
                              k.placeholder = {}
                              local cd = self:Label(k, cm)
                              self:SetTextColor(cd, "disabled")
                              k.placeholder.label = cd
                              if aq then
                                  local bQ = self:Texture(k, 14, 14, aq)
                                  local u = cn or self.config.font.color.disabled
                                  bQ:SetVertexColor(u.r, u.g, u.b, u.a)
                                  self:GlueLeft(bQ, k, 5, 0, true)
                                  self:GlueRight(cd, bQ, 2, 0)
                                  k.placeholder.icon = bQ
                              else
                                  self:GlueLeft(cd, k, 2, 0, true)
                              end
                              k:HookScript("OnTextChanged", cl)
                          end
                          local co = function(self)
                              if self.OnValueChanged then
                                  self:OnValueChanged(self:GetText())
                              end
                          end
                          function d:SearchEditBox(be, q, r, cm)
                              local ck = self:SimpleEditBox(be, q, r, "")
                              ck:SetScript("OnTextChanged", co)
                              self:ApplyPlaceholder(ck, cm, "Interface\\Common\\UI-Searchbox-Icon")
                              return ck
                          end
                          local cp = {GetValue = function(self)
                                  return self.value
                              end, SetValue = function(self, ap)
                                  self.value = ap
                                  self:SetText(ap)
                                  self:Validate()
                                  self.button:Hide()
                              end, IsValid = function(self)
                                  return self.isValid
                              end, Validate = function(self)
                                  self.isValidated = true
                                  self.isValid = self.validator(self)
                                  if self.isValid then
                                      if self.button then
                                          self.button:Hide()
                                      end
                                      if self.OnValueChanged and tostring(self.lastValue) ~= tostring(self.value) then
                                          self:OnValueChanged(self.value)
                                          self.lastValue = self.value
                                      end
                                  end
                                  self.isValidated = false
                              end}
                          local cq = function(self)
                              self.editBox:Validate(self.editBox)
                          end
                          local cr = {OnEnterPressed = function(self)
                                  self:Validate()
                              end, OnTextChanged = function(self, cs)
                                  local ap = d.Util.stripColors(self:GetText())
                                  if tostring(ap) ~= tostring(self.value) then
                                      if not self.isValidated and self.button and cs then
                                          self.button:Show()
                                      end
                                  else
                                      self.button:Hide()
                                  end
                              end}
                          function d:EditBox(be, q, r, aj, ct)
                              ct = ct or d.Util.editBoxValidator
                              local ck = self:SimpleEditBox(be, q, r, aj)
                              ck.validator = ct
                              local J = self:Button(ck, 40, r - 4, OKAY)
                              J:SetPoint("RIGHT", -2, 0)
                              J:Hide()
                              J.editBox = ck
                              ck.button = J
                              for aL, aM in pairs(cp) do
                                  ck[aL] = aM
                              end
                              J:SetScript("OnClick", cq)
                              for aL, aM in pairs(cr) do
                                  ck:SetScript(aL, aM)
                              end
                              return ck
                          end
                          local cu = {SetMaxValue = function(self, ap)
                                  self.maxValue = ap
                                  self:Validate()
                              end, SetMinValue = function(self, ap)
                                  self.minValue = ap
                                  self:Validate()
                              end, SetMinMaxValue = function(self, cv, cw)
                                  self.minValue = cv
                                  self.maxValue = cw
                                  self:Validate()
                              end}
                          function d:NumericBox(be, q, r, aj, ct)
                              ct = ct or self.Util.numericBoxValidator
                              local ck = self:EditBox(be, q, r, aj, ct)
                              ck:SetNumeric(true)
                              for aL, aM in pairs(cu) do
                                  ck[aL] = aM
                              end
                              return ck
                          end
                          local cx = {SetValue = function(self, ap)
                                  self.value = ap
                                  local cy = self.stdUi.Util.formatMoney(ap)
                                  self:SetText(cy)
                                  self:Validate()
                                  self.button:Hide()
                              end}
                          function d:MoneyBox(be, q, r, aj, ct, ax)
                              if ax then
                                  ct = ct or self.Util.moneyBoxValidatorExC
                              else
                                  ct = ct or self.Util.moneyBoxValidator
                              end
                              local ck = self:EditBox(be, q, r, aj, ct)
                              ck.stdUi = self
                              ck:SetMaxLetters(20)
                              for aL, aM in pairs(cx) do
                                  ck[aL] = aM
                              end
                              return ck
                          end
                          local cz = {SetValue = function(self, ap)
                                  self.editBox:SetText(ap)
                                  if self.OnValueChanged then
                                      self:OnValueChanged(ap)
                                  end
                              end, GetValue = function(self)
                                  return self.editBox:GetText()
                              end, SetFont = function(self, L, Q, cA)
                                  self.editBox:SetFont(L, Q, cA)
                              end, Enable = function(self)
                                  self.editBox:Enable()
                              end, Disable = function(self)
                                  self.editBox:Disable()
                              end, SetFocus = function(self)
                                  self.editBox:SetFocus()
                              end, ClearFocus = function(self)
                                  self.editBox:ClearFocus()
                              end, HasFocus = function(self)
                                  return self.editBox:HasFocus()
                              end}
                          local cB = function(self, N, a4, N, cC)
                              local cD, cE = self.scrollFrame, -a4
                              local cF = cD:GetVerticalScroll()
                              if cE < cF then
                                  cD:SetVerticalScroll(cE)
                              else
                                  cE = cE + cC - cD:GetHeight() + 6
                                  if cE > cF then
                                      cD:SetVerticalScroll(math.ceil(cE))
                                  end
                              end
                          end
                          local cG = function(self)
                              if self.panel.OnValueChanged then
                                  self.panel.OnValueChanged(self.panel, self:GetText())
                              end
                          end
                          local cH = function(self, J)
                              self.scrollChild:SetFocus()
                          end
                          local cI = function(self, cF)
                              self.scrollChild:SetHitRectInsets(0, 0, cF, self.scrollChild:GetHeight() - cF - self:GetHeight())
                          end
                          function d:MultiLineBox(be, q, r, aj)
                              local ck = CreateFrame("EditBox")
                              local k = self:ScrollFrame(be, q, r, ck)
                              ck.stdUi = self
                              local cJ = k.scrollFrame
                              cJ.editBox = ck
                              k.editBox = ck
                              ck.panel = k
                              self:ApplyBackdrop(k, "button")
                              self:HookHoverBorder(cJ)
                              self:HookHoverBorder(ck)
                              ck:SetWidth(cJ:GetWidth())
                              self:GlueAcross(cJ, k, 2, -2, -k.scrollBarWidth - 2, 3)
                              ck:SetTextInsets(3, 3, 3, 3)
                              ck:SetFontObject(ChatFontNormal)
                              ck:SetAutoFocus(false)
                              ck:SetScript("OnEscapePressed", ck.ClearFocus)
                              ck:SetMultiLine(true)
                              ck:EnableMouse(true)
                              ck:SetAutoFocus(false)
                              ck:SetCountInvisibleLetters(false)
                              ck:SetAllPoints()
                              ck.scrollFrame = cJ
                              ck.panel = k
                              for aL, aM in pairs(cz) do
                                  k[aL] = aM
                              end
                              if aj then
                                  ck:SetText(aj)
                              end
                              ck:SetScript("OnCursorChanged", cB)
                              ck:SetScript("OnTextChanged", cG)
                              cJ:HookScript("OnMouseDown", cH)
                              cJ:HookScript("OnVerticalScroll", cI)
                              k.SetText = k.SetValue
                              k.GetText = k.GetValue
                              return k
                          end
                          d:RegisterModule(g, h)
                      end
                      local function cK(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Checkbox", 5
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local cL = {SetChecked = function(self, cM, cN)
                                  self.isChecked = cM
                                  if not cN and self.OnValueChanged then
                                      self:OnValueChanged(cM, self.value)
                                  end
                                  if not cM then
                                      self.checkedTexture:Hide()
                                      self.disabledCheckedTexture:Hide()
                                      return
                                  end
                                  if self.isDisabled then
                                      self.checkedTexture:Hide()
                                      self.disabledCheckedTexture:Show()
                                  else
                                      self.checkedTexture:Show()
                                      self.disabledCheckedTexture:Hide()
                                  end
                              end, GetChecked = function(self)
                                  return self.isChecked
                              end, SetText = function(self, aQ)
                                  self.text:SetText(aQ)
                              end, SetValue = function(self, ap)
                                  self.value = ap
                              end, GetValue = function(self)
                                  if self:GetChecked() then
                                      return self.value
                                  else
                                      return nil
                                  end
                              end, Disable = function(self)
                                  self.isDisabled = true
                                  self:SetChecked(self.isChecked)
                              end, Enable = function(self)
                                  self.isDisabled = false
                                  self:SetChecked(self.isChecked)
                              end, AutoWidth = function(self)
                                  self:SetWidth(self.target:GetWidth() + 15 + self.text:GetWidth())
                              end}
                          local cO = {OnClick = function(self)
                                  if not self.isDisabled then
                                      self:SetChecked(not self:GetChecked())
                                  end
                              end}
                          function d:Checkbox(be, aj, q, r)
                              local cP = CreateFrame("Button", nil, be)
                              cP.stdUi = self
                              cP:EnableMouse(true)
                              self:SetObjSize(cP, q, r or 20)
                              self:InitWidget(cP)
                              cP.target = self:Panel(cP, 16, 16)
                              cP.target.stdUi = self
                              cP.target:SetPoint("LEFT", 0, 0)
                              cP.value = true
                              cP.isChecked = false
                              cP.text = self:Label(cP, aj)
                              cP.text:SetPoint("LEFT", cP.target, "RIGHT", 5, 0)
                              cP.text:SetPoint("RIGHT", cP, "RIGHT", -5, 0)
                              cP.target.text = cP.text
                              cP.checkedTexture = self:Texture(cP.target, nil, nil, "Interface\\Buttons\\UI-CheckBox-Check")
                              cP.checkedTexture:SetAllPoints()
                              cP.checkedTexture:Hide()
                              cP.disabledCheckedTexture = self:Texture(cP.target, nil, nil, "Interface\\Buttons\\UI-CheckBox-Check-Disabled")
                              cP.disabledCheckedTexture:SetAllPoints()
                              cP.disabledCheckedTexture:Hide()
                              for aL, aM in pairs(cL) do
                                  cP[aL] = aM
                              end
                              self:ApplyBackdrop(cP.target)
                              self:HookDisabledBackdrop(cP)
                              self:HookHoverBorder(cP)
                              if q == nil then
                                  cP:AutoWidth()
                              end
                              for aL, aM in pairs(cO) do
                                  cP:SetScript(aL, aM)
                              end
                              return cP
                          end
                          function d:IconCheckbox(be, aq, aj, q, r, cQ)
                              cQ = cQ or 16
                              local cP = self:Checkbox(be, aj, q, r)
                              cP.icon = self:Texture(cP, cQ, cQ, aq)
                              cP.icon:SetPoint("LEFT", cP.target, "RIGHT", 5, 0)
                              cP.text:ClearAllPoints()
                              cP.text:SetPoint("LEFT", cP.target, "RIGHT", cQ + 5, 0)
                              cP.text:SetPoint("RIGHT", cP, "RIGHT", -5, 0)
                              return cP
                          end
                          local cR = {OnClick = function(self)
                                  if not self.isDisabled then
                                      self:SetChecked(true)
                                  end
                              end}
                          function d:Radio(be, aj, cS, q, r)
                              local cT = self:Checkbox(be, aj, q, r)
                              cT.checkedTexture = self:Texture(cT.target, nil, nil, "Interface\\Buttons\\UI-RadioButton")
                              cT.checkedTexture:SetAllPoints(cT.target)
                              cT.checkedTexture:Hide()
                              cT.checkedTexture:SetTexCoord(0.25, 0.5, 0, 1)
                              cT.disabledCheckedTexture = self:Texture(cT.target, nil, nil, "Interface\\Buttons\\UI-RadioButton")
                              cT.disabledCheckedTexture:SetAllPoints(cT.target)
                              cT.disabledCheckedTexture:Hide()
                              cT.disabledCheckedTexture:SetTexCoord(0.75, 1, 0, 1)
                              for aL, aM in pairs(cR) do
                                  cT:SetScript(aL, aM)
                              end
                              if cS then
                                  self:AddToRadioGroup(cT, cS)
                              end
                              return cT
                          end
                          d.radioGroups = {}
                          d.radioGroupValues = {}
                          function d:RadioGroup(cS)
                              if not self.radioGroups[cS] then
                                  self.radioGroups[cS] = {}
                              end
                              if not self.radioGroupValues[cS] then
                                  self.radioGroupValues[cS] = {}
                              end
                              return self.radioGroups[cS]
                          end
                          function d:GetRadioGroupValue(cS)
                              local cU = self:RadioGroup(cS)
                              for n = 1, #cU do
                                  local cT = cU[n]
                                  if cT:GetChecked() then
                                      return cT:GetValue()
                                  end
                              end
                              return nil
                          end
                          function d:SetRadioGroupValue(cS, ap)
                              local cU = self:RadioGroup(cS)
                              for n = 1, #cU do
                                  local cT = cU[n]
                                  cT:SetChecked(cT.value == ap)
                              end
                              return nil
                          end
                          local cV = function(cT)
                              cT.notified = true
                              local cU = cT.radioGroup
                              local cS = cT.radioGroupName
                              for n = 1, #cU do
                                  if not cU[n].notified then
                                      return
                                  end
                              end
                              local cW = cT.stdUi:GetRadioGroupValue(cS)
                              if cT.stdUi.radioGroupValues[cS] ~= cW then
                                  cT.OnValueChangedCallback(cW, cS)
                              end
                              cT.stdUi.radioGroupValues[cS] = cW
                              for n = 1, #cU do
                                  cU[n].notified = false
                              end
                          end
                          function d:OnRadioGroupValueChanged(cS, cX)
                              local cU = self:RadioGroup(cS)
                              for n = 1, #cU do
                                  local cT = cU[n]
                                  cT.OnValueChangedCallback = cX
                                  cT.OnValueChanged = cV
                              end
                              return nil
                          end
                          local cY = {OnClick = function(cT)
                                  for n = 1, #cT.radioGroup do
                                      local cZ = cT.radioGroup[n]
                                      if cZ ~= cT then
                                          cZ:SetChecked(false)
                                      end
                                  end
                              end}
                          function d:AddToRadioGroup(cT, cS)
                              local cU = self:RadioGroup(cS)
                              tinsert(cU, cT)
                              cT.radioGroup = cU
                              cT.radioGroupName = cS
                              for aL, aM in pairs(cY) do
                                  cT:HookScript(aL, aM)
                              end
                          end
                          d:RegisterModule(g, h)
                      end
                      local function c_(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Dropdown", 4
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local e = tinsert
                          local d0 = StdUiDropdowns or {}
                          StdUiDropdowns = d0
                          local d1 = function(self)
                              self.dropdown:SetValue(self.value, self:GetText())
                              self.dropdown.optsFrame:Hide()
                          end
                          local d2 = function(cP, d3)
                              cP.dropdown:ToggleValue(cP.value, d3)
                          end
                          local d4 = {buttonCreate = function(be)
                                  local d5 = be.dropdown
                                  local d6
                                  if d5.multi then
                                      d6 = d5.stdUi:Checkbox(be, "", be:GetWidth(), 20)
                                  else
                                      d6 = d5.stdUi:HighlightButton(be, be:GetWidth(), 20, "")
                                      d6.text:SetJustifyH("LEFT")
                                  end
                                  d6.dropdown = d5
                                  d6:SetFrameLevel(be:GetFrameLevel() + 2)
                                  if not d5.multi then
                                      d6:SetScript("OnClick", d1)
                                  else
                                      d6.OnValueChanged = d2
                                  end
                                  return d6
                              end, buttonUpdate = function(be, bq, bl)
                                  bq:SetWidth(be:GetWidth())
                                  bq:SetText(bl.text)
                                  if bq.dropdown.multi then
                                      bq:SetValue(bl.value)
                                  else
                                      bq.value = bl.value
                                  end
                              end, ShowOptions = function(self)
                                  for n = 1, #d0 do
                                      d0[n]:HideOptions()
                                  end
                                  self.optsFrame:UpdateSize(self:GetWidth(), self.optsFrame:GetHeight())
                                  self.optsFrame:Show()
                                  self.optsFrame:Update()
                                  self:RepaintOptions()
                              end, HideOptions = function(self)
                                  self.optsFrame:Hide()
                              end, ToggleOptions = function(self)
                                  if self.optsFrame:IsShown() then
                                      self:HideOptions()
                                  else
                                      self:ShowOptions()
                                  end
                              end, SetPlaceholder = function(self, cm)
                                  if self:GetText() == "" or self:GetText() == self.placeholder then
                                      self:SetText(cm)
                                  end
                                  self.placeholder = cm
                              end, RepaintOptions = function(self)
                                  local d7 = self.optsFrame.scrollChild
                                  self.stdUi:ObjectList(d7, d7.items, self.buttonCreate, self.buttonUpdate, self.options)
                                  self.optsFrame:UpdateItemsCount(#self.options)
                              end, SetOptions = function(self, d8)
                                  self.options = d8
                                  local d9 = #d8 * 20
                                  local d7 = self.optsFrame.scrollChild
                                  if not d7.items then
                                      d7.items = {}
                                  end
                                  self.optsFrame:SetHeight(math.min(d9 + 4, 200))
                                  d7:SetHeight(d9)
                                  self:RepaintOptions()
                              end, ToggleValue = function(self, ap, aT)
                                  assert(self.multi, "Single dropdown cannot have more than one value!")
                                  if self.assoc then
                                      self.value[ap] = aT
                                  else
                                      if aT then
                                          if not tContains(self.value, ap) then
                                              e(self.value, ap)
                                          end
                                      else
                                          if tContains(self.value, ap) then
                                              tDeleteItem(self.value, ap)
                                          end
                                      end
                                  end
                                  self:SetValue(self.value)
                              end, SetValue = function(self, ap, aj)
                                  self.value = ap
                                  if aj then
                                      self:SetText(aj)
                                  else
                                      self:SetText(self:FindValueText(ap))
                                  end
                                  if self.multi then
                                      for N, cP in pairs(self.optsFrame.scrollChild.items) do
                                          local d3 = false
                                          if self.assoc then
                                              d3 = self.value[cP.value]
                                          else
                                              d3 = tContains(self.value, cP.value)
                                          end
                                          cP:SetChecked(d3, true)
                                      end
                                  end
                                  if self.OnValueChanged then
                                      self.OnValueChanged(self, ap, self:GetText())
                                  end
                              end, GetValue = function(self)
                                  return self.value
                              end, FindValueText = function(self, ap)
                                  if type(ap) ~= "table" then
                                      for n = 1, #self.options do
                                          local da = self.options[n]
                                          if da.value == ap then
                                              return da.text
                                          end
                                      end
                                      return self.placeholder or ""
                                  else
                                      local m = ""
                                      for n = 1, #self.options do
                                          local da = self.options[n]
                                          if self.assoc then
                                              for aS, db in pairs(ap) do
                                                  if db and aS == da.value then
                                                      if m == "" then
                                                          m = da.text
                                                      else
                                                          m = m .. ", " .. da.text
                                                      end
                                                  end
                                              end
                                          else
                                              for a3 = 1, #ap do
                                                  if ap[a3] == da.value then
                                                      if m == "" then
                                                          m = da.text
                                                      else
                                                          m = m .. ", " .. da.text
                                                      end
                                                  end
                                              end
                                          end
                                      end
                                      if m ~= "" then
                                          return m
                                      else
                                          return self.placeholder or ""
                                      end
                                  end
                              end}
                          local dc = {OnClick = function(self)
                                  self:ToggleOptions()
                              end}
                          function d:Dropdown(be, q, r, dd, ap, de, df)
                              local d5 = self:Button(be, q, r, "")
                              d5.stdUi = self
                              d5.text:SetJustifyH("LEFT")
                              d5.text:ClearAllPoints()
                              self:GlueAcross(d5.text, d5, 2, -2, -16, 2)
                              local dg = self:Texture(d5, 15, 15, "Interface\\Buttons\\SquareButtonTextures")
                              dg:SetTexCoord(0.45312500, 0.64062500, 0.20312500, 0.01562500)
                              self:GlueRight(dg, d5, -2, 0, true)
                              local dh = self:FauxScrollFrame(d5, d5:GetWidth(), 200, 10, 20)
                              dh:Hide()
                              self:GlueBelow(dh, d5, 0, 1, "LEFT")
                              d5:SetFrameLevel(dh:GetFrameLevel() + 1)
                              d5.multi = de
                              d5.assoc = df
                              d5.optsFrame = dh
                              d5.dropTex = dg
                              d5.options = dd
                              dh.scrollChild.dropdown = d5
                              for aL, aM in pairs(d4) do
                                  d5[aL] = aM
                              end
                              if dd then
                                  d5:SetOptions(dd)
                              end
                              if ap then
                                  d5:SetValue(ap)
                              elseif de then
                                  d5.value = {}
                              end
                              for aL, aM in pairs(dc) do
                                  d5:SetScript(aL, aM)
                              end
                              e(d0, d5)
                              return d5
                          end
                          d:RegisterModule(g, h)
                      end
                      local function di(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Autocomplete", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local e = tinsert
                          d.Util.autocompleteTransformer = function(N, ap)
                              return ap
                          end
                          d.Util.autocompleteValidator = function(self)
                              self.stdUi:MarkAsValid(self, true)
                              return true
                          end
                          d.Util.autocompleteItemTransformer = function(N, ap)
                              if not ap or ap == "" then
                                  return ap
                              end
                              local dj = GetItemInfo(ap)
                              return dj
                          end
                          d.Util.autocompleteItemValidator = function(dk)
                              local dj, dl
                              local aQ = dk:GetText()
                              local aM = dk:GetValue()
                              if tonumber(aQ) ~= nil then
                                  dj = GetItemInfo(tonumber(aQ))
                                  if dj then
                                      dl = tonumber(aQ)
                                  end
                              elseif aM then
                                  dj = GetItemInfo(aM)
                                  if dj == aQ then
                                      dl = aM
                                  end
                              end
                              if dl then
                                  dk.value = dl
                                  dk:SetText(dj)
                                  self.stdUi:MarkAsValid(dk, true)
                                  return true
                              else
                                  self.stdUi:MarkAsValid(dk, false)
                                  return false
                              end
                          end
                          local dm = {
                              buttonCreate = function(dn)
                                  local d6
                                  d6 = d:HighlightButton(dn, dn:GetWidth(), 20, "")
                                  d6.text:SetJustifyH("LEFT")
                                  d6.autocomplete = dn.autocomplete
                                  d6:SetFrameLevel(dn:GetFrameLevel() + 2)
                                  d6:SetScript(
                                      "OnClick",
                                      function(aE)
                                          local dk = aE.autocomplete
                                          if aE.boundItem then
                                              aE.autocomplete.selectedItem = aE.boundItem
                                          end
                                          dk:SetValue(aE.value, aE:GetText())
                                          aE.autocomplete.dropdown:Hide()
                                      end
                                  )
                                  return d6
                              end,
                              buttonUpdate = function(dn, d6, bl)
                                  d6.boundItem = bl
                                  d6.value = bl.value
                                  d6:SetWidth(dn:GetWidth())
                                  d6:SetText(bl.text)
                              end,
                              filterItems = function(dk, dp, dq)
                                  local m = {}
                                  for N, dr in pairs(dq) do
                                      local ds = tostring(dr.value)
                                      if dr.text:lower():find(dp:lower(), nil, true) or ds:lower():find(dp:lower(), nil, true) then
                                          e(m, dr)
                                      end
                                      if #m >= dk.itemLimit then
                                          break
                                      end
                                  end
                                  return m
                              end,
                              SetItems = function(self, dt)
                                  self.items = dt
                                  self:RenderItems()
                                  self.dropdown:Hide()
                              end,
                              RenderItems = function(self)
                                  local du = 20 * #self.filteredItems
                                  self.dropdown:SetHeight(du)
                                  self.stdUi:ObjectList(
                                      self.dropdown,
                                      self.itemTable,
                                      self.buttonCreate,
                                      self.buttonUpdate,
                                      self.filteredItems
                                  )
                              end,
                              ValueToText = function(self, ap)
                                  return self.transformer(ap)
                              end,
                              SetValue = function(self, ap, aQ)
                                  self.value = ap
                                  self:SetText(aQ or self:ValueToText(ap) or "")
                                  self:Validate()
                                  self.button:Hide()
                              end,
                              Validate = function(self)
                                  self.isValidated = true
                                  self.isValid = self:validator()
                                  if self.isValid then
                                      if self.OnValueChanged then
                                          self:OnValueChanged(self.value, self:GetText())
                                      end
                                  end
                                  self.isValidated = false
                              end
                          }
                          local dv = {OnEditFocusLost = function(dw)
                                  dw.dropdown:Hide()
                              end, OnEnterPressed = function(dw)
                                  dw.dropdown:Hide()
                                  dw:Validate()
                              end, OnTextChanged = function(dk, cs)
                                  local dx = d.Util.stripColors(dk:GetText())
                                  dk.selectedItem = nil
                                  if cs then
                                      dk.value = nil
                                      if type(dk.items) == "function" then
                                          dk.filteredItems = dk:items(dx)
                                      elseif type(dk.items) == "table" then
                                          dk.filteredItems = dk:filterItems(dx, dk.items)
                                      end
                                      if not dk.filteredItems or #dk.filteredItems == 0 then
                                          dk.dropdown:Hide()
                                      else
                                          dk:RenderItems()
                                          dk.dropdown:Show()
                                      end
                                  end
                              end}
                          function d:Autocomplete(be, q, r, aj, ct, dy, dz)
                              dy = dy or d.Util.autocompleteTransformer
                              ct = ct or d.Util.autocompleteValidator
                              local dA = self:EditBox(be, q, r, aj, ct)
                              dA.stdUi = self
                              dA.transformer = dy
                              dA.items = dz
                              dA.filteredItems = {}
                              dA.selectedItem = nil
                              dA.itemLimit = 8
                              dA.itemTable = {}
                              dA.dropdown = self:Panel(be, q, 20)
                              dA.dropdown:SetPoint("TOPLEFT", dA, "BOTTOMLEFT", 0, 0)
                              dA.dropdown:SetPoint("TOPRIGHT", dA, "BOTTOMRIGHT", 0, 0)
                              dA.dropdown:Hide()
                              dA.dropdown:SetFrameLevel(dA:GetFrameLevel() + 10)
                              dA.dropdown.autocomplete = dA
                              for aL, aM in pairs(dm) do
                                  dA[aL] = aM
                              end
                              for aL, aM in pairs(dv) do
                                  dA:SetScript(aL, aM)
                              end
                              return dA
                          end
                          d:RegisterModule(g, h)
                      end
                      local function dB(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Label", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local dC = {SetFontSize = function(self, cg)
                                  self:SetFont(self:GetFont(), cg)
                              end}
                          function d:FontString(be, aj, cf)
                              local dD = be:CreateFontString(nil, self.config.font.strata, cf or "GameFontNormal")
                              dD:SetText(aj)
                              dD:SetJustifyH("LEFT")
                              dD:SetJustifyV("MIDDLE")
                              for aL, aM in pairs(dC) do
                                  dD[aL] = aM
                              end
                              return dD
                          end
                          function d:Label(be, aj, Q, cf, q, r)
                              local dD = self:FontString(be, aj, cf)
                              if Q then
                                  dD:SetFontSize(Q)
                              end
                              self:SetTextColor(dD, "normal")
                              self:SetObjSize(dD, q, r)
                              return dD
                          end
                          function d:Header(be, aj, Q, cf, q, r)
                              local dD = self:Label(be, aj, Q, cf or "GameFontNormalLarge", q, r)
                              self:SetTextColor(dD, "header")
                              return dD
                          end
                          function d:AddLabel(be, w, aj, dE, dF)
                              local dG = self.config.font.size + 4
                              local cd = self:Label(be, aj, self.config.font.size, nil, dF, dG)
                              if dE == "TOP" or dE == nil then
                                  self:GlueAbove(cd, w, 0, 4, "LEFT")
                              elseif dE == "RIGHT" then
                                  self:GlueRight(cd, w, 4, 0)
                              else
                                  cd:SetWidth(dF or cd:GetStringWidth())
                                  self:GlueLeft(cd, w, -4, 0)
                              end
                              w.label = cd
                              return cd
                          end
                          d:RegisterModule(g, h)
                      end
                      local function dH(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Scroll", 6
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local dI = function(dJ)
                              return math.floor(dJ + .5)
                          end
                          d.ScrollBarEvents = {UpDownButtonOnClick = function(self)
                                  local dK = self.scrollBar
                                  local cJ = dK.scrollFrame
                                  local dL = dK.scrollStep or cJ:GetHeight() / 2
                                  if self.direction == 1 then
                                      dK:SetValue(dK:GetValue() - dL)
                                  else
                                      dK:SetValue(dK:GetValue() + dL)
                                  end
                              end, OnValueChanged = function(self, ap)
                                  self.scrollFrame:SetVerticalScroll(ap)
                              end}
                          d.ScrollFrameEvents = {OnMouseWheel = function(self, ap, dK)
                                  dK = dK or self.scrollBar
                                  local dL = dK.scrollStep or dK:GetHeight() / 2
                                  if ap > 0 then
                                      dK:SetValue(dK:GetValue() - dL)
                                  else
                                      dK:SetValue(dK:GetValue() + dL)
                                  end
                              end, OnScrollRangeChanged = function(self, N, dM)
                                  local dN = self.scrollBar
                                  if not dM then
                                      dM = self:GetVerticalScrollRange()
                                  end
                                  dM = math.floor(dM)
                                  local ap = math.min(dN:GetValue(), dM)
                                  dN:SetMinMaxValues(0, dM)
                                  dN:SetValue(ap)
                                  local dO = dN.ScrollDownButton
                                  local dP = dN.ScrollUpButton
                                  local dQ = dN.ThumbTexture
                                  if dM == 0 then
                                      if self.scrollBarHideable then
                                          dN:Hide()
                                          dO:Hide()
                                          dP:Hide()
                                          dQ:Hide()
                                      else
                                          dO:Disable()
                                          dP:Disable()
                                          dO:Show()
                                          dP:Show()
                                          if not self.noScrollThumb then
                                              dQ:Show()
                                          end
                                      end
                                  else
                                      dO:Show()
                                      dP:Show()
                                      dN:Show()
                                      if not self.noScrollThumb then
                                          dQ:Show()
                                      end
                                      if dM - ap > 0.005 then
                                          dO:Enable()
                                      else
                                          dO:Disable()
                                      end
                                  end
                              end, OnVerticalScroll = function(self, cF)
                                  local dK = self.scrollBar
                                  dK:SetValue(cF)
                                  local N, cw = dK:GetMinMaxValues()
                                  dK.ScrollUpButton:SetEnabled(cF ~= 0)
                                  dK.ScrollDownButton:SetEnabled(dK:GetValue() - cw ~= 0)
                              end}
                          d.ScrollFrameMethods = {SetScrollStep = function(self, dL)
                                  dL = dI(dL)
                                  self.scrollBar.scrollStep = dL
                                  self.scrollBar:SetValueStep(dL)
                              end, GetChildFrames = function(self)
                                  return self.scrollBar, self.scrollChild, self.scrollBar.ScrollUpButton, self.scrollBar.ScrollDownButton
                              end, UpdateSize = function(self, dR, dS)
                                  self:SetSize(dR, dS)
                                  self.scrollFrame:ClearAllPoints()
                                  self.scrollFrame:SetSize(dR - self.scrollBarWidth - 5, dS - 4)
                                  self.stdUi:GlueAcross(self.scrollFrame, self, 2, -2, -self.scrollBarWidth - 2, 2)
                                  self.scrollBar.panel:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)
                                  self.scrollBar.panel:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 2)
                                  if self.scrollChild then
                                      self.scrollChild:SetWidth(self.scrollFrame:GetWidth())
                                      self.scrollChild:SetHeight(self.scrollFrame:GetHeight())
                                  end
                              end}
                          function d:ScrollFrame(be, q, r, d7)
                              local dn = self:Panel(be, q, r)
                              dn.stdUi = self
                              dn.offset = 0
                              dn.scrollBarWidth = 16
                              local cJ = CreateFrame("ScrollFrame", nil, dn)
                              local dK = self:ScrollBar(dn, dn.scrollBarWidth)
                              dK:SetMinMaxValues(0, 0)
                              dK:SetValue(0)
                              dK:SetScript("OnValueChanged", self.ScrollBarEvents.OnValueChanged)
                              dK.ScrollUpButton.direction = 1
                              dK.ScrollDownButton.direction = -1
                              dK.ScrollDownButton:SetScript("OnClick", self.ScrollBarEvents.UpDownButtonOnClick)
                              dK.ScrollUpButton:SetScript("OnClick", self.ScrollBarEvents.UpDownButtonOnClick)
                              dK.ScrollDownButton:Disable()
                              dK.ScrollUpButton:Disable()
                              if self.noScrollThumb then
                                  dK.ThumbTexture:Hide()
                              end
                              dK.scrollFrame = cJ
                              cJ.scrollBar = dK
                              cJ.panel = dn
                              dn.scrollBar = dK
                              dn.scrollFrame = cJ
                              for aL, aM in pairs(self.ScrollFrameMethods) do
                                  dn[aL] = aM
                              end
                              for aL, aM in pairs(self.ScrollFrameEvents) do
                                  cJ:SetScript(aL, aM)
                              end
                              if not d7 then
                                  d7 = CreateFrame("Frame", nil, cJ)
                                  d7:SetWidth(cJ:GetWidth())
                                  d7:SetHeight(cJ:GetHeight())
                              else
                                  d7:SetParent(cJ)
                              end
                              dn.scrollChild = d7
                              dn:UpdateSize(q, r)
                              cJ:SetScrollChild(d7)
                              cJ:EnableMouse(true)
                              cJ:SetClampedToScreen(true)
                              cJ:SetClipsChildren(true)
                              d7:SetPoint("RIGHT", cJ, "RIGHT", 0, 0)
                              cJ.scrollChild = d7
                              return dn
                          end
                          d.FauxScrollFrameMethods = {GetOffset = function(self)
                                  return self.offset or 0
                              end, DoVerticalScroll = function(self, ap, dT, dU)
                                  local dK = self.scrollBar
                                  dT = dT or self.lineHeight
                                  dK:SetValue(ap)
                                  self.offset = floor(ap / dT + 0.5)
                                  if dU then
                                      dU(self)
                                  end
                              end, Redraw = function(self)
                                  self:Update(self.itemCount or #self.scrollChild.items, self.displayCount, self.lineHeight)
                              end, UpdateItemsCount = function(self, dV)
                                  self.itemCount = dV
                                  self:Update(dV, self.displayCount, self.lineHeight)
                              end, Update = function(self, dW, dX, dY)
                                  local dK, dZ, dP, dO = self:GetChildFrames()
                                  local d_
                                  if dW == nil or dX == nil then
                                      return
                                  end
                                  if dW > dX then
                                      d_ = 1
                                  else
                                      dK:SetValue(0)
                                  end
                                  if self:IsShown() then
                                      local e0 = 0
                                      local e1 = 0
                                      if dW > 0 then
                                          e0 = (dW - dX) * dY
                                          e1 = dW * dY
                                          if e0 < 0 then
                                              e0 = 0
                                          end
                                          dZ:Show()
                                      else
                                          dZ:Hide()
                                      end
                                      local e2 = (dW - dX) * dY
                                      if e2 < 0 then
                                          e2 = 0
                                      end
                                      dK:SetMinMaxValues(0, e2)
                                      self:SetScrollStep(dY)
                                      dK:SetStepsPerPage(dX - 1)
                                      dZ:SetHeight(e1)
                                      if dK:GetValue() == 0 then
                                          dP:Disable()
                                      else
                                          dP:Enable()
                                      end
                                      if dK:GetValue() - e0 == 0 then
                                          dO:Disable()
                                      else
                                          dO:Enable()
                                      end
                                  end
                                  return d_
                              end}
                          local e3 = function(self)
                              self:Redraw()
                          end
                          d.FauxScrollFrameEvents = {OnVerticalScroll = function(self, ap)
                                  ap = dI(ap)
                                  local dn = self.panel
                                  dn:DoVerticalScroll(ap, dn.lineHeight, e3)
                              end}
                          function d:FauxScrollFrame(be, q, r, e4, e5, d7)
                              local dn = self:ScrollFrame(be, q, r, d7)
                              dn.lineHeight = e5
                              dn.displayCount = e4
                              for aL, aM in pairs(self.FauxScrollFrameMethods) do
                                  dn[aL] = aM
                              end
                              for aL, aM in pairs(self.FauxScrollFrameEvents) do
                                  dn.scrollFrame:SetScript(aL, aM)
                              end
                              return dn
                          end
                          d.HybridScrollFrameMethods = {
                              Update = function(self, bb)
                                  local e6 = floor(bb - self.scrollChild:GetHeight() + 0.5)
                                  if e6 > 0 and self.scrollBar then
                                      local N, e7 = self.scrollBar:GetMinMaxValues()
                                      if math.floor(self.scrollBar:GetValue()) >= math.floor(e7) then
                                          self.scrollBar:SetMinMaxValues(0, e6)
                                          if e6 < e7 then
                                              if math.floor(self.scrollBar:GetValue()) ~= math.floor(e6) then
                                                  self.scrollBar:SetValue(e6)
                                              else
                                                  self:SetOffset(self, e6)
                                              end
                                          end
                                      else
                                          self.scrollBar:SetMinMaxValues(0, e6)
                                      end
                                      self.scrollBar:Enable()
                                      self:UpdateScrollBarState()
                                      self.scrollBar:Show()
                                  elseif self.scrollBar then
                                      self.scrollBar:SetValue(0)
                                      if self.scrollBar.doNotHide then
                                          self.scrollBar:Disable()
                                          self.scrollBar.ScrollUpButton:Disable()
                                          self.scrollBar.ScrollDownButton:Disable()
                                          self.scrollBar.ThumbTexture:Hide()
                                      else
                                          self.scrollBar:Hide()
                                      end
                                  end
                                  self.range = e6
                                  self.totalHeight = bb
                                  self.scrollFrame:UpdateScrollChildRect()
                              end,
                              SetData = function(self, bl)
                                  self.data = bl
                              end,
                              SetUpdateFunction = function(self, e8)
                                  self.updateFn = e8
                              end,
                              UpdateScrollBarState = function(self, e9)
                                  if not e9 then
                                      e9 = self.scrollBar:GetValue()
                                  end
                                  self.scrollBar.ScrollUpButton:Enable()
                                  self.scrollBar.ScrollDownButton:Enable()
                                  local ea, e7 = self.scrollBar:GetMinMaxValues()
                                  if e9 >= e7 then
                                      self.scrollBar.ThumbTexture:Show()
                                      if self.scrollBar.ScrollDownButton then
                                          self.scrollBar.ScrollDownButton:Disable()
                                      end
                                  end
                                  if e9 <= ea then
                                      self.scrollBar.ThumbTexture:Show()
                                      if self.scrollBar.ScrollUpButton then
                                          self.scrollBar.ScrollUpButton:Disable()
                                      end
                                  end
                              end,
                              GetOffset = function(self)
                                  return math.floor(self.offset or 0), self.offset or 0
                              end,
                              SetOffset = function(self, cF)
                                  local dz = self.items
                                  local dT = self.itemHeight
                                  local bG, eb
                                  local ec = 0
                                  if self.dynamic then
                                      if cF < dT then
                                          bG, ec = 0, cF
                                      else
                                          bG, ec = self.dynamic(cF)
                                      end
                                  else
                                      bG = cF / dT
                                      eb = bG - math.floor(bG)
                                      ec = eb * dT
                                  end
                                  if math.floor(self.offset or 0) ~= math.floor(bG) and self.updateFn then
                                      self.offset = bG
                                      self:UpdateItems()
                                  else
                                      self.offset = bG
                                  end
                                  self.scrollFrame:SetVerticalScroll(ec)
                              end,
                              CreateItems = function(self, bl, bj, bk, bm, bn, bo)
                                  local d7 = self.scrollChild
                                  local dT = 0
                                  local dW = #bl
                                  if not self.items then
                                      self.items = {}
                                  end
                                  self.data = bl
                                  self.createFn = bj
                                  self.updateFn = bk
                                  self.itemPadding = bm
                                  self.stdUi:ObjectList(
                                      d7,
                                      self.items,
                                      bj,
                                      bk,
                                      bl,
                                      bm,
                                      bn,
                                      bo,
                                      function(n, bb, ed)
                                          return bb > self:GetHeight() + ed
                                      end
                                  )
                                  if self.items[1] then
                                      dT = dI(self.items[1]:GetHeight() + bm)
                                  end
                                  self.itemHeight = dT
                                  local bb = dW * dT
                                  self.scrollFrame:SetVerticalScroll(0)
                                  local dK = self.scrollBar
                                  dK:SetMinMaxValues(0, bb)
                                  dK.itemHeight = dT
                                  self:SetScrollStep(dT / 2)
                                  dK:SetStepsPerPage(dW - 2)
                                  dK:SetValue(0)
                                  self:Update(bb)
                              end,
                              UpdateItems = function(self)
                                  local ee = #self.data
                                  local cF = self:GetOffset()
                                  local dz = self:GetItems()
                                  for n = 1, #dz do
                                      local dr = dz[n]
                                      local ef = cF + n
                                      if ef <= ee then
                                          self.updateFn(self.scrollChild, dr, self.data[ef], ef, n)
                                      end
                                  end
                                  local eg = dz[1]
                                  local bb = 0
                                  if eg then
                                      bb = ee * (eg:GetHeight() + self.itemPadding)
                                  end
                                  self:Update(bb, self:GetHeight())
                              end,
                              GetItems = function(self)
                                  return self.items
                              end,
                              SetDoNotHideScrollBar = function(self, eh)
                                  if not self.scrollBar or self.scrollBar.doNotHide == eh then
                                      return
                                  end
                                  self.scrollBar.doNotHide = eh
                                  self:Update(self.totalHeight or 0, self.scrollChild:GetHeight())
                              end,
                              ScrollToIndex = function(self, ef, ei)
                                  local bb = 0
                                  local e0 = self:GetHeight()
                                  for n = 1, ef do
                                      local ej = ei(n)
                                      if n == ef then
                                          local cF = 0
                                          if bb + ej > e0 then
                                              if ej > e0 then
                                                  cF = bb
                                              else
                                                  local ek = e0 - ej
                                                  cF = bb - ek / 2
                                              end
                                              local el = self.scrollBar:GetValueStep()
                                              cF = cF + el - mod(cF, el)
                                              if cF > bb then
                                                  cF = cF - el
                                              end
                                          end
                                          self.scrollBar:SetValue(cF)
                                          break
                                      end
                                      bb = bb + ej
                                  end
                              end
                          }
                          local em = function(self, ap)
                              local k = self.scrollFrame.panel
                              ap = dI(ap)
                              k:SetOffset(ap)
                              k:UpdateScrollBarState(ap)
                          end
                          function d:HybridScrollFrame(be, q, r, d7)
                              local dn = self:ScrollFrame(be, q, r, d7)
                              dn.scrollBar:SetScript("OnValueChanged", em)
                              dn.scrollFrame:SetScript("OnScrollRangeChanged", nil)
                              dn.scrollFrame:SetScript("OnVerticalScroll", nil)
                              for aL, aM in pairs(self.HybridScrollFrameMethods) do
                                  dn[aL] = aM
                              end
                              return dn
                          end
                          d:RegisterModule(g, h)
                      end
                      local function en(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "ScrollTable", 6
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local e = tinsert
                          local ah = table.sort
                          local bm = 2.5
                          local eo = {
                              SetAutoHeight = function(self)
                                  self:SetHeight(self.numberOfRows * self.rowHeight + 10)
                                  self:Refresh()
                              end,
                              SetAutoWidth = function(self)
                                  local q = 13
                                  for N, b7 in pairs(self.columns) do
                                      q = q + b7.width
                                  end
                                  self:SetWidth(q + 20)
                                  self:Refresh()
                              end,
                              ScrollToLine = function(self, ep)
                                  ep = Clamp(ep, 1, #self.filtered - self.numberOfRows + 1)
                                  self:DoVerticalScroll(
                                      self.rowHeight * (ep - 1),
                                      self.rowHeight,
                                      function(dw)
                                          dw:Refresh()
                                      end
                                  )
                              end,
                              SetColumns = function(self, eq)
                                  local table = self
                                  self.columns = eq
                                  local er = self.head
                                  if not er then
                                      er = CreateFrame("Frame", nil, self)
                                      er:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 4, 0)
                                      er:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -4, 0)
                                      er:SetHeight(self.rowHeight)
                                      er.columns = {}
                                      self.head = er
                                  end
                                  for n = 1, #eq do
                                      local es = self.columns[n]
                                      local et = er.columns[n]
                                      if not er.columns[n] then
                                          et = self.stdUi:HighlightButton(er)
                                          et:SetPushedTextOffset(0, 0)
                                          et.arrow = self.stdUi:Texture(et, 8, 8, "Interface\\Buttons\\UI-SortArrow")
                                          et.arrow:Hide()
                                          if self.headerEvents then
                                              for eu, ev in pairs(self.headerEvents) do
                                                  et:SetScript(
                                                      eu,
                                                      function(ew, ...)
                                                          table:FireHeaderEvent(eu, ev, et, er, n, ...)
                                                      end
                                                  )
                                              end
                                          end
                                          er.columns[n] = et
                                          es.head = et
                                          es.cells = {}
                                      end
                                      local a5 = eq[n].align or "LEFT"
                                      et.text:SetJustifyH(a5)
                                      et.text:SetText(eq[n].name)
                                      if a5 == "LEFT" then
                                          et.arrow:ClearAllPoints()
                                          self.stdUi:GlueRight(et.arrow, et, 0, 0, true)
                                      else
                                          et.arrow:ClearAllPoints()
                                          self.stdUi:GlueLeft(et.arrow, et, 5, 0, true)
                                      end
                                      if eq[n].sortable == false and eq[n].sortable ~= nil then
                                      else
                                      end
                                      if n > 1 then
                                          et:SetPoint("LEFT", er.columns[n - 1], "RIGHT", 0, 0)
                                      else
                                          et:SetPoint("LEFT", er, "LEFT", 2, 0)
                                      end
                                      et:SetHeight(self.rowHeight)
                                      et:SetWidth(eq[n].width)
                                      function es:SetWidth(q)
                                          es.width = q
                                          es.head:SetWidth(q)
                                          for ex = 1, #es.cells do
                                              es.cells[ex]:SetWidth(q)
                                          end
                                      end
                                  end
                                  self:SetDisplayRows(self.numberOfRows, self.rowHeight)
                                  self:SetAutoWidth()
                              end,
                              SetDisplayRows = function(self, ey, ez)
                                  local table = self
                                  self.numberOfRows = ey
                                  self.rowHeight = ez
                                  if not self.rows then
                                      self.rows = {}
                                  end
                                  for n = 1, ey do
                                      local eA = self.rows[n]
                                      if not eA then
                                          eA = CreateFrame("Button", nil, self)
                                          self.rows[n] = eA
                                          if n > 1 then
                                              eA:SetPoint("TOPLEFT", self.rows[n - 1], "BOTTOMLEFT", 0, 0)
                                              eA:SetPoint("TOPRIGHT", self.rows[n - 1], "BOTTOMRIGHT", 0, 0)
                                          else
                                              eA:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 1, -1)
                                              eA:SetPoint("TOPRIGHT", self.scrollFrame, "TOPRIGHT", -1, -1)
                                          end
                                          eA:SetHeight(ez)
                                      end
                                      if not eA.columns then
                                          eA.columns = {}
                                      end
                                      for ex = 1, #self.columns do
                                          local eB = self.columns[ex]
                                          local eC = eA.columns[ex]
                                          if not eC then
                                              eC = CreateFrame("Button", nil, eA)
                                              eC.text = self.stdUi:FontString(eC, "")
                                              eA.columns[ex] = eC
                                              self.columns[ex].cells[n] = eC
                                              local a5 = eB.align or "LEFT"
                                              eC.text:SetJustifyH(a5)
                                              eC:EnableMouse(true)
                                              eC:RegisterForClicks("AnyUp")
                                              if self.cellEvents then
                                                  for eu, ev in pairs(self.cellEvents) do
                                                      eC:SetScript(
                                                          eu,
                                                          function(ew, ...)
                                                              if table.offset then
                                                                  local eD = table.filtered[n + table.offset]
                                                                  local eE = table:GetRow(eD)
                                                                  table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                              end
                                                          end
                                                      )
                                                  end
                                              end
                                              if eB.events then
                                                  for eu, ev in pairs(eB.events) do
                                                      eC:SetScript(
                                                          eu,
                                                          function(ew, ...)
                                                              if table.offset then
                                                                  local eD = table.filtered[n + table.offset]
                                                                  local eE = table:GetRow(eD)
                                                                  table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                              end
                                                          end
                                                      )
                                                  end
                                              end
                                          end
                                          if ex > 1 then
                                              eC:SetPoint("LEFT", eA.columns[ex - 1], "RIGHT", 0, 0)
                                          else
                                              eC:SetPoint("LEFT", eA, "LEFT", 2, 0)
                                          end
                                          eC:SetHeight(ez)
                                          eC:SetWidth(self.columns[ex].width)
                                          eC.text:SetPoint("TOP", eC, "TOP", 0, 0)
                                          eC.text:SetPoint("BOTTOM", eC, "BOTTOM", 0, 0)
                                          eC.text:SetWidth(self.columns[ex].width - 2 * bm)
                                      end
                                      local ex = #self.columns + 1
                                      local b7 = eA.columns[ex]
                                      while b7 do
                                          b7:Hide()
                                          ex = ex + 1
                                          b7 = eA.columns[ex]
                                      end
                                  end
                                  for n = ey + 1, #self.rows do
                                      self.rows[n]:Hide()
                                  end
                                  self:SetAutoHeight()
                              end,
                              SetColumnWidth = function(self, eF, q)
                                  self.columns[eF]:SetWidth(q)
                              end,
                              SortData = function(self, eG)
                                  if not self.sortTable or #self.sortTable ~= #self.data then
                                      self.sortTable = {}
                                  end
                                  if #self.sortTable ~= #self.data then
                                      for n = 1, #self.data do
                                          self.sortTable[n] = n
                                      end
                                  end
                                  if not eG then
                                      local n = 1
                                      while n <= #self.columns and not eG do
                                          if self.columns[n].sort then
                                              eG = n
                                          end
                                          n = n + 1
                                      end
                                  end
                                  if eG then
                                      ah(
                                          self.sortTable,
                                          function(eH, eI)
                                              local es = self.columns[eG]
                                              if es.compareSort then
                                                  return es.compareSort(self, eH, eI, eG)
                                              else
                                                  return self:CompareSort(eH, eI, eG)
                                              end
                                          end
                                      )
                                  end
                                  self.filtered = self:DoFilter()
                                  self:Refresh()
                                  self:UpdateSortArrows(eG)
                              end,
                              CompareSort = function(self, eH, eI, eG)
                                  local aF = self:GetRow(eH)
                                  local aE = self:GetRow(eI)
                                  local es = self.columns[eG]
                                  local eJ = es.index
                                  local G = es.sort or es.defaultSort or "asc"
                                  if G:lower() == "asc" then
                                      return aF[eJ] > aE[eJ]
                                  else
                                      return aF[eJ] < aE[eJ]
                                  end
                              end,
                              Filter = function(self, eE)
                                  return true
                              end,
                              SetFilter = function(self, eK, eL)
                                  self.Filter = eK
                                  if not eL then
                                      self:SortData()
                                  end
                              end,
                              DoFilter = function(self)
                                  local m = {}
                                  for bf = 1, #self.data do
                                      local eM = self.sortTable[bf]
                                      local eE = self:GetRow(eM)
                                      if self:Filter(eE) then
                                          e(m, eM)
                                      end
                                  end
                                  return m
                              end,
                              SetHighLightColor = function(self, x, eN)
                                  if not x.highlight then
                                      x.highlight = x:CreateTexture(nil, "OVERLAY")
                                      x.highlight:SetAllPoints(x)
                                  end
                                  if not eN then
                                      x.highlight:SetColorTexture(0, 0, 0, 0)
                                  else
                                      x.highlight:SetColorTexture(eN.r, eN.g, eN.b, eN.a)
                                  end
                              end,
                              ClearHighlightedRows = function(self)
                                  self.highlightedRows = {}
                                  self:Refresh()
                              end,
                              HighlightRows = function(self, eO)
                                  self.highlightedRows = eO
                                  self:Refresh()
                              end,
                              EnableSelection = function(self, cM)
                                  self.selectionEnabled = cM
                              end,
                              ClearSelection = function(self)
                                  self:SetSelection(nil)
                              end,
                              SetSelection = function(self, eD)
                                  self.selected = eD
                                  self:Refresh()
                              end,
                              GetSelection = function(self)
                                  return self.selected
                              end,
                              GetSelectedItem = function(self)
                                  return self:GetRow(self.selected)
                              end,
                              SetData = function(self, bl)
                                  self.data = bl
                                  self:SortData()
                              end,
                              GetRow = function(self, eD)
                                  return self.data[eD]
                              end,
                              GetCell = function(self, bf, b7)
                                  local eE = bf
                                  if type(bf) == "number" then
                                      eE = self:GetRow(bf)
                                  end
                                  return eE[b7]
                              end,
                              IsRowVisible = function(self, eD)
                                  return eD > self.offset and eD <= self.numberOfRows + self.offset
                              end,
                              DoCellUpdate = function(table, eP, eA, ew, ap, eB, eE, eD)
                                  if eP then
                                      local format = eB.format
                                      if type(format) == "function" then
                                          ew.text:SetText(format(ap, eE, eB))
                                      elseif format == "money" then
                                          ap = table.stdUi.Util.formatMoney(ap)
                                          ew.text:SetText(ap)
                                      elseif format == "moneyShort" then
                                          ap = table.stdUi.Util.formatMoney(ap, true)
                                          ew.text:SetText(ap)
                                      elseif format == "number" then
                                          ap = tostring(ap)
                                          ew.text:SetText(ap)
                                      elseif format == "icon" then
                                          if ew.texture then
                                              ew.texture:SetTexture(ap)
                                          else
                                              local cQ = eB.iconSize or table.rowHeight
                                              ew.texture = table.stdUi:Texture(ew, cQ, cQ, ap)
                                              ew.texture:SetPoint("CENTER", 0, 0)
                                          end
                                      elseif format == "custom" then
                                          eB.renderer(ew, ap, eE, eB)
                                      else
                                          ew.text:SetText(ap)
                                      end
                                      local eN
                                      if eE.color then
                                          eN = eE.color
                                      elseif eB.color then
                                          eN = eB.color
                                      end
                                      if type(eN) == "function" then
                                          eN = eN(table, ap, eE, eB)
                                      end
                                      if eN then
                                          ew.text:SetTextColor(eN.r, eN.g, eN.b, eN.a)
                                      else
                                          table.stdUi:SetTextColor(ew.text, "normal")
                                      end
                                      if table.selectionEnabled then
                                          if table.selected == eD then
                                              table:SetHighLightColor(eA, table.stdUi.config.highlight.color)
                                          else
                                              table:SetHighLightColor(eA, nil)
                                          end
                                      else
                                          if tContains(table.highlightedRows, eD) then
                                              table:SetHighLightColor(eA, table.stdUi.config.highlight.color)
                                          else
                                              table:SetHighLightColor(eA, nil)
                                          end
                                      end
                                  else
                                      ew.text:SetText("")
                                  end
                              end,
                              Refresh = function(self)
                                  self:Update(#self.filtered, self.numberOfRows, self.rowHeight)
                                  local eQ = self:GetOffset()
                                  self.offset = eQ
                                  for n = 1, self.numberOfRows do
                                      local bf = n + eQ
                                      if self.rows then
                                          local eA = self.rows[n]
                                          local eD = self.filtered[bf]
                                          local eE = self:GetRow(eD)
                                          local eP = true
                                          for b7 = 1, #self.columns do
                                              local ew = eA.columns[b7]
                                              local eB = self.columns[b7]
                                              local eR = self.DoCellUpdate
                                              local ap
                                              if eE then
                                                  ap = eE[eB.index]
                                                  self.rows[n]:Show()
                                                  if eE.doCellUpdate then
                                                      eR = eE.doCellUpdate
                                                  elseif eB.doCellUpdate then
                                                      eR = eB.doCellUpdate
                                                  end
                                              else
                                                  self.rows[n]:Hide()
                                                  eP = false
                                              end
                                              eR(self, eP, eA, ew, ap, eB, eE, eD)
                                          end
                                      end
                                  end
                              end,
                              UpdateSortArrows = function(self, eG)
                                  if not self.head then
                                      return
                                  end
                                  for n = 1, #self.columns do
                                      local b7 = self.head.columns[n]
                                      if b7 then
                                          if n == eG then
                                              local es = self.columns[eG]
                                              local G = es.sort or es.defaultSort or "asc"
                                              if G == "asc" then
                                                  b7.arrow:SetTexCoord(0, 0.5625, 0, 1)
                                              else
                                                  b7.arrow:SetTexCoord(0, 0.5625, 1, 0)
                                              end
                                              b7.arrow:Show()
                                          else
                                              b7.arrow:Hide()
                                          end
                                      end
                                  end
                              end,
                              FireCellEvent = function(self, eu, ev, ...)
                                  if not ev(self, ...) then
                                      if self.cellEvents[eu] then
                                          self.cellEvents[eu](self, ...)
                                      end
                                  end
                              end,
                              FireHeaderEvent = function(self, eu, ev, ...)
                                  if not ev(self, ...) then
                                      if self.headerEvents[eu] then
                                          self.headerEvents[eu](self, ...)
                                      end
                                  end
                              end,
                              RegisterEvents = function(self, eS, eT, eU)
                                  local table = self
                                  if eS then
                                      for n, eA in ipairs(self.rows) do
                                          for ex, eC in ipairs(eA.columns) do
                                              local eB = self.columns[ex]
                                              if eU and self.cellEvents then
                                                  for eu, ev in pairs(self.cellEvents) do
                                                      eC:SetScript(eu, nil)
                                                  end
                                              end
                                              for eu, ev in pairs(eS) do
                                                  eC:SetScript(
                                                      eu,
                                                      function(ew, ...)
                                                          local eD = table.filtered[n + table.offset]
                                                          local eE = table:GetRow(eD)
                                                          table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                      end
                                                  )
                                              end
                                              if eB.events then
                                                  for eu, ev in pairs(self.columns[ex].events) do
                                                      eC:SetScript(
                                                          eu,
                                                          function(ew, ...)
                                                              if table.offset then
                                                                  local eD = table.filtered[n + table.offset]
                                                                  local eE = table:GetRow(eD)
                                                                  table:FireCellEvent(eu, ev, ew, eA, eE, eB, eD, ...)
                                                              end
                                                          end
                                                      )
                                                  end
                                              end
                                          end
                                      end
                                  end
                                  if eT then
                                      for eV, et in ipairs(self.head.columns) do
                                          if eU and self.headerEvents then
                                              for eu, N in pairs(self.headerEvents) do
                                                  et:SetScript(eu, nil)
                                              end
                                          end
                                          for eu, ev in pairs(eT) do
                                              et:SetScript(
                                                  eu,
                                                  function(ew, ...)
                                                      table:FireHeaderEvent(eu, ev, et, self.head, eV, ...)
                                                  end
                                              )
                                          end
                                      end
                                  end
                              end
                          }
                          local eS = {OnEnter = function(table, ew, eA, eE, eB, eD)
                                  table:SetHighLightColor(eA, table.stdUi.config.highlight.color)
                                  return true
                              end, OnLeave = function(table, ew, eA, eE, eB, eD)
                                  if eD ~= table.selected or not table.selectionEnabled then
                                      table:SetHighLightColor(eA, nil)
                                  end
                                  return true
                              end, OnClick = function(table, ew, eA, eE, eB, eD, J)
                                  if J == "LeftButton" then
                                      if table:GetSelection() == eD then
                                          table:ClearSelection()
                                      else
                                          table:SetSelection(eD)
                                      end
                                      return true
                                  end
                              end}
                          local eT = {OnClick = function(table, et, er, eV, J, ...)
                                  if J == "LeftButton" then
                                      local eq = table.columns
                                      local es = eq[eV]
                                      for n, N in ipairs(er.columns) do
                                          if n ~= eV then
                                              eq[n].sort = nil
                                          end
                                      end
                                      local eW = "asc"
                                      if not es.sort and es.defaultSort then
                                          eW = es.defaultSort
                                      elseif es.sort and es.sort:lower() == "asc" then
                                          eW = "dsc"
                                      end
                                      es.sort = eW
                                      table:SortData()
                                      return true
                                  end
                              end}
                          local eX = function(self)
                              self:Refresh()
                          end
                          local eY = function(self, cF)
                              local eZ = self.panel
                              eZ:DoVerticalScroll(cF, eZ.rowHeight, eX)
                          end
                          function d:ScrollTable(be, eq, e_, ez)
                              local eZ = self:FauxScrollFrame(be, 100, 100, ez or 15)
                              local cJ = eZ.scrollFrame
                              eZ.stdUi = self
                              eZ.numberOfRows = e_ or 12
                              eZ.rowHeight = ez or 15
                              eZ.columns = eq
                              eZ.data = {}
                              eZ.cellEvents = eS
                              eZ.headerEvents = eT
                              eZ.highlightedRows = {}
                              for f0, f1 in pairs(eo) do
                                  eZ[f0] = f1
                              end
                              cJ:SetScript("OnVerticalScroll", eY)
                              eZ:SortData()
                              eZ:SetColumns(eZ.columns)
                              eZ:UpdateSortArrows()
                              eZ:RegisterEvents(eZ.cellEvents, eZ.headerEvents)
                              return eZ
                          end
                          d:RegisterModule(g, h)
                      end
                      local function f2(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Slider", 7
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          function d:SliderButton(be, q, r, G)
                              local J = self:Button(be, q, r)
                              local bQ = self:ArrowTexture(J, G)
                              bQ:SetPoint("CENTER")
                              local f3 = self:ArrowTexture(J, G)
                              f3:SetPoint("CENTER")
                              f3:SetDesaturated(0)
                              J:SetNormalTexture(bQ)
                              J:SetDisabledTexture(f3)
                              return J
                          end
                          function d:StyleScrollBar(dK)
                              local f4, f5 = dK:GetChildren()
                              dK.background = d:Panel(dK)
                              dK.background:SetFrameLevel(dK:GetFrameLevel() - 1)
                              dK.background:SetWidth(dK:GetWidth())
                              self:GlueAcross(dK.background, dK, 0, 1, 0, -1)
                              self:StripTextures(f4)
                              self:StripTextures(f5)
                              self:ApplyBackdrop(f4, "button")
                              self:ApplyBackdrop(f5, "button")
                              f4:SetWidth(dK:GetWidth())
                              f5:SetWidth(dK:GetWidth())
                              local f6 = self:ArrowTexture(f4, "UP")
                              f6:SetPoint("CENTER")
                              local f7 = self:ArrowTexture(f4, "UP")
                              f7:SetPoint("CENTER")
                              f7:SetDesaturated(0)
                              f4:SetNormalTexture(f6)
                              f4:SetDisabledTexture(f7)
                              local f8 = self:ArrowTexture(f5, "DOWN")
                              f8:SetPoint("CENTER")
                              local f9 = self:ArrowTexture(f5, "DOWN")
                              f9:SetPoint("CENTER")
                              f9:SetDesaturated(0)
                              f5:SetNormalTexture(f8)
                              f5:SetDisabledTexture(f9)
                              local fa = dK:GetWidth()
                              dK:GetThumbTexture():SetWidth(fa)
                              self:StripTextures(dK)
                              dK.thumb = self:Panel(dK)
                              dK.thumb:SetAllPoints(dK:GetThumbTexture())
                              self:ApplyBackdrop(dK.thumb, "button")
                          end
                          local fb = {SetPrecision = function(self, fc)
                                  self.precision = fc
                              end, GetPrecision = function(self)
                                  return self.precision
                              end, GetValue = function(self)
                                  local fd, fe = self:GetMinMaxValues()
                                  return Clamp(d.Util.roundPrecision(self:OriginalGetValue(), self.precision), fd, fe)
                              end}
                          local ff = {OnValueChanged = function(self, ap, ...)
                                  if self.lock then
                                      return
                                  end
                                  self.lock = true
                                  ap = self:GetValue()
                                  if self.OnValueChanged then
                                      self:OnValueChanged(ap, ...)
                                  end
                                  self.lock = false
                              end}
                          function d:Slider(be, q, r, ap, fg, cv, cw)
                              local fh = CreateFrame("Slider", nil, be)
                              self:InitWidget(fh)
                              self:ApplyBackdrop(fh, "panel")
                              self:SetObjSize(fh, q, r)
                              fh.vertical = fg
                              fh.precision = 1
                              local fi = fg and q or 20
                              local fj = fg and 20 or r
                              fh.ThumbTexture = self:Texture(fh, fi, fj, self.config.backdrop.texture)
                              fh.ThumbTexture:SetVertexColor(
                                  self.config.backdrop.slider.r,
                                  self.config.backdrop.slider.g,
                                  self.config.backdrop.slider.b,
                                  self.config.backdrop.slider.a
                              )
                              fh:SetThumbTexture(fh.ThumbTexture)
                              fh.thumb = self:Frame(fh)
                              fh.thumb:SetAllPoints(fh:GetThumbTexture())
                              self:ApplyBackdrop(fh.thumb, "button")
                              if fg then
                                  fh:SetOrientation("VERTICAL")
                                  fh.ThumbTexture:SetPoint("LEFT")
                                  fh.ThumbTexture:SetPoint("RIGHT")
                              else
                                  fh:SetOrientation("HORIZONTAL")
                                  fh.ThumbTexture:SetPoint("TOP")
                                  fh.ThumbTexture:SetPoint("BOTTOM")
                              end
                              fh.OriginalGetValue = fh.GetValue
                              for aL, aM in pairs(fb) do
                                  fh[aL] = aM
                              end
                              fh:SetMinMaxValues(cv or 0, cw or 100)
                              fh:SetValue(ap or cv or 0)
                              for aL, aM in pairs(ff) do
                                  fh:HookScript(aL, aM)
                              end
                              return fh
                          end
                          local fk = {SetValue = function(self, aM)
                                  self.lock = true
                                  self.slider:SetValue(aM)
                                  aM = self.slider:GetValue()
                                  self.editBox:SetValue(aM)
                                  self.value = aM
                                  self.lock = false
                                  if self.OnValueChanged then
                                      self.OnValueChanged(self, aM)
                                  end
                              end, GetValue = function(self)
                                  return self.value
                              end, SetValueStep = function(self, fl)
                                  self.slider:SetValueStep(fl)
                              end, SetPrecision = function(self, fc)
                                  self.slider.precision = fc
                              end, GetPrecision = function(self)
                                  return self.slider.precision
                              end, SetMinMaxValues = function(self, cv, cw)
                                  self.min = cv
                                  self.max = cw
                                  self.editBox:SetMinMaxValue(cv, cw)
                                  self.slider:SetMinMaxValues(cv, cw)
                                  self.leftLabel:SetText(cv)
                                  self.rightLabel:SetText(cw)
                              end}
                          local fm = function(self, fn)
                              if self.widget.lock then
                                  return
                              end
                              self.widget:SetValue(fn)
                          end
                          function d:SliderWithBox(be, q, r, ap, cv, cw)
                              local k = CreateFrame("Frame", nil, be)
                              self:SetObjSize(k, q, r)
                              k.slider = self:Slider(k, 100, 12, ap, false)
                              k.editBox = self:NumericBox(k, 80, 16, ap)
                              k.value = ap
                              k.editBox:SetNumeric(false)
                              k.leftLabel = self:Label(k, "")
                              k.rightLabel = self:Label(k, "")
                              k.slider.widget = k
                              k.editBox.widget = k
                              for aL, aM in pairs(fk) do
                                  k[aL] = aM
                              end
                              if cv and cw then
                                  k:SetMinMaxValues(cv, cw)
                              end
                              k.slider.OnValueChanged = fm
                              k.editBox.OnValueChanged = fm
                              k.slider:SetPoint("TOPLEFT", k, "TOPLEFT", 0, 0)
                              k.slider:SetPoint("TOPRIGHT", k, "TOPRIGHT", 0, 0)
                              self:GlueBelow(k.editBox, k.slider, 0, -5, "CENTER")
                              k.leftLabel:SetPoint("TOPLEFT", k.slider, "BOTTOMLEFT", 0, 0)
                              k.rightLabel:SetPoint("TOPRIGHT", k.slider, "BOTTOMRIGHT", 0, 0)
                              return k
                          end
                          function d:ScrollBar(be, q, r, fo)
                              local dn = self:Panel(be, q, r)
                              local dK = self:Slider(be, q, r, 0, not fo)
                              dK.ScrollDownButton = self:SliderButton(be, q, 16, "DOWN")
                              dK.ScrollUpButton = self:SliderButton(be, q, 16, "UP")
                              dK.panel = dn
                              dK.ScrollUpButton.scrollBar = dK
                              dK.ScrollDownButton.scrollBar = dK
                              if fo then
                              else
                                  dK.ScrollUpButton:SetPoint("TOPLEFT", dn, "TOPLEFT", 0, 0)
                                  dK.ScrollUpButton:SetPoint("TOPRIGHT", dn, "TOPRIGHT", 0, 0)
                                  dK.ScrollDownButton:SetPoint("BOTTOMLEFT", dn, "BOTTOMLEFT", 0, 0)
                                  dK.ScrollDownButton:SetPoint("BOTTOMRIGHT", dn, "BOTTOMRIGHT", 0, 0)
                                  dK:SetPoint("TOPLEFT", dK.ScrollUpButton, "BOTTOMLEFT", 0, 1)
                                  dK:SetPoint("TOPRIGHT", dK.ScrollUpButton, "BOTTOMRIGHT", 0, 1)
                                  dK:SetPoint("BOTTOMLEFT", dK.ScrollDownButton, "TOPLEFT", 0, -1)
                                  dK:SetPoint("BOTTOMRIGHT", dK.ScrollDownButton, "TOPRIGHT", 0, -1)
                              end
                              return dK, dn
                          end
                          d:RegisterModule(g, h)
                      end
                      local function fp(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Tooltip", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          d.tooltips = {}
                          d.frameTooltips = {}
                          local fq = {
                              OnEnter = function(self)
                                  local fr = self.stdUiTooltip
                                  fr:SetOwner(fr.owner or UIParent, fr.anchor or "ANCHOR_NONE")
                                  if type(fr.text) == "string" then
                                      fr:SetText(
                                          fr.text,
                                          fr.stdUi.config.font.color.r,
                                          fr.stdUi.config.font.color.g,
                                          fr.stdUi.config.font.color.b,
                                          fr.stdUi.config.font.color.a
                                      )
                                  elseif type(fr.text) == "function" then
                                      fr.text(fr)
                                  end
                                  fr:Show()
                                  fr:ClearAllPoints()
                                  fr.stdUi:GlueOpposite(fr, fr.owner, 0, 0, fr.anchor)
                              end,
                              OnLeave = function(self)
                                  local fr = self.stdUiTooltip
                                  fr:Hide()
                              end
                          }
                          function d:Tooltip(fs, aj, ft, I, fu)
                              local fr
                              if ft and self.tooltips[ft] then
                                  fr = self.tooltips[ft]
                              else
                                  fr = CreateFrame("GameTooltip", ft, UIParent, "GameTooltipTemplate")
                                  self:ApplyBackdrop(fr, "panel")
                              end
                              fr.owner = fs
                              fr.anchor = I
                              fr.text = aj
                              fr.stdUi = self
                              fs.stdUiTooltip = fr
                              if fu then
                                  for aL, aM in pairs(fq) do
                                      fs:HookScript(aL, aM)
                                  end
                              end
                              return fr
                          end
                          local fv = {SetText = function(self, aj, aC, aD, aE)
                                  if aC and aD and aE then
                                      aj = self.stdUi.Util.WrapTextInColor(aj, aC, aD, aE, 1)
                                  end
                                  self.text:SetText(aj)
                                  self:RecalculateSize()
                              end, GetText = function(self)
                                  return self.text:GetText()
                              end, AddLine = function(self, aj, aC, aD, aE)
                                  local fw = self:GetText()
                                  if not fw then
                                      fw = ""
                                  else
                                      fw = fw .. "\n"
                                  end
                                  if aC and aD and aE then
                                      aj = self.stdUi.Util.WrapTextInColor(aj, aC, aD, aE, 1)
                                  end
                                  self:SetText(fw .. aj)
                              end, RecalculateSize = function(self)
                                  self:SetSize(self.text:GetWidth() + self.padding * 2, self.text:GetHeight() + self.padding * 2)
                              end}
                          local fx = function(self)
                              self:RecalculateSize()
                              self:ClearAllPoints()
                              self.stdUi:GlueOpposite(self, self.owner, 0, 0, self.anchor)
                          end
                          local fy = {OnEnter = function(self)
                                  self.stdUiTooltip:Show()
                              end, OnLeave = function(self)
                                  self.stdUiTooltip:Hide()
                              end}
                          function d:FrameTooltip(fs, aj, ft, I, fu, fz)
                              local fr
                              if ft and self.frameTooltips[ft] then
                                  fr = self.frameTooltips[ft]
                              else
                                  fr = self:Panel(fs, 10, 10)
                                  fr.stdUi = self
                                  fr:SetFrameStrata("TOOLTIP")
                                  self:ApplyBackdrop(fr, "panel")
                                  fr.padding = self.config.tooltip.padding
                                  fr.text = self:FontString(fr, "")
                                  self:GlueTop(fr.text, fr, fr.padding, -fr.padding, "LEFT")
                                  for aL, aM in pairs(fv) do
                                      fr[aL] = aM
                                  end
                                  if not fz then
                                      hooksecurefunc(fr, "Show", fx)
                                  end
                              end
                              fr.owner = fs
                              fr.anchor = I
                              fs.stdUiTooltip = fr
                              if type(aj) == "string" then
                                  fr:SetText(aj)
                              elseif type(aj) == "function" then
                                  aj(fr)
                              end
                              if fu then
                                  for aL, aM in pairs(fy) do
                                      fs:HookScript(aL, aM)
                                  end
                              end
                              return fr
                          end
                          d:RegisterModule(g, h)
                      end
                      local function fA(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Table", 2
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local e = tinsert
                          local fB = strlen
                          local fC = {SetColumns = function(self, eq)
                                  self.columns = eq
                              end, SetData = function(self, bl)
                                  self.tableData = bl
                              end, AddRow = function(self, bf)
                                  if not self.tableData then
                                      self.tableData = {}
                                  end
                                  e(self.tableData, bf)
                              end, DrawHeaders = function(self)
                                  if not self.headers then
                                      self.headers = {}
                                  end
                                  local fD = 0
                                  for n = 1, #self.columns do
                                      local b7 = self.columns[n]
                                      if b7.header and fB(b7.header) > 0 then
                                          if not self.headers[n] then
                                              self.headers[n] = {text = self.stdUi:FontString(self, "")}
                                          end
                                          local es = self.headers[n]
                                          es.text:SetText(b7.header)
                                          es.text:SetWidth(b7.width)
                                          es.text:SetHeight(self.rowHeight)
                                          es.text:ClearAllPoints()
                                          if b7.align then
                                              es.text:SetJustifyH(b7.align)
                                          end
                                          self.stdUi:GlueTop(es.text, self, fD, 0, "LEFT")
                                          fD = fD + b7.width
                                          es.index = b7.index
                                          es.width = b7.width
                                      end
                                  end
                              end, DrawData = function(self)
                                  if not self.rows then
                                      self.rows = {}
                                  end
                                  local fE = -self.rowHeight
                                  for a4 = 1, #self.tableData do
                                      local bf = self.tableData[a4]
                                      local fD = 0
                                      for a3 = 1, #self.columns do
                                          local b7 = self.columns[a3]
                                          if not self.rows[a4] then
                                              self.rows[a4] = {}
                                          end
                                          if not self.rows[a4][a3] then
                                              self.rows[a4][a3] = {text = self.stdUi:FontString(self, "")}
                                          end
                                          local eC = self.rows[a4][a3]
                                          eC.text:SetText(bf[b7.index])
                                          eC.text:SetWidth(b7.width)
                                          eC.text:SetHeight(self.rowHeight)
                                          eC.text:ClearAllPoints()
                                          if b7.align then
                                              eC.text:SetJustifyH(b7.align)
                                          end
                                          self.stdUi:GlueTop(eC.text, self, fD, fE, "LEFT")
                                          fD = fD + b7.width
                                      end
                                      fE = fE - self.rowHeight
                                  end
                              end, DrawTable = function(self)
                                  self:DrawHeaders()
                                  self:DrawData()
                              end}
                          function d:Table(be, q, r, ez, eq, bl)
                              local dn = self:Panel(be, q, r)
                              dn.stdUi = self
                              dn.rowHeight = ez
                              for aL, aM in pairs(fC) do
                                  dn[aL] = aM
                              end
                              dn:SetColumns(eq)
                              dn:SetData(bl)
                              dn:DrawTable()
                              return dn
                          end
                          d:RegisterModule(g, h)
                      end
                      local function fF(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "ProgressBar", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local fG = {GetPercentageValue = function(self)
                                  local N, cw = self:GetMinMaxValues()
                                  local ap = self:GetValue()
                                  return ap / cw * 100
                              end, TextUpdate = function(self)
                                  return Round(self:GetPercentageValue()) .. "%"
                              end}
                          local fH = {OnValueChanged = function(self, ap)
                                  local cv, cw = self:GetMinMaxValues()
                                  self.text:SetText(self:TextUpdate(cv, cw, ap))
                              end, OnMinMaxChanged = function(self)
                                  local cv, cw = self:GetMinMaxValues()
                                  local ap = self:GetValue()
                                  self.text:SetText(self:TextUpdate(cv, cw, ap))
                              end}
                          function d:ProgressBar(be, q, r, fg)
                              fg = fg or false
                              local fI = CreateFrame("StatusBar", nil, be)
                              fI:SetStatusBarTexture(self.config.backdrop.texture)
                              fI:SetStatusBarColor(
                                  self.config.progressBar.color.r,
                                  self.config.progressBar.color.g,
                                  self.config.progressBar.color.b,
                                  self.config.progressBar.color.a
                              )
                              self:SetObjSize(fI, q, r)
                              fI.texture = fI:GetRegions()
                              fI.texture:SetDrawLayer("BORDER", -1)
                              if fg then
                                  fI:SetOrientation("VERTICAL")
                              end
                              fI.text = self:Label(fI, "")
                              fI.text:SetJustifyH("MIDDLE")
                              fI.text:SetAllPoints()
                              self:ApplyBackdrop(fI)
                              for aL, aM in pairs(fG) do
                                  fI[aL] = aM
                              end
                              for aL, aM in pairs(fH) do
                                  fI:SetScript(aL, aM)
                              end
                              return fI
                          end
                          d:RegisterModule(g, h)
                      end
                      local function fJ(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "ColorPicker", 6
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local fK = {SetColorRGBA = function(self, aC, aD, aE, aF)
                                  self:SetColorAlpha(aF)
                                  self:SetColorRGB(aC, aD, aE)
                                  self.newTexture:SetVertexColor(aC, aD, aE, aF)
                              end, GetColorRGBA = function(self)
                                  local aC, aD, aE = self:GetColorRGB()
                                  return aC, aD, aE, self:GetColorAlpha()
                              end, SetColor = function(self, u)
                                  self:SetColorAlpha(u.a or 1)
                                  self:SetColorRGB(u.r, u.g, u.b)
                                  self.newTexture:SetVertexColor(u.r, u.g, u.b, u.a or 1)
                              end, GetColor = function(self)
                                  local aC, aD, aE = self:GetColorRGB()
                                  return {r = aC, g = aD, b = aE, a = self:GetColorAlpha()}
                              end, SetColorAlpha = function(self, aF, fL)
                                  aF = Clamp(aF, 0, 1)
                                  if not fL then
                                      self.alphaSlider:SetValue(100 - aF * 100)
                                  end
                                  self.aEdit:SetValue(Round(aF * 100))
                                  self.aEdit:Validate()
                                  self:SetColorRGB(self:GetColorRGB())
                              end, GetColorAlpha = function(self)
                                  local aF = Clamp(tonumber(self.aEdit:GetValue()) or 100, 0, 100)
                                  return aF / 100
                              end}
                          local fM = {OnColorSelect = function(self)
                                  local aC, aD, aE, aF = self:GetColorRGBA()
                                  if not self.skipTextUpdate then
                                      self.rEdit:SetValue(aC * 255)
                                      self.gEdit:SetValue(aD * 255)
                                      self.bEdit:SetValue(aE * 255)
                                      self.aEdit:SetValue(100 * aF)
                                      self.rEdit:Validate()
                                      self.gEdit:Validate()
                                      self.bEdit:Validate()
                                      self.aEdit:Validate()
                                  end
                                  self.newTexture:SetVertexColor(aC, aD, aE, aF)
                                  self.alphaTexture:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, aC, aD, aE, 1)
                              end}
                          local function fN(self)
                              local fO = self:GetParent()
                              local aC = tonumber(fO.rEdit:GetValue() or 255) / 255
                              local aD = tonumber(fO.gEdit:GetValue() or 255) / 255
                              local aE = tonumber(fO.bEdit:GetValue() or 255) / 255
                              local aF = tonumber(fO.aEdit:GetValue() or 100) / 100
                              fO.skipTextUpdate = true
                              fO:SetColorRGB(aC, aD, aE)
                              fO.alphaSlider:SetValue(100 - aF * 100)
                              fO.skipTextUpdate = false
                          end
                          function d:ColorPicker(be, fP)
                              local fQ = 128
                              local fi = 10
                              local fR = 16
                              local fO = CreateFrame("ColorSelect", nil, be)
                              fO:SetPoint("CENTER")
                              self:ApplyBackdrop(fO, "panel")
                              self:SetObjSize(fO, 340, 200)
                              fO.wheelTexture = self:Texture(fO, fQ, fQ)
                              self:GlueTop(fO.wheelTexture, fO, 10, -10, "LEFT")
                              fO.wheelThumbTexture = self:Texture(fO, fi, fi, "Interface\\Buttons\\UI-ColorPicker-Buttons")
                              fO.wheelThumbTexture:SetTexCoord(0, 0.15625, 0, 0.625)
                              fO.valueTexture = self:Texture(fO, fR, fQ)
                              self:GlueRight(fO.valueTexture, fO.wheelTexture, 10, 0)
                              fO.valueThumbTexture = self:Texture(fO, fR, fi, "Interface\\Buttons\\UI-ColorPicker-Buttons")
                              fO.valueThumbTexture:SetTexCoord(0.25, 1, 0.875, 0)
                              fO:SetColorWheelTexture(fO.wheelTexture)
                              fO:SetColorWheelThumbTexture(fO.wheelThumbTexture)
                              fO:SetColorValueTexture(fO.valueTexture)
                              fO:SetColorValueThumbTexture(fO.valueThumbTexture)
                              fO.alphaSlider = CreateFrame("Slider", nil, fO)
                              fO.alphaSlider:SetOrientation("VERTICAL")
                              fO.alphaSlider:SetMinMaxValues(0, 100)
                              fO.alphaSlider:SetValue(0)
                              self:SetObjSize(fO.alphaSlider, fR, fQ + fi)
                              self:GlueRight(fO.alphaSlider, fO.valueTexture, 10, 0)
                              fO.alphaTexture = self:Texture(fO.alphaSlider, nil, nil, fP)
                              self:GlueAcross(fO.alphaTexture, fO.alphaSlider, 0, -fi / 2, 0, fi / 2)
                              fO.alphaThumbTexture = self:Texture(fO.alphaSlider, fR, fi, "Interface\\Buttons\\UI-ColorPicker-Buttons")
                              fO.alphaThumbTexture:SetTexCoord(0.275, 1, 0.875, 0)
                              fO.alphaThumbTexture:SetDrawLayer("ARTWORK", 2)
                              fO.alphaSlider:SetThumbTexture(fO.alphaThumbTexture)
                              fO.newTexture = self:Texture(fO, 32, 32, "Interface\\Buttons\\WHITE8X8")
                              fO.oldTexture = self:Texture(fO, 32, 32, "Interface\\Buttons\\WHITE8X8")
                              fO.newTexture:SetDrawLayer("ARTWORK", 5)
                              fO.oldTexture:SetDrawLayer("ARTWORK", 4)
                              self:GlueTop(fO.newTexture, fO, -30, -30, "RIGHT")
                              self:GlueBelow(fO.oldTexture, fO.newTexture, 20, 45)
                              fO.rEdit = self:NumericBox(fO, 60, 20)
                              fO.gEdit = self:NumericBox(fO, 60, 20)
                              fO.bEdit = self:NumericBox(fO, 60, 20)
                              fO.aEdit = self:NumericBox(fO, 60, 20)
                              fO.rEdit:SetMinMaxValue(0, 255)
                              fO.gEdit:SetMinMaxValue(0, 255)
                              fO.bEdit:SetMinMaxValue(0, 255)
                              fO.aEdit:SetMinMaxValue(0, 100)
                              self:AddLabel(fO, fO.rEdit, "R", "LEFT")
                              self:AddLabel(fO, fO.gEdit, "G", "LEFT")
                              self:AddLabel(fO, fO.bEdit, "B", "LEFT")
                              self:AddLabel(fO, fO.aEdit, "A", "LEFT")
                              self:GlueAfter(fO.rEdit, fO.alphaSlider, 20, -fi / 2)
                              self:GlueBelow(fO.gEdit, fO.rEdit, 0, -10)
                              self:GlueBelow(fO.bEdit, fO.gEdit, 0, -10)
                              self:GlueBelow(fO.aEdit, fO.bEdit, 0, -10)
                              fO.okButton = d:Button(fO, 100, 20, OKAY)
                              fO.cancelButton = d:Button(fO, 100, 20, CANCEL)
                              self:GlueBottom(fO.okButton, fO, 40, 20, "LEFT")
                              self:GlueBottom(fO.cancelButton, fO, -40, 20, "RIGHT")
                              for aL, aM in pairs(fK) do
                                  fO[aL] = aM
                              end
                              fO.alphaSlider:SetScript(
                                  "OnValueChanged",
                                  function(fh)
                                      fO:SetColorAlpha((100 - fh:GetValue()) / 100, true)
                                  end
                              )
                              for aL, aM in pairs(fM) do
                                  fO:SetScript(aL, aM)
                              end
                              fO.rEdit.OnValueChanged = fN
                              fO.gEdit.OnValueChanged = fN
                              fO.bEdit.OnValueChanged = fN
                              fO.aEdit.OnValueChanged = fN
                              return fO
                          end
                          local fS = function(self)
                              local fO = self:GetParent()
                              if fO.okCallback then
                                  fO.okCallback(fO)
                              end
                              fO:Hide()
                          end
                          local fT = function(self)
                              local fO = self:GetParent()
                              if fO.cancelCallback then
                                  fO.cancelCallback(fO)
                              end
                              fO:Hide()
                          end
                          function d:ColorPickerFrame(aC, aD, aE, aF, fU, fV, fP)
                              local fW = self.colorPickerFrame
                              if not fW then
                                  fW = self:ColorPicker(UIParent, fP)
                                  fW:SetFrameStrata("FULLSCREEN_DIALOG")
                                  self.colorPickerFrame = fW
                              end
                              fW.okCallback = fU
                              fW.cancelCallback = fV
                              fW.okButton:SetScript("OnClick", fS)
                              fW.cancelButton:SetScript("OnClick", fT)
                              fW:SetColorRGBA(aC or 1, aD or 1, aE or 1, aF or 1)
                              fW.oldTexture:SetVertexColor(aC or 1, aD or 1, aE or 1, aF or 1)
                              fW:ClearAllPoints()
                              fW:SetPoint("CENTER")
                              fW:Show()
                          end
                          local fX = {SetColor = function(self, u)
                                  if type(u) == "table" then
                                      self.color.r = u.r
                                      self.color.g = u.g
                                      self.color.b = u.b
                                      self.color.a = u.a or 1
                                  end
                                  self.target:SetBackdropColor(u.r, u.g, u.b, u.a or 1)
                                  if self.OnValueChanged then
                                      self:OnValueChanged(u)
                                  end
                              end, GetColor = function(self, type)
                                  if type == "hex" then
                                  elseif type == "rgba" then
                                      return self.color.r, self.color.g, self.color.b, self.color.a
                                  else
                                      return self.color
                                  end
                              end}
                          local fY = {
                              OnClick = function(self)
                                  self.stdUi:ColorPickerFrame(
                                      self.color.r,
                                      self.color.g,
                                      self.color.b,
                                      self.color.a,
                                      function(fO)
                                          self:SetColor(fO:GetColor())
                                      end
                                  )
                              end
                          }
                          function d:ColorInput(be, cd, q, r, eN)
                              local J = CreateFrame("Button", nil, be)
                              J.stdUi = self
                              J:EnableMouse(true)
                              self:SetObjSize(J, q, r or 20)
                              self:InitWidget(J)
                              J.target = self:Panel(J, 16, 16)
                              J.target.stdUi = self
                              J.target:SetPoint("LEFT", 0, 0)
                              J.text = self:Label(J, cd)
                              J.text:SetPoint("LEFT", J.target, "RIGHT", 5, 0)
                              J.text:SetPoint("RIGHT", J, "RIGHT", -5, 0)
                              J.color = {r = 1, g = 1, b = 1, a = 1}
                              if not J.SetBackdrop then
                                  Mixin(J, BackdropTemplateMixin)
                              end
                              self:HookDisabledBackdrop(J)
                              self:HookHoverBorder(J)
                              for aL, aM in pairs(fX) do
                                  J[aL] = aM
                              end
                              for aL, aM in pairs(fY) do
                                  J:SetScript(aL, aM)
                              end
                              if eN then
                                  J:SetColor(eN)
                              end
                              return J
                          end
                          d:RegisterModule(g, h)
                      end
                      local function fZ(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Tab", 4
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local f_ = {
                              EnumerateTabs = function(self, cX, ...)
                                  local m
                                  for n = 1, #self.tabs do
                                      local aH = self.tabs[n]
                                      m = cX(aH, self, n, ...)
                                      if m then
                                          break
                                      end
                                  end
                                  return m
                              end,
                              HideAllFrames = function(self)
                                  for N, aH in pairs(self.tabs) do
                                      if aH.frame then
                                          aH.frame:Hide()
                                      end
                                  end
                              end,
                              DrawButtons = function(self)
                                  local g0
                                  for N, aH in pairs(self.tabs) do
                                      if aH.button then
                                          aH.button:Hide()
                                      end
                                      local c5 = aH.button
                                      local g1 = self.buttonContainer
                                      if not c5 then
                                          c5 = self.stdUi:Button(g1, nil, self.buttonHeight)
                                          aH.button = c5
                                          c5.tabFrame = self
                                          c5:SetScript(
                                              "OnClick",
                                              function(g2)
                                                  g2.tabFrame:SelectTab(g2.tab.name)
                                              end
                                          )
                                      end
                                      c5.tab = aH
                                      c5:SetText(aH.title)
                                      c5:ClearAllPoints()
                                      if self.vertical then
                                          c5:SetWidth(self.buttonWidth)
                                      else
                                          self.stdUi:ButtonAutoWidth(c5)
                                      end
                                      if self.vertical then
                                          if not g0 then
                                              self.stdUi:GlueTop(c5, g1, 0, 0, "CENTER")
                                          else
                                              self.stdUi:GlueBelow(c5, g0, 0, -1)
                                          end
                                      else
                                          if not g0 then
                                              self.stdUi:GlueTop(c5, g1, 0, 0, "LEFT")
                                          else
                                              self.stdUi:GlueRight(c5, g0, 5, 0)
                                          end
                                      end
                                      c5:Show()
                                      g0 = c5
                                  end
                              end,
                              DrawFrames = function(self)
                                  for N, aH in pairs(self.tabs) do
                                      if not aH.frame then
                                          aH.frame = self.stdUi:Frame(self.container)
                                      end
                                      aH.frame:ClearAllPoints()
                                      aH.frame:SetAllPoints()
                                      if aH.layout then
                                          self.stdUi:BuildWindow(aH.frame, aH.layout)
                                          self.stdUi:EasyLayout(aH.frame, {padding = {top = 10}})
                                          aH.frame:SetScript(
                                              "OnShow",
                                              function(bM)
                                                  bM:DoLayout()
                                              end
                                          )
                                      end
                                      if aH.onHide then
                                          aH.frame:SetScript("OnHide", aH.onHide)
                                      end
                                  end
                              end,
                              Update = function(self, g3)
                                  if g3 then
                                      self.tabs = g3
                                  end
                                  self:DrawButtons()
                                  self:DrawFrames()
                              end,
                              GetTabByName = function(self, i)
                                  for N, aH in pairs(self.tabs) do
                                      if aH.name == i then
                                          return aH
                                      end
                                  end
                              end,
                              SelectTab = function(self, i)
                                  self.selected = i
                                  if self.selectedTab then
                                      self.selectedTab.button:Enable()
                                  end
                                  self:HideAllFrames()
                                  local g4 = self:GetTabByName(i)
                                  if g4.name == i and g4.frame then
                                      g4.button:Disable()
                                      g4.frame:Show()
                                      self.selectedTab = g4
                                      return true
                                  end
                              end,
                              GetSelectedTab = function(self)
                                  return self.selectedTab
                              end,
                              DoLayout = function(self)
                                  local aH = self:GetSelectedTab()
                                  if aH then
                                      if aH.frame and aH.frame.DoLayout then
                                          aH.frame:DoLayout()
                                      end
                                  end
                              end
                          }
                          function d:TabPanel(be, q, r, g5, fg, g6, dY)
                              fg = fg or false
                              g6 = g6 or 160
                              dY = dY or 20
                              local g7 = self:Frame(be, q, r)
                              g7.stdUi = self
                              g7.tabs = g5
                              g7.vertical = fg
                              g7.buttonWidth = g6
                              g7.buttonHeight = dY
                              g7.buttonContainer = self:Frame(g7)
                              g7.container = self:Panel(g7)
                              if fg then
                                  g7.buttonContainer:SetPoint("TOPLEFT", g7, "TOPLEFT", 0, 0)
                                  g7.buttonContainer:SetPoint("BOTTOMLEFT", g7, "BOTTOMLEFT", 0, 0)
                                  g7.buttonContainer:SetWidth(g6)
                                  g7.container:SetPoint("TOPLEFT", g7.buttonContainer, "TOPRIGHT", 5, 0)
                                  g7.container:SetPoint("BOTTOMLEFT", g7.buttonContainer, "BOTTOMRIGHT", 5, 0)
                                  g7.container:SetPoint("TOPRIGHT", g7, "TOPRIGHT", 0, 0)
                                  g7.container:SetPoint("BOTTOMRIGHT", g7, "BOTTOMRIGHT", 0, 0)
                              else
                                  g7.buttonContainer:SetPoint("TOPLEFT", g7, "TOPLEFT", 0, 0)
                                  g7.buttonContainer:SetPoint("TOPRIGHT", g7, "TOPRIGHT", 0, 0)
                                  g7.buttonContainer:SetHeight(dY)
                                  g7.container:SetPoint("TOPLEFT", g7.buttonContainer, "BOTTOMLEFT", 0, -5)
                                  g7.container:SetPoint("TOPRIGHT", g7.buttonContainer, "BOTTOMRIGHT", 0, -5)
                                  g7.container:SetPoint("BOTTOMLEFT", g7, "BOTTOMLEFT", 0, 0)
                                  g7.container:SetPoint("BOTTOMRIGHT", g7, "BOTTOMRIGHT", 0, 0)
                              end
                              for aL, aM in pairs(f_) do
                                  g7[aL] = aM
                              end
                              g7:Update()
                              if #g7.tabs > 0 then
                                  g7:SelectTab(g7.tabs[1].name)
                              end
                              return g7
                          end
                          d:RegisterModule(g, h)
                      end
                      local function g8(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "Spell", 2
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local g9 = {OnEnter = function(self)
                                  if self.editBox.value then
                                      GameTooltip:SetOwner(self.editBox)
                                      GameTooltip:SetSpellByID(self.editBox.value)
                                      GameTooltip:Show()
                                  end
                              end, OnLeave = function(self)
                                  if self.editBox.value then
                                      GameTooltip:Hide()
                                  end
                              end}
                          function d:SpellBox(be, q, r, cQ, ga)
                              cQ = cQ or 16
                              local ck = self:EditBox(be, q, r, "", ga or self.Util.spellValidator)
                              ck:SetTextInsets(cQ + 7, 3, 3, 3)
                              local gb = self:Panel(ck, cQ, cQ)
                              self:GlueLeft(gb, ck, 2, 0, true)
                              local aq = self:Texture(gb, cQ, cQ, 134400)
                              aq:SetAllPoints()
                              ck.icon = aq
                              gb.editBox = ck
                              for aL, aM in pairs(g9) do
                                  gb:SetScript(aL, aM)
                              end
                              return ck
                          end
                          local gc = {SetSpell = function(self, gd)
                                  local i, N, n, N, N, N, ar = GetSpellInfo(gd)
                                  self.spellId = ar
                                  self.spellName = i
                                  self.icon:SetTexture(n)
                                  self.text:SetText(i)
                              end}
                          local ge = {OnEnter = function(self)
                                  GameTooltip:SetOwner(self.widget)
                                  GameTooltip:SetSpellByID(self.widget.spellId)
                                  GameTooltip:Show()
                              end, OnLeave = function()
                                  GameTooltip:Hide()
                              end}
                          function d:SpellInfo(be, q, r, cQ)
                              cQ = cQ or 16
                              local x = self:Panel(be, q, r)
                              local gb = self:Panel(x, cQ, cQ)
                              self:GlueLeft(gb, x, 2, 0, true)
                              local aq = self:Texture(gb, cQ, cQ)
                              aq:SetAllPoints()
                              local c5 = self:SquareButton(x, cQ, cQ, "DELETE")
                              d:GlueRight(c5, x, -3, 0, true)
                              local aj = self:Label(x)
                              aj:SetPoint("LEFT", aq, "RIGHT", 3, 0)
                              aj:SetPoint("RIGHT", c5, "RIGHT", -3, 0)
                              x.removeBtn = c5
                              x.icon = aq
                              x.text = aj
                              c5.parent = x
                              gb.widget = x
                              for aL, aM in pairs(gc) do
                                  x[aL] = aM
                              end
                              for aL, aM in pairs(ge) do
                                  gb:SetScript(aL, aM)
                              end
                              return x
                          end
                          local gf = {SetSpell = function(self, gd)
                                  local i, N, n, N, N, N, ar = GetSpellInfo(gd)
                                  self.spellId = ar
                                  self.spellName = i
                                  self.icon:SetTexture(n)
                                  self.text:SetText(i)
                              end}
                          local gg = {OnEnter = function(self)
                                  if self.spellId then
                                      GameTooltip:SetOwner(self)
                                      GameTooltip:SetSpellByID(self.spellId)
                                      GameTooltip:Show()
                                  end
                              end, OnLeave = function(self)
                                  if self.spellId then
                                      GameTooltip:Hide()
                                  end
                              end}
                          function d:SpellCheckbox(be, q, r, cQ)
                              cQ = cQ or 16
                              local cP = self:Checkbox(be, "", q, r)
                              cP.spellId = nil
                              cP.spellName = ""
                              local gb = self:Panel(cP, cQ, cQ)
                              gb:SetPoint("LEFT", cP.target, "RIGHT", 5, 0)
                              local aq = self:Texture(gb, cQ, cQ)
                              aq:SetAllPoints()
                              cP.icon = aq
                              cP.text:SetPoint("LEFT", gb, "RIGHT", 5, 0)
                              for aL, aM in pairs(gf) do
                                  cP[aL] = aM
                              end
                              for aL, aM in pairs(gg) do
                                  cP:SetScript(aL, aM)
                              end
                              return cP
                          end
                          d:RegisterModule(g, h)
                      end
                      local function gh(...)
                          local d = LibStub and LibStub("StdUi", true)
                          if not d then
                              return
                          end
                          local g, h = "ContextMenu", 3
                          if not d:UpgradeNeeded(g, h) then
                              return
                          end
                          local gi = function(bq, J)
                              bq.parentContext:CloseSubMenus()
                              bq.childContext:ClearAllPoints()
                              bq.childContext:SetPoint("TOPLEFT", bq, "TOPRIGHT", 0, 0)
                              bq.childContext:Show()
                          end
                          local gj = function(bq, J)
                              if J == "LeftButton" and bq.contextMenuData.callback then
                                  bq.contextMenuData.callback(bq, bq.parentContext)
                              end
                          end
                          local gk = function(self, J)
                              if J == "RightButton" then
                                  local gl = UIParent:GetScale()
                                  local gm, gn = GetCursorPosition()
                                  gm = gm / gl
                                  gn = gn / gl
                                  self:ClearAllPoints()
                                  if self:IsShown() then
                                      self:Hide()
                                  else
                                      self:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", gm, gn)
                                      self:Show()
                                  end
                              end
                          end
                          d.ContextMenuMethods = {
                              CloseMenu = function(self)
                                  self:CloseSubMenus()
                                  self:Hide()
                              end,
                              CloseSubMenus = function(self)
                                  for n = 1, #self.optionFrames do
                                      local go = self.optionFrames[n]
                                      if go.childContext then
                                          go.childContext:CloseMenu()
                                      end
                                  end
                              end,
                              HookRightClick = function(self)
                                  local be = self:GetParent()
                                  if be then
                                      be:HookScript("OnMouseUp", gk)
                                  end
                              end,
                              HookChildrenClick = function(self)
                              end,
                              CreateItem = function(be, bl, n)
                                  local bq
                                  if bl.title then
                                      bq = be.stdUi:Frame(be, nil, 20)
                                      bq.text = be.stdUi:Label(bq)
                                      be.stdUi:GlueLeft(bq.text, bq, 0, 0, true)
                                  elseif bl.isSeparator then
                                      bq = be.stdUi:Frame(be, nil, 20)
                                      bq.texture = be.stdUi:Texture(bq, nil, 8, "Interface\\COMMON\\UI-TooltipDivider-Transparent")
                                      bq.texture:SetPoint("CENTER")
                                      bq.texture:SetPoint("LEFT")
                                      bq.texture:SetPoint("RIGHT")
                                  elseif bl.checkbox then
                                      bq = be.stdUi:Checkbox(be, "")
                                  elseif bl.radio then
                                      bq = be.stdUi:Radio(be, "", bl.radioGroup)
                                  elseif bl.text then
                                      bq = be.stdUi:HighlightButton(be, nil, 20)
                                  end
                                  bq.contextMenuData = bl
                                  if not bl.isSeparator then
                                      bq.text:SetJustifyH("LEFT")
                                  end
                                  if not bl.isSeparator and bl.children then
                                      bq.icon = be.stdUi:Texture(bq, 10, 10, "Interface\\Buttons\\SquareButtonTextures")
                                      bq.icon:SetTexCoord(0.42187500, 0.23437500, 0.01562500, 0.20312500)
                                      be.stdUi:GlueRight(bq.icon, bq, -4, 0, true)
                                      bq.childContext = be.stdUi:ContextMenu(be, bl.children, true, be.level + 1)
                                      bq.parentContext = be
                                      bq.mainContext = be.mainContext
                                      bq:HookScript("OnEnter", gi)
                                  end
                                  if bl.events then
                                      for gp, gq in pairs(bl.events) do
                                          bq:SetScript(gp, gq)
                                      end
                                  end
                                  if bl.callback then
                                      bq:SetScript("OnMouseUp", gj)
                                  end
                                  if bl.custom then
                                      for aS, ap in pairs(bl.custom) do
                                          bq[aS] = ap
                                      end
                                  end
                                  return bq
                              end,
                              UpdateItem = function(be, bq, bl, n)
                                  local bm = be.padding
                                  if bl.title then
                                      bq.text:SetText(bl.title)
                                      be.stdUi:ButtonAutoWidth(bq)
                                  elseif bl.checkbox or bl.radio then
                                      bq.text:SetText(bl.checkbox or bl.radio)
                                      bq:AutoWidth()
                                      if bl.value then
                                          bq:SetValue(bl.value)
                                      end
                                  elseif bl.text then
                                      bq:SetText(bl.text)
                                      be.stdUi:ButtonAutoWidth(bq)
                                  end
                                  if bl.children then
                                      bq:SetWidth(bq:GetWidth() + 16)
                                  end
                                  if be:GetWidth() - bm * 2 < bq:GetWidth() then
                                      be:SetWidth(bq:GetWidth() + bm * 2)
                                  end
                                  bq:SetPoint("LEFT", bm, 0)
                                  bq:SetPoint("RIGHT", -bm, 0)
                                  if bl.color and not bl.isSeparator then
                                      bq.text:SetTextColor(unpack(bl.color))
                                  end
                              end,
                              DrawOptions = function(self, dd)
                                  if not self.optionFrames then
                                      self.optionFrames = {}
                                  end
                                  local N, bb =
                                      self.stdUi:ObjectList(
                                      self,
                                      self.optionFrames,
                                      self.CreateItem,
                                      self.UpdateItem,
                                      dd,
                                      0,
                                      self.padding,
                                      -self.padding
                                  )
                                  self:SetHeight(bb + self.padding)
                              end,
                              StartHideCounter = function(self)
                                  if self.timer then
                                      self.timer:Cancel()
                                  end
                                  self.timer = C_Timer:NewTimer(3, self.TimerCallback)
                              end,
                              StopHideCounter = function()
                              end
                          }
                          d.ContextMenuEvents = {OnEnter = function(self)
                              end, OnLeave = function(self)
                              end}
                          function d:ContextMenu(be, dd, gr, gs)
                              local dn = self:Panel(be)
                              dn.stdUi = self
                              dn.level = gs or 1
                              dn.padding = 16
                              dn:SetFrameStrata("FULLSCREEN_DIALOG")
                              for aL, aM in pairs(self.ContextMenuMethods) do
                                  dn[aL] = aM
                              end
                              for aL, aM in pairs(self.ContextMenuEvents) do
                                  dn:SetScript(aL, aM)
                              end
                              dn:DrawOptions(dd)
                              if dn.level == 1 then
                                  dn.mainContext = dn
                                  if not gr then
                                      dn:HookRightClick()
                                  end
                              end
                              dn:Hide()
                              return dn
                          end
                          d:RegisterModule(g, h)
                      end
                  a()
                  K()
                  T()
                  af()
                  aW()
                  bh()
                  bw()
                  bO()
                  bS()
                  c6()
                  ch()
                  cK()
                  c_()
                  di()
                  dB()
                  dH()
                  en()
                  f2()
                  fp()
                  fA()
                  fF()
                  fJ()
                  fZ()
                  g8()
                  gh()
        System.Console.WriteLine("StdUI was Injected")
        IsInjected = true
      end
    end
    return {
      Init = Init
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.API", function (namespace)
  namespace.class("WoWAPI", function (namespace)
    namespace.enum("PVPClassification", function ()
      return {
        None = -1,
        FlagCarrierHorde = 0,
        FlagCarrierAlliance = 1,
        FlagCarrierNeutral = 2,
        CartRunnerHorde = 3,
        CartRunnerAlliance = 4,
        AssassinHorde = 5,
        AssassinAlliance = 6,
        OrbCarrierBlue = 7,
        OrbCarrierGreen = 8,
        OrbCarrierOrange = 9,
        OrbCarrierPurple = 10,
        __metadata__ = function (out)
          return {
            fields = {
              { "AssassinAlliance", 0xE, System.Int32 },
              { "AssassinHorde", 0xE, System.Int32 },
              { "CartRunnerAlliance", 0xE, System.Int32 },
              { "CartRunnerHorde", 0xE, System.Int32 },
              { "FlagCarrierAlliance", 0xE, System.Int32 },
              { "FlagCarrierHorde", 0xE, System.Int32 },
              { "FlagCarrierNeutral", 0xE, System.Int32 },
              { "None", 0xE, System.Int32 },
              { "OrbCarrierBlue", 0xE, System.Int32 },
              { "OrbCarrierGreen", 0xE, System.Int32 },
              { "OrbCarrierOrange", 0xE, System.Int32 },
              { "OrbCarrierPurple", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    return {}
  end)

  namespace.class("WoWFrame", function (namespace)
    return {}
  end)

  namespace.class("WoWTexture", function (namespace)
    local _holder, class, static
    static = function (this)
      _holder = class()
    end
    class = {
      base = function (out)
        return {
          out.Wrapper.API.WoWFrame
        }
      end,
      static = static
    }
    return class
  end)

  namespace.class("WoWButton", function (namespace)
    local _holder, class, static
    static = function (this)
      _holder = class()
    end
    class = {
      base = function (out)
        return {
          out.Wrapper.API.WoWFrame
        }
      end,
      static = static
    }
    return class
  end)


  namespace.interface("DataProviderBase", function ()
    return {}
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.enum("FactionID", function ()
    return {
      Neutral = 1,
      Horde = 2,
      Alliance = 3,
      __metadata__ = function (out)
        return {
          fields = {
            { "Alliance", 0xE, System.Int32 },
            { "Horde", 0xE, System.Int32 },
            { "Neutral", 0xE, System.Int32 }
          }
        }
      end
    }
  end)
end)

end
do
local System = System
local ListString = System.List(System.String)
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("GatherableTypes", function (namespace)
    local static
    static = function (this)
      local default = ListString()
      default:Add("Anchor Weed")
      default:Add("Draenic Seeds")
      default:Add("Stranglekelp")
      default:Add("Purple Lotus")
      default:Add("Wildvine")
      default:Add("Zin'anthid")
      default:Add("Ancient Lichen")
      default:Add("Goldthorn")
      default:Add("Frost Lotus")
      default:Add("Peacebloom")
      default:Add("Yseralline Seed")
      default:Add("Silverleaf")
      default:Add("Aethril")
      default:Add("Whiptail")
      default:Add("Siren's Pollen")
      default:Add("Sea Stalk")
      default:Add("Earthroot")
      default:Add("Foxflower")
      default:Add("Briarthorn")
      default:Add("Sungrass")
      default:Add("Cinderbloom")
      default:Add("Kingsblood")
      default:Add("Stormvine")
      default:Add("Nightmare Vine")
      default:Add("Adder's Tongue")
      default:Add("Wild Steelbloom")
      default:Add("Firebloom")
      default:Add("Mageroyal")
      default:Add("Golden Sansam")
      default:Add("Star Moss")
      default:Add("Astral Glory")
      default:Add("Mountain Silversage")
      default:Add("Marrowroot")
      default:Add("Vigil's Torch")
      default:Add("Rising Glory")
      default:Add("Death Blossom")
      default:Add("Nightshade")
      default:Add("Ground Death Blossom")
      default:Add("Ground Nightshade")
      default:Add("Ground Widowbloom")
      default:Add("Starlight Rose")
      default:Add("Ground Marrowroot")
      default:Add("Ground Rising Glory")
      default:Add("Golden Lotus")
      default:Add("Ground Vigil's Torch")
      default:Add("Azshara's Veil")
      default:Add("Flame Cap")
      default:Add("Fel Lotus")
      default:Add("Felwort")
      default:Add("Black Lotus")
      default:Add("Grave Moss")
      default:Add("Mana Thistle")
      default:Add("Netherbloom")
      default:Add("Talandra's Rose")
      default:Add("Winter's Kiss")
      default:Add("Dreamleaf")
      default:Add("Liferoot")
      default:Add("Felweed")
      default:Add("Lichbloom")
      default:Add("Gorgrond Flytrap")
      default:Add("Riverbud")
      default:Add("Dreaming Glory")
      default:Add("Swiftthistle")
      default:Add("Arthas' Tears")
      default:Add("Ghost Mushroom")
      default:Add("Gromsblood")
      default:Add("Terocone")
      default:Add("Fire Leaf")
      default:Add("Dreamfoil")
      default:Add("Sorrowmoss")
      default:Add("Khadgar's Whisker")
      default:Add("Blindweed")
      default:Add("Akunda's Bite")
      default:Add("Goldclover")
      default:Add("Heartblossom")
      default:Add("Green Tea Leaf")
      default:Add("Fadeleaf")
      default:Add("Bruiseweed")
      default:Add("Icethorn")
      default:Add("Starflower")
      default:Add("Twilight Jasmine")
      default:Add("Deadnettle")
      default:Add("Ragveil")
      default:Add("Dragon's Teeth")
      default:Add("Frostweed")
      default:Add("Fool's Cap")
      default:Add("Icecap")
      default:Add("Fjarnskaggl")
      default:Add("Snow Lily")
      default:Add("Fireweed")
      default:Add("Nagrand Arrowbloom")
      default:Add("Talador Orchid")
      default:Add("Tiger Lily")
      default:Add("Rain Poppy")
      default:Add("Felwort Seed")
      default:Add("Silkweed")
      default:Add("Blood Elf")
      default:Add("Bloodthistle")
      default:Add("Rising Glory Petal")
      default:Add("Starlight Rose Seed")
      default:Add("Broken Frostweed Stem")
      default:Add("Starflower Petal")
      default:Add("Nagrand Arrowbloom Petal")
      default:Add("Rain Poppy Petal")
      default:Add("Talador Orchid Petal")
      default:Add("Dreamleaf Seed")
      default:Add("Whiptail Stem")
      default:Add("Fire Leaf Bramble")
      default:Add("Broken Fireweed Stem")
      default:Add("Heartblossom Petal")
      default:Add("Ancient Lichen Petal")
      default:Add("Marrowroot Petal")
      default:Add("Gorgrond Flytrap Ichor")
      default:Add("Felweed Stalk")
      default:Add("Purple Lotus Petal")
      default:Add("Nightshade Petal")
      default:Add("Death Blossom Petal")
      default:Add("Silkweed Stem")
      default:Add("Golden Sansam Leaf")
      default:Add("Liferoot Stem")
      default:Add("Aethril Seed")
      default:Add("Foxflower Seed")
      default:Add("Torn Green Tea Leaf")
      default:Add("Dreamfoil Blade")
      default:Add("Goldthorn Bramble")
      default:Add("Talandra's Rose Petal")
      default:Add("Fadeleaf Petal")
      default:Add("Widowbloom Petal")
      default:Add("Mana Thistle Leaf")
      default:Add("Bloodvine")
      default:Add("Fjarnskaggl Seed")
      default:Add("Nightmare Vine Stem")
      default:Add("Icecap Petal")
      default:Add("Firebloom Petal")
      default:Add("Fool's Cap Spores")
      default:Add("Stormvine Stalk")
      default:Add("Cinderbloom Petal")
      default:Add("Ragveil Cap")
      default:Add("Wild Steelbloom Petal")
      default:Add("Earthroot Stem")
      default:Add("Vigil's Torch Petal")
      default:Add("Snow Lily Petal")
      default:Add("Azshara's Veil Stem")
      default:Add("Lichbloom Stalk")
      default:Add("Sungrass Stalk")
      default:Add("Twilight Jasmine Petal")
      default:Add("Dragon's Teeth Stem")
      default:Add("Kingsblood Petal")
      default:Add("Bruiseweed Stem")
      default:Add("Nightmare Seed")
      default:Add("Goldclover Leaf")
      default:Add("Sorrowmoss Leaf")
      default:Add("Ghost Mushroom Cap")
      default:Add("Grave Moss Leaf")
      default:Add("Icethorn Bramble")
      default:Add("Swiftthistle Leaf")
      default:Add("Nightshade")
      this.HerbNames = default
      local default = ListString()
      default:Add("Cobalt Deposit")
      default:Add("Titanium Vein")
      default:Add("Silver Vein")
      default:Add("Khorium Vein")
      default:Add("Adamantite Deposit")
      default:Add("Mithril Deposit")
      default:Add("Fel Iron Deposit")
      default:Add("Iron Deposit")
      default:Add("Saronite Deposit")
      default:Add("Tin Vein")
      default:Add("Obsidium Deposit")
      default:Add("Rich Thorium Vein")
      default:Add("Copper Vein")
      default:Add("Elethium Deposit")
      default:Add("Truesilver Deposit")
      default:Add("Elementium Vein")
      default:Add("Trillium Vein")
      default:Add("Oxxein Deposit")
      default:Add("Gold Vein")
      default:Add("Solenium Deposit")
      default:Add("Laestrite Deposit")
      default:Add("Phaedrum Deposit")
      default:Add("Rich Cobalt Deposit")
      default:Add("Sinvyr Deposit")
      default:Add("Rich Elethium Deposit")
      default:Add("Rich Saronite Deposit")
      default:Add("Pyrite Deposit")
      default:Add("Rich Adamantite Deposit")
      default:Add("Small Thorium Vein")
      default:Add("Phaedrum Deposit")
      default:Add("Dark Iron Deposit")
      default:Add("Pure Saronite Deposit")
      default:Add("Rich Sinvyr Deposit")
      default:Add("Rich Solenium Deposit")
      default:Add("Rich Laestrite Deposit")
      default:Add("Rich Obsidium Deposit")
      default:Add("Ancient Gem Vein")
      default:Add("Rich Oxxein Deposit")
      default:Add("Rich Elementium Vein")
      default:Add("Rich Trillium Vein")
      default:Add("Leystone Deposit")
      default:Add("Rich Adamantite Deposit")
      default:Add("Felslate Deposit")
      default:Add("Monelite Deposit")
      default:Add("Ghost Iron Deposit")
      default:Add("Platinum Deposit")
      default:Add("Rich Phaedrum Deposit")
      default:Add("Kyparite Deposit")
      default:Add("Storm Silver Deposit")
      default:Add("Nethercite Deposit")
      default:Add("Tin Vein")
      default:Add("Felslate Seam")
      default:Add("Brimstone Destroyer Core")
      default:Add("Leystone Seam")
      default:Add("Rich Pyrite Deposit")
      default:Add("Rich Ghost Iron Deposit")
      default:Add("True Iron Deposit")
      default:Add("Ooze Covered Thorium Vein")
      default:Add("Rich Felslate Deposit")
      default:Add("Brimstone Destroyer Core")
      default:Add("Brimstone Destroyer Core")
      default:Add("Ooze Covered Rich Thorium Vein")
      default:Add("Harvestable Precious Crystal")
      default:Add("Smoldering True Iron Deposit")
      default:Add("True Iron Deposit")
      default:Add("Azure Ore")
      default:Add("Burnished Platinum Deposit")
      default:Add("Rich Leystone Deposit")
      default:Add("Rich True Iron Deposit")
      default:Add("Luminous Monelite Deposit")
      default:Add("Shiny Stones")
      default:Add("Brimstone Destroyer Core")
      default:Add("Copper Vein")
      default:Add("Monelite Seam")
      default:Add("Rich Storm Silver Deposit")
      default:Add("Incendicite Mineral Vein")
      default:Add("Blackrock Deposit")
      default:Add("Empyrium Seam")
      default:Add("Hardened Monelite Deposit")
      default:Add("Blackrock Deposit")
      default:Add("Rich True Iron Deposit")
      default:Add("Brimstone Destroyer Core")
      default:Add("Gleaming Storm Silver Deposit")
      default:Add("Luminous Monelite Deposit")
      default:Add("Storm Silver Seam")
      default:Add("Trillium Vein")
      default:Add("Coarse Storm Silver Deposit")
      default:Add("Dense Storm Silver Deposit")
      default:Add("Empyrium Deposit")
      default:Add("Rich Empyrium Deposit")
      default:Add("Chrysoberyl Outcropping")
      default:Add("Felslate Spike")
      default:Add("Gleaming Storm Silver Deposit")
      default:Add("Large Obsidian Chunk")
      default:Add("Rich Kyparite Deposit")
      default:Add("Rich Monelite Deposit")
      default:Add("Rich Trillium Vein")
      default:Add("Small Obsidian Chunk")
      default:Add("Brimstone Destroyer Core")
      default:Add("Primordial Felslate Deposit")
      default:Add("Rich Platinum Deposit")
      default:Add("Superior Leystone Deposit")
      default:Add("Alterac Granite")
      default:Add("Burnished Platinum Deposit")
      default:Add("Copper Vein")
      default:Add("Enchanted Earth")
      default:Add("Osmenite Seam")
      default:Add("Rich Blackrock Deposit")
      default:Add("Rich Blackrock Deposit")
      default:Add("Rough Monelite Deposit")
      default:Add("Secreted Wax Glob")
      default:Add("True Iron Deposit")
      default:Add("True Iron Deposit")
      default:Add("Ooze Covered Silver Vein")
      default:Add("Ooze Covered Iron Deposit")
      default:Add("Rich Thorium Vein")
      default:Add("Black Blood of Yogg-Saron")
      default:Add("Brimstone Destroyer Core")
      default:Add("Brimstone Destroyer Core")
      default:Add("Rich True Iron Deposit")
      default:Add("Lesser Bloodstone Deposit")
      default:Add("Indurium Mineral Vein")
      default:Add("Brimstone Destroyer Core")
      default:Add("Coarse Leystone Outcropping")
      default:Add("Copper Vein")
      default:Add("Fine Leystone Deposit")
      default:Add("Massive Leystone Deposit")
      default:Add("Rich Ghost Iron Deposit")
      default:Add("Blackrock Deposit")
      default:Add("Brimstone Destroyer Core")
      default:Add("Brimstone Destroyer Core")
      default:Add("Brimstone Destroyer Core")
      default:Add("Burning Felslate Deposit")
      default:Add("Chrysoberyl Outcropping")
      default:Add("Dense Leystone Outcropping")
      default:Add("Fiery Leystone Deposit")
      default:Add("Gleaming Leystone Outcropping")
      default:Add("Luminous Sinvyr Deposit")
      default:Add("Ooze Covered Truesilver Deposit")
      default:Add("Primal Leystone Outcropping")
      default:Add("Rich Osmenite Deposit")
      default:Add("Rich True Iron Deposit")
      default:Add("Shattered Felslate Seam")
      default:Add("Stormy Leystone Deposit")
      default:Add("Warm Leystone Deposit")
      default:Add("Ooze Covered Gold Vein")
      default:Add("Rich Adamantite Deposit")
      default:Add("Rich Adamantite Deposit")
      default:Add("Blackrock Deposit")
      default:Add("Brimstone Destroyer Core")
      default:Add("Brimstone Destroyer Core")
      default:Add("Brimstone Destroyer Core")
      default:Add("Charged Leystone Deposit")
      default:Add("Chrysoberyl Outcropping")
      default:Add("Chunk of Saronite")
      default:Add("Darkened Felslate Deposit")
      default:Add("Ductile Platinum Deposit")
      default:Add("Enchanted Earth")
      default:Add("Exquisite Leystone Deposit")
      default:Add("Ghost Iron Deposit")
      default:Add("Hardened Leystone Outcropping")
      default:Add("Hardened Monelite Deposit")
      default:Add("Heavy Felslate Deposit")
      default:Add("Odious Felslate Outcropping")
      default:Add("Osmenite Deposit")
      default:Add("Radiant Leystone Outcropping")
      default:Add("Rich Blackrock Deposit")
      default:Add("Rich Trillium Vein")
      default:Add("Sapphire of Aku'Mai")
      default:Add("Smooth Platinum Deposit")
      default:Add("Strange Ore")
      default:Add("Striking Leystone Deposit")
      default:Add("Wild Leystone Seam")
      default:Add("Iron Deposit")
      default:Add("Iron Deposit")
      default:Add("Gold Vein")
      default:Add("Ooze Covered Mithril Deposit")
      default:Add("Titanium Node")
      default:Add("Ancient Leystone Deposit")
      default:Add("Bright Leystone Deposit")
      default:Add("Brilliant Leystone Seam")
      default:Add("Coarse Storm Silver Deposit")
      default:Add("Crude Leystone Seam")
      default:Add("Dark Leystone Deposit")
      default:Add("Draenethyst Mine Crystal")
      default:Add("Ductile Platinum Deposit")
      default:Add("Glowing Leystone Deposit")
      default:Add("Hard Leystone Deposit")
      default:Add("Krasari Iron")
      default:Add("Kyparite Deposit")
      default:Add("Luminous Leystone Outcropping")
      default:Add("Magnificent Leystone Deposit")
      default:Add("Malevolent Felslate Outcropping")
      default:Add("Needles Iron Pyrite")
      default:Add("Nethervine Crystal")
      default:Add("Raw Leystone Seam")
      default:Add("Rich Energized Iron")
      default:Add("Rich Kyparite Deposit")
      default:Add("Rough Leystone Outcropping")
      default:Add("Smooth Leystone Deposit")
      default:Add("Smooth Platinum Deposit")
      default:Add("The Light of Souls")
      default:Add("Tin Vein")
      default:Add("Truesilver Deposit")
      default:Add("Arcanite Lode")
      default:Add("Ooze Covered Arcanite Lode")
      default:Add("Saronite Deposit")
      default:Add("Obsidium Deposit")
      default:Add("Rich Saronite Deposit")
      default:Add("Dense Storm Silver Deposit")
      default:Add("Iron Deposit")
      default:Add("Mining Node Point Check")
      default:Add("Rough Monelite Deposit")
      this.OreNames = default
    end
    return {
      static = static
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("LocationInfo", function (namespace)
    return {
      X = 0,
      Y = 0,
      Z = 0,
      MapID = 0,
      ObjectId = 0
    }
  end)
end)

end
do
local System = System
local WrapperDatabase
local ListNPCLocationInfo
local ListNodeLocationInfo
System.import(function (out)
  WrapperDatabase = Wrapper.Database
  ListNPCLocationInfo = System.List(WrapperDatabase.NPCLocationInfo)
  ListNodeLocationInfo = System.List(WrapperDatabase.NodeLocationInfo)
end)
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("MapDataEntry", function (namespace)
    local RestoreFromJson, __ctor__
    __ctor__ = function (this)
      this.InnKeepers = ListNPCLocationInfo()
      this.MailBoxes = ListNPCLocationInfo()
      this.Auctioneers = ListNPCLocationInfo()
      this.FlightMaster = ListNPCLocationInfo()
      this.Vendors = ListNPCLocationInfo()
      this.Repair = ListNPCLocationInfo()
      this.Nodes = ListNodeLocationInfo()
    end
    RestoreFromJson = function (this, mapDataEntry)
      for _, node in System.each(mapDataEntry.Nodes) do
        local default = WrapperDatabase.NodeLocationInfo()
        default.X = node.X
        default.Y = node.Y
        default.Z = node.Z
        default.Name = node.Name
        default.NodeType = node.NodeType
        default.MapID = node.MapID
        default.ObjectId = node.ObjectId
        this.Nodes:Add(default)
      end

      for _, node in System.each(mapDataEntry.Repair) do
        local default = WrapperDatabase.NPCLocationInfo()
        default.X = node.X
        default.Y = node.Y
        default.Z = node.Z
        default.Name = node.Name
        default.NodeType = node.NodeType
        default.MapID = node.MapID
        default.ObjectId = node.ObjectId
        this.Repair:Add(default)
      end

      for _, node in System.each(mapDataEntry.Vendors) do
        local default = WrapperDatabase.NPCLocationInfo()
        default.X = node.X
        default.Y = node.Y
        default.Z = node.Z
        default.Name = node.Name
        default.NodeType = node.NodeType
        default.MapID = node.MapID
        default.ObjectId = node.ObjectId
        this.Vendors:Add(default)
      end

      for _, node in System.each(mapDataEntry.InnKeepers) do
        local default = WrapperDatabase.NPCLocationInfo()
        default.X = node.X
        default.Y = node.Y
        default.Z = node.Z
        default.Name = node.Name
        default.NodeType = node.NodeType
        default.MapID = node.MapID
        default.ObjectId = node.ObjectId
        this.InnKeepers:Add(default)
      end

      for _, node in System.each(mapDataEntry.FlightMaster) do
        local default = WrapperDatabase.NPCLocationInfo()
        default.X = node.X
        default.Y = node.Y
        default.Z = node.Z
        default.Name = node.Name
        default.NodeType = node.NodeType
        default.MapID = node.MapID
        default.ObjectId = node.ObjectId
        this.FlightMaster:Add(default)
      end


      for _, node in System.each(mapDataEntry.MailBoxes) do
        local default = WrapperDatabase.NPCLocationInfo()
        default.X = node.X
        default.Y = node.Y
        default.Z = node.Z
        default.Name = node.Name
        default.NodeType = node.NodeType
        default.MapID = node.MapID
        default.ObjectId = node.ObjectId
        this.MailBoxes:Add(default)
      end
    end
    return {
      RestoreFromJson = RestoreFromJson,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("NodeLocationInfo", function (namespace)
    return {
      base = function (out)
        return {
          out.Wrapper.Database.LocationInfo
        }
      end,
      NodeType = 0
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.enum("NodeType", function ()
    return {
      Ore = 1,
      Herb = 2,
      __metadata__ = function (out)
        return {
          fields = {
            { "Herb", 0xE, System.Int32 },
            { "Ore", 0xE, System.Int32 }
          }
        }
      end
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("NPCLocationInfo", function (namespace)
    return {
      base = function (out)
        return {
          out.Wrapper.Database.LocationInfo
        }
      end,
      NodeType = 0,
      Faction = 0
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.enum("NPCNodeType", function ()
    return {
      Repair = 1,
      Vendor = 2,
      FlightMaster = 3,
      InnKeeper = 4,
      MailBox = 5,
      __metadata__ = function (out)
        return {
          fields = {
            { "FlightMaster", 0xE, System.Int32 },
            { "InnKeeper", 0xE, System.Int32 },
            { "MailBox", 0xE, System.Int32 },
            { "Repair", 0xE, System.Int32 },
            { "Vendor", 0xE, System.Int32 }
          }
        }
      end
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("VendorLocationInfo", function (namespace)
    return {}
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local ListInt32 = System.List(System.Int32)
local HashSetInt32 = System.HashSet(System.Int32)
local WrapperDatabase
local WrapperWoW
local ListNPCLocationInfo
local ListNodeLocationInfo
local DictInt32MapDataEntry
System.import(function (out)
  WrapperDatabase = Wrapper.Database
  WrapperWoW = Wrapper.WoW
  ListNPCLocationInfo = System.List(WrapperDatabase.NPCLocationInfo)
  ListNodeLocationInfo = System.List(WrapperDatabase.NodeLocationInfo)
  DictInt32MapDataEntry = System.Dictionary(System.Int32, WrapperDatabase.MapDataEntry)
end)
System.namespace("Wrapper.Database", function (namespace)
  namespace.class("WoWDatabase", function (namespace)
    local DirtyMapIds, IsSaveTaskRunning, getHasDirtyMaps, GetGridHash, InsertNpcIfRequired, HandlePersistance, InsertNodeIfRequired, EnsureSaveProcessIsRunning, 
    GetMapDatabase, GetClosestRepairNPC, GetClosestVendorNPC, GetAllHerbLocations, GetAllOreLocations, class, static
    static = function (this)
      this.Maps = DictInt32MapDataEntry()
      local default = HashSetInt32()
      default:Add(62822)
      default:Add(64515)
      default:Add(32642)
      default:Add(32641)
      default:Add(142668)
      default:Add(142666)
      this.BannedObjectIDs = default
      DirtyMapIds = ListInt32()
    end
    IsSaveTaskRunning = false
    getHasDirtyMaps = function ()
      return Linq.Count(DirtyMapIds) > 0
    end
    GetGridHash = function (Location)
      return WrapperWoW.Vector3.Floor(WrapperWoW.Vector3.Divide1(WrapperWoW.Vector3(Location.X, Location.Y, Location.Z), class.GRID_SIZE)):GetHashCode()
    end
    InsertNpcIfRequired = function (Unit)
      local MapId =  __LB__.GetMapId()
      local IsRepair =  __LB__.UnitHasNpcFlag(Unit.GUID, 4096 --[[ENpcFlags.Repair]])
      local IsVendor =  __LB__.UnitHasNpcFlag(Unit.GUID, 128 --[[ENpcFlags.Vendor]])
      local IsInnKeeper = false
      local IsFlightmaster = false
      local IsMailBox = false
      --LuaBox.Instance.UnitHasNpcFlag(Unit.GUID, LuaBox.ENpcFlags.Mailbox);

      if (not IsRepair and not IsVendor and not IsInnKeeper and not IsFlightmaster and not IsMailBox) or __LB__.UnitTagHandler(GetUnitSpeed, Unit.GUID) > 1 or class.BannedObjectIDs:Contains(Unit.ObjectId) then
        return
      end

      local IsDirty = false
      local MapDatabase = GetMapDatabase(MapId)

      if IsRepair then
        if not Linq.Any(MapDatabase.Repair, function (x)
          return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
        end) then
          local UnitFaction
          local FactionGroupString = __LB__.UnitTagHandler(UnitFactionGroup, Unit.GUID)

          repeat
            local default = FactionGroupString
            if default == "Alliance" then
              UnitFaction = 3 --[[FactionID.Alliance]]
              break
            elseif default == "Horde" then
              UnitFaction = 2 --[[FactionID.Horde]]
              break
            else
              UnitFaction = 1 --[[FactionID.Neutral]]
              break
            end
          until 1

          local extern = WrapperDatabase.NPCLocationInfo()
          extern.X = Unit.Position.X
          extern.Y = Unit.Position.Y
          extern.Z = Unit.Position.Z
          extern.ObjectId = Unit.ObjectId
          extern.MapID = MapId
          extern.NodeType = 1 --[[NPCNodeType.Repair]]
          extern.Faction = UnitFaction
          extern.Name = Unit.Name
          MapDatabase.Repair:Add(extern)

          System.Console.WriteLine("[WoWDatabase] Found New Repair NPC: " .. System.toString(Unit.Name))
          IsDirty = true
        end
      end
      if IsVendor then
        if not Linq.Any(MapDatabase.Vendors, function (x)
          return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
        end) then
          local UnitFaction
          local FactionGroupString = __LB__.UnitTagHandler(UnitFactionGroup, Unit.GUID)

          repeat
            local default = FactionGroupString
            if default == "Alliance" then
              UnitFaction = 3 --[[FactionID.Alliance]]
              break
            elseif default == "Horde" then
              UnitFaction = 2 --[[FactionID.Horde]]
              break
            else
              UnitFaction = 1 --[[FactionID.Neutral]]
              break
            end
          until 1

          local extern = WrapperDatabase.NPCLocationInfo()
          extern.X = Unit.Position.X
          extern.Y = Unit.Position.Y
          extern.Z = Unit.Position.Z
          extern.ObjectId = Unit.ObjectId
          extern.MapID = MapId
          extern.NodeType = 2 --[[NPCNodeType.Vendor]]
          extern.Faction = UnitFaction
          extern.Name = Unit.Name
          MapDatabase.Vendors:Add(extern)

          System.Console.WriteLine("[WoWDatabase] Found New Vendor NPC: " .. System.toString(Unit.Name))
          IsDirty = true
        end
      end
      if IsInnKeeper then
        if not Linq.Any(MapDatabase.InnKeepers, function (x)
          return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
        end) then
          local UnitFaction
          local FactionGroupString = __LB__.UnitTagHandler(UnitFactionGroup, Unit.GUID)

          repeat
            local default = FactionGroupString
            if default == "Alliance" then
              UnitFaction = 3 --[[FactionID.Alliance]]
              break
            elseif default == "Horde" then
              UnitFaction = 2 --[[FactionID.Horde]]
              break
            else
              UnitFaction = 1 --[[FactionID.Neutral]]
              break
            end
          until 1

          local extern = WrapperDatabase.NPCLocationInfo()
          extern.X = Unit.Position.X
          extern.Y = Unit.Position.Y
          extern.Z = Unit.Position.Z
          extern.ObjectId = Unit.ObjectId
          extern.MapID = MapId
          extern.NodeType = 4 --[[NPCNodeType.InnKeeper]]
          extern.Faction = UnitFaction
          extern.Name = Unit.Name
          MapDatabase.InnKeepers:Add(extern)

          System.Console.WriteLine("[WoWDatabase] Found New InnKeeper NPC: " .. System.toString(Unit.Name))
          IsDirty = true
        end
      end
      if IsFlightmaster then
        if not Linq.Any(MapDatabase.FlightMaster, function (x)
          return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
        end) then
          local UnitFaction
          local FactionGroupString = __LB__.UnitTagHandler(UnitFactionGroup, Unit.GUID)

          repeat
            local default = FactionGroupString
            if default == "Alliance" then
              UnitFaction = 3 --[[FactionID.Alliance]]
              break
            elseif default == "Horde" then
              UnitFaction = 2 --[[FactionID.Horde]]
              break
            else
              UnitFaction = 1 --[[FactionID.Neutral]]
              break
            end
          until 1

          local extern = WrapperDatabase.NPCLocationInfo()
          extern.X = Unit.Position.X
          extern.Y = Unit.Position.Y
          extern.Z = Unit.Position.Z
          extern.ObjectId = Unit.ObjectId
          extern.MapID = MapId
          extern.NodeType = 3 --[[NPCNodeType.FlightMaster]]
          extern.Faction = UnitFaction
          extern.Name = Unit.Name
          MapDatabase.FlightMaster:Add(extern)

          System.Console.WriteLine("[WoWDatabase] Found New Flightmaster NPC: " .. System.toString(Unit.Name))
          IsDirty = true
        end
      end
      if IsMailBox then
        if not Linq.Any(MapDatabase.MailBoxes, function (x)
          return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
        end) then
          local UnitFaction
          local FactionGroupString = __LB__.UnitTagHandler(UnitFactionGroup, Unit.GUID)

          repeat
            local default = FactionGroupString
            if default == "Alliance" then
              UnitFaction = 3 --[[FactionID.Alliance]]
              break
            elseif default == "Horde" then
              UnitFaction = 2 --[[FactionID.Horde]]
              break
            else
              UnitFaction = 1 --[[FactionID.Neutral]]
              break
            end
          until 1

          local extern = WrapperDatabase.NPCLocationInfo()
          extern.X = Unit.Position.X
          extern.Y = Unit.Position.Y
          extern.Z = Unit.Position.Z
          extern.ObjectId = Unit.ObjectId
          extern.MapID = MapId
          extern.NodeType = 5 --[[NPCNodeType.MailBox]]
          extern.Faction = UnitFaction
          extern.Name = Unit.Name
          MapDatabase.MailBoxes:Add(extern)

          System.Console.WriteLine("[WoWDatabase] Found New MailBox NPC: " .. System.toString(Unit.Name))
          IsDirty = true
        end
      end

      if IsDirty and not DirtyMapIds:Contains(MapId) then
        DirtyMapIds:Add(MapId)
        EnsureSaveProcessIsRunning()
      end
    end
    HandlePersistance = function ()
      if not  __LB__.DirectoryExists(System.toString( __LB__.GetBaseDirectory()) .. "\\BroBot\\Database\\MapData\\") then
         __LB__.CreateDirectory(System.toString( __LB__.GetBaseDirectory()) .. "\\BroBot\\Database\\MapData\\")
      end

      for _, MapId in System.each(DirtyMapIds) do
        local Path = System.toString( __LB__.GetBaseDirectory()) .. "\\BroBot\\Database\\MapData\\" .. MapId .. ".db"
        local Data = GetMapDatabase(MapId)
         __LB__.WriteFile(Path, LibJSON.Serialize(Data), false)

        System.Console.WriteLine("[WoWDatabase] Persisted Changes to MapId: " .. MapId)
      end

      DirtyMapIds:Clear()
    end
    InsertNodeIfRequired = function (Unit)
      local MapId =  __LB__.GetMapId()
      local IsHerbOrOre = (Unit:getIsHerb() or Unit:getIsOre())
      local IsMailBox = __LB__.GameObjectType(Unit.GUID) == 19 --[[EGameObjectTypes.Mailbox]]



      if (not IsHerbOrOre and not IsMailBox) or class.BannedObjectIDs:Contains(Unit.ObjectId) then
        return
      end

      local IsDirty = false
      local MapDatabase = GetMapDatabase(MapId)


      if IsMailBox then
        System.Console.WriteLine("Handling MailBox")

        if not Linq.Any(MapDatabase.MailBoxes, function (x)
          return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
        end) then
          local default = WrapperDatabase.NPCLocationInfo()
          default.X = Unit.Position.X
          default.Y = Unit.Position.Y
          default.Z = Unit.Position.Z
          default.ObjectId = Unit.ObjectId
          default.MapID = MapId
          default.NodeType = 5 --[[NPCNodeType.MailBox]]
          default.Faction = 1 --[[FactionID.Neutral]]
          default.Name = Unit.Name
          MapDatabase.MailBoxes:Add(default)

          System.Console.WriteLine("[WoWDatabase] Found New MailBox GameObject: " .. System.toString(Unit.Name))
          IsDirty = true
        end

        return
      end








      if not Linq.Any(MapDatabase.Nodes, function (x)
        return x.ObjectId == Unit.ObjectId and WrapperWoW.Vector3.Distance(Unit.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z)) < class.GRID_SIZE
      end) then
        local default = WrapperDatabase.NodeLocationInfo()
        default.X = Unit.Position.X
        default.Y = Unit.Position.Y
        default.Z = Unit.Position.Z
        default.ObjectId = Unit.ObjectId
        default.MapID = MapId
        default.NodeType = Unit:getIsHerb() and 2 --[[NodeType.Herb]] or 1 --[[NodeType.Ore]]
        default.Name = Unit.Name
        MapDatabase.Nodes:Add(default)

        System.Console.WriteLine("[WoWDatabase] Found New Harvest Node: " .. System.toString(Unit.Name))
        IsDirty = true
      end

      if IsDirty and not DirtyMapIds:Contains(MapId) then
        DirtyMapIds:Add(MapId)
        EnsureSaveProcessIsRunning()
      end
    end
    EnsureSaveProcessIsRunning = function ()
      if not IsSaveTaskRunning then
        IsSaveTaskRunning = true

        C_Timer.NewTicker(15, function ()
          HandlePersistance()
        end)
      end
    end
    GetMapDatabase = function (MapId)
      if not class.Maps:ContainsKey(MapId) then
        if not  __LB__.FileExists(System.toString( __LB__.GetBaseDirectory()) .. "\\BroBot\\Database\\MapData\\" .. MapId .. ".db") then
          local default = WrapperDatabase.MapDataEntry()
          default.Nodes = ListNodeLocationInfo()
          default.Vendors = ListNPCLocationInfo()
          default.Repair = ListNPCLocationInfo()
          class.Maps:AddKeyValue(MapId, default)
        else
          local Text =  __LB__.ReadFile(System.toString( __LB__.GetBaseDirectory()) .. "\\BroBot\\Database\\MapData\\" .. MapId .. ".db")
          local MapDataEntry = LibJSON.Deserialize(Text)
          local MapDataClass = WrapperDatabase.MapDataEntry()
          MapDataClass:RestoreFromJson(MapDataEntry)
          class.Maps:AddKeyValue(MapId, MapDataClass)
        end
      end

      return class.Maps:get(MapId)
    end
    GetClosestRepairNPC = function ()
      local MapDb = GetMapDatabase( __LB__.GetMapId())

      if Linq.Count(MapDb.Repair) > 0 then
        return Linq.FirstOrDefault(Linq.OrderBy(MapDb.Repair, function (x)
          return WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z))
        end, nil, System.Double))
      end

      return nil
    end
    GetClosestVendorNPC = function ()
      local MapDb = GetMapDatabase( __LB__.GetMapId())

      if Linq.Count(MapDb.Vendors) > 0 then
        return Linq.FirstOrDefault(Linq.OrderBy(MapDb.Vendors, function (x)
          return WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, WrapperWoW.Vector3(x.X, x.Y, x.Z))
        end, nil, System.Double))
      end

      return nil
    end
    GetAllHerbLocations = function ()
      local MapDb = GetMapDatabase( __LB__.GetMapId())
      local Herbs = Linq.ToList(Linq.Where(MapDb.Nodes, function (x)
        return x.NodeType == 2 --[[NodeType.Herb]]
      end))
      return Herbs
    end
    GetAllOreLocations = function ()
      local MapDb = GetMapDatabase( __LB__.GetMapId())
      local Herbs = Linq.ToList(Linq.Where(MapDb.Nodes, function (x)
        return x.NodeType == 1 --[[NodeType.Ore]]
      end))
      return Herbs
    end
    class = {
      GRID_SIZE = 20,
      getHasDirtyMaps = getHasDirtyMaps,
      GetGridHash = GetGridHash,
      InsertNpcIfRequired = InsertNpcIfRequired,
      HandlePersistance = HandlePersistance,
      InsertNodeIfRequired = InsertNodeIfRequired,
      GetMapDatabase = GetMapDatabase,
      GetClosestRepairNPC = GetClosestRepairNPC,
      GetClosestVendorNPC = GetClosestVendorNPC,
      GetAllHerbLocations = GetAllHerbLocations,
      GetAllOreLocations = GetAllOreLocations,
      static = static
    }
    return class
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Helpers", function (namespace)
  namespace.class("FileLogger", function (namespace)
    local WriteLine
    WriteLine = function (this)
    end
    return {
      WriteLine = WriteLine
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.Helpers", function (namespace)
  namespace.class("LuaHelper", function (namespace)
    local GetGlobalFrom_G_Namespace
    GetGlobalFrom_G_Namespace = function (PropertyChain, T)
      local CurrentObject = _G[PropertyChain:get(0)]
      --Console.WriteLine("Aquired Global Object: " + PropertyChain[0]);
      local Index = 1

      while Index < #PropertyChain do
        --Console.WriteLine("Trying To Access Property: " + PropertyChain[Index]);
        local NameValue = PropertyChain:get(Index)
        CurrentObject = CurrentObject[NameValue]
        Index = Index + 1
      end

      return System.cast(T, CurrentObject)
    end
    return {
      GetGlobalFrom_G_Namespace = GetGlobalFrom_G_Namespace
    }
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local WrapperHelpers
local WrapperWoW
local ListScoredWowPlayer
System.import(function (out)
  WrapperHelpers = Wrapper.Helpers
  WrapperWoW = Wrapper.WoW
  ListScoredWowPlayer = System.List(WrapperHelpers.ScoredWowPlayer)
end)
System.namespace("Wrapper.Helpers", function (namespace)
  namespace.class("ScoredWowPlayer", function (namespace)
    return {
      Score = 0
    }
  end)

  namespace.class("SmartMovePVP", function (namespace)
    local Pulse, GetBestUnit, __ctor__
    __ctor__ = function (this)
      this.Units = ListScoredWowPlayer()
    end
    Pulse = function (this)
      if GetTime() - this.LastUpdateTime < 5 then
        return
      end

      this.LastUpdateTime = GetTime()

      this.Units:Clear()

      local FriendlyScore = 4
      local HostileScore = 2

      local Role = GetSpecializationRole(GetSpecialization())

      if Role == "HEALER" then
        FriendlyScore = 5
        HostileScore = 2
      end


      local ValidUnits = Linq.Where(WrapperWoW.ObjectManager.GetAllPlayers(500), function (x)
        return x.GUID ~= WrapperWoW.ObjectManager.getInstance().Player.GUID and not x.Dead
      end)

      --Console.WriteLine("Smart Move Found " + ValidUnits.Count() + " Units");

      for _, unit in System.each(ValidUnits) do
        local score = 0

        local NumFriends = Linq.Count((Linq.Where(ValidUnits, function (x)
          return WrapperWoW.Vector3.Distance(x.Position, unit.Position) < 60 and x.Reaction > 4
        end)))

        local NumHostile = Linq.Count((Linq.Where(ValidUnits, function (x)
          return WrapperWoW.Vector3.Distance(x.Position, unit.Position) < 60 and x.Reaction < 4
        end)))

        score = 1000 + (NumFriends * FriendlyScore) + (NumHostile * HostileScore)

        if (NumHostile * HostileScore) > (NumFriends * FriendlyScore) * 1.5 then
          score = score - 1000
          -- No suicde plx.
        end

        --Console.WriteLine("Scored New Unit: " + unit.Name + " score: " + score);
        local default = WrapperHelpers.ScoredWowPlayer()
        default.Player = unit
        default.Score = score
        this.Units:Add(default)
      end
    end
    GetBestUnit = function (this)
      local default
      if Linq.Count(this.Units) > 0 then
        default = Linq.FirstOrDefault(Linq.OrderByDescending(this.Units, function (x)
          return x.Score
        end, nil, System.Single))
      else
        default = nil
      end
      return default
    end
    return {
      LastUpdateTime = 0,
      Pulse = Pulse,
      GetBestUnit = GetBestUnit,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local WrapperHelpers
local WrapperWoW
local ListScoredWowPlayer
System.import(function (out)
  WrapperHelpers = Wrapper.Helpers
  WrapperWoW = Wrapper.WoW
  ListScoredWowPlayer = System.List(WrapperHelpers.ScoredWowPlayer)
end)
System.namespace("Wrapper.Helpers", function (namespace)
  namespace.class("SmartTargetPVP", function (namespace)
    local Pulse, GetBestUnit, __ctor__
    __ctor__ = function (this)
      this.Units = ListScoredWowPlayer()
    end
    Pulse = function (this)
      if GetTime() - this.LastUpdateTime < 5 then
        return
      end

      this.LastUpdateTime = GetTime()

      this.Units:Clear()

      local AllValid = (Linq.Where(WrapperWoW.ObjectManager.GetAllPlayers(60), function (p)
        return not p.Dead and p.GUID ~= WrapperWoW.ObjectManager.getInstance().Player.GUID and p.Reaction < 4
      end))

      for _, player in System.each(AllValid) do
        local score = 1000 - System.ToSingle(WrapperWoW.Vector3.Distance(player.Position, WrapperWoW.ObjectManager.getInstance().Player.Position))
        score = score + (System.div((player.HealthMax - player.Health), 5))

        if __LB__.UnitTagHandler(UnitPvpClassification, player.GUID) ~= -1 --[[PVPClassification.None]] then
          score = score + 100
        end

        local target =  __LB__.UnitTarget(player.GUID)
        if target ~= nil then
          if target == WrapperWoW.ObjectManager.getInstance().Player.GUID and __LB__.UnitTagHandler(UnitAffectingCombat, target) then
            score = score + 152
          end
        end

        local default = WrapperHelpers.ScoredWowPlayer()
        default.Player = player
        default.Score = score
        this.Units:Add(default)
      end
    end
    GetBestUnit = function (this)
      local default
      if Linq.Count(this.Units) > 0 then
        default = Linq.FirstOrDefault(Linq.OrderByDescending(this.Units, function (x)
          return x.Score
        end, nil, System.Single)).Player
      else
        default = nil
      end
      return default
    end
    return {
      LastUpdateTime = 0,
      Pulse = Pulse,
      GetBestUnit = GetBestUnit,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local WrapperAPI
local WrapperNativeBehaviors
local BehaviorStateMachine
local ArrayBroBotBehavior
System.import(function (out)
  WrapperAPI = Wrapper.API
  WrapperNativeBehaviors = Wrapper.NativeBehaviors
  BehaviorStateMachine = Wrapper.NativeBehaviors.BehaviorStateMachine
  ArrayBroBotBehavior = System.Array(WrapperAPI.BroBotBehavior)
end)
System.namespace("Wrapper.NativeBehaviors", function (namespace)
  namespace.class("NativeGrind", function (namespace)
    local Run, Exit, class, __ctor__
    __ctor__ = function (this)
      this.children = ArrayBroBotBehavior:new(0)
      this.PersistentData = WrapperAPI.BehaviorPersistentData()
      this.LastRun = GetTime()
      this.name = "NativeGrind"
      this.author = "Fusspawn"
      this.showInGUI = true
      this.canHaveChildren = false

      this.skip_default_logic = true
      --c# has no default logic
      this.skip_spell_avoidance = true
      --not even sure this exists now?!
      this.children = ArrayBroBotBehavior:new(0)
      this.PersistentData = WrapperAPI.BehaviorPersistentData()
      this.PersistentData.enabled = true
      this.PersistentData.minfood = 0
      this.PersistentData.minfoodbuy = 0
      this.PersistentData.minwater = 0
      this.PersistentData.minwaterbuy = 0
      class.StateMachine = BehaviorStateMachine.StateMachine()
      class.StateMachine.States:Push(WrapperNativeBehaviors.NativeGrindBaseState())
    end
    Run = function (this)
      if GetTime() - this.LastRun > 0.5 then
        this.LastRun = GetTime()
        --ObjectManager.Instance.Pulse();
        class.StateMachine:Run()
      end
    end
    Exit = function (this)
      return false
    end
    class = {
      name = "NativeGrind",
      author = "Fusspawn",
      showInGUI = true,
      canHaveChildren = false,
      death_count = 0,
      kill_count = 0,
      skip_default_logic = true,
      skip_spell_avoidance = true,
      Run = Run,
      Exit = Exit,
      __ctor__ = __ctor__
    }
    return class
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local ArrayString = System.Array(System.String)
local WrapperHelpers
local WrapperNativeBehaviors
local NativeGrindSmartObjective
local WrapperNativeGrindTasks
local WrapperWoW
local ListSmartObjectiveTask
System.import(function (out)
  WrapperHelpers = Wrapper.Helpers
  WrapperNativeBehaviors = Wrapper.NativeBehaviors
  NativeGrindSmartObjective = Wrapper.NativeBehaviors.NativeGrindSmartObjective
  WrapperNativeGrindTasks = Wrapper.NativeBehaviors.NativeGrindTasks
  WrapperWoW = Wrapper.WoW
  ListSmartObjectiveTask = System.List(NativeGrindSmartObjective.SmartObjectiveTask)
end)
System.namespace("Wrapper.NativeBehaviors", function (namespace)
  namespace.class("NativeGrindBaseState", function (namespace)
    local Complete, Tick, __ctor__
    __ctor__ = function (this)
      this.SmartObjective = WrapperNativeBehaviors.NativeGrindSmartObjective()
    end
    Complete = function (this)
      return false
      --Base Grind. Should Never Complete. Stack Should Never Go Empty!
    end
    Tick = function (this)
      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") and (System.ObjectGetType(WrapperNativeBehaviors.NativeGrind.StateMachine.States:Peek()):getName() ~= System.typeof(WrapperNativeGrindTasks.NativeGrindCorpseRunTask):getName()) then
        WrapperNativeBehaviors.NativeGrind.StateMachine.States:Push(WrapperNativeGrindTasks.NativeGrindCorpseRunTask())
        return
      end


      this.SmartObjective:Update()
      local NextObjective = this.SmartObjective:GetNextTask()

      if NextObjective ~= nil then
        repeat
          local default = NextObjective.TaskType
          if default == 1 --[[SmartObjectiveTaskType.Gather]] then
            WrapperNativeBehaviors.NativeGrind.StateMachine.States:Push(WrapperNativeGrindTasks.NativeGrindGatherTask(NextObjective))
            break
          elseif default == 2 --[[SmartObjectiveTaskType.Loot]] then
            WrapperNativeBehaviors.NativeGrind.StateMachine.States:Push(WrapperNativeGrindTasks.NativeGrindLootTask(NextObjective))
            break
          elseif default == 0 --[[SmartObjectiveTaskType.Kill]] then
            WrapperNativeBehaviors.NativeGrind.StateMachine.States:Push(WrapperNativeGrindTasks.NativeGrindKillTask(NextObjective))
            break
          end
        until 1
      else
        WrapperNativeBehaviors.NativeGrind.StateMachine.States:Push(WrapperNativeGrindTasks.NativeGrindSearchForNode(this.SmartObjective))
      end

      System.base(this).Tick(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState
        }
      end,
      Complete = Complete,
      Tick = Tick,
      __ctor__ = __ctor__
    }
  end)


  namespace.class("NativeGrindSmartObjective", function (namespace)
    local Update, GetNextTask, class, __ctor__
    namespace.enum("SmartObjectiveTaskType", function ()
      return {
        Kill = 0,
        Gather = 1,
        Loot = 2,
        Repair = 3,
        Vendor = 4,
        GuildBank = 5,
        __metadata__ = function (out)
          return {
            fields = {
              { "Gather", 0xE, System.Int32 },
              { "GuildBank", 0xE, System.Int32 },
              { "Kill", 0xE, System.Int32 },
              { "Loot", 0xE, System.Int32 },
              { "Repair", 0xE, System.Int32 },
              { "Vendor", 0xE, System.Int32 }
            }
          }
        end
      }
    end)
    namespace.class("SmartObjectiveTask", function (namespace)
      return {
        TaskType = 0,
        Score = 0
      }
    end)
    __ctor__ = function (this)
      this.Tasks = ListSmartObjectiveTask()
      this.LastUpdateTime = GetTime()
    end
    Update = function (this)
      --ObjectManager.Instance.Pulse();

      local CurrentTime = GetTime()
      if CurrentTime - this.LastUpdateTime < 1 then
        return
      end

      System.Console.WriteLine("Updating Smart Objective")
      this.LastUpdateTime = CurrentTime
      this.Tasks:Clear()

      if not __LB__.UnitTagHandler(UnitAffectingCombat, "player") then
        if WrapperHelpers.LuaHelper.GetGlobalFrom_G_Namespace(ArrayString("BroBot", "UI", "CoreConfig", "PersistentData", "AllowGathering"), System.Boolean) then
          for _, GameObject in System.each(Linq.Where(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
            return x.Value:getIsHerb() or x.Value:getIsOre()
          end), function (x)
            return not (BroBot.Engine.BlackList.BannedGUIDs[x.Value.GUID] ~= nil) and WrapperWoW.ObjectManager.getInstance().Player:HasRequiredSkillToHarvest(x.Value)
          end)) do
            local score = 0
            score = 5
            score = score + (200 - WrapperWoW.Vector3.Distance(GameObject.Value.Position, WrapperWoW.ObjectManager.getInstance().Player.Position))

            if score > 0 then
              --Console.WriteLine("Found Gathering Objective");

              local default = class.SmartObjectiveTask()
              default.Score = score
              default.TargetUnitOrObject = GameObject.Value
              default.TaskType = 1 --[[SmartObjectiveTaskType.Gather]]
              this.Tasks:Add(default)
            else
              -- Console.WriteLine("Gathering Objective Was To Low Scored");
            end
          end
        end


        for _, Unit in System.each(Linq.Where(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
          return x.Value.ObjectType == 5 --[[EObjectType.Unit]] and x.Value.ObjectType ~= 6 --[[EObjectType.Player]]
        end), function (x)
          return not (BroBot.Engine.BlackList.BannedGUIDs[x.Value.GUID] ~= nil)
        end)) do
          local continue
          repeat
            if not __LB__.UnitTagHandler(UnitIsDeadOrGhost, Unit.Value.GUID) then
              continue = true
              break
            end

            if (System.as(Unit.Value, WrapperWoW.WoWUnit)).PlayerHasFought and ( __LB__.UnitIsLootable(Unit.Value.GUID) or ( __LB__.UnitHasFlag(Unit.Value.GUID, 67108864 --[[EUnitFlags.Skinnable]]) and WrapperHelpers.LuaHelper.GetGlobalFrom_G_Namespace(ArrayString("BroBot", "UI", "CoreConfig", "PersistentData", "AllowSkinning"), System.Boolean))) then
              local score = 0
              score = score + (200 - WrapperWoW.Vector3.Distance(Unit.Value.Position, WrapperWoW.ObjectManager.getInstance().Player.Position))

              if score > 0 then
                --Console.WriteLine("Found LootOrSkin Objective");

                local default = class.SmartObjectiveTask()
                default.Score = score
                default.TargetUnitOrObject = Unit.Value
                default.TaskType = 2 --[[SmartObjectiveTaskType.Loot]]
                this.Tasks:Add(default)
              else
                -- Console.WriteLine("Potential LootOrSkin Objective was to low scored");
              end
            end
            continue = true
          until 1
          if not continue then
            break
          end
        end
      end

      for _, Unit in System.each(Linq.Where(Linq.Where(WrapperWoW.ObjectManager.getInstance().AllObjects, function (x)
        return x.Value.ObjectType == 5 --[[EObjectType.Unit]] and x.Value.ObjectType ~= 6 --[[EObjectType.Player]]
      end), function (x)
        return not (BroBot.Engine.BlackList.BannedGUIDs[x.Value.GUID] ~= nil)
      end)) do
        local continue
        repeat
          local _Unit = System.as(Unit.Value, WrapperWoW.WoWUnit)
          if __LB__.UnitTagHandler(UnitIsDeadOrGhost, Unit.Value.GUID) or _Unit.Reaction >= 4 then
            continue = true
            break
          end

          if __LB__.UnitTagHandler(UnitIsTrivial, Unit.Value.GUID) or __LB__.UnitTagHandler(UnitCreatureType, Unit.Value.GUID) == "Critter" then
            continue = true
            break
          end

          local score = 0
          score = score + (200 - WrapperWoW.Vector3.Distance(Unit.Value.Position, WrapperWoW.ObjectManager.getInstance().Player.Position))
          score = score + ((8 - _Unit.Reaction) * 10)

          if score > 0 then
            --Console.WriteLine("Found Combat Objective");

            local default = class.SmartObjectiveTask()
            default.Score = score
            default.TargetUnitOrObject = Unit.Value
            default.TaskType = 0 --[[SmartObjectiveTaskType.Kill]]
            this.Tasks:Add(default)
          end
          continue = true
        until 1
        if not continue then
          break
        end
      end
    end
    GetNextTask = function (this)
      local default
      if #this.Tasks > 0 then
        default = this.Tasks:get(0)
      else
        default = nil
      end
      return default
    end
    class = {
      Update = Update,
      GetNextTask = GetNextTask,
      __ctor__ = __ctor__
    }
    return class
  end)
end)

end
do
local System = System
System.namespace("Wrapper.UI", function (namespace)
  namespace.class("NativeErrorLoggerUI", function (namespace)
    local instance, getInstance, AddErrorMessage, class
    namespace.class("ErrorMessageData", function (namespace)
      return {
        RecordedAt = 0
      }
    end)
    getInstance = function ()
      return instance
    end
    AddErrorMessage = function (this, Message, Stack)
      local default = class.ErrorMessageData()
      default.Message = Message
      default.Stack = Stack
      default.RecordedAt = GetTime()
      this.ErrorMessages:Add(default)
    end
    class = {
      getInstance = getInstance,
      AddErrorMessage = AddErrorMessage
    }
    return class
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local WrapperAPI
local WrapperDatabase
local WrapperWoW
System.import(function (out)
  WrapperAPI = Wrapper.API
  WrapperDatabase = Wrapper.Database
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.WoW", function (namespace)
  namespace.class("WoWGameObject", function (namespace)
    local getIsHerb, getIsOre, Update, __ctor__
    __ctor__ = function (this, _GUID)
      this.Position = System.default(WrapperWoW.Vector3)
      this.GUID = _GUID
      this.Name = __LB__.ObjectName(this.GUID)
      this.ObjectType = __LB__.ObjectType(this.GUID)
      this.ObjectId =  __LB__.ObjectId(this.GUID)

      this:Update()
    end
    getIsHerb = function (this)
      if this.WasHerb == nil then
        this.WasHerb = Linq.Any(WrapperDatabase.GatherableTypes.HerbNames, function (x)
          return x == this.Name
        end)
      end

      return System.Nullable.Value(this.WasHerb)
    end
    getIsOre = function (this)
      if this.WasOre == nil then
        this.WasOre = Linq.Any(WrapperDatabase.GatherableTypes.OreNames, function (x)
          return x == this.Name
        end)
      end

      return System.Nullable.Value(this.WasOre)
    end
    Update = function (this)
      this.Position = WrapperAPI.LuaBox.getInstance():ObjectPositionVector3(this.GUID)
    end
    return {
      ObjectType = 0,
      ObjectId = 0,
      getIsHerb = getIsHerb,
      getIsOre = getIsOre,
      Update = Update,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.WoW", function (namespace)
  namespace.class("LocalPlayer", function (namespace)
    local Update, HasRequiredSkillToHarvest, HasProfession, __ctor__
    __ctor__ = function (this)
      System.base(this).__ctor__(this, "player")
    end
    Update = function (this)
      System.base(this).Update(this)
    end
    HasRequiredSkillToHarvest = function (this, Object)
      local IsOre = Object:getIsOre()
      local IsHerb = Object:getIsHerb()

      if IsOre then
        local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
        if prof1 then
            local name = select(11, GetProfessionInfo(prof1))
            local senderarg = { (" "):split(name) }
            if senderarg[2] == "Mining" then
                return true
            else
            local name = select(11, GetProfessionInfo(prof2))
                local senderarg = { (" "):split(name) }
                return senderarg[2] == "Mining"
            end
        end
      end


      if IsHerb then
        local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
        if prof1 then
            local name = select(11, GetProfessionInfo(prof1))
            local senderarg = { (" "):split(name) }
            if senderarg[2] == "Herbalism" then
                return true
            else
            local name = select(11, GetProfessionInfo(prof2))
                local senderarg = { (" "):split(name) }
                return senderarg[2] == "Herbalism"
            end
        end
      end

      return false
    end
    HasProfession = function (this, Name)
      local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
      if prof1 then
          local name = select(11, GetProfessionInfo(prof1))
          local senderarg = { (" "):split(name) }
          if senderarg[2] == Name then
              return true
          else
          local name = select(11, GetProfessionInfo(prof2))
              local senderarg = { (" "):split(name) }
              return senderarg[2] == Name
          end
      end

      return false
    end
    return {
      base = function (out)
        return {
          out.Wrapper.WoW.WoWPlayer
        }
      end,
      Update = Update,
      HasRequiredSkillToHarvest = HasRequiredSkillToHarvest,
      HasProfession = HasProfession,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local ListString = System.List(System.String)
local WrapperWoW
local ListWoWGameObject
local DictStringWoWGameObject
System.import(function (out)
  WrapperWoW = Wrapper.WoW
  ListWoWGameObject = System.List(WrapperWoW.WoWGameObject)
  DictStringWoWGameObject = System.Dictionary(System.String, WrapperWoW.WoWGameObject)
end)
System.namespace("Wrapper.WoW", function (namespace)
  namespace.class("ObjectManager", function (namespace)
    local _instance, getInstance, Pulse, CreateWowObject, GetAllPlayers, class, __ctor__
    __ctor__ = function (this)
      this.AllObjects = DictStringWoWGameObject()
      this.Pendings = ListWoWGameObject()
    end
    getInstance = function ()
      if _instance == nil then
        _instance = class()
        _instance.Player = WrapperWoW.LocalPlayer()
      end

      return _instance
    end
    Pulse = function (this)
      System.try(function ()
        this.Player:Update()

        for _, GUID in System.each(__LB__.GetObjects(class.ObjectManagerScanRange)) do
          if not this.AllObjects:ContainsKey(GUID) and __LB__.ObjectName(GUID) ~= "Unknown" then
            this.AllObjects:set(GUID, CreateWowObject(this, GUID))
            repeat
              local default = this.AllObjects:get(GUID).ObjectType
              if default == 5 --[[EObjectType.Unit]] then
                if this.OnNewUnit ~= nil then
                  this.OnNewUnit(System.as(this.AllObjects:get(GUID), WrapperWoW.WoWUnit))
                end
                break
              elseif default == 8 --[[EObjectType.GameObject]] then
                if this.OnNewGameObject ~= nil then
                  this.OnNewGameObject(this.AllObjects:get(GUID))
                end
                break
              end
            until 1
          end
        end

        local RemovalList = ListString()
        for _, kvp in System.each(this.AllObjects) do
          if not  __LB__.ObjectExists(kvp.Key) then
            RemovalList:Add(kvp.Key)
          else
            kvp.Value:Update()
          end
        end

        RemovalList:ForEach(function (item)
          this.AllObjects:RemoveKey(item)
        end)
      end, function (default)
        local E = default
        System.Console.WriteLine("OM Error: " .. System.toString(E:getMessage()) .. "StackTrace: " .. System.toString(debugstack()))
      end)
    end
    CreateWowObject = function (this, GUID)
      repeat
        local default = __LB__.ObjectType(GUID)
        if default == 6 --[[EObjectType.Player]] then
          return WrapperWoW.WoWPlayer(GUID)
        elseif default == 5 --[[EObjectType.Unit]] then
          return WrapperWoW.WoWUnit(GUID)
        else
          return WrapperWoW.WoWGameObject(GUID)
        end
      until 1
    end
    GetAllPlayers = function (Yards)
      return Linq.Select(Linq.Where(getInstance().AllObjects:getValues(), function (x)
        return x.ObjectType == 6 --[[EObjectType.Player]] and WrapperWoW.Vector3.Distance(x.Position, getInstance().Player.Position) <= Yards
      end), function (x)
        return System.as(x, WrapperWoW.WoWPlayer)
      end, WrapperWoW.WoWPlayer)
    end
    class = {
      getInstance = getInstance,
      ObjectManagerScanRange = 500,
      Pulse = Pulse,
      GetAllPlayers = GetAllPlayers,
      __ctor__ = __ctor__
    }
    return class
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.WoW", function (namespace)
  namespace.class("WoWPlayer", function (namespace)
    local Update, __ctor__
    __ctor__ = function (this, _GUID)
      WrapperWoW.WoWUnit.__ctor__(this, _GUID)
    end
    Update = function (this)
      WrapperWoW.WoWUnit.Update(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.WoW.WoWUnit
        }
      end,
      Update = Update,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.WoW", function (namespace)
  namespace.class("WoWUnit", function (namespace)
    local getFriend, getHostile, getNeutral, getIsCasting, getIsChanneling, Update, Target, __ctor__
    __ctor__ = function (this, _GUID)
      WrapperWoW.WoWGameObject.__ctor__(this, _GUID)
    end
    getFriend = function (this)
      return this.Reaction > 4
    end
    getHostile = function (this)
      return this.Reaction < 4
    end
    getNeutral = function (this)
      return this.Reaction == 4
    end
    getIsCasting = function (this)
      local CastID
      local TargetGUID
      local TimeLeft
      local NotInterruptable

      local _
      _, CastID, TargetGUID, TimeLeft, NotInterruptable =  __LB__.UnitCastingInfo(this.GUID)
      return not System.String.IsNullOrEmpty(CastID)
    end
    getIsChanneling = function (this)
      local CastID
      local TargetGUID
      local TimeLeft
      local NotInterruptable

      local _
      _, CastID, TargetGUID, TimeLeft, NotInterruptable =  __LB__.UnitChannelInfo(this.GUID)
      return not System.String.IsNullOrEmpty(CastID)
    end
    Update = function (this)
      this.Health = __LB__.UnitTagHandler(UnitHealth, this.GUID)
      this.HealthMax = __LB__.UnitTagHandler(UnitHealthMax, this.GUID)
      this.Reaction = __LB__.UnitTagHandler(UnitReaction, "player", this.GUID)
      this.Dead = __LB__.UnitTagHandler(UnitIsDeadOrGhost, this.GUID)
      this.TargetGUID =  __LB__.UnitTarget(this.GUID)

      if this.Name == "Unknown" then
        this.Name = __LB__.ObjectName(this.GUID)
      end



      if WrapperWoW.ObjectManager.getInstance().Player ~= nil and WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, this.Position:__clone__()) < 50 then
        this.LineOfSight = not  (__LB__.Raycast(this.Position.X, this.Position.Y, this.Position.Z + 1.5, WrapperWoW.ObjectManager.getInstance().Player.Position.X, WrapperWoW.ObjectManager.getInstance().Player.Position.Y, WrapperWoW.ObjectManager.getInstance().Player.Position.Z + 1.5, 0x100010) ~= nil) and not  (__LB__.Raycast(this.Position.X, this.Position.Y, this.Position.Z + 2, WrapperWoW.ObjectManager.getInstance().Player.Position.X, WrapperWoW.ObjectManager.getInstance().Player.Position.Y, WrapperWoW.ObjectManager.getInstance().Player.Position.Z + 2, 0x100010) ~= nil)
      else
        this.LineOfSight = false
      end

      WrapperWoW.WoWGameObject.Update(this)
    end
    Target = function (this)
      __LB__.UnitTagHandler(TargetUnit, this.GUID)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.WoW.WoWGameObject
        }
      end,
      Health = 0,
      HealthMax = 0,
      Level = 0,
      Reaction = 0,
      Dead = false,
      LineOfSight = false,
      PlayerHasFought = false,
      getFriend = getFriend,
      getHostile = getHostile,
      getNeutral = getNeutral,
      getIsCasting = getIsCasting,
      getIsChanneling = getIsChanneling,
      Update = Update,
      Target = Target,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.WoW", function (namespace)
  namespace.struct("Vector3", function (namespace)
    local zero, one, unitX, unitY, unitZ, up, down, right, 
    left, forward, backward, getZero, getOne, getUnitX, getUnitY, getUnitZ, 
    getUp, getDown, getRight, getLeft, getForward, getBackward, Add, Add1, 
    Floor, Cross, Cross1, Distance, Distance1, DistanceSquared, DistanceSquared1, Divide, 
    Divide1, Divide2, Divide3, Dot, Dot1, EqualsObj, Equals, GetHashCode, 
    Length, LengthSquared, Multiply, Multiply1, Multiply2, Multiply3, Negate, Negate1, 
    Normalize, Normalize1, Normalize2, Reflect, Reflect1, Subtract, Subtract1, ToString, 
    op_Equality, op_Inequality, op_Addition, op_UnaryNegation, op_Subtraction, op_Multiply, op_Multiply1, op_Multiply2, 
    op_Division, op_Division1, class, static, __ctor1__, __ctor2__
    static = function (this)
      zero = class(0, 0, 0)
      one = class(1, 1, 1)
      unitX = class(1, 0, 0)
      unitY = class(0, 1, 0)
      unitZ = class(0, 0, 1)
      up = class(0, 1, 0)
      down = class(0, - 1, 0)
      right = class(1, 0, 0)
      left = class(- 1, 0, 0)
      forward = class(0, 0, - 1)
      backward = class(0, 0, 1)
    end
    __ctor1__ = function (this, x, y, z)
      if x == nil then
        return
      end
      this.X = x
      this.Y = y
      this.Z = z
    end
    __ctor2__ = function (this, value)
      this.X = value
      this.Y = value
      this.Z = value
    end
    getZero = function ()
      return zero:__clone__()
    end
    getOne = function ()
      return one:__clone__()
    end
    getUnitX = function ()
      return unitX:__clone__()
    end
    getUnitY = function ()
      return unitY:__clone__()
    end
    getUnitZ = function ()
      return unitZ:__clone__()
    end
    getUp = function ()
      return up:__clone__()
    end
    getDown = function ()
      return down:__clone__()
    end
    getRight = function ()
      return right:__clone__()
    end
    getLeft = function ()
      return left:__clone__()
    end
    getForward = function ()
      return forward:__clone__()
    end
    getBackward = function ()
      return backward:__clone__()
    end
    Add = function (value1, value2)
      value1.X = value1.X + value2.X
      value1.Y = value1.Y + value2.Y
      value1.Z = value1.Z + value2.Z
      return value1:__clone__()
    end
    Add1 = function (value1, value2, result)
      result.X = value1.X + value2.X
      result.Y = value1.Y + value2.Y
      result.Z = value1.Z + value2.Z
      return value1, value2, result
    end
    Floor = function (Vector3)
      return class(math.Floor(Vector3.X), math.Floor(Vector3.Y), math.Floor(Vector3.Z))
    end
    Cross = function (vector1, vector2)
      vector1, vector2, vector1 = Cross1(vector1, vector2)
      return vector1:__clone__()
    end
    Cross1 = function (vector1, vector2, result)
      result = class(vector1.Y * vector2.Z - vector2.Y * vector1.Z, - (vector1.X * vector2.Z - vector2.X * vector1.Z), vector1.X * vector2.Y - vector2.X * vector1.Y)
      return vector1, vector2, result
    end
    Distance = function (vector1, vector2)
      local result
      vector1, vector2, result = DistanceSquared1(vector1, vector2)
      return math.Sqrt(result)
    end
    Distance1 = function (value1, value2, result)
      value1, value2, result = DistanceSquared1(value1, value2)
      result = math.Sqrt(result)
      return value1, value2, result
    end
    DistanceSquared = function (value1, value2)
      local result
      value1, value2, result = DistanceSquared1(value1, value2)
      return result
    end
    DistanceSquared1 = function (value1, value2, result)
      result = (value1.X - value2.X) * (value1.X - value2.X) + (value1.Y - value2.Y) * (value1.Y - value2.Y) + (value1.Z - value2.Z) * (value1.Z - value2.Z)
      return value1, value2, result
    end
    Divide = function (value1, value2)
      value1.X = value1.X / value2.X
      value1.Y = value1.Y / value2.Y
      value1.Z = value1.Z / value2.Z
      return value1:__clone__()
    end
    Divide1 = function (value1, value2)
      local factor = 1 / value2
      value1.X = value1.X * factor
      value1.Y = value1.Y * factor
      value1.Z = value1.Z * factor
      return value1:__clone__()
    end
    Divide2 = function (value1, divisor, result)
      local factor = 1 / divisor
      result.X = value1.X * factor
      result.Y = value1.Y * factor
      result.Z = value1.Z * factor
      return value1, result
    end
    Divide3 = function (value1, value2, result)
      result.X = value1.X / value2.X
      result.Y = value1.Y / value2.Y
      result.Z = value1.Z / value2.Z
      return value1, value2, result
    end
    Dot = function (vector1, vector2)
      return vector1.X * vector2.X + vector1.Y * vector2.Y + vector1.Z * vector2.Z
    end
    Dot1 = function (vector1, vector2, result)
      result = vector1.X * vector2.X + vector1.Y * vector2.Y + vector1.Z * vector2.Z
      return vector1, vector2, result
    end
    EqualsObj = function (this, obj)
      local default
      if (System.is(obj, class)) then
        default = op_Equality(this, System.cast(class, obj))
      else
        default = false
      end
      return default
    end
    Equals = function (this, other)
      return op_Equality(this, other)
    end
    GetHashCode = function (this)
      return System.ToInt32(this.X + this.Y + this.Z)
    end
    Length = function (this)
      local result
      this, zero, result = DistanceSquared1(this, zero)
      return math.Sqrt(result)
    end
    LengthSquared = function (this)
      local result
      this, zero, result = DistanceSquared1(this, zero)
      return result
    end
    Multiply = function (value1, value2)
      value1.X = value1.X * value2.X
      value1.Y = value1.Y * value2.Y
      value1.Z = value1.Z * value2.Z
      return value1:__clone__()
    end
    Multiply1 = function (value1, scaleFactor)
      value1.X = value1.X * scaleFactor
      value1.Y = value1.Y * scaleFactor
      value1.Z = value1.Z * scaleFactor
      return value1:__clone__()
    end
    Multiply2 = function (value1, scaleFactor, result)
      result.X = value1.X * scaleFactor
      result.Y = value1.Y * scaleFactor
      result.Z = value1.Z * scaleFactor
      return value1, result
    end
    Multiply3 = function (value1, value2, result)
      result.X = value1.X * value2.X
      result.Y = value1.Y * value2.Y
      result.Z = value1.Z * value2.Z
      return value1, value2, result
    end
    Negate = function (value)
      value = class(- value.X, - value.Y, - value.Z)
      return value:__clone__()
    end
    Negate1 = function (value, result)
      result = class(- value.X, - value.Y, - value.Z)
      return value, result
    end
    Normalize = function (this)
      this, this = Normalize2(this)
    end
    Normalize1 = function (vector)
      vector, vector = Normalize2(vector)
      return vector:__clone__()
    end
    Normalize2 = function (value, result)
      local factor
      value, zero, factor = Distance1(value, zero)
      factor = 1 / factor
      result.X = value.X * factor
      result.Y = value.Y * factor
      result.Z = value.Z * factor
      return value, result
    end
    Reflect = function (vector, normal)
      -- I is the original array
      -- N is the normal of the incident plane
      -- R = I - (2 * N * ( DotProduct[ I,N] ))
      local reflectedVector = System.default(class)
      -- inline the dotProduct here instead of calling method
      local dotProduct = ((vector.X * normal.X) + (vector.Y * normal.Y)) + (vector.Z * normal.Z)
      reflectedVector.X = vector.X - (2.0 * normal.X) * dotProduct
      reflectedVector.Y = vector.Y - (2.0 * normal.Y) * dotProduct
      reflectedVector.Z = vector.Z - (2.0 * normal.Z) * dotProduct

      return reflectedVector:__clone__()
    end
    Reflect1 = function (vector, normal, result)
      -- I is the original array
      -- N is the normal of the incident plane
      -- R = I - (2 * N * ( DotProduct[ I,N] ))

      -- inline the dotProduct here instead of calling method
      local dotProduct = ((vector.X * normal.X) + (vector.Y * normal.Y)) + (vector.Z * normal.Z)
      result.X = vector.X - (2.0 * normal.X) * dotProduct
      result.Y = vector.Y - (2.0 * normal.Y) * dotProduct
      result.Z = vector.Z - (2.0 * normal.Z) * dotProduct
      return vector, normal, result
    end
    Subtract = function (value1, value2)
      value1.X = value1.X - value2.X
      value1.Y = value1.Y - value2.Y
      value1.Z = value1.Z - value2.Z
      return value1:__clone__()
    end
    Subtract1 = function (value1, value2, result)
      result.X = value1.X - value2.X
      result.Y = value1.Y - value2.Y
      result.Z = value1.Z - value2.Z
      return value1, value2, result
    end
    ToString = function (this)
      local sb = System.StringBuilder()
      sb:Append("{X:")
      sb:Append(this.X)
      sb:Append(" Y:")
      sb:Append(this.Y)
      sb:Append(" Z:")
      sb:Append(this.Z)
      sb:Append(" Distance From Player: ")
      sb:Append(Distance(this, WrapperWoW.ObjectManager.getInstance().Player.Position))
      sb:Append("}")
      return sb:ToString()
    end
    -- <summary>
    -- Transforms a vector by a quaternion rotation.
    -- </summary>
    -- <param name="vec">The vector to transform.</param>
    -- <param name="quat">The quaternion to rotate the vector by.</param>
    -- <returns>The result of the operation.</returns>
    op_Equality = function (value1, value2)
      return value1.X == value2.X and value1.Y == value2.Y and value1.Z == value2.Z
    end
    op_Inequality = function (value1, value2)
      return not (op_Equality(value1, value2))
    end
    op_Addition = function (value1, value2)
      value1.X = value1.X + value2.X
      value1.Y = value1.Y + value2.Y
      value1.Z = value1.Z + value2.Z
      return value1:__clone__()
    end
    op_UnaryNegation = function (value)
      value = class(- value.X, - value.Y, - value.Z)
      return value:__clone__()
    end
    op_Subtraction = function (value1, value2)
      value1.X = value1.X - value2.X
      value1.Y = value1.Y - value2.Y
      value1.Z = value1.Z - value2.Z
      return value1:__clone__()
    end
    op_Multiply = function (value1, value2)
      value1.X = value1.X * value2.X
      value1.Y = value1.Y * value2.Y
      value1.Z = value1.Z * value2.Z
      return value1:__clone__()
    end
    op_Multiply1 = function (value, scaleFactor)
      value.X = value.X * scaleFactor
      value.Y = value.Y * scaleFactor
      value.Z = value.Z * scaleFactor
      return value:__clone__()
    end
    op_Multiply2 = function (scaleFactor, value)
      value.X = value.X * scaleFactor
      value.Y = value.Y * scaleFactor
      value.Z = value.Z * scaleFactor
      return value:__clone__()
    end
    op_Division = function (value1, value2)
      value1.X = value1.X / value2.X
      value1.Y = value1.Y / value2.Y
      value1.Z = value1.Z / value2.Z
      return value1:__clone__()
    end
    op_Division1 = function (value, divider)
      local factor = 1 / divider
      value.X = value.X * factor
      value.Y = value.Y * factor
      value.Z = value.Z * factor
      return value:__clone__()
    end
    class = {
      base = function (out)
        return {
          System.IEquatable_1(out.Wrapper.WoW.Vector3)
        }
      end,
      X = 0,
      Y = 0,
      Z = 0,
      getZero = getZero,
      getOne = getOne,
      getUnitX = getUnitX,
      getUnitY = getUnitY,
      getUnitZ = getUnitZ,
      getUp = getUp,
      getDown = getDown,
      getRight = getRight,
      getLeft = getLeft,
      getForward = getForward,
      getBackward = getBackward,
      Add = Add,
      Add1 = Add1,
      Floor = Floor,
      Cross = Cross,
      Cross1 = Cross1,
      Distance = Distance,
      Distance1 = Distance1,
      DistanceSquared = DistanceSquared,
      DistanceSquared1 = DistanceSquared1,
      Divide = Divide,
      Divide1 = Divide1,
      Divide2 = Divide2,
      Divide3 = Divide3,
      Dot = Dot,
      Dot1 = Dot1,
      EqualsObj = EqualsObj,
      Equals = Equals,
      GetHashCode = GetHashCode,
      Length = Length,
      LengthSquared = LengthSquared,
      Multiply = Multiply,
      Multiply1 = Multiply1,
      Multiply2 = Multiply2,
      Multiply3 = Multiply3,
      Negate = Negate,
      Negate1 = Negate1,
      Normalize = Normalize,
      Normalize1 = Normalize1,
      Normalize2 = Normalize2,
      Reflect = Reflect,
      Reflect1 = Reflect1,
      Subtract = Subtract,
      Subtract1 = Subtract1,
      ToString = ToString,
      op_Equality = op_Equality,
      op_Inequality = op_Inequality,
      op_Addition = op_Addition,
      op_UnaryNegation = op_UnaryNegation,
      op_Subtraction = op_Subtraction,
      op_Multiply = op_Multiply,
      op_Multiply1 = op_Multiply1,
      op_Multiply2 = op_Multiply2,
      op_Division = op_Division,
      op_Division1 = op_Division1,
      static = static,
      __ctor__ = {
        __ctor1__,
        __ctor2__
      }
    }
    return class
  end)
end)

end
do
local System = System
System.namespace("Wrapper.API", function (namespace)
  namespace.class("BroBotAPI", function (namespace)
    return {}
  end)
end)

end
do
local System = System
local WrapperAPI
local ArrayBroBotBehavior
System.import(function (out)
  WrapperAPI = Wrapper.API
  ArrayBroBotBehavior = System.Array(WrapperAPI.BroBotBehavior)
end)
System.namespace("Wrapper.API", function (namespace)
  namespace.interface("stub_class_please_ignore", function ()
    local Run, Exit
    Run = function (this)
    end
    Exit = function (this)
      return false
    end
    return {
      extern = {
        Run = Run,
        Exit = Exit
      }
    }
  end)

  namespace.class("BroBotBehavior", function (namespace)
    local Exit, Run, __ctor__
    __ctor__ = function (this)
      this.children = ArrayBroBotBehavior:new(0)
      this.PersistentData = WrapperAPI.BehaviorPersistentData()
      this.name = "BroBotBehavior"
      this.author = "Fusspawn"
      this.showInGUI = true
      this.canHaveChildren = false

      this.skip_default_logic = true
      --c# has no default logic
      this.skip_spell_avoidance = true
      --not even sure this exists now?!
      this.children = ArrayBroBotBehavior:new(0)
      this.PersistentData = WrapperAPI.BehaviorPersistentData()
      this.PersistentData.enabled = true
      this.PersistentData.minfood = 0
      this.PersistentData.minfoodbuy = 0

      this.PersistentData.minwater = 0
      this.PersistentData.minwaterbuy = 0
    end
    Exit = function (this)
      return false
    end
    Run = function (this)
      System.Console.WriteLine("Fucking Single Line Run Magics")
    end
    return {
      base = function (out)
        return {
          out.Wrapper.API.stub_class_please_ignore
        }
      end,
      name = "BroBotBehavior",
      author = "Fusspawn",
      showInGUI = true,
      canHaveChildren = false,
      death_count = 0,
      kill_count = 0,
      skip_default_logic = true,
      skip_spell_avoidance = true,
      Exit = Exit,
      Run = Run,
      __ctor__ = __ctor__
    }
  end)

  namespace.class("BehaviorPersistentData", function (namespace)
    return {
      enabled = false,
      minwater = 0,
      minfood = 0,
      minwaterbuy = 0,
      minfoodbuy = 0
    }
  end)
end)

end
do
local System = System
local WrapperAPI
System.import(function (out)
  WrapperAPI = Wrapper.API
end)
System.namespace("Wrapper.API", function (namespace)
  namespace.class("BroBotCC", function (namespace)
    local Rotation
    Rotation = function (this)
    end
    return {
      Class = "Unknown",
      Name = "Unknown",
      Rotation = Rotation
    }
  end)

  namespace.class("PersistentData", function (namespace)
    return {
      range = 5,
      Author = "CBot"
    }
  end)

  namespace.class("HunterCCTest", function (namespace)
    local Rotation, __ctor__
    __ctor__ = function (this)
      this.PersistentData = WrapperAPI.PersistentData()
      this.PersistentData.range = 5
      this.PersistentData.Author = "CBot"

      this.Class = "HUNTER"
      this.Name = "CHunter"
    end
    Rotation = function (this)
      System.Console.WriteLine("c#s in your rotation. ")
    end
    return {
      Class = "HUNTER",
      Name = "CHunter",
      Rotation = Rotation,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local BehaviorStateMachine
local StackStateMachineState
System.import(function (out)
  BehaviorStateMachine = Wrapper.NativeBehaviors.BehaviorStateMachine
  StackStateMachineState = System.Stack(BehaviorStateMachine.StateMachineState)
end)
System.namespace("Wrapper.NativeBehaviors.BehaviorStateMachine", function (namespace)
  namespace.class("StateMachine", function (namespace)
    local Run, __ctor__
    __ctor__ = function (this)
      this.States = StackStateMachineState()
    end
    Run = function (this)
      if #this.States > 0 then
        if this.States:Peek():Complete() then
          this.States:Pop()
          this.States:Peek():ResetMaxStateTime()
        end

        this.States:Peek():Tick()
      end
    end
    return {
      Run = Run,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
System.namespace("Wrapper.NativeBehaviors.BehaviorStateMachine", function (namespace)
  namespace.class("StateMachineState", function (namespace)
    local ResetMaxStateTime, IsOutOfTime, SetMaxStateTime, StringRepr, Complete, Tick
    ResetMaxStateTime = function (this)
      this.EntryTime = GetTime()
    end
    IsOutOfTime = function (this)
      if this.EntryTime == 0 then
        this.EntryTime = GetTime()
      end

      if not this.HasMaxStateTime then
        return false
      end

      --Console.WriteLine($"Out Of time Data: Current: {WoWAPI.GetTime()}   Entry: {EntryTime} Max: {MaxStateTime}");
      return GetTime() - this.EntryTime > this.MaxStateTime
    end
    SetMaxStateTime = function (this, Seconds)
      this.MaxStateTime = Seconds
      this.HasMaxStateTime = true
    end
    StringRepr = function (this)
      return "StateMachineState"
    end
    Complete = function (this)
      return true
    end
    Tick = function (this)
      if this.EntryTime == 0 then
        this.EntryTime = GetTime()
      end
    end
    return {
      EntryTime = 0,
      MaxStateTime = 0,
      HasMaxStateTime = false,
      ResetMaxStateTime = ResetMaxStateTime,
      IsOutOfTime = IsOutOfTime,
      SetMaxStateTime = SetMaxStateTime,
      StringRepr = StringRepr,
      Complete = Complete,
      Tick = Tick
    }
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.NativeBehaviors.NativeGrindTasks", function (namespace)
  namespace.class("NativeGrindCorpseRunTask", function (namespace)
    local Complete, Tick
    Complete = function (this)
      return not __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player")
    end
    Tick = function (this)
      if __LB__.UnitTagHandler(UnitIsDead, "player") and not __LB__.UnitTagHandler(UnitIsGhost, "player") then
        RepopMe()
        return
      end

      local CorpsePos = WrapperWoW.Vector3()
      CorpsePos.X, CorpsePos.Y, CorpsePos.Z =  __LB__.GetPlayerCorpsePosition()


      if WrapperWoW.Vector3.Distance(WrapperWoW.ObjectManager.getInstance().Player.Position, CorpsePos:__clone__()) > 28 then
        __LB__.Navigator.MoveTo(CorpsePos.X, CorpsePos.Y, CorpsePos.Z, 1, 1)
        return
      end

      __LB__.Navigator.Stop()

      RetrieveCorpse();

      System.base(this).Tick(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState
        }
      end,
      Complete = Complete,
      Tick = Tick
    }
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.NativeBehaviors.NativeGrindTasks", function (namespace)
  namespace.class("NativeGrindGatherTask", function (namespace)
    local Complete, Tick, __ctor__
    __ctor__ = function (this, Task)
      this.Task = Task
      this:SetMaxStateTime(120)
    end
    Complete = function (this)
      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") then
        return true
      end
      --[[
           Console.WriteLine("In Gather Complete");
           Console.WriteLine($"Object Exists: {LuaBox.Instance.ObjectExists(Task.TargetUnitOrObject.GUID)}");
           Console.WriteLine($"GatherAndNotCasting: {(HasGathered && !ObjectManager.Instance.Player.IsCasting && !ObjectManager.Instance.Player.IsChanneling)}");
           Console.WriteLine($"InCombat: {WoWAPI.UnitAffectingCombat("player")}");
           Console.WriteLine($"Out Of Time: {IsOutOfTime()}");
]]
      return (not  __LB__.ObjectExists(this.Task.TargetUnitOrObject.GUID) and WrapperWoW.Vector3.Distance(this.Task.TargetUnitOrObject.Position, WrapperWoW.ObjectManager.getInstance().Player.Position) < 300) or (this.HasGathered and not WrapperWoW.ObjectManager.getInstance().Player:getIsCasting() and not WrapperWoW.ObjectManager.getInstance().Player:getIsChanneling()) or __LB__.UnitTagHandler(UnitAffectingCombat, "player") or this:IsOutOfTime()
    end
    Tick = function (this)
      --BroBotAPI.BroBotDebugMessage("NativeGatherTask", "In Gather Tick");
      local Distance = WrapperWoW.Vector3.Distance(this.Task.TargetUnitOrObject.Position, WrapperWoW.ObjectManager.getInstance().Player.Position)


      if Distance > 5 then
        subtaskframe:SetText("[" .. "NativeGatherTask" .. "]" .. "Getting Closer: " .. Distance .. " TaskLocation: " .. this.Task.TargetUnitOrObject.Position:ToString() .. " Player: " .. WrapperWoW.ObjectManager.getInstance().Player.Position:ToString())
        __LB__.Navigator.MoveTo(this.Task.TargetUnitOrObject.Position.X, this.Task.TargetUnitOrObject.Position.Y, this.Task.TargetUnitOrObject.Position.Z, 1, 1)
        return
      end

      subtaskframe:SetText("[" .. "NativeGatherTask" .. "]" .. "Interacting")

      __LB__.Navigator.Stop()


      if WrapperWoW.ObjectManager.getInstance().Player:getIsCasting() or WrapperWoW.ObjectManager.getInstance().Player:getIsChanneling() then
        System.Console.WriteLine("Blacklisting Gather Node" .. "")
        BroBot.Engine.BlackList:RegisterUnitInstance(this.Task.TargetUnitOrObject.GUID, 120)
        this.HasGathered = true
      else
        local func = function (...) return __LB__.Unlock(__LB__.ObjectInteract, ...) end func(this.Task.TargetUnitOrObject.GUID)
      end

      this.HasGathered = true
      System.base(this).Tick(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState
        }
      end,
      HasGathered = false,
      Complete = Complete,
      Tick = Tick,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.NativeBehaviors.NativeGrindTasks", function (namespace)
  namespace.class("NativeGrindKillTask", function (namespace)
    local Complete, Tick, __ctor__
    __ctor__ = function (this, Task)
      this.Task = Task
      this:SetMaxStateTime(120)
    end
    Complete = function (this)
      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") then
        return true
      end
      return (not  __LB__.ObjectExists(this.Task.TargetUnitOrObject.GUID) or __LB__.UnitTagHandler(UnitIsDeadOrGhost, this.Task.TargetUnitOrObject.GUID) or this:IsOutOfTime())
    end
    Tick = function (this)
      System.Console.WriteLine("In Combat Task")

      local Distance = WrapperWoW.Vector3.Distance(this.Task.TargetUnitOrObject.Position, WrapperWoW.ObjectManager.getInstance().Player.Position)

      local CombatRange = GetPlayersRange()
      -- local xy = AngleTo("Target", "Player")
       --__LB__.SetPlayerAngles(xy)


      if Distance > CombatRange then
        subtaskframe:SetText("[" .. "NativeKillTask" .. "]" .. "Getting Closer: " .. Distance .. " TaskLocation: " .. this.Task.TargetUnitOrObject.Position:ToString() .. " Player: " .. WrapperWoW.ObjectManager.getInstance().Player.Position:ToString())
        __LB__.Navigator.MoveTo(this.Task.TargetUnitOrObject.Position.X, this.Task.TargetUnitOrObject.Position.Y, this.Task.TargetUnitOrObject.Position.Z, 1, 1)
        return
      else
        if IsMounted() then
           Dismount()
                        end
        __LB__.Navigator.Stop()
         __LB__.UnitTarget(this.Task.TargetUnitOrObject.GUID)
        StartAttack()
      end

      System.base(this).Tick(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState
        }
      end,
      Complete = Complete,
      Tick = Tick,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local WrapperWoW
System.import(function (out)
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.NativeBehaviors.NativeGrindTasks", function (namespace)
  namespace.class("NativeGrindLootTask", function (namespace)
    local Complete, Tick, __ctor__
    __ctor__ = function (this, Task)
      this.Task = Task
      this:SetMaxStateTime(120)
    end
    Complete = function (this)
      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") then
        return true
      end
      return (not  __LB__.ObjectExists(this.Task.TargetUnitOrObject.GUID) or this.HasLooted or __LB__.UnitTagHandler(UnitAffectingCombat, "player") or this:IsOutOfTime())
    end
    Tick = function (this)
      local Distance = WrapperWoW.Vector3.Distance(this.Task.TargetUnitOrObject.Position, WrapperWoW.ObjectManager.getInstance().Player.Position)

      local TaskUnit = System.as(this.Task.TargetUnitOrObject, WrapperWoW.WoWUnit)
      TaskUnit.PlayerHasFought = true

      if Distance > 5 then
        subtaskframe:SetText("[" .. "NativeKillTask" .. "]" .. "Getting Closer: " .. Distance .. " TaskLocation: " .. this.Task.TargetUnitOrObject.Position:ToString() .. " Player: " .. WrapperWoW.ObjectManager.getInstance().Player.Position:ToString())
        __LB__.Navigator.MoveTo(this.Task.TargetUnitOrObject.Position.X, this.Task.TargetUnitOrObject.Position.Y, this.Task.TargetUnitOrObject.Position.Z, 1, 1)
        return
      end



      __LB__.Navigator.Stop()
      local func = function (...) return __LB__.Unlock(__LB__.ObjectInteract, ...) end func(this.Task.TargetUnitOrObject.GUID)
      this.HasLooted = true

      C_Timer.After(3, function ()
        BroBot.Engine.BlackList:RegisterUnitInstance(this.Task.TargetUnitOrObject.GUID, 120)
      end)
      System.base(this).Tick(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState
        }
      end,
      HasLooted = false,
      Complete = Complete,
      Tick = Tick,
      __ctor__ = __ctor__
    }
  end)
end)

end
do
local System = System
local Linq = System.Linq.Enumerable
local ArrayString = System.Array(System.String)
local WrapperDatabase
local WrapperHelpers
local WrapperWoW
System.import(function (out)
  WrapperDatabase = Wrapper.Database
  WrapperHelpers = Wrapper.Helpers
  WrapperWoW = Wrapper.WoW
end)
System.namespace("Wrapper.NativeBehaviors.NativeGrindTasks", function (namespace)
  namespace.class("NativeGrindSearchForNode", function (namespace)
    local Complete, Tick, __ctor__
    __ctor__ = function (this, SmartObjective)
      this.ObjectiveScanner = SmartObjective
    end
    Complete = function (this)
      if __LB__.UnitTagHandler(UnitIsDeadOrGhost, "player") then
        return true
      end
      return this.ObjectiveScanner:GetNextTask() ~= nil or __LB__.UnitTagHandler(UnitAffectingCombat, "player")
    end
    Tick = function (this)
      this.ObjectiveScanner:Update()

      if this.TargetNode == nil then
        local AllowGather = WrapperHelpers.LuaHelper.GetGlobalFrom_G_Namespace(ArrayString("BroBot", "UI", "CoreConfig", "PersistentData", "AllowGathering"), System.Boolean)

        local Player = WrapperWoW.ObjectManager.getInstance().Player
        local PlayerPosition = Player.Position:__clone__()
        local KnowsHerbalism = Player:HasProfession("Herbalism")
        local KnowsMining = Player:HasProfession("Mining")
        local AllNodes = Linq.ToList((Linq.Where(WrapperDatabase.WoWDatabase.GetMapDatabase( __LB__.GetMapId()).Nodes, function (p)
          return ((p.NodeType == 2 --[[NodeType.Herb]] and KnowsHerbalism) or (p.NodeType == 1 --[[NodeType.Ore]] and KnowsMining)) and WrapperWoW.Vector3.Distance(WrapperWoW.Vector3(p.X, p.Y, p.Z), PlayerPosition:__clone__()) > 100
        end)))

        if #AllNodes > 0 then
          this.TargetNode = AllNodes:get(System.Random():Next(0, #AllNodes - 1))
          System.Console.WriteLine("Found new Destination: " .. this.TargetNode.X .. " / " .. this.TargetNode.Y .. " / " .. this.TargetNode.Z)
        else
          System.Console.WriteLine("Unable to find a valid node in the database? Has the map been scanned?!")
          return
        end
      end



      subtaskframe:SetText("[" .. "RandomNodePositionFinder" .. "]" .. "Moving To TargetNode")
      __LB__.Navigator.MoveTo(this.TargetNode.X, this.TargetNode.Y, this.TargetNode.Z, 1, 1)

      if WrapperWoW.Vector3.Distance(WrapperWoW.Vector3(this.TargetNode.X, this.TargetNode.Y, this.TargetNode.Z), WrapperWoW.ObjectManager.getInstance().Player.Position) < 10 then
        System.Console.WriteLine("Got to target node with nothing to do. Lets give this one up and grab another")
        this.TargetNode = nil
      end

      System.base(this).Tick(this)
    end
    return {
      base = function (out)
        return {
          out.Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState
        }
      end,
      Complete = Complete,
      Tick = Tick,
      __ctor__ = __ctor__
    }
  end)
end)

end
System.init({
  types = {
    "Wrapper.StdUI",
    "Wrapper.API.WoWFrame",
    "Wrapper.WoW.WoWGameObject",
    "Wrapper.BotBase",
    "Wrapper.StdUI.StdUiFrame",
    "Wrapper.WoW.WoWUnit",
    "Wrapper.API.stub_class_please_ignore",
    "Wrapper.API.LuaBox",
    "Wrapper.API.WoWAPI",
    "Wrapper.Database.LocationInfo",
    "Wrapper.DataLoggerBase",
    "Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachineState",
    "Wrapper.NativeBehaviors.NativeGrindSmartObjective",
    "Wrapper.StdUI.StdUiInputFrame",
    "Wrapper.UI.NativeErrorLoggerUI",
    "Wrapper.WoW.WoWPlayer",
    "Wrapper.API.BehaviorPersistentData",
    "Wrapper.API.BroBotAPI",
    "Wrapper.API.BroBotBehavior",
    "Wrapper.API.BroBotCC",
    "Wrapper.API.DataProviderBase",
    "Wrapper.API.HunterCCTest",
    "Wrapper.API.LibJson",
    "Wrapper.API.LibStub",
    "Wrapper.API.LuaBox.EClientTypes",
    "Wrapper.API.LuaBox.EGameObjectTypes",
    "Wrapper.API.LuaBox.ELockTypes",
    "Wrapper.API.LuaBox.EMovementFlags",
    "Wrapper.API.LuaBox.ENpcFlags",
    "Wrapper.API.LuaBox.EObjectType",
    "Wrapper.API.LuaBox.ERaycastFlags",
    "Wrapper.API.LuaBox.EUnitDynamicFlags",
    "Wrapper.API.LuaBox.EUnitFlags",
    "Wrapper.API.LuaBox.EUnitFlags2",
    "Wrapper.API.Navigator",
    "Wrapper.API.PersistentData",
    "Wrapper.API.UnitAura",
    "Wrapper.API.WoWAPI.PVPClassification",
    "Wrapper.API.WoWButton",
    "Wrapper.API.WoWTexture",
    "Wrapper.CameraFaceTarget",
    "Wrapper.Database.FactionID",
    "Wrapper.Database.GatherableTypes",
    "Wrapper.Database.MapDataEntry",
    "Wrapper.Database.NodeLocationInfo",
    "Wrapper.Database.NodeType",
    "Wrapper.Database.NPCLocationInfo",
    "Wrapper.Database.NPCNodeType",
    "Wrapper.Database.VendorLocationInfo",
    "Wrapper.Database.WoWDatabase",
    "Wrapper.DataLoggerBase.DataLoggerBaseUI",
    "Wrapper.Helpers.FileLogger",
    "Wrapper.Helpers.LuaHelper",
    "Wrapper.Helpers.ScoredWowPlayer",
    "Wrapper.Helpers.SmartMovePVP",
    "Wrapper.Helpers.SmartTargetPVP",
    "Wrapper.NativeBehaviors.BehaviorStateMachine.StateMachine",
    "Wrapper.NativeBehaviors.NativeGrind",
    "Wrapper.NativeBehaviors.NativeGrindBaseState",
    "Wrapper.NativeBehaviors.NativeGrindSmartObjective.SmartObjectiveTask",
    "Wrapper.NativeBehaviors.NativeGrindSmartObjective.SmartObjectiveTaskType",
    "Wrapper.NativeBehaviors.NativeGrindTasks.NativeGrindCorpseRunTask",
    "Wrapper.NativeBehaviors.NativeGrindTasks.NativeGrindGatherTask",
    "Wrapper.NativeBehaviors.NativeGrindTasks.NativeGrindKillTask",
    "Wrapper.NativeBehaviors.NativeGrindTasks.NativeGrindLootTask",
    "Wrapper.NativeBehaviors.NativeGrindTasks.NativeGrindSearchForNode",
    "Wrapper.Program",
    "Wrapper.PVPBotBase",
    "Wrapper.StdUI.StdUiButton",
    "Wrapper.StdUI.StdUiCheckBox",
    "Wrapper.StdUI.StdUiLabel",
    "Wrapper.StdUI.StdUiNumericInputFrame",
    "Wrapper.UI.NativeErrorLoggerUI.ErrorMessageData",
    "Wrapper.WoW.LocalPlayer",
    "Wrapper.WoW.ObjectManager",
    "Wrapper.WoW.Vector3"
  }
})

Wrapper.Program.Main()

