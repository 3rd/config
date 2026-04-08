package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	msgRe         = regexp.MustCompile(`msg=audit\((\d+(?:\.\d+)?):(\d+)\):`)
	typeRe        = regexp.MustCompile(`(?:^| )type=([A-Z_]+)`)
	fieldRe       = regexp.MustCompile(`([A-Za-z_][A-Za-z0-9_]*)=("(?:[^"\\]|\\.)*"|[^ ]+)`)
	socketFieldRe = regexp.MustCompile(`([A-Za-z_]+)=([^ ]+)`)
	hexTextRe     = regexp.MustCompile(`^[0-9A-Fa-f]+$`)
	argvKeyRe     = regexp.MustCompile(`^a(\d+)$`)
	quotedValueRe = regexp.MustCompile(`"([^"]+)"`)
)

var anycastDNSIPs = map[string]struct{}{
	"1.0.0.1":              {},
	"1.1.1.1":              {},
	"8.8.4.4":              {},
	"8.8.8.8":              {},
	"9.9.9.9":              {},
	"149.112.112.112":      {},
	"2001:4860:4860::8844": {},
	"2001:4860:4860::8888": {},
	"2606:4700:4700::1001": {},
	"2606:4700:4700::1111": {},
	"2620:fe::9":           {},
	"2620:fe::fe":          {},
}

var anycastDNSHosts = map[string]struct{}{
	"dns.google":      {},
	"one.one.one.one": {},
}

var anycastDNSHostSuffixes = []string{
	".cloudflare-dns.com",
	".quad9.net",
}

type auditMode string

const (
	auditModeFS   auditMode = "fs"
	auditModeExec auditMode = "exec"
	auditModeNet  auditMode = "net"

	auditDispatcherSocketPath = "/run/audit/audispd_events"
	auditBackfillSeconds      = 3600
	auditSpoolPollInterval    = time.Second
	defaultStateSyncInterval  = 30 * time.Second
	defaultFullStateInterval  = 5 * time.Minute
	geoLookupTimeout          = 2 * time.Second
	geoNegativeCacheTTL       = 15 * time.Minute
	geoPositiveCacheTTL       = 24 * time.Hour
)

func main() {
	if len(os.Args) < 2 {
		fatalf("usage: %s <audit-normalize|audit-stream-exporter|network-usage|process-metrics-exporter> ...", filepath.Base(os.Args[0]))
	}

	var err error
	switch os.Args[1] {
	case "audit-normalize":
		err = runAuditNormalize(os.Args[2:])
	case "audit-stream-exporter":
		err = runAuditStreamExporter(os.Args[2:])
	case "network-usage":
		err = runNetworkUsage(os.Args[2:])
	case "process-metrics-exporter":
		err = runProcessMetricsExporter()
	default:
		err = fmt.Errorf("unknown subcommand: %s", os.Args[1])
	}

	if err != nil {
		fatalf("%v", err)
	}
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func infof(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
}

func parseAuditMode(value string) (auditMode, bool) {
	switch strings.TrimSpace(value) {
	case string(auditModeFS):
		return auditModeFS, true
	case string(auditModeExec):
		return auditModeExec, true
	case string(auditModeNet):
		return auditModeNet, true
	default:
		return "", false
	}
}

func auditModeKeys(mode auditMode) []string {
	switch mode {
	case auditModeFS:
		return []string{"fs_home", "fs_system"}
	case auditModeExec:
		return []string{"exec"}
	case auditModeNet:
		return []string{"net_connect"}
	default:
		return nil
	}
}

type auditConfig struct {
	watchPaths            []string
	homeWatchPaths        map[string]struct{}
	mmdbLookupBin         string
	countryDB             string
	enabledModes          map[auditMode]struct{}
	stateSyncInterval     time.Duration
	fullStateInterval     time.Duration
	streamChannelCapacity int
}

func (cfg auditConfig) modeEnabled(mode auditMode) bool {
	_, ok := cfg.enabledModes[mode]
	return ok
}

func (cfg auditConfig) enabledModesList() []auditMode {
	modes := make([]auditMode, 0, 3)
	for _, mode := range []auditMode{auditModeFS, auditModeExec, auditModeNet} {
		if cfg.modeEnabled(mode) {
			modes = append(modes, mode)
		}
	}
	return modes
}

func runAuditNormalize(args []string) error {
	if len(args) != 7 {
		return fmt.Errorf("usage: core-monitoring-tools audit-normalize <mode> <input> <output> <anomaly> <state-dir> <threshold> <lookback-days>")
	}

	cfg, err := loadAuditConfigFromEnv()
	if err != nil {
		return err
	}

	mode := args[0]
	inputPath := args[1]
	outputPath := args[2]
	anomalyPath := args[3]
	stateDir := args[4]
	threshold, err := strconv.Atoi(args[5])
	if err != nil {
		return fmt.Errorf("parse threshold: %w", err)
	}
	lookbackDays, err := strconv.Atoi(args[6])
	if err != nil {
		return fmt.Errorf("parse lookback days: %w", err)
	}

	events, err := collectAuditEvents(inputPath)
	if err != nil {
		return err
	}

	normalized := normalizeAuditEvents(events)
	var records []map[string]any
	var anomalies []map[string]any

	switch mode {
	case "fs":
		records, anomalies, err = transformAuditFS(normalized, outputPath, threshold, cfg)
	case "exec":
		records, anomalies, err = transformAuditExec(normalized, outputPath, stateDir, lookbackDays)
	case "net":
		records, anomalies, err = transformAuditNet(normalized, outputPath, stateDir, threshold, cfg)
	default:
		err = fmt.Errorf("unsupported mode: %s", mode)
	}
	if err != nil {
		return err
	}

	if err := appendNDJSON(outputPath, records); err != nil {
		return err
	}
	return appendNDJSON(anomalyPath, anomalies)
}

type auditModeBuffer struct {
	mode           auditMode
	interval       time.Duration
	threshold      int
	rawRecords     []map[string]any
	anomalies      []map[string]any
	summaryGroups  map[string]*groupedAuditSummary
	processGroups  map[string]*groupedProcessCount
	windowStart    float64
	windowEnd      float64
	windowCount    int
	flushedThrough float64
	lastFlush      time.Time
}

type auditStreamExporter struct {
	cfg             auditConfig
	logDir          string
	stateDir        string
	lookbackDays    int
	ausearchBin     string
	dedupeRetention time.Duration
	buffers         map[auditMode]*auditModeBuffer
	fsSeen          map[string]float64
	execSeen        map[string]float64
	netSeen         map[string]float64
	seenExecutables map[string]float64
	geoResolver     *auditGeoResolver
	spoolOffsets    map[string]int64
	spoolMu         sync.RWMutex
	stateDirty      bool
	heavyStateDirty bool
	lastFullSave    time.Time
}

type auditGeoResolver struct {
	cfg     auditConfig
	mu      sync.RWMutex
	cache   map[string]geoRecord
	pending map[string]struct{}
	queue   chan string
	dirty   bool
}

type geoRecord struct {
	CountryCode  string  `json:"country_code"`
	CountryName  string  `json:"country_name"`
	Host         string  `json:"host"`
	LastResolved float64 `json:"last_resolved,omitempty"`
}

type auditRawEventGroup struct {
	Serial    int
	Timestamp float64
	Lines     []string
}

func runAuditStreamExporter(args []string) error {
	if len(args) != 8 {
		return fmt.Errorf("usage: core-monitoring-tools audit-stream-exporter <log-dir> <state-dir> <fs-threshold> <net-threshold> <lookback-days> <fs-interval-seconds> <exec-interval-seconds> <net-interval-seconds>")
	}

	cfg, err := loadAuditConfigFromEnv()
	if err != nil {
		return err
	}

	fsThreshold, err := strconv.Atoi(args[2])
	if err != nil {
		return fmt.Errorf("parse fs threshold: %w", err)
	}
	netThreshold, err := strconv.Atoi(args[3])
	if err != nil {
		return fmt.Errorf("parse net threshold: %w", err)
	}
	lookbackDays, err := strconv.Atoi(args[4])
	if err != nil {
		return fmt.Errorf("parse lookback days: %w", err)
	}
	fsIntervalSeconds, err := strconv.Atoi(args[5])
	if err != nil {
		return fmt.Errorf("parse fs interval: %w", err)
	}
	execIntervalSeconds, err := strconv.Atoi(args[6])
	if err != nil {
		return fmt.Errorf("parse exec interval: %w", err)
	}
	netIntervalSeconds, err := strconv.Atoi(args[7])
	if err != nil {
		return fmt.Errorf("parse net interval: %w", err)
	}

	now := time.Now().UTC()
	maxIntervalSeconds := 1
	buffers := map[auditMode]*auditModeBuffer{}
	if cfg.modeEnabled(auditModeFS) {
		buffers[auditModeFS] = &auditModeBuffer{
			mode:           auditModeFS,
			interval:       time.Duration(fsIntervalSeconds) * time.Second,
			threshold:      fsThreshold,
			summaryGroups:  map[string]*groupedAuditSummary{},
			processGroups:  map[string]*groupedProcessCount{},
			flushedThrough: float64(now.Unix()),
			lastFlush:      now,
		}
		maxIntervalSeconds = maxInt(maxIntervalSeconds, fsIntervalSeconds)
	}
	if cfg.modeEnabled(auditModeExec) {
		buffers[auditModeExec] = &auditModeBuffer{
			mode:           auditModeExec,
			interval:       time.Duration(execIntervalSeconds) * time.Second,
			summaryGroups:  map[string]*groupedAuditSummary{},
			flushedThrough: float64(now.Unix()),
			lastFlush:      now,
		}
		maxIntervalSeconds = maxInt(maxIntervalSeconds, execIntervalSeconds)
	}
	if cfg.modeEnabled(auditModeNet) {
		buffers[auditModeNet] = &auditModeBuffer{
			mode:           auditModeNet,
			interval:       time.Duration(netIntervalSeconds) * time.Second,
			threshold:      netThreshold,
			summaryGroups:  map[string]*groupedAuditSummary{},
			processGroups:  map[string]*groupedProcessCount{},
			flushedThrough: float64(now.Unix()),
			lastFlush:      now,
		}
		maxIntervalSeconds = maxInt(maxIntervalSeconds, netIntervalSeconds)
	}
	if len(buffers) == 0 {
		return fmt.Errorf("audit-stream-exporter requires at least one enabled mode")
	}

	exporter := &auditStreamExporter{
		cfg:             cfg,
		logDir:          args[0],
		stateDir:        args[1],
		lookbackDays:    lookbackDays,
		ausearchBin:     os.Getenv("CORE_MONITORING_AUSEARCH_BIN"),
		dedupeRetention: time.Duration(maxInt(2*auditBackfillSeconds, 2*maxIntervalSeconds)) * time.Second,
		buffers:         buffers,
		fsSeen:          map[string]float64{},
		execSeen:        map[string]float64{},
		netSeen:         map[string]float64{},
		seenExecutables: map[string]float64{},
		geoResolver:     newAuditGeoResolver(cfg),
		spoolOffsets:    map[string]int64{},
		lastFullSave:    now,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := exporter.run(ctx, now); err != nil {
		return err
	}
	return nil
}

func (exporter *auditStreamExporter) run(ctx context.Context, now time.Time) error {
	if err := exporter.loadRuntimeState(now); err != nil {
		return err
	}
	if err := exporter.cleanupDisabledModeState(); err != nil {
		return err
	}
	exporter.geoResolver.start(ctx)

	if err := exporter.backfill(ctx, now); err != nil {
		return err
	}
	if err := exporter.saveState(); err != nil {
		return err
	}

	rawEvents := make(chan auditRawEventGroup, 256)
	events := make(chan auditEvent, 256)
	if exporter.cfg.streamChannelCapacity > 0 {
		rawEvents = make(chan auditRawEventGroup, exporter.cfg.streamChannelCapacity)
		events = make(chan auditEvent, exporter.cfg.streamChannelCapacity)
	}
	normalizerErrors := make(chan error, 1)
	go exporter.streamAuditEvents(ctx, rawEvents)
	go exporter.normalizeSpoolLoop(ctx, events, normalizerErrors)

	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	stateTicker := time.NewTicker(exporter.cfg.stateSyncInterval)
	defer stateTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			// don't flush on shutdown; next start backfills from the last durable timestamp
			return exporter.saveState()
		case err := <-normalizerErrors:
			if err != nil {
				return err
			}
		case rawEvent := <-rawEvents:
			if err := exporter.handleLiveRawAuditEventGroup(rawEvent); err != nil {
				return err
			}
			if err := exporter.drainRawAuditEvents(rawEvents, 256); err != nil {
				return err
			}
		case event := <-events:
			exporter.enqueueEvent(event)
		case now := <-ticker.C:
			if err := exporter.drainRawAuditEvents(rawEvents, exporter.cfg.streamChannelCapacity); err != nil {
				return err
			}
			if err := exporter.flushDue(now.UTC()); err != nil {
				return err
			}
		case <-stateTicker.C:
			if err := exporter.saveStateIfDirty(); err != nil {
				return err
			}
		}
	}
}

func (exporter *auditStreamExporter) backfill(ctx context.Context, now time.Time) error {
	startTs := exporter.loadStateStart(now)
	count, err := exporter.collectBackfillEvents(ctx, startTs)
	if err != nil {
		return err
	}
	if count == 0 {
		exporter.setAllFlushedThrough(float64(now.Unix()))
		return nil
	}
	return exporter.flushAll(now)
}

func (exporter *auditStreamExporter) loadStateStart(now time.Time) int64 {
	data, err := os.ReadFile(exporter.stateFilePath())
	if err != nil {
		return now.Unix() - auditBackfillSeconds
	}

	parsed, err := strconv.ParseInt(strings.TrimSpace(string(data)), 10, 64)
	if err != nil {
		return now.Unix() - auditBackfillSeconds
	}
	if parsed > now.Unix() {
		return now.Unix() - 60
	}
	return parsed
}

