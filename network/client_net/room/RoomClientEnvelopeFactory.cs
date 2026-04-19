using Godot;
using QQT.Room.V1;
using System;

namespace QQTang.Network.ClientNet.Room;

public sealed class RoomClientEnvelopeFactory
{
    private readonly RoomClientEnvelopeFactoryCore _core = new();

    public ClientEnvelope BuildEnvelope(Godot.Collections.Dictionary message, RoomClientSessionState sessionState)
    {
        if (message == null)
        {
            throw new ArgumentNullException(nameof(message));
        }

        if (sessionState == null)
        {
            throw new ArgumentNullException(nameof(sessionState));
        }
        var plain = RoomGodotInteropConverter.ToPlainDictionary(message);
        return _core.BuildEnvelope(plain, sessionState);
    }
}
