using QQTang.Network.ClientNet.Room;
using QQT.Room.V1;
using System.Collections.Generic;
using Xunit;

namespace QQTang.RoomClient.Tests;

public class RoomSnapshotMapperTests
{
    [Fact]
    public void ToSnapshotDictionary_MapsMembersAndDoesNotExposeReconnectToken()
    {
        var snapshot = new RoomSnapshot
        {
            RoomId = "room_1",
            RoomKind = "casual_match_room",
            RoomDisplayName = "alpha",
            OwnerMemberId = "member_1",
            RoomPhase = "queue_active",
            RoomPhaseReason = "none",
            QueueState = "queued",
            QueuePhase = "queued",
            QueueTerminalReason = "none",
            QueueStatusText = "Matchmaking",
            QueueEntryId = "queue_1",
            CanToggleReady = false,
            CanStartManualBattle = false,
            CanUpdateSelection = false,
            CanUpdateMatchRoomConfig = true,
            CanEnterQueue = false,
            CanCancelQueue = true,
            CanLeaveRoom = true,
            Selection = new RoomSelection
            {
                MapId = "map_arcade",
                RuleSetId = "ruleset_classic",
                ModeId = "mode_classic",
                MatchFormatId = "2v2",
            },
            Members =
            {
                new RoomMember
                {
                    MemberId = "member_1",
                    PlayerName = "owner",
                    Ready = true,
                    MemberPhase = "queue_locked",
                    ConnectionState = "connected",
                    Loadout = new RoomLoadout { CharacterId = "char_default" },
                },
            },
            BattleEntry = new BattleEntryState
            {
                AssignmentId = "assign_1",
                BattleId = "battle_1",
                MatchId = "match_1",
                ServerHost = "127.0.0.1",
                ServerPort = 19010,
                BattleEntryReady = true,
                Phase = "ready",
                TerminalReason = "none",
                StatusText = "Battle ready",
            },
        };

        var mapped = RoomSnapshotMapperCore.ToSnapshotDictionary(snapshot);
        var members = Assert.IsType<List<object?>>(mapped["members"]);
        var firstMember = Assert.IsType<Dictionary<string, object?>>(members[0]);

        Assert.Equal("room_1", mapped["room_id"]);
        Assert.Equal("mode_classic", mapped["mode_id"]);
        Assert.Equal("queue_active", mapped["room_phase"]);
        Assert.Equal("none", mapped["room_phase_reason"]);
        Assert.Equal("queued", mapped["queue_phase"]);
        Assert.Equal("none", mapped["queue_terminal_reason"]);
        Assert.Equal("Matchmaking", mapped["queue_status_text"]);
        Assert.Equal("queue_1", mapped["room_queue_entry_id"]);
        Assert.Equal("ready", mapped["battle_phase"]);
        Assert.Equal("none", mapped["battle_terminal_reason"]);
        Assert.Equal("Battle ready", mapped["battle_status_text"]);
        Assert.Equal(false, mapped["can_toggle_ready"]);
        Assert.Equal(false, mapped["can_start_manual_battle"]);
        Assert.Equal(false, mapped["can_update_selection"]);
        Assert.Equal(true, mapped["can_update_match_room_config"]);
        Assert.Equal(false, mapped["can_enter_queue"]);
        Assert.Equal(true, mapped["can_cancel_queue"]);
        Assert.Equal(true, mapped["can_leave_room"]);
        Assert.Equal("queued", mapped["room_queue_state"]);
        Assert.Equal(string.Empty, mapped["room_lifecycle_state"]);
        Assert.Equal("battle_ready", mapped["battle_allocation_state"]);
        Assert.False(firstMember.ContainsKey("reconnect_token"));
        Assert.Equal("member_1", firstMember["member_id"]);
        Assert.Equal("queue_locked", firstMember["member_phase"]);
    }
}
