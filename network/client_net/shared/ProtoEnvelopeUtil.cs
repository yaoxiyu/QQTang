using System;
using QQTang.Network.ClientNet.Room;

namespace QQTang.Network.ClientNet.Shared;

public static class ProtoEnvelopeUtil
{
    public static string NewRequestId()
    {
        return Guid.NewGuid().ToString("N");
    }

    public static long UnixTimeMs()
    {
        return DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    }

    public static long NextSequence(RoomClientSessionState state)
    {
        if (state == null)
        {
            throw new ArgumentNullException(nameof(state));
        }

        if (state.NextSequence <= 0)
        {
            state.NextSequence = 1;
        }

        var next = state.NextSequence;
        state.LastSequence = next;
        state.NextSequence = next + 1;
        return next;
    }
}
