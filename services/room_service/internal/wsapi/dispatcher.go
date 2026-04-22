package wsapi

import (
	"errors"

	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/roomapp"
)

type Dispatcher struct {
	app                       *roomapp.Service
	directorySnapshotProvider func() *roomv1.RoomDirectorySnapshot
}

func NewDispatcher(app *roomapp.Service) *Dispatcher {
	return &Dispatcher{app: app}
}

func (d *Dispatcher) SetDirectorySnapshotProvider(provider func() *roomv1.RoomDirectorySnapshot) {
	d.directorySnapshotProvider = provider
}

func (d *Dispatcher) Dispatch(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	if d == nil || d.app == nil || !d.app.Ready() {
		return nil, errors.New("room app not ready")
	}
	if env == nil {
		return nil, errors.New("empty envelope")
	}
	if env.RequestID == "" {
		return nil, errors.New("request_id is required")
	}

	switch env.PayloadType {
	case PayloadCreateRoom:
		return d.handleCreate(conn, env)
	case PayloadJoinRoom:
		return d.handleJoin(conn, env)
	case PayloadResumeRoom:
		return d.handleResume(conn, env)
	case PayloadUpdateProfile:
		return d.handleUpdateProfile(conn, env)
	case PayloadUpdateSelection:
		return d.handleUpdateSelection(conn, env)
	case PayloadUpdateMatchRoomConfig:
		return d.handleUpdateMatchRoomConfig(conn, env)
	case PayloadToggleReady:
		return d.handleToggleReady(conn, env)
	case PayloadLeaveRoom:
		return d.handleLeaveRoom(conn, env)
	case PayloadSubscribeDirectory:
		return d.handleSubscribeDirectory(conn, env)
	case PayloadUnsubscribeDirectory:
		return d.handleUnsubscribeDirectory(conn, env)
	case PayloadStartManualRoomBattle:
		return d.handleStartManualRoomBattle(conn, env)
	case PayloadEnterMatchQueue:
		return d.handleEnterMatchQueue(conn, env)
	case PayloadCancelMatchQueue:
		return d.handleCancelMatchQueue(conn, env)
	case PayloadAckBattleEntry:
		return d.handleAckBattleEntry(conn, env)
	default:
		return nil, errors.New("unsupported payload")
	}
}

func (d *Dispatcher) handleCreate(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	payload := env.CreateRoom
	snapshot, err := d.app.CreateRoom(roomapp.CreateRoomInput{
		RoomKind:        payload.RoomKind,
		RoomDisplayName: payload.RoomDisplayName,
		RoomTicket:      payload.RoomTicket,
		AccountID:       payload.AccountID,
		ProfileID:       payload.ProfileID,
		PlayerName:      payload.PlayerName,
		ConnectionID:    conn.ID(),
		Loadout: roomapp.Loadout{
			CharacterID:     payload.Loadout.CharacterID,
			CharacterSkinID: payload.Loadout.CharacterSkinID,
			BubbleStyleID:   payload.Loadout.BubbleStyleID,
			BubbleSkinID:    payload.Loadout.BubbleSkinID,
		},
		Selection: roomapp.Selection{
			MapID:         payload.Selection.MapID,
			RuleSetID:     payload.Selection.RuleSetID,
			ModeID:        payload.Selection.ModeID,
			MatchFormatID: payload.Selection.MatchFormatID,
		},
	})
	if err != nil {
		return [][]byte{
			EncodeOperationRejected(conn, env.RequestID, "CreateRoom", "ROOM_CREATE_REJECTED", err.Error()),
		}, nil
	}
	if roomID, memberID, resolveErr := d.resolveCaller(conn); resolveErr == nil {
		conn.BindRoom(roomID, memberID)
	}
	return [][]byte{
		EncodeOperationAccepted(conn, env.RequestID, "CreateRoom"),
		EncodeSnapshotPush(conn, env.RequestID, snapshot),
	}, nil
}

