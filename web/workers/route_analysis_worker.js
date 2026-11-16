self.onmessage = function (event) {
  var started = performance.now();
  var input = JSON.parse(event.data);
  var points = input.synthetic > 0 ? synthetic(input.synthetic, input.zones) : input.points;
  var result = analyze(points, input.zones || []);
  result.elapsedMs = performance.now() - started;
  result.thread = 'web-worker';
  self.postMessage(JSON.stringify(result));
};

function haversine(lat1, lng1, lat2, lng2) {
  var R = 6371000, rad = Math.PI / 180;
  var dLat = (lat2 - lat1) * rad, dLng = (lng2 - lng1) * rad;
  var a = Math.pow(Math.sin(dLat / 2), 2) + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.pow(Math.sin(dLng / 2), 2);
  return 2 * R * Math.asin(Math.sqrt(a));
}

function rng(seed) {
  var s = seed >>> 0;
  return function () { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

function synthetic(n, zones) {
  var home = zones.length ? zones[0] : [1.21361, -77.28111, 100, 'Casa'];
  var r = rng(42), out = new Array(n), lat = home[0], lng = home[1], t = 0;
  for (var i = 0; i < n; i++) {
    lat += (r() - 0.5) * 0.0004 + (home[0] - lat) * 0.02;
    lng += (r() - 0.5) * 0.0004 + (home[1] - lng) * 0.02;
    t += 60000;
    out[i] = [lat, lng, t];
  }
  return out;
}

function analyze(points, zones) {
  var distance = 0, maxSpeed = 0, outsideMs = 0, totalMs = 0;
  var zoneMs = {}, cells = {};
  for (var z = 0; z < zones.length; z++) zoneMs[zones[z][3]] = 0;
  for (var i = 0; i < points.length; i++) {
    var p = points[i];
    var key = Math.round(p[0] * 1000) + ',' + Math.round(p[1] * 1000);
    cells[key] = (cells[key] || 0) + 1;
    if (i === 0) continue;
    var q = points[i - 1];
    var d = haversine(q[0], q[1], p[0], p[1]);
    var dt = p[2] - q[2];
    distance += d;
    if (dt > 0) {
      totalMs += dt;
      var kmh = d / (dt / 1000) * 3.6;
      if (kmh > maxSpeed && kmh < 200) maxSpeed = kmh;
      var inside = null;
      for (var j = 0; j < zones.length; j++) {
        if (haversine(zones[j][0], zones[j][1], q[0], q[1]) <= zones[j][2]) { inside = zones[j][3]; break; }
      }
      if (inside === null) outsideMs += dt; else zoneMs[inside] += dt;
    }
  }
  var top = Object.keys(cells).map(function (k) {
    var parts = k.split(',');
    return [parts[0] / 1000, parts[1] / 1000, cells[k]];
  }).sort(function (a, b) { return b[2] - a[2]; }).slice(0, 5);
  return {
    points: points.length,
    distanceM: distance,
    maxSpeedKmh: maxSpeed,
    avgSpeedKmh: totalMs > 0 ? distance / (totalMs / 1000) * 3.6 : 0,
    totalMs: totalMs,
    outsideMs: outsideMs,
    zoneMs: zoneMs,
    topPlaces: top
  };
}