func (exporter *auditStreamExporter) collectBackfillEvents(ctx context.Context, startTs int64) (int, error) {
	if exporter.ausearchBin == "" {
		return 0, nil
	}

	file, err := os.CreateTemp("", "core-monitoring-audit-backfill-*.log")
	if err != nil {
		return 0, fmt.Errorf("create audit backfill temp file: %w", err)
	}
	defer os.Remove(file.Name())
	defer file.Close()

	for _, mode := range exporter.cfg.enabledModesList() {
		for _, key := range auditModeKeys(mode) {
			if err := appendAusearchRaw(ctx, file, exporter.ausearchBin, key, startTs); err != nil {
				return 0, err
			}
		}
	}

	if _, err := file.Seek(0, 0); err != nil {
		return 0, fmt.Errorf("rewind audit backfill temp file: %w", err)
	}
	count := 0
	if err := exporter.streamAuditGroups(file, func(wrapper auditEventGroup) error {
		event, _, ok := exporter.normalizeEnabledAuditEvent(wrapper)
		if !ok {
			return nil
		}
		count++
		exporter.enqueueEvent(event)
		return nil
	}); err != nil {
		return 0, err
	}
	return count, nil
}

func appendAusearchRaw(ctx context.Context, output *os.File, ausearchBin string, key string, startTs int64) error {
	start := time.Unix(startTs, 0).Local()
	command := exec.CommandContext(ctx, ausearchBin, "--input-logs", "--raw", "-ts", start.Format("01/02/06"), start.Format("15:04:05"), "-k", key)
	command.Env = append(os.Environ(), "LC_TIME=C")
	command.Stdout = output

	var stderr bytes.Buffer
	command.Stderr = &stderr

	err := command.Run()
	if err == nil {
		return nil
	}

	exitError := &exec.ExitError{}
	if errors.As(err, &exitError) && exitError.ExitCode() == 1 && strings.TrimSpace(stderr.String()) == "" {
		return nil
	}

	if stderr.Len() > 0 {
		return fmt.Errorf("ausearch %s failed: %s", key, strings.TrimSpace(stderr.String()))
	}
	return fmt.Errorf("ausearch %s failed: %w", key, err)
}

func (exporter *auditStreamExporter) streamAuditEvents(ctx context.Context, output chan<- auditRawEventGroup) {
	wasConnected := false
	lastDialError := ""

	for {
		if ctx.Err() != nil {
			return
		}

		conn, err := net.Dial("unix", auditDispatcherSocketPath)
		if err != nil {
			errText := err.Error()
			if wasConnected || errText != lastDialError {
				infof("audit stream connect failed: %v", err)
			}
			wasConnected = false
			lastDialError = errText
			if !sleepContext(ctx, time.Second) {
				return
			}
			continue
		}

		if !wasConnected {
			infof("audit stream connected: %s", auditDispatcherSocketPath)
		}
		wasConnected = true
		lastDialError = ""

		err = exporter.readAuditStream(ctx, conn, output)
		_ = conn.Close()
		if err != nil && ctx.Err() == nil {
			infof("audit stream disconnected: %v", err)
			wasConnected = false
		}
		if !sleepContext(ctx, time.Second) {
			return
		}
	}
}

func (exporter *auditStreamExporter) readAuditStream(ctx context.Context, conn net.Conn, output chan<- auditRawEventGroup) error {
	closeOnDone := make(chan struct{})
	defer close(closeOnDone)
	go func() {
		select {
		case <-ctx.Done():
			if unixConn, ok := conn.(*net.UnixConn); ok {
				_ = unixConn.SetReadDeadline(time.Now())
				_ = unixConn.CloseRead()
			}
			_ = conn.Close()
		case <-closeOnDone:
		}
	}()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)

	var current *auditRawEventGroup
	for scanner.Scan() {
		rawLine := scanner.Text()
		parsed, ok := parseAuditLine(rawLine)
		if !ok {
			continue
		}

		if current != nil && parsed.Serial != current.Serial {
			select {
			case output <- *current:
			case <-ctx.Done():
				return nil
			}
			current = nil
		}

		if current == nil {
			current = &auditRawEventGroup{
				Serial:    parsed.Serial,
				Timestamp: parsed.Timestamp,
				Lines:     make([]string, 0, 4),
			}
		}
		current.Timestamp = parsed.Timestamp
		current.Lines = append(current.Lines, rawLine)
	}

	if current != nil {
		select {
		case output <- *current:
		case <-ctx.Done():
		}
	}

	if ctx.Err() != nil {
		return nil
	}
	return scanner.Err()
}

func (exporter *auditStreamExporter) enqueueEvent(event auditEvent) {
	buffer, ok := exporter.buffers[eventMode(event)]
	if !ok {
		return
	}
	exporter.markWindowEvent(buffer, event.Timestamp)

	switch buffer.mode {
	case auditModeFS:
		exporter.processFSEvent(buffer, event)
	case auditModeExec:
		exporter.processExecEvent(buffer, event)
	case auditModeNet:
		exporter.processNetEvent(buffer, event)
	}
}

func eventMode(event auditEvent) auditMode {
	switch cleanControl(event.Key) {
	case "fs_home", "fs_system":
		return auditModeFS
	case "exec":
		return auditModeExec
	case "net_connect":
		return auditModeNet
	default:
		return ""
	}
}

func (exporter *auditStreamExporter) flushDue(now time.Time) error {
	flushed := false
	for _, buffer := range exporter.buffers {
		if !exporter.bufferHasPending(buffer) || now.Sub(buffer.lastFlush) < buffer.interval {
			continue
		}
		if err := exporter.flushMode(buffer.mode, now); err != nil {
			return err
		}
		flushed = true
	}
	if flushed {
		return exporter.saveState()
	}
	return nil
}

func (exporter *auditStreamExporter) flushAll(now time.Time) error {
	flushed := false
	for _, buffer := range exporter.buffers {
		if !exporter.bufferHasPending(buffer) {
			buffer.lastFlush = now
			continue
		}
		if err := exporter.flushMode(buffer.mode, now); err != nil {
			return err
		}
		flushed = true
	}
	if flushed {
		return exporter.saveState()
	}
	return nil
}

func (exporter *auditStreamExporter) flushMode(mode auditMode, now time.Time) error {
	buffer := exporter.buffers[mode]
	if buffer == nil || !exporter.bufferHasPending(buffer) {
		return nil
	}
	flushedThrough := buffer.windowEnd

	outputPath := exporter.modeOutputPath(mode, now)
	summaryPath := exporter.summaryOutputPath(mode, now)
	anomalyPath := exporter.anomalyOutputPath(now)
	if err := appendNDJSON(outputPath, buffer.rawRecords); err != nil {
		return err
	}
	if err := appendNDJSON(summaryPath, exporter.buildPreparedSummaries(buffer)); err != nil {
		return err
	}
	if err := appendNDJSON(anomalyPath, exporter.prepareAnomalies(buffer)); err != nil {
		return err
	}

	buffer.rawRecords = nil
	buffer.anomalies = nil
	buffer.summaryGroups = map[string]*groupedAuditSummary{}
	buffer.processGroups = exporter.newProcessGroupMap(mode)
	buffer.windowStart = 0
	buffer.windowEnd = 0
	buffer.windowCount = 0
	buffer.lastFlush = now
	if flushedThrough > buffer.flushedThrough {
		buffer.flushedThrough = flushedThrough
	}
	exporter.markStateDirty()
	return nil
}

func (exporter *auditStreamExporter) stateFilePath() string {
	return filepath.Join(exporter.stateDir, "audit-stream-last-ts")
}

func (exporter *auditStreamExporter) spoolDirPath() string {
	return filepath.Join(exporter.stateDir, "spool")
}

func (exporter *auditStreamExporter) spoolOffsetsPath() string {
	return filepath.Join(exporter.stateDir, "audit-spool-offsets.json")
}

func (exporter *auditStreamExporter) saveState() error {
	if err := exporter.saveCheckpoint(); err != nil {
		return err
	}

	nowTS := float64(time.Now().UTC().Unix())
	dedupeCutoff := nowTS - exporter.dedupeRetention.Seconds()
	if exporter.cfg.modeEnabled(auditModeFS) {
		pruneTimestampMap(exporter.fsSeen, dedupeCutoff)
		if err := saveJSON(exporter.fsSeenPath(), exporter.fsSeen); err != nil {
			return err
		}
	}
	if exporter.cfg.modeEnabled(auditModeExec) {
		pruneTimestampMap(exporter.execSeen, dedupeCutoff)
		pruneTimestampMap(exporter.seenExecutables, nowTS-float64(exporter.lookbackDays*86400))
		if err := saveJSON(exporter.execSeenPath(), exporter.execSeen); err != nil {
			return err
		}
		if err := saveJSON(exporter.seenExecPath(), exporter.seenExecutables); err != nil {
			return err
		}
	}
	if exporter.cfg.modeEnabled(auditModeNet) {
		pruneTimestampMap(exporter.netSeen, dedupeCutoff)
		if err := saveJSON(exporter.netSeenPath(), exporter.netSeen); err != nil {
			return err
		}
	}
	if cache, dirty := exporter.geoResolver.snapshotDirty(); dirty {
		if err := saveJSON(exporter.geoCachePath(), cache); err != nil {
			return err
		}
	}
	exporter.heavyStateDirty = false
	exporter.lastFullSave = time.Now().UTC()
	return nil
}

func (exporter *auditStreamExporter) saveCheckpoint() error {
	if err := os.MkdirAll(exporter.stateDir, 0o750); err != nil {
		return fmt.Errorf("mkdir %s: %w", exporter.stateDir, err)
	}

	safeTs := exporter.safeTimestamp()
	if err := writeFileAtomic(exporter.stateFilePath(), []byte(strconv.FormatInt(int64(safeTs), 10)+"\n"), 0o640); err != nil {
		return err
	}
	if err := saveJSON(exporter.spoolOffsetsPath(), exporter.snapshotSpoolOffsets()); err != nil {
		return err
	}
	exporter.stateDirty = false
	return nil
}

func (exporter *auditStreamExporter) saveStateIfDirty() error {
	if !exporter.stateDirty && !exporter.heavyStateDirty && !exporter.geoResolver.isDirty() {
		return nil
	}
	if exporter.heavyStateDirty || exporter.geoResolver.isDirty() {
		if time.Since(exporter.lastFullSave) >= exporter.cfg.fullStateInterval {
			return exporter.saveState()
		}
	}
	if exporter.stateDirty {
		return exporter.saveCheckpoint()
	}
	return nil
}

func (exporter *auditStreamExporter) safeTimestamp() float64 {
	var safeTs float64
	first := true
	for _, buffer := range exporter.buffers {
		if first || buffer.flushedThrough < safeTs {
			safeTs = buffer.flushedThrough
			first = false
		}
	}
	if first {
		return float64(time.Now().UTC().Unix())
	}
	return safeTs
}

func (exporter *auditStreamExporter) setAllFlushedThrough(ts float64) {
	for _, buffer := range exporter.buffers {
		buffer.flushedThrough = ts
		buffer.lastFlush = time.Now().UTC()
	}
	exporter.markStateDirty()
}

func (exporter *auditStreamExporter) loadRuntimeState(now time.Time) error {
	var err error
	if exporter.cfg.modeEnabled(auditModeFS) {
		if exporter.fsSeen, err = loadTimestampMap(exporter.fsSeenPath()); err != nil {
			return err
		}
	} else {
		exporter.fsSeen = map[string]float64{}
	}
	if exporter.cfg.modeEnabled(auditModeExec) {
		if exporter.execSeen, err = loadTimestampMap(exporter.execSeenPath()); err != nil {
			return err
		}
		if exporter.seenExecutables, err = loadTimestampMap(exporter.seenExecPath()); err != nil {
			return err
		}
	} else {
		exporter.execSeen = map[string]float64{}
		exporter.seenExecutables = map[string]float64{}
	}
	if exporter.cfg.modeEnabled(auditModeNet) {
		if exporter.netSeen, err = loadTimestampMap(exporter.netSeenPath()); err != nil {
			return err
		}
	} else {
		exporter.netSeen = map[string]float64{}
	}
	if exporter.spoolOffsets, err = loadOffsetMap(exporter.spoolOffsetsPath()); err != nil {
		return err
	}
	cache, err := loadGeoCache(exporter.geoCachePath())
	if err != nil {
		return err
	}
	exporter.geoResolver.replaceCache(cache)

	nowTS := float64(now.Unix())
	dedupeCutoff := nowTS - exporter.dedupeRetention.Seconds()
	if exporter.cfg.modeEnabled(auditModeFS) {
		pruneTimestampMap(exporter.fsSeen, dedupeCutoff)
	}
	if exporter.cfg.modeEnabled(auditModeExec) {
		pruneTimestampMap(exporter.execSeen, dedupeCutoff)
		pruneTimestampMap(exporter.seenExecutables, nowTS-float64(exporter.lookbackDays*86400))
	}
	if exporter.cfg.modeEnabled(auditModeNet) {
		pruneTimestampMap(exporter.netSeen, dedupeCutoff)
	}
	exporter.geoResolver.prune(now)
	exporter.stateDirty = false
	exporter.heavyStateDirty = false
	exporter.lastFullSave = now
	return nil
}

func (exporter *auditStreamExporter) drainRawAuditEvents(input <-chan auditRawEventGroup, limit int) error {
	if limit <= 0 {
		return nil
	}
	for drained := 0; drained < limit; drained++ {
		select {
		case event := <-input:
			if err := exporter.handleLiveRawAuditEventGroup(event); err != nil {
				return err
			}
		default:
			return nil
		}
	}
	return nil
}

func (exporter *auditStreamExporter) normalizeSpoolLoop(ctx context.Context, output chan<- auditEvent, errors chan<- error) {
	for {
		if ctx.Err() != nil {
			return
		}
		if err := exporter.processSpool(ctx, output); err != nil {
			select {
			case errors <- err:
			case <-ctx.Done():
			}
			return
		}
		if !sleepContext(ctx, auditSpoolPollInterval) {
			return
		}
	}
}

