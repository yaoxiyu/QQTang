using Google.Protobuf;
using QQT.Room.V1;
using System;

namespace QQTang.Network.ClientNet.Room;

public sealed class RoomServerEnvelopeParser
{
    public ServerEnvelope Parse(byte[] payload)
    {
        if (payload == null || payload.Length == 0)
        {
            throw new RoomProtocolDecodeException("ROOM_PROTO_DECODE_FAILED", "Empty room server envelope payload.");
        }

        try
        {
            return ServerEnvelope.Parser.ParseFrom(payload);
        }
        catch (InvalidProtocolBufferException ex)
        {
            throw new RoomProtocolDecodeException("ROOM_PROTO_DECODE_FAILED", "Invalid room server envelope payload.", ex);
        }
    }
}

public sealed class RoomProtocolDecodeException : Exception
{
    public string ErrorCode { get; }

    public string UserMessage { get; }

    public RoomProtocolDecodeException(string errorCode, string userMessage)
        : base(userMessage)
    {
        ErrorCode = errorCode;
        UserMessage = userMessage;
    }

    public RoomProtocolDecodeException(string errorCode, string userMessage, Exception innerException)
        : base(userMessage, innerException)
    {
        ErrorCode = errorCode;
        UserMessage = userMessage;
    }
}
