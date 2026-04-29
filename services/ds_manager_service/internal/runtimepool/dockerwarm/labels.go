package dockerwarm

import "time"

const (
	LabelComponent    = "qqt.component"
	LabelManagedBy    = "qqt.managed_by"
	LabelPoolID       = "qqt.pool_id"
	LabelSlotID       = "qqt.slot_id"
	LabelDSInstanceID = "qqt.ds_instance_id"
	LabelCreatedAt    = "qqt.created_at"

	LabelComponentBattleDS = "battle_ds"
	LabelManagedByDSM      = "ds_manager_service"
)

func BuildLabels(poolID string, slotID string, dsInstanceID string, createdAt time.Time) map[string]string {
	return map[string]string{
		LabelComponent:    LabelComponentBattleDS,
		LabelManagedBy:    LabelManagedByDSM,
		LabelPoolID:       poolID,
		LabelSlotID:       slotID,
		LabelDSInstanceID: dsInstanceID,
		LabelCreatedAt:    createdAt.UTC().Format(time.RFC3339Nano),
	}
}