func (exporter *auditStreamExporter) processSpool(ctx context.Context, output chan<- auditEvent) error {
	paths, err := exporter.spoolPaths()
	if err != nil {
		return err
	}

	for _, path := range paths {
		mode, ok := spoolModeFromPath(path)
		if !ok {
			if err := exporter.dropSpoolFile(path); err != nil {
				return err
			}
			continue
		}
		if !exporter.cfg.modeEnabled(mode) {
			if err := exporter.dropSpoolFile(path); err != nil {
				return err
			}
			continue
		}
		offset := exporter.spoolOffset(path)
		newOffset, err := exporter.streamAuditGroupsAtOffset(path, offset, func(wrapper auditEventGroup) error {
			event, _, ok := exporter.normalizeEnabledAuditEvent(wrapper)
			if !ok {
				return nil
			}
			select {
			case output <- event:
			case <-ctx.Done():
				return ctx.Err()
			}
			return nil
		})
		if err != nil {
			if errors.Is(err, context.Canceled) {
				return nil
			}
			return err
		}
		if newOffset > offset {
			exporter.setSpoolOffset(path, newOffset)
		}
	}

	return exporter.pruneProcessedSpoolFiles()
}

func (exporter *auditStreamExporter) handleLiveRawAuditEventGroup(group auditRawEventGroup) error {
	if len(group.Lines) == 0 {
		return nil
	}
	event, mode, ok := exporter.normalizeEnabledRawAuditEventGroup(group)
	if !ok {
		return nil
	}
	path, offset, err := exporter.writeRawAuditEventGroup(mode, group)
	if err != nil {
		return err
	}
	exporter.enqueueEvent(event)
	exporter.setSpoolOffset(path, offset)
	return nil
}

func (exporter *auditStreamExporter) writeRawAuditEventGroup(mode auditMode, group auditRawEventGroup) (string, int64, error) {
	path := exporter.spoolPathForTimestamp(mode, group.Timestamp)
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return "", 0, fmt.Errorf("mkdir %s: %w", filepath.Dir(path), err)
	}

	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o640)
	if err != nil {
		return "", 0, fmt.Errorf("open raw audit spool: %w", err)
	}
	defer file.Close()

	payload := strings.Join(group.Lines, "\n") + "\n"
	startOffset, err := file.Seek(0, io.SeekEnd)
	if err != nil {
		return "", 0, fmt.Errorf("seek raw audit spool: %w", err)
	}
	if _, err := file.WriteString(payload); err != nil {
		return "", 0, fmt.Errorf("append raw audit spool: %w", err)
	}
	exporter.markStateDirty()
	return path, startOffset + int64(len(payload)), nil
}

func (exporter *auditStreamExporter) spoolPathForTimestamp(mode auditMode, timestamp float64) string {
	date := time.Unix(int64(timestamp), 0).UTC().Format("20060102")
	return filepath.Join(exporter.spoolDirPath(), fmt.Sprintf("audit-live-%s-%s.log", mode, date))
}

func spoolModeFromPath(path string) (auditMode, bool) {
	name := filepath.Base(path)
	if !strings.HasPrefix(name, "audit-live-") || !strings.HasSuffix(name, ".log") {
		return "", false
	}
	trimmed := strings.TrimSuffix(strings.TrimPrefix(name, "audit-live-"), ".log")
	parts := strings.Split(trimmed, "-")
	if len(parts) < 2 {
		return "", false
	}
	return parseAuditMode(parts[0])
}

func (exporter *auditStreamExporter) spoolPaths() ([]string, error) {
	entries, err := os.ReadDir(exporter.spoolDirPath())
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read spool dir: %w", err)
	}

	paths := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if !strings.HasPrefix(entry.Name(), "audit-live-") || !strings.HasSuffix(entry.Name(), ".log") {
			continue
		}
		paths = append(paths, filepath.Join(exporter.spoolDirPath(), entry.Name()))
	}
	sort.Strings(paths)
	return paths, nil
}

func (exporter *auditStreamExporter) cleanupDisabledModeState() error {
	disabledPaths := []string{}
	if !exporter.cfg.modeEnabled(auditModeFS) {
		disabledPaths = append(disabledPaths, exporter.fsSeenPath())
	}
	if !exporter.cfg.modeEnabled(auditModeExec) {
		disabledPaths = append(disabledPaths, exporter.execSeenPath(), exporter.seenExecPath())
	}
	if !exporter.cfg.modeEnabled(auditModeNet) {
		disabledPaths = append(disabledPaths, exporter.netSeenPath())
	}
	for _, path := range disabledPaths {
		if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("remove disabled state %s: %w", path, err)
		}
	}
	spoolPaths, err := exporter.spoolPaths()
	if err != nil {
		return err
	}
	for _, path := range spoolPaths {
		mode, ok := spoolModeFromPath(path)
		if !ok {
			if err := exporter.dropSpoolFile(path); err != nil {
				return err
			}
			continue
		}
		if exporter.cfg.modeEnabled(mode) {
			continue
		}
		if err := exporter.dropSpoolFile(path); err != nil {
			return err
		}
	}
	return nil
}

func (exporter *auditStreamExporter) spoolOffset(path string) int64 {
	exporter.spoolMu.RLock()
	defer exporter.spoolMu.RUnlock()
	return exporter.spoolOffsets[path]
}

func (exporter *auditStreamExporter) setSpoolOffset(path string, offset int64) {
	exporter.spoolMu.Lock()
	defer exporter.spoolMu.Unlock()
	if current, ok := exporter.spoolOffsets[path]; ok && current == offset {
		return
	}
	exporter.spoolOffsets[path] = offset
	exporter.stateDirty = true
}

func (exporter *auditStreamExporter) removeSpoolOffset(path string) {
	exporter.spoolMu.Lock()
	defer exporter.spoolMu.Unlock()
	if _, ok := exporter.spoolOffsets[path]; !ok {
		return
	}
	delete(exporter.spoolOffsets, path)
	exporter.stateDirty = true
}

func (exporter *auditStreamExporter) snapshotSpoolOffsets() map[string]int64 {
	exporter.spoolMu.RLock()
	defer exporter.spoolMu.RUnlock()

	snapshot := make(map[string]int64, len(exporter.spoolOffsets))
	for path, offset := range exporter.spoolOffsets {
		snapshot[path] = offset
	}
	return snapshot
}

func (exporter *auditStreamExporter) pruneProcessedSpoolFiles() error {
	paths, err := exporter.spoolPaths()
	if err != nil {
		return err
	}

	currentPaths := map[string]struct{}{}
	nowTS := float64(time.Now().UTC().Unix())
	for _, mode := range exporter.cfg.enabledModesList() {
		currentPaths[exporter.spoolPathForTimestamp(mode, nowTS)] = struct{}{}
	}
	for _, path := range paths {
		if _, ok := currentPaths[path]; ok {
			continue
		}
		info, err := os.Stat(path)
		if errors.Is(err, os.ErrNotExist) {
			exporter.removeSpoolOffset(path)
			continue
		}
		if err != nil {
			return fmt.Errorf("stat spool file: %w", err)
		}
		if exporter.spoolOffset(path) < info.Size() {
			continue
		}
		if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("remove spool file: %w", err)
		}
		exporter.removeSpoolOffset(path)
	}
	return nil
}

func (exporter *auditStreamExporter) dropSpoolFile(path string) error {
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove spool file: %w", err)
	}
	exporter.removeSpoolOffset(path)
	return nil
}

func (exporter *auditStreamExporter) bufferHasPending(buffer *auditModeBuffer) bool {
	return buffer != nil && (len(buffer.rawRecords) > 0 || len(buffer.anomalies) > 0 || buffer.windowCount > 0)
}

func (exporter *auditStreamExporter) markWindowEvent(buffer *auditModeBuffer, timestamp float64) {
	if buffer.windowStart == 0 || timestamp < buffer.windowStart {
		buffer.windowStart = timestamp
	}
	if timestamp > buffer.windowEnd {
		buffer.windowEnd = timestamp
	}
}

func (exporter *auditStreamExporter) newProcessGroupMap(mode auditMode) map[string]*groupedProcessCount {
	switch mode {
	case auditModeFS, auditModeNet:
		return map[string]*groupedProcessCount{}
	default:
		return nil
	}
}

func (exporter *auditStreamExporter) buildPreparedSummaries(buffer *auditModeBuffer) []map[string]any {
	windowStart, windowEnd := auditSummaryWindowFromBounds(buffer.windowStart, buffer.windowEnd)
	switch buffer.mode {
	case auditModeFS:
		return append(
			[]map[string]any{newAuditSummary("audit_fs_summary", "window_total", windowStart, windowEnd, buffer.windowCount, nil)},
			groupedAuditSummaries("audit_fs_summary", "by_path_process", windowStart, windowEnd, buffer.summaryGroups)...,
		)
	case auditModeExec:
		return append(
			[]map[string]any{newAuditSummary("audit_exec_summary", "window_total", windowStart, windowEnd, buffer.windowCount, nil)},
			groupedAuditSummaries("audit_exec_summary", "by_exe", windowStart, windowEnd, buffer.summaryGroups)...,
		)
	case auditModeNet:
		return append(
			[]map[string]any{newAuditSummary("audit_net_summary", "window_total", windowStart, windowEnd, buffer.windowCount, nil)},
			groupedAuditSummaries("audit_net_summary", "by_endpoint_process", windowStart, windowEnd, buffer.summaryGroups)...,
		)
	default:
		return nil
	}
}

func (exporter *auditStreamExporter) prepareAnomalies(buffer *auditModeBuffer) []map[string]any {
	anomalies := append([]map[string]any{}, buffer.anomalies...)

	switch buffer.mode {
	case auditModeFS:
		for signature, group := range buffer.processGroups {
			if group.Count < buffer.threshold {
				continue
			}
			anomalies = append(anomalies, buildAnomaly(
				group.EventTime,
				"write_burst",
				"warning",
				"audit_fs",
				fmt.Sprintf("%s touched %d watched paths in one export window", signature, group.Count),
				map[string]any{
					"count": group.Count,
					"exe":   group.Exe,
					"comm":  group.Comm,
				},
			))
		}
	case auditModeNet:
		for signature, group := range buffer.processGroups {
			if group.Count < buffer.threshold {
				continue
			}
			anomalies = append(anomalies, buildAnomaly(
				group.EventTime,
				"connect_burst",
				"warning",
				"audit_net",
				fmt.Sprintf("%s opened %d network connections in one export window", signature, group.Count),
				map[string]any{
					"count": group.Count,
					"exe":   group.Exe,
					"comm":  group.Comm,
				},
			))
		}
	}

	return anomalies
}

func (exporter *auditStreamExporter) processFSEvent(buffer *auditModeBuffer, event auditEvent) {
	if len(event.Paths) == 0 {
		return
	}

	base := baseProcessRecord(event)
	base["kind"] = "audit_fs_event"
	addOptionalString(base, "key", cleanControl(event.Key))
	addOptionalString(base, "cwd", cleanControl(event.Cwd))

	for _, item := range event.Paths {
		if item.Path == "" {
			continue
		}
		watchedRoot := watchedRootFor(item.Path, exporter.cfg.watchPaths)
		if watchedRoot == "" {
			continue
		}
		dedupeKey := fmt.Sprintf("%d:%s:%s", event.Serial, item.Path, item.NameType)
		if seenRecently(exporter.fsSeen, dedupeKey, event.Timestamp) {
			continue
		}
		exporter.fsSeen[dedupeKey] = event.Timestamp
		exporter.markHeavyStateDirty()

		scope := "system"
		if _, ok := exporter.cfg.homeWatchPaths[watchedRoot]; ok {
			scope = "home"
		}

		record := cloneRecord(base)
		record["scope"] = scope
		record["watched_root"] = watchedRoot
		record["path"] = item.Path
		addOptionalString(record, "nametype", cleanControl(item.NameType))
		addOptionalInt(record, "item", item.Item)
		buffer.rawRecords = append(buffer.rawRecords, record)
		buffer.windowCount++

		signature := firstNonEmpty(anyToString(record["exe"]), anyToString(record["comm"]), "unknown")
		group := ensureGroupedCount(buffer.processGroups, signature, anyToString(record["event_time"]), anyToString(record["exe"]), anyToString(record["comm"]))
		group.Count++
		group.EventTime = anyToString(record["event_time"])

		summaryKey := strings.Join([]string{
			anyToString(record["exe"]),
			anyToString(record["comm"]),
			anyToString(record["path"]),
			anyToString(record["watched_root"]),
			anyToString(record["scope"]),
		}, "\x00")
		summary := ensureAuditSummary(buffer.summaryGroups, summaryKey, map[string]any{
			"exe":          anyToString(record["exe"]),
			"comm":         anyToString(record["comm"]),
			"path":         anyToString(record["path"]),
			"watched_root": anyToString(record["watched_root"]),
			"scope":        anyToString(record["scope"]),
		})
		summary.Count++
	}
}

func (exporter *auditStreamExporter) processExecEvent(buffer *auditModeBuffer, event auditEvent) {
	dedupeKey := strconv.Itoa(event.Serial)
	if seenRecently(exporter.execSeen, dedupeKey, event.Timestamp) {
		return
	}
	exporter.execSeen[dedupeKey] = event.Timestamp
	exporter.markHeavyStateDirty()

	record := baseProcessRecord(event)
	record["kind"] = "audit_exec_event"
	addOptionalInt(record, "argc", event.Argc)
	addOptionalString(record, "argv", cleanControl(event.Argv))
	buffer.rawRecords = append(buffer.rawRecords, record)
	buffer.windowCount++

	summaryKey := strings.Join([]string{
		anyToString(record["exe"]),
		anyToString(record["comm"]),
		anyToString(record["cmdline"]),
	}, "\x00")
	summary := ensureAuditSummary(buffer.summaryGroups, summaryKey, map[string]any{
		"exe":     anyToString(record["exe"]),
		"comm":    anyToString(record["comm"]),
		"cmdline": anyToString(record["cmdline"]),
	})
	summary.Count++

	exe := anyToString(record["exe"])
	if exe == "" {
		return
	}
	if _, ok := exporter.seenExecutables[exe]; ok {
		return
	}
	exporter.seenExecutables[exe] = event.Timestamp
	exporter.markHeavyStateDirty()
	buffer.anomalies = append(buffer.anomalies, buildAnomaly(
		anyToString(record["event_time"]),
		"new_executable",
		"info",
		"audit_exec",
		fmt.Sprintf("first seen executable: %s", exe),
		map[string]any{
			"exe":     exe,
			"comm":    record["comm"],
			"pid":     record["pid"],
			"cmdline": record["cmdline"],
		},
	))
}

