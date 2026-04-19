using Google.Protobuf;
using QQT.Room.V1;
using System;

namespace QQTang.Network.ClientNet.Room;

public sealed class RoomProtoCodec
{
    private readonly RoomServerEnvelopeParser _serverEnvelopeParser = new();

    public byte[] EncodeEnvelope(ClientEnvelope envelope)
    {
        if (envelope == null)
        {
            throw new ArgumentNullException(nameof(envelope));
        }
        return envelope.ToByteArray();
    }

    public ServerEnvelope DecodeServerEnvelope(byte[] frame)
    {
        return _serverEnvelopeParser.Parse(frame);
    }

    [Obsolete("Use EncodeEnvelope(ClientEnvelope)")]
    public byte[] EncodeEnvelope(byte[] payload)
    {
        throw new InvalidOperationException("Typed protobuf ClientEnvelope is required.");
    }

    [Obsolete("Use DecodeServerEnvelope(byte[])")]
    public byte[] DecodeEnvelope(byte[] frame)
    {
        throw new InvalidOperationException("Use DecodeServerEnvelope for typed protobuf decoding.");
    }
}
