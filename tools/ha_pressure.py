#!/usr/bin/env python3
"""Pull Pump Monitor pressure history straight from HA's recorder DB on machone
and print the sustained plateaus (line / zone levels) with times.

Usage: ./tools/ha_pressure.py [start 'YYYY-MM-DD HH:MM'] [end 'YYYY-MM-DD HH:MM']
       (local Pacific time; defaults to the last 12 hours)

Runs the query over ssh; HA's DB is opened read-only (WAL is still read, so
the newest samples are included). Nothing is written on the HA host.
"""
import subprocess, sys, json, datetime as dt

TZ = dt.timezone(dt.timedelta(hours=-7))  # PDT; adjust to -8 in standard time
now = dt.datetime.now(TZ)
start = dt.datetime.strptime(sys.argv[1], '%Y-%m-%d %H:%M').replace(tzinfo=TZ) if len(sys.argv) > 1 else now - dt.timedelta(hours=12)
end = dt.datetime.strptime(sys.argv[2], '%Y-%m-%d %H:%M').replace(tzinfo=TZ) if len(sys.argv) > 2 else now

remote = f"""
import sqlite3, json
con = sqlite3.connect('file:/home/caseman/ha-infrastructure/ha-config/home-assistant_v2.db?mode=ro', uri=True)
cur = con.cursor()
cur.execute("SELECT metadata_id FROM states_meta WHERE entity_id='sensor.pump_monitor_pump_pressure'")
mid = cur.fetchone()[0]
cur.execute('SELECT last_updated_ts, state FROM states WHERE metadata_id=? AND last_updated_ts BETWEEN ? AND ? ORDER BY last_updated_ts', (mid, {start.timestamp()}, {end.timestamp()}))
rows = [(t, float(s)) for t, s in cur.fetchall() if s not in ('unknown', 'unavailable', None)]
print(json.dumps(rows))
"""
out = subprocess.run(['ssh', 'machone', 'python3', '-'], input=remote, capture_output=True, text=True, check=True).stdout
rows = json.loads(out)
if not rows:
    sys.exit('no samples in range')

# Plateau detection: group consecutive samples within a band of the running mean.
BAND = float(__import__("os").environ.get("BAND", "1.2"))      # psi
MIN_LEN = 90    # seconds
segs, cur_seg = [], [rows[0]]
mean = rows[0][1]
for t, p in rows[1:]:
    if abs(p - mean) <= BAND:
        cur_seg.append((t, p)); mean = sum(x[1] for x in cur_seg[-60:]) / min(len(cur_seg), 60)
    else:
        segs.append(cur_seg); cur_seg = [(t, p)]; mean = p
segs.append(cur_seg)

f = lambda t: dt.datetime.fromtimestamp(t, TZ).strftime('%H:%M:%S')
print(f"{len(rows)} samples {f(rows[0][0])} -> {f(rows[-1][0])}  (plateaus >= {MIN_LEN}s, band +/-{BAND} psi)\n")
print(f"{'start':>9} {'end':>9} {'dur':>7} {'mean':>6} {'min':>6} {'max':>6}  n")
for s in segs:
    dur = s[-1][0] - s[0][0]
    if dur < MIN_LEN:
        continue
    ps = [p for _, p in s]
    print(f"{f(s[0][0]):>9} {f(s[-1][0]):>9} {dur/60:6.1f}m {sum(ps)/len(ps):6.1f} {min(ps):6.1f} {max(ps):6.1f}  {len(ps)}")