func (exporter *auditStreamExporter) processNetEvent(buffer *auditModeBuffer, event auditEvent) {
	dedupeKey := strconv.Itoa(event.Serial)
	if seenRecently(exporter.netSeen, dedupeKey, event.Timestamp) {
		return
	}
	exporter.netSeen[dedupeKey] = event.Timestamp
	exporter.markHeavyStateDirty()

	sockaddr := map[string]string{}
	for _, item := range event.SockAddrs {
		if len(item) > 0 {
			sockaddr = item
			break
		}
	}

	family := cleanControl(sockaddr["saddr_fam"])
	destIP := normalizeLookupIP(firstNonEmpty(sockaddr["daddr"], sockaddr["faddr"], sockaddr["raddr"], sockaddr["addr"], sockaddr["laddr"]))
	rawDestPort := firstNonEmpty(sockaddr["dport"], sockaddr["fport"], sockaddr["rport"], sockaddr["port"], sockaddr["lport"])
	destPort := parseOptionalInt(rawDestPort)
	if destPort != nil && (*destPort == 0 || *destPort == 65535) {
		destPort = nil
	}
	unixPath := cleanControl(sockaddr["path"])
	if family == "" && unixPath != "" {
		family = "local"
	}

	endpointKey, fallbackTarget := buildEndpointIdentity(family, destIP, destPort, unixPath)
	geo := exporter.geoResolver.lookup(destIP)
	if destIP != "" && geo.isExpired(time.Now().UTC()) {
		exporter.geoResolver.enqueueLookup(destIP)
	}
	destTarget := firstNonEmpty(geo.Host, fallbackTarget)

	record := baseProcessRecord(event)
	record["kind"] = "audit_net_event"
	addOptionalString(record, "family", family)
	addOptionalString(record, "dest_ip", destIP)
	addOptionalInt(record, "dest_port", destPort)
	addOptionalString(record, "unix_path", unixPath)
	addOptionalString(record, "endpoint_key", endpointKey)
	addOptionalString(record, "country_code", geo.CountryCode)
	addOptionalString(record, "country_name", geo.CountryName)
	addOptionalString(record, "dest_host", geo.Host)
	addOptionalString(record, "dest_target", destTarget)
	buffer.rawRecords = append(buffer.rawRecords, record)
	buffer.windowCount++

	signature := firstNonEmpty(anyToString(record["exe"]), anyToString(record["comm"]), "unknown")
	group := ensureGroupedCount(buffer.processGroups, signature, anyToString(record["event_time"]), anyToString(record["exe"]), anyToString(record["comm"]))
	group.Count++
	group.EventTime = anyToString(record["event_time"])

	summaryKey := strings.Join([]string{
		anyToString(record["exe"]),
		anyToString(record["comm"]),
		anyToString(record["endpoint_key"]),
	}, "\x00")
	summary := ensureAuditSummary(buffer.summaryGroups, summaryKey, map[string]any{
		"exe":          anyToString(record["exe"]),
		"comm":         anyToString(record["comm"]),
		"endpoint_key": anyToString(record["endpoint_key"]),
		"dest_target":  anyToString(record["dest_target"]),
		"dest_ip":      anyToString(record["dest_ip"]),
		"family":       anyToString(record["family"]),
		"country_code": anyToString(record["country_code"]),
		"country_name": anyToString(record["country_name"]),
	})
	if destPortValue, ok := record["dest_port"]; ok {
		summary.Fields["dest_port"] = destPortValue
	}
	if destTargetValue := anyToString(record["dest_target"]); destTargetValue != "" {
		summary.Fields["dest_target"] = destTargetValue
	}
	if hostValue := anyToString(record["dest_host"]); hostValue != "" {
		summary.Fields["dest_host"] = hostValue
	}
	if countryCode := anyToString(record["country_code"]); countryCode != "" {
		summary.Fields["country_code"] = countryCode
	}
	if countryName := anyToString(record["country_name"]); countryName != "" {
		summary.Fields["country_name"] = countryName
	}
	summary.Count++

}

func (exporter *auditStreamExporter) fsSeenPath() string {
	return filepath.Join(exporter.stateDir, "audit-fs-seen.json")
}

func (exporter *auditStreamExporter) execSeenPath() string {
	return filepath.Join(exporter.stateDir, "audit-exec-seen.json")
}

func (exporter *auditStreamExporter) netSeenPath() string {
	return filepath.Join(exporter.stateDir, "audit-net-seen.json")
}

func (exporter *auditStreamExporter) seenExecPath() string {
	return filepath.Join(exporter.stateDir, "seen-executables.json")
}

func (exporter *auditStreamExporter) geoCachePath() string {
	return filepath.Join(exporter.stateDir, "geoip-cache.json")
}

func newAuditGeoResolver(cfg auditConfig) *auditGeoResolver {
	return &auditGeoResolver{
		cfg:     cfg,
		cache:   map[string]geoRecord{},
		pending: map[string]struct{}{},
		queue:   make(chan string, 256),
	}
}

func (resolver *auditGeoResolver) start(ctx context.Context) {
	go resolver.loop(ctx)
}

func (resolver *auditGeoResolver) loop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case ip := <-resolver.queue:
			record := resolveGeoRecord(ctx, resolver.cfg, ip)
			resolver.mu.Lock()
			delete(resolver.pending, ip)
			resolver.cache[ip] = record
			resolver.dirty = true
			resolver.mu.Unlock()
		}
	}
}

func (resolver *auditGeoResolver) replaceCache(cache map[string]geoRecord) {
	resolver.mu.Lock()
	defer resolver.mu.Unlock()
	resolver.cache = cache
}

func (resolver *auditGeoResolver) lookup(ip string) geoRecord {
	normalized := normalizeLookupIP(ip)
	if normalized == "" {
		return geoRecord{}
	}
	resolver.mu.RLock()
	record := resolver.cache[normalized]
	resolver.mu.RUnlock()
	record.CountryCode = cleanControl(record.CountryCode)
	record.CountryName = cleanControl(record.CountryName)
	record.Host = cleanControl(record.Host)
	return record
}

func (resolver *auditGeoResolver) enqueueLookup(ip string) {
	normalized := normalizeLookupIP(ip)
	if normalized == "" {
		return
	}

	resolver.mu.Lock()
	if _, ok := resolver.pending[normalized]; ok {
		resolver.mu.Unlock()
		return
	}
	resolver.pending[normalized] = struct{}{}
	resolver.mu.Unlock()

	select {
	case resolver.queue <- normalized:
	default:
		resolver.mu.Lock()
		delete(resolver.pending, normalized)
		resolver.mu.Unlock()
	}
}

func (resolver *auditGeoResolver) snapshotDirty() (map[string]geoRecord, bool) {
	resolver.mu.Lock()
	defer resolver.mu.Unlock()
	if !resolver.dirty {
		return nil, false
	}
	snapshot := make(map[string]geoRecord, len(resolver.cache))
	for ip, record := range resolver.cache {
		snapshot[ip] = record
	}
	resolver.dirty = false
	return snapshot, true
}

func (resolver *auditGeoResolver) isDirty() bool {
	resolver.mu.RLock()
	defer resolver.mu.RUnlock()
	return resolver.dirty
}

func (resolver *auditGeoResolver) prune(now time.Time) {
	resolver.mu.Lock()
	defer resolver.mu.Unlock()

	changed := false
	for ip, record := range resolver.cache {
		if !record.isExpired(now) {
			continue
		}
		delete(resolver.cache, ip)
		changed = true
	}
	if changed {
		resolver.dirty = true
	}
}

func resolveGeoRecord(parent context.Context, cfg auditConfig, ip string) geoRecord {
	record := geoRecord{
		LastResolved: float64(time.Now().UTC().Unix()),
	}

	if normalized := normalizeLookupIP(ip); normalized == "" {
		return record
	}

	hostCtx, cancel := context.WithTimeout(parent, geoLookupTimeout)
	defer cancel()

	if hosts, err := net.DefaultResolver.LookupAddr(hostCtx, ip); err == nil && len(hosts) > 0 {
		record.Host = strings.TrimSuffix(hosts[0], ".")
	}

	if anycast := detectAnycastLocation(ip, record.Host); anycast != "" {
		record.CountryName = anycast
		return record
	}

	if record.CountryCode == "" {
		record.CountryCode = mmdbLookupValue(hostCtx, cfg, ip, "country", "iso_code")
	}
	if record.CountryCode != "" && record.CountryName == "" {
		record.CountryName = mmdbLookupValue(hostCtx, cfg, ip, "country", "names", "en")
	}
	return record
}

func (record geoRecord) isExpired(now time.Time) bool {
	if record.LastResolved == 0 {
		return true
	}
	resolvedAt := time.Unix(int64(record.LastResolved), 0)
	ttl := geoNegativeCacheTTL
	if record.Host != "" || record.CountryCode != "" || record.CountryName != "" {
		ttl = geoPositiveCacheTTL
	}
	return now.After(resolvedAt.Add(ttl))
}

func maxInt(left int, right int) int {
	if left > right {
		return left
	}
	return right
}

func (exporter *auditStreamExporter) markStateDirty() {
	exporter.stateDirty = true
}

func (exporter *auditStreamExporter) markHeavyStateDirty() {
	exporter.heavyStateDirty = true
	exporter.stateDirty = true
}

func normalizeRawAuditEventGroup(group auditRawEventGroup) (auditEvent, bool) {
	wrapper := auditEventGroup{
		Serial:    group.Serial,
		Timestamp: group.Timestamp,
		Records:   make([]parsedAuditLine, 0, len(group.Lines)),
	}
	for _, line := range group.Lines {
		parsed, ok := parseAuditLine(line)
		if !ok {
			continue
		}
		wrapper.Timestamp = parsed.Timestamp
		wrapper.Records = append(wrapper.Records, parsed)
	}
	if len(wrapper.Records) == 0 {
		return auditEvent{}, false
	}
	return normalizeAuditEvent(wrapper), true
}

func (exporter *auditStreamExporter) normalizeEnabledRawAuditEventGroup(group auditRawEventGroup) (auditEvent, auditMode, bool) {
	event, ok := normalizeRawAuditEventGroup(group)
	if !ok {
		return auditEvent{}, "", false
	}
	mode := eventMode(event)
	if mode == "" || !exporter.cfg.modeEnabled(mode) {
		return auditEvent{}, "", false
	}
	return event, mode, true
}

func (exporter *auditStreamExporter) normalizeEnabledAuditEvent(wrapper auditEventGroup) (auditEvent, auditMode, bool) {
	event := normalizeAuditEvent(wrapper)
	mode := eventMode(event)
	if mode == "" || !exporter.cfg.modeEnabled(mode) {
		return auditEvent{}, "", false
	}
	return event, mode, true
}

func (exporter *auditStreamExporter) streamAuditGroups(reader io.Reader, onGroup func(auditEventGroup) error) error {
	scanner := bufio.NewScanner(reader)
	return scanAuditEventGroups(scanner, onGroup)
}

func (exporter *auditStreamExporter) streamAuditGroupsAtOffset(path string, startOffset int64, onGroup func(auditEventGroup) error) (int64, error) {
	return scanAuditEventGroupsAtOffset(path, startOffset, onGroup)
}

func loadTimestampMap(path string) (map[string]float64, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]float64{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}

	result := map[string]float64{}
	if err := json.Unmarshal(data, &result); err != nil {
		quarantineCorruptFile(path, err)
		return map[string]float64{}, nil
	}
	return result, nil
}

func pruneTimestampMap(values map[string]float64, cutoff float64) {
	for key, timestamp := range values {
		if timestamp >= cutoff {
			continue
		}
		delete(values, key)
	}
}

func seenRecently(values map[string]float64, key string, timestamp float64) bool {
	seenAt, ok := values[key]
	return ok && seenAt >= timestamp
}

func auditSummaryWindowFromBounds(windowStart float64, windowEnd float64) (string, string) {
	if windowStart == 0 || windowEnd == 0 {
		now := formatUTCMicros(time.Now().UTC())
		return now, now
	}
	return isoTimestamp(windowStart), isoTimestamp(windowEnd)
}

func buildEndpointIdentity(family string, destIP string, destPort *int, unixPath string) (string, string) {
	switch {
	case unixPath != "":
		return "unix:" + unixPath, unixPath
	case family == "inet6" && destIP != "" && destPort != nil:
		target := fmt.Sprintf("[%s]:%d", destIP, *destPort)
		return "ip:" + target, target
	case destIP != "" && destPort != nil:
		target := fmt.Sprintf("%s:%d", destIP, *destPort)
		return "ip:" + target, target
	case destIP != "":
		return "ip:" + destIP, destIP
	default:
		return "", ""
	}
}

func (exporter *auditStreamExporter) modeOutputPath(mode auditMode, now time.Time) string {
	return filepath.Join(exporter.logDir, fmt.Sprintf("audit-%s-%s.ndjson", mode, now.Format("20060102")))
}

func (exporter *auditStreamExporter) anomalyOutputPath(now time.Time) string {
	return filepath.Join(exporter.logDir, fmt.Sprintf("anomaly-%s.ndjson", now.Format("20060102")))
}

