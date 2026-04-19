using Google.Protobuf;
using QQTang.Network.ClientNet.Room;
using QQT.Room.V1;
using Xunit;

namespace QQTang.RoomClient.Tests;

public class RoomProtoCodecTests
{
    [Fact]
    public void EncodeDecodeEnvelope_RoundTrips()
    {
        var codec = new RoomProtoCodec();
        var outbound = new ClientEnvelope
        {
            ProtocolVersion = "1",
            RequestId = "req_1",
            CreateRoom = new CreateRoomRequest
            {
                RoomKind = "private_room",
                RoomDisplayName = "alpha",
            },
        };
        var encoded = codec.EncodeEnvelope(outbound);
        Assert.NotEmpty(encoded);

        var serverEnvelope = new ServerEnvelope
        {
            ProtocolVersion = "1",
            RequestId = "req_1",
            OperationAccepted = new OperationAccepted
            {
                RequestId = "req_1",
                Operation = "CreateRoom",
            },
        };

        var decoded = codec.DecodeServerEnvelope(serverEnvelope.ToByteArray());
        Assert.Equal(ServerEnvelope.PayloadOneofCase.OperationAccepted, decoded.PayloadCase);
        Assert.Equal("CreateRoom", decoded.OperationAccepted.Operation);
    }
}
