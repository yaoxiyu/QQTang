using QQTang.Network.ClientNet.Room;
using QQT.Room.V1;
using System.Collections.Generic;
using Xunit;

namespace QQTang.RoomClient.Tests;

public class RoomClientEnvelopeFactoryTests
{
    [Fact]
    public void BuildEnvelope_CreateJoinResume_SetExpectedPayloads()
    {
        var factory = new RoomClientEnvelopeFactoryCore();
        var session = new RoomClientSessionState();

        var create = factory.BuildEnvelope(new Dictionary<string, object?>
        {
            { "message_type", "ROOM_CREATE_REQUEST" },
            { "room_kind", "private_room" },
            { "room_display_name", "alpha" },
            { "account_id", "acc_1" },
            { "profile_id", "pro_1" },
            { "player_name", "p1" },
        }, session);
        var join = factory.BuildEnvelope(new Dictionary<string, object?>
        {
            { "message_type", "ROOM_JOIN_REQUEST" },
            { "room_id", "room_1" },
            { "account_id", "acc_2" },
            { "profile_id", "pro_2" },
            { "player_name", "p2" },
        }, session);
        var resume = factory.BuildEnvelope(new Dictionary<string, object?>
        {
            { "message_type", "ROOM_RESUME_REQUEST" },
            { "room_id", "room_1" },
            { "member_id", "member_1" },
            { "reconnect_token", "rt_1" },
        }, session);

        Assert.Equal(ClientEnvelope.PayloadOneofCase.CreateRoom, create.PayloadCase);
        Assert.Equal("private_room", create.CreateRoom.RoomKind);
        Assert.Equal(ClientEnvelope.PayloadOneofCase.JoinRoom, join.PayloadCase);
        Assert.Equal("room_1", join.JoinRoom.RoomId);
        Assert.Equal(ClientEnvelope.PayloadOneofCase.ResumeRoom, resume.PayloadCase);
        Assert.Equal("member_1", resume.ResumeRoom.MemberId);
        Assert.True(create.Sequence < join.Sequence && join.Sequence < resume.Sequence);
    }

    [Fact]
    public void BuildEnvelope_UpdateSelectionToggleReady_AreMapped()
    {
        var factory = new RoomClientEnvelopeFactoryCore();
        var session = new RoomClientSessionState();

        var updateSelection = factory.BuildEnvelope(new Dictionary<string, object?>
        {
            { "message_type", "ROOM_UPDATE_SELECTION" },
            { "selection", new Dictionary<string, object?>
                {
                    { "map_id", "map_arcade" },
                    { "rule_set_id", "ruleset_classic" },
                    { "mode_id", "box" },
                    { "match_format_id", "2v2" },
                    { "selected_mode_ids", new List<object?> { "box" } },
                }
            },
        }, session);

        var toggleReady = factory.BuildEnvelope(new Dictionary<string, object?>
        {
            { "message_type", "ROOM_TOGGLE_READY" },
            { "expected_ready", true },
        }, session);

        Assert.Equal(ClientEnvelope.PayloadOneofCase.UpdateSelection, updateSelection.PayloadCase);
        Assert.Equal("map_arcade", updateSelection.UpdateSelection.Selection.MapId);
        Assert.Single(updateSelection.UpdateSelection.Selection.SelectedModeIds);
        Assert.Equal(ClientEnvelope.PayloadOneofCase.ToggleReady, toggleReady.PayloadCase);
        Assert.True(toggleReady.ToggleReady.ExpectedReady);
    }
}