func (d *Dispatcher) handleJoin(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	payload := env.JoinRoom
	snapshot, err := d.app.JoinRoom(roomapp.JoinRoomInput{
		RoomID:       payload.RoomID,
		RoomTicket:   payload.RoomTicket,
		AccountID:    payload.AccountID,
		ProfileID:    payload.ProfileID,
		PlayerName:   payload.PlayerName,
		ConnectionID: conn.ID(),
		Loadout: roomapp.Loadout{
			CharacterID:     payload.Loadout.CharacterID,
			CharacterSkinID: payload.Loadout.CharacterSkinID,
			BubbleStyleID:   payload.Loadout.BubbleStyleID,
			BubbleSkinID:    payload.Loadout.BubbleSkinID,
		},
	})
	if err != nil {
		return [][]byte{
			EncodeOperationRejected(conn, env.RequestID, "JoinRoom", "ROOM_JOIN_REJECTED", err.Error()),
		}, nil
	}
	if roomID, memberID, resolveErr := d.resolveCaller(conn); resolveErr == nil {
		conn.BindRoom(roomID, memberID)
	}
	return [][]byte{
		EncodeOperationAccepted(conn, env.RequestID, "JoinRoom"),
		EncodeSnapshotPush(conn, env.RequestID, snapshot),
	}, nil
}

func (d *Dispatcher) handleResume(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	payload := env.ResumeRoom
	snapshot, err := d.app.ResumeRoom(roomapp.ResumeRoomInput{
		RoomID:         payload.RoomID,
		MemberID:       payload.MemberID,
		ReconnectToken: payload.ReconnectToken,
		ConnectionID:   conn.ID(),
		RoomTicket:     payload.RoomTicket,
	})
	if err != nil {
		return [][]byte{
			EncodeOperationRejected(conn, env.RequestID, "ResumeRoom", "ROOM_RESUME_REJECTED", err.Error()),
		}, nil
	}
	conn.BindRoom(payload.RoomID, payload.MemberID)
	return [][]byte{
		EncodeOperationAccepted(conn, env.RequestID, "ResumeRoom"),
		EncodeSnapshotPush(conn, env.RequestID, snapshot),
	}, nil
}

func (d *Dispatcher) handleUpdateProfile(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "UpdateProfile", "ROOM_UPDATE_PROFILE_REJECTED", err.Error())}, nil
	}
	payload := env.UpdateProfile
	snapshot, err := d.app.UpdateProfile(roomapp.UpdateProfileInput{
		RoomID:     roomID,
		MemberID:   memberID,
		PlayerName: payload.PlayerName,
		TeamID:     payload.TeamID,
		Loadout: roomapp.Loadout{
			CharacterID:     payload.Loadout.CharacterID,
			CharacterSkinID: payload.Loadout.CharacterSkinID,
			BubbleStyleID:   payload.Loadout.BubbleStyleID,
			BubbleSkinID:    payload.Loadout.BubbleSkinID,
		},
	})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "UpdateProfile", "ROOM_UPDATE_PROFILE_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "UpdateProfile"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) handleUpdateSelection(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "UpdateSelection", "ROOM_UPDATE_SELECTION_REJECTED", err.Error())}, nil
	}
	payload := env.UpdateSelection.Selection
	snapshot, err := d.app.UpdateSelection(roomapp.UpdateSelectionInput{
		RoomID:   roomID,
		MemberID: memberID,
		Selection: roomapp.Selection{
			MapID:           payload.MapID,
			RuleSetID:       payload.RuleSetID,
			ModeID:          payload.ModeID,
			MatchFormatID:   payload.MatchFormatID,
			SelectedModeIDs: append([]string{}, payload.SelectedModeIDs...),
		},
	})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "UpdateSelection", "ROOM_UPDATE_SELECTION_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "UpdateSelection"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) handleUpdateMatchRoomConfig(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "UpdateMatchRoomConfig", "ROOM_UPDATE_MATCH_ROOM_CONFIG_REJECTED", err.Error())}, nil
	}
	payload := env.UpdateMatchRoomConfig
	snapshot, err := d.app.UpdateMatchRoomConfig(roomapp.UpdateMatchRoomConfigInput{
		RoomID:          roomID,
		MemberID:        memberID,
		MatchFormatID:   payload.MatchFormatID,
		SelectedModeIDs: append([]string{}, payload.SelectedModeIDs...),
	})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "UpdateMatchRoomConfig", "ROOM_UPDATE_MATCH_ROOM_CONFIG_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "UpdateMatchRoomConfig"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) handleToggleReady(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "ToggleReady", "ROOM_TOGGLE_READY_REJECTED", err.Error())}, nil
	}
	snapshot, err := d.app.ToggleReady(roomapp.ToggleReadyInput{RoomID: roomID, MemberID: memberID})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "ToggleReady", "ROOM_TOGGLE_READY_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "ToggleReady"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) handleLeaveRoom(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "LeaveRoom", "ROOM_LEAVE_REJECTED", err.Error())}, nil
	}
	snapshot, err := d.app.LeaveRoom(roomapp.LeaveRoomInput{RoomID: roomID, MemberID: memberID})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "LeaveRoom", "ROOM_LEAVE_REJECTED", err.Error())}, nil
	}
	conn.ClearRoomBinding()
	out := [][]byte{EncodeOperationAccepted(conn, env.RequestID, "LeaveRoom")}
	if snapshot != nil {
		out = append(out, EncodeSnapshotPush(conn, env.RequestID, snapshot))
	}
	return out, nil
}

