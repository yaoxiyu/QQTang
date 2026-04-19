using QQTang.Network.ClientNet.Room;
using Xunit;

namespace QQTang.RoomClient.Tests;

public class RoomServerEnvelopeParserTests
{
    [Fact]
    public void Parse_InvalidPayload_ThrowsDecodeException()
    {
        var parser = new RoomServerEnvelopeParser();
        var ex = Assert.Throws<RoomProtocolDecodeException>(() => parser.Parse([0x01, 0x02, 0x03]));
        Assert.Equal("ROOM_PROTO_DECODE_FAILED", ex.ErrorCode);
    }
}
