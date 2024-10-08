-- Generated by CSharp.lua Compiler
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
      },
      __metadata__ = function (out)
        return {
          fields = {
            { "backward", 0x9, class },
            { "down", 0x9, class },
            { "forward", 0x9, class },
            { "left", 0x9, class },
            { "one", 0x9, class },
            { "right", 0x9, class },
            { "unitX", 0x9, class },
            { "unitY", 0x9, class },
            { "unitZ", 0x9, class },
            { "up", 0x9, class },
            { "X", 0x6, System.Double },
            { "Y", 0x6, System.Double },
            { "Z", 0x6, System.Double },
            { "zero", 0x9, class }
          },
          properties = {
            { "Backward", 0x20E, class, getBackward },
            { "Down", 0x20E, class, getDown },
            { "Forward", 0x20E, class, getForward },
            { "Left", 0x20E, class, getLeft },
            { "One", 0x20E, class, getOne },
            { "Right", 0x20E, class, getRight },
            { "UnitX", 0x20E, class, getUnitX },
            { "UnitY", 0x20E, class, getUnitY },
            { "UnitZ", 0x20E, class, getUnitZ },
            { "Up", 0x20E, class, getUp },
            { "Zero", 0x20E, class, getZero }
          },
          methods = {
            { ".ctor", 0x306, __ctor1__, System.Double, System.Double, System.Double },
            { ".ctor", 0x106, __ctor2__, System.Double },
            { "Add", 0x28E, Add, class, class, class },
            { "Add", 0x30E, Add1, class, class, class },
            { "Cross", 0x28E, Cross, class, class, class },
            { "Cross", 0x30E, Cross1, class, class, class },
            { "Distance", 0x28E, Distance, class, class, System.Double },
            { "Distance", 0x30E, Distance1, class, class, System.Double },
            { "DistanceSquared", 0x28E, DistanceSquared, class, class, System.Double },
            { "DistanceSquared", 0x30E, DistanceSquared1, class, class, System.Double },
            { "Divide", 0x28E, Divide, class, class, class },
            { "Divide", 0x28E, Divide1, class, System.Double, class },
            { "Divide", 0x30E, Divide2, class, System.Double, class },
            { "Divide", 0x30E, Divide3, class, class, class },
            { "Dot", 0x28E, Dot, class, class, System.Double },
            { "Dot", 0x30E, Dot1, class, class, System.Double },
            { "Equals", 0x186, Equals, class, System.Boolean },
            { "Equals", 0x186, EqualsObj, System.Object, System.Boolean },
            { "Floor", 0x18E, Floor, class, class },
            { "GetHashCode", 0x86, GetHashCode, System.Int32 },
            { "Length", 0x86, Length, System.Double },
            { "LengthSquared", 0x86, LengthSquared, System.Double },
            { "Multiply", 0x28E, Multiply, class, class, class },
            { "Multiply", 0x28E, Multiply1, class, System.Double, class },
            { "Multiply", 0x30E, Multiply2, class, System.Double, class },
            { "Multiply", 0x30E, Multiply3, class, class, class },
            { "Negate", 0x20E, Negate1, class, class },
            { "Negate", 0x18E, Negate, class, class },
            { "Normalize", 0x6, Normalize },
            { "Normalize", 0x18E, Normalize1, class, class },
            { "Normalize", 0x20E, Normalize2, class, class },
            { "Reflect", 0x28E, Reflect, class, class, class },
            { "Reflect", 0x30E, Reflect1, class, class, class },
            { "Subtract", 0x28E, Subtract, class, class, class },
            { "Subtract", 0x30E, Subtract1, class, class, class },
            { "ToString", 0x86, ToString, System.String }
          },
          class = { 0x6 }
        }
      end
    }
    return class
  end)
end)
