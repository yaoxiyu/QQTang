package storage

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/tracelog"
)

var ErrStoreUnavailable = errors.New("store unavailable")

type PostgresStore struct {
	Pool *pgxpool.Pool
}

func NewPostgresStore(ctx context.Context, dsn string, logSQL bool) (*PostgresStore, error) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, err
	}

	cfg.MaxConns = 10
	cfg.MinConns = 1
	cfg.MaxConnIdleTime = 5 * time.Minute
	cfg.HealthCheckPeriod = 30 * time.Second
	if logSQL {
		cfg.ConnConfig.Tracer = &tracelog.TraceLog{
			Logger: tracelog.LoggerFunc(func(ctx context.Context, level tracelog.LogLevel, msg string, data map[string]any) {
				log.Printf("pgx %s %s %v", level.String(), msg, data)
			}),
			LogLevel: tracelog.LogLevelInfo,
		}
	}

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, err
	}

	pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, err
	}

	return &PostgresStore{Pool: pool}, nil
}

func (s *PostgresStore) Ping(ctx context.Context) error {
	if s == nil || s.Pool == nil {
		return ErrStoreUnavailable
	}
	var value int
	return s.Pool.QueryRow(ctx, "SELECT 1").Scan(&value)
}

func (s *PostgresStore) Close() {
	if s != nil && s.Pool != nil {
		s.Pool.Close()
	}
}
