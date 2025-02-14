// Package remotemetrics is a plugin that enables log metrics too complex for Prometheus, but still interesting in terms of analysis and debugging.
// It is enabled by default.
// The destination can be set via logger.remotelog.serverAddress.
package remotemetrics

import (
	"context"
	"time"

	"github.com/iotaledger/hive.go/autopeering/peer"
	"github.com/iotaledger/hive.go/types"

	"github.com/iotaledger/goshimmer/packages/ledgerstate"
	"github.com/iotaledger/goshimmer/plugins/remotelog"

	"github.com/iotaledger/hive.go/daemon"
	"github.com/iotaledger/hive.go/events"
	"github.com/iotaledger/hive.go/node"
	"github.com/iotaledger/hive.go/timeutil"
	"go.uber.org/dig"

	"github.com/iotaledger/goshimmer/packages/drng"
	"github.com/iotaledger/goshimmer/packages/remotemetrics"
	"github.com/iotaledger/goshimmer/packages/shutdown"
	"github.com/iotaledger/goshimmer/packages/tangle"
)

const (
	updateTime = 500 * time.Millisecond
)

const (
	// Debug defines the most verbose metrics collection level.
	Debug uint8 = iota
	// Info defines regular metrics collection level.
	Info
	// Important defines the level of collection of only most important metrics.
	Important
	// Critical defines the level of collection of only critical metrics.
	Critical
)

var (
	// Plugin is the plugin instance of the remote plugin instance.
	Plugin *node.Plugin
	deps   = new(dependencies)
)

type dependencies struct {
	dig.In

	Local        *peer.Local
	Tangle       *tangle.Tangle
	RemoteLogger *remotelog.RemoteLoggerConn `optional:"true"`
	DrngInstance *drng.DRNG                  `optional:"true"`
	ClockPlugin  *node.Plugin                `name:"clock" optional:"true"`
}

func init() {
	Plugin = node.NewPlugin("RemoteLogMetrics", deps, node.Disabled, configure, run)
}

func configure(_ *node.Plugin) {
	measureInitialBranchCounts()
	configureSyncMetrics()
	if deps.DrngInstance != nil {
		configureDRNGMetrics()
	}
	configureMessageFinalizedMetrics()
}

func run(plugin *node.Plugin) {
	// create a background worker that update the metrics every second
	if err := daemon.BackgroundWorker("Node State Logger Updater", func(ctx context.Context) {
		// Do not block until the Ticker is shutdown because we might want to start multiple Tickers and we can
		// safely ignore the last execution when shutting down.
		timeutil.NewTicker(func() { checkSynced() }, updateTime, ctx)

		// Wait before terminating so we get correct log messages from the daemon regarding the shutdown order.
		<-ctx.Done()
	}, shutdown.PriorityRemoteLog); err != nil {
		plugin.Panicf("Failed to start as daemon: %s", err)
	}
}

func configureSyncMetrics() {
	if Parameters.MetricsLevel > Info {
		return
	}
	remotemetrics.Events().TangleTimeSyncChanged.Attach(events.NewClosure(func(syncUpdate remotemetrics.SyncStatusChangedEvent) {
		isTangleTimeSynced.Store(syncUpdate.CurrentStatus)
	}))
	remotemetrics.Events().TangleTimeSyncChanged.Attach(events.NewClosure(sendSyncStatusChangedEvent))
}

func configureDRNGMetrics() {
	if Parameters.MetricsLevel > Info {
		return
	}
	deps.DrngInstance.Events.Randomness.Attach(events.NewClosure(onRandomnessReceived))
}

func configureBranchConfirmationMetrics() {
	if Parameters.MetricsLevel > Info {
		return
	}
	deps.Tangle.ConfirmationOracle.Events().BranchConfirmed.Attach(events.NewClosure(onBranchConfirmed))

	deps.Tangle.LedgerState.BranchDAG.Events.BranchCreated.Attach(events.NewClosure(func(branchID ledgerstate.BranchID) {
		activeBranchesMutex.Lock()
		defer activeBranchesMutex.Unlock()
		if _, exists := activeBranches[branchID]; !exists {
			branchTotalCountDB.Inc()
			activeBranches[branchID] = types.Void
			sendBranchMetrics()
		}
	}))
}

func configureMessageFinalizedMetrics() {
	if Parameters.MetricsLevel > Info {
		return
	} else if Parameters.MetricsLevel == Info {
		deps.Tangle.ConfirmationOracle.Events().TransactionConfirmed.Attach(events.NewClosure(onTransactionConfirmed))
	} else {
		deps.Tangle.ConfirmationOracle.Events().MessageConfirmed.Attach(events.NewClosure(onMessageFinalized))
	}
}
