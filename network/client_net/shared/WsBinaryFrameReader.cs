using System;

namespace QQTang.Network.ClientNet.Shared;

public static class WsBinaryFrameReader
{
    public static byte[] ToManagedBytes(byte[] packet)
    {
        if (packet == null || packet.Length == 0)
        {
            return Array.Empty<byte>();
        }
        return packet;
    }
}
