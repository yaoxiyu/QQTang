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
            RoomKind = "private_room",
            RoomDisplayName = "alpha",
            OwnerMemberId = "member_1",
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
                    ConnectionState = "connected",
                    Loadout = new RoomLoadout { CharacterId = "char_default" },
                },
            },
        };

        var mapped = RoomSnapshotMapperCore.ToSnapshotDictionary(snapshot);
        var members = Assert.IsType<List<object?>>(mapped["members"]);
        var firstMember = Assert.IsType<Dictionary<string, object?>>(members[0]);

        Assert.Equal("room_1", mapped["room_id"]);
        Assert.Equal("mode_classic", mapped["mode_id"]);
        Assert.False(firstMember.ContainsKey("reconnect_token"));
        Assert.Equal("member_1", firstMember["member_id"]);
    }
}
