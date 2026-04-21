package queue

import "testing"

func TestNormalizeAssignmentDefaults_CommitDeadlineNotLessThanCaptainDeadline(t *testing.T) {
	normalized := NormalizeAssignmentDefaults(AssignmentDefaults{
		CaptainDeadlineSeconds: 45,
		CommitDeadlineSeconds:  10,
	})
	if normalized.CaptainDeadlineSeconds != 45 {
		t.Fatalf("expected captain deadline 45, got %d", normalized.CaptainDeadlineSeconds)
	}
	if normalized.CommitDeadlineSeconds != 45 {
		t.Fatalf("expected commit deadline normalized to 45, got %d", normalized.CommitDeadlineSeconds)
	}
}
