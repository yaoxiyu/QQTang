using System;

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
}
