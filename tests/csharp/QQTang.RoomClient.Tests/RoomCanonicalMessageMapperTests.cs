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
                    RoomPhase = "battle_entry_ready",
                    QueuePhase = "entry_ready",
                    QueueTerminalReason = "none",
                    CanCancelQueue = true,
                    BattleEntry = new BattleEntryState
                    {
                        Phase = "ready",
                        TerminalReason = "manual_start",
                        StatusText = "Battle ready",
                    },
                    Members = { new RoomMember { MemberId = "member_1", MemberPhase = "queue_locked" } },
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
                    Phase = "ready",
                    TerminalReason = "manual_start",
                    StatusText = "Battle ready",
                },
            },
        });

        Assert.Equal("ROOM_SNAPSHOT", snapshotResult["message_type"]);
        var mappedSnapshot = Assert.IsType<Dictionary<string, object?>>(snapshotResult["snapshot"]);
        Assert.Equal("battle_entry_ready", mappedSnapshot["room_phase"]);
        Assert.Equal("entry_ready", mappedSnapshot["queue_phase"]);
        Assert.Equal("none", mappedSnapshot["queue_terminal_reason"]);
        Assert.Equal("ready", mappedSnapshot["battle_phase"]);
        Assert.Equal("manual_start", mappedSnapshot["battle_terminal_reason"]);
        Assert.Equal(true, mappedSnapshot["can_cancel_queue"]);
        var mappedMembers = Assert.IsType<List<object?>>(mappedSnapshot["members"]);
        var firstMember = Assert.IsType<Dictionary<string, object?>>(mappedMembers[0]);
        Assert.Equal("queue_locked", firstMember["member_phase"]);
        Assert.Equal("ROOM_MATCH_ASSIGNMENT_READY", battleResult["message_type"]);
        Assert.Equal("assign_1", battleResult["assignment_id"]);
        Assert.Equal(true, battleResult["battle_entry_ready"]);
        Assert.Equal("ready", battleResult["battle_phase"]);
        Assert.Equal("manual_start", battleResult["battle_terminal_reason"]);
        Assert.Equal("Battle ready", battleResult["battle_status_text"]);
    }
}
