var resp = jelastic.env.control.GetEnvs();
if (resp.result !== 0) return resp;
var envs = [];
var nodes = {};
var currentStorageExists = false;
var scheduleType = '${settings.scheduleType}';
for (var i = 0, envInfo, env; envInfo = resp.infos[i]; i++) {
    if (envInfo.envGroups.includes("WP Backup") || envInfo.envGroups.includes("Backup storage nodes")) {
        env = envInfo.env
        if (env.status == 1) {
            for (var j = 0, node; node = envInfo.nodes[j]; j++) {
                nodes[env.envName] = nodes[env.envName] || [];
                nodes[env.envName].groups = nodes[env.envName].groups || {};
                if (!nodes[env.envName].groups[node.nodeGroup]) nodes[env.envName].push({
                    value: node.nodeGroup,
                    caption: (node.displayName || node.name) + ' (' + node.nodeGroup + ')'
                });
                nodes[env.envName].groups[node.nodeGroup] = true;
                if ( env.envName == '${settings.storageName}' ) {
                    currentStorageExists = true;
                }
            }
            if (nodes[env.envName] && nodes[env.envName].length > 0) {
                envs.push({
                    value: env.envName,
                    caption: (env.displayName + " (" + env.envName + ")"  || env.envName)
                });
            }
        }
    }
}

jps.settings.main.fields[1].values = envs;
jps.settings.main.fields[1].default = "";
if (envs.length > 0) {
    if (currentStorageExists == true) {
        jps.settings.main.fields[1].default = '${settings.storageName}';
    } else {
        jps.settings.main.fields[1].default = envs[0].value;
    }
}
      
import java.util.TimeZone;
var zones = toNative(TimeZone.getAvailableIDs());
var values = {};

for (var i = 0, n = zones.length; i < n; i++) {
  var offset = TimeZone.getTimeZone(zones[i]).getRawOffset()/3600000;
  var m = offset % 1;
  if (m != 0) m = Math.abs(m * 60);
  if (m < 10) m = "0" + m;
  var h = Math.floor(offset);
  if (Math.abs(h) < 10) h = h < 0 ? "-0" + Math.abs(h) : "+0" + h; else if (h >= 0) h = "+" + h;
  values[zones[i]] = zones[i] + (zones[i] == "GMT" ? "" : " (GMT" + h + ":" + m + ")");
}

jps.settings.main.fields[0].default = '${settings.scheduleType}';

if (scheduleType == '1') {
    jps.settings.main.fields[0].showIf[1][0].default = '${settings.cronTime}';
} else if (scheduleType == '2') {
    jps.settings.main.fields[0].showIf[2][0].default = '${settings.backupTime}';
    var sun = ('${settings.sun}' === 'true'), 
        mon = ('${settings.mon}' === 'true'), 
        tue = ('${settings.tue}' === 'true'), 
        wed = ('${settings.wed}' === 'true'), 
        thu = ('${settings.thu}' === 'true'), 
        fri = ('${settings.fri}' === 'true'), 
        sat = ('${settings.sat}' === 'true');
    var selectedDays = {
      "caption": "Days",
      "type": "compositefield",
      "name": "days",
      "defaultMargins": "0 12 0 0",
      "items": [
        {
          "name": "sun",
          "value": sun,
          "type": "checkbox",
          "caption": "Su"
        },
        {
          "name": "mon",
          "value": mon,
          "type": "checkbox",
          "caption": "Mo"
        },
        {
          "name": "tue",
          "value": tue,
          "type": "checkbox",
          "caption": "Tu"
        },
        {
          "name": "wed",
          "value": wed,
          "type": "checkbox",
          "caption": "We"
        },
        {
          "name": "thu",
          "value": thu,
          "type": "checkbox",
          "caption": "Th"
        },
        {
          "name": "fri",
          "value": fri,
          "type": "checkbox",
          "caption": "Fr"
        },
        {
          "name": "sat",
          "value": sat,
          "type": "checkbox",
          "caption": "Sa"
        }
      ]
    };
    jps.settings.main.fields[0].showIf[2][1] = selectedDays;
    jps.settings.main.fields[0].showIf[2][2].values = values;
    jps.settings.main.fields[0].showIf[2][2].value = '${settings.tz}';    
} else {
    jps.settings.main.fields[0].showIf[3][0].default = '${settings.cronTime}';
}

jps.settings.main.fields[2].default = '${settings.backupCount}';

return settings;