func (d *Dispatcher) handleSubscribeDirectory(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	d.app.SetDirectorySubscribed(conn.ID(), true)
	conn.SetDirectorySubscribed(true)
	snapshot := &roomv1.RoomDirectorySnapshot{}
	if d.directorySnapshotProvider != nil {
		snapshot = d.directorySnapshotProvider()
	}
	return [][]byte{
		EncodeOperationAccepted(conn, env.RequestID, "SubscribeDirectory"),
		EncodeDirectorySnapshotPush(conn, env.RequestID, snapshot),
	}, nil
}

func (d *Dispatcher) handleUnsubscribeDirectory(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	d.app.SetDirectorySubscribed(conn.ID(), false)
	conn.SetDirectorySubscribed(false)
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "UnsubscribeDirectory")}, nil
}

func (d *Dispatcher) handleStartManualRoomBattle(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "StartManualRoomBattle", "ROOM_START_REJECTED", err.Error())}, nil
	}
	snapshot, err := d.app.StartManualRoomBattle(roomapp.StartManualRoomBattleInput{RoomID: roomID, MemberID: memberID})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "StartManualRoomBattle", "ROOM_START_REJECTED", err.Error())}, nil
	}
	return [][]byte{
		EncodeOperationAccepted(conn, env.RequestID, "StartManualRoomBattle"),
		EncodeSnapshotPush(conn, env.RequestID, snapshot),
		EncodeBattleEntryReadyPushFromSnapshot(conn, env.RequestID, snapshot),
	}, nil
}

func (d *Dispatcher) handleEnterMatchQueue(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "EnterMatchQueue", "ROOM_ENTER_MATCH_QUEUE_REJECTED", err.Error())}, nil
	}
	snapshot, err := d.app.EnterMatchQueue(roomapp.EnterMatchQueueInput{RoomID: roomID, MemberID: memberID})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "EnterMatchQueue", "ROOM_ENTER_MATCH_QUEUE_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "EnterMatchQueue"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) handleCancelMatchQueue(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "CancelMatchQueue", "ROOM_CANCEL_MATCH_QUEUE_REJECTED", err.Error())}, nil
	}
	snapshot, err := d.app.CancelMatchQueue(roomapp.CancelMatchQueueInput{RoomID: roomID, MemberID: memberID})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "CancelMatchQueue", "ROOM_CANCEL_MATCH_QUEUE_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "CancelMatchQueue"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) handleAckBattleEntry(conn *Connection, env *ClientEnvelope) ([][]byte, error) {
	roomID, memberID, err := d.resolveCaller(conn)
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "AckBattleEntry", "ROOM_ACK_BATTLE_ENTRY_REJECTED", err.Error())}, nil
	}
	payload := env.AckBattleEntry
	snapshot, err := d.app.AckBattleEntry(roomapp.AckBattleEntryInput{
		RoomID:       roomID,
		MemberID:     memberID,
		AssignmentID: payload.AssignmentID,
		BattleID:     payload.BattleID,
		MatchID:      "",
	})
	if err != nil {
		return [][]byte{EncodeOperationRejected(conn, env.RequestID, "AckBattleEntry", "ROOM_ACK_BATTLE_ENTRY_REJECTED", err.Error())}, nil
	}
	return [][]byte{EncodeOperationAccepted(conn, env.RequestID, "AckBattleEntry"), EncodeSnapshotPush(conn, env.RequestID, snapshot)}, nil
}

func (d *Dispatcher) resolveCaller(conn *Connection) (string, string, error) {
	if conn == nil {
		return "", "", errors.New("connection is nil")
	}
	return d.app.ResolveRoomMemberByConnection(conn.ID())
}