func (exporter *auditStreamExporter) summaryOutputPath(mode auditMode, now time.Time) string {
	return filepath.Join(exporter.logDir, fmt.Sprintf("audit-%s-summary-%s.ndjson", mode, now.Format("20060102")))
}

func sleepContext(ctx context.Context, delay time.Duration) bool {
	timer := time.NewTimer(delay)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}

func loadAuditConfigFromEnv() (auditConfig, error) {
	cfg := auditConfig{
		homeWatchPaths: map[string]struct{}{},
		enabledModes: map[auditMode]struct{}{
			auditModeFS:   {},
			auditModeExec: {},
			auditModeNet:  {},
		},
		mmdbLookupBin:         os.Getenv("CORE_MONITORING_MMDBLOOKUP_BIN"),
		countryDB:             os.Getenv("CORE_MONITORING_COUNTRY_DB"),
		stateSyncInterval:     defaultStateSyncInterval,
		fullStateInterval:     defaultFullStateInterval,
		streamChannelCapacity: 256,
	}

	var watchPaths []string
	if err := json.Unmarshal([]byte(os.Getenv("CORE_MONITORING_WATCH_PATHS_JSON")), &watchPaths); err != nil {
		return auditConfig{}, fmt.Errorf("parse watch paths: %w", err)
	}
	for _, path := range watchPaths {
		cfg.watchPaths = append(cfg.watchPaths, filepath.Clean(path))
	}

	var homeWatchPaths []string
	if err := json.Unmarshal([]byte(os.Getenv("CORE_MONITORING_HOME_WATCH_PATHS_JSON")), &homeWatchPaths); err != nil {
		return auditConfig{}, fmt.Errorf("parse home watch paths: %w", err)
	}
	for _, path := range homeWatchPaths {
		cfg.homeWatchPaths[filepath.Clean(path)] = struct{}{}
	}

	if raw := strings.TrimSpace(os.Getenv("CORE_MONITORING_STREAM_CHANNEL_CAPACITY")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil {
			return auditConfig{}, fmt.Errorf("parse stream channel capacity: %w", err)
		}
		if value <= 0 {
			return auditConfig{}, fmt.Errorf("parse stream channel capacity: must be positive")
		}
		cfg.streamChannelCapacity = value
	}

	if raw := strings.TrimSpace(os.Getenv("CORE_MONITORING_ENABLED_AUDIT_MODES")); raw != "" {
		var enabledModes []string
		if err := json.Unmarshal([]byte(raw), &enabledModes); err != nil {
			return auditConfig{}, fmt.Errorf("parse enabled audit modes: %w", err)
		}
		cfg.enabledModes = map[auditMode]struct{}{}
		for _, value := range enabledModes {
			mode, ok := parseAuditMode(value)
			if !ok {
				return auditConfig{}, fmt.Errorf("parse enabled audit modes: unsupported mode %q", value)
			}
			cfg.enabledModes[mode] = struct{}{}
		}
	}

	if raw := strings.TrimSpace(os.Getenv("CORE_MONITORING_STATE_SYNC_INTERVAL_SECONDS")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil {
			return auditConfig{}, fmt.Errorf("parse state sync interval: %w", err)
		}
		if value <= 0 {
			return auditConfig{}, fmt.Errorf("parse state sync interval: must be positive")
		}
		cfg.stateSyncInterval = time.Duration(value) * time.Second
	}
	if raw := strings.TrimSpace(os.Getenv("CORE_MONITORING_FULL_STATE_SYNC_INTERVAL_SECONDS")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil {
			return auditConfig{}, fmt.Errorf("parse full state sync interval: %w", err)
		}
		if value <= 0 {
			return auditConfig{}, fmt.Errorf("parse full state sync interval: must be positive")
		}
		cfg.fullStateInterval = time.Duration(value) * time.Second
	}

	return cfg, nil
}

type parsedAuditLine struct {
	Timestamp float64
	Serial    int
	Type      string
	Fields    map[string]string
	Extra     map[string]string
}

type auditEventGroup struct {
	Serial    int
	Timestamp float64
	Records   []parsedAuditLine
}

type auditPathRecord struct {
	Path     string
	NameType string
	Item     *int
}

type auditEvent struct {
	Serial    int
	Timestamp float64
	PID       *int
	PPID      *int
	UID       *int
	AUID      *int
	SES       *int
	Comm      string
	Exe       string
	Success   string
	Key       string
	Syscall   string
	Argc      *int
	Argv      string
	Proctitle string
	Cwd       string
	Cmdline   string
	Paths     []auditPathRecord
	SockAddrs []map[string]string
}

func collectAuditEvents(inputPath string) ([]auditEventGroup, error) {
	file, err := os.Open(inputPath)
	if err != nil {
		return nil, fmt.Errorf("open audit input: %w", err)
	}
	defer file.Close()

	var events []auditEventGroup
	if err := scanAuditEventGroups(bufio.NewScanner(file), func(group auditEventGroup) error {
		events = append(events, group)
		return nil
	}); err != nil {
		return nil, err
	}
	return events, nil
}

func collectAuditEventsDelta(inputPath string, startOffset int64) ([]auditEventGroup, int64, error) {
	var events []auditEventGroup
	offset, err := scanAuditEventGroupsAtOffset(inputPath, startOffset, func(group auditEventGroup) error {
		events = append(events, group)
		return nil
	})
	if err != nil {
		return nil, startOffset, err
	}
	return events, offset, nil
}

func scanAuditEventGroups(scanner *bufio.Scanner, onGroup func(auditEventGroup) error) error {
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
	var current *auditEventGroup
	emitCurrent := func() error {
		if current == nil {
			return nil
		}
		group := *current
		current = nil
		return onGroup(group)
	}

	for scanner.Scan() {
		parsed, ok := parseAuditLine(scanner.Text())
		if !ok {
			continue
		}

		if current != nil && parsed.Serial != current.Serial {
			if err := emitCurrent(); err != nil {
				return err
			}
		}

		if current == nil {
			current = &auditEventGroup{
				Serial:    parsed.Serial,
				Timestamp: parsed.Timestamp,
			}
		}
		current.Timestamp = parsed.Timestamp
		current.Records = append(current.Records, parsed)
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("scan audit input: %w", err)
	}
	return emitCurrent()
}

func scanAuditEventGroupsAtOffset(inputPath string, startOffset int64, onGroup func(auditEventGroup) error) (int64, error) {
	file, err := os.Open(inputPath)
	if errors.Is(err, os.ErrNotExist) {
		return startOffset, nil
	}
	if err != nil {
		return startOffset, fmt.Errorf("open audit input: %w", err)
	}
	defer file.Close()

	if _, err := file.Seek(startOffset, io.SeekStart); err != nil {
		return startOffset, fmt.Errorf("seek audit input: %w", err)
	}

	reader := bufio.NewReader(file)
	offset := startOffset
	var current *auditEventGroup
	lastReadEndedWithNewline := true
	emitCurrent := func() error {
		if current == nil {
			return nil
		}
		group := *current
		current = nil
		return onGroup(group)
	}

	for {
		line, err := reader.ReadString('\n')
		if line != "" {
			completeLine := strings.HasSuffix(line, "\n")
			lastReadEndedWithNewline = completeLine
			if completeLine {
				offset += int64(len(line))
				parsed, ok := parseAuditLine(strings.TrimRight(line, "\r\n"))
				if ok {
					if current != nil && parsed.Serial != current.Serial {
						if err := emitCurrent(); err != nil {
							return startOffset, err
						}
					}

					if current == nil {
						current = &auditEventGroup{
							Serial:    parsed.Serial,
							Timestamp: parsed.Timestamp,
						}
					}
					current.Timestamp = parsed.Timestamp
					current.Records = append(current.Records, parsed)
				}
			}
		}

		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return startOffset, fmt.Errorf("scan audit input: %w", err)
		}
	}

	if current != nil && lastReadEndedWithNewline {
		if err := emitCurrent(); err != nil {
			return startOffset, err
		}
	}

	return offset, nil
}

func parseAuditLine(line string) (parsedAuditLine, bool) {
	raw, extra := splitControl(line)
	if raw == "" {
		return parsedAuditLine{}, false
	}

	msgMatch := msgRe.FindStringSubmatch(raw)
	typeMatch := typeRe.FindStringSubmatch(raw)
	if msgMatch == nil || typeMatch == nil {
		return parsedAuditLine{}, false
	}

	timestamp, err := strconv.ParseFloat(msgMatch[1], 64)
	if err != nil {
		return parsedAuditLine{}, false
	}
	serial, err := strconv.Atoi(msgMatch[2])
	if err != nil {
		return parsedAuditLine{}, false
	}

	fields := map[string]string{}
	for _, match := range fieldRe.FindAllStringSubmatch(raw, -1) {
		fields[match[1]] = unquote(match[2])
	}

	return parsedAuditLine{
		Timestamp: timestamp,
		Serial:    serial,
		Type:      typeMatch[1],
		Fields:    fields,
		Extra:     parseExtra(extra),
	}, true
}

func splitControl(line string) (string, string) {
	for _, separator := range []rune{0x1d, 0x1e} {
		if index := strings.IndexRune(line, separator); index >= 0 {
			return strings.TrimSpace(line[:index]), strings.TrimSpace(line[index+1:])
		}
	}
	return strings.TrimSpace(line), ""
}

