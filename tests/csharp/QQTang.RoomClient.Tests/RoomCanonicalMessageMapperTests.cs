using QQTang.Network.ClientNet.Room;
using QQT.Room.V1;
using System.Collections.Generic;
using Xunit;

namespace QQTang.RoomClient.Tests;

public class RoomCanonicalMessageMapperTests
{
    [Fact]
    public void Map_OperationRejected_ReturnsCanonicalError()
    {
        var mapper = new RoomCanonicalMessageMapperCore();
        var result = mapper.Map(new ServerEnvelope
        {
            RequestId = "req_1",
            OperationRejected = new OperationRejected
            {
                RequestId = "req_1",
                Operation = "JoinRoom",
                Error = new OperationError
                {
                    Code = "ROOM_JOIN_REJECTED",
                    UserMessage = "room not joinable",
                },
            },
        });

        Assert.Equal("ROOM_JOIN_REJECTED", result["message_type"]);
        Assert.Equal("room not joinable", result["user_message"]);
    }

    [Fact]
    public void Map_SnapshotAndBattleReadyPush_AreCanonical()
    {
        var mapper = new RoomCanonicalMessageMapperCore();

        var snapshotResult = mapper.Map(new ServerEnvelope
        {
            RoomSnapshotPush = new RoomSnapshotPush
            {
                Snapshot = new RoomSnapshot
                {
                    RoomId = "room_1",
                    RoomKind = "private_room",
                    Members = { new RoomMember { MemberId = "member_1" } },
                },
            },
        });
        var battleResult = mapper.Map(new ServerEnvelope
        {
            BattleEntryReadyPush = new BattleEntryReadyPush
            {
                BattleEntry = new BattleEntryState
                {
                    AssignmentId = "assign_1",
                    BattleId = "battle_1",
                    MatchId = "match_1",
                    ServerHost = "127.0.0.1",
                    ServerPort = 19090,
                    BattleEntryReady = true,
                },
            },
        });

        Assert.Equal("ROOM_SNAPSHOT", snapshotResult["message_type"]);
        Assert.IsType<Dictionary<string, object?>>(snapshotResult["snapshot"]);
        Assert.Equal("ROOM_MATCH_ASSIGNMENT_READY", battleResult["message_type"]);
        Assert.Equal("assign_1", battleResult["assignment_id"]);
        Assert.Equal(true, battleResult["battle_entry_ready"]);
    }
}
