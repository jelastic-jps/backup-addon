var resp = jelastic.env.control.GetEnvs();
if (resp.result !== 0) return resp;
var envs = [];
var nodes = {};
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

if (envs.length > 0) {
    jps.settings.main.fields[1].values = envs;
    jps.settings.main.fields[1].default = envs[0].value;
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
      
jps.settings.main.fields[0].showIf[2][2].values = values;
jps.settings.main.fields[0].showIf[2][2].value = "GMT0";
      
return {
    result: 0,
    settings: jps.settings
};
