using Godot;
using QQT.Room.V1;
using System;

namespace QQTang.Network.ClientNet.Room;

public sealed class RoomCanonicalMessageMapper
{
    private readonly RoomCanonicalMessageMapperCore _core = new();

    public Godot.Collections.Dictionary Map(ServerEnvelope envelope)
    {
        var plain = _core.Map(envelope);
        return RoomGodotInteropConverter.ToGodotDictionary(plain);
    }
}
