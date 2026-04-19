namespace QQTang.Network.ClientNet.Room;

public sealed class RoomProtoCodec
{
    public byte[] EncodeEnvelope(byte[] payload)
    {
        return payload ?? [];
    }

    public byte[] DecodeEnvelope(byte[] frame)
    {
        return frame ?? [];
    }
}
