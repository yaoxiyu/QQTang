package wsapi

import (
	"errors"

	"qqtang/services/room_service/internal/roomapp"
)

type Dispatcher struct {
	app *roomapp.Service
}

func NewDispatcher(app *roomapp.Service) *Dispatcher {
	return &Dispatcher{app: app}
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
	return [][]byte{
		EncodeOperationAccepted(conn, env.RequestID, "ResumeRoom"),
		EncodeSnapshotPush(conn, env.RequestID, snapshot),
	}, nil
}
