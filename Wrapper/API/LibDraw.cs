using System;
using System.Collections.Generic;
using System.Text;

namespace Wrapper.API
{
    public class LibDraw
    {

        public class LibDrawColor
        {
            public double R;
            public double G;
            public double B;
            public double A;
            public string? Hex;
        }


        /// <summary>
        ///   @CSharpLua.Template = "lb.LibDraw.ClearCanvas()"
        /// </summary>
        public static extern void ClearCanvas();

        public static void Line(WoW.Vector3 Start, WoW.Vector3 Destination, float Size, LibDrawColor Color)
        {
             /*
              [[
                lb.LibDraw.Line({Start.X, Start.Y, Start.Z}, {Destination.X, Destination.Y, Destination.Z}, Size, Color);
              ]]
             */
        }

        public static void Circle(WoW.Vector3 Position, float Size, float Thickness, LibDrawColor Color)
        {
            /*
             [[
               lb.LibDraw.Circle({Position.X, Position.Y, Position.Z}, Size, Thickness, Color);
             ]]
            */
        }


        //function Text(this: void, text: string, position: Position, size: number, color?: IColor, font?: string): void;

        public static void Text(string Text, WoW.Vector3 Position, float Size, LibDrawColor? Color, string? font)
        {
            /*
             [[
               lb.LibDraw.Text(Text, {Position.X, Position.Y, Position.Z}, Size, Color, font);
             ]]
            */
        }
    }
}

