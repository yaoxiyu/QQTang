using Godot;
using System.Collections;
using System.Collections.Generic;

namespace QQTang.Network.ClientNet.Room;

internal static class RoomGodotInteropConverter
{
    public static Dictionary<string, object?> ToPlainDictionary(Godot.Collections.Dictionary source)
    {
        var result = new Dictionary<string, object?>();
        if (source == null)
        {
            return result;
        }
        foreach (var keyObj in source.Keys)
        {
            var key = keyObj.ToString() ?? string.Empty;
            result[key] = ToPlainObject(source[keyObj]);
        }
        return result;
    }

    public static Godot.Collections.Dictionary ToGodotDictionary(IDictionary<string, object?> source)
    {
        var result = new Godot.Collections.Dictionary();
        if (source == null)
        {
            return result;
        }
        foreach (var pair in source)
        {
            result[pair.Key] = ToGodotVariant(pair.Value);
        }
        return result;
    }

    private static object? ToPlainObject(object value)
    {
        if (value is Variant variant)
        {
            return variant.VariantType switch
            {
                Variant.Type.Nil => null,
                Variant.Type.Bool => variant.AsBool(),
                Variant.Type.Int => variant.AsInt64(),
                Variant.Type.Float => variant.AsDouble(),
                Variant.Type.String => variant.AsString(),
                Variant.Type.StringName => variant.AsStringName().ToString(),
                Variant.Type.Dictionary => ToPlainDictionary((Godot.Collections.Dictionary)variant),
                Variant.Type.Array => ToPlainList((Godot.Collections.Array)variant),
                _ => variant.ToString(),
            };
        }
        return value;
    }

    private static List<object?> ToPlainList(Godot.Collections.Array source)
    {
        var result = new List<object?>(source.Count);
        foreach (var item in source)
        {
            result.Add(ToPlainObject(item));
        }
        return result;
    }

    private static Variant ToGodotVariant(object? value)
    {
        if (value == null)
        {
            return default;
        }
        if (value is IDictionary<string, object?> dict)
        {
            return ToGodotDictionary(dict);
        }
        if (value is IEnumerable enumerable && value is not string)
        {
            var array = new Godot.Collections.Array();
            foreach (var item in enumerable)
            {
                array.Add(ToGodotVariant(item));
            }
            return array;
        }
        return value switch
        {
            bool v => v,
            int v => v,
            long v => v,
            float v => v,
            double v => v,
            string v => v,
            _ => value.ToString() ?? string.Empty,
        };
    }
}