func unquote(raw string) string {
	if len(raw) < 2 || raw[0] != '"' || raw[len(raw)-1] != '"' {
		return raw
	}
	value, err := strconv.Unquote(raw)
	if err == nil {
		return value
	}
	inner := raw[1 : len(raw)-1]
	return strings.ReplaceAll(strings.ReplaceAll(inner, `\\`, `\`), `\"`, `"`)
}

func parseExtra(text string) map[string]string {
	result := map[string]string{}
	for index := 0; index < len(text); {
		for index < len(text) && isSpace(text[index]) {
			index++
		}
		if index >= len(text) || !strings.ContainsRune(text[index:], '=') {
			break
		}

		keyStart := index
		for index < len(text) && (isAlphaNum(text[index]) || text[index] == '_') {
			index++
		}
		key := text[keyStart:index]
		if key == "" || index >= len(text) || text[index] != '=' {
			for index < len(text) && !isSpace(text[index]) {
				index++
			}
			continue
		}

		index++
		if index >= len(text) {
			result[key] = ""
			break
		}

		switch text[index] {
		case '{':
			depth := 1
			valueStart := index
			index++
			for index < len(text) && depth > 0 {
				switch text[index] {
				case '{':
					depth++
				case '}':
					depth--
				}
				index++
			}
			result[key] = text[valueStart:index]
		case '"':
			valueStart := index
			index++
			escaped := false
			for index < len(text) {
				char := text[index]
				if char == '"' && !escaped {
					index++
					break
				}
				if char == '\\' && !escaped {
					escaped = true
					index++
					continue
				}
				escaped = false
				index++
			}
			result[key] = unquote(text[valueStart:index])
		default:
			valueStart := index
			for index < len(text) && !isSpace(text[index]) {
				index++
			}
			result[key] = text[valueStart:index]
		}
	}
	return result
}

func isSpace(value byte) bool {
	return value == ' ' || value == '\t' || value == '\n' || value == '\r'
}

func isAlphaNum(value byte) bool {
	return (value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z') || (value >= '0' && value <= '9')
}

func normalizeAuditEvents(events []auditEventGroup) []auditEvent {
	normalized := make([]auditEvent, 0, len(events))
	for _, wrapper := range events {
		normalized = append(normalized, normalizeAuditEvent(wrapper))
	}
	return normalized
}

func normalizeAuditEvent(wrapper auditEventGroup) auditEvent {
	event := auditEvent{
		Serial:    wrapper.Serial,
		Timestamp: wrapper.Timestamp,
		Paths:     []auditPathRecord{},
		SockAddrs: []map[string]string{},
	}
	argvParts := map[int]string{}

	for _, record := range wrapper.Records {
		fields := record.Fields
		extra := record.Extra

		switch record.Type {
		case "SYSCALL":
			event.PID = parseOptionalInt(fields["pid"])
			event.PPID = parseOptionalInt(fields["ppid"])
			event.UID = parseOptionalInt(fields["uid"])
			event.AUID = parseOptionalInt(fields["auid"])
			event.SES = parseOptionalInt(fields["ses"])
			event.Comm = fields["comm"]
			event.Exe = fields["exe"]
			event.Success = fields["success"]
			event.Key = fields["key"]
			event.Syscall = firstNonEmpty(extra["SYSCALL"], fields["syscall"])
		case "EXECVE":
			event.Argc = parseOptionalInt(fields["argc"])
			for key, value := range fields {
				match := argvKeyRe.FindStringSubmatch(key)
				if match == nil {
					continue
				}
				index, err := strconv.Atoi(match[1])
				if err != nil {
					continue
				}
				argvParts[index] = value
			}
		case "PROCTITLE":
			event.Proctitle = decodeProctitle(fields["proctitle"])
		case "CWD":
			event.Cwd = fields["cwd"]
		case "PATH":
			event.Paths = append(event.Paths, auditPathRecord{
				Path:     normalizePath(fields["name"], event.Cwd),
				NameType: fields["nametype"],
				Item:     parseOptionalInt(fields["item"]),
			})
		case "SOCKADDR":
			event.SockAddrs = append(event.SockAddrs, parseSocketAddress(extra["SADDR"]))
		}
	}

	if len(argvParts) > 0 {
		indexes := make([]int, 0, len(argvParts))
		for index := range argvParts {
			indexes = append(indexes, index)
		}
		sort.Ints(indexes)

		argvList := make([]string, 0, len(indexes))
		for _, index := range indexes {
			argvList = append(argvList, argvParts[index])
		}
		event.Argv = strings.TrimSpace(strings.Join(argvList, " "))
	}

	if event.Proctitle != "" && event.Cmdline == "" {
		event.Cmdline = event.Proctitle
	} else if event.Argv != "" && event.Cmdline == "" {
		event.Cmdline = event.Argv
	}

	return event
}

func decodeProctitle(raw string) string {
	if raw == "" {
		return ""
	}
	decoded, err := hex.DecodeString(raw)
	if err != nil {
		return raw
	}
	return cleanControl(strings.ReplaceAll(string(decoded), "\x00", " "))
}

func normalizePath(path string, cwd string) string {
	if path == "" || path == "(null)" {
		return ""
	}
	if filepath.IsAbs(path) {
		return filepath.Clean(path)
	}
	if cwd != "" {
		return filepath.Clean(filepath.Join(cwd, path))
	}
	return path
}

func parseSocketAddress(raw string) map[string]string {
	if raw == "" || !strings.HasPrefix(raw, "{") || !strings.HasSuffix(raw, "}") {
		return map[string]string{}
	}
	parsed := map[string]string{}
	for _, match := range socketFieldRe.FindAllStringSubmatch(strings.TrimSpace(raw[1:len(raw)-1]), -1) {
		parsed[strings.ToLower(match[1])] = match[2]
	}
	return parsed
}

func parseOptionalInt(value string) *int {
	if value == "" {
		return nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return nil
	}
	return &parsed
}

func cleanControl(value string) string {
	if value == "" {
		return ""
	}
	return strings.TrimSpace(strings.ReplaceAll(value, "\x00", " "))
}

func decodeHexText(value string) string {
	cleaned := cleanControl(value)
	if cleaned == "" || len(cleaned) < 4 || len(cleaned)%2 != 0 || !hexTextRe.MatchString(cleaned) {
		return cleaned
	}

	decodedBytes, err := hex.DecodeString(cleaned)
	if err != nil {
		return cleaned
	}
	decoded := cleanControl(string(bytes.ReplaceAll(decodedBytes, []byte{0}, []byte(" "))))
	if decoded == "" {
		return cleaned
	}
	for _, char := range decoded {
		if !charIsPrintable(char) && !charIsSpace(char) {
			return cleaned
		}
	}
	return decoded
}

func charIsPrintable(char rune) bool {
	return char >= 32 && char != 127
}

func charIsSpace(char rune) bool {
	return char == ' ' || char == '\n' || char == '\t' || char == '\r'
}

func displayProcessName(event auditEvent) string {
	comm := decodeHexText(event.Comm)
	exe := cleanControl(event.Exe)
	if comm != "" && !allDigits(comm) {
		return comm
	}
	if exe != "" {
		return filepath.Base(exe)
	}
	return comm
}

func allDigits(value string) bool {
	if value == "" {
		return false
	}
	for _, char := range value {
		if char < '0' || char > '9' {
			return false
		}
	}
	return true
}

func baseProcessRecord(event auditEvent) map[string]any {
	record := map[string]any{
		"event_time": isoTimestamp(event.Timestamp),
		"serial":     event.Serial,
	}
	addOptionalInt(record, "pid", event.PID)
	addOptionalInt(record, "ppid", event.PPID)
	addOptionalInt(record, "uid", event.UID)
	addOptionalInt(record, "auid", event.AUID)
	addOptionalInt(record, "ses", event.SES)
	addOptionalString(record, "comm", displayProcessName(event))
	addOptionalString(record, "exe", cleanControl(event.Exe))
	addOptionalString(record, "cmdline", cleanControl(event.Cmdline))
	addOptionalString(record, "proctitle", cleanControl(event.Proctitle))
	addOptionalString(record, "syscall", cleanControl(event.Syscall))
	addOptionalString(record, "success", cleanControl(event.Success))
	return record
}

func addOptionalString(record map[string]any, key string, value string) {
	if value != "" {
		record[key] = value
	}
}

func addOptionalInt(record map[string]any, key string, value *int) {
	if value != nil {
		record[key] = *value
	}
}

func isoTimestamp(timestamp float64) string {
	micros := int64(math.Round(timestamp * 1_000_000))
	return formatUTCMicros(time.Unix(0, micros*int64(time.Microsecond)).UTC())
}

func formatUTCMicros(value time.Time) string {
	return value.UTC().Format("2006-01-02T15:04:05.000000Z")
}

func transformAuditFS(events []auditEvent, outputPath string, threshold int, cfg auditConfig) ([]map[string]any, []map[string]any, error) {
	seen, err := readSeenKeys(outputPath, "fs")
	if err != nil {
		return nil, nil, err
	}

	var records []map[string]any
	grouped := map[string]*groupedProcessCount{}

	for _, event := range events {
		if len(event.Paths) == 0 {
			continue
		}

		base := baseProcessRecord(event)
		base["kind"] = "audit_fs_event"
		addOptionalString(base, "key", cleanControl(event.Key))
		addOptionalString(base, "cwd", cleanControl(event.Cwd))

		for _, item := range event.Paths {
			if item.Path == "" {
				continue
			}
			watchedRoot := watchedRootFor(item.Path, cfg.watchPaths)
			if watchedRoot == "" {
				continue
			}

			scope := "system"
			if _, ok := cfg.homeWatchPaths[watchedRoot]; ok {
				scope = "home"
			}

			dedupeKey := fmt.Sprintf("%d:%s:%s", event.Serial, item.Path, item.NameType)
			if _, ok := seen[dedupeKey]; ok {
				continue
			}
			seen[dedupeKey] = struct{}{}

			record := cloneRecord(base)
			record["scope"] = scope
			record["watched_root"] = watchedRoot
			record["path"] = item.Path
			addOptionalString(record, "nametype", cleanControl(item.NameType))
			addOptionalInt(record, "item", item.Item)
			records = append(records, record)

			signature := firstNonEmpty(anyToString(record["exe"]), anyToString(record["comm"]), "unknown")
			group := ensureGroupedCount(grouped, signature, anyToString(record["event_time"]), anyToString(record["exe"]), anyToString(record["comm"]))
			group.Count++
			group.EventTime = anyToString(record["event_time"])
		}
	}

	anomalies := make([]map[string]any, 0)
	for signature, info := range grouped {
		if info.Count < threshold {
			continue
		}
		anomalies = append(anomalies, buildAnomaly(
			info.EventTime,
			"write_burst",
			"warning",
			"audit_fs",
			fmt.Sprintf("%s touched %d watched paths in one export window", signature, info.Count),
			map[string]any{
				"count": info.Count,
				"exe":   info.Exe,
				"comm":  info.Comm,
			},
		))
	}

	return records, anomalies, nil
}

func transformAuditExec(events []auditEvent, outputPath string, stateDir string, lookbackDays int) ([]map[string]any, []map[string]any, error) {
	seen, err := readSeenKeys(outputPath, "exec")
	if err != nil {
		return nil, nil, err
	}

	seenExecPath := filepath.Join(stateDir, "seen-executables.json")
	seenExec, err := loadTimestampMap(seenExecPath)
	if err != nil {
		return nil, nil, err
	}

	nowTS := float64(time.Now().UTC().Unix())
	cutoff := nowTS - float64(lookbackDays*86400)
	pruned := map[string]float64{}
	for exe, ts := range seenExec {
		if ts >= cutoff {
			pruned[exe] = ts
		}
	}

	var records []map[string]any
	var anomalies []map[string]any
	for _, event := range events {
		serialKey := strconv.Itoa(event.Serial)
		if _, ok := seen[serialKey]; ok {
			continue
		}
		seen[serialKey] = struct{}{}

		record := baseProcessRecord(event)
		record["kind"] = "audit_exec_event"
		addOptionalInt(record, "argc", event.Argc)
		addOptionalString(record, "argv", cleanControl(event.Argv))
		records = append(records, record)

		exe := anyToString(record["exe"])
		if exe != "" {
			if _, ok := pruned[exe]; !ok {
				anomalies = append(anomalies, buildAnomaly(
					anyToString(record["event_time"]),
					"new_executable",
					"info",
					"audit_exec",
					fmt.Sprintf("first seen executable: %s", exe),
					map[string]any{
						"exe":     exe,
						"comm":    record["comm"],
						"pid":     record["pid"],
						"cmdline": record["cmdline"],
					},
				))
				pruned[exe] = event.Timestamp
			}
		}
	}

	if err := saveJSON(seenExecPath, pruned); err != nil {
		return nil, nil, err
	}
	return records, anomalies, nil
}

func transformAuditNet(events []auditEvent, outputPath string, stateDir string, threshold int, cfg auditConfig) ([]map[string]any, []map[string]any, error) {
	seen, err := readSeenKeys(outputPath, "net")
	if err != nil {
		return nil, nil, err
	}

	geoCachePath := filepath.Join(stateDir, "geoip-cache.json")
	geoCache, err := loadGeoCache(geoCachePath)
	if err != nil {
		return nil, nil, err
	}

	var records []map[string]any
	grouped := map[string]*groupedProcessCount{}
	for _, event := range events {
		serialKey := strconv.Itoa(event.Serial)
		if _, ok := seen[serialKey]; ok {
			continue
		}
		seen[serialKey] = struct{}{}

		sockaddr := map[string]string{}
		for _, item := range event.SockAddrs {
			if len(item) > 0 {
				sockaddr = item
				break
			}
		}

		family := cleanControl(sockaddr["saddr_fam"])
		destIP := normalizeLookupIP(firstNonEmpty(sockaddr["daddr"], sockaddr["faddr"], sockaddr["raddr"], sockaddr["addr"], sockaddr["laddr"]))
		rawDestPort := firstNonEmpty(sockaddr["dport"], sockaddr["fport"], sockaddr["rport"], sockaddr["port"], sockaddr["lport"])
		destPort := parseOptionalInt(rawDestPort)
		if destPort != nil && (*destPort == 0 || *destPort == 65535) {
			destPort = nil
		}
		unixPath := cleanControl(sockaddr["path"])
		if family == "" && unixPath != "" {
			family = "local"
		}

		geo := geoLookup(destIP, geoCache, cfg)
		destTarget := geo.Host
		if destTarget == "" {
			switch {
			case family == "inet6" && destIP != "" && destPort != nil:
				destTarget = fmt.Sprintf("[%s]:%d", destIP, *destPort)
			case destIP != "" && destPort != nil:
				destTarget = fmt.Sprintf("%s:%d", destIP, *destPort)
			default:
				destTarget = firstNonEmpty(destIP, unixPath)
			}
		}

		record := baseProcessRecord(event)
		record["kind"] = "audit_net_event"
		addOptionalString(record, "family", family)
		addOptionalString(record, "dest_ip", destIP)
		addOptionalInt(record, "dest_port", destPort)
		addOptionalString(record, "unix_path", unixPath)
		addOptionalString(record, "country_code", geo.CountryCode)
		addOptionalString(record, "country_name", geo.CountryName)
		addOptionalString(record, "dest_host", geo.Host)
		addOptionalString(record, "dest_target", destTarget)
		records = append(records, record)

		signature := firstNonEmpty(anyToString(record["exe"]), anyToString(record["comm"]), "unknown")
		group := ensureGroupedCount(grouped, signature, anyToString(record["event_time"]), anyToString(record["exe"]), anyToString(record["comm"]))
		group.Count++
		group.EventTime = anyToString(record["event_time"])
	}

	if err := saveJSON(geoCachePath, geoCache); err != nil {
		return nil, nil, err
	}

	anomalies := make([]map[string]any, 0)
	for signature, info := range grouped {
		if info.Count < threshold {
			continue
		}
		anomalies = append(anomalies, buildAnomaly(
			info.EventTime,
			"connect_burst",
			"warning",
			"audit_net",
			fmt.Sprintf("%s opened %d network connections in one export window", signature, info.Count),
			map[string]any{
				"count": info.Count,
				"exe":   info.Exe,
				"comm":  info.Comm,
			},
		))
	}

	return records, anomalies, nil
}

type groupedProcessCount struct {
	Count     int
	EventTime string
	Exe       string
	Comm      string
}

type groupedAuditSummary struct {
	Count  int
	Fields map[string]any
}

func ensureGroupedCount(grouped map[string]*groupedProcessCount, signature string, eventTime string, exe string, comm string) *groupedProcessCount {
	group, ok := grouped[signature]
	if !ok {
		group = &groupedProcessCount{
			EventTime: eventTime,
			Exe:       exe,
			Comm:      comm,
		}
		grouped[signature] = group
	}
	return group
}

func buildAuditSummaries(mode auditMode, events []auditEvent, records []map[string]any) []map[string]any {
	windowStart, windowEnd := auditSummaryWindow(events)

	switch mode {
	case auditModeFS:
		return buildAuditFSSummaries(records, windowStart, windowEnd)
	case auditModeExec:
		return buildAuditExecSummaries(records, windowStart, windowEnd)
	case auditModeNet:
		return buildAuditNetSummaries(records, windowStart, windowEnd)
	default:
		return nil
	}
}

func auditSummaryWindow(events []auditEvent) (string, string) {
	if len(events) == 0 {
		now := formatUTCMicros(time.Now().UTC())
		return now, now
	}

	minTs := events[0].Timestamp
	maxTs := events[0].Timestamp
	for _, event := range events[1:] {
		if event.Timestamp < minTs {
			minTs = event.Timestamp
		}
		if event.Timestamp > maxTs {
			maxTs = event.Timestamp
		}
	}
	return isoTimestamp(minTs), isoTimestamp(maxTs)
}

func buildAuditExecSummaries(records []map[string]any, windowStart string, windowEnd string) []map[string]any {
	summaries := []map[string]any{
		newAuditSummary("audit_exec_summary", "window_total", windowStart, windowEnd, len(records), nil),
	}

	grouped := map[string]*groupedAuditSummary{}
	for _, record := range records {
		exe := anyToString(record["exe"])
		comm := anyToString(record["comm"])
		cmdline := anyToString(record["cmdline"])
		if exe == "" && comm == "" && cmdline == "" {
			continue
		}

		key := strings.Join([]string{exe, comm, cmdline}, "\x00")
		group := ensureAuditSummary(grouped, key, map[string]any{
			"exe":     exe,
			"comm":    comm,
			"cmdline": cmdline,
		})
		group.Count++
	}

	return append(summaries, groupedAuditSummaries("audit_exec_summary", "by_exe", windowStart, windowEnd, grouped)...)
}

func buildAuditFSSummaries(records []map[string]any, windowStart string, windowEnd string) []map[string]any {
	summaries := []map[string]any{
		newAuditSummary("audit_fs_summary", "window_total", windowStart, windowEnd, len(records), nil),
	}

	grouped := map[string]*groupedAuditSummary{}
	for _, record := range records {
		exe := anyToString(record["exe"])
		comm := anyToString(record["comm"])
		path := anyToString(record["path"])
		root := anyToString(record["watched_root"])
		scope := anyToString(record["scope"])
		if path == "" || root == "" {
			continue
		}

		key := strings.Join([]string{exe, comm, path, root, scope}, "\x00")
		group := ensureAuditSummary(grouped, key, map[string]any{
			"exe":          exe,
			"comm":         comm,
			"path":         path,
			"watched_root": root,
			"scope":        scope,
		})
		group.Count++
	}

	return append(summaries, groupedAuditSummaries("audit_fs_summary", "by_path_process", windowStart, windowEnd, grouped)...)
}

func buildAuditNetSummaries(records []map[string]any, windowStart string, windowEnd string) []map[string]any {
	summaries := []map[string]any{
		newAuditSummary("audit_net_summary", "window_total", windowStart, windowEnd, len(records), nil),
	}

	grouped := map[string]*groupedAuditSummary{}
	for _, record := range records {
		exe := anyToString(record["exe"])
		comm := anyToString(record["comm"])
		destTarget := anyToString(record["dest_target"])
		destIP := anyToString(record["dest_ip"])
		family := anyToString(record["family"])
		countryCode := anyToString(record["country_code"])
		countryName := anyToString(record["country_name"])
		destPort := anyToString(record["dest_port"])
		if destTarget == "" {
			continue
		}

		key := strings.Join([]string{exe, comm, destTarget, destIP, destPort, family, countryCode, countryName}, "\x00")
		fields := map[string]any{
			"exe":          exe,
			"comm":         comm,
			"dest_target":  destTarget,
			"dest_ip":      destIP,
			"family":       family,
			"country_code": countryCode,
			"country_name": countryName,
		}
		if destPortValue, ok := record["dest_port"]; ok {
			fields["dest_port"] = destPortValue
		}

		group := ensureAuditSummary(grouped, key, fields)
		group.Count++
	}

	return append(summaries, groupedAuditSummaries("audit_net_summary", "by_endpoint_process", windowStart, windowEnd, grouped)...)
}

func ensureAuditSummary(grouped map[string]*groupedAuditSummary, key string, fields map[string]any) *groupedAuditSummary {
	group, ok := grouped[key]
	if ok {
		return group
	}

	group = &groupedAuditSummary{
		Fields: fields,
	}
	grouped[key] = group
	return group
}

func groupedAuditSummaries(kind string, summaryKind string, windowStart string, windowEnd string, grouped map[string]*groupedAuditSummary) []map[string]any {
	summaries := make([]map[string]any, 0, len(grouped))
	for _, group := range grouped {
		summaries = append(summaries, newAuditSummary(kind, summaryKind, windowStart, windowEnd, group.Count, group.Fields))
	}
	return summaries
}

func newAuditSummary(kind string, summaryKind string, windowStart string, windowEnd string, count int, extra map[string]any) map[string]any {
	record := map[string]any{
		"kind":         kind,
		"event_time":   windowEnd,
		"summary_kind": summaryKind,
		"window_start": windowStart,
		"window_end":   windowEnd,
		"count":        count,
	}
	for key, value := range extra {
		switch typed := value.(type) {
		case nil:
			continue
		case string:
			if typed == "" {
				continue
			}
		}
		record[key] = value
	}
	return record
}

func watchedRootFor(path string, watchPaths []string) string {
	normalized := filepath.Clean(path)
	longest := ""
	for _, root := range watchPaths {
		if pathMatchesRoot(normalized, root) && len(root) > len(longest) {
			longest = root
		}
	}
	return longest
}

func pathMatchesRoot(path string, root string) bool {
	return path == root || strings.HasPrefix(path, root+"/")
}

func readSeenKeys(path string, mode string) (map[string]struct{}, error) {
	seen := map[string]struct{}{}
	file, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		return seen, nil
	}
	if err != nil {
		return nil, fmt.Errorf("open seen keys: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		var record map[string]any
		if err := json.Unmarshal(scanner.Bytes(), &record); err != nil {
			continue
		}

		serial, ok := record["serial"]
		if !ok {
			continue
		}

		if mode == "fs" {
			pathValue := anyToString(record["path"])
			if pathValue == "" {
				continue
			}
			seen[fmt.Sprintf("%v:%s:%s", serial, pathValue, anyToString(record["nametype"]))] = struct{}{}
			continue
		}
		seen[fmt.Sprintf("%v", serial)] = struct{}{}
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scan seen keys: %w", err)
	}
	return seen, nil
}

func loadGeoCache(path string) (map[string]geoRecord, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]geoRecord{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}

	cache := map[string]geoRecord{}
	if err := json.Unmarshal(data, &cache); err != nil {
		quarantineCorruptFile(path, err)
		return map[string]geoRecord{}, nil
	}
	return cache, nil
}

func loadOffsetMap(path string) (map[string]int64, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]int64{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}

	offsets := map[string]int64{}
	if err := json.Unmarshal(data, &offsets); err != nil {
		quarantineCorruptFile(path, err)
		return map[string]int64{}, nil
	}
	return offsets, nil
}

func quarantineCorruptFile(path string, err error) {
	corruptPath := fmt.Sprintf("%s.corrupt-%d", path, time.Now().UTC().UnixNano())
	if renameErr := os.Rename(path, corruptPath); renameErr != nil {
		infof("discarding corrupt state %s after parse error: %v (quarantine failed: %v)", path, err, renameErr)
		return
	}
	infof("discarding corrupt state %s after parse error: %v (moved to %s)", path, err, corruptPath)
}

func writeFileAtomic(path string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(path)
	file, err := os.CreateTemp(dir, filepath.Base(path)+".tmp-*")
	if err != nil {
		return fmt.Errorf("create temp %s: %w", path, err)
	}
	tempPath := file.Name()
	defer os.Remove(tempPath)

	if err := file.Chmod(perm); err != nil {
		file.Close()
		return fmt.Errorf("chmod temp %s: %w", path, err)
	}
	if _, err := file.Write(data); err != nil {
		file.Close()
		return fmt.Errorf("write temp %s: %w", path, err)
	}
	if err := file.Close(); err != nil {
		return fmt.Errorf("close temp %s: %w", path, err)
	}
	if err := os.Rename(tempPath, path); err != nil {
		return fmt.Errorf("rename temp %s: %w", path, err)
	}
	return nil
}

func saveJSON(path string, payload any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return fmt.Errorf("mkdir %s: %w", filepath.Dir(path), err)
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal %s: %w", path, err)
	}
	return writeFileAtomic(path, data, 0o640)
}

func appendNDJSON(path string, records []map[string]any) error {
	if len(records) == 0 {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return fmt.Errorf("mkdir %s: %w", filepath.Dir(path), err)
	}

	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o640)
	if err != nil {
		return fmt.Errorf("open %s: %w", path, err)
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	for _, record := range records {
		line, err := json.Marshal(record)
		if err != nil {
			return fmt.Errorf("marshal ndjson record: %w", err)
		}
		if _, err := writer.Write(line); err != nil {
			return fmt.Errorf("write %s: %w", path, err)
		}
		if err := writer.WriteByte('\n'); err != nil {
			return fmt.Errorf("write newline %s: %w", path, err)
		}
	}
	return writer.Flush()
}

func buildAnomaly(eventTime string, anomalyType string, severity string, sourceComponent string, message string, extra map[string]any) map[string]any {
	record := map[string]any{
		"kind":             "monitoring_anomaly",
		"event_time":       eventTime,
		"anomaly_type":     anomalyType,
		"severity":         severity,
		"source_component": sourceComponent,
		"message":          message,
	}
	for key, value := range extra {
		switch typed := value.(type) {
		case nil:
			continue
		case string:
			if typed == "" {
				continue
			}
		}
		record[key] = value
	}
	return record
}

func normalizeLookupIP(ip string) string {
	cleaned := cleanControl(ip)
	if strings.HasPrefix(strings.ToLower(cleaned), "::ffff:") {
		return cleaned[7:]
	}
	return cleaned
}

func geoLookup(ip string, cache map[string]geoRecord, cfg auditConfig) geoRecord {
	lookupIP := normalizeLookupIP(ip)
	if lookupIP == "" {
		return geoRecord{}
	}

	result := cache[lookupIP]
	result.CountryCode = cleanControl(result.CountryCode)
	result.CountryName = cleanControl(result.CountryName)
	result.Host = cleanControl(result.Host)

	if result.Host == "" {
		if hosts, err := net.LookupAddr(lookupIP); err == nil && len(hosts) > 0 {
			result.Host = strings.TrimSuffix(hosts[0], ".")
		}
	}

	if anycast := detectAnycastLocation(lookupIP, result.Host); anycast != "" {
		result.CountryCode = ""
		result.CountryName = anycast
		cache[lookupIP] = result
		return result
	}

	if result.CountryCode == "" {
		result.CountryCode = mmdbLookupValue(context.Background(), cfg, lookupIP, "country", "iso_code")
	}
	if result.CountryCode != "" && result.CountryName == "" {
		result.CountryName = mmdbLookupValue(context.Background(), cfg, lookupIP, "country", "names", "en")
	}

	cache[lookupIP] = result
	return result
}

func detectAnycastLocation(ip string, host string) string {
	normalizedIP := normalizeLookupIP(ip)
	normalizedHost := strings.TrimSuffix(strings.ToLower(cleanControl(host)), ".")
	if _, ok := anycastDNSIPs[normalizedIP]; ok {
		return "Anycast"
	}
	if _, ok := anycastDNSHosts[normalizedHost]; ok {
		return "Anycast"
	}
	for _, suffix := range anycastDNSHostSuffixes {
		if normalizedHost != "" && strings.HasSuffix(normalizedHost, suffix) {
			return "Anycast"
		}
	}
	return ""
}

func mmdbLookupValue(ctx context.Context, cfg auditConfig, ip string, lookupPath ...string) string {
	if ip == "" || cfg.mmdbLookupBin == "" || cfg.countryDB == "" {
		return ""
	}

	args := []string{"--file", cfg.countryDB, "--ip", ip}
	args = append(args, lookupPath...)

	output, err := exec.CommandContext(ctx, cfg.mmdbLookupBin, args...).Output()
	if err != nil {
		return ""
	}
	match := quotedValueRe.FindStringSubmatch(strings.TrimSpace(string(output)))
	if len(match) < 2 {
		return ""
	}
	return match[1]
}

func cloneRecord(record map[string]any) map[string]any {
	cloned := make(map[string]any, len(record))
	for key, value := range record {
		cloned[key] = value
	}
	return cloned
}

func anyToString(value any) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case string:
		return typed
	default:
		return fmt.Sprintf("%v", typed)
	}
}

func anyInt(value any) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int32:
		return int(typed)
	case int64:
		return int(typed)
	case float64:
		return int(typed)
	default:
		return 0
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func runNetworkUsage(args []string) error {
	if len(args) != 6 {
		return fmt.Errorf("usage: core-monitoring-tools network-usage <input> <output> <anomaly> <sample-seconds> <top-n> <threshold>")
	}

	inputPath := args[0]
	outputPath := args[1]
	anomalyPath := args[2]
	sampleSeconds, err := strconv.Atoi(args[3])
	if err != nil {
		return fmt.Errorf("parse sample seconds: %w", err)
	}
	topN, err := strconv.Atoi(args[4])
	if err != nil {
		return fmt.Errorf("parse top n: %w", err)
	}
	threshold, err := strconv.Atoi(args[5])
	if err != nil {
		return fmt.Errorf("parse threshold: %w", err)
	}

	records, anomalies, err := parseNetworkUsage(inputPath, sampleSeconds, topN, threshold)
	if err != nil {
		return err
	}
	if err := appendNDJSON(outputPath, records); err != nil {
		return err
	}
	return appendNDJSON(anomalyPath, anomalies)
}

func parseNetworkUsage(inputPath string, sampleSeconds int, topN int, threshold int) ([]map[string]any, []map[string]any, error) {
	file, err := os.Open(inputPath)
	if err != nil {
		return nil, nil, fmt.Errorf("open network usage input: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)

	latestBlock := make([]map[string]any, 0)
	currentBlock := make([]map[string]any, 0)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "Refreshing:" {
			if len(currentBlock) > 0 {
				latestBlock = currentBlock
			}
			currentBlock = make([]map[string]any, 0)
			continue
		}
		record := parseNetworkUsageProcessLine(line, sampleSeconds)
		if record != nil {
			currentBlock = append(currentBlock, record)
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, nil, fmt.Errorf("scan network usage input: %w", err)
	}
	if len(currentBlock) > 0 {
		latestBlock = currentBlock
	}

	sort.SliceStable(latestBlock, func(i int, j int) bool {
		return latestBlock[i]["total_kib_s"].(float64) > latestBlock[j]["total_kib_s"].(float64)
	})
	if len(latestBlock) > topN {
		latestBlock = latestBlock[:topN]
	}

	anomalies := make([]map[string]any, 0)
	for _, record := range latestBlock {
		total := record["total_kib_s"].(float64)
		if total < float64(threshold) {
			continue
		}
		anomalies = append(anomalies, map[string]any{
			"kind":             "monitoring_anomaly",
			"event_time":       record["event_time"],
			"anomaly_type":     "network_hot",
			"severity":         "warning",
			"source_component": "net_usage",
			"message":          fmt.Sprintf("%s is using %.1f KiB/s", anyToString(record["cmd"]), total),
			"pid":              record["pid"],
			"cmd":              record["cmd"],
			"exe":              record["exe"],
			"cmdline":          record["cmdline"],
			"total_kib_s":      total,
		})
	}

	return latestBlock, anomalies, nil
}

func parseNetworkUsageProcessLine(line string, sampleSeconds int) map[string]any {
	stripped := strings.TrimSpace(line)
	if stripped == "" || stripped == "Refreshing:" || strings.HasPrefix(stripped, "unknown") || strings.HasPrefix(stripped, "Adding local address:") {
		return nil
	}

	parts := strings.Split(stripped, "\t")
	if len(parts) != 3 {
		return nil
	}

	identityParts := strings.Split(parts[0], "/")
	if len(identityParts) < 3 {
		return nil
	}
	user := identityParts[len(identityParts)-1]
	pidRaw := identityParts[len(identityParts)-2]
	exe := strings.Join(identityParts[:len(identityParts)-2], "/")

	pid, err := strconv.Atoi(pidRaw)
	if err != nil {
		return nil
	}
	tx, err := strconv.ParseFloat(parts[1], 64)
	if err != nil {
		return nil
	}
	rx, err := strconv.ParseFloat(parts[2], 64)
	if err != nil {
		return nil
	}

	now := time.Now().UTC()
	bucket := time.Date(now.Year(), now.Month(), now.Day(), now.Hour(), (now.Minute()/5)*5, 0, 0, time.UTC)
	cmdline := readProcCmdline(pid)
	cmd := filepath.Base(exe)
	if cmd == "" {
		cmd = exe
	}

	return map[string]any{
		"kind":           "net_usage_process",
		"event_time":     formatUTCMicros(now),
		"time_bucket":    bucket.Format("20060102T1504"),
		"pid":            pid,
		"user":           user,
		"cmd":            cmd,
		"exe":            exe,
		"cmdline":        cmdline,
		"tx_kib_s":       tx,
		"rx_kib_s":       rx,
		"total_kib_s":    tx + rx,
		"sample_seconds": sampleSeconds,
	}
}

func runProcessMetricsExporter() error {
	port := envInt("CORE_MONITORING_EXPORTER_PORT", 9109)
	sampleInterval := time.Duration(envInt("CORE_MONITORING_SAMPLE_INTERVAL", 15)) * time.Second
	topN := envInt("CORE_MONITORING_TOP_N", 5)
	clockTicks := readClockTicks()
	pageSize := os.Getpagesize()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	exporter := newProcessMetricsExporter(sampleInterval, topN, clockTicks, uint64(pageSize))
	exporter.start(ctx)

	mux := http.NewServeMux()
	mux.HandleFunc("/metrics", exporter.serveMetrics)
	server := &http.Server{
		Addr:    fmt.Sprintf("127.0.0.1:%d", port),
		Handler: mux,
	}

	serverErr := make(chan error, 1)
	go func() {
		err := server.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
			return
		}
		serverErr <- nil
	}()

	select {
	case <-ctx.Done():
	case err := <-serverErr:
		if err != nil {
			return err
		}
		return nil
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_ = server.Shutdown(shutdownCtx)
	<-serverErr
	return nil
}

func envInt(name string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}

func readClockTicks() float64 {
	output, err := exec.Command("getconf", "CLK_TCK").Output()
	if err != nil {
		return 100.0
	}

	parsed, err := strconv.ParseFloat(strings.TrimSpace(string(output)), 64)
	if err != nil || parsed <= 0 {
		return 100.0
	}
	return parsed
}

type processSnapshot struct {
	PID      string
	Comm     string
	Cmd      string
	Exe      string
	CPUTicks uint64
	RSSBytes uint64
	IOBytes  uint64
}

type processMetricRow struct {
	PID         string
	Comm        string
	Cmd         string
	Exe         string
	CPUPercent  float64
	RSSBytes    float64
	DiskIOBytes float64
}

type processMetricsExporter struct {
	sampleInterval time.Duration
	topN           int
	clockTicks     float64
	pageSize       uint64

	mu             sync.RWMutex
	payload        []byte
	latestError    string
	latestSampleTS float64
}

func newProcessMetricsExporter(sampleInterval time.Duration, topN int, clockTicks float64, pageSize uint64) *processMetricsExporter {
	return &processMetricsExporter{
		sampleInterval: sampleInterval,
		topN:           topN,
		clockTicks:     clockTicks,
		pageSize:       pageSize,
		payload:        []byte(renderProcessMetricsPayload(nil, nil, nil, float64(time.Now().UTC().Unix()), "")),
	}
}

func (exporter *processMetricsExporter) start(ctx context.Context) {
	go exporter.samplerLoop(ctx)
}

func (exporter *processMetricsExporter) samplerLoop(ctx context.Context) {
	previousSnapshot := exporter.readSnapshot()
	previousMonotonic := time.Now()
	exporter.updatePayload(nil, nil, nil, "", time.Now().UTC())

	ticker := time.NewTicker(exporter.sampleInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			currentSnapshot := exporter.readSnapshot()
			currentMonotonic := time.Now()
			elapsed := currentMonotonic.Sub(previousMonotonic).Seconds()
			if elapsed < 0.001 {
				elapsed = 0.001
			}

			rows := make([]processMetricRow, 0, len(currentSnapshot))
			for pid, current := range currentSnapshot {
				previous, ok := previousSnapshot[pid]
				cpuPercent := 0.0
				diskIOBytes := 0.0
				if ok {
					cpuTicks := clampUint64Diff(current.CPUTicks, previous.CPUTicks)
					cpuPercent = (float64(cpuTicks) / exporter.clockTicks) / elapsed * 100.0
					diskIOBytes = float64(clampUint64Diff(current.IOBytes, previous.IOBytes))
				}
				rows = append(rows, processMetricRow{
					PID:         current.PID,
					Comm:        current.Comm,
					Cmd:         current.Cmd,
					Exe:         current.Exe,
					CPUPercent:  cpuPercent,
					RSSBytes:    float64(current.RSSBytes),
					DiskIOBytes: diskIOBytes,
				})
			}

			sort.SliceStable(rows, func(i int, j int) bool { return rows[i].CPUPercent > rows[j].CPUPercent })
			cpuRows := truncateProcessRows(rows, exporter.topN)

			sort.SliceStable(rows, func(i int, j int) bool { return rows[i].RSSBytes > rows[j].RSSBytes })
			memRows := truncateProcessRows(rows, exporter.topN)

			sort.SliceStable(rows, func(i int, j int) bool { return rows[i].DiskIOBytes > rows[j].DiskIOBytes })
			diskRows := truncateProcessRows(rows, exporter.topN)

			previousSnapshot = currentSnapshot
			previousMonotonic = currentMonotonic
			exporter.updatePayload(cpuRows, memRows, diskRows, "", currentMonotonic.UTC())
		}
	}
}

func (exporter *processMetricsExporter) readSnapshot() map[string]processSnapshot {
	snapshot := map[string]processSnapshot{}
	entries, err := os.ReadDir("/proc")
	if err != nil {
		exporter.updatePayload(nil, nil, nil, err.Error(), time.Now().UTC())
		return snapshot
	}

	for _, entry := range entries {
		if !entry.IsDir() || !allDigits(entry.Name()) {
			continue
		}

		pid := entry.Name()
		stat, err := readProcessStat(pid, exporter.pageSize)
		if err != nil {
			continue
		}
		cmdline, _ := readProcCmdlineWithError(pid)
		exe, _ := readProcExe(pid)
		snapshot[pid] = processSnapshot{
			PID:      pid,
			Comm:     firstNonEmpty(stat.Comm, "?"),
			Cmd:      firstNonEmpty(cmdline, exe, stat.Comm, "?"),
			Exe:      exe,
			CPUTicks: stat.CPUTicks,
			RSSBytes: stat.RSSBytes,
			IOBytes:  readProcessIOBytes(pid),
		}
	}
	return snapshot
}

type processStat struct {
	Comm     string
	CPUTicks uint64
	RSSBytes uint64
}

func readProcessStat(pid string, pageSize uint64) (processStat, error) {
	content, err := os.ReadFile(filepath.Join("/proc", pid, "stat"))
	if err != nil {
		return processStat{}, err
	}
	raw := string(content)
	rightParen := strings.LastIndex(raw, ")")
	leftParen := strings.Index(raw, "(")
	if rightParen < 0 || leftParen < 0 || rightParen <= leftParen {
		return processStat{}, fmt.Errorf("malformed stat")
	}
	comm := raw[leftParen+1 : rightParen]
	fields := strings.Fields(raw[rightParen+2:])
	if len(fields) < 22 {
		return processStat{}, fmt.Errorf("short stat")
	}

	utime, err := strconv.ParseUint(fields[11], 10, 64)
	if err != nil {
		return processStat{}, err
	}
	stime, err := strconv.ParseUint(fields[12], 10, 64)
	if err != nil {
		return processStat{}, err
	}
	rssPages, err := strconv.ParseUint(fields[21], 10, 64)
	if err != nil {
		return processStat{}, err
	}

	return processStat{
		Comm:     comm,
		CPUTicks: utime + stime,
		RSSBytes: rssPages * pageSize,
	}, nil
}

func readProcCmdline(pid int) string {
	cmdline, _ := readProcCmdlineWithError(strconv.Itoa(pid))
	return cmdline
}

func readProcCmdlineWithError(pid string) (string, error) {
	raw, err := os.ReadFile(filepath.Join("/proc", pid, "cmdline"))
	if err != nil {
		return "", err
	}
	replaced := bytes.ReplaceAll(raw, []byte{0}, []byte(" "))
	return strings.TrimSpace(string(replaced)), nil
}

func readProcExe(pid string) (string, error) {
	return os.Readlink(filepath.Join("/proc", pid, "exe"))
}

func readProcessIOBytes(pid string) uint64 {
	file, err := os.Open(filepath.Join("/proc", pid, "io"))
	if err != nil {
		return 0
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var total uint64
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "read_bytes:") && !strings.HasPrefix(line, "write_bytes:") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		value, err := strconv.ParseUint(strings.TrimSpace(parts[1]), 10, 64)
		if err != nil {
			continue
		}
		total += value
	}
	return total
}

func clampUint64Diff(current uint64, previous uint64) uint64 {
	if current < previous {
		return 0
	}
	return current - previous
}

func truncateProcessRows(rows []processMetricRow, topN int) []processMetricRow {
	if len(rows) <= topN {
		cloned := make([]processMetricRow, len(rows))
		copy(cloned, rows)
		return cloned
	}
	cloned := make([]processMetricRow, topN)
	copy(cloned, rows[:topN])
	return cloned
}

func (exporter *processMetricsExporter) updatePayload(cpuRows []processMetricRow, memRows []processMetricRow, diskRows []processMetricRow, latestError string, sampledAt time.Time) {
	exporter.mu.Lock()
	defer exporter.mu.Unlock()
	exporter.latestError = latestError
	exporter.latestSampleTS = float64(sampledAt.UnixNano()) / float64(time.Second)
	exporter.payload = []byte(renderProcessMetricsPayload(cpuRows, memRows, diskRows, exporter.latestSampleTS, latestError))
}

func renderProcessMetricsPayload(cpuRows []processMetricRow, memRows []processMetricRow, diskRows []processMetricRow, sampledAt float64, latestError string) string {
	lines := make([]string, 0, 8+len(cpuRows)+len(memRows)+len(diskRows))
	lines = append(lines, renderProcessMetric("core_monitoring_process_cpu_percent", "Top processes by CPU percentage for the last sampling interval.", "gauge", cpuRows, func(row processMetricRow) float64 {
		return row.CPUPercent
	})...)
	lines = append(lines, renderProcessMetric("core_monitoring_process_memory_rss_bytes", "Top processes by resident set size in bytes.", "gauge", memRows, func(row processMetricRow) float64 {
		return row.RSSBytes
	})...)
	lines = append(lines, renderProcessMetric("core_monitoring_process_disk_io_bytes", "Top processes by storage IO bytes for the last sampling interval.", "gauge", diskRows, func(row processMetricRow) float64 {
		return row.DiskIOBytes
	})...)
	lines = append(lines,
		"# HELP core_monitoring_process_exporter_last_sample_timestamp_seconds Unix timestamp of the last successful process sample.",
		"# TYPE core_monitoring_process_exporter_last_sample_timestamp_seconds gauge",
		fmt.Sprintf("core_monitoring_process_exporter_last_sample_timestamp_seconds %.6f", sampledAt),
		"# HELP core_monitoring_process_exporter_error 1 when the latest sampling loop failed.",
		"# TYPE core_monitoring_process_exporter_error gauge",
		fmt.Sprintf("core_monitoring_process_exporter_error %d", boolToInt(latestError != "")),
	)
	return strings.Join(lines, "\n") + "\n"
}

func renderProcessMetric(name string, helpText string, metricType string, rows []processMetricRow, valueFn func(processMetricRow) float64) []string {
	lines := []string{
		fmt.Sprintf("# HELP %s %s", name, helpText),
		fmt.Sprintf("# TYPE %s %s", name, metricType),
	}
	for _, row := range rows {
		lines = append(lines, fmt.Sprintf(
			`%s{pid="%s",comm="%s",cmd="%s",exe="%s"} %.6f`,
			name,
			escapePrometheusLabel(row.PID),
			escapePrometheusLabel(row.Comm),
			escapePrometheusLabel(row.Cmd),
			escapePrometheusLabel(row.Exe),
			valueFn(row),
		))
	}
	return lines
}

func escapePrometheusLabel(value string) string {
	return strings.NewReplacer(`\`, `\\`, "\n", `\n`, `"`, `\"`).Replace(value)
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func (exporter *processMetricsExporter) serveMetrics(writer http.ResponseWriter, request *http.Request) {
	if request.URL.Path != "/metrics" {
		http.NotFound(writer, request)
		return
	}

	exporter.mu.RLock()
	payload := exporter.payload
	exporter.mu.RUnlock()

	writer.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	writer.Header().Set("Content-Length", strconv.Itoa(len(payload)))
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write(payload)
}
